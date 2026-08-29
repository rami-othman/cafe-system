<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\Product;
use App\Models\ProductVariant;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProductVariantService
{
    public function __construct(private readonly CatalogAuditService $audit, private readonly LegacyProductVariantCompatibilityService $legacy, private readonly CatalogProductService $products) {}

    public function create(Product $product, array $data): ProductVariant
    {
        if (! $product->is_active) {
            throw ValidationException::withMessages(['product' => 'Variants cannot be created for an archived product.']);
        }
        $this->uniqueCodes($product->tenant_id, $data);

        return DB::transaction(function () use ($product, $data): ProductVariant {
            if (($data['isDefault'] ?? false) && ! ($data['isActive'] ?? true)) {
                throw ValidationException::withMessages(['isDefault' => 'A default variant must be active.']);
            }
            if ($data['isDefault'] ?? false) {
                $product->variants()->update(['is_default' => false]);
            }
            $variant = $product->variants()->create(['tenant_id' => $product->tenant_id] + $this->products->variantPayload($data));
            $this->legacy->sync($product->fresh());
            $this->audit->log($product->tenant_id, $variant, MenuAuditAction::Created, null, $variant->toArray());

            return $variant;
        });
    }

    public function update(ProductVariant $variant, array $data): ProductVariant
    {
        if (($data['isActive'] ?? $variant->is_active) && (! $variant->product || $variant->product->trashed() || ! $variant->product->is_active)) {
            throw ValidationException::withMessages(['product' => 'An active variant requires an active product.']);
        }
        $this->uniqueCodes($variant->tenant_id, $data, $variant->id);

        return DB::transaction(function () use ($variant, $data): ProductVariant {
            if ($variant->is_default && array_key_exists('isActive', $data) && ! $data['isActive']) {
                throw ValidationException::withMessages(['isActive' => 'Archive or replace the default variant instead.']);
            }
            $before = $variant->toArray();
            $variant->update($this->products->variantPayload($data));
            if ($variant->is_default) {
                $this->legacy->sync($variant->product->fresh());
            }
            $this->audit->log($variant->tenant_id, $variant, MenuAuditAction::Updated, $before, $variant->fresh()->toArray());

            return $variant->fresh();
        });
    }

    public function setDefault(ProductVariant $variant): ProductVariant
    {
        if (! $variant->is_active) {
            throw ValidationException::withMessages(['variant' => 'Only an active variant can be the default.']);
        }

        return DB::transaction(function () use ($variant): ProductVariant {
            $product = Product::query()->lockForUpdate()->findOrFail($variant->product_id);
            $product->variants()->lockForUpdate()->update(['is_default' => false]);
            $variant->update(['is_default' => true]);
            $this->legacy->sync($product->fresh());
            $this->audit->log($variant->tenant_id, $variant, MenuAuditAction::Updated, null, ['isDefault' => true]);

            return $variant->fresh();
        });
    }

    public function archive(ProductVariant $variant, ?int $replacementId): ProductVariant
    {
        return DB::transaction(function () use ($variant, $replacementId): ProductVariant {
            $product = Product::query()->lockForUpdate()->findOrFail($variant->product_id);
            $active = $product->variants()->where('is_active', true)->lockForUpdate()->get();
            if ($product->is_active && $active->count() <= 1) {
                throw ValidationException::withMessages(['variant' => 'The only active variant cannot be archived.']);
            }
            if ($variant->is_default && $product->is_active) {
                $replacement = $replacementId ? $product->variants()->where('id', $replacementId)->where('is_active', true)->first() : null;
                if (! $replacement) {
                    throw ValidationException::withMessages(['replacementDefaultVariantId' => 'An active replacement variant from this product is required.']);
                }
                $product->variants()->update(['is_default' => false]);
                $replacement->update(['is_default' => true]);
            }
            $variant->update(['is_active' => false]);
            $variant->delete();
            if ($product->is_active) {
                $this->legacy->sync($product->fresh());
            }
            $this->audit->log($variant->tenant_id, $variant, MenuAuditAction::Archived, null, ['isActive' => false]);

            return $variant;
        });
    }

    public function restore(ProductVariant $variant, bool $makeDefault): ProductVariant
    {
        return DB::transaction(function () use ($variant, $makeDefault): ProductVariant {
            $product = Product::query()->find($variant->product_id);
            if (! $product || ! $product->is_active) {
                throw ValidationException::withMessages(['product' => 'An archived variant can only be restored to an active product.']);
            }
            $hasDefault = $product->variants()->where('is_active', true)->where('is_default', true)->exists();
            if (! $hasDefault && ! $makeDefault) {
                throw ValidationException::withMessages(['makeDefault' => 'Set makeDefault=true because this product has no active default variant.']);
            }
            $variant->restore();
            $variant->update(['is_active' => true]);
            if ($makeDefault) {
                $product->variants()->update(['is_default' => false]);
                $variant->update(['is_default' => true]);
                $this->legacy->sync($product->fresh());
            }
            $this->audit->log($variant->tenant_id, $variant, MenuAuditAction::Restored, null, $variant->fresh()->toArray());

            return $variant->fresh();
        });
    }

    public function reorder(Product $product, array $items): void
    {
        DB::transaction(function () use ($product, $items): void {
            $ids = collect($items)->pluck('id')->map(fn ($id) => (int) $id);
            if ($ids->unique()->count() !== $ids->count() || $product->variants()->whereIn('id', $ids)->count() !== $ids->count()) {
                throw ValidationException::withMessages(['items' => 'Every variant must belong to this product.']);
            }
            foreach ($items as $item) {
                $product->variants()->whereKey($item['id'])->update(['sort_order' => $item['sortOrder']]);
            }
            $this->audit->log($product->tenant_id, $product, MenuAuditAction::Reordered, null, ['variants' => $items]);
        });
    }

    private function uniqueCodes(int $tenantId, array $data, ?int $ignore = null): void
    {
        foreach (['sku', 'barcode'] as $field) {
            if (! empty($data[$field]) && ProductVariant::withTrashed()->where('tenant_id', $tenantId)->where($field, $data[$field])->when($ignore, fn ($q) => $q->where('id', '!=', $ignore))->exists()) {
                throw ValidationException::withMessages([$field => "The {$field} has already been taken."]);
            }
        }
    }
}
