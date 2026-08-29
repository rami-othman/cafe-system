<?php

namespace App\Services\Catalog;

use Illuminate\Support\Facades\DB;

class MaterialCatalogService
{
    public function __construct(private readonly RecipeUnitRegistry $units) {}

    public function list(int $tenant, string $status = 'active', ?string $search = null): array
    {
        $q = DB::table('inventory_items')->where('tenant_id', $tenant);
        if ($status === 'archived') {
            $q->whereNotNull('deleted_at');
        } elseif ($status !== 'all') {
            $q->whereNull('deleted_at')->where('is_active', true);
        } if ($search) {
            $q->where(fn ($x) => $x->whereRaw('LOWER(name) LIKE ?', ['%'.strtolower($search).'%'])->orWhereRaw('LOWER(COALESCE(sku,\'\')) LIKE ?', ['%'.strtolower($search).'%']));
        }

        return $q->orderBy('name')->get()->map(fn ($m) => $this->resource($m))->all();
    }

    public function material(int $tenant, int $id): ?object
    {
        return DB::table('inventory_items')->where('tenant_id', $tenant)->where('id', $id)->first();
    }

    /** @return array<int, object> */
    public function materials(int $tenant, array $ids): array
    {
        return DB::table('inventory_items')
            ->where('tenant_id', $tenant)
            ->whereIn('id', array_values(array_unique(array_map('intval', $ids))))
            ->get()
            ->keyBy('id')
            ->all();
    }

    public function resource(object $m): array
    {
        $unit = $this->units->inventoryUnit($m->unit);

        return ['id' => (int) $m->id, 'name' => $m->name, 'sku' => $m->sku, 'unitCode' => $unit, 'unitFamily' => $unit ? $this->units->family($unit) : null, 'isActive' => (bool) $m->is_active, 'archivedAt' => $m->deleted_at, 'configurationAvailable' => $unit !== null && $m->deleted_at === null && (bool) $m->is_active, 'unavailabilityReason' => $unit ? null : 'unit_unmapped'];
    }
}
