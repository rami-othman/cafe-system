<?php

namespace App\Services;

use App\Support\InventoryDecimal;
use App\Support\Money;
use Illuminate\Support\Facades\DB;

/**
 * Read-only cross-module Finance diagnostic.  It intentionally reads the
 * business records and the authoritative journal rather than maintaining a
 * second financial state or attempting to repair data.
 */
final class FinancialIntegrityService
{
    public function __construct(private readonly FinancialSetupService $setup) {}

    public function inspect(int $tenantId): array
    {
        $checks = [
            $this->journalBalance($tenantId),
            $this->orphanJournalLines($tenantId),
            $this->paidExpenses($tenantId),
            $this->duplicateSourcePostings($tenantId),
            $this->supplierInvoices($tenantId),
            ...$this->supplierPayments($tenantId),
            $this->paidSales($tenantId),
            ...$this->inventoryPostings($tenantId),
            $this->cashTransfers($tenantId),
            $this->refunds($tenantId),
            $this->lateClosingActivity($tenantId),
            $this->closedPeriodActivity($tenantId),
            $this->trialBalance($tenantId),
            $this->balanceSheet($tenantId),
            $this->accountsPayable($tenantId),
            $this->configuration($tenantId),
        ];

        $critical = count(array_filter($checks, fn (array $check): bool => $check['severity'] === 'critical' && $check['count'] > 0));
        $warnings = count(array_filter($checks, fn (array $check): bool => $check['severity'] === 'warning' && $check['count'] > 0));

        return [
            'status' => $critical > 0 ? 'FAIL' : ($warnings > 0 ? 'WARNING' : 'PASS'),
            'checks' => $checks,
            'summary' => [
                'critical' => $critical,
                'warnings' => $warnings,
                'passed' => count($checks) - $critical - $warnings,
            ],
        ];
    }

    private function journalBalance(int $tenant): array
    {
        $rows = DB::table('journal_entries as entries')
            ->join('journal_entry_lines as lines', 'lines.journal_entry_id', '=', 'entries.id')
            ->where('entries.tenant_id', $tenant)->where('entries.status', 'posted')->where('lines.tenant_id', $tenant)
            ->groupBy('entries.id', 'entries.entry_number')
            ->selectRaw('entries.id, entries.entry_number, SUM(lines.debit) as debit, SUM(lines.credit) as credit')
            ->get()->filter(fn (object $row): bool => Money::cents($row->debit) !== Money::cents($row->credit));

        return $this->check('UNBALANCED_POSTED_JOURNAL', 'critical', $rows->map(fn ($r) => $r->entry_number)->all(), 'Posted journals must have equal debit and credit totals.');
    }

    private function orphanJournalLines(int $tenant): array
    {
        $rows = DB::table('journal_entry_lines as lines')
            ->leftJoin('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->leftJoin('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $tenant)
            ->where(function ($query) use ($tenant): void {
                $query->whereNull('entries.id')->orWhere('entries.tenant_id', '!=', $tenant)
                    ->orWhereNull('accounts.id')->orWhere('accounts.tenant_id', '!=', $tenant);
            })->pluck('lines.id')->all();

        return $this->check('ORPHAN_OR_CROSS_TENANT_JOURNAL_LINE', 'critical', $rows, 'Journal lines must reference a tenant-matching entry and account.');
    }

    private function paidExpenses(int $tenant): array
    {
        $missing = DB::table('expenses as expenses')->leftJoin('journal_entries as entries', 'entries.id', '=', 'expenses.journal_entry_id')
            ->where('expenses.tenant_id', $tenant)->where('expenses.status', 'paid')
            ->where(fn ($q) => $q->whereNull('entries.id')->orWhere('entries.tenant_id', '!=', $tenant)->orWhere('entries.status', '!=', 'posted'))
            ->pluck('expenses.id')->all();
        return $this->check('PAID_EXPENSE_MISSING_JOURNAL', 'critical', $missing, 'Paid expenses require a posted journal.');
    }

    private function duplicateSourcePostings(int $tenant): array
    {
        $rows = DB::table('journal_entries')->where('tenant_id', $tenant)->whereNotNull('source_id')->whereNotNull('source_event')
            ->groupBy('source_type', 'source_id', 'source_event')->havingRaw('COUNT(*) > 1')
            ->selectRaw('source_type, source_id, source_event, COUNT(*) as duplicate_count')->get()
            ->map(fn ($row) => $row->source_type.':'.$row->source_id.':'.$row->source_event)->all();
        return $this->check('DUPLICATE_SOURCE_POSTING', 'critical', $rows, 'A business event may create only one source-event journal.');
    }

    private function supplierInvoices(int $tenant): array
    {
        $rows = DB::table('supplier_invoices as invoices')->leftJoin('journal_entries as entries', 'entries.id', '=', 'invoices.journal_entry_id')
            ->where('invoices.tenant_id', $tenant)->where('invoices.status', 'posted')
            ->where(fn ($q) => $q->whereNull('entries.id')->orWhere('entries.tenant_id', '!=', $tenant)->orWhere('entries.status', '!=', 'posted'))
            ->pluck('invoices.id')->all();
        return $this->check('POSTED_SUPPLIER_INVOICE_MISSING_AP_JOURNAL', 'critical', $rows, 'Posted supplier invoices require a posted AP journal.');
    }

    private function supplierPayments(int $tenant): array
    {
        $payments = DB::table('supplier_payments as payments')->leftJoin('journal_entries as entries', 'entries.id', '=', 'payments.journal_entry_id')
            ->leftJoin('payment_allocations as allocations', 'allocations.supplier_payment_id', '=', 'payments.id')
            ->where('payments.tenant_id', $tenant)->where('payments.status', 'posted')
            ->groupBy('payments.id', 'payments.amount', 'entries.id', 'entries.tenant_id', 'entries.status')
            ->selectRaw('payments.id, payments.amount, entries.id as journal_id, entries.tenant_id as journal_tenant, entries.status as journal_status, COALESCE(SUM(allocations.amount),0) as allocated')
            ->get();
        $missing = $payments->filter(fn ($row) => ! $row->journal_id || (int) $row->journal_tenant !== $tenant || $row->journal_status !== 'posted')->pluck('id')->all();
        $mismatch = $payments->filter(fn ($row) => Money::cents($row->amount) !== Money::cents($row->allocated))->pluck('id')->all();
        return [
            $this->check('SUPPLIER_PAYMENT_MISSING_JOURNAL', 'critical', $missing, 'Posted supplier payments require a posted journal.'),
            $this->check('SUPPLIER_PAYMENT_ALLOCATION_MISMATCH', 'critical', $mismatch, 'Supplier payment allocations must equal the payment amount.'),
        ];
    }

    private function paidSales(int $tenant): array
    {
        $rows = DB::table('orders as orders')->join('payments as payments', 'payments.order_id', '=', 'orders.id')
            ->leftJoin('journal_entries as entries', function ($join): void {
                $join->on('entries.source_id', '=', 'orders.id')->where('entries.source_type', '=', 'pos_order')->where('entries.source_event', '=', 'POS_ORDER_PAID');
            })->where('orders.tenant_id', $tenant)->where('payments.tenant_id', $tenant)->where('payments.status', 'completed')
            ->whereNotNull('payments.payment_method_id')->where(fn ($q) => $q->whereNull('entries.id')->orWhere('entries.tenant_id', '!=', $tenant)->orWhere('entries.status', '!=', 'posted'))
            ->distinct()->pluck('orders.id')->all();
        return $this->check('PAID_POS_SALE_MISSING_JOURNAL', 'critical', $rows, 'Finance-mapped paid POS sales require a posted sale journal.');
    }

    private function inventoryPostings(int $tenant): array
    {
        $movements = DB::table('stock_movements as movements')
            ->leftJoin('journal_entries as entries', function ($join): void {
                $join->on('entries.source_id', '=', 'movements.id')->where('entries.source_type', '=', 'inventory_movement');
            })->where('movements.tenant_id', $tenant)
            ->whereIn('movements.type', ['waste', 'stock_count_variance', 'transfer_in', 'transfer_out'])
            ->select('movements.id', 'movements.type', 'movements.quantity_out', 'movements.total_cost', 'entries.id as journal_id', 'entries.source_event', 'entries.status as journal_status')->get();
        $required = $movements->filter(fn ($row) => in_array($row->type, ['waste', 'stock_count_variance'], true) && Money::cents($row->total_cost) !== 0)
            ->filter(function ($row): bool {
                $event = $row->type === 'waste' ? 'INVENTORY_WASTE' : (InventoryDecimal::units($row->quantity_out) > 0 ? 'STOCK_COUNT_SHORTAGE' : 'STOCK_COUNT_SURPLUS');
                return ! $row->journal_id || $row->source_event !== $event || $row->journal_status !== 'posted';
            })->pluck('id')->all();
        $internal = $movements->filter(fn ($row) => in_array($row->type, ['transfer_in', 'transfer_out'], true) && $row->journal_id)->pluck('id')->all();
        return [
            $this->check('INVENTORY_FINANCE_EVENT_MISSING_POSTING', 'critical', $required, 'Finalized waste and stock-count variances with cost require their mapped journal.'),
            $this->check('INTERNAL_TRANSFER_INCORRECTLY_POSTED', 'critical', $internal, 'Internal inventory transfers must not create a Finance journal.'),
        ];
    }

    private function cashTransfers(int $tenant): array
    {
        $rows = DB::table('cash_transfers as transfers')->leftJoin('journal_entries as entries', 'entries.id', '=', 'transfers.journal_entry_id')
            ->where('transfers.tenant_id', $tenant)->where('transfers.status', 'posted')
            ->where(fn ($q) => $q->whereNull('entries.id')->orWhere('entries.tenant_id', '!=', $tenant)->orWhere('entries.status', '!=', 'posted'))
            ->pluck('transfers.id')->all();
        return $this->check('CASH_TRANSFER_MISSING_JOURNAL', 'critical', $rows, 'Posted cash transfers require a posted journal.');
    }

    private function refunds(int $tenant): array
    {
        $rows = DB::table('payment_refunds as refunds')->leftJoin('journal_entries as entries', function ($join): void {
            $join->on('entries.source_id', '=', 'refunds.id')->where('entries.source_type', '=', 'payment_refund')->where('entries.source_event', '=', 'PAYMENT_REFUNDED');
        })->join('payments', 'payments.id', '=', 'refunds.payment_id')
            ->where('refunds.tenant_id', $tenant)->where('refunds.status', 'completed')->whereNotNull('payments.payment_method_id')
            ->where(fn ($q) => $q->whereNull('entries.id')->orWhere('entries.tenant_id', '!=', $tenant)->orWhere('entries.status', '!=', 'posted'))
            ->pluck('refunds.id')->all();
        return $this->check('REFUND_MISSING_JOURNAL', 'critical', $rows, 'Refunds of Finance-mapped payments require a posted refund journal.');
    }

    private function lateClosingActivity(int $tenant): array
    {
        $rows = DB::table('daily_closings as closings')->join('journal_entries as entries', function ($join): void {
            $join->on('entries.tenant_id', '=', 'closings.tenant_id')->on('entries.branch_id', '=', 'closings.branch_id')
                ->whereColumn('entries.entry_date', 'closings.business_date')->where('entries.status', '=', 'posted')->whereColumn('entries.posted_at', '>', 'closings.closed_at');
        })->where('closings.tenant_id', $tenant)->where('closings.status', 'closed')->select('closings.id', 'entries.entry_number')->get()
            ->map(fn ($row) => $row->id.':'.$row->entry_number)->all();
        return $this->check('LATE_FINANCIAL_ACTIVITY_AFTER_CLOSE', 'warning', $rows, 'Posted activity dated on a closed day was created after the close snapshot.');
    }

    private function closedPeriodActivity(int $tenant): array
    {
        $rows = DB::table('accounting_periods as periods')->join('journal_entries as entries', function ($join): void {
            $join->on('entries.tenant_id', '=', 'periods.tenant_id')->where('entries.status', '=', 'posted')
                ->whereColumn('entries.entry_date', '>=', 'periods.start_date')->whereColumn('entries.entry_date', '<=', 'periods.end_date')
                ->whereColumn('entries.posted_at', '>', 'periods.closed_at');
        })->where('periods.tenant_id', $tenant)->where('periods.status', 'closed')->select('periods.id', 'entries.entry_number')->get()
            ->map(fn ($row) => $row->id.':'.$row->entry_number)->all();
        return $this->check('POSTING_AFTER_ACCOUNTING_PERIOD_CLOSE', 'critical', $rows, 'A posted journal was created in an already closed accounting period.');
    }

    private function trialBalance(int $tenant): array
    {
        $row = DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->where('lines.tenant_id', $tenant)->where('entries.tenant_id', $tenant)->where('entries.status', 'posted')
            ->selectRaw('COALESCE(SUM(lines.debit),0) as debit, COALESCE(SUM(lines.credit),0) as credit')->first();
        $difference = Money::cents($row->debit) - Money::cents($row->credit);
        return $this->check('TRIAL_BALANCE_IMBALANCE', 'critical', $difference === 0 ? [] : [Money::decimal($difference)], 'Posted trial balance must reconcile to zero.');
    }

    private function balanceSheet(int $tenant): array
    {
        $rows = DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $tenant)->where('entries.tenant_id', $tenant)->where('entries.status', 'posted')
            ->where('accounts.tenant_id', $tenant)->whereNull('accounts.deleted_at')->groupBy('accounts.account_group', 'accounts.normal_balance')
            ->selectRaw('accounts.account_group, accounts.normal_balance, SUM(lines.debit) as debit, SUM(lines.credit) as credit')->get();
        $totals = ['assets' => 0, 'liabilities' => 0, 'equity' => 0];
        $revenue = $costOfSales = $operatingExpenses = 0;
        foreach ($rows as $row) {
            $normal = $row->normal_balance === 'credit' ? Money::cents($row->credit) - Money::cents($row->debit) : Money::cents($row->debit) - Money::cents($row->credit);
            if (isset($totals[$row->account_group])) $totals[$row->account_group] += $normal;
            match ((string) $row->account_group) {
                'revenue' => $revenue += ($row->normal_balance === 'debit' ? -$normal : $normal),
                'cost_of_sales' => $costOfSales += $normal,
                'expenses', 'expense' => $operatingExpenses += $normal,
                default => null,
            };
        }
        $earnings = $revenue - $costOfSales - $operatingExpenses;
        $difference = $totals['assets'] - $totals['liabilities'] - $totals['equity'] - $earnings;
        return $this->check('BALANCE_SHEET_IMBALANCE', 'critical', $difference === 0 ? [] : [[
            'difference' => Money::decimal($difference),
            'assets' => Money::decimal($totals['assets']),
            'liabilities' => Money::decimal($totals['liabilities']),
            'equity' => Money::decimal($totals['equity']),
            'earnings' => Money::decimal($earnings),
            'revenue' => Money::decimal($revenue),
            'costOfSales' => Money::decimal($costOfSales),
            'operatingExpenses' => Money::decimal($operatingExpenses),
            'ledgerGroups' => $rows->map(fn ($row) => [
                'group' => $row->account_group,
                'normalBalance' => $row->normal_balance,
                'debit' => $row->debit,
                'credit' => $row->credit,
            ])->all(),
        ]], 'Assets must equal liabilities plus equity and retained earnings.');
    }

    private function accountsPayable(int $tenant): array
    {
        $invoices = DB::table('supplier_invoices')->where('tenant_id', $tenant)->whereIn('status', ['posted', 'partially_paid', 'paid'])->sum('total_amount');
        $allocated = DB::table('payment_allocations as allocations')->join('supplier_payments as payments', 'payments.id', '=', 'allocations.supplier_payment_id')
            ->where('allocations.tenant_id', $tenant)->where('payments.status', 'posted')->sum('allocations.amount');
        $expected = Money::cents($invoices) - Money::cents($allocated);
        $ap = DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $tenant)->where('entries.tenant_id', $tenant)->where('entries.status', 'posted')->where('accounts.code', '2000')
            ->selectRaw('COALESCE(SUM(lines.debit),0) as debit, COALESCE(SUM(lines.credit),0) as credit')->first();
        $actual = Money::cents($ap->credit) - Money::cents($ap->debit);
        return $this->check('ACCOUNTS_PAYABLE_RECONCILIATION_MISMATCH', 'critical', $expected === $actual ? [] : [Money::decimal($expected - $actual)], 'Posted supplier invoice/payment outstanding must match the AP ledger balance.');
    }

    private function configuration(int $tenant): array
    {
        $readiness = $this->setup->financeReadiness($tenant);
        return $this->check('FINANCE_CONFIGURATION_MISSING', 'critical', $readiness['issues'], 'Required Finance configuration is incomplete.');
    }

    private function check(string $code, string $severity, array $references, string $message): array
    {
        return ['code' => $code, 'severity' => $severity, 'count' => count($references), 'references' => array_values($references), 'message' => $message];
    }
}
