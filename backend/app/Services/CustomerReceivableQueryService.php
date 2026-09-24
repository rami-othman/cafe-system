<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

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
        // Joined to `customer_receivables` rather than filtered by
        // `customers.is_walk_in`: the receivable record — inserted by
        // SalesInvoicePostingService::post() only for a registered
        // (non-cash) sale — is the actual ground truth for "this invoice
        // carries AR", not a proxy read off the customer master row. This
        // also means the query is correct even if a future data anomaly
        // ever left a registered customer's invoice without one (it would
        // then be correctly excluded from AR too, not silently included).
        $totals = DB::table('sales_invoices as i')
            ->join('customer_receivables as r', function ($join) use ($tenantId): void {
                $join->on('r.sales_invoice_id', '=', 'i.id')->where('r.tenant_id', '=', $tenantId);
            })
            ->join('customers as c', 'c.id', '=', 'i.customer_id')
            ->where('i.tenant_id', $tenantId)->whereIn('i.status', self::OPEN_STATUSES)
            ->when($branchIds !== null, fn ($q) => $q->whereIn('i.branch_id', $branchIds))
            ->selectRaw('i.customer_id, c.name as customer_name, c.customer_number, COUNT(*) as invoice_count, SUM(i.total) as total_invoiced')
            ->groupBy('i.customer_id', 'c.name', 'c.customer_number')->get();
        if ($totals->isEmpty()) {
            return [];
        }
        $invoiceIds = DB::table('sales_invoices as i')
            ->join('customer_receivables as r', function ($join) use ($tenantId): void {
                $join->on('r.sales_invoice_id', '=', 'i.id')->where('r.tenant_id', '=', $tenantId);
            })
            ->where('i.tenant_id', $tenantId)->whereIn('i.status', self::OPEN_STATUSES)
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
        // Only an invoice with an actual customer_receivables row ever
        // carries AR — a direct-cash sale never gets one (see class docblock).
        $invoices = DB::table('sales_invoices as i')
            ->join('customer_receivables as r', function ($join) use ($tenantId): void {
                $join->on('r.sales_invoice_id', '=', 'i.id')->where('r.tenant_id', '=', $tenantId);
            })
            ->where('i.tenant_id', $tenantId)->where('i.customer_id', $customerId)
            ->whereIn('i.status', self::OPEN_STATUSES)->when($branchIds !== null, fn ($q) => $q->whereIn('i.branch_id', $branchIds))
            ->orderByRaw('i.due_date IS NULL')->orderBy('i.due_date')->orderBy('i.invoice_date')->orderBy('i.id')
            ->get(['i.id', 'i.invoice_number', 'i.invoice_date', 'i.due_date', 'i.total']);
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
        $invoices = DB::table('sales_invoices as i')
            ->join('customer_receivables as r', function ($join) use ($tenantId): void {
                $join->on('r.sales_invoice_id', '=', 'i.id')->where('r.tenant_id', '=', $tenantId);
            })
            ->where('i.tenant_id', $tenantId)->whereIn('i.status', self::OPEN_STATUSES)
            ->whereNotNull('i.due_date')->where('i.due_date', '<', now()->toDateString())
            ->when($customerId, fn ($q) => $q->where('i.customer_id', $customerId))
            ->get(['i.id', 'i.total']);

        $totalCents = 0;
        foreach ($invoices as $invoice) {
            $remaining = Money::cents($invoice->total) - $this->invoiceAllocatedCents($tenantId, (int) $invoice->id) - $this->invoiceCreditedArCents($tenantId, (int) $invoice->id);
            if ($remaining > 0) {
                $totalCents += $remaining;
            }
        }

        return Money::decimal($totalCents);
    }

    /**
     * Historical invoice-level AR evidence for aging and statement reports,
     * mirroring SupplierPayableQueryService::invoicesAsOf() for AP. Only a
     * `posted` invoice ever carries AR, and Sales Invoices are never
     * reversed after posting (Phase 2), so — unlike the supplier side —
     * there is no posting/reversal-journal join here: eligibility keys off
     * `invoice_date` directly, exactly matching the journal's own
     * `entry_date` (SalesInvoicePostingService posts with
     * `entryDate: $invoice->invoice_date`), never the wall-clock
     * `posted_at` timestamp of the click that posted it. Live allocations
     * are reduced by whatever `customer_payment_allocation_history`
     * proves was still applied as of $asOfDate but has since been reversed
     * (CustomerPaymentService::reverse() logs exactly that pair).
     */
    public function invoicesAsOf(int $tenantId, string $asOfDate, ?int $branchId = null, array $authorizedBranchIds = [], ?int $customerId = null): array
    {
        if (! Schema::hasTable('sales_invoices')) {
            return [];
        }

        // Joined to `customer_receivables` (never a `customers.is_walk_in`
        // filter — see customerOverview()'s docblock): a direct-cash sale
        // never gets a receivable row, so it is structurally absent from
        // this join, keeping aging, the customer statement and the AR
        // snapshot/summary tiles from treating a fully cash-settled sale as
        // permanently outstanding — without hiding it merely by customer.
        $query = DB::table('sales_invoices as i')
            ->join('customer_receivables as r', function ($join) use ($tenantId): void {
                $join->on('r.sales_invoice_id', '=', 'i.id')->where('r.tenant_id', '=', $tenantId);
            })
            ->join('customers as c', 'c.id', '=', 'i.customer_id')
            ->where('i.tenant_id', $tenantId)->where('i.status', 'posted')->whereDate('i.invoice_date', '<=', $asOfDate)
            ->when($customerId, fn ($q) => $q->where('i.customer_id', $customerId));
        if ($branchId !== null) {
            $query->where('i.branch_id', $branchId);
        } elseif ($authorizedBranchIds !== []) {
            $query->whereIn('i.branch_id', $authorizedBranchIds);
        }
        $invoices = $query->get(['i.id', 'i.customer_id', 'i.branch_id', 'i.invoice_number', 'i.invoice_date', 'i.due_date', 'i.total', 'i.posted_at', 'c.name as customer_name']);
        if ($invoices->isEmpty()) {
            return [];
        }
        $ids = $invoices->pluck('id');
        $live = DB::table('customer_payment_allocations as a')->join('customer_payments as p', 'p.id', '=', 'a.customer_payment_id')
            ->where('a.tenant_id', $tenantId)->whereIn('a.sales_invoice_id', $ids)->whereDate('p.payment_date', '<=', $asOfDate)
            ->selectRaw('a.sales_invoice_id, SUM(a.amount) as total')->groupBy('a.sales_invoice_id')->pluck('total', 'sales_invoice_id');
        $history = DB::table('customer_payment_allocation_history')->where('tenant_id', $tenantId)->whereIn('sales_invoice_id', $ids)
            ->whereDate('payment_date', '<=', $asOfDate)->where('reversed_at', '>', $asOfDate.' 23:59:59')
            ->selectRaw('sales_invoice_id, SUM(amount) as total')->groupBy('sales_invoice_id')->pluck('total', 'sales_invoice_id');
        $credited = DB::table('sales_credit_notes')->where('tenant_id', $tenantId)->where('status', 'posted')->whereIn('original_sales_invoice_id', $ids)
            ->whereDate('credit_date', '<=', $asOfDate)
            ->selectRaw('original_sales_invoice_id, SUM(ar_reduction_amount) as total')->groupBy('original_sales_invoice_id')->pluck('total', 'original_sales_invoice_id');

        return $invoices->map(function (object $invoice) use ($live, $history, $credited): array {
            $remaining = Money::cents($invoice->total) - Money::cents($live[$invoice->id] ?? '0') - Money::cents($history[$invoice->id] ?? '0') - Money::cents($credited[$invoice->id] ?? '0');

            return [
                'id' => (int) $invoice->id,
                'customerId' => (int) $invoice->customer_id,
                'customerName' => $invoice->customer_name,
                'branchId' => $invoice->branch_id ? (int) $invoice->branch_id : null,
                'reference' => $invoice->invoice_number,
                'invoiceDate' => $invoice->invoice_date,
                // Matches the journal's own entry_date exactly (SalesInvoicePostingService
                // posts with `entryDate: $invoice->invoice_date`) — never the wall-clock
                // `posted_at` timestamp, which can differ when a user posts today against
                // an earlier, still-open business date.
                'postedDate' => $invoice->invoice_date,
                'dueDate' => $invoice->due_date ?? $invoice->invoice_date,
                'totalCents' => Money::cents($invoice->total),
                'remainingCents' => $remaining,
            ];
        })->all();
    }

    /**
     * AR overview KPI strip: total outstanding, current-vs-overdue split,
     * total unapplied customer credit, and invoice counts by derived
     * payment status — for the Finance Dashboard / AR summary tile.
     */
    public function summary(int $tenantId, ?array $branchIds = null): array
    {
        $today = now()->toDateString();
        $invoices = DB::table('sales_invoices as i')
            ->join('customer_receivables as r', function ($join) use ($tenantId): void {
                $join->on('r.sales_invoice_id', '=', 'i.id')->where('r.tenant_id', '=', $tenantId);
            })
            ->where('i.tenant_id', $tenantId)->whereIn('i.status', self::OPEN_STATUSES)
            ->when($branchIds !== null, fn ($q) => $q->whereIn('i.branch_id', $branchIds))
            ->get(['i.id', 'i.customer_id', 'i.due_date', 'i.total']);
        if ($invoices->isEmpty()) {
            return ['totalOutstanding' => '0.00', 'currentOutstanding' => '0.00', 'overdueOutstanding' => '0.00', 'totalCustomerCredit' => '0.00', 'invoiceCounts' => ['paid' => 0, 'partial' => 0, 'unpaid' => 0]];
        }
        $ids = $invoices->pluck('id')->all();
        $allocated = $this->allocatedCentsForInvoices($tenantId, $ids);
        $creditedAr = $this->creditedArCentsForInvoices($tenantId, $ids);
        $totalOutstanding = 0;
        $currentOutstanding = 0;
        $overdueOutstanding = 0;
        $counts = ['paid' => 0, 'partial' => 0, 'unpaid' => 0];
        foreach ($invoices as $invoice) {
            $totalCents = Money::cents($invoice->total);
            $remaining = $totalCents - ($allocated[$invoice->id] ?? 0) - ($creditedAr[$invoice->id] ?? 0);
            $counts[$this->paymentStatus($totalCents, $remaining)]++;
            if ($remaining <= 0) {
                continue;
            }
            $totalOutstanding += $remaining;
            if ($invoice->due_date !== null && $invoice->due_date < $today) {
                $overdueOutstanding += $remaining;
            } else {
                $currentOutstanding += $remaining;
            }
        }
        $customerIds = $invoices->pluck('customer_id')->unique();
        $totalCredit = DB::table('customer_credit_ledger')->where('tenant_id', $tenantId)->whereIn('customer_id', $customerIds)->sum('amount') ?: '0';

        return [
            'totalOutstanding' => Money::decimal($totalOutstanding),
            'currentOutstanding' => Money::decimal($currentOutstanding),
            'overdueOutstanding' => Money::decimal($overdueOutstanding),
            'totalCustomerCredit' => Money::decimal(max(0, Money::cents($totalCredit))),
            'invoiceCounts' => $counts,
        ];
    }

    /** Balance-style AR snapshot as of a cutoff date, mirroring SupplierPayableQueryService::snapshotAsOf() — for the Finance Dashboard AR KPI tile. */
    public function snapshotAsOf(int $tenantId, string $asOfDate, ?array $branchIds = null): array
    {
        $invoices = $this->invoicesAsOf($tenantId, $asOfDate, null, $branchIds ?? []);
        $outstanding = 0;
        $overdue = 0;
        $openCount = 0;
        $overdueCount = 0;
        foreach ($invoices as $invoice) {
            if ($invoice['remainingCents'] <= 0) {
                continue;
            }
            $outstanding += $invoice['remainingCents'];
            $openCount++;
            if ($invoice['dueDate'] !== null && $invoice['dueDate'] < $asOfDate) {
                $overdue += $invoice['remainingCents'];
                $overdueCount++;
            }
        }

        return ['outstanding' => Money::decimal($outstanding), 'overdue' => Money::decimal($overdue), 'openInvoiceCount' => $openCount, 'overdueInvoiceCount' => $overdueCount];
    }

    public function openInvoiceCount(int $tenantId, ?int $customerId = null): int
    {
        $invoices = DB::table('sales_invoices as i')
            ->join('customer_receivables as r', function ($join) use ($tenantId): void {
                $join->on('r.sales_invoice_id', '=', 'i.id')->where('r.tenant_id', '=', $tenantId);
            })
            ->where('i.tenant_id', $tenantId)->whereIn('i.status', self::OPEN_STATUSES)
            ->when($customerId, fn ($q) => $q->where('i.customer_id', $customerId))->get(['i.id', 'i.total']);

        $count = 0;
        foreach ($invoices as $invoice) {
            if (Money::cents($invoice->total) - $this->invoiceAllocatedCents($tenantId, (int) $invoice->id) - $this->invoiceCreditedArCents($tenantId, (int) $invoice->id) > 0) {
                $count++;
            }
        }

        return $count;
    }
}
