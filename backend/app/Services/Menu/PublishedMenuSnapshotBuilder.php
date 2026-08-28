<?php

namespace App\Services\Menu;

use App\Models\Branch;
use App\Models\Menu;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Services\Catalog\MaterialCatalogService;
use App\Services\Catalog\ProductVariantPriceResolver;
use App\Services\Catalog\RecipeConfigurationService;

/** Builds the static source of truth for a published menu version. */
class PublishedMenuSnapshotBuilder
{
    public function __construct(private readonly ProductVariantPriceResolver $prices, private readonly RecipeConfigurationService $recipes, private readonly MaterialCatalogService $materials) {}

    public function build(int $tenantId, Branch $branch, string $channel, array $menuIds): array
    {
        $menus = Menu::query()->where('tenant_id', $tenantId)->whereIn('id', $menuIds)->with([
            'availabilityRules' => fn ($q) => $q->where('is_active', true)->orderBy('id'),
            'sections' => fn ($q) => $q->where('is_active', true)->orderBy('sort_order')->orderBy('id')->with([
                'placements' => fn ($p) => $p->where('is_visible', true)->orderBy('sort_order')->orderBy('id')->with([
                    'product' => fn ($products) => $products->where('is_active', true)->with([
                        'availabilityRules' => fn ($r) => $r->where('is_active', true)->orderBy('id'),
                        'variants' => fn ($variants) => $variants->where('is_active', true)->with('recipe.components')->orderBy('sort_order')->orderBy('id'),
                        'modifierGroups' => fn ($groups) => $groups->where('is_active', true)->with(['options' => fn ($options) => $options->where('is_active', true)->with('recipeProfiles.components')->orderBy('sort_order')->orderBy('id')]),
                    ]),
                ]),
            ]),
        ])->get()->keyBy('id');
        $menus = collect($menuIds)->map(fn (int $id) => $menus->get($id))->filter()->values();

        return ['context' => ['tenantId' => $tenantId, 'branchId' => $branch->id, 'channel' => $channel, 'schemaVersion' => 2, 'generatedAt' => null], 'menus' => $menus->map(fn (Menu $menu) => $this->menu($tenantId, $menu, $branch, $channel))->values()->all()];
    }

    private function menu(int $tenantId, Menu $menu, Branch $branch, string $channel): array
    {
        return ['id' => $menu->id, 'name' => $this->localized($menu, 'name'), 'description' => $this->localized($menu, 'description'), 'coverImageUrl' => $menu->cover_image_url, 'priority' => $menu->priority,
            'availabilityRules' => $menu->availabilityRules->map(fn ($rule) => $this->rule($rule))->values()->all(),
            'sections' => $menu->sections->map(function ($section) use ($tenantId, $branch, $channel): array {
                return ['id' => $section->id, 'name' => $this->localized($section, 'name'), 'description' => $this->localized($section, 'description'), 'imageUrl' => $section->image_url, 'sortOrder' => $section->sort_order,
                    'products' => $section->placements->filter(fn ($placement) => $placement->product !== null)->map(fn ($placement) => $this->product($tenantId, $placement, $placement->product, $branch, $channel))->values()->all()];
            })->values()->all()];
    }

    private function product(int $tenantId, object $placement, Product $product, Branch $branch, string $channel): array
    {
        return ['placementId' => $placement->id, 'productId' => $product->id,
            'name' => $this->overrideOrLocalized($placement->display_name_override, $product, 'name'), 'description' => $this->overrideOrLocalized($placement->display_description_override, $product, 'description'), 'imageUrl' => $placement->display_image_override ?: $product->image_url,
            'isFeatured' => (bool) $placement->is_featured, 'sortOrder' => $placement->sort_order, 'productType' => $this->value($product->product_type), 'preparationTimeMinutes' => $product->preparation_time_minutes,
            'categoryId' => $product->category_id, 'reportingCategoryId' => $product->reporting_category_id, 'kitchenStationId' => $product->kitchen_station_id,
            'productAvailabilityRules' => $product->availabilityRules->map(fn ($rule) => $this->rule($rule))->values()->all(),
            'variants' => $product->variants->map(fn (ProductVariant $variant) => $this->variant($tenantId, $variant, $branch, $channel, $product))->values()->all(),
            'modifierGroups' => $this->modifiers($product)];
    }

    private function variant(int $tenantId, ProductVariant $variant, Branch $branch, string $channel, Product $product): array
    {
        $price = $this->prices->resolve($tenantId, $variant->id, $branch->id, $channel);

        return ['id' => $variant->id, 'name' => $this->localized($variant, 'name'), 'sku' => $variant->sku, 'barcode' => $variant->barcode, 'sortOrder' => $variant->sort_order, 'isDefault' => (bool) $variant->is_default,
            'basePrice' => $this->decimal($price['basePrice']), 'effectivePrice' => $this->decimal($price['effectivePrice']), 'matchedPriceScope' => $price['matchedScope'],
            'baseRecipe' => ($variant->recipe?->components ?? collect())->sortBy('sort_order')->map(fn ($c) => $this->recipeComponent($tenantId, $c))->values()->all(),
            'modifierRecipeAdjustments' => $product->modifierGroups->flatMap->options->map(function ($option) use ($product, $variant, $tenantId): array {
                $profile = $this->recipes->effective($option, $product->id, $variant->id);

                return ['optionId' => $option->id, 'components' => ($profile?->components ?? collect())->sortBy('sort_order')->map(fn ($c) => $this->recipeComponent($tenantId, $c, true))->values()->all()];
            })->values()->all()];
    }

    private function modifiers(Product $product): array
    {
        return $product->modifierGroups->sort(fn ($a, $b) => (($a->pivot->sort_order ?? 0) <=> ($b->pivot->sort_order ?? 0)) ?: ($a->id <=> $b->id))->map(function ($group): array {
            return ['id' => $group->id, 'name' => $this->localized($group, 'name'), 'groupType' => $this->value($group->group_type), 'selectionType' => $group->selection_type,
                'isRequired' => (bool) ($group->pivot->is_required_override ?? $group->is_required), 'minSelections' => $group->pivot->min_selections_override ?? $group->min_selections,
                'maxSelections' => $group->pivot->max_selections_override ?? $group->max_selections, 'allowQuantity' => (bool) ($group->pivot->allow_quantity_override ?? $group->allow_quantity), 'sortOrder' => $group->pivot->sort_order ?? $group->sort_order,
                'options' => $group->options->map(fn ($option) => ['id' => $option->id, 'name' => $this->localized($option, 'name'), 'priceDelta' => $this->decimal($option->price_delta), 'isDefault' => (bool) $option->is_default, 'isAvailable' => (bool) $option->is_available, 'sortOrder' => $option->sort_order])->values()->all()];
        })->values()->all();
    }

    private function rule(object $rule): array
    {
        return ['id' => $rule->id, 'branchId' => $rule->branch_id, 'channel' => $this->value($rule->channel), 'productVariantId' => $rule->product_variant_id ?? null, 'dayOfWeek' => $rule->day_of_week, 'startTime' => $this->time($rule->start_time), 'endTime' => $this->time($rule->end_time), 'startDate' => $rule->start_date?->toDateString(), 'endDate' => $rule->end_date?->toDateString(), 'priority' => $rule->priority];
    }

    private function recipeComponent(int $tenantId, object $component, bool $hasOperation = false): array
    {
        $material = $this->materials->material($tenantId, $component->inventory_item_id);

        return ['materialId' => $component->inventory_item_id, 'materialName' => $material?->name, 'materialSku' => $material?->sku, 'quantity' => rtrim(rtrim((string) $component->quantity, '0'), '.'), 'unitCode' => $component->unit_code, 'sortOrder' => $component->sort_order] + ($hasOperation ? ['operation' => $component->operation] : []);
    }

    private function localized(object $entity, string $field): array
    {
        return ['default' => $entity->{$field}, 'ar' => $entity->{$field.'_ar'} ?? null, 'en' => $entity->{$field.'_en'} ?? null];
    }

    private function overrideOrLocalized(?string $override, object $entity, string $field): array
    {
        return $override === null || $override === '' ? $this->localized($entity, $field) : ['default' => $override, 'ar' => $override, 'en' => $override];
    }

    private function decimal(mixed $value): string
    {
        return number_format((float) $value, 2, '.', '');
    }

    private function time(mixed $value): ?string
    {
        return $value instanceof \DateTimeInterface ? $value->format('H:i:s') : ($value === null ? null : substr((string) $value, 0, 8));
    }

    private function value(mixed $value): mixed
    {
        return $value instanceof \BackedEnum ? $value->value : $value;
    }
}
