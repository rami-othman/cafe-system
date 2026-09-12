<?php

namespace App\Services;

use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Draft Credit Note CRUD — mirrors SalesInvoiceService for the same reason:
 * a draft has no financial effect (docs/sales Phase 4 §1/§21). Returnable
 * quantity is checked here for fast UX feedback only; the authoritative,
 * lock-protected check happens again in SalesCreditNotePostingService.
 */
final class SalesCreditNoteService
{
    public function create(int $tenantId, int $actorId, array $data): object
    {
        return DB::transaction(function () use ($tenantId, $actorId, $data): object {
            DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->firstOrFail();
            $fingerprint = IdempotencyFingerprint::from($data);
            if (! empty($data['idempotencyKey'])) {
                $existing = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('idempotency_key', $data['idempotencyKey'])->first();
                if ($existing) {
                    if ($existing->request_fingerprint !== $fingerprint) throw ValidationException::withMessages(['idempotencyKey' => 'This idempotency key was already used for a different request.']);

                    return $this->find($tenantId, $existing->id);
                }
            }
            $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $data['originalSalesInvoiceId'] ?? 0)->first();
            if (! $invoice || $invoice->status !== 'posted') {
                throw ValidationException::withMessages(['originalSalesInvoiceId' => 'Select a posted sales invoice to credit.']);
            }
            $lines = $this->pricedLines($tenantId, (int) $invoice->id, $data['lines'] ?? []);
            $totals = $this->totals($lines);
            $creditDate = CarbonImmutable::parse($data['creditDate'] ?? now())->toDateString();
            $year = CarbonImmutable::parse($creditDate)->year;
            $sequence = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('credit_note_number', 'like', "CN-{$year}-%")->count() + 1;
            $id = DB::table('sales_credit_notes')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $invoice->branch_id, 'customer_id' => $invoice->customer_id,
                'original_sales_invoice_id' => $invoice->id, 'credit_note_number' => sprintf('CN-%d-%06d', $year, $sequence),
                'credit_date' => $creditDate, 'reason' => $data['reason'] ?? null, 'status' => 'draft',
                'subtotal' => Money::decimal($totals['subtotal']), 'tax_total' => Money::decimal($totals['tax']), 'total' => Money::decimal($totals['total']),
                'idempotency_key' => $data['idempotencyKey'] ?? null, 'request_fingerprint' => $fingerprint,
                'created_by' => $actorId, 'updated_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
            ]);
            $this->replaceLines($tenantId, $id, $lines);

            return $this->find($tenantId, $id);
        });
    }

    public function cancel(int $tenantId, int $id, int $actorId): object
    {
        $note = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('id', $id)->first();
        abort_unless($note, 404, 'Credit note not found.');
        if ($note->status !== 'draft') {
            throw ValidationException::withMessages(['status' => 'Only a draft credit note can be cancelled.']);
        }
        DB::table('sales_credit_notes')->where('id', $id)->update(['status' => 'cancelled', 'updated_by' => $actorId, 'updated_at' => now()]);

        return $this->find($tenantId, $id);
    }

    public function find(int $tenantId, int $id): object
    {
        $note = DB::table('sales_credit_notes as n')->join('customers as c', 'c.id', '=', 'n.customer_id')->join('branches as b', 'b.id', '=', 'n.branch_id')
            ->join('sales_invoices as i', 'i.id', '=', 'n.original_sales_invoice_id')->leftJoin('users as u', 'u.id', '=', 'n.created_by')
            ->where('n.tenant_id', $tenantId)->where('n.id', $id)
            ->select('n.*', 'c.name as customer_name', 'c.customer_number', 'b.name as branch_name', 'i.invoice_number as original_invoice_number', 'u.name as creator_name')
            ->first();
        abort_unless($note, 404, 'Credit note not found.');
        $note->lines = DB::table('sales_credit_note_lines')->where('sales_credit_note_id', $id)->orderBy('line_number')->get();

        return $note;
    }

    /** Original invoice lines annotated with already-returned/returnable quantities — feeds the "Create Credit Note" UI (§33). */
    public function returnableLines(int $tenantId, int $invoiceId): array
    {
        $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first();
        abort_unless($invoice, 404, 'Sales invoice not found.');
        $lines = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->orderBy('line_number')->get();
        $products = DB::table('products')->whereIn('id', $lines->pluck('product_id'))->get(['id', 'is_stock_tracked', 'inventory_controlled'])->keyBy('id');

        return $lines->map(function (object $line) use ($tenantId, $products): array {
            $originalMilli = $this->milli($line->quantity);
            $returnedMilli = $this->returnedQuantityMilli($tenantId, (int) $line->id);
            $returnableMilli = max(0, $originalMilli - $returnedMilli);
            $product = $products->get((int) $line->product_id);

            return [
                'originalSalesInvoiceLineId' => (int) $line->id, 'productId' => (int) $line->product_id, 'productName' => $line->product_name, 'productSku' => $line->product_sku,
                'originalQuantity' => $line->quantity, 'alreadyReturned' => $this->milliDecimal($returnedMilli), 'returnable' => $this->milliDecimal($returnableMilli),
                'unitPrice' => $line->unit_price, 'taxRate' => $line->tax_rate,
                'isStockTracked' => $product ? ((bool) $product->is_stock_tracked || (bool) $product->inventory_controlled) : false,
            ];
        })->values()->all();
    }

    /** Cumulative already-returned quantity (milli-units), posted credit notes only. Callers needing the authoritative figure must lock the original `sales_invoice_lines` row first (see SalesCreditNotePostingService) — this method itself takes no lock. */
    public function returnedQuantityMilli(int $tenantId, int $originalLineId): int
    {
        return DB::table('sales_credit_note_lines as l')->join('sales_credit_notes as n', 'n.id', '=', 'l.sales_credit_note_id')
            ->where('l.tenant_id', $tenantId)->where('l.original_sales_invoice_line_id', $originalLineId)->where('n.status', 'posted')
            ->pluck('l.quantity')->reduce(fn (int $total, mixed $qty): int => $total + $this->milli($qty), 0);
    }

    /** @return array<int, array<string, mixed>> */
    private function pricedLines(int $tenantId, int $invoiceId, array $input): array
    {
        if ($input === []) {
            throw ValidationException::withMessages(['lines' => 'At least one credited line is required.']);
        }
        $lines = [];
        foreach ($input as $index => $line) {
            $originalLine = DB::table('sales_invoice_lines')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoiceId)->where('id', (int) ($line['originalSalesInvoiceLineId'] ?? 0))->first();
            if (! $originalLine) {
                throw ValidationException::withMessages(["lines.{$index}.originalSalesInvoiceLineId" => 'Select a line belonging to the original invoice.']);
            }
            $creditQtyMilli = $this->quantityMilli($line['quantity'] ?? null, "lines.{$index}.quantity");
            $originalMilli = $this->milli($originalLine->quantity);
            $returnedMilli = $this->returnedQuantityMilli($tenantId, (int) $originalLine->id);
            $returnableMilli = $originalMilli - $returnedMilli;
            if ($creditQtyMilli > $returnableMilli) {
                throw ValidationException::withMessages(["lines.{$index}.quantity" => 'Credited quantity exceeds the returnable balance of '.$this->milliDecimal(max(0, $returnableMilli)).'.']);
            }
            $product = DB::table('products')->where('tenant_id', $tenantId)->where('id', $originalLine->product_id)->first();
            $tracked = $product && ((bool) $product->is_stock_tracked || (bool) $product->inventory_controlled);
            $restock = (bool) ($line['restock'] ?? false);
            if ($restock && ! $tracked) {
                throw ValidationException::withMessages(["lines.{$index}.restock" => 'Only inventory-tracked lines can be restocked.']);
            }
            // Original price/tax basis (§12/§18) — the frozen unit_price and
            // tax_rate from the original line, never the current product
            // price or today's tax configuration.
            $unit = Money::cents($originalLine->unit_price);
            $rate = $this->rateMicro($originalLine->tax_rate);
            $subtotal = intdiv(($unit * $creditQtyMilli) + 500, 1000);
            $tax = intdiv(($subtotal * $rate) + 500000, 1000000);
            $lines[] = [
                'original_sales_invoice_line_id' => $originalLine->id, 'product_id' => $originalLine->product_id,
                'product_name' => $originalLine->product_name, 'product_sku' => $originalLine->product_sku,
                'quantity' => $this->milliDecimal($creditQtyMilli), 'unit_price' => Money::decimal($unit), 'tax_rate' => $this->rateDecimal($rate),
                'subtotal' => Money::decimal($subtotal), 'tax_total' => Money::decimal($tax), 'total' => Money::decimal($subtotal + $tax),
                'restock' => $restock, '_subtotal' => $subtotal, '_tax' => $tax,
            ];
        }

        return $lines;
    }

    private function replaceLines(int $tenantId, int $creditNoteId, array $lines): void
    {
        foreach ($lines as $index => $line) {
            unset($line['_subtotal'], $line['_tax']);
            DB::table('sales_credit_note_lines')->insert($line + ['tenant_id' => $tenantId, 'sales_credit_note_id' => $creditNoteId, 'line_number' => $index + 1, 'created_at' => now(), 'updated_at' => now()]);
        }
    }

    private function totals(array $lines): array
    {
        $subtotal = array_sum(array_column($lines, '_subtotal'));
        $tax = array_sum(array_column($lines, '_tax'));

        return ['subtotal' => $subtotal, 'tax' => $tax, 'total' => $subtotal + $tax];
    }

    private function quantityMilli(mixed $value, string $field): int
    {
        if (! preg_match('/^(\d+)(?:\.(\d+))?$/', trim((string) $value), $matches)) {
            throw ValidationException::withMessages([$field => 'Quantity must use no more than three decimal places.']);
        }
        $milli = ((int) $matches[1] * 1000) + (int) str_pad(substr($matches[2] ?? '', 0, 3), 3, '0');
        if ($milli < 1) {
            throw ValidationException::withMessages([$field => 'Quantity must be greater than zero.']);
        }

        return $milli;
    }

    private function milli(mixed $value): int
    {
        $v = trim((string) $value);
        preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m);

        return ((int) ($m[1] ?? 0) * 1000) + (int) str_pad(substr($m[2] ?? '', 0, 3), 3, '0');
    }

    private function milliDecimal(int $milli): string { return number_format($milli / 1000, 3, '.', ''); }
    private function rateMicro(mixed $value): int { $v = trim((string) $value); if (! preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m)) return 0; return ((int) $m[1] * 1000000) + (int) str_pad(substr($m[2] ?? '', 0, 6), 6, '0'); }
    private function rateDecimal(int $micro): string { return number_format($micro / 1000000, 6, '.', ''); }
}
