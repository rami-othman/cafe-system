<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use App\Support\FinanceAccess;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class FinancialLocationContractApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_cash_and_bank_detail_and_transaction_contracts_are_kind_safe_and_tenant_scoped(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $owner = $this->ownerHeaders($tenant);
        $cashId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $bankId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');

        $this->getJson("/api/v1/finance/cash-accounts/$cashId", $owner)
            ->assertOk()->assertJsonPath('data.id', $cashId)->assertJsonPath('data.kind', 'cash')->assertJsonStructure(['data' => ['id', 'branchId', 'financialAccountId', 'code', 'name', 'kind', 'type', 'balance']]);
        $this->getJson("/api/v1/finance/cash-accounts/$cashId/transactions", $owner)
            ->assertOk()->assertJsonPath('data.location.id', $cashId)->assertJsonPath('data.location.kind', 'cash')->assertJsonStructure(['data' => ['location' => ['id', 'kind', 'balance'], 'transactions']]);
        $this->getJson("/api/v1/finance/bank-accounts/$bankId", $owner)
            ->assertOk()->assertJsonPath('data.id', $bankId)->assertJsonPath('data.kind', 'bank')->assertJsonStructure(['data' => ['id', 'branchId', 'financialAccountId', 'code', 'name', 'kind', 'type', 'balance']]);
        $this->getJson("/api/v1/finance/bank-accounts/$bankId/transactions", $owner)
            ->assertOk()->assertJsonPath('data.location.id', $bankId)->assertJsonPath('data.location.kind', 'bank')->assertJsonStructure(['data' => ['location' => ['id', 'kind', 'balance'], 'transactions']]);

        foreach ([
            "/api/v1/finance/cash-accounts/$bankId",
            "/api/v1/finance/cash-accounts/$bankId/transactions",
            "/api/v1/finance/bank-accounts/$cashId",
            "/api/v1/finance/bank-accounts/$cashId/transactions",
        ] as $url) {
            $this->getJson($url, $owner)->assertNotFound();
        }

        $otherTenant = $this->createTenant('financial-location-other');
        app(FinancialSetupService::class)->ensureForTenant($otherTenant);
        $this->getJson("/api/v1/finance/cash-accounts/$cashId", $this->ownerHeaders($otherTenant))->assertNotFound();
        $this->getJson("/api/v1/finance/cash-accounts/$cashId/transactions", $this->ownerHeaders($otherTenant))->assertNotFound();
    }

    public function test_branch_restricted_actor_cannot_read_another_branch_cash_location_or_its_transactions(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->orderBy('id')->value('id');
        $account = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $tenant, 'code' => 'BRANCH-CASH-CONTRACT', 'name_ar' => 'Branch cash contract', 'name_en' => 'Branch cash contract',
            'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $locationId = (int) DB::table('financial_locations')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'financial_account_id' => $account,
            'code' => 'BRANCH-RESTRICTED-CASH', 'name' => 'Branch restricted cash', 'kind' => 'cash', 'type' => 'cash_drawer', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $manager = $this->managerHeaders($tenant);

        $this->getJson("/api/v1/finance/cash-accounts/$locationId", $this->ownerHeaders($tenant))->assertOk();
        $this->getJson("/api/v1/finance/cash-accounts/$locationId", $manager)->assertForbidden();
        $this->getJson("/api/v1/finance/cash-accounts/$locationId/transactions", $manager)->assertForbidden();
        $this->getJson('/api/v1/finance/cash-accounts', $manager)->assertOk()->assertJsonMissing(['id' => $locationId]);
    }

    public function test_accounting_periods_use_the_standard_paginated_data_and_meta_contract(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        foreach (range(1, 13) as $number) {
            DB::table('accounting_periods')->insert([
                'tenant_id' => $tenant, 'name' => "Contract period $number", 'start_date' => now()->startOfMonth()->subMonths($number)->toDateString(),
                'end_date' => now()->startOfMonth()->subMonths($number)->endOfMonth()->toDateString(), 'status' => 'open', 'created_at' => now(), 'updated_at' => now(),
            ]);
        }

        $response = $this->getJson('/api/v1/finance/accounting-periods?page=2&perPage=10', $this->ownerHeaders($tenant))
            ->assertOk()->assertJsonPath('meta.currentPage', 2)->assertJsonPath('meta.perPage', 10)->assertJsonStructure(['data', 'meta' => ['currentPage', 'perPage', 'total', 'lastPage']]);
        $this->assertLessThanOrEqual(10, count($response->json('data')));
        $this->assertGreaterThanOrEqual(13, $response->json('meta.total'));
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function createTenant(string $slug): int
    {
        $id = (int) DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $id, 'name' => 'Central', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        return $id;
    }

    private function ownerHeaders(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Owner', 'email' => "owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        return $this->tokenHeaders($tenantId, $userId, 'owner');
    }

    private function managerHeaders(int $tenantId): array
    {
        $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Unassigned manager', 'email' => 'manager-'.uniqid().'@example.test', 'password' => bcrypt('password'), 'role' => 'manager', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        foreach (FinanceAccess::defaultPermissionsForRole('manager') as $permission) DB::table('finance_role_permissions')->updateOrInsert(['tenant_id' => $tenantId, 'role' => 'manager', 'permission' => $permission], ['created_at' => now(), 'updated_at' => now()]);
        return $this->tokenHeaders($tenantId, $userId, 'manager');
    }

    private function tokenHeaders(int $tenantId, int $userId, string $type): array
    {
        $token = "financial-location-$type-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => "financial-location-$type"], ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenantId];
    }
}
