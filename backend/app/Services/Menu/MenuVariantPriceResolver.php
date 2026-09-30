<?php

namespace App\Services\Menu;

use App\Models\MenuVariantPrice;
use App\Models\ProductVariantPriceOverride;
use App\Services\Catalog\ProductVariantPriceResolver;
use Illuminate\Support\Collection;

class MenuVariantPriceResolver
{
    public function __construct(private readonly ProductVariantPriceResolver $shared) {}

    public function resolve(int $tenantId, int $menuId, int $variantId, int $branchId, string $channel): array
    {
        $override = MenuVariantPrice::query()->where('tenant_id', $tenantId)->where('menu_id', $menuId)->where('product_variant_id', $variantId)->where('branch_id', $branchId)->where('channel', $channel)->first();
        if ($override) {
            $inherited = $this->inherited($tenantId, $variantId, $branchId, $channel);
            return ['variantId' => $variantId, 'effectivePrice' => (string) $override->price, 'matchedScope' => 'menu', 'menuOverrideId' => $override->id, 'menuOverrideUpdatedAt' => $override->updated_at?->toIso8601String(), 'inherited' => $inherited];
        }
        $inherited = $this->inherited($tenantId, $variantId, $branchId, $channel);
        return ['variantId' => $variantId, 'effectivePrice' => $inherited['effectivePrice'], 'matchedScope' => $inherited['matchedScope'], 'menuOverrideId' => null, 'menuOverrideUpdatedAt' => null, 'inherited' => $inherited];
    }

    public function inherited(int $tenantId, int $variantId, int $branchId, string $channel): array
    {
        return $this->shared->resolve($tenantId, $variantId, $branchId, $channel);
    }

    /** Bulk equivalent used by overview/adjustment discovery to avoid per-row resolver queries. */
    public function resolveMany(int $tenantId, int $menuId, Collection $variants, int $branchId, string $channel): array
    {
        $ids = $variants->pluck('id')->all();
        $menu = MenuVariantPrice::query()->where('tenant_id', $tenantId)->where('menu_id', $menuId)->where('branch_id', $branchId)->where('channel', $channel)->whereIn('product_variant_id', $ids)->get()->keyBy('product_variant_id');
        $shared = ProductVariantPriceOverride::query()->where('tenant_id', $tenantId)->whereIn('product_variant_id', $ids)->where('is_active', true)
            ->where(function ($q) use ($branchId, $channel): void { $q->where(fn ($q) => $q->where('scope_type', 'branch_channel')->where('branch_id', $branchId)->where('channel', $channel))
                ->orWhere(fn ($q) => $q->where('scope_type', 'branch')->where('branch_id', $branchId)->whereNull('channel'))
                ->orWhere(fn ($q) => $q->where('scope_type', 'channel')->whereNull('branch_id')->where('channel', $channel)); })->get()->groupBy('product_variant_id');
        return $variants->mapWithKeys(function ($variant) use ($menu, $shared, $branchId, $channel): array {
            $matches = $shared->get($variant->id, collect());
            $match = $matches->firstWhere('scope_type', 'branch_channel') ?? $matches->firstWhere('scope_type', 'branch') ?? $matches->firstWhere('scope_type', 'channel');
            $inherited = ['variantId' => $variant->id, 'basePrice' => (string) $variant->base_price, 'effectivePrice' => (string) ($match?->override_price ?? $variant->base_price), 'matchedScope' => $match?->scope_type ?? 'base', 'matchedOverrideId' => $match?->id, 'branchId' => $branchId, 'channel' => $channel];
            $override = $menu->get($variant->id);
            return [$variant->id => $override ? ['variantId' => $variant->id, 'effectivePrice' => (string) $override->price, 'matchedScope' => 'menu', 'menuOverrideId' => $override->id, 'menuOverrideUpdatedAt' => $override->updated_at?->toIso8601String(), 'inherited' => $inherited] : ['variantId' => $variant->id, 'effectivePrice' => $inherited['effectivePrice'], 'matchedScope' => $inherited['matchedScope'], 'menuOverrideId' => null, 'menuOverrideUpdatedAt' => null, 'inherited' => $inherited]];
        })->all();
    }
}
