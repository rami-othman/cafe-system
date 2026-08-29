<?php

namespace App\Http\Resources\Catalog;

use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OperationalAvailabilityResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $until = data_get($this->resource, 'unavailable_until');
        $timezone = data_get($this->resource, 'branch_timezone') ?? data_get($this->resource, 'branch.timezone') ?? config('app.timezone');
        $until = $until ? CarbonImmutable::parse($until)->setTimezone($timezone) : null;

        return [
            'id' => data_get($this->resource, 'id'), 'level' => data_get($this->resource, 'level'),
            'productId' => data_get($this->resource, 'product_id') ?? data_get($this->resource, 'product_variant.product_id'), 'productName' => data_get($this->resource, 'product_name') ?? data_get($this->resource, 'product.name') ?? data_get($this->resource, 'product_variant.product.name'),
            'productVariantId' => data_get($this->resource, 'product_variant_id'), 'variantName' => data_get($this->resource, 'variant_name') ?? data_get($this->resource, 'product_variant.name'),
            'branch' => ['id' => (int) data_get($this->resource, 'branch_id'), 'name' => data_get($this->resource, 'branch_name') ?? data_get($this->resource, 'branch.name'), 'timezone' => $timezone],
            'channel' => data_get($this->resource, 'channel'), 'status' => data_get($this->resource, 'status') instanceof \BackedEnum ? data_get($this->resource, 'status')->value : data_get($this->resource, 'status'),
            'remainingQuantity' => data_get($this->resource, 'remaining_quantity') === null ? null : (float) data_get($this->resource, 'remaining_quantity'),
            'unavailableUntil' => $until?->toIso8601String(), 'reason' => data_get($this->resource, 'reason'),
            'isExpired' => $until !== null && $until->lessThanOrEqualTo(now($timezone)),
            'createdAt' => $this->date('created_at', $timezone), 'updatedAt' => $this->date('updated_at', $timezone),
        ];
    }

    private function date(string $key, string $timezone): ?string
    {
        $value = data_get($this->resource, $key);

        return $value ? CarbonImmutable::parse($value)->setTimezone($timezone)->toIso8601String() : null;
    }
}
