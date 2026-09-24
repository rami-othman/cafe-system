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
    public function preview(int $tenantId, int $invoiceId, ?array $directSettlement = null): array
    {
        $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first();
        abort_unless($invoice, 404, 'Sales invoice not found.');
        if ($invoice->status !== 'draft') throw ValidationException::withMessages(['status' => 'Only a draft sales invoice can be previewed for posting.']);
        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $invoice->customer_id)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $customer) throw ValidationException::withMessages(['customerId' => 'Select an active customer.']);
        if ($customer->is_walk_in && ! $directSettlement) throw ValidationException::withMessages(['payment' => 'العميل النقدي يحتاج إلى دفع كامل ومصدر دفع قبل معاينة الترحيل.']);
        if (! $customer->is_walk_in && $directSettlement) throw ValidationException::withMessages(['payment' => 'الفاتورة الآجلة تستخدم مسار الذمم القائم.']);
        $this->periods->assertPostingAllowed($tenantId, $invoice->invoice_date);
        $lines = DB::table('sales_invoice_lines')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoiceId)->orderBy('line_number')->get();
        if ($lines->isEmpty()) throw ValidationException::withMessages(['lines' => 'A sales invoice requires at least one line before posting.']);
        $charges = DB::table('sales_invoice_charges')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoiceId)->orderBy('sort_order')->get();
        $totals = $this->snapshotTotals($invoice, $lines->all(), $charges->all());
        if (Money::cents($invoice->subtotal) !== $totals['subtotal'] || Money::cents($invoice->discount_total) !== $totals['discount'] || Money::cents($invoice->tax_total) !== $totals['tax'] || Money::cents($invoice->total) !== $totals['total']) throw ValidationException::withMessages(['totals' => 'The stored invoice totals no longer match its immutable line snapshots.']);
        $accounts = $this->accounts->postingAccounts($tenantId, ! $customer->is_walk_in);
        $costs = $this->inventory->preview($tenantId, $invoice, $lines);
        $cogs = array_sum(array_map(fn (array $line): int => $line['cogsCents'], $costs));
        $details = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', array_values($accounts))->get(['id', 'code', 'name_ar', 'name_en'])->keyBy('code');
        $account = fn (string $code): array => ['id' => (int) $details[$code]->id, 'code' => $code, 'name' => $details[$code]->name_ar ?: $details[$code]->name_en];
        $inventory = [];
        foreach ($costs as $lineId => $cost) foreach ($cost['movements'] as $movement) $inventory[] = ['lineId' => (int) $lineId, 'materialId' => $movement['materialId'], 'materialName' => $movement['materialName'], 'recipeQuantity' => $movement['recipeQuantity'], 'recipeUnit' => $movement['recipeUnit'], 'quantityToConsume' => \App\Support\InventoryDecimal::quantity($movement['quantity']), 'baseUnit' => $movement['baseUnit'], 'warehouseId' => $movement['warehouseId'], 'warehouseName' => $movement['warehouseName'], 'unitCost' => \App\Support\InventoryDecimal::unitCost($movement['unitCostCents']), 'estimatedCost' => Money::decimal($movement['costCents'])];
        return ['invoice' => ['subtotal' => Money::decimal($totals['subtotal']), 'discount' => Money::decimal($totals['discount']), 'charges' => Money::decimal($totals['charges']), 'adjustment' => Money::decimal($totals['adjustment']), 'tax' => Money::decimal($totals['tax']), 'total' => Money::decimal($totals['total'])], 'accounting' => ['accountsReceivable' => $customer->is_walk_in ? null : $account($accounts['accountsReceivable']), 'settlement' => $customer->is_walk_in ? ['code' => $directSettlement['accountCode'], 'financialLocationId' => $directSettlement['locationId']] : null, 'revenue' => $account($accounts['revenue']), 'additionalChargeRevenue' => $account($accounts['additionalChargeRevenue']), 'manualAdjustment' => $account($accounts['manualAdjustment']), 'taxPayable' => $account($accounts['taxPayable']), 'cogs' => $account($accounts['cogs']), 'inventory' => $account($accounts['inventory']), 'accountsReceivableDebit' => $customer->is_walk_in ? '0.00' : Money::decimal($totals['total']), 'settlementDebit' => $customer->is_walk_in ? Money::decimal($totals['total']) : '0.00', 'revenueCredit' => Money::decimal($totals['subtotal']), 'additionalChargeRevenueCredit' => Money::decimal($totals['charges']), 'manualAdjustmentDebit' => Money::decimal(max(0, -$totals['adjustment'])), 'manualAdjustmentCredit' => Money::decimal(max(0, $totals['adjustment'])), 'taxCredit' => Money::decimal($totals['tax'])], 'inventory' => $inventory, 'cogs' => ['totalEstimated' => Money::decimal($cogs), 'cogsDebit' => Money::decimal($cogs), 'inventoryCredit' => Money::decimal($cogs)], 'warnings' => []];
    }

    public function post(Request $request, int $tenantId, int $invoiceId, int $actorId, array $data, ?array $directSettlement = null): object
    {
        return DB::transaction(function () use ($request, $tenantId, $invoiceId, $actorId, $data, $directSettlement): object {
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
            if (! $customer) throw ValidationException::withMessages(['customerId' => 'Select an active customer.']);
            if ($customer->is_walk_in && ! $directSettlement) throw ValidationException::withMessages(['payment' => 'العميل النقدي يحتاج إلى دفع كامل ومصدر دفع عند الترحيل.']);
            if (! $customer->is_walk_in && $directSettlement) throw ValidationException::withMessages(['payment' => 'الفاتورة الآجلة تستخدم مسار الذمم القائم.']);
            $this->periods->assertPostingAllowed($tenantId, $invoice->invoice_date);
            $lines = DB::table('sales_invoice_lines')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoiceId)->orderBy('line_number')->get();
            if ($lines->isEmpty()) throw ValidationException::withMessages(['lines' => 'A sales invoice requires at least one line before posting.']);
            $charges = DB::table('sales_invoice_charges')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoiceId)->orderBy('sort_order')->get();
            $totals = $this->snapshotTotals($invoice, $lines->all(), $charges->all());
            if (Money::cents($invoice->subtotal) !== $totals['subtotal'] || Money::cents($invoice->discount_total) !== $totals['discount'] || Money::cents($invoice->tax_total) !== $totals['tax'] || Money::cents($invoice->total) !== $totals['total']) {
                throw ValidationException::withMessages(['totals' => 'The stored invoice totals no longer match its immutable line snapshots.']);
            }
            $accounts = $this->accounts->postingAccounts($tenantId, ! $customer->is_walk_in);
            $costs = $this->inventory->consume($request, $tenantId, $invoice, $lines, $actorId);
            $cogs = array_sum(array_map(fn (array $line): int => $line['cogsCents'], $costs));
            $journalLines = [$customer->is_walk_in
                ? ['accountCode' => $directSettlement['accountCode'], 'debit' => Money::decimal($totals['total']), 'financialLocationId' => $directSettlement['locationId'], 'description' => 'Direct sale collected']
                : ['accountCode' => $accounts['accountsReceivable'], 'debit' => Money::decimal($totals['total']), 'description' => 'Accounts Receivable']];
            if ($totals['subtotal'] > 0) $journalLines[] = ['accountCode' => $accounts['revenue'], 'credit' => Money::decimal($totals['subtotal']), 'description' => 'Sales Revenue'];
            if ($totals['charges'] > 0) $journalLines[] = ['accountCode' => $accounts['additionalChargeRevenue'], 'credit' => Money::decimal($totals['charges']), 'description' => 'Customer-billed charges revenue'];
            if ($totals['adjustment'] > 0) $journalLines[] = ['accountCode' => $accounts['manualAdjustment'], 'credit' => Money::decimal($totals['adjustment']), 'description' => 'Commercial adjustment'];
            if ($totals['adjustment'] < 0) $journalLines[] = ['accountCode' => $accounts['manualAdjustment'], 'debit' => Money::decimal(-$totals['adjustment']), 'description' => 'Commercial adjustment'];
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
            if (! $customer->is_walk_in) DB::table('customer_receivables')->insert(['tenant_id' => $tenantId, 'customer_id' => $invoice->customer_id, 'sales_invoice_id' => $invoiceId, 'journal_entry_id' => $journalId, 'original_amount' => Money::decimal($totals['total']), 'due_date' => $invoice->due_date, 'posted_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
            DB::table('sales_invoice_postings')->insert(['tenant_id' => $tenantId, 'sales_invoice_id' => $invoiceId, 'idempotency_key' => $data['idempotencyKey'], 'request_fingerprint' => $fingerprint, 'journal_entry_id' => $journalId, 'posted_by' => $actorId, 'created_at' => $now, 'updated_at' => $now]);
            DB::table('sales_invoices')->where('id', $invoiceId)->update(['status' => 'posted', 'posted_journal_entry_id' => $journalId, 'posted_at' => $now, 'updated_by' => $actorId, 'updated_at' => $now]);
            $this->audit->record($request, $tenantId, 'sales.invoice.posted', 'sales_invoice', $invoiceId, ['status' => 'draft'], ['invoiceNumber' => $invoice->invoice_number, 'journalEntryId' => $journalId, 'receivableAmount' => $customer->is_walk_in ? '0.00' : Money::decimal($totals['total']), 'cogs' => Money::decimal($cogs)], $invoice->branch_id, $actorId);
            return DB::table('sales_invoices')->where('id', $invoiceId)->first();
        }, 3);
    }

    /** @param array<int, object> $lines @param array<int, object> $charges */
    private function snapshotTotals(object $invoice, array $lines, array $charges): array
    {
        $gross = 0; $lineDiscount = 0; $lineNet = 0;
        foreach ($lines as $line) {
            $quantity = $this->milli($line->quantity); $unit = Money::cents($line->unit_price); $lineDiscount = Money::cents($line->discount_total);
            $lineGross = intdiv(($unit * $quantity) + 500, 1000); $lineNetAmount = $lineGross - $lineDiscount;
            if ($lineDiscount < 0 || $lineDiscount > $lineGross || Money::cents($line->line_subtotal) !== $lineGross || Money::cents($line->discount_amount) !== $lineDiscount || Money::cents($line->subtotal) !== $lineNetAmount) throw ValidationException::withMessages(['totals' => 'A sales line snapshot is invalid.']);
            $gross += $lineGross; $lineNet += $lineNetAmount;
        }
        $lineDiscountTotal = $gross - $lineNet; $invoiceDiscount = Money::cents($invoice->invoice_discount_total); $subtotal = $lineNet - $invoiceDiscount;
        $chargeTotal = 0; $taxableCharges = 0; foreach ($charges as $charge) { $amount = Money::cents($charge->amount); if ($amount < 0) throw ValidationException::withMessages(['totals' => 'A sales charge snapshot is invalid.']); $chargeTotal += $amount; if ($charge->taxable) $taxableCharges += $amount; }
        $rate = $this->rate($invoice->tax_rate); $taxable = $subtotal + $taxableCharges; $tax = intdiv(($taxable * $rate) + 500000, 1000000); $adjustment = Money::cents($invoice->manual_adjustment); $total = $subtotal + $chargeTotal + $tax + $adjustment;
        if ($subtotal < 0 || $total < 0 || Money::cents($invoice->gross_subtotal) !== $gross || Money::cents($invoice->line_discount_total) !== $lineDiscountTotal || Money::cents($invoice->subtotal) !== $subtotal || Money::cents($invoice->discount_total) !== $lineDiscountTotal + $invoiceDiscount || Money::cents($invoice->additional_charges_total) !== $chargeTotal || Money::cents($invoice->taxable_amount) !== $taxable || Money::cents($invoice->tax_total) !== $tax || Money::cents($invoice->total) !== $total) throw ValidationException::withMessages(['totals' => 'The stored invoice totals no longer match its immutable snapshots.']);
        return ['subtotal' => $subtotal, 'discount' => $lineDiscountTotal + $invoiceDiscount, 'charges' => $chargeTotal, 'adjustment' => $adjustment, 'tax' => $tax, 'total' => $total];
    }
    private function milli(mixed $value): int { $v = trim((string) $value); if (! preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m)) throw ValidationException::withMessages(['quantity' => 'Invalid line quantity.']); return ((int) $m[1] * 1000) + (int) str_pad(substr($m[2] ?? '', 0, 3), 3, '0'); }
    private function rate(mixed $value): int { $v = trim((string) $value); if (! preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m)) return 0; return ((int) $m[1] * 1000000) + (int) str_pad(substr($m[2] ?? '', 0, 6), 6, '0'); }
}
