<?php

namespace App\Domain\Manufacturing;

use App\Domain\Inventory\RecipeMaterialEligibility;
use App\Domain\Inventory\UnitConversionResolver;
use App\Support\InventoryDecimal;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Recipes + recipe versioning. A recipe is 1:1 with its output inventory item
 * (manufacturing_recipes.product_item_id is unique per tenant). Editing a
 * recipe never mutates history — it inserts a new immutable
 * manufacturing_recipe_versions row and repoints current_version_id.
 * Production orders reference the exact version they were created against,
 * so past production is unaffected by later recipe edits.
 *
 * Recipe-level "estimated extra costs" (labor/electricity/other) are a
 * memo/estimate only — never capitalized into inventory value, never posted
 * to Finance. See ManufacturingProductionService for the same rule applied
 * to actual production.
 */
final class ManufacturingRecipeService
{
    public function __construct(
        private readonly UnitConversionResolver $conversions,
        private readonly ManufacturingAuditService $audit,
    ) {}

    public function list(int $tenantId, array $filters): array
    {
        $query = DB::table('manufacturing_recipes as r')
            ->join('inventory_items as i', 'i.id', '=', 'r.product_item_id')
            ->join('manufacturing_recipe_versions as v', 'v.id', '=', 'r.current_version_id')
            ->where('r.tenant_id', $tenantId)->whereNull('r.deleted_at')
            ->select('r.id', 'r.status', 'r.product_item_id', 'i.name_en', 'i.name_ar', 'i.item_type', 'v.id as version_id', 'v.version_number', 'v.output_quantity', 'v.output_unit', 'r.updated_at');

        if (! empty($filters['search'])) {
            $search = '%'.strtolower((string) $filters['search']).'%';
            $query->where(fn ($q) => $q->whereRaw('LOWER(i.name_en) LIKE ?', [$search])->orWhereRaw('LOWER(i.name_ar) LIKE ?', [$search]));
        }
        if (! empty($filters['type']) && $filters['type'] !== 'all') {
            $query->where('i.item_type', $filters['type']);
        }
        if (! empty($filters['status']) && $filters['status'] !== 'all') {
            $query->where('r.status', $filters['status']);
        }

        return $query->orderByDesc('r.updated_at')->get()->map(fn ($row) => $this->summarize($tenantId, $row))->all();
    }

    public function get(int $tenantId, int $recipeId): ?array
    {
        $recipe = DB::table('manufacturing_recipes')->where('tenant_id', $tenantId)->where('id', $recipeId)->whereNull('deleted_at')->first();
        if (! $recipe || ! $recipe->current_version_id) {
            return null;
        }

        return $this->detail($tenantId, $recipe);
    }

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $data, $actorId) {
            $item = $this->loadOutputItem($tenantId, (int) $data['productItemId']);
            if (DB::table('manufacturing_recipes')->where('tenant_id', $tenantId)->where('product_item_id', $item->id)->whereNull('deleted_at')->exists()) {
                throw ManufacturingDomainException::validationFailed('productItemId', 'A recipe already exists for this product — edit it instead of creating a new one.');
            }

            $lines = $this->validateLines($tenantId, $item, $data['lines']);
            $this->assertNoCircularDependency($tenantId, (int) $item->id, array_column($lines, 'inventory_item_id'));

            $recipeId = DB::table('manufacturing_recipes')->insertGetId([
                'tenant_id' => $tenantId, 'product_item_id' => $item->id, 'status' => 'active',
                'created_by' => $actorId, 'updated_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
            ]);
            $versionId = $this->insertVersion($tenantId, $recipeId, 1, $data, $lines, $actorId);
            DB::table('manufacturing_recipes')->where('id', $recipeId)->update(['current_version_id' => $versionId]);

            $this->audit->log($tenantId, 'manufacturing_recipe', $recipeId, 'recipe.created', null, ['productItemId' => $item->id, 'versionId' => $versionId], $actorId);

            return $recipeId;
        });
    }

    public function update(Request $request, int $tenantId, int $recipeId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $recipeId, $data, $actorId) {
            $recipe = DB::table('manufacturing_recipes')->where('tenant_id', $tenantId)->where('id', $recipeId)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $recipe) {
                throw ManufacturingDomainException::recipeNotFound();
            }
            $item = $this->loadOutputItem($tenantId, (int) $recipe->product_item_id);

            $lines = $this->validateLines($tenantId, $item, $data['lines']);
            $this->assertNoCircularDependency($tenantId, (int) $item->id, array_column($lines, 'inventory_item_id'));

            $nextVersionNumber = (int) DB::table('manufacturing_recipe_versions')->where('tenant_id', $tenantId)->where('manufacturing_recipe_id', $recipeId)->max('version_number') + 1;
            $versionId = $this->insertVersion($tenantId, $recipeId, $nextVersionNumber, $data, $lines, $actorId);
            DB::table('manufacturing_recipes')->where('id', $recipeId)->update(['current_version_id' => $versionId, 'updated_by' => $actorId, 'updated_at' => now()]);

            $this->audit->log($tenantId, 'manufacturing_recipe', $recipeId, 'recipe.version_created', null, ['versionId' => $versionId, 'versionNumber' => $nextVersionNumber], $actorId);

            return $recipeId;
        });
    }

    public function setStatus(Request $request, int $tenantId, int $recipeId, string $status, ?int $actorId): void
    {
        DB::transaction(function () use ($tenantId, $recipeId, $status, $actorId) {
            $recipe = DB::table('manufacturing_recipes')->where('tenant_id', $tenantId)->where('id', $recipeId)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $recipe) {
                throw ManufacturingDomainException::recipeNotFound();
            }
            DB::table('manufacturing_recipes')->where('id', $recipeId)->update(['status' => $status, 'updated_by' => $actorId, 'updated_at' => now()]);
            $this->audit->log($tenantId, 'manufacturing_recipe', $recipeId, $status === 'active' ? 'recipe.activated' : 'recipe.deactivated', ['status' => $recipe->status], ['status' => $status], $actorId);
        });
    }

    /**
     * A recipe is 1:1 with its output item, so "duplicate" must target a
     * different (existing, recipe-less) inventory item — this is a deliberate
     * deviation from the original frontend mock, which cloned onto a synthetic
     * local id with no real distinct product behind it. See API_CONTRACT.md.
     */
    public function duplicate(Request $request, int $tenantId, int $recipeId, int $targetProductItemId, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $recipeId, $targetProductItemId, $actorId) {
            $source = DB::table('manufacturing_recipes')->where('tenant_id', $tenantId)->where('id', $recipeId)->whereNull('deleted_at')->first();
            if (! $source || ! $source->current_version_id) {
                throw ManufacturingDomainException::recipeNotFound();
            }
            $version = DB::table('manufacturing_recipe_versions')->where('tenant_id', $tenantId)->where('id', $source->current_version_id)->first();
            $lines = DB::table('manufacturing_recipe_version_lines')->where('tenant_id', $tenantId)->where('manufacturing_recipe_version_id', $version->id)->orderBy('sort_order')->get();

            $data = [
                'outputQuantity' => $version->output_quantity, 'outputUnit' => $version->output_unit,
                'shelfLifeValue' => $version->shelf_life_value, 'shelfLifeUnit' => $version->shelf_life_unit,
                'estimatedExtraCosts' => $version->estimated_extra_costs ? json_decode((string) $version->estimated_extra_costs, true) : null,
                'lines' => $lines->map(fn ($l) => ['inventoryItemId' => $l->inventory_item_id, 'quantity' => (string) $l->quantity, 'unit' => $l->unit])->all(),
            ];

            return $this->create($request, $tenantId, ['productItemId' => $targetProductItemId] + $data, $actorId);
        });
    }

    // ---- validation ----

    private function loadOutputItem(int $tenantId, int $itemId): object
    {
        $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $itemId)->whereNull('deleted_at')->first();
        if (! $item) {
            throw ManufacturingDomainException::validationFailed('productItemId', 'Product not found.');
        }
        if (! in_array($item->item_type, ['finished_good', 'semi_finished_good'], true)) {
            throw ManufacturingDomainException::validationFailed('productItemId', 'Only finished_good or semi_finished_good items can have a manufacturing recipe.');
        }

        return $item;
    }

    /** @return list<array{inventory_item_id:int, quantity:string, unit:string}> */
    private function validateLines(int $tenantId, object $outputItem, array $lines): array
    {
        if (empty($lines)) {
            throw ManufacturingDomainException::validationFailed('lines', 'Add at least one ingredient.');
        }
        $seen = [];
        $result = [];
        foreach ($lines as $line) {
            $itemId = (int) $line['inventoryItemId'];
            if (isset($seen[$itemId])) {
                $item = DB::table('inventory_items')->where('id', $itemId)->first();
                throw ManufacturingDomainException::duplicateIngredient($item->name_en ?? (string) $itemId);
            }
            $seen[$itemId] = true;

            if ($itemId === (int) $outputItem->id) {
                throw ManufacturingDomainException::circularRecipe();
            }
            if (! preg_match('/^\d+(\.\d{1,6})?$/', trim((string) $line['quantity'])) || (float) $line['quantity'] <= 0) {
                throw ManufacturingDomainException::validationFailed('quantity', 'Ingredient quantity must be greater than zero.');
            }

            $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $itemId)->whereNull('deleted_at')->first();
            if (! $item) {
                throw ManufacturingDomainException::validationFailed('inventoryItemId', 'Ingredient not found.');
            }
            if (! RecipeMaterialEligibility::allows($item)) {
                throw ManufacturingDomainException::validationFailed('inventoryItemId', "\"{$item->name_en}\" cannot be used as a recipe ingredient.");
            }
            if (! $item->is_active) {
                throw ManufacturingDomainException::itemInactive($item->name_en ?? (string) $itemId);
            }

            try {
                $this->conversions->resolveRecipe($tenantId, $item, (string) $line['quantity'], $line['unit'] ?? null);
            } catch (ValidationException) {
                throw ManufacturingDomainException::missingUnitConversion($item->name_en ?? (string) $itemId, (string) ($line['unit'] ?? $item->unit), (string) $item->unit);
            }

            $result[] = ['inventory_item_id' => $itemId, 'quantity' => (string) $line['quantity'], 'unit' => $line['unit'] ?? $item->unit];
        }

        return $result;
    }

    private function assertNoCircularDependency(int $tenantId, int $productItemId, array $ingredientItemIds): void
    {
        $visited = [];
        foreach ($ingredientItemIds as $ingredientId) {
            if ($this->reaches($tenantId, (int) $ingredientId, $productItemId, $visited)) {
                throw ManufacturingDomainException::circularRecipe();
            }
        }
    }

    private function reaches(int $tenantId, int $fromItemId, int $targetItemId, array &$visited): bool
    {
        if ($fromItemId === $targetItemId) {
            return true;
        }
        if (isset($visited[$fromItemId])) {
            return false;
        }
        $visited[$fromItemId] = true;

        $recipe = DB::table('manufacturing_recipes')->where('tenant_id', $tenantId)->where('product_item_id', $fromItemId)->whereNull('deleted_at')->first();
        if (! $recipe || ! $recipe->current_version_id) {
            return false;
        }
        $ingredientIds = DB::table('manufacturing_recipe_version_lines')->where('tenant_id', $tenantId)->where('manufacturing_recipe_version_id', $recipe->current_version_id)->pluck('inventory_item_id');
        foreach ($ingredientIds as $id) {
            if ($this->reaches($tenantId, (int) $id, $targetItemId, $visited)) {
                return true;
            }
        }

        return false;
    }

    private function insertVersion(int $tenantId, int $recipeId, int $versionNumber, array $data, array $lines, ?int $actorId): int
    {
        if (! (isset($data['outputQuantity']) && (float) $data['outputQuantity'] > 0)) {
            throw ManufacturingDomainException::validationFailed('outputQuantity', 'Output quantity must be greater than zero.');
        }

        $versionId = DB::table('manufacturing_recipe_versions')->insertGetId([
            'tenant_id' => $tenantId, 'manufacturing_recipe_id' => $recipeId, 'version_number' => $versionNumber,
            'output_quantity' => $data['outputQuantity'], 'output_unit' => $data['outputUnit'],
            'shelf_life_value' => $data['shelfLifeValue'] ?? null, 'shelf_life_unit' => $data['shelfLifeUnit'] ?? null,
            'estimated_extra_costs' => isset($data['estimatedExtraCosts']) ? json_encode($data['estimatedExtraCosts']) : null,
            'created_by' => $actorId, 'created_at' => now(),
        ]);

        $rows = [];
        foreach ($lines as $i => $line) {
            $rows[] = ['tenant_id' => $tenantId, 'manufacturing_recipe_version_id' => $versionId, 'inventory_item_id' => $line['inventory_item_id'], 'quantity' => $line['quantity'], 'unit' => $line['unit'], 'sort_order' => $i];
        }
        DB::table('manufacturing_recipe_version_lines')->insert($rows);

        return $versionId;
    }

    // ---- read helpers ----

    private function summarize(int $tenantId, object $row): array
    {
        $cost = $this->materialCost($tenantId, (int) $row->version_id);

        return [
            'id' => (int) $row->id, 'productItemId' => (int) $row->product_item_id,
            'name' => $row->name_ar ?: $row->name_en, 'type' => $row->item_type, 'status' => $row->status,
            'yield' => (string) $row->output_quantity, 'yieldUnit' => $row->output_unit, 'version' => (int) $row->version_number,
            'updatedAt' => $row->updated_at, 'materialsCost' => $cost['hasMissingCost'] ? null : $cost['materialsCost'],
            'unitCost' => $cost['hasMissingCost'] ? null : $cost['unitCost'],
        ];
    }

    private function detail(int $tenantId, object $recipe): array
    {
        $item = DB::table('inventory_items')->where('id', $recipe->product_item_id)->first();
        $version = DB::table('manufacturing_recipe_versions')->where('id', $recipe->current_version_id)->first();
        $lineRows = DB::table('manufacturing_recipe_version_lines as l')
            ->join('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')
            ->where('l.manufacturing_recipe_version_id', $version->id)->orderBy('l.sort_order')
            ->select('l.*', 'i.name_ar', 'i.name_en', 'i.item_type', 'i.unit as base_unit', 'i.cost_per_unit')
            ->get();

        $rows = [];
        $hasMissingCost = false;
        $materialsCostUnits = 0;
        foreach ($lineRows as $l) {
            $item2 = (object) ['id' => $l->inventory_item_id, 'unit' => $l->base_unit];
            try {
                $resolved = $this->conversions->resolveRecipe($tenantId, $item2, (string) $l->quantity, $l->unit);
                $costPerUnit = (int) round(((float) $l->cost_per_unit) * 10000);
                $lineCostUnits = InventoryDecimal::totalCost($resolved['baseQuantity'], $costPerUnit);
                $error = $costPerUnit === 0 ? 'missing-cost' : null;
            } catch (ValidationException) {
                $lineCostUnits = '0.00';
                $error = 'conversion';
            }
            if ($error) {
                $hasMissingCost = true;
            } else {
                $materialsCostUnits += (int) round(((float) $lineCostUnits) * 100);
            }
            $rows[] = [
                'materialId' => (int) $l->inventory_item_id, 'name' => $l->name_ar ?: $l->name_en,
                'semiFinished' => $l->item_type === 'semi_finished_good', 'qty' => (string) $l->quantity, 'unit' => $l->unit,
                'cost' => $error ? null : (float) $lineCostUnits, 'error' => $error,
            ];
        }
        $materialsCost = $hasMissingCost ? null : round($materialsCostUnits / 100, 2);
        $unitCost = $materialsCost !== null && (float) $version->output_quantity > 0 ? round($materialsCost / (float) $version->output_quantity, 4) : null;

        $history = DB::table('manufacturing_orders')->where('tenant_id', $tenantId)->where('manufacturing_recipe_id', $recipe->id)->orderByDesc('created_at')->limit(10)->get();

        return [
            'id' => (int) $recipe->id, 'productItemId' => (int) $item->id, 'name' => $item->name_ar ?: $item->name_en,
            'type' => $item->item_type, 'status' => $recipe->status, 'version' => (int) $version->version_number,
            'yield' => (string) $version->output_quantity, 'yieldUnit' => $version->output_unit,
            'shelfLife' => $version->shelf_life_value !== null, 'shelfValue' => $version->shelf_life_value, 'shelfUnit' => $version->shelf_life_unit,
            'updatedAt' => $recipe->updated_at, 'rows' => $rows, 'hasMissingCost' => $hasMissingCost,
            'materialsCost' => $materialsCost, 'unitCost' => $unitCost,
            'extraCost' => $version->estimated_extra_costs ? array_sum(array_column(json_decode((string) $version->estimated_extra_costs, true), 'amount')) : 0,
            'history' => $history->map(fn ($p) => ['id' => $p->reference ?? ('draft_'.$p->id), 'planned' => (string) $p->planned_quantity, 'actual' => $p->actual_quantity !== null ? (string) $p->actual_quantity : null, 'date' => $p->created_at, 'status' => $p->status])->all(),
        ];
    }

    private function materialCost(int $tenantId, int $versionId): array
    {
        $version = DB::table('manufacturing_recipe_versions')->where('id', $versionId)->first();
        $lineRows = DB::table('manufacturing_recipe_version_lines as l')->join('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')
            ->where('l.manufacturing_recipe_version_id', $versionId)->select('l.*', 'i.unit as base_unit', 'i.cost_per_unit')->get();

        $hasMissingCost = false;
        $totalCents = 0;
        foreach ($lineRows as $l) {
            $item2 = (object) ['id' => $l->inventory_item_id, 'unit' => $l->base_unit];
            try {
                $resolved = $this->conversions->resolveRecipe($tenantId, $item2, (string) $l->quantity, $l->unit);
                $costPerUnit = (int) round(((float) $l->cost_per_unit) * 10000);
                if ($costPerUnit === 0) {
                    $hasMissingCost = true;

                    continue;
                }
                $totalCents += (int) round(((float) InventoryDecimal::totalCost($resolved['baseQuantity'], $costPerUnit)) * 100);
            } catch (ValidationException) {
                $hasMissingCost = true;
            }
        }
        $materialsCost = round($totalCents / 100, 2);
        $unitCost = (float) $version->output_quantity > 0 ? round($materialsCost / (float) $version->output_quantity, 4) : null;

        return ['hasMissingCost' => $hasMissingCost, 'materialsCost' => $materialsCost, 'unitCost' => $unitCost];
    }
}
