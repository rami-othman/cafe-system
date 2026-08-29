<?php

namespace App\Services\Menu;

use App\Models\Branch;
use App\Models\Menu;
use App\Models\MenuItemPlacement;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Services\Catalog\OperationalAvailabilityResolver;
use App\Services\Catalog\ProductAvailabilityResolver;
use App\Services\Catalog\ProductVariantPriceResolver;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

/** Builds an administrator-only, non-persisted resolved menu view. */
class MenuPreviewService
{
    public function __construct(
        private readonly MenuValidationService $validation,
        private readonly MenuAvailabilityResolver $menuAvailability,
        private readonly ProductVariantPriceResolver $prices,
        private readonly ProductAvailabilityResolver $scheduled,
        private readonly OperationalAvailabilityResolver $operational,
    ) {}

    public function one(int $tenantId, int $menuId, array $input): array
    {
        $branch = $this->branch($tenantId, $input['branchId']);
        $menu = Menu::withTrashed()->where('tenant_id', $tenantId)->findOrFail($menuId);

        return $this->build($tenantId, collect([$menu->id]), $branch, $input);
    }

    public function collection(int $tenantId, array $input): array
    {
        $branch = $this->branch($tenantId, $input['branchId']);
        $automatic = ! array_key_exists('menuIds', $input);
        if (! $automatic) {
            $ids = $input['menuIds'];
            $found = Menu::withTrashed()->where('tenant_id', $tenantId)->whereIn('id', $ids)->count();
            if ($found !== count($ids)) {
                throw ValidationException::withMessages(['menuIds' => 'One or more selected menus are invalid.']);
            }
        } else {
            $ids = $this->validation->assignedMenuIds($tenantId, $branch->id, $input['channel']);
        }

        return $this->build($tenantId, collect($ids), $branch, $input, $automatic);
    }

    private function build(int $tenantId, Collection $ids, Branch $branch, array $input, bool $automatic = false): array
    {
        $language = $input['language'] ?? 'default';
        $timezone = $branch->timezone ?: config('app.timezone');
        $at = CarbonImmutable::parse($input['at'] ?? 'now', $timezone);
        $includeUnavailable = $input['includeUnavailable'] ?? true;
        $includeHidden = $input['includeHidden'] ?? false;
        $menus = $this->load($ids->all(), $automatic);
        $validation = $this->validation->validateCollection($tenantId, $branch, $input['channel'], $automatic ? null : $ids->all(), $at->toIso8601String())->toArray();

        return [
            'context' => ['branchId' => $branch->id, 'channel' => $input['channel'], 'language' => $language, 'evaluatedAt' => $at->toIso8601String(), 'timezone' => $timezone],
            'canPublish' => $validation['errorCount'] === 0,
            'validation' => collect($validation)->only(['errorCount', 'warningCount', 'informationCount', 'errors', 'warnings', 'information'])->all(),
            'menus' => $menus->map(fn (Menu $menu) => $this->menu($tenantId, $menu, $branch, $input['channel'], $at, $language, $includeUnavailable, $includeHidden))->values()->all(),
        ];
    }

    private function load(array $ids, bool $preserveOrder = false): Collection
    {
        $menus = Menu::withTrashed()->whereIn('id', $ids)->with([
            'assignments', 'availabilityRules' => fn ($query) => $query->withTrashed(),
            'sections' => fn ($sections) => $sections->withTrashed()->orderBy('sort_order')->orderBy('id')->with([
                'placements' => fn ($placements) => $placements->withTrashed()->orderBy('sort_order')->orderBy('id')->with([
                    'product' => fn ($products) => $products->withTrashed()->with([
                        'variants' => fn ($variants) => $variants->withTrashed()->with('recipe.components')->orderBy('sort_order')->orderBy('id'),
                        'modifierGroups' => fn ($groups) => $groups->withTrashed()->with(['options' => fn ($options) => $options->withTrashed()->orderBy('sort_order')->orderBy('id')]),
                    ]),
                ]),
            ]),
        ])->when(! $preserveOrder, fn ($query) => $query->orderBy('priority')->orderBy('id'))->get();

        if (! $preserveOrder) {
            return $menus;
        }

        $menus = $menus->keyBy('id');

        return collect($ids)->map(fn (int $id) => $menus->get($id))->filter()->values();
    }

    private function menu(int $tenantId, Menu $menu, Branch $branch, string $channel, CarbonImmutable $at, string $language, bool $includeUnavailable, bool $includeHidden): array
    {
        $schedule = $this->menuAvailability->resolve($tenantId, $menu->id, $branch->id, $channel, $at, $branch->timezone ?: config('app.timezone'));
        $assigned = $menu->assignments->contains(fn ($assignment) => $assignment->is_active && $assignment->branch_id === $branch->id && $this->value($assignment->channel) === $channel);
        $sections = $menu->sections->filter(fn ($section) => ! $section->trashed() && $section->is_active)
            ->map(function ($section) use ($tenantId, $branch, $channel, $at, $language, $includeUnavailable, $includeHidden): array {
                $products = $section->placements->filter(fn ($placement) => ! $placement->trashed())
                    ->map(fn (MenuItemPlacement $placement) => $this->placement($tenantId, $placement, $branch, $channel, $at, $language))
                    ->filter(fn (array $placement) => $includeHidden || $placement['isVisible'])
                    ->filter(fn (array $placement) => $includeUnavailable || $placement['isSellable'])
                    ->values()->all();

                return ['id' => $section->id, 'name' => $this->localized($section, 'name', $language), 'description' => $section->description,
                    'imageUrl' => $section->image_url, 'sortOrder' => $section->sort_order, 'products' => $products];
            })->values()->all();

        return ['id' => $menu->id, 'name' => $this->localized($menu, 'name', $language), 'description' => $this->localized($menu, 'description', $language),
            'coverImageUrl' => $menu->cover_image_url, 'priority' => $menu->priority, 'isAssigned' => $assigned,
            'isScheduledAvailable' => $schedule['isScheduledAvailable'], 'scheduleReason' => $schedule['reason'], 'sections' => $sections];
    }

    private function placement(int $tenantId, MenuItemPlacement $placement, Branch $branch, string $channel, CarbonImmutable $at, string $language): array
    {
        /** @var Product|null $product */
        $product = $placement->product;
        $hidden = ! $placement->is_visible;
        $productArchived = $product === null || $product->trashed() || ! $product->is_active;
        $variants = $product ? $product->variants->filter(fn (ProductVariant $variant) => ! $variant->trashed() && $variant->is_active)
            ->map(fn (ProductVariant $variant) => $this->variant($tenantId, $product, $variant, $branch, $channel, $at, $language))->values()->all() : [];
        $sellableVariants = collect($variants)->where('isSellable', true)->count();
        $reasons = [];
        if ($hidden) {
            $reasons[] = 'hidden';
        }
        if ($productArchived) {
            $reasons[] = 'archived_product';
        }
        if ($variants === []) {
            $reasons[] = 'no_active_variant';
        }
        if (! $hidden && ! $productArchived && $variants !== [] && $sellableVariants === 0) {
            $reasons = array_values(array_unique(array_merge($reasons, collect($variants)->flatMap(fn (array $variant) => $variant['unavailabilityReasons'])->all())));
        }
        $scheduledAvailable = collect($variants)->contains('isScheduledAvailable', true);
        $operationallyAvailable = collect($variants)->contains('isOperationallyAvailable', true);
        $sellable = ! $hidden && ! $productArchived && $sellableVariants > 0;

        return ['placementId' => $placement->id, 'productId' => $placement->product_id,
            'name' => $placement->display_name_override ?: ($product ? $this->localized($product, 'name', $language) : null),
            'description' => $placement->display_description_override ?: ($product ? $this->localized($product, 'description', $language) : null),
            'imageUrl' => $placement->display_image_override ?: $product?->image_url, 'sortOrder' => $placement->sort_order,
            'isFeatured' => (bool) $placement->is_featured, 'isVisible' => (bool) $placement->is_visible,
            'isScheduledAvailable' => $scheduledAvailable, 'isOperationallyAvailable' => $operationallyAvailable, 'isSellable' => $sellable,
            'unavailabilityReasons' => $reasons, 'variants' => $variants, 'modifierGroups' => $product ? $this->modifiers($product, $language) : []];
    }

    private function variant(int $tenantId, Product $product, ProductVariant $variant, Branch $branch, string $channel, CarbonImmutable $at, string $language): array
    {
        $timezone = $branch->timezone ?: config('app.timezone');
        $price = $this->prices->resolve($tenantId, $variant->id, $branch->id, $channel);
        $scheduled = $this->scheduled->resolve($tenantId, $product->id, $variant->id, $branch->id, $channel, $at, $timezone);
        $operational = $this->operational->resolve($tenantId, $product->id, $variant->id, $branch->id, $channel, $at, $timezone);
        $validPrice = is_numeric($price['effectivePrice']) && (float) $price['effectivePrice'] >= 0;
        $reasons = [];
        if (! $scheduled['isScheduledAvailable']) {
            $reasons[] = 'outside_product_schedule';
        }
        if (! $operational['isOperationallyAvailable']) {
            $reasons[] = $this->operationalCode($operational);
        }
        if (! $validPrice) {
            $reasons[] = 'invalid_price';
        }
        $sellable = ! $product->trashed() && $product->is_active && $variant->is_active && $scheduled['isScheduledAvailable'] && $operational['isOperationallyAvailable'] && $validPrice;

        return ['id' => $variant->id, 'name' => $this->localized($variant, 'name', $language), 'sku' => $variant->sku, 'barcode' => $variant->barcode,
            'sortOrder' => $variant->sort_order, 'isDefault' => (bool) $variant->is_default, 'basePrice' => (float) $price['basePrice'],
            'effectivePrice' => (float) $price['effectivePrice'], 'matchedPriceScope' => $price['matchedScope'],
            'isScheduledAvailable' => $scheduled['isScheduledAvailable'], 'isOperationallyAvailable' => $operational['isOperationallyAvailable'],
            'isSellable' => $sellable, 'unavailabilityReasons' => $reasons,
            'recipeConfigured' => $variant->recipe !== null && $variant->recipe->components->isNotEmpty(), 'recipeComponentCount' => $variant->recipe?->components->count() ?? 0];
    }

    private function modifiers(Product $product, string $language): array
    {
        return $product->modifierGroups->filter(fn ($group) => ! $group->trashed() && $group->is_active)
            ->sort(fn ($left, $right) => (($left->pivot->sort_order ?? 0) <=> ($right->pivot->sort_order ?? 0)) ?: ($left->id <=> $right->id))
            ->map(function ($group) use ($language): array {
                $options = $group->options->filter(fn ($option) => ! $option->trashed() && $option->is_active)
                    ->sortBy([['sort_order', 'asc'], ['id', 'asc']])->values()->map(fn ($option) => [
                        'id' => $option->id, 'name' => $this->localized($option, 'name', $language), 'priceDelta' => (float) $option->price_delta,
                        'isDefault' => (bool) $option->is_default, 'isAvailable' => (bool) $option->is_available, 'sortOrder' => $option->sort_order,
                    ])->all();

                return ['id' => $group->id, 'name' => $this->localized($group, 'name', $language), 'groupType' => $this->value($group->group_type),
                    'selectionType' => $group->selection_type, 'isRequired' => (bool) ($group->pivot->is_required_override ?? $group->is_required),
                    'minSelections' => $group->pivot->min_selections_override ?? $group->min_selections,
                    'maxSelections' => $group->pivot->max_selections_override ?? $group->max_selections,
                    'allowQuantity' => (bool) ($group->pivot->allow_quantity_override ?? $group->allow_quantity),
                    'sortOrder' => $group->pivot->sort_order ?? $group->sort_order, 'options' => $options];
            })->values()->all();
    }

    private function branch(int $tenantId, int $branchId): Branch
    {
        $branch = Branch::query()->where('tenant_id', $tenantId)->where('is_active', true)->find($branchId);
        if (! $branch) {
            throw ValidationException::withMessages(['branchId' => 'The selected branch is invalid or archived.']);
        }

        return $branch;
    }

    private function localized(object $entity, string $field, string $language): mixed
    {
        $localized = $language === 'default' ? [] : [$field.'_'.$language];
        $fallbacks = $language === 'ar' ? [$field, $field.'_en'] : ($language === 'en' ? [$field, $field.'_ar'] : [$field, $field.'_ar', $field.'_en']);
        foreach (array_merge($localized, $fallbacks) as $attribute) {
            if (($value = $entity->{$attribute} ?? null) !== null && $value !== '') {
                return $value;
            }
        }

        return null;
    }

    private function operationalCode(array $operational): string
    {
        $prefix = ($operational['matchedLevel'] ?? 'product') === 'variant' ? 'variant' : 'product';

        return $prefix.'_'.(($operational['status'] ?? null) === 'sold_out' ? 'sold_out' : 'temporarily_unavailable');
    }

    private function value(mixed $value): mixed
    {
        return $value instanceof \BackedEnum ? $value->value : $value;
    }
}
