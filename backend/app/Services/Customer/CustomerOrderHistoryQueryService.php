<?php

namespace App\Services\Customer;

use App\Models\Customer;
use App\Services\BranchAccessService;
use App\Support\Money;
use App\Support\TenantContext;
use Carbon\Carbon;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class CustomerOrderHistoryQueryService
{
    /**
     * Returns the bounded order preview and all-time, financially-recognized
     * customer metrics for the authenticated tenant and accessible branches.
     *
     * Spending includes only the same payment states used by Finance
     * (paid, partially_refunded, refunded), less completed refunds. Draft,
     * held, unpaid and cancelled records stay visible in recent history but
     * never affect spending or average order value.
     */
    public function overview(Request $request, int $customerId): array
    {
        $tenantId = TenantContext::id($request);
        $branchIds = app(BranchAccessService::class)->accessibleBranchIds($request->attributes->get('auth_user'));

        $financial = DB::table('orders')
            ->join('branches', function ($join) use ($tenantId): void {
                $join->on('branches.id', '=', 'orders.branch_id')->where('branches.tenant_id', '=', $tenantId);
            })
            ->where('orders.tenant_id', $tenantId)
            ->where('orders.customer_id', $customerId)
            ->whereIn('orders.branch_id', $branchIds)
            ->whereNull('orders.deleted_at')
            ->whereIn('orders.payment_status', ['paid', 'partially_refunded', 'refunded']);

        $summary = (clone $financial)->selectRaw('COUNT(*) as order_count, COALESCE(SUM(orders.total), 0) as gross_total, COUNT(DISTINCT branches.currency) as currency_count, MIN(branches.currency) as currency, MAX(COALESCE(orders.closed_at, orders.created_at)) as last_order_at')->first();
        $refunds = DB::table('payment_refunds as refunds')
            ->join('orders', 'orders.id', '=', 'refunds.order_id')
            ->where('refunds.tenant_id', $tenantId)
            ->where('orders.tenant_id', $tenantId)
            ->where('orders.customer_id', $customerId)
            ->whereIn('orders.branch_id', $branchIds)
            ->whereNull('orders.deleted_at')
            ->whereIn('orders.payment_status', ['paid', 'partially_refunded', 'refunded'])
            ->where('refunds.status', 'completed')
            ->sum('refunds.amount');

        $count = (int) ($summary->order_count ?? 0);
        $singleCurrency = $count > 0 && (int) $summary->currency_count === 1;
        $netCents = Money::cents($summary->gross_total ?? '0') - Money::cents($refunds ?: '0');
        $money = ! $singleCurrency ? null : ['amount' => Money::decimal($netCents), 'currency' => (string) $summary->currency];

        $recent = DB::table('orders')
            ->join('branches', function ($join) use ($tenantId): void {
                $join->on('branches.id', '=', 'orders.branch_id')->where('branches.tenant_id', '=', $tenantId);
            })
            ->where('orders.tenant_id', $tenantId)
            ->where('orders.customer_id', $customerId)
            ->whereIn('orders.branch_id', $branchIds)
            ->whereNull('orders.deleted_at')
            ->select(['orders.id', 'orders.order_number', 'orders.status', 'orders.payment_status', 'orders.total', 'orders.created_at', 'branches.id as branch_id', 'branches.name as branch_name', 'branches.currency as branch_currency'])
            ->orderByDesc('orders.created_at')
            ->orderByDesc('orders.id')
            ->limit(5)
            ->get()
            ->map(fn ($order) => $this->serialize($order))
            ->all();

        return [
            'summary' => [
                'totalOrders' => $count,
                'totalSpending' => $money,
                'averageOrderValue' => ! $singleCurrency ? null : ['amount' => Money::decimal(intdiv($netCents, $count)), 'currency' => (string) $summary->currency],
                'lastOrderAt' => empty($summary->last_order_at) ? null : Carbon::parse($summary->last_order_at)->utc()->toISOString(),
            ],
            'recentOrders' => $recent,
        ];
    }

    public function paginate(Request $request, int $customerId, array $filters): LengthAwarePaginator
    {
        $tenantId = TenantContext::id($request);
        Customer::withTrashed()->where('tenant_id', $tenantId)->whereKey($customerId)->firstOrFail();
        $branchIds = app(BranchAccessService::class)->accessibleBranchIds($request->attributes->get('auth_user'));
        $query = DB::table('orders')
            ->join('branches', function ($join) use ($tenantId): void {
                $join->on('branches.id', '=', 'orders.branch_id')->where('branches.tenant_id', '=', $tenantId);
            })
            ->where('orders.tenant_id', $tenantId)
            ->where('orders.customer_id', $customerId)
            ->whereIn('orders.branch_id', $branchIds)
            ->select(['orders.id', 'orders.order_number', 'orders.status', 'orders.payment_status', 'orders.total', 'orders.created_at', 'branches.id as branch_id', 'branches.name as branch_name', 'branches.currency as branch_currency']);
        if (isset($filters['branchId'])) $query->where('orders.branch_id', (int) $filters['branchId']);
        if (isset($filters['status'])) $query->where('orders.status', $filters['status']);
        if (isset($filters['paymentStatus'])) $query->where('orders.payment_status', $filters['paymentStatus']);
        if (isset($filters['from'])) $query->whereDate('orders.created_at', '>=', $filters['from']);
        if (isset($filters['to'])) $query->whereDate('orders.created_at', '<=', $filters['to']);

        return $query->orderByDesc('orders.created_at')->orderByDesc('orders.id')->paginate((int) ($filters['perPage'] ?? 25), ['*'], 'page', (int) ($filters['page'] ?? 1));
    }

    public function serialize(object $order): array
    {
        return [
            'id' => (int) $order->id,
            'orderNumber' => (string) $order->order_number,
            'branch' => ['id' => (int) $order->branch_id, 'name' => (string) $order->branch_name],
            'createdAt' => $order->created_at,
            'status' => (string) $order->status,
            'paymentStatus' => (string) $order->payment_status,
            'total' => ['amount' => (string) $order->total, 'currency' => (string) $order->branch_currency],
        ];
    }
}
