<?php

namespace App\Services;

use App\Support\InventoryDecimal;
use App\Support\InventoryCatalogIdentity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
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

        return ['name' => $nameAr, 'name_ar' => $nameAr, 'name_en' => $nameEn, 'sku' => $sku, 'barcode' => trim((string) ($data['barcode'] ?? '')) ?: null, 'catalog_identity' => InventoryCatalogIdentity::forValues($sku, $nameEn ?: $nameAr, $unit, $data['itemType']), 'item_type' => $data['itemType'], 'category' => trim((string) ($data['category'] ?? '')) ?: null, 'unit' => $unit, 'minimum_stock' => InventoryDecimal::quantity(InventoryDecimal::units($data['minimumStock'] ?? '0')), 'reorder_level' => InventoryDecimal::quantity(InventoryDecimal::units($data['reorderLevel'] ?? $data['minimumStock'] ?? '0')), 'cost_per_unit' => InventoryDecimal::unitCost($cost), 'latest_unit_cost' => InventoryDecimal::unitCost($cost), 'is_active' => $data['isActive'], 'notes' => $data['notes'] ?? null, 'updated_by' => $actorId];
    }
}
