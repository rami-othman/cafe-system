<?php

namespace App\Http\Resources\CafeConfiguration;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TaxResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['taxRate' => (float) $this->tax_rate];
    }
}
