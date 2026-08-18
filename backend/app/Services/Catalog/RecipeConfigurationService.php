<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\ModifierOption;
use App\Models\ModifierOptionRecipeProfile;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\VariantRecipe;
use Brick\Math\BigDecimal;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class RecipeConfigurationService
{
    public function __construct(private readonly MaterialCatalogService $materials, private readonly RecipeUnitRegistry $units, private readonly CatalogAuditService $audit) {}

    public function recipe(ProductVariant $variant): array
    {
        $r = $variant->recipe()->with('components')->first();

        return ['variantId' => $variant->id, 'components' => $r?->components->sortBy('sort_order')->map(fn ($c) => $this->component($c))->values()->all() ?? []];
    }

    public function replaceRecipe(ProductVariant $variant, array $components): array
    {
        $this->activeVariant($variant);
        $this->validateComponents($variant->tenant_id, $components, false);

        return DB::transaction(function () use ($variant, $components) {
            $recipe = VariantRecipe::query()->firstOrCreate(['tenant_id' => $variant->tenant_id, 'product_variant_id' => $variant->id]);
            $before = $this->recipe($variant);
            $recipe->components()->delete();
            foreach ($components as $c) {
                $recipe->components()->create(['tenant_id' => $variant->tenant_id, 'inventory_item_id' => $c['materialId'], 'quantity' => $c['quantity'], 'unit_code' => $c['unitCode'], 'sort_order' => $c['sortOrder'] ?? 0]);
            } $this->audit->log($variant->tenant_id, $variant, MenuAuditAction::Updated, $before, ['recipeComponents' => count($components)]);

            return $this->recipe($variant->fresh('recipe.components'));
        });
    }

    public function profile(ModifierOption $option, ?Product $product = null, ?ProductVariant $variant = null): array
    {
        $this->scope($option, $product, $variant);
        $productId = $variant?->product_id ?? $product?->id;
        $effective = $this->effective($option, $productId, $variant?->id);
        $own = $this->own($option, $productId, $variant?->id);

        return ['optionId' => $option->id, 'scope' => $variant ? 'variant' : ($product ? 'product' : 'global'), 'hasOverride' => $own !== null, 'inheritedFrom' => $own ? null : ($effective?->scope_type ?? null), 'components' => ($own ?? $effective)?->components->sortBy('sort_order')->map(fn ($c) => $this->component($c))->values()->all() ?? []];
    }

    public function replaceProfile(ModifierOption $option, array $components, ?Product $product = null, ?ProductVariant $variant = null): array
    {
        $scope = $this->scope($option, $product, $variant);
        $productId = $variant?->product_id ?? $product?->id;
        $this->validateComponents($option->tenant_id, $components, true);
        if (collect($components)->contains(fn ($c) => $c['operation'] === 'remove') && $this->removeWouldApplyToQuantityEnabledGroup($option, $product, $variant)) {
            throw ValidationException::withMessages(['components' => 'REMOVE adjustments are not allowed for quantity-enabled modifier groups.']);
        }

        return DB::transaction(function () use ($option, $components, $product, $productId, $variant, $scope) {
            $profile = $this->own($option, $productId, $variant?->id) ?? ModifierOptionRecipeProfile::query()->create(['tenant_id' => $option->tenant_id, 'modifier_option_id' => $option->id, 'scope_type' => $scope, 'product_id' => $variant ? null : $product?->id, 'product_variant_id' => $variant?->id]);
            $profile->components()->delete();
            foreach ($components as $c) {
                $profile->components()->create(['tenant_id' => $option->tenant_id, 'inventory_item_id' => $c['materialId'], 'operation' => $c['operation'], 'quantity' => $c['quantity'], 'unit_code' => $c['unitCode'], 'sort_order' => $c['sortOrder'] ?? 0]);
            } $this->audit->log($option->tenant_id, $option, MenuAuditAction::Updated, null, ['recipeProfileScope' => $scope, 'componentCount' => count($components)]);

            return $this->profile($option, $product, $variant);
        });
    }

    public function deleteProfile(ModifierOption $option, ?Product $product = null, ?ProductVariant $variant = null): void
    {
        $this->scope($option, $product, $variant);
        $this->own($option, $variant?->product_id ?? $product?->id, $variant?->id)?->delete();
    }

    public function effective(ModifierOption $option, ?int $productId, ?int $variantId): ?ModifierOptionRecipeProfile
    {
        return ModifierOptionRecipeProfile::query()->where('tenant_id', $option->tenant_id)->where('modifier_option_id', $option->id)->where(fn ($q) => $q->where('scope_type', 'global')->orWhere(fn ($x) => $x->where('scope_type', 'product')->where('product_id', $productId))->orWhere(fn ($x) => $x->where('scope_type', 'variant')->where('product_variant_id', $variantId)))->with('components')->orderByRaw("CASE scope_type WHEN 'variant' THEN 1 WHEN 'product' THEN 2 ELSE 3 END")->first();
    }

    private function own(ModifierOption $option, ?int $productId, ?int $variantId): ?ModifierOptionRecipeProfile
    {
        return ModifierOptionRecipeProfile::query()->where('tenant_id', $option->tenant_id)->where('modifier_option_id', $option->id)->when($variantId, fn ($q) => $q->where('scope_type', 'variant')->where('product_variant_id', $variantId), fn ($q) => ($productId ? $q->where('scope_type', 'product')->where('product_id', $productId) : $q->where('scope_type', 'global')))->with('components')->first();
    }

    private function scope(ModifierOption $option, ?Product $product, ?ProductVariant $variant): string
    {
        if ($option->trashed() || ! $option->modifierGroup || $option->modifierGroup->trashed()) {
            throw ValidationException::withMessages(['option' => 'Archived modifier options and groups are read-only.']);
        }
        if ($variant) {
            $product = $variant->product;
            if ($variant->trashed() || ! $product || $product->trashed()) {
                throw ValidationException::withMessages(['variant' => 'Archived variants and products are read-only.']);
            }
            if (! $product || ! $product->modifierGroups()->whereKey($option->modifier_group_id)->exists()) {
                throw ValidationException::withMessages(['option' => 'Option is not assigned to this product.']);
            }

            return 'variant';
        } if ($product) {
            if ($product->trashed()) {
                throw ValidationException::withMessages(['product' => 'Archived products are read-only.']);
            }
            if (! $product->modifierGroups()->whereKey($option->modifier_group_id)->exists()) {
                throw ValidationException::withMessages(['option' => 'Option is not assigned to this product.']);
            }

            return 'product';
        }

        return 'global';
    }

    private function validateComponents(int $tenant, array $components, bool $operations): void
    {
        $seen = [];
        foreach ($components as $i => $c) {
            $id = (int) ($c['materialId'] ?? 0);
            $op = $c['operation'] ?? 'base';
            if (! $id || isset($seen[$id.':'.$op])) {
                throw ValidationException::withMessages(['components' => 'Duplicate or invalid material component.']);
            }$seen[$id.':'.$op] = true;
            $m = $this->materials->material($tenant, $id);
            if (! $m || ! $m->is_active || $m->deleted_at || ! $this->materials->resource($m)['configurationAvailable']) {
                throw ValidationException::withMessages(['components' => 'Material is unavailable or has an unmapped unit.']);
            } $q = (string) ($c['quantity'] ?? '');
            try {
                $quantity = BigDecimal::of($q);
            } catch (\Throwable) {
                $quantity = BigDecimal::zero();
            }
            if (! preg_match('/^\d+(\.\d{1,6})?$/', $q) || $quantity->isLessThanOrEqualTo(BigDecimal::zero())) {
                throw ValidationException::withMessages(['components' => 'Quantity must be a positive decimal with at most six places.']);
            } $u = $c['unitCode'] ?? '';
            $mu = $this->units->inventoryUnit($m->unit);
            if (! $this->units->compatible($mu, $u)) {
                throw ValidationException::withMessages(['components' => 'Recipe unit is incompatible with the material.']);
            } if ($operations && ! in_array($op, ['add', 'remove'], true)) {
                throw ValidationException::withMessages(['components' => 'Operation must be add or remove.']);
            }
        }
    }

    private function component(object $c): array
    {
        return ['materialId' => (int) $c->inventory_item_id, 'quantity' => $this->units->quantityString((string) $c->quantity), 'unitCode' => $c->unit_code, 'operation' => $c->operation ?? null, 'sortOrder' => $c->sort_order];
    }

    private function activeVariant(ProductVariant $v): void
    {
        if ($v->trashed() || ! $v->product || $v->product->trashed()) {
            throw ValidationException::withMessages(['variant' => 'Archived variants are read-only.']);
        }
    }

    private function effectiveAllowQuantity(Product $p, int $groupId): bool
    {
        $g = $p->modifierGroups()->whereKey($groupId)->first();

        return (bool) ($g?->pivot->allow_quantity_override ?? $g?->allow_quantity);
    }

    private function removeWouldApplyToQuantityEnabledGroup(ModifierOption $option, ?Product $product, ?ProductVariant $variant): bool
    {
        if ($variant) {
            return $this->effectiveAllowQuantity($variant->product, $option->modifier_group_id);
        }
        if ($product) {
            return $this->effectiveAllowQuantity($product, $option->modifier_group_id);
        }

        return DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->where('product_modifier_group.modifier_group_id', $option->modifier_group_id)
            ->where(fn ($query) => $query->where('product_modifier_group.allow_quantity_override', true)->orWhere(fn ($nested) => $nested->whereNull('product_modifier_group.allow_quantity_override')->where('modifier_groups.allow_quantity', true)))
            ->exists();
    }
}
