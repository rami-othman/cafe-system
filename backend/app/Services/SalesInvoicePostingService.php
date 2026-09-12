<?php

namespace App\Services;

use App\Services\AccountingPeriodGuard;
use App\Support\IdempotencyFingerprint;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Small aggregate coordinator: it delegates WAC/movements and journal primitives to their existing owners. */
final class SalesInvoicePostingService
{
    public function __construct(
        private readonly SalesAccountResolver $accounts,
        private readonly AccountingPeriodGuard $periods,
        private readonly SalesInvoiceInventoryConsumptionService $inventory,
        private readonly AccountingPostingService $posting,
        private readonly OperationalAuditService $audit,
    ) {}

    /**
     * Read-only posting projection. It deliberately calls the same totals,
     * account resolver and inventory consumption planner as `post()`.
     */
    public function preview(int $tenantId, int $invoiceId): array
    {
        $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first();
        abort_unless($invoice, 404, 'Sales invoice not found.');
        if ($invoice->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only a draft sales invoice can be previewed for posting.']);
        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $invoice->customer_id)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $customer || $customer->is_walk_in) throw ValidationException::withMessages(['customerId' => 'A posted accrual invoice requires an active registered customer.']);
        $this->periods->assertPostingAllowed($tenantId, $invoice->invoice_date);
        $lines = DB::table('sales_invoice_lines')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoiceId)->orderBy('line_number')->get();
        if ($lines->isEmpty()) throw ValidationException::withMessages(['lines' => 'A sales invoice requires at least one line before posting.']);
        $totals = $this->snapshotTotals($lines->all());
        if (Money::cents($invoice->subtotal) !== $totals['subtotal'] || Money::cents($invoice->discount_total) !== $totals['discount'] || Money::cents($invoice->tax_total) !== $totals['tax'] || Money::cents($invoice->total) !== $totals['total']) throw ValidationException::withMessages(['totals' => 'The stored invoice totals no longer match its immutable line snapshots.']);
        $accounts = $this->accounts->postingAccounts($tenantId);
        $costs = $this->inventory->preview($tenantId, $invoice, $lines);
        $cogs = array_sum(array_map(fn (array $line): int => $line['cogsCents'], $costs));
        $details = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', array_values($accounts))->get(['id', 'code', 'name_ar', 'name_en'])->keyBy('code');
        $account = fn (string $code): array => ['id' => (int) $details[$code]->id, 'code' => $code, 'name' => $details[$code]->name_ar ?: $details[$code]->name_en];
        $inventory = [];
        foreach ($costs as $lineId => $cost) foreach ($cost['movements'] as $movement) $inventory[] = ['lineId' => (int) $lineId, 'materialId' => $movement['materialId'], 'materialName' => $movement['materialName'], 'recipeQuantity' => $movement['recipeQuantity'], 'recipeUnit' => $movement['recipeUnit'], 'quantityToConsume' => \App\Support\InventoryDecimal::quantity($movement['quantity']), 'baseUnit' => $movement['baseUnit'], 'warehouseId' => $movement['warehouseId'], 'warehouseName' => $movement['warehouseName'], 'unitCost' => \App\Support\InventoryDecimal::unitCost($movement['unitCostCents']), 'estimatedCost' => Money::decimal($movement['costCents'])];
        return ['invoice' => ['subtotal' => Money::decimal($totals['subtotal']), 'discount' => Money::decimal($totals['discount']), 'tax' => Money::decimal($totals['tax']), 'total' => Money::decimal($totals['total'])], 'accounting' => ['accountsReceivable' => $account($accounts['accountsReceivable']), 'revenue' => $account($accounts['revenue']), 'taxPayable' => $account($accounts['taxPayable']), 'cogs' => $account($accounts['cogs']), 'inventory' => $account($accounts['inventory']), 'accountsReceivableDebit' => Money::decimal($totals['total']), 'revenueCredit' => Money::decimal($totals['subtotal']), 'taxCredit' => Money::decimal($totals['tax'])], 'inventory' => $inventory, 'cogs' => ['totalEstimated' => Money::decimal($cogs), 'cogsDebit' => Money::decimal($cogs), 'inventoryCredit' => Money::decimal($cogs)], 'warnings' => []];
    }

    public function post(Request $request, int $tenantId, int $invoiceId, int $actorId, array $data): object
    {
        return DB::transaction(function () use ($request, $tenantId, $invoiceId, $actorId, $data): object {
            $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->lockForUpdate()->first();
            abort_unless($invoice, 404, 'Sales invoice not found.');
            $fingerprint = IdempotencyFingerprint::from($data);
            $existing = DB::table('sales_invoice_postings')->where('tenant_id', $tenantId)->where('idempotency_key', $data['idempotencyKey'])->lockForUpdate()->first();
            if ($existing) {
                if ((int) $existing->sales_invoice_id !== $invoiceId || ! hash_equals($existing->request_fingerprint, $fingerprint)) throw ValidationException::withMessages(['idempotencyKey' => 'This posting key was already used for a different request.']);
                return $invoice;
            }
            if ($invoice->status === 'posted') return $invoice;
            if ($invoice->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only a draft sales invoice can be posted.']);

            $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $invoice->customer_id)->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $customer || $customer->is_walk_in) throw ValidationException::withMessages(['customerId' => 'A posted accrual invoice requires an active registered customer.']);
            $this->periods->assertPostingAllowed($tenantId, $invoice->invoice_date);
            $lines = DB::table('sales_invoice_lines')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoiceId)->orderBy('line_number')->get();
            if ($lines->isEmpty()) throw ValidationException::withMessages(['lines' => 'A sales invoice requires at least one line before posting.']);
            $totals = $this->snapshotTotals($lines->all());
            if (Money::cents($invoice->subtotal) !== $totals['subtotal'] || Money::cents($invoice->discount_total) !== $totals['discount'] || Money::cents($invoice->tax_total) !== $totals['tax'] || Money::cents($invoice->total) !== $totals['total']) {
                throw ValidationException::withMessages(['totals' => 'The stored invoice totals no longer match its immutable line snapshots.']);
            }
            $accounts = $this->accounts->postingAccounts($tenantId);
            $costs = $this->inventory->consume($request, $tenantId, $invoice, $lines, $actorId);
            $cogs = array_sum(array_map(fn (array $line): int => $line['cogsCents'], $costs));
            $journalLines = [['accountCode' => $accounts['accountsReceivable'], 'debit' => Money::decimal($totals['total']), 'description' => 'Accounts Receivable']];
            if ($totals['subtotal'] > 0) $journalLines[] = ['accountCode' => $accounts['revenue'], 'credit' => Money::decimal($totals['subtotal']), 'description' => 'Sales Revenue'];
            if ($totals['tax'] > 0) $journalLines[] = ['accountCode' => $accounts['taxPayable'], 'credit' => Money::decimal($totals['tax']), 'description' => 'Sales Tax Payable'];
            if ($cogs > 0) {
                $journalLines[] = ['accountCode' => $accounts['cogs'], 'debit' => Money::decimal($cogs), 'description' => 'Cost of Goods Sold'];
                $journalLines[] = ['accountCode' => $accounts['inventory'], 'credit' => Money::decimal($cogs), 'description' => 'Inventory Asset'];
            }
            $journalId = $this->posting->post($request, $tenantId, ['sourceType' => 'sales_invoice', 'sourceId' => $invoiceId, 'sourceEvent' => 'SALES_INVOICE_POSTED', 'branchId' => $invoice->branch_id, 'entryDate' => $invoice->invoice_date, 'description' => "Sales Invoice {$invoice->invoice_number}", 'lines' => $journalLines], $actorId);
            $now = now();
            foreach ($costs as $lineId => $cost) {
                $firstMovementId = $cost['movements'][0]['movementId'] ?? null;
                DB::table('sales_invoice_lines')->where('id', $lineId)->update(['inventory_movement_id' => $firstMovementId, 'cogs_total' => Money::decimal($cost['cogsCents']), 'updated_at' => $now]);
                foreach ($cost['movements'] as $movement) DB::table('sales_invoice_costs')->insert(['tenant_id' => $tenantId, 'sales_invoice_id' => $invoiceId, 'sales_invoice_line_id' => $lineId, 'inventory_movement_id' => $movement['movementId'], 'cost_amount' => Money::decimal($movement['costCents']), 'created_at' => $now, 'updated_at' => $now]);
            }
            DB::table('customer_receivables')->insert(['tenant_id' => $tenantId, 'customer_id' => $invoice->customer_id, 'sales_invoice_id' => $invoiceId, 'journal_entry_id' => $journalId, 'original_amount' => Money::decimal($totals['total']), 'due_date' => $invoice->due_date, 'posted_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
            DB::table('sales_invoice_postings')->insert(['tenant_id' => $tenantId, 'sales_invoice_id' => $invoiceId, 'idempotency_key' => $data['idempotencyKey'], 'request_fingerprint' => $fingerprint, 'journal_entry_id' => $journalId, 'posted_by' => $actorId, 'created_at' => $now, 'updated_at' => $now]);
            DB::table('sales_invoices')->where('id', $invoiceId)->update(['status' => 'posted', 'posted_journal_entry_id' => $journalId, 'posted_at' => $now, 'updated_by' => $actorId, 'updated_at' => $now]);
            $this->audit->record($request, $tenantId, 'sales.invoice.posted', 'sales_invoice', $invoiceId, ['status' => 'draft'], ['invoiceNumber' => $invoice->invoice_number, 'journalEntryId' => $journalId, 'receivableAmount' => Money::decimal($totals['total']), 'cogs' => Money::decimal($cogs)], $invoice->branch_id, $actorId);
            return DB::table('sales_invoices')->where('id', $invoiceId)->first();
        }, 3);
    }

    /** @param array<int, object> $lines @return array{subtotal:int,discount:int,tax:int,total:int} */
    private function snapshotTotals(array $lines): array
    {
        $subtotal = 0; $discount = 0; $tax = 0;
        foreach ($lines as $line) {
            $quantity = $this->milli($line->quantity); $unit = Money::cents($line->unit_price); $lineDiscount = Money::cents($line->discount_total);
            $base = intdiv(($unit * $quantity) + 500, 1000) - $lineDiscount; $rate = $this->rate($line->tax_rate); $lineTax = intdiv(($base * $rate) + 500000, 1000000);
            if (Money::cents($line->subtotal) !== $base || Money::cents($line->tax_total) !== $lineTax || Money::cents($line->total) !== $base + $lineTax) throw ValidationException::withMessages(['totals' => 'A sales line snapshot is invalid.']);
            $subtotal += $base; $discount += $lineDiscount; $tax += $lineTax;
        }
        return ['subtotal' => $subtotal, 'discount' => $discount, 'tax' => $tax, 'total' => $subtotal + $tax];
    }
    private function milli(mixed $value): int { $v = trim((string) $value); if (! preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m)) throw ValidationException::withMessages(['quantity' => 'Invalid line quantity.']); return ((int) $m[1] * 1000) + (int) str_pad(substr($m[2] ?? '', 0, 3), 3, '0'); }
    private function rate(mixed $value): int { $v = trim((string) $value); if (! preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m)) return 0; return ((int) $m[1] * 1000000) + (int) str_pad(substr($m[2] ?? '', 0, 6), 6, '0'); }
}
