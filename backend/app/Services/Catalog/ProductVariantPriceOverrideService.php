<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\Branch;
use App\Models\ProductVariant;
use App\Models\ProductVariantPriceOverride;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProductVariantPriceOverrideService
{
    public function __construct(private readonly CatalogAuditService $audit) {}

    public function variant(int $tenantId, int $variantId): ProductVariant
    {
        return ProductVariant::query()
            ->where('tenant_id', $tenantId)
            ->whereHas('product', fn (Builder $query) => $query->where('tenant_id', $tenantId))
            ->with('product')
            ->findOrFail($variantId);
    }

    public function overrides(ProductVariant $variant): array
    {
        return $variant->priceOverrides()
            ->orderBy('scope_type')
            ->orderBy('branch_id')
            ->orderBy('channel')
            ->orderBy('id')
            ->get()
            ->all();
    }

    public function sync(int $tenantId, int $variantId, array $items): array
    {
        $variant = $this->variant($tenantId, $variantId);
        $this->validateBranches($tenantId, $items);

        return DB::transaction(function () use ($variant, $items): array {
            $lockedVariant = ProductVariant::query()->whereKey($variant->id)->lockForUpdate()->firstOrFail();
            $existing = ProductVariantPriceOverride::withTrashed()
                ->where('tenant_id', $lockedVariant->tenant_id)
                ->where('product_variant_id', $lockedVariant->id)
                ->lockForUpdate()
                ->get()
                ->keyBy('scope_key');
            $submittedKeys = [];
            $changes = ['created' => 0, 'updated' => 0, 'restored' => 0, 'archived' => 0];

            foreach ($items as $item) {
                $scopeKey = $this->scopeKey($item['branchId'] ?? null, $item['channel'] ?? null);
                $submittedKeys[] = $scopeKey;
                $override = $existing->get($scopeKey);
                // A complete-sync item may originate from an older client.
                // Preserve lifecycle on an existing override when it is omitted.
                $payload = $this->payload($item, $scopeKey, $override?->is_active);
                if (! $override) {
                    $override = ProductVariantPriceOverride::query()->create([
                        'tenant_id' => $lockedVariant->tenant_id,
                        'product_variant_id' => $lockedVariant->id,
                    ] + $payload);
                    $changes['created']++;
                    $this->audit->log($lockedVariant->tenant_id, $override, MenuAuditAction::Created, null, $this->auditData($override, null, $override->override_price));

                    continue;
                }

                $oldPrice = $override->override_price;
                $before = $this->auditData($override, $oldPrice, null);
                if ($override->trashed()) {
                    $override->restore();
                    $override->update($payload);
                    $changes['restored']++;
                    $this->audit->log($lockedVariant->tenant_id, $override, MenuAuditAction::Restored, $before, $this->auditData($override, null, $override->override_price));
                } else {
                    $override->update($payload);
                    $changes['updated']++;
                    $this->audit->log($lockedVariant->tenant_id, $override, MenuAuditAction::Updated, $before, $this->auditData($override, null, $override->override_price));
                }
            }

            $existing->filter(fn (ProductVariantPriceOverride $override) => ! $override->trashed() && ! in_array($override->scope_key, $submittedKeys, true))
                ->each(function (ProductVariantPriceOverride $override) use ($lockedVariant, &$changes): void {
                    $before = $this->auditData($override, $override->override_price, null);
                    $override->delete();
                    $changes['archived']++;
                    $this->audit->log($lockedVariant->tenant_id, $override, MenuAuditAction::Archived, $before, null);
                });

            $this->audit->log($lockedVariant->tenant_id, $lockedVariant, MenuAuditAction::Synchronized, null, [
                'variantId' => $lockedVariant->id,
                'created' => $changes['created'],
                'updated' => $changes['updated'],
                'restored' => $changes['restored'],
                'archived' => $changes['archived'],
            ]);

            return $this->overrides($lockedVariant);
        });
    }

    private function validateBranches(int $tenantId, array $items): void
    {
        foreach ($items as $index => $item) {
            if (! isset($item['branchId'])) {
                continue;
            }
            $branch = Branch::query()->where('tenant_id', $tenantId)->where('is_active', true)->find($item['branchId']);
            if (! $branch) {
                throw ValidationException::withMessages(["overrides.$index.branchId" => 'The selected branch is invalid or archived.']);
            }
        }
    }

    private function payload(array $item, string $scopeKey, ?bool $existingIsActive = null): array
    {
        return [
            'scope_type' => $item['scopeType'],
            'scope_key' => $scopeKey,
            'branch_id' => $item['branchId'] ?? null,
            'channel' => $item['channel'] ?? null,
            'override_price' => $item['overridePrice'],
            'is_active' => $item['isActive'] ?? $existingIsActive ?? true,
        ];
    }

    private function scopeKey(?int $branchId, ?string $channel): string
    {
        return 'branch:'.($branchId ?? '*').'|channel:'.($channel ?? '*');
    }

    private function auditData(ProductVariantPriceOverride $override, mixed $oldPrice, mixed $newPrice): array
    {
        return [
            'variantId' => $override->product_variant_id,
            'scopeType' => $override->scope_type,
            'branchId' => $override->branch_id,
            'channel' => $override->channel instanceof \BackedEnum ? $override->channel->value : $override->channel,
            'oldPrice' => $oldPrice === null ? null : (float) $oldPrice,
            'newPrice' => $newPrice === null ? null : (float) $newPrice,
            'isActive' => (bool) $override->is_active,
        ];
    }
}
