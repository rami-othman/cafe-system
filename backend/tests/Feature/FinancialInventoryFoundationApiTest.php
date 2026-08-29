<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Database\Seeders\FinancialInventoryFoundationSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FinancialInventoryFoundationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_tenants_cannot_access_each_others_warehouses_accounts_or_journal_entries(): void
    {
        $this->seed();
        $tenantA = $this->demoTenantId();
        $tenantB = $this->createTenant('other-finance-tenant');
        app(FinancialSetupService::class)->ensureForTenant($tenantB);

        $warehouse = $this->postJson('/api/v1/warehouses', $this->warehousePayload(), $this->headers($tenantA))->assertCreated();
        $accountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenantA)->where('code', '1010')->value('id');
        $equityId = (int) DB::table('financial_accounts')->where('tenant_id', $tenantA)->where('code', '3000')->value('id');
        $entry = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($accountId, $equityId), $this->headers($tenantA))->assertCreated();

        $this->getJson('/api/v1/warehouses', $this->headers($tenantB))->assertOk()->assertJsonCount(1, 'data');
        $this->patchJson('/api/v1/warehouses/'.$warehouse->json('data.id'), $this->warehousePayload(), $this->headers($tenantB))->assertNotFound();
        $this->getJson('/api/v1/finance/accounts', $this->headers($tenantB))->assertOk()->assertJsonMissing(['id' => $accountId]);
        $this->getJson('/api/v1/finance/journal-entries/'.$entry->json('data.id'), $this->headers($tenantB))->assertNotFound();
    }

    public function test_default_accounts_are_seeded_once_per_tenant_and_codes_are_unique_per_tenant(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $this->seed(FinancialInventoryFoundationSeeder::class);
        $this->assertSame(19, DB::table('financial_accounts')->where('tenant_id', $tenantId)->count());

        $this->postJson('/api/v1/finance/accounts', $this->accountPayload(['code' => '9000']), $this->headers($tenantId))->assertCreated();
        $this->postJson('/api/v1/finance/accounts', $this->accountPayload(['code' => '9000', 'nameAr' => 'حساب مكرر']), $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('code');

        $tenantB = $this->createTenant('unique-code-tenant');
        app(FinancialSetupService::class)->ensureForTenant($tenantB);
        $this->postJson('/api/v1/finance/accounts', $this->accountPayload(['code' => '9000']), $this->headers($tenantB))->assertCreated();
    }

    public function test_journal_entry_cannot_post_when_unbalanced_but_balanced_entry_posts_and_is_immutable(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $cash = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id');
        $equity = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '3000')->value('id');

        $unbalanced = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity, '100.00', '90.00'), $this->headers($tenantId))->assertCreated();
        $this->postJson('/api/v1/finance/journal-entries/'.$unbalanced->json('data.id').'/post', [], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('lines');

        $balanced = $this->postJson('/api/v1/finance/journal-entries', $this->journalPayload($cash, $equity), $this->headers($tenantId))->assertCreated();
        $entryId = $balanced->json('data.id');
        $this->postJson('/api/v1/finance/journal-entries/'.$entryId.'/post', [], $this->headers($tenantId))->assertOk()->assertJsonPath('data.status', 'posted')->assertJsonPath('data.debitTotal', '100.00')->assertJsonPath('data.creditTotal', '100.00');
        $this->putJson('/api/v1/finance/journal-entries/'.$entryId, [], $this->headers($tenantId))->assertMethodNotAllowed();
        $this->deleteJson('/api/v1/finance/journal-entries/'.$entryId, [], $this->headers($tenantId))->assertMethodNotAllowed();
        $this->assertDatabaseHas('activity_logs', ['tenant_id' => $tenantId, 'entity_type' => 'journal_entry', 'entity_id' => $entryId, 'action' => 'journal_entry.posted']);
    }

    public function test_warehouse_type_and_branch_rules_are_validated(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
        $this->postJson('/api/v1/warehouses', $this->warehousePayload(['type' => 'central', 'branchId' => $branchId]), $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $this->postJson('/api/v1/warehouses', $this->warehousePayload(['type' => 'bar', 'branchId' => null]), $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('branchId');

        $tenantB = $this->createTenant('foreign-branch-tenant');
        $foreignBranchId = DB::table('branches')->insertGetId(['tenant_id' => $tenantB, 'name' => 'Other Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson('/api/v1/warehouses', $this->warehousePayload(['branchId' => $foreignBranchId]), $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('branchId');
    }

    public function test_setup_status_reports_foundation_readiness_accurately(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $this->getJson('/api/v1/finance/setup-status', $this->headers($tenantId))->assertOk()->assertJsonPath('data.systemAccountsReady', true)->assertJsonPath('data.centralWarehouseReady', true)->assertJsonPath('data.branchWarehouseCoverageReady', true)->assertJsonPath('data.financialSetupReady', true);

        DB::table('warehouses')->where('tenant_id', $tenantId)->where('type', 'central')->update(['is_active' => false]);
        $this->getJson('/api/v1/finance/setup-status', $this->headers($tenantId))->assertOk()->assertJsonPath('data.centralWarehouseReady', false)->assertJsonPath('data.financialSetupReady', false);
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Finance Owner', 'email' => "finance-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $plainToken = "financial-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'financial-feature-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }

    private function createTenant(string $slug): int
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Central Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return (int) $tenantId;
    }

    private function warehousePayload(array $overrides = []): array
    {
        $branchId = $overrides['branchId'] ?? (int) DB::table('branches')->where('tenant_id', $this->demoTenantId())->value('id');

        return $overrides + ['name' => 'مخزن اختبار', 'code' => 'TEST-STORE', 'type' => 'branch_main', 'branchId' => $branchId, 'isActive' => true, 'notes' => 'مخزن تجريبي'];
    }

    private function accountPayload(array $overrides = []): array
    {
        return $overrides + ['code' => '9001', 'nameAr' => 'مصروف اختبار', 'nameEn' => 'Test Expense', 'accountGroup' => 'expenses', 'normalBalance' => 'debit', 'isActive' => true];
    }

    private function journalPayload(int $debitAccountId, int $creditAccountId, string $debit = '100.00', string $credit = '100.00'): array
    {
        return ['entryDate' => '2026-08-16', 'sourceType' => 'manual', 'description' => 'قيد اختبار', 'lines' => [['accountId' => $debitAccountId, 'debit' => $debit, 'credit' => '0.00'], ['accountId' => $creditAccountId, 'debit' => '0.00', 'credit' => $credit]]];
    }
}
