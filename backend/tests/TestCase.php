<?php

namespace Tests;

use App\Models\ApiToken;
use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

abstract class TestCase extends BaseTestCase
{
    /**
     * Compatibility bridge for pre-Phase-4 operational tests. Production
     * requests never resolve tenant identity from X-Tenant-Id; tests that still
     * name a tenant through the old header receive a real opaque bearer token
     * for a test owner in that tenant. New tests should call
     * authenticateTenantUser() explicitly.
     */
    public function json($method, $uri, array $data = [], array $headers = [], $options = 0)
    {
        if ($this->requiresOperationalToken($uri) && ! array_key_exists('Authorization', $headers) && ! array_key_exists('Authorization', $this->defaultHeaders)) {
            $headers['Authorization'] = 'Bearer '.$this->authenticateTenantUser($this->tenantIdForTestHeaders($headers));
        }

        return parent::json($method, $uri, $data, $headers, $options);
    }

    protected function authenticateTenantUser(?int $tenantId = null, ?User $user = null): string
    {
        $tenantId ??= (int) DB::table('tenants')->orderBy('id')->value('id');
        $user ??= User::query()->where('tenant_id', $tenantId)->where('role', 'owner')->where('is_active', true)->whereNull('deleted_at')->orderBy('id')->first();
        if (! $user) {
            $now = now();
            $user = User::query()->create([
                'tenant_id' => $tenantId,
                'name' => 'Phase 4 Test Owner',
                'email' => 'phase4-owner-'.Str::uuid().'@example.test',
                'password' => 'testing-password',
                'role' => 'owner',
                'is_active' => true,
                'must_change_password' => false,
            ]);
        }

        $token = 'phase4-test-'.Str::random(48);
        ApiToken::query()->create([
            'tenant_id' => $tenantId,
            'user_id' => $user->id,
            'name' => 'phase4-test',
            'token_hash' => hash('sha256', $token),
            // Test tokens intentionally have no expiry so clock-controlled
            // schedule tests exercise their business time rather than a
            // synthetic session timeout. They remain real opaque DB tokens.
            'expires_at' => null,
        ]);

        return $token;
    }

    private function requiresOperationalToken(string $uri): bool
    {
        return str_starts_with($uri, '/api/v1/')
            && ! str_starts_with($uri, '/api/v1/auth/')
            && ! str_starts_with($uri, '/api/v1/product-images/');
    }

    private function tenantIdForTestHeaders(array $headers): ?int
    {
        $header = $headers['X-Tenant-Id'] ?? $headers['x-tenant-id'] ?? null;

        return is_numeric($header) ? (int) $header : null;
    }
}
