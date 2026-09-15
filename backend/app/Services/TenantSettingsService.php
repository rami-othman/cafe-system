<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

/**
 * Reads arbitrary keys out of `tenant_settings.settings` (a per-tenant JSON
 * blob, currently only ever written once at onboarding by
 * App\Actions\SuperAdmin\OnboardTenant). A tenant with no row, or no matching
 * key, gets the caller-supplied default — this is intentionally tolerant so
 * existing tenants never need a backfill migration just to read a new key.
 */
class TenantSettingsService
{
    public function get(int $tenantId, string $key, mixed $default = null): mixed
    {
        $raw = DB::table('tenant_settings')->where('tenant_id', $tenantId)->value('settings');
        if ($raw === null) {
            return $default;
        }

        $settings = is_array($raw) ? $raw : json_decode((string) $raw, true);
        if (! is_array($settings) || ! array_key_exists($key, $settings)) {
            return $default;
        }

        return $settings[$key];
    }

    public function getBool(int $tenantId, string $key, bool $default = false): bool
    {
        $value = $this->get($tenantId, $key, $default);

        return filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? $default;
    }
}
