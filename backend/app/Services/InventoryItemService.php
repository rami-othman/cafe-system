<?php

namespace App\Services;

use App\Support\InventoryDecimal;
use App\Support\InventoryCatalogIdentity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class InventoryItemService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function save(Request $request, int $tenantId, array $data, ?int $actorId, ?int $itemId = null): int
    {
        return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $itemId): int {
            $before = $itemId ? $this->find($tenantId, $itemId) : null;
            if ($before && $before->unit !== $data['unit'] && (
                DB::table('stock_movements')->where('tenant_id', $tenantId)->where('inventory_item_id', $itemId)->exists()
                || DB::table('inventory_item_unit_conversions')->where('tenant_id', $tenantId)->where('inventory_item_id', $itemId)->exists()
            )) {
                throw ValidationException::withMessages([
                    'unit' => 'The base unit cannot change after stock history or unit conversions exist.',
                ]);
            }
            $payload = $this->payload($data, $actorId) + ['updated_at' => now()];
            if ($itemId) {
                DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $itemId)->update($payload);
                $id = $itemId;
            } else {
                $id = (int) DB::table('inventory_items')->insertGetId($payload + ['tenant_id' => $tenantId, 'created_by' => $actorId, 'created_at' => now()]);
            }
            if (array_key_exists('warehouseIds', $data) && Schema::hasTable('inventory_item_warehouses')) {
                DB::table('inventory_item_warehouses')
                    ->where('tenant_id', $tenantId)
                    ->where('inventory_item_id', $id)
                    ->delete();
                $warehouseIds = collect($data['warehouseIds'])
                    ->map(fn ($id) => (int) $id)
                    ->unique()
                    ->values();
                if ($warehouseIds->isNotEmpty()) {
                    DB::table('inventory_item_warehouses')->insert(
                        $warehouseIds->map(fn (int $warehouseId) => [
                            'tenant_id' => $tenantId,
                            'inventory_item_id' => $id,
                            'warehouse_id' => $warehouseId,
                            'created_at' => now(),
                            'updated_at' => now(),
                        ])->all(),
                    );
                }
            }
            $this->syncFormConversions($tenantId, $id, $data, $actorId);
            $after = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, $itemId ? 'inventory_item.updated' : 'inventory_item.created', 'inventory_item', $id, $before ? (array) $before : [], (array) $after, null, $actorId);

            return $id;
        });
    }

    public function setStatus(Request $request, int $tenantId, int $itemId, bool $active, ?int $actorId): void
    {
        $before = $this->find($tenantId, $itemId);
        DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $itemId)->update(['is_active' => $active, 'updated_by' => $actorId, 'updated_at' => now()]);
        $this->audit->record($request, $tenantId, $active ? 'inventory_item.activated' : 'inventory_item.deactivated', 'inventory_item', $itemId, (array) $before, (array) $this->find($tenantId, $itemId), null, $actorId);
    }

    public function find(int $tenantId, int $itemId): object
    {
        $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $itemId)->whereNull('deleted_at')->first();
        abort_unless($item, 404, 'الصنف غير موجود.');

        return $item;
    }

    private function payload(array $data, ?int $actorId): array
    {
        $cost = InventoryDecimal::cost($data['latestUnitCost'] ?? $data['costPerUnit'] ?? '0');

        $sku = trim((string) ($data['sku'] ?? '')) ?: null;
        $nameAr = trim($data['nameAr']);
        $nameEn = trim((string) ($data['nameEn'] ?? '')) ?: null;
        $unit = trim($data['unit']);

        $payload = ['name' => $nameAr, 'name_ar' => $nameAr, 'name_en' => $nameEn, 'sku' => $sku, 'barcode' => trim((string) ($data['barcode'] ?? '')) ?: null, 'catalog_identity' => InventoryCatalogIdentity::forValues($sku, $nameEn ?: $nameAr, $unit, $data['itemType']), 'item_type' => $data['itemType'], 'category' => trim((string) ($data['category'] ?? '')) ?: null, 'unit' => $unit, 'minimum_stock' => InventoryDecimal::quantity(InventoryDecimal::units($data['minimumStock'] ?? '0')), 'reorder_level' => InventoryDecimal::quantity(InventoryDecimal::units($data['reorderLevel'] ?? $data['minimumStock'] ?? '0')), 'cost_per_unit' => InventoryDecimal::unitCost($cost), 'latest_unit_cost' => InventoryDecimal::unitCost($cost), 'is_active' => $data['isActive'], 'notes' => $data['notes'] ?? null, 'updated_by' => $actorId];
        if (Schema::hasColumn('inventory_items', 'purchase_unit')) {
            $payload += ['purchase_unit' => trim((string) ($data['purchaseUnit'] ?? '')) ?: null, 'consumption_unit' => trim((string) ($data['consumptionUnit'] ?? '')) ?: null, 'last_purchase_cost' => InventoryDecimal::unitCost($data['lastPurchaseCost'] ?? $cost), 'preferred_supplier_name' => trim((string) ($data['preferredSupplierName'] ?? '')) ?: null, 'track_expiry' => (bool) ($data['trackExpiry'] ?? false), 'track_batch' => (bool) ($data['trackBatch'] ?? false)];
        }
        return $payload;
    }

    private function syncFormConversions(int $tenantId, int $itemId, array $data, ?int $actorId): void
    {
        if (! Schema::hasTable('inventory_item_unit_conversions')) {
            return;
        }
        $baseUnit = $data['unit'];
        foreach ([
            ['unit' => $data['purchaseUnit'] ?? null, 'factor' => $data['purchaseConversionFactor'] ?? null],
            ['unit' => $data['consumptionUnit'] ?? null, 'factor' => $data['consumptionConversionFactor'] ?? null],
        ] as $conversion) {
            if (! $conversion['unit'] || $conversion['unit'] === $baseUnit) {
                continue;
            }
            DB::table('inventory_item_unit_conversions')->updateOrInsert(
                [
                    'tenant_id' => $tenantId,
                    'inventory_item_id' => $itemId,
                    'source_unit' => $conversion['unit'],
                    'target_unit' => $baseUnit,
                ],
                [
                    'factor' => number_format((float) $conversion['factor'], 6, '.', ''),
                    'is_active' => true,
                    'updated_by' => $actorId,
                    'updated_at' => now(),
                    'created_by' => $actorId,
                    'created_at' => now(),
                ],
            );
        }
    }
}
