<?php

namespace App\Services;

use App\Support\InventoryUnitCatalog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryItemUnitConversionService
{
    public function __construct(
        private readonly InventoryItemService $items,
        private readonly OperationalAuditService $audit,
    ) {}

    public function index(int $tenantId, int $itemId): array
    {
        $this->items->find($tenantId, $itemId);

        return DB::table('inventory_item_unit_conversions')
            ->where('tenant_id', $tenantId)
            ->where('inventory_item_id', $itemId)
            ->orderByDesc('is_active')
            ->orderBy('source_unit')
            ->orderBy('target_unit')
            ->get()
            ->map(fn (object $conversion) => $this->serialize($conversion))
            ->all();
    }

    public function save(Request $request, int $tenantId, int $itemId, array $data, ?int $actorId, ?int $conversionId = null): array
    {
        return DB::transaction(function () use ($request, $tenantId, $itemId, $data, $actorId, $conversionId): array {
            $this->items->find($tenantId, $itemId);
            $before = $conversionId ? $this->find($tenantId, $itemId, $conversionId) : null;
            $payload = [
                'source_unit' => $data['sourceUnit'],
                'target_unit' => $data['targetUnit'],
                'factor' => number_format((float) $data['factor'], 6, '.', ''),
                'is_active' => $data['isActive'],
                'updated_by' => $actorId,
                'updated_at' => now(),
            ];
            if ($conversionId) {
                DB::table('inventory_item_unit_conversions')
                    ->where('tenant_id', $tenantId)
                    ->where('inventory_item_id', $itemId)
                    ->where('id', $conversionId)
                    ->update($payload);
                $id = $conversionId;
            } else {
                $id = (int) DB::table('inventory_item_unit_conversions')->insertGetId($payload + [
                    'tenant_id' => $tenantId,
                    'inventory_item_id' => $itemId,
                    'created_by' => $actorId,
                    'created_at' => now(),
                ]);
            }
            $after = $this->find($tenantId, $itemId, $id);
            $this->audit->record(
                $request,
                $tenantId,
                $conversionId ? 'inventory_unit_conversion.updated' : 'inventory_unit_conversion.created',
                'inventory_item_unit_conversion',
                $id,
                $before ? (array) $before : [],
                (array) $after,
                null,
                $actorId,
            );

            return $this->serialize($after);
        });
    }

    public function find(int $tenantId, int $itemId, int $conversionId): object
    {
        $conversion = DB::table('inventory_item_unit_conversions')
            ->where('tenant_id', $tenantId)
            ->where('inventory_item_id', $itemId)
            ->where('id', $conversionId)
            ->first();
        abort_unless($conversion, 404, 'The requested unit conversion was not found.');

        return $conversion;
    }

    private function serialize(object $conversion): array
    {
        return [
            'id' => (int) $conversion->id,
            'itemId' => (int) $conversion->inventory_item_id,
            'sourceUnit' => $conversion->source_unit,
            'sourceLabel' => InventoryUnitCatalog::UNITS[$conversion->source_unit],
            'targetUnit' => $conversion->target_unit,
            'targetLabel' => InventoryUnitCatalog::UNITS[$conversion->target_unit],
            'factor' => number_format((float) $conversion->factor, 6, '.', ''),
            'isActive' => (bool) $conversion->is_active,
        ];
    }
}
