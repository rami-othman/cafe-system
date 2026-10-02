<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PhinixAccountImportTest extends TestCase
{
    use RefreshDatabase;

    public function test_catalog_import_is_preview_first_complete_and_idempotent(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->orderBy('id')->value('id');
        $before = DB::table('financial_accounts')->where('tenant_id', $tenantId)->count();
        $journalsBefore = DB::table('journal_entries')->where('tenant_id', $tenantId)->count();

        $this->artisan('finance:import-phinix-accounts', ['tenantId' => $tenantId])->assertExitCode(0);
        $this->assertSame($before, DB::table('financial_accounts')->where('tenant_id', $tenantId)->count());

        $this->artisan('finance:import-phinix-accounts', ['tenantId' => $tenantId, '--apply' => true])->assertExitCode(0);
        $this->assertSame($before + 5075, DB::table('financial_accounts')->where('tenant_id', $tenantId)->count());
        $this->assertSame(5075, DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('catalog_source', 'phinix')->count());
        $catalog = collect($this->getJson('/api/v1/finance/accounts/catalog', ['X-Tenant-Id' => (string) $tenantId])->assertOk()->json('data'));
        $this->assertCount(5075, $catalog);
        $this->assertFalse($catalog->contains(fn (array $account) => $account['code'] === '1010'));
        $capital = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '211')->first();
        $this->assertSame('equity', $capital->account_group);
        $this->assertSame('credit', $capital->normal_balance);
        $this->assertSame('liabilities', DB::table('financial_accounts')->where('id', $capital->parent_account_id)->value('account_group'));
        $depreciation = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1152')->first();
        $this->assertSame('assets', $depreciation->account_group);
        $this->assertSame('credit', $depreciation->normal_balance);
        $this->assertSame('debit', DB::table('financial_accounts')->where('id', $depreciation->parent_account_id)->value('normal_balance'));
        $party = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1211')->first();
        $this->assertFalse((bool) $party->is_active);
        $this->assertSame($journalsBefore, DB::table('journal_entries')->where('tenant_id', $tenantId)->count());

        $this->artisan('finance:import-phinix-accounts', ['tenantId' => $tenantId, '--apply' => true])->assertExitCode(0);
        $this->assertSame($before + 5075, DB::table('financial_accounts')->where('tenant_id', $tenantId)->count());

        $root = $this->postJson('/api/v1/finance/accounts', [
            'code' => 'PHINIX-TEST-ROOT', 'nameAr' => 'حساب جديد', 'nameEn' => 'New Account',
            'accountGroup' => 'assets', 'normalBalance' => 'debit', 'isActive' => true,
        ], ['X-Tenant-Id' => (string) $tenantId])->assertCreated();
        $this->assertSame('phinix', DB::table('financial_accounts')->where('id', $root->json('data.id'))->value('catalog_source'));
    }
}
