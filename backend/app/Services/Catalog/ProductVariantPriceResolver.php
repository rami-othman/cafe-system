<?php

namespace App\Services\Catalog;

use App\Models\Branch;
use App\Models\ProductVariantPriceOverride;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Validation\ValidationException;

class ProductVariantPriceResolver
{
    public function __construct(private readonly ProductVariantPriceOverrideService $overrides) {}

    public function resolve(int $tenantId, int $variantId, ?int $branchId, ?string $channel): array
    {
        $variant = $this->overrides->variant($tenantId, $variantId);
        if ($branchId !== null) {
            $branch = Branch::query()->where('tenant_id', $tenantId)->where('is_active', true)->find($branchId);
            if (! $branch) {
                throw ValidationException::withMessages(['branchId' => 'The selected branch is invalid or archived.']);
            }
        }

        $match = $branchId !== null && $channel !== null ? $this->match($tenantId, $variant->id, 'branch_channel', $branchId, $channel) : null;
        $match ??= $branchId !== null ? $this->match($tenantId, $variant->id, 'branch', $branchId, null) : null;
        $match ??= $channel !== null ? $this->match($tenantId, $variant->id, 'channel', null, $channel) : null;

        return [
            'variantId' => $variant->id,
            'basePrice' => $variant->base_price,
            'effectivePrice' => $match?->override_price ?? $variant->base_price,
            'matchedScope' => $match?->scope_type ?? 'base',
            'matchedOverrideId' => $match?->id,
            'branchId' => $branchId,
            'channel' => $channel,
        ];
    }

    private function match(int $tenantId, int $variantId, string $scopeType, ?int $branchId, ?string $channel): ?ProductVariantPriceOverride
    {
        return ProductVariantPriceOverride::query()
            ->where('tenant_id', $tenantId)
            ->where('product_variant_id', $variantId)
            ->where('scope_type', $scopeType)
            ->where('is_active', true)
            ->when($branchId !== null, function (Builder $query) use ($branchId): void {
                $query->where('branch_id', $branchId)->whereHas('branch', fn (Builder $branch) => $branch->where('is_active', true));
            })
            ->when($channel !== null, fn (Builder $query) => $query->where('channel', $channel))
            ->first();
    }
}
