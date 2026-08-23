<?php

namespace App\Services;

use App\Support\InventoryDecimal;
use App\Support\WarehousePresentation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class StockCountService
{
    public function __construct(private readonly StockMovementService $movements, private readonly OperationalAuditService $audit) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        $warehouse = $this->warehouse($tenantId, (int) $data['warehouseId']);

        return (int) DB::table('stock_counts')->insertGetId(['tenant_id' => $tenantId, 'warehouse_id' => $warehouse->id, 'count_date' => $data['countDate'], 'status' => 'draft', 'notes' => $data['notes'] ?? null, 'counted_by' => $actorId, 'created_at' => now(), 'updated_at' => now()]);
    }

    public function upsertLine(int $tenantId, int $countId, array $data): void
    {
        $count = $this->find($tenantId, $countId, true);
        $this->assertEditable($count);
        $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $data['itemId'])->whereNull('deleted_at')->first();
        abort_unless($item, 404, 'الصنف غير موجود.');
        $balance = DB::table('stock_balances')->where(['tenant_id' => $tenantId, 'warehouse_id' => $count->warehouse_id, 'inventory_item_id' => $item->id])->first();
        $expected = InventoryDecimal::units($balance->quantity_on_hand ?? '0');
        $counted = InventoryDecimal::units($data['countedQuantity']);
        $variance = $counted - $expected;
        if ($variance !== 0 && blank($data['reason'] ?? null)) {
            throw ValidationException::withMessages(['reason' => 'سبب الفرق مطلوب عند وجود فرق في الجرد.']);
        }
        DB::table('stock_count_lines')->updateOrInsert(['stock_count_id' => $countId, 'inventory_item_id' => $item->id], ['tenant_id' => $tenantId, 'expected_quantity' => InventoryDecimal::quantity($expected), 'counted_quantity' => InventoryDecimal::quantity($counted), 'variance_quantity' => InventoryDecimal::quantity($variance), 'reason' => $data['reason'] ?? null, 'updated_at' => now(), 'created_at' => now()]);
    }

    public function transition(Request $request, int $tenantId, int $countId, string $action, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $countId, $action, $actorId): void {
            $count = $this->find($tenantId, $countId, true);
            if ($action === 'start') {
                $this->requireStatus($count, 'draft');
                $changes = ['status' => 'in_progress'];
            } elseif ($action === 'submit') {
                $this->requireStatus($count, 'in_progress');
                if (! DB::table('stock_count_lines')->where('stock_count_id', $countId)->exists()) {
                    throw ValidationException::withMessages(['lines' => 'أضف سطر جرد واحداً على الأقل قبل الإرسال.']);
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
            $this->audit->record($request, $tenantId, 'stock_count.'.$action, 'stock_count', $countId, ['status' => $count->status], $changes, $count->warehouse_id, $actorId);
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
        $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->whereNull('deleted_at')->first();
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
