<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Carbon\Carbon;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ReportsOverviewController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        if (in_array($request->query('compare_previous'), ['true', 'false'], true)) {
            $request->merge(['compare_previous' => $request->query('compare_previous') === 'true']);
        }

        $data = $request->validate([
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:from'],
            'branch_id' => ['nullable', 'integer'],
            'compare_previous' => ['nullable', 'boolean'],
        ]);

        $tenantId = TenantContext::id($request);
        $branches = $this->availableBranches($request, $tenantId);
        abort_if($branches->isEmpty(), 404, 'No branches are available for this user.');

        $branchId = isset($data['branch_id']) ? (int) $data['branch_id'] : null;
        if ($branchId && ! $branches->contains('id', $branchId)) {
            throw ValidationException::withMessages(['branch_id' => 'The selected branch is not available to this user.']);
        }

        $to = Carbon::createFromFormat('Y-m-d', $data['to'] ?? now()->toDateString())->endOfDay();
        $from = Carbon::createFromFormat('Y-m-d', $data['from'] ?? $to->copy()->subDays(13)->toDateString())->startOfDay();
        $previousTo = $from->copy()->subSecond();
        $previousFrom = $previousTo->copy()->subDays($from->diffInDays($to));
        $branchIds = $branches->pluck('id')->map(fn ($id) => (int) $id)->all();

        $current = $this->period($tenantId, $branchIds, $branchId, $from, $to);
        $previous = (bool) ($data['compare_previous'] ?? true)
            ? $this->period($tenantId, $branchIds, $branchId, $previousFrom, $previousTo)
            : null;

        $selectedBranch = $branchId ? $branches->firstWhere('id', $branchId) : null;
        $currency = (string) ($selectedBranch?->currency ?? $branches->first()?->currency ?? 'SYP');

        return response()->json(['data' => [
            'period' => ['from' => $from->toDateString(), 'to' => $to->toDateString()],
            'currency' => $currency,
            'branches' => $branches->map(fn (object $branch) => [
                'id' => (int) $branch->id,
                'name' => $branch->name,
            ])->values(),
            'selectedBranchId' => $branchId,
            'kpis' => $this->kpis($current, $previous),
            'salesTrend' => $this->salesTrend($tenantId, $branchIds, $branchId, $from, $to),
            'branchComparison' => $branchId ? [] : $this->branchComparison($tenantId, $branchIds, $from, $to),
            'topProducts' => $this->topProducts($tenantId, $branchIds, $branchId, $from, $to),
            'recentExceptions' => $this->exceptions($tenantId, $branchIds, $branchId, $from, $to),
        ]]);
    }

    private function availableBranches(Request $request, int $tenantId): Collection
    {
        $query = DB::table('branches')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at');
        $user = $request->attributes->get('auth_user');
        if (is_array($user) && ($user['role'] ?? null) !== 'owner') {
            $query->whereIn('id', DB::table('user_branches')->where('tenant_id', $tenantId)->where('user_id', (int) $user['id'])->select('branch_id'));
        }

        return $query->orderBy('name')->get(['id', 'name', 'currency']);
    }

    /** @return array{netSales: float, cogs: float, expenses: float, cogsAvailable: bool, expensesAvailable: bool} */
    private function period(int $tenantId, array $allowedBranchIds, ?int $branchId, Carbon $from, Carbon $to): array
    {
        $orders = $this->orders($tenantId, $allowedBranchIds, $branchId, $from, $to)
            ->selectRaw('COALESCE(SUM(total), 0) as sales, COALESCE(SUM(cogs_total), 0) as cogs, COUNT(*) as order_count, SUM(CASE WHEN cogs_total IS NULL THEN 1 ELSE 0 END) as missing_cogs')
            ->first();
        $refunds = $this->refunds($tenantId, $allowedBranchIds, $branchId, $from, $to)->sum('amount');
        $hasExpenseAccounts = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('account_group', 'expenses')->where('is_active', true)->whereNull('deleted_at')->exists();
        $expenseLines = DB::table('journal_entry_lines as lines')
            ->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $tenantId)->where('entries.tenant_id', $tenantId)->where('entries.status', 'posted')
            ->whereBetween('entries.entry_date', [$from->toDateString(), $to->toDateString()])
            ->where('accounts.account_group', 'expenses')
            ->when(
                $branchId,
                fn (Builder $query) => $query->where('entries.branch_id', $branchId),
                fn (Builder $query) => $query->where(function (Builder $query) use ($allowedBranchIds): void {
                    $query->whereIn('entries.branch_id', $allowedBranchIds)->orWhereNull('entries.branch_id');
                }),
            )
            ->selectRaw('COALESCE(SUM(lines.debit - lines.credit), 0) as total')->value('total');

        return [
            'netSales' => round((float) $orders->sales - (float) $refunds, 2),
            'cogs' => round((float) $orders->cogs, 2),
            'expenses' => round((float) $expenseLines, 2),
            'cogsAvailable' => (int) $orders->order_count === 0 || (int) $orders->missing_cogs === 0,
            'expensesAvailable' => $hasExpenseAccounts,
        ];
    }

    private function kpis(array $current, ?array $previous): array
    {
        $grossProfitAvailable = $current['cogsAvailable'];
        $grossProfit = $grossProfitAvailable ? round($current['netSales'] - $current['cogs'], 2) : null;
        $netProfitAvailable = $grossProfitAvailable && $current['expensesAvailable'];
        $values = [
            'netSales' => [$current['netSales'], true, null],
            'grossProfit' => [$grossProfit, $grossProfitAvailable, 'Cost of goods sold has not been recorded for every paid order.'],
            'grossMargin' => [$grossProfitAvailable && $current['netSales'] != 0 ? round(($grossProfit / $current['netSales']) * 100, 2) : null, $grossProfitAvailable && $current['netSales'] != 0, 'Gross margin needs recorded cost of goods sold and net sales.'],
            'totalExpenses' => [$current['expensesAvailable'] ? $current['expenses'] : null, $current['expensesAvailable'], 'No active operating expense accounts are configured.'],
            'netProfit' => [$netProfitAvailable ? round($grossProfit - $current['expenses'], 2) : null, $netProfitAvailable, 'Net profit needs recorded cost of goods sold and operating expenses.'],
        ];

        $previousGrossProfit = $previous && $previous['cogsAvailable'] ? round($previous['netSales'] - $previous['cogs'], 2) : null;
        $previousValues = [
            'netSales' => $previous['netSales'] ?? null,
            'grossProfit' => $previousGrossProfit,
            'grossMargin' => $previousGrossProfit !== null && $previous['netSales'] != 0 ? round(($previousGrossProfit / $previous['netSales']) * 100, 2) : null,
            'totalExpenses' => $previous && $previous['expensesAvailable'] ? $previous['expenses'] : null,
            'netProfit' => $previousGrossProfit !== null && $previous && $previous['expensesAvailable'] ? round($previousGrossProfit - $previous['expenses'], 2) : null,
        ];

        return collect($values)->map(function (array $metric, string $key) use ($previousValues): array {
            [$value, $available, $reason] = $metric;
            $previousValue = $previousValues[$key];
            return [
                'value' => $available ? $value : null,
                'previousValue' => $available ? $previousValue : null,
                'available' => $available,
                'reason' => $available ? null : $reason,
            ];
        })->all();
    }

    private function salesTrend(int $tenantId, array $allowedBranchIds, ?int $branchId, Carbon $from, Carbon $to): array
    {
        $sales = $this->orders($tenantId, $allowedBranchIds, $branchId, $from, $to)
            ->selectRaw('DATE(closed_at) as date, SUM(total) as total')->groupByRaw('DATE(closed_at)')->pluck('total', 'date');
        $refunds = $this->refunds($tenantId, $allowedBranchIds, $branchId, $from, $to)
            ->selectRaw('DATE(refunded_at) as date, SUM(amount) as total')->groupByRaw('DATE(refunded_at)')->pluck('total', 'date');

        return collect(range(0, $from->diffInDays($to)))->map(function (int $offset) use ($from, $sales, $refunds): array {
            $date = $from->copy()->addDays($offset)->toDateString();
            return ['date' => $date, 'netSales' => round((float) ($sales[$date] ?? 0) - (float) ($refunds[$date] ?? 0), 2)];
        })->all();
    }

    private function branchComparison(int $tenantId, array $branchIds, Carbon $from, Carbon $to): array
    {
        $sales = $this->orders($tenantId, $branchIds, null, $from, $to)->selectRaw('branch_id, SUM(total) as total')->groupBy('branch_id')->pluck('total', 'branch_id');
        $refunds = $this->refunds($tenantId, $branchIds, null, $from, $to)->selectRaw('branch_id, SUM(amount) as total')->groupBy('branch_id')->pluck('total', 'branch_id');
        return DB::table('branches')->whereIn('id', $branchIds)->get(['id', 'name'])->map(fn (object $branch) => [
            'id' => (int) $branch->id,
            'name' => $branch->name,
            'netSales' => round((float) ($sales[$branch->id] ?? 0) - (float) ($refunds[$branch->id] ?? 0), 2),
        ])->sortByDesc('netSales')->values()->all();
    }

    private function topProducts(int $tenantId, array $allowedBranchIds, ?int $branchId, Carbon $from, Carbon $to): array
    {
        $refunds = $this->refunds($tenantId, $allowedBranchIds, $branchId, $from, $to)->selectRaw('order_id, SUM(amount) as refund_total')->groupBy('order_id');
        $itemTotals = DB::table('order_items')->where('tenant_id', $tenantId)->whereNull('deleted_at')->selectRaw('order_id, SUM(total) as items_total')->groupBy('order_id');
        return $this->orders($tenantId, $allowedBranchIds, $branchId, $from, $to)
            ->join('order_items as items', 'items.order_id', '=', 'orders.id')
            ->leftJoinSub($refunds, 'refunds', fn ($join) => $join->on('refunds.order_id', '=', 'orders.id'))
            ->joinSub($itemTotals, 'item_totals', fn ($join) => $join->on('item_totals.order_id', '=', 'orders.id'))
            ->whereNull('items.deleted_at')->selectRaw('items.product_name as name, SUM(items.total - (COALESCE(refunds.refund_total, 0) * items.total / NULLIF(item_totals.items_total, 0))) as net_sales')
            ->groupBy('items.product_name')->orderByDesc('net_sales')->limit(5)->get()
            ->map(fn (object $item) => ['name' => $item->name, 'netSales' => round((float) $item->net_sales, 2)])->all();
    }

    private function exceptions(int $tenantId, array $allowedBranchIds, ?int $branchId, Carbon $from, Carbon $to): array
    {
        $filter = $branchId ? [$branchId] : $allowedBranchIds;
        $cash = DB::table('shifts as shifts')->join('branches', 'branches.id', '=', 'shifts.branch_id')
            ->where('shifts.tenant_id', $tenantId)->whereIn('shifts.branch_id', $filter)->where('shifts.status', 'closed')->where('shifts.cash_difference', '!=', 0)
            ->whereBetween('shifts.closed_at', [$from, $to])->select(['shifts.id', 'shifts.cash_difference', 'shifts.closed_at', 'branches.name as branch'])
            ->get()->map(fn (object $shift) => ['severity' => 'critical', 'description' => 'Cash difference of '.number_format((float) $shift->cash_difference, 2).' on closed shift #'.$shift->id, 'branch' => $shift->branch, 'occurredAt' => $shift->closed_at]);
        $stock = DB::table('inventory_items as items')->leftJoin('stock_balances as balances', function ($join) use ($tenantId): void {
            $join->on('balances.inventory_item_id', '=', 'items.id')->where('balances.tenant_id', '=', $tenantId);
        })->leftJoin('warehouses', 'warehouses.id', '=', 'balances.warehouse_id')
            ->where('items.tenant_id', $tenantId)->where('items.is_active', true)->where(fn ($query) => $query->whereNull('warehouses.branch_id')->orWhereIn('warehouses.branch_id', $filter))
            ->selectRaw('COALESCE(items.name_en, items.name) as name, SUM(COALESCE(balances.quantity_on_hand, 0)) as quantity, items.reorder_level, MAX(balances.updated_at) as occurred_at')
            ->groupBy('items.id', 'items.name', 'items.name_en', 'items.reorder_level')->havingRaw('SUM(COALESCE(balances.quantity_on_hand, 0)) <= items.reorder_level')->get()
            ->map(fn (object $item) => ['severity' => (float) $item->quantity <= 0 ? 'critical' : 'warning', 'description' => ((float) $item->quantity <= 0 ? 'Out of stock: ' : 'Low stock: ').$item->name, 'branch' => $branchId ? DB::table('branches')->where('id', $branchId)->value('name') : 'Inventory', 'occurredAt' => $item->occurred_at]);
        return $cash->concat($stock)->sortByDesc('occurredAt')->take(10)->values()->all();
    }

    private function orders(int $tenantId, array $allowedBranchIds, ?int $branchId, Carbon $from, Carbon $to): Builder
    {
        // Columns are qualified with the table name because topProducts()
        // joins order_items (which also has a tenant_id column) onto this
        // query — an unqualified "tenant_id" is ambiguous once that join is
        // added, and every driver rejects it.
        return DB::table('orders')->where('orders.tenant_id', $tenantId)->whereIn('orders.branch_id', $branchId ? [$branchId] : $allowedBranchIds)
            ->whereIn('orders.payment_status', ['paid', 'partially_refunded', 'refunded'])->whereBetween('orders.closed_at', [$from, $to])->whereNull('orders.deleted_at');
    }

    private function refunds(int $tenantId, array $allowedBranchIds, ?int $branchId, Carbon $from, Carbon $to): Builder
    {
        return DB::table('payment_refunds')->where('tenant_id', $tenantId)->whereIn('branch_id', $branchId ? [$branchId] : $allowedBranchIds)
            ->where('status', 'completed')->whereBetween('refunded_at', [$from, $to]);
    }
}
