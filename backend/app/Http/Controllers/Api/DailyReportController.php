<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Support\TenantContext;
use Carbon\Carbon;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class DailyReportController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validate([
            'branchId' => ['nullable', 'integer', Rule::exists('branches', 'id')->where(fn (Builder $query) => $query->where('tenant_id', $tenantId)->whereNull('deleted_at'))],
            'date' => ['nullable', 'date_format:Y-m-d'],
        ]);

        $branchId = $data['branchId'] ?? DB::table('branches')->where('tenant_id', $tenantId)->whereIn('id', app(BranchAccessService::class)->accessibleBranchIds($request->attributes->get('auth_user')))->orderBy('id')->value('id');
        abort_unless($branchId, 404, 'No branch is available for this tenant.');

        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->first();
        abort_unless($branch, 404, 'Branch not found.');

        $date = Carbon::createFromFormat('Y-m-d', $data['date'] ?? now()->toDateString())->startOfDay();
        $start = $date->copy();
        $end = $date->copy()->endOfDay();
        $orders = $this->ordersQuery($tenantId, (int) $branchId, $start, $end)->get();
        $orderIds = $orders->pluck('id');
        $refundTotal = $this->refundsQuery($tenantId, (int) $branchId, $start, $end)->sum('amount');
        $grossSales = (float) $orders->sum('subtotal');
        $discounts = (float) $orders->sum('discount_total');
        $tax = (float) $orders->sum('tax_total');
        $netSales = round((float) $orders->sum('total') - (float) $refundTotal, 2);

        return response()->json(['data' => [
            'date' => $date->toDateString(),
            'branch' => ['id' => (int) $branch->id, 'name' => $branch->name, 'currency' => $branch->currency],
            'hasData' => $orders->isNotEmpty(),
            'kpis' => [
                'netSales' => $netSales,
                'grossSales' => $grossSales,
                'totalOrders' => $orders->count(),
                'averageOrder' => $orders->isEmpty() ? 0 : round((float) $orders->avg('total'), 2),
                'discounts' => $discounts,
                'tax' => $tax,
                'refunds' => (float) $refundTotal,
                'expectedCash' => $this->expectedCash($tenantId, (int) $branchId, $start, $end),
            ],
            'hourlySales' => $this->hourlySales($orders),
            'paymentMethods' => $this->paymentMethods($tenantId, (int) $branchId, $start, $end),
            'orderTypes' => $this->orderTypes($orders),
            'topProducts' => $this->topProducts($tenantId, $orderIds),
            'refunds' => $this->refunds($tenantId, (int) $branchId, $start, $end),
            'discounts' => $this->discounts($tenantId, $orderIds),
            'transactions' => $this->transactions($tenantId, $orders),
        ]]);
    }

    private function ordersQuery(int $tenantId, int $branchId, Carbon $start, Carbon $end)
    {
        return DB::table('orders')
            ->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)
            ->whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])
            ->whereBetween('closed_at', [$start, $end])
            ->whereNull('deleted_at');
    }

    private function refundsQuery(int $tenantId, int $branchId, Carbon $start, Carbon $end)
    {
        return DB::table('payment_refunds')
            ->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)
            ->where('status', 'completed')
            ->whereBetween('refunded_at', [$start, $end]);
    }

    private function expectedCash(int $tenantId, int $branchId, Carbon $start, Carbon $end): float
    {
        $openingCash = (float) DB::table('shifts')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->whereBetween('opened_at', [$start, $end])->sum('opening_cash');
        $cashPayments = (float) DB::table('payments')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('method', 'cash')->where('status', 'completed')
            ->whereBetween('paid_at', [$start, $end])->whereNull('deleted_at')->sum('amount');
        $cashRefunds = (float) DB::table('payment_refunds as refunds')
            ->join('payments', 'payments.id', '=', 'refunds.payment_id')
            ->where('refunds.tenant_id', $tenantId)->where('refunds.branch_id', $branchId)
            ->where('refunds.status', 'completed')->where('payments.method', 'cash')
            ->whereBetween('refunds.refunded_at', [$start, $end])->sum('refunds.amount');

        return round($openingCash + $cashPayments - $cashRefunds, 2);
    }

    private function hourlySales($orders): array
    {
        $salesByHour = $orders->groupBy(fn ($order) => Carbon::parse($order->closed_at)->format('H'))
            ->map(fn ($rows) => round((float) $rows->sum('total'), 2));
        $peak = $salesByHour->isEmpty() ? null : $salesByHour->keys()->sortByDesc(fn ($hour) => $salesByHour[$hour])->first();

        return collect(range(0, 23))->map(fn (int $hour) => [
            'label' => Carbon::createFromTime($hour)->format('g a'),
            'value' => (float) ($salesByHour->get(str_pad((string) $hour, 2, '0', STR_PAD_LEFT), 0)),
            'isPeak' => (int) $peak === $hour,
        ])->all();
    }

    private function paymentMethods(int $tenantId, int $branchId, Carbon $start, Carbon $end): array
    {
        $payments = DB::table('payments')->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('status', 'completed')->whereBetween('paid_at', [$start, $end])->whereNull('deleted_at')
            ->selectRaw('method, SUM(amount) as total')->groupBy('method')->get();
        $total = (float) $payments->sum('total');

        return $payments->map(fn ($payment) => [
            'method' => $payment->method,
            'amount' => (float) $payment->total,
            'percent' => $total > 0 ? (int) round(((float) $payment->total / $total) * 100) : 0,
        ])->values()->all();
    }

    private function orderTypes($orders): array
    {
        return $orders->groupBy('type')->map(fn ($rows, string $type) => [
            'type' => $type,
            'count' => $rows->count(),
            'amount' => round((float) $rows->sum('total'), 2),
        ])->values()->all();
    }

    private function topProducts(int $tenantId, $orderIds): array
    {
        if ($orderIds->isEmpty()) {
            return [];
        }

        return DB::table('order_items as items')->leftJoin('products', 'products.id', '=', 'items.product_id')
            ->leftJoin('categories', 'categories.id', '=', 'products.category_id')
            ->where('items.tenant_id', $tenantId)->whereIn('items.order_id', $orderIds)->whereNull('items.deleted_at')
            ->selectRaw('items.product_name as name, COALESCE(categories.name, \'Uncategorized\') as category, SUM(items.quantity) as quantity, SUM(items.total) as revenue')
            ->groupBy('items.product_name', 'categories.name')->orderByDesc('quantity')->limit(10)->get()
            ->map(fn ($item) => ['name' => $item->name, 'category' => $item->category, 'quantity' => (float) $item->quantity, 'revenue' => (float) $item->revenue])->all();
    }

    private function refunds(int $tenantId, int $branchId, Carbon $start, Carbon $end): array
    {
        return DB::table('payment_refunds')
            ->join('orders', 'orders.id', '=', 'payment_refunds.order_id')
            ->leftJoin('customers', 'customers.id', '=', 'orders.customer_id')
            ->where('payment_refunds.tenant_id', $tenantId)
            ->where('payment_refunds.branch_id', $branchId)
            ->where('payment_refunds.status', 'completed')
            ->whereBetween('payment_refunds.refunded_at', [$start, $end])
            ->select(['orders.order_number', 'payment_refunds.reason', 'payment_refunds.amount', 'payment_refunds.refunded_at', 'customers.name as customer_name'])
            ->orderByDesc('payment_refunds.refunded_at')->limit(10)->get()
            ->map(fn ($refund) => ['orderNumber' => $refund->order_number, 'reason' => $refund->reason ?: 'Refund', 'amount' => (float) $refund->amount, 'refundedAt' => $refund->refunded_at, 'customer' => $refund->customer_name ?: 'Walk-in'])->all();
    }

    private function discounts(int $tenantId, $orderIds): array
    {
        if ($orderIds->isEmpty()) {
            return [];
        }

        return DB::table('order_discounts')
            ->join('orders', 'orders.id', '=', 'order_discounts.order_id')
            ->where('order_discounts.tenant_id', $tenantId)->whereIn('order_discounts.order_id', $orderIds)
            ->selectRaw('discount_name as name, discount_type as type, COUNT(*) as usage_count, SUM(discount_amount) as total_value, SUM(orders.total) as revenue_after')
            ->groupBy('discount_name', 'discount_type')->orderByDesc('usage_count')->get()
            ->map(fn ($discount) => ['name' => $discount->name, 'type' => $discount->type, 'usageCount' => (int) $discount->usage_count, 'totalValue' => (float) $discount->total_value, 'revenueAfter' => (float) $discount->revenue_after])->all();
    }

    private function transactions(int $tenantId, $orders): array
    {
        return $orders->sortByDesc('closed_at')->take(20)->map(function ($order) use ($tenantId) {
            $payment = DB::table('payments')->where('tenant_id', $tenantId)->where('order_id', $order->id)->where('status', 'completed')->whereNull('deleted_at')->latest('paid_at')->value('method');
            $customer = $order->customer_id ? DB::table('customers')->where('tenant_id', $tenantId)->where('id', $order->customer_id)->value('name') : null;

            return ['orderNumber' => $order->order_number, 'closedAt' => $order->closed_at, 'customer' => $customer ?: 'Walk-in', 'orderType' => $order->type, 'payment' => $payment ?: 'Unknown', 'subtotal' => (float) $order->subtotal, 'discount' => (float) $order->discount_total, 'tax' => (float) $order->tax_total, 'total' => (float) $order->total, 'status' => $order->payment_status];
        })->values()->all();
    }
}
