<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\Category;
use App\Models\KitchenStation;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\ReportingCategory;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CatalogProductService
{
    public function __construct(private readonly CatalogAuditService $audit, private readonly LegacyProductVariantCompatibilityService $legacy) {}

    public function create(int $tenantId, array $data): Product
    {
        $this->validateReferences($tenantId, $data);
        $this->validateVariants($tenantId, $data['variants']);

        return DB::transaction(function () use ($tenantId, $data): Product {
            $product = Product::query()->create(['tenant_id' => $tenantId] + $this->productPayload($data));
            foreach ($data['variants'] as $variant) {
                $product->variants()->create(['tenant_id' => $tenantId] + $this->variantPayload($variant));
            }
            $this->legacy->sync($product->fresh('variants'));
            $product = $product->fresh(['category', 'reportingCategory', 'kitchenStation', 'variants', 'defaultVariant']);
            $this->audit->log($tenantId, $product, MenuAuditAction::Created, null, $product->toArray());

            return $product;
        });
    }

    public function update(Product $product, array $data): Product
    {
        $this->validateReferences($product->tenant_id, $data);

        return DB::transaction(function () use ($product, $data): Product {
            $before = $product->toArray();
            $product->update($this->productPayload($data, false));
            $product = $product->fresh(['category', 'reportingCategory', 'kitchenStation', 'variants', 'defaultVariant']);
            $this->audit->log($product->tenant_id, $product, MenuAuditAction::Updated, $before, $product->toArray());

            return $product;
        });
    }

    public function archive(Product $product): Product
    {
        return DB::transaction(function () use ($product): Product {
            $before = $product->toArray();
            $product->update(['is_active' => false]);
            $product->delete();
            $this->audit->log($product->tenant_id, $product, MenuAuditAction::Archived, $before, ['isActive' => false]);

            return $product;
        });
    }

    public function restore(Product $product): Product
    {
        $this->validateReferences($product->tenant_id, ['categoryId' => $product->category_id, 'reportingCategoryId' => $product->reporting_category_id, 'kitchenStationId' => $product->kitchen_station_id]);

        return DB::transaction(function () use ($product): Product {
            $this->legacy->sync($product);
            $product->restore();
            $product->update(['is_active' => true]);
            $product = $product->fresh(['category', 'reportingCategory', 'kitchenStation', 'variants', 'defaultVariant']);
            $this->audit->log($product->tenant_id, $product, MenuAuditAction::Restored, null, $product->toArray());

            return $product;
        });
    }

    private function validateReferences(int $tenantId, array $data): void
    {
        foreach ([['categoryId', Category::class], ['reportingCategoryId', ReportingCategory::class], ['kitchenStationId', KitchenStation::class]] as [$key, $model]) {
            if (! empty($data[$key]) && ! $model::query()->where('tenant_id', $tenantId)->where('id', $data[$key])->where('is_active', true)->exists()) {
                throw ValidationException::withMessages([$key => 'The selected value is invalid.']);
            }
        }
    }

    private function validateVariants(int $tenantId, array $variants): void
    {
        $activeDefaults = collect($variants)->filter(fn (array $variant) => ($variant['isDefault'] ?? false) && ($variant['isActive'] ?? true));
        if (count($variants) < 1 || $activeDefaults->count() !== 1) {
            throw ValidationException::withMessages(['variants' => 'Exactly one active default variant is required.']);
        }
        $names = collect($variants)->pluck('name')->map(fn ($name) => strtolower($name));
        if ($names->unique()->count() !== $names->count()) {
            throw ValidationException::withMessages(['variants' => 'Variant names must be unique within the product.']);
        }
        foreach (['sku', 'barcode'] as $field) {
            foreach (collect($variants)->pluck($field)->filter() as $value) {
                if (ProductVariant::withTrashed()->where('tenant_id', $tenantId)->where($field, $value)->exists()) {
                    throw ValidationException::withMessages([$field => "The {$field} has already been taken."]);
                }
            }
        }
    }

    private function productPayload(array $data, bool $create = true): array
    {
        $type = $data['productType'] ?? 'standard';
        if ($type === 'combo') {
            throw ValidationException::withMessages(['productType' => 'Combo products are not available in this phase.']);
        }
        $payload = ['name' => $data['name'], 'name_ar' => $data['nameAr'] ?? null, 'name_en' => $data['nameEn'] ?? null, 'description' => $data['description'] ?? null, 'description_ar' => $data['descriptionAr'] ?? null, 'description_en' => $data['descriptionEn'] ?? null, 'image_url' => $data['imageUrl'] ?? null, 'category_id' => $data['categoryId'] ?? null, 'reporting_category_id' => $data['reportingCategoryId'] ?? null, 'kitchen_station_id' => $data['kitchenStationId'] ?? null, 'product_type' => $type, 'preparation_time_minutes' => $data['preparationTimeMinutes'] ?? null, 'is_stock_tracked' => $data['isStockTracked'] ?? false, 'sort_order' => $data['sortOrder'] ?? 0];

        return $create ? $payload + ['is_active' => $data['isActive'] ?? true] : $payload;
    }

    public function variantPayload(array $data): array
    {
        return ['name' => $data['name'], 'name_ar' => $data['nameAr'] ?? null, 'name_en' => $data['nameEn'] ?? null, 'sku' => $data['sku'] ?? null, 'barcode' => $data['barcode'] ?? null, 'base_price' => $data['basePrice'], 'cost_price' => $data['costPrice'] ?? 0, 'is_default' => $data['isDefault'] ?? false, 'is_active' => $data['isActive'] ?? true, 'sort_order' => $data['sortOrder'] ?? 0];
    }
}
