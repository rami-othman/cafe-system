<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class TenantTaxService
{
    private const DEFAULT_RATE = 0.08;

    /** @var array<int, float> */
    private array $rates = [];

    public function rateFor(int $tenantId): float
    {
        if (array_key_exists($tenantId, $this->rates)) {
            return $this->rates[$tenantId];
        }

        $rate = DB::table('tenants')->where('id', $tenantId)->whereNull('deleted_at')->value('tax_rate');

        return $this->rates[$tenantId] = $this->normalize($rate);
    }

    private function normalize(mixed $rate): float
    {
        if (! is_numeric($rate)) {
            return self::DEFAULT_RATE;
        }

        $value = (float) $rate;

        return $value >= 0 && $value <= 1 ? $value : self::DEFAULT_RATE;
    }
}
