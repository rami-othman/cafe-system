<?php

namespace App\Services;

use App\Support\InventoryDecimal;
use App\Support\FinancialActor;
use App\Support\WarehousePresentation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class StockCountService
{
    public function __construct(private readonly StockMovementService $movements, private readonly OperationalAuditService $audit) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        $warehouse = $this->warehouse($tenantId, (int) $data['warehouseId']);
        FinancialActor::assertBranchAccess(
            $actorId,
            $tenantId,
            $warehouse->branch_id ? (int) $warehouse->branch_id : null,
        );

        return DB::transaction(function () use ($tenantId, $warehouse, $data, $actorId): int {
            $categories = array_values(array_filter($data['categoryFilters'] ?? [], fn ($value) => is_string($value) && $value !== ''));
            $countType = $data['countType'] ?? 'full';
            if ($countType === 'cycle' && $categories === []) {
                throw ValidationException::withMessages(['categoryFilters' => 'اختر فئة واحدة على الأقل للجرد الدوري.']);
            }
            // Locking the warehouse serializes count creation for it, so two
            // concurrent requests cannot create the same active count.
            DB::table('warehouses')->where('id', $warehouse->id)->lockForUpdate()->first();
            $hasActiveDuplicate = DB::table('stock_counts')
                ->where('tenant_id', $tenantId)
                ->where('warehouse_id', $warehouse->id)
                ->whereDate('count_date', $data['countDate'])
                ->where('count_type', $countType)
                ->whereIn('status', ['draft', 'in_progress', 'submitted', 'approved'])
                ->exists();
            if ($hasActiveDuplicate) {
                throw ValidationException::withMessages([
                    'warehouseId' => 'يوجد جرد نشط من النوع نفسه لهذا المستودع في التاريخ المحدد.',
                ]);
            }
            $countId = (int) DB::table('stock_counts')->insertGetId([
                'tenant_id' => $tenantId,
                'warehouse_id' => $warehouse->id,
                'count_date' => $data['countDate'],
                'count_type' => $countType,
                'category_filters' => $categories === [] ? null : json_encode($categories),
                'status' => 'draft',
                'notes' => $data['notes'] ?? null,
                'counted_by' => $actorId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $items = DB::table('inventory_items as items')
                ->leftJoin('stock_balances as balances', function ($join) use ($tenantId, $warehouse): void {
                    $join->on('balances.inventory_item_id', '=', 'items.id')
                        ->where('balances.tenant_id', $tenantId)
                        ->where('balances.warehouse_id', $warehouse->id);
                })
                ->where('items.tenant_id', $tenantId)
                ->where('items.is_active', true)
                ->whereNull('items.deleted_at')
                ->whereNotIn('items.item_type', ['non_stock_item', 'service'])
                ->when($categories !== [], fn ($query) => $query->whereIn('items.category', $categories))
                ->when(Schema::hasTable('inventory_item_warehouses'), fn ($query) => $query->whereExists(fn ($assigned) => $assigned
                    ->selectRaw('1')
                    ->from('inventory_item_warehouses as availability')
                    ->whereColumn('availability.inventory_item_id', 'items.id')
                    ->where('availability.tenant_id', $tenantId)
                    ->where('availability.warehouse_id', $warehouse->id)))
                ->orderBy('items.name_en')
                ->get(['items.id', 'balances.quantity_on_hand', 'balances.average_unit_cost']);

            if ($items->isNotEmpty()) {
                DB::table('stock_count_lines')->insert($items->map(fn (object $item) => [
                    'tenant_id' => $tenantId,
                    'stock_count_id' => $countId,
                    'inventory_item_id' => $item->id,
                    'expected_quantity' => InventoryDecimal::quantity(InventoryDecimal::units($item->quantity_on_hand ?? '0')),
                    'counted_quantity' => '0.000',
                    'variance_quantity' => '0.000',
                    'average_unit_cost' => InventoryDecimal::unitCost($item->average_unit_cost ?? '0'),
                    'created_at' => now(),
                    'updated_at' => now(),
                ])->all());
            }

            return $countId;
        });
    }

    public function upsertLine(int $tenantId, int $countId, array $data, ?int $actorId): void
    {
        DB::transaction(function () use ($tenantId, $countId, $data, $actorId): void {
            $count = $this->find($tenantId, $countId, true);
            $this->assertEditable($count);
            $warehouse = $this->warehouse($tenantId, (int) $count->warehouse_id);
            FinancialActor::assertBranchAccess(
                $actorId,
                $tenantId,
                $warehouse->branch_id ? (int) $warehouse->branch_id : null,
            );

            // This row was materialized when the count was created. Its
            // expected quantity and cost are immutable snapshot values.
            $line = DB::table('stock_count_lines')
                ->where('tenant_id', $tenantId)
                ->where('stock_count_id', $countId)
                ->where('inventory_item_id', $data['itemId'])
                ->lockForUpdate()
                ->first();
            abort_unless($line, 404, 'الصنف ليس ضمن أسطر الجرد.');

            $counted = InventoryDecimal::units($data['countedQuantity']);
            if ($counted < 0) {
                throw ValidationException::withMessages([
                    'countedQuantity' => 'الكمية المجرودة لا يمكن أن تكون سالبة.',
                ]);
            }
            $expected = InventoryDecimal::units($line->expected_quantity);
            $variance = $counted - $expected;
            DB::table('stock_count_lines')->where('id', $line->id)->update([
                'counted_quantity' => InventoryDecimal::quantity($counted),
                'variance_quantity' => InventoryDecimal::quantity($variance),
                'reason' => array_key_exists('reason', $data) ? $data['reason'] : $line->reason,
                'counted_at' => now(),
                'updated_at' => now(),
            ]);
        });
    }

    public function transition(Request $request, int $tenantId, int $countId, string $action, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $countId, $action, $actorId): void {
            $count = $this->find($tenantId, $countId, true);
            $warehouseBranchId = DB::table('warehouses')
                ->where('tenant_id', $tenantId)
                ->where('id', $count->warehouse_id)
                ->value('branch_id');
            FinancialActor::assertBranchAccess(
                $actorId,
                $tenantId,
                $warehouseBranchId ? (int) $warehouseBranchId : null,
            );
            if ($action === 'start') {
                $this->requireStatus($count, 'draft');
                $changes = ['status' => 'in_progress'];
            } elseif ($action === 'submit') {
                $this->requireStatus($count, 'in_progress');
                if (DB::table('stock_count_lines')->where('stock_count_id', $countId)->whereNull('counted_at')->exists()) {
                    throw ValidationException::withMessages(['lines' => 'أضف سطر جرد واحداً على الأقل قبل الإرسال.']);
                }
                if (DB::table('stock_count_lines')
                    ->where('stock_count_id', $countId)
                    ->where('variance_quantity', '!=', 0)
                    ->where(fn ($query) => $query->whereNull('reason')->orWhereRaw("TRIM(reason) = ''"))
                    ->exists()) {
                    throw ValidationException::withMessages(['reason' => 'A variance reason is required before submission.']);
                }
                $changes = ['status' => 'submitted', 'submitted_at' => now(), 'counted_by' => $actorId];
            } elseif ($action === 'approve') {
                $this->requireStatus($count, 'submitted');
                $changes = ['status' => 'approved', 'approved_at' => now(), 'approved_by' => $actorId];
            } elseif ($action === 'cancel') {
                if (in_array($count->status, ['posted', 'cancelled'], true)) {
                    throw ValidationException::withMessages(['status' => 'لا يمكن إلغاء جرد مرحّل أو ملغى.']);
                }
                $changes = ['status' => 'cancelled', 'cancelled_at' => now()];
            } else {
                $this->requireStatus($count, 'approved');
                foreach (DB::table('stock_count_lines')->where('stock_count_id', $countId)->lockForUpdate()->get() as $line) {
                    $variance = InventoryDecimal::signedUnits($line->variance_quantity);
                    if ($variance === 0) {
                        continue;
                    }
                    $this->movements->record($request, $tenantId, ['warehouseId' => $count->warehouse_id, 'itemId' => $line->inventory_item_id, 'type' => 'stock_count_variance', 'countDirection' => $variance > 0 ? 'in' : 'out', 'quantity' => InventoryDecimal::quantity(abs($variance)), 'reason' => $line->reason ?: 'فرق جرد', 'referenceType' => 'stock_count', 'referenceId' => $countId, 'occurredAt' => now()], $actorId);
                }
                $changes = ['status' => 'posted', 'posted_at' => now()];
            }
            DB::table('stock_counts')->where('id', $countId)->update($changes + ['updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'stock_count.'.$action, 'stock_count', $countId, ['status' => $count->status], $changes, $warehouseBranchId ? (int) $warehouseBranchId : null, $actorId);
        });
    }

    public function find(int $tenantId, int $countId, bool $lock = false): object
    {
        $query = DB::table('stock_counts')->where('tenant_id', $tenantId)->where('id', $countId);
        if ($lock) {
            $query->lockForUpdate();
        }
        $count = $query->first();
        abort_unless($count, 404, 'سجل الجرد غير موجود.');

        return $count;
    }

    private function warehouse(int $tenantId, int $warehouseId): object
    {
        $warehouse = DB::table('warehouses')
            ->where('tenant_id', $tenantId)
            ->where('id', $warehouseId)
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->first();
        abort_unless($warehouse, 404, 'المخزن غير موجود.');

        if (WarehousePresentation::isLegacy($warehouse->code)) {
            throw ValidationException::withMessages(['warehouseId' => 'Legacy warehouses are read-only and cannot be counted.']);
        }

        return $warehouse;
    }

    private function assertEditable(object $count): void
    {
        if (! in_array($count->status, ['draft', 'in_progress'], true)) {
            throw ValidationException::withMessages(['status' => 'لا يمكن تعديل أسطر الجرد بعد الإرسال.']);
        }
    }

    private function requireStatus(object $count, string $status): void
    {
        if ($count->status !== $status) {
            throw ValidationException::withMessages(['status' => 'حالة الجرد الحالية لا تسمح بهذه العملية.']);
        }
    }
}
