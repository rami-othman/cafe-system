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

        return ['nameAr' => ['required', 'string', 'max:255'], 'nameEn' => ['nullable', 'string', 'max:255'], 'sku' => ['nullable', 'string', 'max:100', $unique('sku')], 'barcode' => ['nullable', 'string', 'max:100', $unique('barcode')], 'itemType' => ['required', Rule::in(['raw_material', 'packaging', 'supply', 'finished_good', 'other'])], 'category' => ['nullable', 'string', 'max:120'], 'unit' => ['required', Rule::in(InventoryUnitCatalog::codes())], 'minimumStock' => ['nullable', 'regex:/^\d+(\.\d{1,3})?$/'], 'reorderLevel' => ['nullable', 'regex:/^\d+(\.\d{1,3})?$/'], 'latestUnitCost' => ['nullable', 'regex:/^\d+(\.\d{1,4})?$/'], 'isActive' => ['required', 'boolean'], 'notes' => ['nullable', 'string', 'max:4000']];
    }

    protected function prepareForValidation(): void
    {
        $this->merge(['unit' => InventoryUnitCatalog::normalize($this->input('unit'))]);
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            if ($validator->errors()->isNotEmpty()) {
                return;
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
