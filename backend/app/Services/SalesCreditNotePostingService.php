<?php

namespace App\Services;

use App\Support\IdempotencyFingerprint;
use App\Support\InventoryDecimal;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Atomic Credit Note posting (docs/sales Phase 4 §21). Mirrors
 * SalesInvoicePostingService's shape: a read-only preview() shares the same
 * validation/computation as post(), which additionally writes the
 * inventory restock, the reversal journal and the customer-credit ledger
 * entry — all inside one transaction, or none of it happens.
 *
 * AR never goes negative (§9/§27/§28): the AR-reduction portion of a
 * Credit Note is capped at the original invoice's *current* outstanding
 * balance (itself already net of prior payments and prior credit notes —
 * see CustomerReceivableQueryService); any excess becomes unapplied
 * customer credit (CustomerCreditQueryService), fixed at posting time on
 * the credit note row itself so the figure never has to be recomputed
 * from history.
 */
final class SalesCreditNotePostingService
{
    public function __construct(
        private readonly SalesCreditNoteService $creditNotes,
        private readonly SalesAccountResolver $accounts,
        private readonly AccountingPeriodGuard $periods,
        private readonly AccountingPostingService $posting,
        private readonly CustomerReceivableQueryService $receivables,
        private readonly SalesInventoryMovementService $movements,
        private readonly OperationalAuditService $audit,
    ) {}

    public function preview(int $tenantId, int $creditNoteId): array
    {
        $plan = $this->computePlan($tenantId, $creditNoteId, lock: false);
        $accounts = $plan['accounts'];
        $details = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', array_values($accounts))->get(['id', 'code', 'name_ar', 'name_en'])->keyBy('code');
        $account = fn (string $code): array => ['id' => (int) $details[$code]->id, 'code' => $code, 'name' => $details[$code]->name_ar ?: $details[$code]->name_en];

        $lines = [];
        foreach ($plan['lineResults'] as $result) {
            $line = $result['line'];
            $restockPlan = $result['restockPlan'];
            $lines[] = [
                'lineId' => (int) $line->id, 'productName' => $line->product_name, 'quantity' => $line->quantity,
                'subtotal' => $line->subtotal, 'tax' => $line->tax_total, 'total' => $line->total, 'restock' => (bool) $line->restock,
                'cogsReversal' => $restockPlan ? Money::decimal($restockPlan['cogsCents']) : '0.00',
                'materials' => $restockPlan ? collect($restockPlan['materials'])->map(fn (array $m) => ['materialId' => $m['materialId'], 'quantity' => InventoryDecimal::quantity($m['quantity']), 'unit' => $m['baseUnit']])->values() : [],
            ];
        }

        return [
            'creditNote' => ['subtotal' => Money::decimal($plan['subtotalCents']), 'tax' => Money::decimal($plan['taxCents']), 'total' => Money::decimal($plan['totalCents'])],
            'accounting' => [
                'salesReturns' => $account($accounts['salesReturns']), 'taxPayable' => $account($accounts['taxPayable']),
                'accountsReceivable' => $account($accounts['accountsReceivable']), 'customerCredit' => $account($accounts['customerCredit']),
                'cogs' => $account($accounts['cogs']), 'inventory' => $account($accounts['inventory']),
                'salesReturnsDebit' => Money::decimal($plan['subtotalCents']), 'taxDebit' => Money::decimal($plan['taxCents']),
                'accountsReceivableCredit' => Money::decimal($plan['arReductionCents']), 'customerCreditCredit' => Money::decimal($plan['customerCreditCents']),
                'cogsReversalCredit' => Money::decimal($plan['cogsCents']), 'inventoryDebit' => Money::decimal($plan['cogsCents']),
            ],
            'invoiceImpact' => [
                'outstandingBefore' => Money::decimal($this->receivables->invoiceRemainingCents($tenantId, (int) $plan['invoice']->id)),
                'arReduction' => Money::decimal($plan['arReductionCents']), 'customerCreditCreated' => Money::decimal($plan['customerCreditCents']),
            ],
            'lines' => $lines,
            'warnings' => [],
        ];
    }

    public function post(Request $request, int $tenantId, int $creditNoteId, int $actorId, array $data): object
    {
        return DB::transaction(function () use ($request, $tenantId, $creditNoteId, $actorId, $data): object {
            $note = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('id', $creditNoteId)->lockForUpdate()->first();
            abort_unless($note, 404, 'Credit note not found.');
            $fingerprint = IdempotencyFingerprint::from($data);
            $existingPosting = DB::table('sales_credit_note_postings')->where('tenant_id', $tenantId)->where('idempotency_key', $data['idempotencyKey'])->lockForUpdate()->first();
            if ($existingPosting) {
                if ((int) $existingPosting->sales_credit_note_id !== $creditNoteId || ! hash_equals($existingPosting->request_fingerprint, $fingerprint)) {
                    throw ValidationException::withMessages(['idempotencyKey' => 'This posting key was already used for a different request.']);
                }

                return $this->creditNotes->find($tenantId, $creditNoteId);
            }
            if ($note->status === 'posted') {
                return $this->creditNotes->find($tenantId, $creditNoteId);
            }
            if ($note->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'Only a draft credit note can be posted.']);
            }

            $plan = $this->computePlan($tenantId, $creditNoteId, lock: true);
            $accounts = $plan['accounts'];
            $now = now();

            foreach ($plan['lineResults'] as $result) {
                $line = $result['line'];
                $restockPlan = $result['restockPlan'];
                if (! $restockPlan || $restockPlan['materials'] === []) {
                    continue;
                }
                $restored = $this->movements->restore($request, $tenantId, $restockPlan['branchId'], $restockPlan['warehouseId'], 'sales_credit_note_line', (int) $line->id, $restockPlan['materials'], $actorId);
                DB::table('sales_credit_note_lines')->where('id', $line->id)->update(['cogs_total' => Money::decimal($restored['cogsCents']), 'updated_at' => $now]);
                foreach ($restored['movements'] as $movement) {
                    DB::table('sales_credit_note_costs')->insert(['tenant_id' => $tenantId, 'sales_credit_note_id' => $creditNoteId, 'sales_credit_note_line_id' => $line->id, 'inventory_movement_id' => $movement['movementId'], 'cost_amount' => Money::decimal($movement['costCents']), 'created_at' => $now, 'updated_at' => $now]);
                }
            }

            $journalLines = [];
            if ($plan['subtotalCents'] > 0) $journalLines[] = ['accountCode' => $accounts['salesReturns'], 'debit' => Money::decimal($plan['subtotalCents']), 'description' => 'Sales Returns'];
            if ($plan['taxCents'] > 0) $journalLines[] = ['accountCode' => $accounts['taxPayable'], 'debit' => Money::decimal($plan['taxCents']), 'description' => 'Sales Tax Reversal'];
            if ($plan['arReductionCents'] > 0) $journalLines[] = ['accountCode' => $accounts['accountsReceivable'], 'credit' => Money::decimal($plan['arReductionCents']), 'description' => 'Accounts Receivable'];
            if ($plan['customerCreditCents'] > 0) $journalLines[] = ['accountCode' => $accounts['customerCredit'], 'credit' => Money::decimal($plan['customerCreditCents']), 'description' => 'Customer Credit Balance'];
            if ($plan['cogsCents'] > 0) {
                $journalLines[] = ['accountCode' => $accounts['inventory'], 'debit' => Money::decimal($plan['cogsCents']), 'description' => 'Inventory Asset'];
                $journalLines[] = ['accountCode' => $accounts['cogs'], 'credit' => Money::decimal($plan['cogsCents']), 'description' => 'Cost of Goods Sold Reversal'];
            }

            $journalId = $this->posting->postSalesCreditNote($request, $tenantId, [
                'branchId' => $note->branch_id, 'sourceId' => $creditNoteId, 'sourceEvent' => 'SALES_CREDIT_NOTE_POSTED',
                'entryDate' => $note->credit_date, 'description' => "Sales Credit Note {$note->credit_note_number}", 'lines' => $journalLines,
            ], $actorId);

            if ($plan['customerCreditCents'] > 0) {
                DB::table('customer_credit_ledger')->insert(['tenant_id' => $tenantId, 'customer_id' => $note->customer_id, 'sales_credit_note_id' => $creditNoteId, 'amount' => Money::decimal($plan['customerCreditCents']), 'created_at' => $now, 'updated_at' => $now]);
            }

            DB::table('sales_credit_notes')->where('id', $creditNoteId)->update([
                'status' => 'posted', 'ar_reduction_amount' => Money::decimal($plan['arReductionCents']), 'customer_credit_amount' => Money::decimal($plan['customerCreditCents']),
                'posted_journal_entry_id' => $journalId, 'posted_by' => $actorId, 'posted_at' => $now, 'updated_by' => $actorId, 'updated_at' => $now,
            ]);
            DB::table('sales_credit_note_postings')->insert(['tenant_id' => $tenantId, 'sales_credit_note_id' => $creditNoteId, 'idempotency_key' => $data['idempotencyKey'], 'request_fingerprint' => $fingerprint, 'journal_entry_id' => $journalId, 'posted_by' => $actorId, 'created_at' => $now, 'updated_at' => $now]);
            $this->audit->record($request, $tenantId, 'sales.credit_note.posted', 'sales_credit_note', $creditNoteId, ['status' => 'draft'], ['creditNoteNumber' => $note->credit_note_number, 'journalEntryId' => $journalId, 'arReduction' => Money::decimal($plan['arReductionCents']), 'customerCredit' => Money::decimal($plan['customerCreditCents']), 'cogsReversal' => Money::decimal($plan['cogsCents'])], $note->branch_id, $actorId);

            return $this->creditNotes->find($tenantId, $creditNoteId);
        }, 3);
    }

    /**
     * Shared by preview() (lock: false) and post() (lock: true, inside the
     * posting transaction). Locking the original invoice, its lines (in
     * deterministic ascending-ID order — avoids deadlocks against a
     * concurrent credit note touching overlapping lines) and the invoice's
     * payment-allocation/credit-note rows (via invoiceRemainingCents) gives
     * the same concurrency guarantee as CustomerPaymentService: two
     * simultaneous Credit Notes attempting to over-return the same line
     * serialize on the locked `sales_invoice_lines` row, and the second one
     * re-reads a now-smaller returnable balance.
     */
    private function computePlan(int $tenantId, int $creditNoteId, bool $lock): array
    {
        $note = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('id', $creditNoteId)->first();
        abort_unless($note, 404, 'Credit note not found.');
        if (! in_array($note->status, ['draft'], true)) {
            throw ValidationException::withMessages(['status' => 'Only a draft credit note can be previewed or posted.']);
        }

        $invoiceQuery = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $note->original_sales_invoice_id);
        $invoice = $lock ? $invoiceQuery->lockForUpdate()->first() : $invoiceQuery->first();
        if (! $invoice || $invoice->status !== 'posted') {
            throw ValidationException::withMessages(['originalSalesInvoiceId' => 'The original invoice is no longer posted.']);
        }
        $this->periods->assertPostingAllowed($tenantId, $note->credit_date);

        $noteLines = DB::table('sales_credit_note_lines')->where('sales_credit_note_id', $creditNoteId)->orderBy('line_number')->get();
        if ($noteLines->isEmpty()) {
            throw ValidationException::withMessages(['lines' => 'A credit note requires at least one line before posting.']);
        }

        $accounts = $this->accounts->creditNoteAccounts($tenantId);

        $originalLineIds = $noteLines->pluck('original_sales_invoice_line_id')->unique()->sort()->values();
        $originalLines = [];
        foreach ($originalLineIds as $id) {
            $q = DB::table('sales_invoice_lines')->where('id', $id)->where('sales_invoice_id', $invoice->id);
            $originalLine = $lock ? $q->lockForUpdate()->first() : $q->first();
            if (! $originalLine) {
                throw ValidationException::withMessages(['lines' => "Original invoice line #{$id} was not found."]);
            }
            $originalLines[$id] = $originalLine;
        }

        $subtotalCents = 0;
        $taxCents = 0;
        $cogsCents = 0;
        $lineResults = [];
        foreach ($noteLines as $line) {
            $originalLine = $originalLines[$line->original_sales_invoice_line_id];
            $creditQtyMilli = $this->milli($line->quantity);
            $originalMilli = $this->milli($originalLine->quantity);
            $returnedMilli = $this->creditNotes->returnedQuantityMilli($tenantId, (int) $originalLine->id);
            $returnableMilli = $originalMilli - $returnedMilli;
            if ($creditQtyMilli > $returnableMilli) {
                throw ValidationException::withMessages(['lines' => "Line {$line->line_number} exceeds its returnable balance of ".number_format(max(0, $returnableMilli) / 1000, 3, '.', '').'.']);
            }

            $unit = Money::cents($originalLine->unit_price);
            $rate = $this->rateMicro($originalLine->tax_rate);
            $subtotal = intdiv(($unit * $creditQtyMilli) + 500, 1000);
            $tax = intdiv(($subtotal * $rate) + 500000, 1000000);
            if (Money::cents($line->subtotal) !== $subtotal || Money::cents($line->tax_total) !== $tax || Money::cents($line->total) !== $subtotal + $tax) {
                throw ValidationException::withMessages(['totals' => 'A credit note line snapshot is invalid.']);
            }
            $subtotalCents += $subtotal;
            $taxCents += $tax;

            $restockPlan = $line->restock ? $this->planRestock($tenantId, $invoice, $originalLine, $creditQtyMilli, $originalMilli) : null;
            if ($restockPlan) {
                $cogsCents += $restockPlan['cogsCents'];
            }
            $lineResults[] = ['line' => $line, 'originalLine' => $originalLine, 'restockPlan' => $restockPlan];
        }
        $totalCents = $subtotalCents + $taxCents;
        if (Money::cents($note->subtotal) !== $subtotalCents || Money::cents($note->tax_total) !== $taxCents || Money::cents($note->total) !== $totalCents) {
            throw ValidationException::withMessages(['totals' => 'The stored credit note totals no longer match its line snapshots.']);
        }

        // Never negative AR (§9/§27/§28): cap the reduction at the invoice's
        // CURRENT outstanding balance, itself already net of prior payments
        // and prior credit notes. Any excess becomes unapplied customer credit.
        $invoiceOutstandingCents = max(0, $this->receivables->invoiceRemainingCents($tenantId, (int) $invoice->id, lock: $lock));
        $arReductionCents = min($totalCents, $invoiceOutstandingCents);
        $customerCreditCents = $totalCents - $arReductionCents;

        return compact('note', 'invoice', 'lineResults', 'accounts', 'subtotalCents', 'taxCents', 'totalCents', 'cogsCents', 'arReductionCents', 'customerCreditCents');
    }

    /**
     * Proportional restock from the ORIGINAL sale's cost snapshot
     * (`sales_invoice_costs` → `stock_movements`), never today's WAC
     * (§13/§15). A service/non-tracked line has no `sales_invoice_costs`
     * rows and yields an empty plan — no stock movement, no COGS reversal.
     */
    private function planRestock(int $tenantId, object $invoice, object $originalLine, int $creditQtyMilli, int $originalMilli): array
    {
        $costs = DB::table('sales_invoice_costs as c')->join('stock_movements as m', 'm.id', '=', 'c.inventory_movement_id')
            ->where('c.tenant_id', $tenantId)->where('c.sales_invoice_line_id', $originalLine->id)
            ->select('m.inventory_item_id', 'm.unit_cost', 'm.quantity_out', 'm.warehouse_id', 'm.branch_id', 'm.input_unit')
            ->get();
        if ($costs->isEmpty()) {
            return ['warehouseId' => null, 'branchId' => null, 'materials' => [], 'cogsCents' => 0];
        }

        $warehouseId = (int) $costs->first()->warehouse_id;
        $branchId = (int) ($costs->first()->branch_id ?? $invoice->branch_id);
        $materials = [];
        $cogsCents = 0;
        foreach ($costs as $cost) {
            $movementQtyUnits = InventoryDecimal::units($cost->quantity_out);
            // Proportional to the credited share of the ORIGINAL line quantity, rounded to the nearest milli-unit.
            $restockQtyUnits = intdiv(($movementQtyUnits * $creditQtyMilli) + intdiv($originalMilli, 2), $originalMilli);
            if ($restockQtyUnits <= 0) {
                continue;
            }
            $unitCostCents = InventoryDecimal::cost($cost->unit_cost);
            $materials[] = ['materialId' => (int) $cost->inventory_item_id, 'baseUnit' => $cost->input_unit, 'quantity' => $restockQtyUnits, 'unitCostCents' => $unitCostCents];
            $cogsCents += Money::cents(InventoryDecimal::totalCost($restockQtyUnits, $unitCostCents));
        }

        return ['warehouseId' => $warehouseId, 'branchId' => $branchId, 'materials' => $materials, 'cogsCents' => $cogsCents];
    }

    private function milli(mixed $value): int
    {
        $v = trim((string) $value);
        preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m);

        return ((int) ($m[1] ?? 0) * 1000) + (int) str_pad(substr($m[2] ?? '', 0, 3), 3, '0');
    }

    private function rateMicro(mixed $value): int
    {
        $v = trim((string) $value);
        if (! preg_match('/^(\d+)(?:\.(\d+))?$/', $v, $m)) {
            return 0;
        }

        return ((int) $m[1] * 1000000) + (int) str_pad(substr($m[2] ?? '', 0, 6), 6, '0');
    }
}
