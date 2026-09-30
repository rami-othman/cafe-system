<?php

namespace App\Services\Menu;

use App\Models\Branch;
use App\Models\Menu;
use App\Models\MenuVariantPrice;
use App\Models\ProductVariant;
use App\Models\PublishedMenuVersion;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class MenuPricingQueryService
{
    public function __construct(private readonly MenuVariantPriceResolver $prices) {}

    public function context(int $tenantId, int $menuId, int $branchId, string $channel): array
    {
        $menu = Menu::query()->where('tenant_id', $tenantId)->where('status', '!=', 'archived')->findOrFail($menuId);
        $branch = Branch::query()->where('tenant_id', $tenantId)->where('is_active', true)->find($branchId);
        if (! $branch) {
            throw ValidationException::withMessages(['branchId' => 'The selected branch is invalid or archived.']);
        }
        return compact('menu', 'branch', 'channel');
    }

    /** Lock and validate the apply-time configuration context. */
    public function lockApplyContext(int $tenantId, int $menuId, int $branchId, string $channel): array
    {
        $menu = Menu::withTrashed()->where('tenant_id', $tenantId)->whereKey($menuId)->lockForUpdate()->first();
        $branch = Branch::withTrashed()->where('tenant_id', $tenantId)->whereKey($branchId)->lockForUpdate()->first();
        if (! $menu || $menu->trashed() || $this->value($menu->status) === 'archived' || ! $branch || $branch->trashed() || ! $branch->is_active) {
            throw new \App\Domain\Menu\MenuPricingException('MENU_PRICING_CONTEXT_INVALID', 409);
        }

        return compact('menu', 'branch', 'channel');
    }

    /** Active composition candidates, deduplicated by variant. Open-price rows remain visible but are not adjustable. */
    public function candidates(int $tenantId, int $menuId): Collection
    {
        return ProductVariant::query()->select('product_variants.*', 'products.name as product_name', 'products.name_ar as product_name_ar', 'products.name_en as product_name_en', 'products.category_id', 'products.product_type', 'products.updated_at as product_updated_at')
            ->selectRaw('bool_or(menu_item_placements.is_visible) as has_visible_placement')
            ->join('products', 'products.id', '=', 'product_variants.product_id')
            ->join('menu_item_placements', 'menu_item_placements.product_id', '=', 'products.id')
            ->join('menu_sections', 'menu_sections.id', '=', 'menu_item_placements.menu_section_id')
            ->where('product_variants.tenant_id', $tenantId)->where('products.tenant_id', $tenantId)->where('menu_sections.tenant_id', $tenantId)->where('menu_item_placements.tenant_id', $tenantId)
            ->where('menu_sections.menu_id', $menuId)->where('menu_sections.is_active', true)->whereNull('menu_sections.deleted_at')->whereNull('menu_item_placements.deleted_at')
            ->where('products.is_active', true)->whereNull('products.deleted_at')->where('product_variants.is_active', true)->whereNull('product_variants.deleted_at')
            ->groupBy('product_variants.id', 'products.id')->orderBy('products.name')->orderBy('product_variants.sort_order')->orderBy('product_variants.id')->get();
    }

    public function resolved(int $tenantId, int $menuId, int $branchId, string $channel): Collection
    {
        $variants = $this->candidates($tenantId, $menuId);
        $resolved = $this->prices->resolveMany($tenantId, $menuId, $variants, $branchId, $channel);
        return $variants->map(function (ProductVariant $variant) use ($resolved): array {
            $adjustable = $this->value($variant->product_type) !== 'open_price';
            return ['variant' => $variant, 'resolved' => $resolved[$variant->id], 'adjustable' => $adjustable, 'eligibilityReason' => $adjustable ? null : 'open_price'];
        });
    }

    public function overview(int $tenantId, int $menuId, array $input): array
    {
        $context = $this->context($tenantId, $menuId, $input['branchId'], $input['channel']);
        $all = $this->resolved($tenantId, $menuId, $context['branch']->id, $input['channel']);
        $published = $this->publishedPrices($tenantId, $context['branch']->id, $input['channel'], $menuId);
        $filtered = $all->filter(function (array $row) use ($input): bool {
            $v = $row['variant'];
            if (($input['categoryId'] ?? null) !== null && (int) $v->category_id !== (int) $input['categoryId']) return false;
            $search = mb_strtolower(trim((string) ($input['search'] ?? '')));
            return $search === '' || str_contains(mb_strtolower(implode(' ', [
                $v->product_name, $v->product_name_ar, $v->product_name_en,
                $v->name, $v->name_ar, $v->name_en, $v->sku ?? '',
            ])), $search);
        })->values();
        $perPage = min(100, max(1, (int) ($input['perPage'] ?? 25))); $page = max(1, (int) ($input['page'] ?? 1));
        $items = $filtered->slice(($page - 1) * $perPage, $perPage)->map(function (array $row) use ($published): array {
            $v = $row['variant']; $r = $row['resolved'];
            return ['variantId' => $v->id, 'variantName' => $v->name, 'variantNameAr' => $v->name_ar, 'variantNameEn' => $v->name_en, 'sku' => $v->sku,
                'productId' => $v->product_id, 'productName' => $v->product_name, 'productNameAr' => $v->product_name_ar, 'productNameEn' => $v->product_name_en, 'isDefault' => (bool) $v->is_default, 'categoryId' => $v->category_id, 'hasVisiblePlacement' => (bool) $v->has_visible_placement,
                'configuredEffectivePrice' => $this->decimal($r['effectivePrice']), 'configuredSource' => $r['matchedScope'], 'inheritedPrice' => $this->decimal($r['inherited']['effectivePrice']), 'inheritedSource' => $r['inherited']['matchedScope'],
                'hasMenuOverride' => $r['menuOverrideId'] !== null, 'eligibility' => ['adjustable' => $row['adjustable'], 'reason' => $row['eligibilityReason']], 'published' => $published[$v->id] ?? null];
        })->values()->all();
        return ['context' => ['menuId' => $menuId, 'branchId' => $context['branch']->id, 'channel' => $input['channel'], 'currency' => $context['branch']->currency], 'items' => $items, 'pagination' => ['page' => $page, 'perPage' => $perPage, 'total' => $filtered->count()], 'scope' => ['adjustableVariantCount' => $all->where('adjustable', true)->count(), 'excludedVariantCount' => $all->where('adjustable', false)->count()]];
    }

    public function fingerprint(Collection $rows): string
    {
        return hash('sha256', json_encode($rows->map(fn (array $row) => ['variantId' => $row['variant']->id, 'variantUpdatedAt' => $row['variant']->updated_at?->format('c'), 'productUpdatedAt' => $row['variant']->getAttribute('product_updated_at'), 'effective' => $this->decimal($row['resolved']['effectivePrice']), 'source' => $row['resolved']['matchedScope'], 'inherited' => $this->decimal($row['resolved']['inherited']['effectivePrice']), 'inheritedSource' => $row['resolved']['inherited']['matchedScope'], 'menuOverrideUpdatedAt' => $row['resolved']['menuOverrideUpdatedAt'], 'adjustable' => $row['adjustable']])->values()->all(), JSON_THROW_ON_ERROR));
    }

    private function publishedPrices(int $tenantId, int $branchId, string $channel, int $menuId): array
    {
        $version = PublishedMenuVersion::query()->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('channel', $channel)->where('status', 'current')->first();
        if (! $version) return [];
        $payload = is_array($version->payload_json) ? $version->payload_json : json_decode((string) $version->payload_json, true);
        $menu = collect($payload['menus'] ?? [])->firstWhere('id', $menuId); if (! $menu) return [];
        $prices = [];
        foreach ($menu['sections'] ?? [] as $section) foreach ($section['products'] ?? [] as $product) foreach ($product['variants'] ?? [] as $variant) $prices[(int) $variant['id']] = ['price' => $this->decimal($variant['effectivePrice'] ?? '0'), 'versionId' => $version->id, 'versionNumber' => $version->version_number];
        return $prices;
    }

    private function decimal(string|int|float $value): string { return \Brick\Math\BigDecimal::of((string) $value)->toScale(2, \Brick\Math\RoundingMode::HALF_UP)->__toString(); }
    private function value(mixed $v): mixed { return $v instanceof \BackedEnum ? $v->value : $v; }
}
