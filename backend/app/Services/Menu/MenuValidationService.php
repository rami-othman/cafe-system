<?php

namespace App\Services\Menu;

use App\Models\Branch;
use App\Models\Menu;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Services\Catalog\MaterialCatalogService;
use App\Services\Catalog\OperationalAvailabilityResolver;
use App\Services\Catalog\ProductAvailabilityResolver;
use App\Services\Catalog\ProductVariantPriceResolver;
use App\Services\Catalog\RecipeConfigurationService;
use App\Services\Catalog\RecipeUnitRegistry;
use Brick\Math\BigDecimal;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class MenuValidationService
{
    private array $duplicateSkus = [];

    private array $duplicateBarcodes = [];

    public function __construct(private readonly ProductVariantPriceResolver $prices, private readonly ProductAvailabilityResolver $scheduled, private readonly OperationalAvailabilityResolver $operational, private readonly RecipeConfigurationService $recipes, private readonly RecipeUnitRegistry $units, private readonly MaterialCatalogService $materials) {}

    public function menu(int $tenantId, int $menuId): Menu
    {
        return Menu::withTrashed()->where('tenant_id', $tenantId)->findOrFail($menuId);
    }

    public function branch(int $tenantId, int $branchId): Branch
    {
        $branch = Branch::query()->where('tenant_id', $tenantId)->where('is_active', true)->find($branchId);
        if (! $branch) {
            throw ValidationException::withMessages(['branchId' => 'The selected branch is invalid or archived.']);
        }

        return $branch;
    }

    public function validateOne(int $tenantId, Menu $menu, Branch $branch, string $channel, ?string $at): MenuValidationResult
    {
        return $this->validate($tenantId, collect([$menu]), $branch, $channel, $at);
    }

    public function validateCollection(int $tenantId, Branch $branch, string $channel, ?array $menuIds, ?string $at): MenuValidationResult
    {
        $automatic = $menuIds === null;
        if ($menuIds !== null) {
            $menus = Menu::withTrashed()->where('tenant_id', $tenantId)->whereIn('id', $menuIds)->get();
            if ($menus->count() !== count($menuIds)) {
                throw ValidationException::withMessages(['menuIds' => 'One or more selected menus are invalid.']);
            }
        } else {
            $menuIds = $this->assignedMenuIds($tenantId, $branch->id, $channel);
            if ($menuIds === []) {
                $result = new MenuValidationResult;
                $result->noAssignedMenu();

                return $result;
            }
            $menus = Menu::query()->where('tenant_id', $tenantId)->whereIn('id', $menuIds)->get();
        }

        return $this->validate($tenantId, $menus, $branch, $channel, $at, $automatic, $menuIds);
    }

    public function assignedMenuIds(int $tenantId, int $branchId, string $channel): array
    {
        return Menu::query()->where('menus.tenant_id', $tenantId)
            ->join('menu_assignments', fn ($join) => $join->on('menu_assignments.menu_id', '=', 'menus.id')->where('menu_assignments.tenant_id', $tenantId)->where('menu_assignments.branch_id', $branchId)->where('menu_assignments.channel', $channel)->where('menu_assignments.is_active', true))
            ->orderBy('menu_assignments.priority')->orderBy('menus.id')->pluck('menus.id')->all();
    }

    private function validate(int $tenantId, Collection $menus, Branch $branch, string $channel, ?string $at, bool $preserveOrder = false, ?array $orderedIds = null): MenuValidationResult
    {
        $this->duplicateSkus = ProductVariant::query()->where('tenant_id', $tenantId)->where('is_active', true)->whereNotNull('sku')->groupBy('sku')->havingRaw('count(*) > 1')->pluck('sku')->all();
        $this->duplicateBarcodes = ProductVariant::query()->where('tenant_id', $tenantId)->where('is_active', true)->whereNotNull('barcode')->groupBy('barcode')->havingRaw('count(*) > 1')->pluck('barcode')->all();
        $loaded = $this->load($orderedIds ?? $menus->pluck('id')->all(), $preserveOrder);
        $result = new MenuValidationResult;
        $evaluatedAt = CarbonImmutable::parse($at ?? 'now', $branch->timezone ?: config('app.timezone'));
        foreach ($loaded as $menu) {
            $result->begin($menu->id);
            $this->validateMenu($result, $menu, $tenantId, $branch, $channel, $evaluatedAt);
        }

        return $result;
    }

    private function load(array $ids, bool $preserveOrder = false): Collection
    {
        $menus = Menu::withTrashed()->whereIn('id', $ids)->with([
            'assignments', 'availabilityRules' => fn ($query) => $query->withTrashed(),
            'sections' => fn ($query) => $query->withTrashed()->with([
                'placements' => fn ($placements) => $placements->withTrashed()->with([
                    'product' => fn ($products) => $products->withTrashed()->with([
                        'category' => fn ($categories) => $categories->withTrashed(), 'reportingCategory' => fn ($categories) => $categories->withTrashed(), 'kitchenStation' => fn ($stations) => $stations->withTrashed(),
                        'variants' => fn ($variants) => $variants->withTrashed()->with('recipe.components'),
                        'modifierGroups' => fn ($groups) => $groups->withTrashed()->with(['options' => fn ($options) => $options->withTrashed()->with('recipeProfiles.components')]),
                    ]),
                ]),
            ]),
        ])->when(! $preserveOrder, fn ($query) => $query->orderBy('id'))->get();

        if (! $preserveOrder) {
            return $menus;
        }

        $menus = $menus->keyBy('id');

        return collect($ids)->map(fn (int $id) => $menus->get($id))->filter()->values();
    }

    private function validateMenu(MenuValidationResult $result, Menu $menu, int $tenantId, Branch $branch, string $channel, CarbonImmutable $at): void
    {
        if ($menu->trashed()) {
            $this->issue($result, 'MENU_ARCHIVED', 'error', 'The menu is archived.', 'menu', $menu->id, $menu->id);
        }
        $assignments = $menu->assignments->filter(fn ($assignment) => $assignment->branch_id === $branch->id && $this->value($assignment->channel) === $channel && $assignment->is_active);
        if ($assignments->isEmpty()) {
            $this->issue($result, 'MENU_MISSING_ASSIGNMENT', 'error', 'The menu has no active assignment for the requested branch and channel.', 'menu', $menu->id, $menu->id);
        }
        if ($assignments->count() > 1) {
            $this->issue($result, 'DUPLICATE_MENU_ASSIGNMENT', 'error', 'The menu has duplicate active assignments for the requested scope.', 'menu', $menu->id, $menu->id);
        }
        if ($menu->availabilityRules->where('is_active', true)->isEmpty()) {
            $this->issue($result, 'MENU_UNRESTRICTED_SCHEDULE', 'warning', 'The menu has no schedule rules and is unrestricted.', 'menu', $menu->id, $menu->id);
        }
        $sections = $menu->sections->filter(fn ($section) => ! $section->trashed() && $section->is_active);
        if ($sections->isEmpty()) {
            $this->issue($result, 'MENU_NO_ACTIVE_SECTION', 'error', 'The menu has no active section.', 'menu', $menu->id, $menu->id);
        }
        $visible = $sections->flatMap->placements->filter(fn ($placement) => ! $placement->trashed() && $placement->is_visible);
        if ($visible->isEmpty()) {
            $this->issue($result, 'MENU_NO_VISIBLE_PLACEMENT', 'error', 'The menu has no active visible placement.', 'menu', $menu->id, $menu->id);
        }
        foreach ($sections as $section) {
            $this->validateSection($result, $menu, $section, $tenantId, $branch, $channel, $at);
        }
    }

    private function validateSection(MenuValidationResult $result, Menu $menu, object $section, int $tenantId, Branch $branch, string $channel, CarbonImmutable $at): void
    {
        if ($section->tenant_id !== $tenantId || $section->menu_id !== $menu->id) {
            $this->issue($result, 'SECTION_INVALID_OWNERSHIP', 'error', 'The active section belongs to another tenant or menu.', 'section', $section->id, $menu->id, $section->id);
        }
        $placements = $section->placements->filter(fn ($placement) => ! $placement->trashed());
        $visible = $placements->filter(fn ($placement) => $placement->is_visible);
        if ($visible->isEmpty()) {
            $this->issue($result, 'SECTION_EMPTY', 'warning', 'The active section has no visible products.', 'section', $section->id, $menu->id, $section->id);
        }
        $placements->where('is_visible', false)->each(fn ($placement) => $this->issue($result, 'PRODUCT_HIDDEN_PLACEMENT', 'warning', 'A product is hidden through its placement.', 'placement', $placement->id, $menu->id, $section->id, $placement->id));
        $duplicates = $placements->groupBy('product_id')->filter(fn ($items) => $items->count() > 1);
        foreach ($duplicates as $items) {
            $this->issue($result, 'DUPLICATE_PRODUCT_PLACEMENT', 'error', 'The same product has duplicate active placements in this section.', 'product', $items->first()->product_id, $menu->id, $section->id, $items->first()->id);
        }
        foreach ($placements as $placement) {
            $this->validateProduct($result, $menu, $section, $placement, $tenantId, $branch, $channel, $at);
        }
    }

    private function validateProduct(MenuValidationResult $result, Menu $menu, object $section, object $placement, int $tenantId, Branch $branch, string $channel, CarbonImmutable $at): void
    {
        $product = $placement->product;
        if (! $product) {
            $this->issue($result, 'PLACEMENT_PRODUCT_MISSING', 'error', 'The placement references a missing product.', 'placement', $placement->id, $menu->id, $section->id, $placement->id);

            return;
        }
        if ($placement->tenant_id !== $tenantId || $product->tenant_id !== $tenantId) {
            $this->issue($result, 'PRODUCT_TENANT_MISMATCH', 'error', 'The placement product belongs to another tenant.', 'product', $product->id, $menu->id, $section->id, $placement->id);

            return;
        }
        if ($product->trashed() || ! $product->is_active) {
            $this->issue($result, 'PLACEMENT_PRODUCT_ARCHIVED', 'error', 'The placement references an archived product.', 'product', $product->id, $menu->id, $section->id, $placement->id);

            return;
        }
        if (! $product->category || $product->category->trashed() || ! $product->category->is_active) {
            $this->issue($result, 'PRODUCT_CATEGORY_MISSING_OR_ARCHIVED', 'error', 'The product category is missing or archived.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        if (! $product->reportingCategory || $product->reportingCategory->trashed() || ! $product->reportingCategory->is_active) {
            $this->issue($result, 'PRODUCT_REPORTING_CATEGORY_UNAVAILABLE', 'warning', 'The product has no active reporting category.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        if (! $product->kitchenStation || $product->kitchenStation->trashed() || ! $product->kitchenStation->is_active) {
            $this->issue($result, 'PRODUCT_KITCHEN_STATION_UNAVAILABLE', 'warning', 'The product has no active kitchen station.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        } elseif ($product->kitchenStation->tenant_id !== $tenantId || ($product->kitchenStation->branch_id !== null && $product->kitchenStation->branch_id !== $branch->id)) {
            $this->issue($result, 'PRODUCT_KITCHEN_STATION_SCOPE_INVALID', 'warning', 'The kitchen station is not valid for the requested branch.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        if (! $product->image_url) {
            $this->issue($result, 'PRODUCT_MISSING_IMAGE', 'warning', 'The product has no image.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        if (! $product->preparation_time_minutes) {
            $this->issue($result, 'PRODUCT_MISSING_PREPARATION_TIME', 'warning', 'The product has no preparation time.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        if ($this->value($product->product_type) === 'open_price') {
            $this->issue($result, 'PRODUCT_OPEN_PRICE', 'warning', 'The menu contains an open-price product.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        $active = $product->variants->filter(fn ($variant) => ! $variant->trashed() && $variant->is_active);
        if ($active->isEmpty()) {
            $this->issue($result, 'PRODUCT_MISSING_ACTIVE_VARIANT', 'error', 'The product has no active variant.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        $defaults = $active->where('is_default', true);
        if ($defaults->isEmpty()) {
            $this->issue($result, 'PRODUCT_MISSING_ACTIVE_DEFAULT_VARIANT', 'error', 'The product has no active default variant.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        if ($defaults->count() > 1) {
            $this->issue($result, 'PRODUCT_MULTIPLE_ACTIVE_DEFAULT_VARIANTS', 'error', 'The product has more than one active default variant.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        foreach ($product->variants as $variant) {
            if ($variant->is_default && (! $variant->is_active || $variant->trashed())) {
                $this->issue($result, 'DEFAULT_VARIANT_INACTIVE', 'error', 'A default variant is inactive.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
            }
        }
        foreach ($active as $variant) {
            $this->validateVariant($result, $menu, $section, $placement, $product, $variant, $tenantId, $branch, $channel, $at);
        }
        $this->validateModifiers($result, $menu, $section, $placement, $product, $active, $tenantId);
        foreach ($active as $variant) {
            if ($product->is_stock_tracked && $variant->recipe?->components->isNotEmpty()) {
                $this->validateCombinedRecipeRemoves($result, $menu, $section, $placement, $product, $variant);
            }
        }
    }

    private function validateVariant(MenuValidationResult $result, Menu $menu, object $section, object $placement, Product $product, ProductVariant $variant, int $tenantId, Branch $branch, string $channel, CarbonImmutable $at): void
    {
        if ($variant->tenant_id !== $product->tenant_id) {
            $this->issue($result, 'VARIANT_TENANT_MISMATCH', 'error', 'The variant tenant does not match the product tenant.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
        }
        if ((float) $variant->base_price < 0 || (float) $variant->cost_price < 0) {
            $this->issue($result, 'VARIANT_NEGATIVE_PRICE_OR_COST', 'error', 'The active variant has a negative price or cost.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
        }
        if ($variant->sku && in_array($variant->sku, $this->duplicateSkus, true)) {
            $this->issue($result, 'VARIANT_DUPLICATE_ACTIVE_SKU', 'error', 'An active SKU is duplicated within the tenant.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
        }
        if ($variant->barcode && in_array($variant->barcode, $this->duplicateBarcodes, true)) {
            $this->issue($result, 'VARIANT_DUPLICATE_ACTIVE_BARCODE', 'error', 'An active barcode is duplicated within the tenant.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
        }
        $price = $this->prices->resolve($tenantId, $variant->id, $branch->id, $channel);
        if (! is_numeric($price['effectivePrice']) || (float) $price['effectivePrice'] < 0) {
            $this->issue($result, 'VARIANT_INVALID_EFFECTIVE_PRICE', 'error', 'The variant effective price is invalid.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
        }
        if ($price['matchedScope'] === 'base') {
            $this->issue($result, 'VARIANT_BASE_PRICE_FALLBACK', 'warning', 'The variant is using its base price.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
        }
        if ($product->is_stock_tracked) {
            if (! $variant->recipe) {
                $this->issue($result, 'VARIANT_RECIPE_MISSING', 'error', 'A stock-tracked variant requires a recipe.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
            } elseif ($variant->recipe->components->isEmpty()) {
                $this->issue($result, 'VARIANT_RECIPE_EMPTY', 'error', 'A stock-tracked variant recipe cannot be empty.', 'variant', $variant->id, $menu->id, $section->id, $placement->id);
            }
        }
        $this->validateRecipeComponents($result, $menu, $section, $placement, $variant, $tenantId);
        $scheduled = $this->scheduled->resolve($tenantId, $product->id, $variant->id, $branch->id, $channel, $at, $branch->timezone ?: config('app.timezone'));
        if (! $scheduled['isScheduledAvailable']) {
            $this->issue($result, 'PRODUCT_OUTSIDE_SCHEDULE', 'warning', 'The product is outside scheduled availability at the requested time.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        $operational = $this->operational->resolve($tenantId, $product->id, $variant->id, $branch->id, $channel, $at, $branch->timezone ?: config('app.timezone'));
        if (! $operational['isOperationallyAvailable']) {
            $this->issue($result, 'PRODUCT_OPERATIONALLY_UNAVAILABLE', 'warning', 'The product or variant is currently operationally unavailable.', 'variant', $variant->id, $menu->id, $section->id, $placement->id, ['status' => $operational['status']]);
        }
    }

    private function validateRecipeComponents(MenuValidationResult $result, Menu $menu, object $section, object $placement, ProductVariant $variant, int $tenantId): void
    {
        foreach ($variant->recipe?->components ?? [] as $component) {
            $material = $this->materials->material($tenantId, $component->inventory_item_id);
            if (! $material || ! $material->is_active || $material->deleted_at) {
                $this->issue($result, 'RECIPE_COMPONENT_MATERIAL_UNAVAILABLE', 'error', 'A recipe component material is archived, inactive, or unavailable.', 'variant', $variant->id, $menu->id, $section->id, $placement->id, ['materialId' => $component->inventory_item_id]);

                continue;
            }
            $materialUnit = $this->units->inventoryUnit($material->unit);
            if (! $materialUnit) {
                $this->issue($result, 'RECIPE_COMPONENT_MATERIAL_UNIT_UNMAPPED', 'error', 'A recipe component material has no mapped canonical unit.', 'variant', $variant->id, $menu->id, $section->id, $placement->id, ['materialId' => $component->inventory_item_id]);

                continue;
            }
            try {
                $quantity = BigDecimal::of((string) $component->quantity);
                if ($quantity->isLessThanOrEqualTo(BigDecimal::zero())) {
                    throw new \InvalidArgumentException('non-positive');
                }
            } catch (\Throwable) {
                $this->issue($result, 'RECIPE_COMPONENT_QUANTITY_INVALID', 'error', 'A recipe component quantity must be positive.', 'variant', $variant->id, $menu->id, $section->id, $placement->id, ['materialId' => $component->inventory_item_id]);

                continue;
            }
            if (! $this->units->compatible($materialUnit, $component->unit_code)) {
                $this->issue($result, 'RECIPE_COMPONENT_UNIT_INVALID', 'error', 'A recipe component unit is not compatible with its material.', 'variant', $variant->id, $menu->id, $section->id, $placement->id, ['materialId' => $component->inventory_item_id]);
            }
        }
    }

    private function validateModifiers(MenuValidationResult $result, Menu $menu, object $section, object $placement, Product $product, Collection $variants, int $tenantId): void
    {
        foreach ($product->modifierGroups as $group) {
            if ($group->tenant_id !== $tenantId || $group->pivot->tenant_id !== $tenantId) {
                $this->issue($result, 'MODIFIER_GROUP_TENANT_MISMATCH', 'error', 'The assigned modifier group belongs to another tenant.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);

                continue;
            }
            if ($group->trashed() || ! $group->is_active) {
                $this->issue($result, 'MODIFIER_GROUP_ARCHIVED', 'error', 'The assigned modifier group is archived.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);

                continue;
            }
            $required = $group->pivot->is_required_override ?? $group->is_required;
            $min = $group->pivot->min_selections_override ?? $group->min_selections;
            $max = $group->pivot->max_selections_override ?? $group->max_selections;
            $active = $group->options->filter(fn ($option) => ! $option->trashed() && $option->is_active);
            if ($active->isEmpty()) {
                $this->issue($result, 'MODIFIER_GROUP_NO_ACTIVE_OPTION', 'error', 'The modifier group has no active option.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            if ($required && $min < 1) {
                $this->issue($result, 'MODIFIER_REQUIRED_MINIMUM_INVALID', 'error', 'A required modifier group must have a minimum of at least one.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            if ($min > $max) {
                $this->issue($result, 'MODIFIER_MINIMUM_EXCEEDS_MAXIMUM', 'error', 'Modifier minimum exceeds maximum.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            $allowQuantity = (bool) ($group->pivot->allow_quantity_override ?? $group->allow_quantity);
            if (! $allowQuantity && $max > $active->count()) {
                $this->issue($result, 'MODIFIER_MAXIMUM_EXCEEDS_OPTIONS', 'error', 'Modifier maximum exceeds the active option count.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            if ($group->selection_type === 'single' && $max > 1) {
                $this->issue($result, 'MODIFIER_SINGLE_MAXIMUM_INVALID', 'error', 'A single-selection group cannot have a maximum above one.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            if ($active->where('is_default', true)->count() > $max) {
                $this->issue($result, 'MODIFIER_DEFAULTS_EXCEED_MAXIMUM', 'error', 'Default active options exceed the effective maximum.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            foreach ($active as $option) {
                foreach ($variants as $variant) {
                    $this->validateEffectiveModifierProfile($result, $menu, $section, $placement, $product, $variant, $group, $option, $tenantId);
                }
            }
            if (in_array($this->normalized($group->name), ['size', 'sizes', 'cup size', 'الحجم', 'الأحجام'], true)) {
                $this->issue($result, 'LEGACY_SIZE_MODIFIER_GROUP', 'warning', 'A legacy size-like modifier group remains assigned.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
        }
    }

    private function validateEffectiveModifierProfile(MenuValidationResult $result, Menu $menu, object $section, object $placement, Product $product, ProductVariant $variant, object $group, object $option, int $tenantId): void
    {
        $profile = $this->recipes->effective($option, $product->id, $variant->id);
        if (! $profile) {
            return;
        }
        $base = [];
        foreach ($variant->recipe?->components ?? [] as $component) {
            try {
                $normalized = $this->units->normalize((string) $component->quantity, $component->unit_code);
                $base[$component->inventory_item_id] = BigDecimal::of($normalized['quantity']);
            } catch (\Throwable) {
                // The base-component validator reports the underlying configuration issue.
            }
        }
        foreach ($profile->components as $component) {
            $material = $this->materials->material($tenantId, $component->inventory_item_id);
            $materialUnit = $material ? $this->units->inventoryUnit($material->unit) : null;
            try {
                $quantity = BigDecimal::of((string) $component->quantity);
                $valid = $material && $material->is_active && ! $material->deleted_at && $materialUnit && $quantity->isGreaterThan(BigDecimal::zero()) && $this->units->compatible($materialUnit, $component->unit_code) && in_array($component->operation, ['add', 'remove'], true);
            } catch (\Throwable) {
                $valid = false;
            }
            if (! $valid) {
                $this->issue($result, 'MODIFIER_RECIPE_PROFILE_INVALID', 'error', 'An effective modifier recipe profile has an invalid component.', 'modifier_option', $option->id, $menu->id, $section->id, $placement->id, ['variantId' => $variant->id, 'materialId' => $component->inventory_item_id]);

                continue;
            }
            if ($component->operation !== 'remove') {
                continue;
            }
            if ((bool) ($group->pivot->allow_quantity_override ?? $group->allow_quantity)) {
                $this->issue($result, 'MODIFIER_RECIPE_QUANTITY_REMOVE_INVALID', 'error', 'Quantity-enabled modifier groups cannot use REMOVE recipe effects.', 'modifier_option', $option->id, $menu->id, $section->id, $placement->id, ['variantId' => $variant->id]);

                continue;
            }
            $normalized = $this->units->normalize((string) $component->quantity, $component->unit_code);
            $remove = BigDecimal::of($normalized['quantity']);
            if (! isset($base[$component->inventory_item_id]) || $remove->isGreaterThan($base[$component->inventory_item_id])) {
                $this->issue($result, 'MODIFIER_RECIPE_REMOVE_EXCEEDS_BASE', 'error', 'A modifier REMOVE adjustment exceeds the variant base recipe.', 'modifier_option', $option->id, $menu->id, $section->id, $placement->id, ['variantId' => $variant->id, 'materialId' => $component->inventory_item_id]);
            }
        }
    }

    /** Conservative bounded maximum: per group choose the greatest legal remove set, then sum groups. */
    private function validateCombinedRecipeRemoves(MenuValidationResult $result, Menu $menu, object $section, object $placement, Product $product, ProductVariant $variant): void
    {
        $base = [];
        foreach ($variant->recipe->components as $component) {
            try {
                $n = $this->units->normalize($component->quantity, $component->unit_code);
                $base[$component->inventory_item_id] = BigDecimal::of($n['quantity']);
            } catch (\Throwable) {
                continue;
            }
        }
        $max = [];
        foreach ($product->modifierGroups as $group) {
            if ($group->trashed() || ! $group->is_active) {
                continue;
            }
            $allowQuantity = $group->pivot->allow_quantity_override ?? $group->allow_quantity;
            if ($allowQuantity) {
                continue;
            }
            $perMaterial = [];
            foreach ($group->options->filter(fn ($o) => ! $o->trashed() && $o->is_active) as $option) {
                $profile = $this->recipes->effective($option, $product->id, $variant->id);
                foreach ($profile?->components ?? [] as $component) {
                    if ($component->operation === 'remove') {
                        $n = $this->units->normalize($component->quantity, $component->unit_code);
                        $perMaterial[$component->inventory_item_id][] = BigDecimal::of($n['quantity']);
                    }
                }
            }
            $take = $group->selection_type === 'single' ? 1 : (int) ($group->pivot->max_selections_override ?? $group->max_selections);
            foreach ($perMaterial as $materialId => $values) {
                usort($values, fn ($a, $b) => $b->compareTo($a));
                $sum = BigDecimal::zero();
                foreach (array_slice($values, 0, $take) as $value) {
                    $sum = $sum->plus($value);
                } $max[$materialId] = ($max[$materialId] ?? BigDecimal::zero())->plus($sum);
            }
        }
        foreach ($max as $materialId => $remove) {
            if (isset($base[$materialId]) && $remove->isGreaterThan($base[$materialId])) {
                $this->issue($result, 'MODIFIER_RECIPE_COMBINED_REMOVE_EXCEEDS_BASE', 'error', 'Simultaneously selectable modifier removes can exceed the variant base recipe.', 'variant', $variant->id, $menu->id, $section->id, $placement->id, ['materialId' => $materialId, 'baseQuantity' => $base[$materialId]->__toString(), 'maximumRemove' => $remove->__toString()]);
            }
        }
    }

    private function issue(MenuValidationResult $result, string $code, string $severity, string $message, string $type, ?int $entityId, int $menuId, ?int $sectionId = null, ?int $placementId = null, array $metadata = []): void
    {
        $result->add(new MenuValidationIssue($code, $severity, $message, $type, $entityId, $menuId, $sectionId, $placementId, $metadata));
    }

    private function value(mixed $value): mixed
    {
        return $value instanceof \BackedEnum ? $value->value : $value;
    }

    private function normalized(?string $name): string
    {
        return mb_strtolower(trim((string) $name));
    }
}
