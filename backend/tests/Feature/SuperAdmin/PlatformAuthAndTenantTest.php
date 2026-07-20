<?php

namespace Tests\Feature\SuperAdmin;

use Database\Seeders\SuperAdminSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PlatformAuthAndTenantTest extends TestCase
{
    use RefreshDatabase;

    public function test_platform_admin_can_login_and_onboard_a_tenant(): void
    {
        $this->seed(SuperAdminSeeder::class);
        $this->postJson('/api/super-admin/v1/auth/login', ['email' => 'admin@cafe618.local', 'password' => 'change-me-local-only'])->assertOk();
        $planId = DB::table('plans')->where('code', 'starter')->value('id');
        $response = $this->postJson('/api/super-admin/v1/tenants', ['name' => 'Acme Cafe', 'slug' => 'acme-cafe', 'email' => 'hello@acme.test', 'timezone' => 'UTC', 'currency' => 'USD', 'planId' => $planId, 'trialDays' => 14, 'ownerName' => 'Acme Owner', 'ownerEmail' => 'owner@acme.test', 'branchName' => 'Central']);
        $response->assertCreated()->assertJsonPath('data.slug', 'acme-cafe');
        $tenantId = $response->json('data.id');
        $this->assertDatabaseHas('subscriptions', ['tenant_id' => $tenantId, 'status' => 'trialing']);
        $this->assertDatabaseHas('platform_audit_logs', ['action' => 'tenant.created', 'tenant_id' => $tenantId]);
    }

    public function test_tenant_user_cannot_access_platform_boundary(): void
    {
        $this->seed(SuperAdminSeeder::class);
        DB::table('tenants')->insert(['name' => 'Tenant', 'slug' => 'tenant', 'created_at' => now(), 'updated_at' => now()]);
        $tenantId = DB::table('tenants')->where('slug', 'tenant')->value('id');
        DB::table('users')->insert(['tenant_id' => $tenantId, 'name' => 'Tenant User', 'email' => 'tenant@example.test', 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson('/api/super-admin/v1/auth/login', ['email' => 'tenant@example.test', 'password' => 'password'])->assertUnauthorized();
    }

    public function test_platform_admin_can_read_the_dashboard_management_modules(): void
    {
        $this->seed(SuperAdminSeeder::class);
        $this->postJson('/api/super-admin/v1/auth/login', ['email' => 'admin@cafe618.local', 'password' => 'change-me-local-only'])->assertOk();

        foreach (['dashboard', 'branches', 'tenant-users', 'plans', 'subscriptions', 'analytics/overview', 'audit-logs', 'announcements', 'system/health', 'settings', 'platform-admins'] as $path) {
            $this->getJson('/api/super-admin/v1/'.$path)->assertOk()->assertJsonStructure(['data']);
        }
    }
}
