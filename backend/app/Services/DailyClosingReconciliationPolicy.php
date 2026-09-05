<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * The single authoritative reconciliation policy consumed by Daily Closing.
 * Cash reconciliation is a hard close blocker; Card/Bank have no configured
 * daily-required frequency anywhere in the domain today, so unresolved
 * Card/Bank reconciliation is surfaced as a WARNING only, never a blocker.
 */
final class DailyClosingReconciliationPolicy
{
    public function __construct(private readonly BusinessDayRangeResolver $days) {}

    public function evaluate(int $tenant, int $branch, string $date, array $summary): array
    {
        $blockers = [];
        $warnings = [];
        $accounts = [];

        $cashAccounts = $this->cashAccounts($tenant, $branch);
        $cashActive = Money::cents($summary['cash']['openingCash']) > 0 || Money::cents($summary['cash']['cashSales']) > 0;
        if ($cashAccounts->isNotEmpty() && $cashActive) {
            $complete = $this->completed($tenant, 'cash', $date, $cashAccounts);
            $accounts[] = ['kind' => 'cash', 'financialAccountIds' => $cashAccounts->values()->all(), 'required' => true, 'complete' => $complete];
            if (! $complete) {
                $blockers[] = ['code' => 'CASH_RECONCILIATION_INCOMPLETE', 'severity' => 'blocking'];
            }
        }

        foreach ($this->cardAccountsWithActivity($tenant, $branch, $date) as $accountId) {
            $complete = $this->completed($tenant, 'card', $date, collect([$accountId]));
            $accounts[] = ['kind' => 'card', 'financialAccountId' => $accountId, 'required' => true, 'complete' => $complete];
            if (! $complete) {
                $warnings[] = ['code' => 'CARD_RECONCILIATION_INCOMPLETE', 'severity' => 'warning', 'financialAccountId' => $accountId];
            }
        }

        foreach ($this->bankAccountsWithActivity($tenant, $branch, $date) as $accountId) {
            $complete = $this->completed($tenant, 'bank', $date, collect([$accountId]));
            $accounts[] = ['kind' => 'bank', 'financialAccountId' => $accountId, 'required' => true, 'complete' => $complete];
            if (! $complete) {
                $warnings[] = ['code' => 'BANK_RECONCILIATION_INCOMPLETE', 'severity' => 'warning', 'financialAccountId' => $accountId];
            }
        }

        $requiredCount = count($accounts);
        $completedCount = collect($accounts)->where('complete', true)->count();

        return [
            'blockers' => $blockers,
            'warnings' => $warnings,
            'accounts' => $accounts,
            'summary' => [
                'requiredCount' => $requiredCount,
                'completedCount' => $completedCount,
                'incompleteCount' => $requiredCount - $completedCount,
                'blockingCount' => count($blockers),
                'warningCount' => count($warnings),
            ],
        ];
    }

    private function cashAccounts(int $tenant, int $branch): Collection
    {
        return DB::table('financial_locations')->where('tenant_id', $tenant)->where('kind', 'cash')->where('is_active', true)
            ->where(fn ($q) => $q->where('branch_id', $branch)->orWhereNull('branch_id'))
            ->pluck('financial_account_id');
    }

    private function cardAccountsWithActivity(int $tenant, int $branch, string $date): array
    {
        $range = $this->days->resolve($tenant, $branch, $date);

        return DB::table('payments as p')->join('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('p.tenant_id', $tenant)->where('p.branch_id', $branch)->where('p.status', 'completed')
            ->whereNull('p.deleted_at')->where('pm.type', 'card')
            ->whereBetween('p.paid_at', [$range['start'], $range['end']])
            ->distinct()->pluck('pm.financial_account_id')->all();
    }

    private function bankAccountsWithActivity(int $tenant, int $branch, string $date): array
    {
        $day = $this->days->resolve($tenant, $branch, $date)['date'];

        $expenseBank = DB::table('expenses as e')->join('financial_locations as l', 'l.id', '=', 'e.paid_from_financial_location_id')
            ->where('e.tenant_id', $tenant)->where('e.branch_id', $branch)->where('e.status', 'paid')->where('l.kind', 'bank')
            ->whereDate('e.expense_date', $day)->pluck('l.financial_account_id');

        $supplierBank = DB::table('supplier_payments as p')->join('financial_locations as l', 'l.id', '=', 'p.financial_location_id')
            ->where('p.tenant_id', $tenant)->where('p.branch_id', $branch)->where('p.status', 'posted')->where('l.kind', 'bank')
            ->whereDate('p.payment_date', $day)->pluck('l.financial_account_id');

        return $expenseBank->merge($supplierBank)->unique()->values()->all();
    }

    private function completed(int $tenant, string $type, string $date, Collection $accountIds): bool
    {
        if ($accountIds->isEmpty()) {
            return true;
        }

        return DB::table('financial_reconciliations')->where('tenant_id', $tenant)->where('type', $type)->where('status', 'completed')
            ->whereDate('date_from', '<=', $date)->whereDate('date_to', '>=', $date)
            ->whereIn('financial_account_id', $accountIds->all())->exists();
    }
}
