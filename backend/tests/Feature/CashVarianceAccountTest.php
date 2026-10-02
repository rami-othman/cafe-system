<?php

namespace Tests\Feature;

use App\Services\CashVarianceService;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class CashVarianceAccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_setup_creates_the_default_cash_over_short_account(): void
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'T1 Tenant', 'slug' => 'cva-tenant', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch);

        $this->assertDatabaseHas('financial_accounts', [
            'tenant_id' => $tenant, 'code' => '6180', 'name_ar' => 'عجز الصندوق',
            'account_group' => 'expenses', 'normal_balance' => 'debit', 'is_active' => true,
        ]);
        $this->assertDatabaseHas('financial_accounts', [
            'tenant_id' => $tenant, 'code' => '4040', 'name_ar' => 'زيادة الصندوق',
            'account_group' => 'revenue', 'normal_balance' => 'credit', 'is_active' => true,
        ]);
    }

    public function test_branch_can_save_a_selected_variance_account_and_rejects_a_cash_location_account(): void
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'T1 Tenant', 'slug' => 'cva-select', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch);
        $owner = DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => 'cva-owner@example.test', 'password' => bcrypt('x'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, \App\Models\User::query()->find($owner))];
        $otherExpenseAccount = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $tenant, 'code' => 'CVA-EXP', 'name_ar' => 'مصروف اختباري', 'name_en' => 'Test expense',
            'account_group' => 'expenses', 'normal_balance' => 'debit', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $safeId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $safeAccountId = (int) DB::table('financial_locations')->where('id', $safeId)->value('financial_account_id');

        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", ['cashVarianceAccountId' => $safeAccountId], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('cashVarianceAccountId');
        $this->assertDatabaseMissing('branches', ['id' => $branch, 'cash_variance_account_id' => $safeAccountId]);

        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", ['cashVarianceAccountId' => $otherExpenseAccount], $headers)->assertOk()
            ->assertJsonPath('data.cashVarianceAccountId', $otherExpenseAccount);
        $this->assertDatabaseHas('branches', ['id' => $branch, 'cash_variance_account_id' => $otherExpenseAccount]);
        $this->assertSame($otherExpenseAccount, (int) app(CashVarianceService::class)->account($tenant, $branch)->id);
    }

    public function test_post_creates_a_debit_or_credit_entry_against_the_variance_account_depending_on_sign(): void
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'T1 Tenant', 'slug' => 'cva-post', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch);
        $owner = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => 'cva-post-owner@example.test', 'password' => bcrypt('x'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $safeId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $service = app(CashVarianceService::class);

        $shortageEntry = $service->post(Request::create('/'), $tenant, $branch, $safeId, -500, '2026-09-28', 'shift_cash_variance', 1001, 'عجز اختباري', $owner);
        $this->assertNotNull($shortageEntry);
        $variance6180 = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6180')->value('id');
        $safeAccountId = (int) DB::table('financial_locations')->where('id', $safeId)->value('financial_account_id');
        $this->assertDatabaseHas('journal_entry_lines', ['journal_entry_id' => $shortageEntry, 'financial_account_id' => $variance6180, 'debit' => '5.00', 'credit' => '0.00']);
        $this->assertDatabaseHas('journal_entry_lines', ['journal_entry_id' => $shortageEntry, 'financial_account_id' => $safeAccountId, 'debit' => '0.00', 'credit' => '5.00']);

        $surplusEntry = $service->post(Request::create('/'), $tenant, $branch, $safeId, 500, '2026-09-28', 'shift_cash_variance', 1002, 'زيادة اختبارية', $owner);
        $this->assertNotNull($surplusEntry);
        $over4040 = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '4040')->value('id');
        $this->assertDatabaseHas('journal_entry_lines', ['journal_entry_id' => $surplusEntry, 'financial_account_id' => $over4040, 'debit' => '0.00', 'credit' => '5.00']);
        $this->assertDatabaseHas('journal_entry_lines', ['journal_entry_id' => $surplusEntry, 'financial_account_id' => $safeAccountId, 'debit' => '5.00', 'credit' => '0.00']);

        $this->assertNull($service->post(Request::create('/'), $tenant, $branch, $safeId, 0, '2026-09-28', 'shift_cash_variance', 1003, 'لا فرق', $owner));
    }
}
