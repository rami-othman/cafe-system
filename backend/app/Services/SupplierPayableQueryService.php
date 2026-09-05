<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;

/**
 * The single authoritative source for supplier/AP balances. Supplier list,
 * Supplier Profile, and the Statement all call this rather than each
 * computing their own formula (see docs/finance §21). A supplier's payable
 * balance is never a stored column — it is always derived as:
 *
 *   SUM(posted-family invoice totals) - SUM(payment allocations against them)
 *
 * "Posted-family" means status in [posted, partially_paid, paid] — a draft
 * or cancelled invoice carries no liability. A fully-paid invoice's
 * allocations equal its total, so it contributes zero automatically; no
 * separate exclusion is needed.
 */
class SupplierPayableQueryService
{
    /** Historical invoice-level AP evidence for ageing and statement reports. */
    public function invoicesAsOf(int $tenantId, string $asOfDate, ?int $branchId = null, array $authorizedBranchIds = [], ?int $supplierId = null): array
    {
        $query = DB::table('supplier_invoices as invoices')->join('suppliers as suppliers', 'suppliers.id', '=', 'invoices.supplier_id')
            ->leftJoin('journal_entries as posting', 'posting.id', '=', 'invoices.journal_entry_id')
            ->leftJoin('journal_entries as reversal', 'reversal.id', '=', 'invoices.reversal_journal_entry_id')
            ->where('invoices.tenant_id', $tenantId)->when($supplierId, fn ($q) => $q->where('invoices.supplier_id', $supplierId));
        if ($branchId !== null) $query->where('invoices.branch_id', $branchId); elseif ($authorizedBranchIds !== []) $query->where(fn ($q) => $q->whereIn('invoices.branch_id', $authorizedBranchIds)->orWhereNull('invoices.branch_id'));
        $invoices = $query->where(function ($q) use ($tenantId, $asOfDate): void { $q->where(function ($legacy) use ($asOfDate): void { $legacy->whereNull('invoices.journal_entry_id')->whereIn('invoices.status', ['posted', 'partially_paid', 'paid'])->whereDate('invoices.invoice_date', '<=', $asOfDate); })->orWhere(function ($posted) use ($tenantId, $asOfDate): void { $posted->where('posting.tenant_id', $tenantId)->where('posting.status', 'posted')->whereDate('posting.entry_date', '<=', $asOfDate)->where(fn ($active) => $active->whereNull('invoices.reversal_journal_entry_id')->orWhereDate('reversal.entry_date', '>', $asOfDate)); }); })->get(['invoices.id', 'invoices.supplier_id', 'invoices.branch_id', 'invoices.internal_reference', 'invoices.invoice_date', 'invoices.due_date', 'invoices.total_amount', 'posting.entry_date as posted_date', 'suppliers.name as supplier_name']);
        if ($invoices->isEmpty()) return [];
        $ids = $invoices->pluck('id');
        $live = DB::table('payment_allocations as allocations')->join('supplier_payments as payments', 'payments.id', '=', 'allocations.supplier_payment_id')->where('allocations.tenant_id', $tenantId)->whereIn('allocations.supplier_invoice_id', $ids)->whereDate('payments.payment_date', '<=', $asOfDate)->selectRaw('allocations.supplier_invoice_id, SUM(allocations.amount) total')->groupBy('allocations.supplier_invoice_id')->pluck('total', 'supplier_invoice_id');
        $history = DB::table('supplier_payment_allocation_history')->where('tenant_id', $tenantId)->whereIn('supplier_invoice_id', $ids)->whereDate('payment_date', '<=', $asOfDate)->where('reversed_at', '>', $asOfDate.' 23:59:59')->selectRaw('supplier_invoice_id, SUM(amount) total')->groupBy('supplier_invoice_id')->pluck('total', 'supplier_invoice_id');
        return $invoices->map(function (object $invoice) use ($live, $history): array { $remaining = Money::cents($invoice->total_amount) - Money::cents($live[$invoice->id] ?? '0') - Money::cents($history[$invoice->id] ?? '0'); return ['id' => (int) $invoice->id, 'supplierId' => (int) $invoice->supplier_id, 'supplierName' => $invoice->supplier_name, 'branchId' => $invoice->branch_id ? (int) $invoice->branch_id : null, 'reference' => $invoice->internal_reference, 'invoiceDate' => $invoice->invoice_date, 'postedDate' => $invoice->posted_date ?? $invoice->invoice_date, 'dueDate' => $invoice->due_date, 'totalCents' => Money::cents($invoice->total_amount), 'remainingCents' => $remaining]; })->all();
    }
    /** Outstanding payable for one supplier, as a decimal string. */
    public function outstanding(int $tenantId, int $supplierId): string
    {
        return Money::decimal($this->invoiceTotalCents($tenantId, $supplierId) - $this->allocatedCents($tenantId, $supplierId));
    }

    /** Outstanding payable across every active supplier, keyed by supplier id. */
    public function outstandingBySupplier(int $tenantId): array
    {
        $invoiceTotals = DB::table('supplier_invoices')
            ->where('tenant_id', $tenantId)->whereIn('status', ['posted', 'partially_paid', 'paid'])
            ->selectRaw('supplier_id, SUM(total_amount) as total')
            ->groupBy('supplier_id')->pluck('total', 'supplier_id');
        $allocated = DB::table('payment_allocations as a')
            ->join('supplier_invoices as i', 'i.id', '=', 'a.supplier_invoice_id')
            ->where('a.tenant_id', $tenantId)
            ->selectRaw('i.supplier_id as supplier_id, SUM(a.amount) as total')
            ->groupBy('i.supplier_id')->pluck('total', 'supplier_id');

        $supplierIds = collect($invoiceTotals->keys())->merge($allocated->keys())->unique();

        return $supplierIds->mapWithKeys(fn ($id) => [
            (int) $id => Money::decimal(Money::cents($invoiceTotals[$id] ?? '0') - Money::cents($allocated[$id] ?? '0')),
        ])->all();
    }

    /** Sum of outstanding balances on invoices already past their due date. */
    public function overdueOutstanding(int $tenantId, ?int $supplierId = null): string
    {
        $invoices = DB::table('supplier_invoices')
            ->where('tenant_id', $tenantId)->whereIn('status', ['posted', 'partially_paid'])
            ->where('due_date', '<', now()->toDateString())
            ->when($supplierId, fn ($q) => $q->where('supplier_id', $supplierId))
            ->get(['id', 'total_amount']);

        $totalCents = 0;
        foreach ($invoices as $invoice) {
            $remaining = Money::cents($invoice->total_amount) - $this->invoiceAllocatedCents($tenantId, (int) $invoice->id);
            if ($remaining > 0) {
                $totalCents += $remaining;
            }
        }

        return Money::decimal($totalCents);
    }

    /** Individual overdue invoices (for alert/exception lists), most-overdue-amount first. */
    public function overdueInvoices(int $tenantId, int $limit = 20): array
    {
        $invoices = DB::table('supplier_invoices as i')->join('suppliers as s', 's.id', '=', 'i.supplier_id')
            ->where('i.tenant_id', $tenantId)->whereIn('i.status', ['posted', 'partially_paid'])
            ->where('i.due_date', '<', now()->toDateString())
            ->get(['i.id', 'i.branch_id', 'i.internal_reference', 'i.total_amount', 'i.due_date', 's.name as supplier_name']);

        $result = [];
        foreach ($invoices as $invoice) {
            $remaining = Money::cents($invoice->total_amount) - $this->invoiceAllocatedCents($tenantId, (int) $invoice->id);
            if ($remaining > 0) {
                $result[] = ['id' => (int) $invoice->id, 'branchId' => $invoice->branch_id ? (int) $invoice->branch_id : null, 'reference' => $invoice->internal_reference, 'remaining' => Money::decimal($remaining), 'remainingCents' => $remaining, 'dueDate' => $invoice->due_date, 'supplierName' => $invoice->supplier_name];
            }
        }

        usort($result, fn ($a, $b) => $b['remainingCents'] <=> $a['remainingCents']);

        return array_slice($result, 0, $limit);
    }

    public function openInvoiceCount(int $tenantId, ?int $supplierId = null): int
    {
        return DB::table('supplier_invoices')->where('tenant_id', $tenantId)
            ->whereIn('status', ['posted', 'partially_paid'])
            ->when($supplierId, fn ($q) => $q->where('supplier_id', $supplierId))
            ->count();
    }

    /**
     * A historical AP snapshot as of a given date — outstanding, overdue,
     * open and overdue invoice counts — for Dashboard balance comparisons.
     * The query is driven by immutable posting/reversal events, not today's
     * invoice status. That keeps a later payment or invoice reversal from
     * changing an earlier dashboard comparison period.
     *
     * @return array{outstanding: string, overdue: string, openInvoiceCount: int, overdueInvoiceCount: int}
     */
    public function snapshotAsOf(int $tenantId, string $asOfDate): array
    {
        $invoices = DB::table('supplier_invoices as invoices')
            ->leftJoin('journal_entries as posting', 'posting.id', '=', 'invoices.journal_entry_id')
            ->leftJoin('journal_entries as reversal', 'reversal.id', '=', 'invoices.reversal_journal_entry_id')
            ->where('invoices.tenant_id', $tenantId)
            ->where(function ($query) use ($asOfDate, $tenantId): void {
                // Legacy/imported records without a journal retain the original
                // Phase 5 status fallback. New records use the actual posting
                // and reversal dates, never their present-day status.
                $query->where(function ($legacy) use ($asOfDate): void {
                    $legacy->whereNull('invoices.journal_entry_id')->whereIn('invoices.status', ['posted', 'partially_paid', 'paid'])
                        ->whereDate('invoices.invoice_date', '<=', $asOfDate);
                })->orWhere(function ($posted) use ($asOfDate, $tenantId): void {
                    $posted->where('posting.tenant_id', $tenantId)->where('posting.status', 'posted')->whereDate('posting.entry_date', '<=', $asOfDate)
                        ->where(function ($active) use ($asOfDate): void {
                            $active->whereNull('invoices.reversal_journal_entry_id')->orWhereDate('reversal.entry_date', '>', $asOfDate);
                        });
                });
            })->get(['invoices.id', 'invoices.total_amount', 'invoices.due_date']);

        if ($invoices->isEmpty()) {
            return ['outstanding' => '0.00', 'overdue' => '0.00', 'openInvoiceCount' => 0, 'overdueInvoiceCount' => 0];
        }

        $allocated = DB::table('payment_allocations as a')
            ->join('supplier_payments as p', 'p.id', '=', 'a.supplier_payment_id')
            ->where('a.tenant_id', $tenantId)->whereIn('a.supplier_invoice_id', $invoices->pluck('id'))
            ->whereDate('p.payment_date', '<=', $asOfDate)
            ->selectRaw('a.supplier_invoice_id, SUM(a.amount) as total')->groupBy('a.supplier_invoice_id')
            ->pluck('total', 'supplier_invoice_id');

        $reversedAllocations = DB::table('supplier_payment_allocation_history')
            ->where('tenant_id', $tenantId)->whereIn('supplier_invoice_id', $invoices->pluck('id'))
            ->whereDate('payment_date', '<=', $asOfDate)->where('reversed_at', '>', $asOfDate.' 23:59:59')
            ->selectRaw('supplier_invoice_id, SUM(amount) as total')->groupBy('supplier_invoice_id')->pluck('total', 'supplier_invoice_id');

        $outstandingCents = 0;
        $overdueCents = 0;
        $openCount = 0;
        $overdueCount = 0;
        foreach ($invoices as $invoice) {
            $paid = Money::cents($allocated[$invoice->id] ?? '0') + Money::cents($reversedAllocations[$invoice->id] ?? '0');
            $remaining = Money::cents($invoice->total_amount) - $paid;
            if ($remaining <= 0) {
                continue;
            }
            $outstandingCents += $remaining;
            $openCount++;
            if ($invoice->due_date < $asOfDate) {
                $overdueCents += $remaining;
                $overdueCount++;
            }
        }

        return ['outstanding' => Money::decimal($outstandingCents), 'overdue' => Money::decimal($overdueCents), 'openInvoiceCount' => $openCount, 'overdueInvoiceCount' => $overdueCount];
    }

    /** Cents still owed on one invoice; pass $lock inside a payment transaction. */
    public function invoiceRemainingCents(int $tenantId, int $invoiceId, bool $lock = false): int
    {
        $invoice = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first();
        abort_unless($invoice, 404, 'Supplier invoice not found.');

        return Money::cents($invoice->total_amount) - $this->invoiceAllocatedCents($tenantId, $invoiceId, $lock);
    }

    private function invoiceAllocatedCents(int $tenantId, int $invoiceId, bool $lock = false): int
    {
        $query = DB::table('payment_allocations')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId);
        if ($lock) {
            // PostgreSQL does not permit FOR UPDATE on SUM(...).  The caller
            // already locks the invoice; locking the allocation rows before
            // summing preserves the payment transaction's concurrency guard.
            return $query->lockForUpdate()->pluck('amount')->reduce(
                fn (int $total, mixed $amount): int => $total + Money::cents($amount),
                0,
            );
        }

        return Money::cents($query->sum('amount') ?: '0');
    }

    private function invoiceTotalCents(int $tenantId, int $supplierId): int
    {
        return Money::cents(DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('supplier_id', $supplierId)
            ->whereIn('status', ['posted', 'partially_paid', 'paid'])->sum('total_amount') ?: '0');
    }

    private function allocatedCents(int $tenantId, int $supplierId): int
    {
        return Money::cents(DB::table('payment_allocations as a')
            ->join('supplier_invoices as i', 'i.id', '=', 'a.supplier_invoice_id')
            ->where('a.tenant_id', $tenantId)->where('i.supplier_id', $supplierId)
            ->sum('a.amount') ?: '0');
    }
}
