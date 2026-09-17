<?php

namespace App\Services;

use App\Models\User;
use App\Support\FinanceAccess;
use App\Support\Money;
use App\Support\WarehousePresentation;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Read model behind GET /api/v1/cashier/dashboard.
 *
 * Aggregates only. Every number it returns comes from an existing authoritative
 * source — expected drawer cash is ShiftCashSummaryService verbatim, the POS
 * warehouse is PosInventoryWarehouseResolver (the same rule that decides
 * where a sale deducts stock) — so this service never becomes a second place
 * where an accounting formula lives.
 *
 * It is also a deliberate exposure boundary: no cost, WAC, valuation, COGS,
 * gross/net profit, margin, ledger or account balance is read or emitted here,
 * for any role. Finance and inventory sections are additionally gated by the
 * caller's existing FinanceAccess permissions, so this endpoint can only ever
 * show a subset of what that actor may already read elsewhere.
 */
class CashierDashboardService
{
    public function __construct(
        private readonly ShiftCashSummaryService $cashSummary,
        private readonly PosInventoryWarehouseResolver $posWarehouses,
        private readonly BranchAccessService $branches,
    ) {}

    public function build(Request $request, User $actor, ?int $requestedBranchId): array
    {
        $tenantId = (int) $actor->tenant_id;
        $accessible = $this->branches->accessibleBranchIds($actor);

        $shift = $this->openShiftFor($tenantId, $actor, $accessible, $requestedBranchId);
        $branchId = $shift !== null ? (int) $shift->branch_id : $this->fallbackBranchId($requestedBranchId, $accessible);
        $branch = $branchId === null ? null : DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->first(['name', 'currency']);

        $inventory = $this->inventory($tenantId, $branchId, $shift);
        $sales = $this->sales($tenantId, $shift);
        $finance = $this->finance($request, $tenantId, $branchId, $actor, $shift);

        return [
            'scope' => [
                // Every metric below belongs to this scope and nothing wider.
                // "current_shift" is the Cashier's own open shift; without one
                // only branch-scoped inventory is meaningful.
                'kind' => $shift !== null ? 'current_shift' : 'branch_only',
                'branchId' => $branchId,
                'branchName' => $branch->name ?? null,
                'cashierId' => (int) $actor->id,
                'cashierName' => $actor->name,
                'currency' => $branch->currency ?? null,
                'generatedAt' => now()->toIso8601String(),
            ],
            'shift' => $shift === null ? null : [
                'id' => (int) $shift->id,
                'status' => $shift->status,
                'openedAt' => $shift->opened_at,
                'durationSeconds' => max(0, (int) Carbon::parse($shift->opened_at)->diffInSeconds(now(), false)),
            ],
            'cashDrawer' => $this->cashDrawer($tenantId, $shift),
            'sales' => $sales['sales'],
            'orders' => $sales['orders'],
            'inventory' => $inventory,
            'finance' => $finance,
            'alerts' => $this->alerts($shift, $branchId, $inventory, $sales['orders']),
        ];
    }

    private function openShiftFor(int $tenantId, User $actor, array $accessible, ?int $branchId): ?object
    {
        if ($accessible === []) {
            return null;
        }

        return DB::table('shifts')
            ->where('tenant_id', $tenantId)
            ->where('user_id', $actor->id)
            ->whereIn('branch_id', $accessible)
            ->when($branchId !== null, fn ($query) => $query->where('branch_id', $branchId))
            ->where('status', 'open')
            ->whereNull('deleted_at')
            ->latest('opened_at')
            ->first();
    }

    private function fallbackBranchId(?int $requestedBranchId, array $accessible): ?int
    {
        if ($requestedBranchId !== null) {
            return in_array($requestedBranchId, $accessible, true) ? $requestedBranchId : null;
        }

        return count($accessible) === 1 ? $accessible[0] : null;
    }

    /**
     * Expected drawer cash is ShiftCashSummaryService's figure unchanged. Cash
     * vouchers are reported beside it rather than folded into it: that service
     * is the single authority on what the drawer should hold, and quietly
     * adding terms here would create a second, disagreeing formula.
     *
     * Physically counted cash is never returned for an open shift — the count
     * belongs to the shift-close flow, and revealing the expected figure as if
     * it were counted would defeat the control it exists to provide.
     */
    private function cashDrawer(int $tenantId, ?object $shift): array
    {
        if ($shift === null) {
            return ['available' => false, 'openingCash' => null, 'cashSales' => null, 'cashRefunds' => null, 'expectedCash' => null, 'cashSaleCount' => 0, 'cashRefundCount' => 0];
        }

        $summary = $this->cashSummary->summarize($tenantId, $shift);

        return [
            'available' => true,
            'openingCash' => $summary['openingCash'],
            'cashSales' => $summary['cashSales'],
            'cashRefunds' => $summary['cashRefunds'],
            'expectedCash' => $summary['expectedCash'],
            'cashSaleCount' => $this->cashPaymentCount($tenantId, (int) $shift->id),
            'cashRefundCount' => $this->cashRefundCount($tenantId, (int) $shift->id),
        ];
    }

    private function cashPaymentCount(int $tenantId, int $shiftId): int
    {
        return (int) DB::table('payments as p')
            ->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('p.tenant_id', $tenantId)->where('p.shift_id', $shiftId)
            ->where('p.status', 'completed')->whereNull('p.deleted_at')
            ->where(fn ($q) => $q->where('pm.type', 'cash')->orWhere(fn ($q2) => $q2->whereNull('p.payment_method_id')->where('p.method', 'cash')))
            ->count();
    }

    private function cashRefundCount(int $tenantId, int $shiftId): int
    {
        return (int) DB::table('payment_refunds as r')
            ->join('payments as p', 'p.id', '=', 'r.payment_id')
            ->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('r.tenant_id', $tenantId)->where('r.shift_id', $shiftId)->where('r.status', 'completed')
            ->where(fn ($q) => $q->where('pm.type', 'cash')->orWhere(fn ($q2) => $q2->whereNull('p.payment_method_id')->where('p.method', 'cash')))
            ->count();
    }

    /**
     * Operational sales for the shift: money taken and orders handled. This is
     * a turnover figure, never a profitability one — no cost side is read.
     *
     * @return array{sales: array<string, mixed>, orders: array<string, int>}
     */
    private function sales(int $tenantId, ?object $shift): array
    {
        if ($shift === null) {
            return [
                'sales' => ['available' => false, 'netSales' => null, 'grossSales' => null, 'discounts' => null, 'refunds' => null, 'orderCount' => 0, 'averageOrderValue' => null, 'byMethod' => []],
                'orders' => ['active' => 0, 'held' => 0, 'completed' => 0, 'blockingCount' => 0],
            ];
        }

        $shiftId = (int) $shift->id;

        $paid = DB::table('orders')
            ->where('tenant_id', $tenantId)->where('shift_id', $shiftId)->whereNull('deleted_at')
            ->where('status', 'paid')
            ->selectRaw('COUNT(*) as order_count, COALESCE(SUM(total), 0) as gross, COALESCE(SUM(discount_total), 0) as discounts')
            ->first();

        $refundCents = Money::cents(DB::table('payment_refunds')
            ->where('tenant_id', $tenantId)->where('shift_id', $shiftId)->where('status', 'completed')
            ->sum('amount') ?? '0');
        $grossCents = Money::cents($paid->gross ?? '0');
        $orderCount = (int) ($paid->order_count ?? 0);

        $byMethod = DB::table('payments as p')
            ->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('p.tenant_id', $tenantId)->where('p.shift_id', $shiftId)
            ->where('p.status', 'completed')->whereNull('p.deleted_at')
            ->groupBy(DB::raw('COALESCE(pm.type, p.method)'))
            ->selectRaw('COALESCE(pm.type, p.method) as bucket, COUNT(*) as entries, COALESCE(SUM(p.amount), 0) as amount')
            ->get()
            ->map(fn (object $row) => [
                'method' => (string) $row->bucket,
                'count' => (int) $row->entries,
                'amount' => Money::decimal(Money::cents($row->amount)),
            ])->values()->all();

        $statuses = DB::table('orders')
            ->where('tenant_id', $tenantId)->where('shift_id', $shiftId)->whereNull('deleted_at')
            ->groupBy('status')->selectRaw('status, COUNT(*) as entries')->pluck('entries', 'status');

        $active = (int) ($statuses['draft'] ?? 0);
        $held = (int) ($statuses['held'] ?? 0);

        return [
            'sales' => [
                'available' => true,
                'netSales' => Money::decimal($grossCents - $refundCents),
                'grossSales' => Money::decimal($grossCents),
                'discounts' => Money::decimal(Money::cents($paid->discounts ?? '0')),
                'refunds' => Money::decimal($refundCents),
                'orderCount' => $orderCount,
                'averageOrderValue' => Money::decimal($orderCount > 0 ? intdiv($grossCents, $orderCount) : 0),
                'byMethod' => $byMethod,
            ],
            'orders' => [
                'active' => $active,
                'held' => $held,
                'completed' => (int) ($statuses['paid'] ?? 0),
                // Unpaid drafts and holds are what a shift close has to resolve.
                'blockingCount' => $active + $held,
            ],
        ];
    }

    /**
     * Quantities only, for the one warehouse this Cashier's sales consume.
     * No average_unit_cost and no valuation is selected at any point.
     */
    private function inventory(int $tenantId, ?int $branchId, ?object $shift): array
    {
        $empty = ['warehouseId' => null, 'warehouseName' => null, 'warehouseTypeLabel' => null, 'configured' => false, 'ambiguous' => false, 'totalItems' => 0, 'lowStockCount' => 0, 'zeroStockCount' => 0, 'negativeStockCount' => 0, 'shiftCount' => ['required' => false, 'completed' => false, 'pendingTemplates' => 0]];
        if ($branchId === null) {
            return $empty;
        }

        $resolved = $this->posWarehouses->resolveForDashboard($tenantId, $branchId);
        if ($resolved['id'] === null) {
            return [...$empty, 'ambiguous' => $resolved['ambiguous'], 'shiftCount' => $this->shiftCountStatus($tenantId, $branchId, $shift)];
        }

        $branchName = DB::table('branches')->where('id', $branchId)->value('name');

        $counts = DB::table('stock_balances as balances')
            ->join('inventory_items as items', 'items.id', '=', 'balances.inventory_item_id')
            ->where('balances.tenant_id', $tenantId)
            ->where('balances.warehouse_id', $resolved['id'])
            ->where('items.is_active', true)->whereNull('items.deleted_at')
            ->selectRaw('COUNT(*) as total')
            ->selectRaw('SUM(CASE WHEN balances.quantity_on_hand < 0 THEN 1 ELSE 0 END) as negative')
            ->selectRaw('SUM(CASE WHEN balances.quantity_on_hand = 0 THEN 1 ELSE 0 END) as zero')
            ->selectRaw('SUM(CASE WHEN balances.quantity_on_hand > 0 AND balances.quantity_on_hand <= items.reorder_level THEN 1 ELSE 0 END) as low')
            ->first();

        return [
            'warehouseId' => (int) $resolved['id'],
            'warehouseName' => WarehousePresentation::displayName($branchName, $resolved['row']->type),
            'warehouseTypeLabel' => WarehousePresentation::typeLabel($resolved['row']->type),
            'configured' => true,
            'ambiguous' => false,
            'totalItems' => (int) ($counts->total ?? 0),
            'lowStockCount' => (int) ($counts->low ?? 0),
            'zeroStockCount' => (int) ($counts->zero ?? 0),
            // Reported, never enforced: negative stock is an allowed outcome of
            // selling past zero and must not read as a blocked till.
            'negativeStockCount' => (int) ($counts->negative ?? 0),
            'shiftCount' => $this->shiftCountStatus($tenantId, $branchId, $shift),
        ];
    }

    /** Mirrors ShiftController::close's bar-check gate without duplicating it. */
    private function shiftCountStatus(int $tenantId, int $branchId, ?object $shift): array
    {
        $templates = DB::table('bar_check_templates')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('is_active', true)->where('required_for_shift_close', true)
            ->get(['id']);

        if ($templates->isEmpty() || $shift === null) {
            return ['required' => $templates->isNotEmpty(), 'completed' => false, 'pendingTemplates' => 0];
        }

        $posted = DB::table('stock_counts')
            ->where('tenant_id', $tenantId)->where('shift_id', $shift->id)
            ->where('count_type', 'shift_check')->where('status', 'posted')
            ->pluck('bar_check_template_id')->filter()->map(fn ($id) => (int) $id)->all();

        $pending = $templates->reject(fn (object $template) => in_array((int) $template->id, $posted, true))->count();

        return ['required' => true, 'completed' => $pending === 0, 'pendingTemplates' => $pending];
    }

    /**
     * Counts and cash totals for documents this actor raised during this shift
     * at this branch — never company receivables, payables, expense totals or
     * account balances. Each block stays null unless the actor already holds
     * the matching finance.*.view permission.
     *
     * @return array<string, mixed>
     */
    private function finance(Request $request, int $tenantId, ?int $branchId, User $actor, ?object $shift): array
    {
        $capabilities = [
            'vouchers' => FinanceAccess::allows($request, 'finance.vouchers.view'),
            'purchases' => FinanceAccess::allows($request, 'finance.purchases.view'),
            'sales' => FinanceAccess::allows($request, 'finance.sales.view'),
            'receipts' => FinanceAccess::allows($request, 'finance.receipts.create'),
            'payments' => FinanceAccess::allows($request, 'finance.payments.create'),
        ];

        $finance = ['capabilities' => $capabilities, 'receiptVouchers' => null, 'paymentVouchers' => null, 'purchaseDocumentCount' => null, 'salesInvoiceCount' => null];

        if ($branchId === null || $shift === null) {
            return $finance;
        }

        $from = $shift->opened_at;

        if ($capabilities['vouchers']) {
            $rows = DB::table('finance_documents as d')
                ->join('financial_locations as l', 'l.id', '=', 'd.financial_location_id')
                ->where('d.tenant_id', $tenantId)
                ->where('d.branch_id', $branchId)
                ->where('d.created_by', $actor->id)
                ->where('d.created_at', '>=', $from)
                ->whereIn('d.status', ['draft', 'posted'])
                ->where('l.kind', 'cash')
                ->groupBy('d.document_type')
                ->selectRaw('d.document_type as document_type, COUNT(*) as entries, COALESCE(SUM(d.amount), 0) as amount')
                ->get()->keyBy('document_type');

            foreach (['receipt' => 'receiptVouchers', 'payment' => 'paymentVouchers'] as $type => $key) {
                $row = $rows->get($type);
                $finance[$key] = [
                    'count' => (int) ($row->entries ?? 0),
                    'cashTotal' => Money::decimal(Money::cents($row->amount ?? '0')),
                ];
            }
        }

        if ($capabilities['purchases']) {
            $finance['purchaseDocumentCount'] = (int) DB::table('supplier_invoices')
                ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
                ->where('created_by', $actor->id)->where('created_at', '>=', $from)
                ->whereNull('deleted_at')->count();
        }

        if ($capabilities['sales']) {
            $finance['salesInvoiceCount'] = (int) DB::table('sales_invoices')
                ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
                ->where('created_by', $actor->id)->where('created_at', '>=', $from)->count();
        }

        return $finance;
    }

    /**
     * Operational only. A management target is never an alert here.
     *
     * @return list<array<string, mixed>>
     */
    private function alerts(?object $shift, ?int $branchId, array $inventory, array $orders): array
    {
        $alerts = [];

        if ($branchId === null) {
            $alerts[] = ['severity' => 'danger', 'code' => 'NO_OPERATIONAL_BRANCH'];
        }
        if ($shift === null) {
            $alerts[] = ['severity' => 'info', 'code' => 'NO_OPEN_SHIFT'];
        }
        if ($branchId !== null && ! $inventory['configured']) {
            $alerts[] = ['severity' => 'danger', 'code' => $inventory['ambiguous'] ? 'POS_WAREHOUSE_AMBIGUOUS' : 'POS_WAREHOUSE_NOT_CONFIGURED'];
        }
        if ($orders['blockingCount'] > 0) {
            $alerts[] = ['severity' => 'warning', 'code' => 'ORDERS_BLOCKING_SHIFT_CLOSE', 'count' => $orders['blockingCount']];
        }
        if ($inventory['negativeStockCount'] > 0) {
            $alerts[] = ['severity' => 'warning', 'code' => 'NEGATIVE_STOCK_ITEMS', 'count' => $inventory['negativeStockCount']];
        }
        if ($inventory['lowStockCount'] > 0) {
            $alerts[] = ['severity' => 'warning', 'code' => 'LOW_STOCK_ITEMS', 'count' => $inventory['lowStockCount']];
        }
        if ($inventory['shiftCount']['required'] && ! $inventory['shiftCount']['completed']) {
            $alerts[] = ['severity' => 'warning', 'code' => 'SHIFT_COUNT_INCOMPLETE', 'count' => $inventory['shiftCount']['pendingTemplates']];
        }

        return $alerts;
    }
}
