<?php

namespace App\Http\Requests\Api\V1;

use App\Support\InventoryCatalogIdentity;
use App\Support\InventoryUnitCatalog;
use App\Support\TenantContext;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use Illuminate\Validation\Rule;

class InventoryItemRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $tenantId = TenantContext::id($this);
        $item = (int) $this->route('item', 0);
        $unique = fn (string $column) => Rule::unique('inventory_items', $column)->where(fn ($q) => $q->where('tenant_id', $tenantId))->ignore($item ?: null);

        return ['nameAr' => ['required', 'string', 'max:255'], 'nameEn' => ['nullable', 'string', 'max:255'], 'sku' => ['nullable', 'string', 'max:100', $unique('sku')], 'barcode' => ['nullable', 'string', 'max:100', $unique('barcode')], 'itemType' => ['required', Rule::in(['stock_item', 'non_stock_item', 'service', 'raw_material', 'packaging', 'supply', 'finished_good', 'other'])], 'category' => ['nullable', 'string', 'max:120'], 'unit' => ['required', Rule::in(InventoryUnitCatalog::codes())], 'purchaseUnit' => ['nullable', Rule::in(InventoryUnitCatalog::codes())], 'purchaseConversionFactor' => ['nullable', 'numeric', 'gt:0'], 'consumptionUnit' => ['nullable', Rule::in(InventoryUnitCatalog::codes())], 'consumptionConversionFactor' => ['nullable', 'numeric', 'gt:0'], 'minimumStock' => ['nullable', 'regex:/^\d+(\.\d{1,3})?$/'], 'reorderLevel' => ['nullable', 'regex:/^\d+(\.\d{1,3})?$/'], 'latestUnitCost' => ['nullable', 'regex:/^\d+(\.\d{1,4})?$/'], 'lastPurchaseCost' => ['nullable', 'regex:/^\d+(\.\d{1,4})?$/'], 'preferredSupplierName' => ['nullable', 'string', 'max:255'], 'trackExpiry' => ['nullable', 'boolean'], 'trackBatch' => ['nullable', 'boolean'], 'warehouseIds' => ['nullable', 'array'], 'warehouseIds.*' => [Rule::exists('warehouses', 'id')->where(fn ($query) => $query->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at'))], 'isActive' => ['required', 'boolean'], 'notes' => ['nullable', 'string', 'max:4000']];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'unit' => InventoryUnitCatalog::normalize($this->input('unit')),
            'purchaseUnit' => $this->filled('purchaseUnit') ? InventoryUnitCatalog::normalize($this->input('purchaseUnit')) : null,
            'consumptionUnit' => $this->filled('consumptionUnit') ? InventoryUnitCatalog::normalize($this->input('consumptionUnit')) : null,
        ]);
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }
            if ($this->input('purchaseUnit') && $this->input('purchaseUnit') !== $this->input('unit') && ! $this->filled('purchaseConversionFactor')) {
                $validator->errors()->add('purchaseConversionFactor', 'A purchase-unit conversion is required when the purchase and base units differ.');
            }
            if ($this->input('consumptionUnit') && $this->input('consumptionUnit') !== $this->input('unit') && ! $this->filled('consumptionConversionFactor')) {
                $validator->errors()->add('consumptionConversionFactor', 'A consumption-unit conversion is required when the consumption and base units differ.');
            }

            $tenantId = TenantContext::id($this);
            $itemId = (int) $this->route('item', 0);
            $identity = InventoryCatalogIdentity::forValues(
                $this->input('sku'),
                $this->input('nameEn') ?: $this->input('nameAr'),
                $this->input('unit'),
                $this->input('itemType'),
            );
            $exists = \DB::table('inventory_items')
                ->where('tenant_id', $tenantId)
                ->where('catalog_identity', $identity)
                ->whereNull('deleted_at')
                ->when($itemId > 0, fn ($query) => $query->where('id', '!=', $itemId))
                ->exists();
            if ($exists) {
                $validator->errors()->add(
                    $this->filled('sku') ? 'sku' : 'nameAr',
                    $this->filled('sku')
                        ? 'An inventory item with this SKU already exists.'
                        : 'An inventory item with the same name, unit, and type already exists.',
                );
            }
        });
    }
}
