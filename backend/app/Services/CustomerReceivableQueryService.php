<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;

/**
 * The single authoritative source for customer/AR balances (mirrors
 * SupplierPayableQueryService for AP — see docs/sales
 * SALES_INVOICE_IMPLEMENTATION_PLAN.md "AR architecture"). A customer's
 * receivable balance is never a stored column on `sales_invoices` — it is
 * always derived as:
 *
 *   posted invoice total - SUM(live customer_payment_allocations)
 *                         - SUM(posted sales_credit_notes.ar_reduction_amount)
 *
 * Only a `posted` sales invoice carries AR; a draft or cancelled invoice
 * never does. There is no separate "paid" invoice status — a fully
 * collected invoice simply has remaining == 0 while its document status
 * stays `posted` (see ADR-03 / the implementation plan's lifecycle table).
 * A Credit Note (Phase 4) never drives AR negative: its posting service
 * caps the AR-reduction portion at the invoice's outstanding balance and
 * routes any excess to the customer-credit subledger instead (see
 * CustomerCreditQueryService) — `ar_reduction_amount` is fixed at that
 * point, so this class only ever sums an already-safe number.
 */
final class CustomerReceivableQueryService
{
    public const OPEN_STATUSES = ['posted'];

    /** Cents still owed on one invoice; pass $lock inside a payment/credit-note transaction to serialize concurrent settlement. */
    public function invoiceRemainingCents(int $tenantId, int $invoiceId, bool $lock = false): int
    {
        $invoice = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first();
        abort_unless($invoice, 404, 'Sales invoice not found.');

        return Money::cents($invoice->total) - $this->invoiceAllocatedCents($tenantId, $invoiceId, $lock) - $this->invoiceCreditedArCents($tenantId, $invoiceId, $lock);
    }

    /** Cents collected per invoice id, batched for list rendering (avoids one query per row). */
    public function allocatedCentsForInvoices(int $tenantId, array $invoiceIds): array
    {
        if ($invoiceIds === []) {
            return [];
        }

        return DB::table('customer_payment_allocations')->where('tenant_id', $tenantId)->whereIn('sales_invoice_id', $invoiceIds)
            ->selectRaw('sales_invoice_id, SUM(amount) as total')->groupBy('sales_invoice_id')->pluck('total', 'sales_invoice_id')
            ->map(fn ($value) => Money::cents($value))->all();
    }

    /** Cents already collected against one invoice (live allocations only). */
    public function invoiceAllocatedCents(int $tenantId, int $invoiceId, bool $lock = false): int
    {
        $query = DB::table('customer_payment_allocations')->where('tenant_id', $tenantId)->where('sales_invoice_id', $invoiceId);
        if ($lock) {
            // PostgreSQL rejects FOR UPDATE on SUM(...). The caller already
            // locks the invoice row; locking the allocation rows before
            // summing preserves the payment transaction's concurrency guard
            // (mirrors SupplierPayableQueryService::invoiceAllocatedCents()).
            return $query->lockForUpdate()->pluck('amount')->reduce(
                fn (int $total, mixed $amount): int => $total + Money::cents($amount),
                0,
            );
        }

        return Money::cents($query->sum('amount') ?: '0');
    }

    /** Cents credited (AR-reduction portion) per invoice id, batched for list rendering (avoids one query per row). */
    public function creditedArCentsForInvoices(int $tenantId, array $invoiceIds): array
    {
        if ($invoiceIds === []) {
            return [];
        }

        return DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('status', 'posted')->whereIn('original_sales_invoice_id', $invoiceIds)
            ->selectRaw('original_sales_invoice_id, SUM(ar_reduction_amount) as total')->groupBy('original_sales_invoice_id')->pluck('total', 'original_sales_invoice_id')
            ->map(fn ($value) => Money::cents($value))->all();
    }

    /** Full credit-note total per invoice id, batched — used for credit STATUS (see invoiceCreditedTotalCents()). */
    public function creditedTotalCentsForInvoices(int $tenantId, array $invoiceIds): array
    {
        if ($invoiceIds === []) {
            return [];
        }

        return DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('status', 'posted')->whereIn('original_sales_invoice_id', $invoiceIds)
            ->selectRaw('original_sales_invoice_id, SUM(total) as total')->groupBy('original_sales_invoice_id')->pluck('total', 'original_sales_invoice_id')
            ->map(fn ($value) => Money::cents($value))->all();
    }

    /** Cents by which posted Credit Notes have reduced this invoice's AR (never the unapplied-credit portion — see class docblock). */
    public function invoiceCreditedArCents(int $tenantId, int $invoiceId, bool $lock = false): int
    {
        $query = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('original_sales_invoice_id', $invoiceId)->where('status', 'posted');
        if ($lock) {
            return $query->lockForUpdate()->pluck('ar_reduction_amount')->reduce(
                fn (int $total, mixed $amount): int => $total + Money::cents($amount ?? '0'),
                0,
            );
        }

        return Money::cents($query->sum('ar_reduction_amount') ?: '0');
    }

    /** Full credit-note value (subtotal + tax) posted against this invoice — used for credit STATUS, distinct from the AR-reduction-only figure above (a fully-paid invoice can be "fully credited" while its AR reduction was 0). */
    public function invoiceCreditedTotalCents(int $tenantId, int $invoiceId): int
    {
        return Money::cents(DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('original_sales_invoice_id', $invoiceId)->where('status', 'posted')->sum('total') ?: '0');
    }

    /** unpaid | partial | paid, derived from total vs. remaining. */
    public function paymentStatus(int $totalCents, int $remainingCents): string
    {
        if ($remainingCents >= $totalCents) {
            return 'unpaid';
        }

        return $remainingCents <= 0 ? 'paid' : 'partial';
    }

    /** not_credited | partially_credited | fully_credited, derived from total vs. credited (kept distinct from payment status — §37). */
    public function creditStatus(int $totalCents, int $creditedTotalCents): string
    {
        if ($creditedTotalCents <= 0) {
            return 'not_credited';
        }

        return $creditedTotalCents >= $totalCents ? 'fully_credited' : 'partially_credited';
    }

    /**
     * A minimal AR overview row per customer with at least one posted
     * invoice: totalInvoiced, totalPaid, outstanding (§33 "Customers / AR
     * minimal view" — no aging buckets here, see overdueOutstanding()).
     *
     * $branchIds restricts to the actor's operationally accessible branches
     * (null means unrestricted — e.g. an owner); invoice totals, their
     * allocations and their credit notes are all filtered by the same
     * invoice set so paid/credited/outstanding stay internally consistent
     * for a branch-limited actor.
     */
    public function customerOverview(int $tenantId, ?array $branchIds = null): array
    {
        $totals = DB::table('sales_invoices as i')->join('customers as c', 'c.id', '=', 'i.customer_id')
            ->where('i.tenant_id', $tenantId)->whereIn('i.status', self::OPEN_STATUSES)
            ->when($branchIds !== null, fn ($q) => $q->whereIn('i.branch_id', $branchIds))
            ->selectRaw('i.customer_id, c.name as customer_name, c.customer_number, COUNT(*) as invoice_count, SUM(i.total) as total_invoiced')
            ->groupBy('i.customer_id', 'c.name', 'c.customer_number')->get();
        if ($totals->isEmpty()) {
            return [];
        }
        $invoiceIds = DB::table('sales_invoices as i')->where('i.tenant_id', $tenantId)->whereIn('i.status', self::OPEN_STATUSES)
            ->whereIn('i.customer_id', $totals->pluck('customer_id'))
            ->when($branchIds !== null, fn ($q) => $q->whereIn('i.branch_id', $branchIds))
            ->pluck('i.id');
        $allocated = DB::table('customer_payment_allocations as a')
            ->join('sales_invoices as i', 'i.id', '=', 'a.sales_invoice_id')
            ->where('a.tenant_id', $tenantId)->whereIn('a.sales_invoice_id', $invoiceIds)
            ->selectRaw('i.customer_id, SUM(a.amount) as total')->groupBy('i.customer_id')->pluck('total', 'customer_id');
        $credited = DB::table('sales_credit_notes as n')
            ->where('n.tenant_id', $tenantId)->where('n.status', 'posted')->whereIn('n.original_sales_invoice_id', $invoiceIds)
            ->selectRaw('n.customer_id, SUM(n.ar_reduction_amount) as total')->groupBy('n.customer_id')->pluck('total', 'customer_id');

        return $totals->map(function (object $row) use ($allocated, $credited): array {
            $invoicedCents = Money::cents($row->total_invoiced);
            $paidCents = Money::cents($allocated[$row->customer_id] ?? '0');
            $creditedCents = Money::cents($credited[$row->customer_id] ?? '0');

            return [
                'customerId' => (int) $row->customer_id,
                'customerName' => $row->customer_name,
                'customerNumber' => $row->customer_number,
                'invoiceCount' => (int) $row->invoice_count,
                'totalInvoiced' => Money::decimal($invoicedCents),
                'totalPaid' => Money::decimal($paidCents),
                'totalCredited' => Money::decimal($creditedCents),
                'outstanding' => Money::decimal($invoicedCents - $paidCents - $creditedCents),
            ];
        })->sortByDesc(fn (array $row) => (float) $row['outstanding'])->values()->all();
    }

    /** Every open (remaining > 0) posted invoice for one customer, oldest due date first — the default auto-allocation order (§10). */
    public function openInvoices(int $tenantId, int $customerId, ?array $branchIds = null): array
    {
        $invoices = DB::table('sales_invoices')->where('tenant_id', $tenantId)->where('customer_id', $customerId)
            ->whereIn('status', self::OPEN_STATUSES)->when($branchIds !== null, fn ($q) => $q->whereIn('branch_id', $branchIds))
            ->orderByRaw('due_date IS NULL')->orderBy('due_date')->orderBy('invoice_date')->orderBy('id')
            ->get(['id', 'invoice_number', 'invoice_date', 'due_date', 'total']);
        $today = now()->toDateString();

        $result = [];
        foreach ($invoices as $invoice) {
            $totalCents = Money::cents($invoice->total);
            $paidCents = $this->invoiceAllocatedCents($tenantId, (int) $invoice->id);
            $creditedCents = $this->invoiceCreditedArCents($tenantId, (int) $invoice->id);
            $remainingCents = $totalCents - $paidCents - $creditedCents;
            if ($remainingCents <= 0) {
                continue;
            }
            $result[] = [
                'id' => (int) $invoice->id,
                'invoiceNumber' => $invoice->invoice_number,
                'invoiceDate' => $invoice->invoice_date,
                'dueDate' => $invoice->due_date,
                'total' => Money::decimal($totalCents),
                'paid' => Money::decimal($paidCents),
                'remaining' => Money::decimal($remainingCents),
                'remainingCents' => $remainingCents,
                'isOverdue' => $invoice->due_date !== null && $invoice->due_date < $today,
            ];
        }

        return $result;
    }

    /** Sum of outstanding balances on posted invoices already past their due date. */
    public function overdueOutstanding(int $tenantId, ?int $customerId = null): string
    {
        $invoices = DB::table('sales_invoices')
            ->where('tenant_id', $tenantId)->whereIn('status', self::OPEN_STATUSES)
            ->whereNotNull('due_date')->where('due_date', '<', now()->toDateString())
            ->when($customerId, fn ($q) => $q->where('customer_id', $customerId))
            ->get(['id', 'total']);

        $totalCents = 0;
        foreach ($invoices as $invoice) {
            $remaining = Money::cents($invoice->total) - $this->invoiceAllocatedCents($tenantId, (int) $invoice->id) - $this->invoiceCreditedArCents($tenantId, (int) $invoice->id);
            if ($remaining > 0) {
                $totalCents += $remaining;
            }
        }

        return Money::decimal($totalCents);
    }

    public function openInvoiceCount(int $tenantId, ?int $customerId = null): int
    {
        $invoices = DB::table('sales_invoices')->where('tenant_id', $tenantId)->whereIn('status', self::OPEN_STATUSES)
            ->when($customerId, fn ($q) => $q->where('customer_id', $customerId))->get(['id', 'total']);

        $count = 0;
        foreach ($invoices as $invoice) {
            if (Money::cents($invoice->total) - $this->invoiceAllocatedCents($tenantId, (int) $invoice->id) - $this->invoiceCreditedArCents($tenantId, (int) $invoice->id) > 0) {
                $count++;
            }
        }

        return $count;
    }
}
