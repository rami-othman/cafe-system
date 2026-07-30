<?php

namespace App\Services\Menu;

use App\Models\Branch;
use App\Models\Menu;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Services\Catalog\OperationalAvailabilityResolver;
use App\Services\Catalog\ProductAvailabilityResolver;
use App\Services\Catalog\ProductVariantPriceResolver;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class MenuValidationService
{
    private array $duplicateSkus = [];

    private array $duplicateBarcodes = [];

    public function __construct(private readonly ProductVariantPriceResolver $prices, private readonly ProductAvailabilityResolver $scheduled, private readonly OperationalAvailabilityResolver $operational) {}

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
        if ($menuIds !== null) {
            $menus = Menu::withTrashed()->where('tenant_id', $tenantId)->whereIn('id', $menuIds)->get();
            if ($menus->count() !== count($menuIds)) {
                throw ValidationException::withMessages(['menuIds' => 'One or more selected menus are invalid.']);
            }
        } else {
            $menus = Menu::query()->where('tenant_id', $tenantId)->whereHas('assignments', fn ($query) => $query->where('branch_id', $branch->id)->where('channel', $channel)->where('is_active', true))->get();
        }

        return $this->validate($tenantId, $menus, $branch, $channel, $at);
    }

    private function validate(int $tenantId, Collection $menus, Branch $branch, string $channel, ?string $at): MenuValidationResult
    {
        $this->duplicateSkus = ProductVariant::query()->where('tenant_id', $tenantId)->where('is_active', true)->whereNotNull('sku')->groupBy('sku')->havingRaw('count(*) > 1')->pluck('sku')->all();
        $this->duplicateBarcodes = ProductVariant::query()->where('tenant_id', $tenantId)->where('is_active', true)->whereNotNull('barcode')->groupBy('barcode')->havingRaw('count(*) > 1')->pluck('barcode')->all();
        $loaded = $this->load($menus->pluck('id')->all());
        $result = new MenuValidationResult;
        $evaluatedAt = CarbonImmutable::parse($at ?? 'now', $branch->timezone ?: config('app.timezone'));
        foreach ($loaded as $menu) {
            $result->begin($menu->id);
            $this->validateMenu($result, $menu, $tenantId, $branch, $channel, $evaluatedAt);
        }

        return $result;
    }

    private function load(array $ids): Collection
    {
        return Menu::withTrashed()->whereIn('id', $ids)->with([
            'assignments', 'availabilityRules' => fn ($query) => $query->withTrashed(),
            'sections' => fn ($query) => $query->withTrashed()->with([
                'placements' => fn ($placements) => $placements->withTrashed()->with([
                    'product' => fn ($products) => $products->withTrashed()->with([
                        'category' => fn ($categories) => $categories->withTrashed(), 'reportingCategory' => fn ($categories) => $categories->withTrashed(), 'kitchenStation' => fn ($stations) => $stations->withTrashed(),
                        'variants' => fn ($variants) => $variants->withTrashed(),
                        'modifierGroups' => fn ($groups) => $groups->withTrashed()->with(['options' => fn ($options) => $options->withTrashed()]),
                    ]),
                ]),
            ]),
        ])->orderBy('id')->get();
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
        $this->validateModifiers($result, $menu, $section, $placement, $product, $tenantId);
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
        $scheduled = $this->scheduled->resolve($tenantId, $product->id, $variant->id, $branch->id, $channel, $at, $branch->timezone ?: config('app.timezone'));
        if (! $scheduled['isScheduledAvailable']) {
            $this->issue($result, 'PRODUCT_OUTSIDE_SCHEDULE', 'warning', 'The product is outside scheduled availability at the requested time.', 'product', $product->id, $menu->id, $section->id, $placement->id);
        }
        $operational = $this->operational->resolve($tenantId, $product->id, $variant->id, $branch->id, $channel, $at, $branch->timezone ?: config('app.timezone'));
        if (! $operational['isOperationallyAvailable']) {
            $this->issue($result, 'PRODUCT_OPERATIONALLY_UNAVAILABLE', 'warning', 'The product or variant is currently operationally unavailable.', 'variant', $variant->id, $menu->id, $section->id, $placement->id, ['status' => $operational['status']]);
        }
    }

    private function validateModifiers(MenuValidationResult $result, Menu $menu, object $section, object $placement, Product $product, int $tenantId): void
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
            if ($max > $active->count()) {
                $this->issue($result, 'MODIFIER_MAXIMUM_EXCEEDS_OPTIONS', 'error', 'Modifier maximum exceeds the active option count.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            if ($group->selection_type === 'single' && $max > 1) {
                $this->issue($result, 'MODIFIER_SINGLE_MAXIMUM_INVALID', 'error', 'A single-selection group cannot have a maximum above one.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            if ($active->where('is_default', true)->count() > $max) {
                $this->issue($result, 'MODIFIER_DEFAULTS_EXCEED_MAXIMUM', 'error', 'Default active options exceed the effective maximum.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
            }
            if (in_array($this->normalized($group->name), ['size', 'sizes', 'cup size', 'الحجم', 'الأحجام'], true)) {
                $this->issue($result, 'LEGACY_SIZE_MODIFIER_GROUP', 'warning', 'A legacy size-like modifier group remains assigned.', 'modifier_group', $group->id, $menu->id, $section->id, $placement->id);
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
