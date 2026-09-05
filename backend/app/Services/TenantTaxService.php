<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class TenantTaxService
{
    private const DEFAULT_RATE = 0.08;

    public function rateFor(int $tenantId): float
    {
        $rate = DB::table('tenants')->where('id', $tenantId)->whereNull('deleted_at')->value('tax_rate');

        return $this->normalize($rate);
    }

    /**
     * Persist the one canonical tenant-wide fractional tax rate. Rate reads
     * intentionally query persistence so a configuration change is visible to
     * every new Order, including under long-lived application workers.
     * Callers validate the public API contract before reaching this method.
     */
    public function updateRateFor(int $tenantId, int|float|string $rate): float
    {
        $normalized = number_format((float) $rate, 6, '.', '');

        DB::table('tenants')
            ->where('id', $tenantId)
            ->whereNull('deleted_at')
            ->update(['tax_rate' => $normalized, 'updated_at' => now()]);

        return (float) $normalized;
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
