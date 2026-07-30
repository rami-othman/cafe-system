<?php

namespace App\Http\Resources\Catalog;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductVariantPriceOverrideResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'scopeType' => $this->scope_type,
            'branchId' => $this->branch_id,
            'channel' => $this->channel instanceof \BackedEnum ? $this->channel->value : $this->channel,
            'overridePrice' => (float) $this->override_price,
            'isActive' => (bool) $this->is_active,
        ];
    }
}
