<?php

namespace App\Services;

use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class SalesInvoiceService
{
    public function create(int $tenantId, int $actorId, array $data): object
    {
        return DB::transaction(function () use ($tenantId, $actorId, $data): object {
            DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->firstOrFail();
            $fingerprint = IdempotencyFingerprint::from($data);
            if (! empty($data['idempotencyKey'])) {
                $existing = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('idempotency_key', $data['idempotencyKey'])->first();
                if ($existing) {
                    if ($existing->request_fingerprint !== $fingerprint) throw ValidationException::withMessages(['idempotencyKey' => 'This idempotency key was already used for a different request.']);
                    return $existing;
                }
            }
            $this->assertAccountsReceivableMapping($tenantId);
            $customer = $this->customer($tenantId, (int) $data['customerId']);
            $lines = $this->pricedLines($tenantId, $data['lines']);
            $totals = $this->totals($lines);
            $invoiceDate = CarbonImmutable::parse($data['invoiceDate'])->toDateString();
            $dueDate = array_key_exists('dueDate', $data) && $data['dueDate'] ? CarbonImmutable::parse($data['dueDate'])->toDateString() : CarbonImmutable::parse($invoiceDate)->addDays((int) $customer->default_credit_terms_days)->toDateString();
            $year = CarbonImmutable::parse($invoiceDate)->year;
            $sequence = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('invoice_number', 'like', "SI-{$year}-%")->count() + 1;
            $id = DB::table('sales_invoices')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $data['branchId'], 'customer_id' => $customer->id,
                'invoice_number' => sprintf('SI-%d-%06d', $year, $sequence), 'invoice_date' => $invoiceDate, 'due_date' => $dueDate,
                'currency_code' => 'SYP', 'reference' => $data['reference'] ?? null, 'notes' => $data['notes'] ?? null, 'status' => 'draft',
                'tax_rate' => $totals['rate'], 'subtotal' => Money::decimal($totals['subtotal']), 'discount_total' => '0.00',
                'tax_total' => Money::decimal($totals['tax']), 'total' => Money::decimal($totals['total']),
                'idempotency_key' => $data['idempotencyKey'] ?? null, 'request_fingerprint' => $fingerprint,
                'created_by' => $actorId, 'updated_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
            ]);
            $this->replaceLines($tenantId, $id, $lines);
            return $this->find($tenantId, $id);
        });
    }

    public function update(int $tenantId, int $invoiceId, int $actorId, array $data): object
    {
        return DB::transaction(function () use ($tenantId, $invoiceId, $actorId, $data): object {
            $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->lockForUpdate()->first();
            abort_unless($invoice, 404, 'Sales invoice not found.');
            if ($invoice->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only draft sales invoices can be edited.']);
            $customer = $this->customer($tenantId, (int) ($data['customerId'] ?? $invoice->customer_id));
            $lines = array_key_exists('lines', $data) ? $this->pricedLines($tenantId, $data['lines']) : $this->currentLines($invoiceId);
            $totals = $this->totals($lines);
            $invoiceDate = array_key_exists('invoiceDate', $data) ? CarbonImmutable::parse($data['invoiceDate'])->toDateString() : $invoice->invoice_date;
            $dueDate = array_key_exists('dueDate', $data) ? ($data['dueDate'] ? CarbonImmutable::parse($data['dueDate'])->toDateString() : CarbonImmutable::parse($invoiceDate)->addDays((int) $customer->default_credit_terms_days)->toDateString()) : $invoice->due_date;
            $values = ['customer_id' => $customer->id, 'invoice_date' => $invoiceDate, 'due_date' => $dueDate, 'tax_rate' => $totals['rate'], 'subtotal' => Money::decimal($totals['subtotal']), 'tax_total' => Money::decimal($totals['tax']), 'total' => Money::decimal($totals['total']), 'updated_by' => $actorId, 'updated_at' => now()];
            foreach (['branchId' => 'branch_id', 'reference' => 'reference', 'notes' => 'notes'] as $input => $column) if (array_key_exists($input, $data)) $values[$column] = $data[$input];
            DB::table('sales_invoices')->where('id', $invoiceId)->update($values);
            if (array_key_exists('lines', $data)) {
                DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->delete();
                $this->replaceLines($tenantId, $invoiceId, $lines);
            }
            return $this->find($tenantId, $invoiceId);
        });
    }

    public function cancel(int $tenantId, int $invoiceId, int $actorId, ?string $reason): object
    {
        $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first();
        abort_unless($invoice, 404, 'Sales invoice not found.');
        if ($invoice->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only draft sales invoices can be cancelled.']);
        DB::table('sales_invoices')->where('id', $invoiceId)->update(['status' => 'cancelled', 'cancelled_by' => $actorId, 'cancelled_at' => now(), 'cancellation_reason' => $reason, 'updated_by' => $actorId, 'updated_at' => now()]);
        return $this->find($tenantId, $invoiceId);
    }

    public function find(int $tenantId, int $invoiceId): object
    {
        $invoice = DB::table('sales_invoices as i')->join('customers as c', 'c.id', '=', 'i.customer_id')->join('branches as b', 'b.id', '=', 'i.branch_id')->leftJoin('users as u', 'u.id', '=', 'i.created_by')
            ->where('i.tenant_id', $tenantId)->where('i.id', $invoiceId)->select('i.*', 'c.name as customer_name', 'c.customer_number', 'b.name as branch_name', 'u.name as creator_name')->first();
        abort_unless($invoice, 404, 'Sales invoice not found.');
        $invoice->lines = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->orderBy('line_number')->get();
        return $invoice;
    }

    private function customer(int $tenantId, int $id): object
    {
        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $id)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $customer) throw ValidationException::withMessages(['customerId' => 'Select an active customer belonging to this tenant.']);
        return $customer;
    }

    /** Phase 1 does not post AR, but it refuses to create documents for a tenant whose future AR configuration is invalid. */
    private function assertAccountsReceivableMapping(int $tenantId): void
    {
        $mapping = DB::table('sales_account_mappings as m')
            ->join('financial_accounts as a', 'a.id', '=', 'm.financial_account_id')
            ->where('m.tenant_id', $tenantId)->where('m.mapping_key', 'sales.accounts_receivable')
            ->where('a.tenant_id', $tenantId)->where('a.is_active', true)->whereNull('a.deleted_at')
            ->select('a.account_group', 'a.normal_balance')->first();
        if (! $mapping || $mapping->account_group !== 'assets' || $mapping->normal_balance !== 'debit') {
            throw ValidationException::withMessages(['accountsReceivable' => 'Configure an active tenant Accounts Receivable asset account before creating sales invoices.']);
        }
    }

    private function pricedLines(int $tenantId, array $input): array
    {
        if ($input === []) throw ValidationException::withMessages(['lines' => 'At least one product line is required.']);
        $rate = $this->tenantTaxRateMicro($tenantId);
        $lines = [];
        foreach ($input as $index => $line) {
            $product = DB::table('products')->where('tenant_id', $tenantId)->where('id', (int) ($line['productId'] ?? 0))->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $product) throw ValidationException::withMessages(["lines.{$index}.productId" => 'Select an active product belonging to this tenant.']);
            $variantId = $line['variantId'] ?? null;
            if ($variantId !== null) {
                $variant = DB::table('product_variants')->where('tenant_id', $tenantId)->where('id', (int) $variantId)->where('product_id', $product->id)->where('is_active', true)->whereNull('deleted_at')->first();
                if (! $variant) throw ValidationException::withMessages(["lines.{$index}.variantId" => 'Select an active variant belonging to the selected product.']);
                $variantId = (int) $variant->id;
            } elseif ((bool) $product->is_stock_tracked || (bool) $product->inventory_controlled) {
                // Default is chosen at draft creation and persisted. It is not
                // re-resolved at posting time, so later catalog changes cannot
                // silently switch the consumed recipe.
                $variantId = DB::table('product_variants')->where('tenant_id', $tenantId)->where('product_id', $product->id)->where('is_active', true)->where('is_default', true)->whereNull('deleted_at')->value('id');
                if (! $variantId) throw ValidationException::withMessages(["lines.{$index}.variantId" => 'Inventory-tracked products require an active sellable variant.']);
            }
            $qty = $this->quantityMilli($line['quantity'] ?? null, "lines.{$index}.quantity");
            $unit = Money::cents($product->price, "lines.{$index}.unitPrice");
            $subtotal = intdiv(($unit * $qty) + 500, 1000);
            $tax = intdiv(($subtotal * $rate) + 500000, 1000000);
            $lines[] = ['product_id' => $product->id, 'product_variant_id' => $variantId, 'product_name' => $product->name_ar ?: $product->name, 'product_sku' => $product->sku, 'quantity' => $this->milliDecimal($qty), 'unit_price' => Money::decimal($unit), 'discount_total' => '0.00', 'tax_rate' => $this->rateDecimal($rate), 'subtotal' => Money::decimal($subtotal), 'tax_total' => Money::decimal($tax), 'total' => Money::decimal($subtotal + $tax), '_subtotal' => $subtotal, '_tax' => $tax, '_rate' => $rate];
        }
        return $lines;
    }

    private function currentLines(int $invoiceId): array
    {
        return DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoiceId)->orderBy('line_number')->get()->map(fn (object $line): array => ['product_id' => $line->product_id, 'product_variant_id' => $line->product_variant_id, 'product_name' => $line->product_name, 'product_sku' => $line->product_sku, 'quantity' => $line->quantity, 'unit_price' => $line->unit_price, 'discount_total' => $line->discount_total, 'tax_rate' => $line->tax_rate, 'subtotal' => $line->subtotal, 'tax_total' => $line->tax_total, 'total' => $line->total, '_subtotal' => Money::cents($line->subtotal), '_tax' => Money::cents($line->tax_total), '_rate' => $this->rateMicro($line->tax_rate)])->all();
    }

    private function replaceLines(int $tenantId, int $invoiceId, array $lines): void
    {
        foreach ($lines as $index => $line) {
            unset($line['_subtotal'], $line['_tax'], $line['_rate']);
            DB::table('sales_invoice_lines')->insert($line + ['tenant_id' => $tenantId, 'sales_invoice_id' => $invoiceId, 'line_number' => $index + 1, 'created_at' => now(), 'updated_at' => now()]);
        }
    }

    private function totals(array $lines): array
    {
        $subtotal = array_sum(array_column($lines, '_subtotal')); $tax = array_sum(array_column($lines, '_tax'));
        return ['subtotal' => $subtotal, 'tax' => $tax, 'total' => $subtotal + $tax, 'rate' => $this->rateDecimal((int) ($lines[0]['_rate'] ?? 0))];
    }

    private function quantityMilli(mixed $value, string $field): int
    {
        if (! preg_match('/^(\d+)(?:\.(\d+))?$/', trim((string) $value), $matches)) throw ValidationException::withMessages([$field => 'Quantity must use no more than three decimal places.']);
        $fraction = $matches[2] ?? '';
        if (strlen($fraction) > 3 && trim(substr($fraction, 3), '0') !== '') throw ValidationException::withMessages([$field => 'Quantity must use no more than three decimal places.']);
        $milli = ((int) $matches[1] * 1000) + (int) str_pad(substr($fraction, 0, 3), 3, '0');
        if ($milli < 1) throw ValidationException::withMessages([$field => 'Quantity must be greater than zero.']);
        return $milli;
    }
    private function milliDecimal(int $milli): string { return number_format($milli / 1000, 3, '.', ''); }
    private function tenantTaxRateMicro(int $tenantId): int { return $this->rateMicro(DB::table('tenants')->where('id', $tenantId)->value('tax_rate') ?? '0'); }
    private function rateMicro(mixed $value): int { $v = trim((string) $value); if (! preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m)) return 0; return ((int) $m[1] * 1000000) + (int) str_pad(substr($m[2] ?? '', 0, 6), 6, '0'); }
    private function rateDecimal(int $micro): string { return number_format($micro / 1000000, 6, '.', ''); }
}
