<?php

namespace App\Services;

use App\Support\InventoryUnitCatalog;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/** Builds the single authoritative read model consumed by all shift screens. */
final class ShiftSnapshotService
{
    public function __construct(private readonly ShiftCashSummaryService $cashSummary) {}

    /** @return array<string, mixed> */
    public function buildSnapshot(int $tenantId, object $shift): array
    {
        $identity = DB::table('shifts as s')->join('branches as b', 'b.id', '=', 's.branch_id')->join('users as u', 'u.id', '=', 's.user_id')
            ->where('s.id', $shift->id)->first(['s.*', 'b.name as branch_name', 'u.name as cashier_name', 'u.username as cashier_code']);
        $shiftId = (int) $shift->id;
        $cash = $this->cashSummary->summarize($tenantId, $shift);
        $paid = DB::table('orders')->where('tenant_id', $tenantId)->where('shift_id', $shiftId)->whereNull('deleted_at')->where('status', 'paid')
            ->selectRaw('COUNT(*) as order_count, COALESCE(SUM(total), 0) as gross, COALESCE(SUM(discount_total), 0) as discounts')->first();
        $refunds = DB::table('payment_refunds')->where('tenant_id', $tenantId)->where('shift_id', $shiftId)->where('status', 'completed');
        $refundTotal = Money::cents((clone $refunds)->sum('amount') ?? '0');
        $statuses = DB::table('orders')->where('tenant_id', $tenantId)->where('shift_id', $shiftId)->whereNull('deleted_at')->groupBy('status')->selectRaw('status, COUNT(*) as count')->pluck('count', 'status');
        $paymentLines = DB::table('payments as p')->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('p.tenant_id', $tenantId)->where('p.shift_id', $shiftId)->where('p.status', 'completed')->whereNull('p.deleted_at')
            ->groupBy(DB::raw('COALESCE(pm.type, p.method)'))->selectRaw('COALESCE(pm.type, p.method) as channel, COUNT(*) as count, COALESCE(SUM(p.amount),0) as amount')->get()
            ->map(fn (object $row) => ['channel' => $this->channel($row->channel), 'amount' => Money::decimal(Money::cents($row->amount)), 'transactionCount' => (int) $row->count])->values();

        $refundedOrders = DB::table('payment_refunds as r')->join('orders as o', 'o.id', '=', 'r.order_id')
            ->where('r.tenant_id', $tenantId)->where('r.shift_id', $shiftId)->where('r.status', 'completed')->groupBy('o.id', 'o.total')
            ->selectRaw('o.id, o.total, SUM(r.amount) as refunded')->get();
        $partial = $refundedOrders->filter(fn (object $row) => Money::cents($row->refunded) < Money::cents($row->total))->count();
        $full = $refundedOrders->filter(fn (object $row) => Money::cents($row->refunded) >= Money::cents($row->total))->count();

        return [
            'identity' => ['id' => $shiftId, 'shiftNumber' => $identity->shift_number ?? 'SH-'.str_pad((string) $shiftId, 6, '0', STR_PAD_LEFT), 'branchName' => $identity->branch_name, 'cashierName' => $identity->cashier_name, 'cashierCode' => $identity->cashier_code ?? '', 'openedAt' => $this->timestamp($identity->opened_at), 'openedBy' => $identity->cashier_name, 'lifecycle' => $identity->status, 'closedAt' => $this->timestamp($identity->closed_at), 'closedBy' => $identity->status === 'closed' ? $identity->cashier_name : null],
            'sales' => ['grossSales' => Money::decimal(Money::cents($paid->gross ?? '0')), 'discounts' => Money::decimal(Money::cents($paid->discounts ?? '0')), 'refunds' => Money::decimal($refundTotal), 'refundCount' => (int) (clone $refunds)->count(), 'orderCount' => (int) ($paid->order_count ?? 0), 'cancelledOrderCount' => (int) ($statuses['cancelled'] ?? 0), 'discountPolicyCount' => $this->discounts($tenantId, $shiftId)->count()],
            'payments' => ['lines' => $paymentLines],
            'orders' => ['completed' => (int) ($statuses['paid'] ?? 0), 'paid' => (int) ($statuses['paid'] ?? 0), 'preparing' => (int) ($statuses['held'] ?? 0), 'open' => (int) ($statuses['draft'] ?? 0), 'cancelled' => (int) ($statuses['cancelled'] ?? 0), 'partiallyRefunded' => $partial, 'fullyRefunded' => $full, 'openOrders' => $this->openOrders($tenantId, $shiftId)],
            'drawer' => ['openingFloat' => $cash['openingCash'], 'cashSales' => $cash['cashSales'], 'cashRefunds' => $cash['cashRefunds'], 'withdrawals' => $cash['withdrawals'], 'deposits' => $cash['deposits'], 'expenses' => $cash['expenses'], 'movements' => $this->movements($tenantId, $shiftId, $shift, $cash)],
            'barCount' => $this->barCount($tenantId, $shift),
            'pendingOperations' => $this->pendingBarChecks($tenantId, $shift),
            'refunds' => $this->refundEntries($tenantId, $shiftId),
            'discounts' => $this->discounts($tenantId, $shiftId)->values(),
            'openingNote' => $identity->notes ?? '',
        ];
    }

    private function channel(?string $value): string
    {
        return in_array($value, ['cash', 'card', 'transfer', 'customer_credit'], true) ? ($value === 'customer_credit' ? 'customerCredit' : $value) : 'other';
    }

    private function openOrders(int $tenant, int $shift): array
    {
        return DB::table('orders')->where('tenant_id', $tenant)->where('shift_id', $shift)->whereNull('deleted_at')->whereIn('status', ['draft', 'held'])->orderBy('opened_at')->get(['order_number', 'total', 'status'])->map(fn (object $row) => ['orderNumber' => $row->order_number, 'amount' => Money::decimal(Money::cents($row->total)), 'stateLabel' => $row->status === 'held' ? 'preparing' : 'open'])->values()->all();
    }

    private function movements(int $tenant, int $shiftId, object $shift, array $cash): array
    {
        $rows = [['kind' => 'openingFloat', 'occurredAt' => $this->timestamp($shift->opened_at), 'description' => 'Opening float', 'amount' => $cash['openingCash']]];
        foreach (DB::table('shift_cash_movements')->where('tenant_id', $tenant)->where('shift_id', $shiftId)->orderBy('created_at')->get() as $row) {
            $rows[] = ['kind' => $row->kind, 'occurredAt' => $this->timestamp($row->created_at), 'description' => $row->description ?? $row->kind, 'amount' => Money::decimal(Money::cents($row->amount) * (in_array($row->kind, ['withdrawal', 'expense'], true) ? -1 : 1))];
        }

        return $rows;
    }

    private function barCount(int $tenant, object $shift): array
    {
        $template = DB::table('bar_check_templates')->where('tenant_id', $tenant)->where('branch_id', $shift->branch_id)->where('is_active', true)->orderByDesc('required_for_shift_close')->first();
        if (! $template) {
            return ['warehouseName' => '', 'lines' => [], 'lastCountedAt' => null];
        } $count = DB::table('stock_counts')->where('tenant_id', $tenant)->where('shift_id', $shift->id)->where('bar_check_template_id', $template->id)->latest('id')->first();
        $lines = DB::table('bar_check_template_lines as t')->join('inventory_items as i', 'i.id', '=', 't.inventory_item_id')->leftJoin('stock_balances as b', fn ($j) => $j->on('b.inventory_item_id', '=', 'i.id')->where('b.tenant_id', $tenant)->where('b.warehouse_id', $template->warehouse_id))->leftJoin('stock_count_lines as c', fn ($j) => $j->on('c.inventory_item_id', '=', 'i.id')->when($count, fn ($q) => $q->where('c.stock_count_id', $count->id), fn ($q) => $q->whereRaw('1=0')))->where('t.tenant_id', $tenant)->where('t.bar_check_template_id', $template->id)->orderBy('t.sort_order')->get(['i.id', 'i.name_ar', 'i.name_en', 'i.sku', 'i.category', 't.count_unit', 'b.quantity_on_hand', 'b.average_unit_cost', 'c.entered_quantity', 'c.is_counted'])->map(fn (object $row) => ['id' => (string) $row->id, 'name' => $row->name_ar ?: $row->name_en, 'sku' => $row->sku ?? '', 'category' => $row->category ?? '', 'unit' => $row->count_unit, 'decimals' => $this->decimals($row->count_unit), 'theoretical' => $row->quantity_on_hand ?? '0', 'unitCost' => $row->average_unit_cost ?? '0', 'counted' => $row->is_counted ? $row->entered_quantity : null, 'note' => ''])->values();

        return ['warehouseName' => DB::table('warehouses')->where('id', $template->warehouse_id)->value('name') ?? '', 'lines' => $lines, 'lastCountedAt' => $this->timestamp($count?->updated_at)];
    }

    private function decimals(?string $unit): int
    {
        return in_array(InventoryUnitCatalog::normalize($unit), ['gram', 'kilogram', 'milliliter', 'liter'], true) ? 2 : 0;
    }

    private function pendingBarChecks(int $tenant, object $shift): array
    {
        return DB::table('bar_check_templates as t')->where('t.tenant_id', $tenant)->where('t.branch_id', $shift->branch_id)->where('t.is_active', true)->where('t.required_for_shift_close', true)->whereNotExists(fn ($q) => $q->selectRaw('1')->from('stock_counts as c')->whereColumn('c.bar_check_template_id', 't.id')->where('c.shift_id', $shift->id)->where('c.status', 'posted'))->get(['t.name'])->map(fn ($t) => ['kind' => 'barCount', 'reference' => $t->name, 'detail' => 'Required bar count is not complete.', 'blocking' => true])->values()->all();
    }

    private function refunds(int $tenant, int $shift): mixed
    {
        return DB::table('order_discounts as d')->join('orders as o', 'o.id', '=', 'd.order_id')->where('d.tenant_id', $tenant)->where('o.shift_id', $shift)->selectRaw("COALESCE(d.discount_name, 'Discount') as policy_name, COUNT(*) as applied_count, COALESCE(SUM(d.discount_amount),0) as amount")->groupBy('d.discount_name')->get()->map(fn ($r) => ['policyName' => $r->policy_name, 'appliedCount' => (int) $r->applied_count, 'amount' => Money::decimal(Money::cents($r->amount))]);
    }

    private function discounts(int $tenant, int $shift): mixed
    {
        return $this->refunds($tenant, $shift);
    }

    private function refundEntries(int $tenant, int $shift): array
    {
        return DB::table('payment_refunds as r')->join('orders as o', 'o.id', '=', 'r.order_id')->join('payments as p', 'p.id', '=', 'r.payment_id')->leftJoin('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')->where('r.tenant_id', $tenant)->where('r.shift_id', $shift)->where('r.status', 'completed')->orderByDesc('r.created_at')->get(['o.order_number', 'r.created_at', 'r.amount', 'r.reason', DB::raw('COALESCE(pm.type,p.method) as channel')])->map(fn ($r) => ['orderNumber' => $r->order_number, 'occurredAt' => $this->timestamp($r->created_at), 'amount' => Money::decimal(Money::cents($r->amount)), 'reason' => $r->reason ?? '', 'channel' => $this->channel($r->channel)])->values()->all();
    }

    private function timestamp(?string $value): ?string
    {
        return $value === null ? null : CarbonImmutable::parse($value, 'UTC')->toIso8601String();
    }
}
