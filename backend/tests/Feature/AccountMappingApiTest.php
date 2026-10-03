<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** The owner chooses which account each kind of posting uses; the server only accepts the right kind of leaf account. */
final class AccountMappingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_remaps_a_posting_account_and_the_server_rejects_the_wrong_kind(): void
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Mapping', 'slug' => 'map-'.uniqid(), 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];

        $rows = $this->getJson('/api/v1/finance/account-mappings', $headers)->assertOk()->json('data');
        $byKey = array_column($rows, null, 'key');
        $this->assertSame('4000', $byKey['sales.revenue']['accountCode']);

        $newRevenue = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $tenant, 'code' => '41', 'name_ar' => 'المبيعات', 'name_en' => 'Sales', 'account_group' => 'revenue',
            'normal_balance' => 'credit', 'is_active' => true, 'is_system_protected' => false, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->putJson('/api/v1/finance/account-mappings/sales.revenue', ['accountId' => $newRevenue], $headers)->assertOk()->assertJsonPath('data.accountCode', '41');
        $this->assertSame('41', collect($this->getJson('/api/v1/finance/account-mappings', $headers)->json('data'))->firstWhere('key', 'sales.revenue')['accountCode']);
        $this->assertSame($newRevenue, app(\App\Services\FinanceAccountMap::class)->id($tenant, 'sales.revenue'));

        // Wrong kind: an expense account cannot carry revenue; a cash box account cannot be a posting target.
        $expense = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('account_group', 'expenses')->value('id');
        $this->putJson('/api/v1/finance/account-mappings/sales.revenue', ['accountId' => $expense], $headers)->assertUnprocessable()->assertJsonValidationErrors('accountId');
        $this->putJson('/api/v1/finance/account-mappings/not.a.key', ['accountId' => $newRevenue], $headers)->assertUnprocessable();

        // A parent (non-leaf) account is refused.
        DB::table('financial_accounts')->insert([
            'tenant_id' => $tenant, 'parent_account_id' => $newRevenue, 'code' => '411', 'name_ar' => 'فرعي', 'name_en' => 'child', 'account_group' => 'revenue',
            'normal_balance' => 'credit', 'is_active' => true, 'is_system_protected' => false, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->putJson('/api/v1/finance/account-mappings/sales.revenue', ['accountId' => $newRevenue], $headers)->assertUnprocessable();
    }

    public function test_defaults_fill_empty_and_unusable_mappings_from_the_imported_chart(): void
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Defaults', 'slug' => 'def-'.uniqid(), 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $chart = [ // code => [parent, group, normal]
            '1' => [null, 'assets', 'debit'], '12' => ['1', 'assets', 'debit'], '121' => ['12', 'assets', 'debit'], '124' => ['12', 'assets', 'debit'],
            '13' => ['1', 'assets', 'debit'], '131' => ['13', 'assets', 'debit'],
            '2' => [null, 'liabilities', 'credit'], '22' => ['2', 'liabilities', 'credit'], '223' => ['22', 'liabilities', 'credit'],
            '21' => ['2', 'liabilities', 'credit'], '211' => ['21', 'equity', 'credit'],
            '3' => [null, 'cost_of_sales', 'debit'],
            '4' => [null, 'revenue', 'credit'], '41' => ['4', 'revenue', 'credit'], '42' => ['4', 'revenue', 'debit'], '43' => ['4', 'revenue', 'debit'],
            '5' => [null, 'expenses', 'debit'], '510' => ['5', 'expenses', 'debit'], '6' => [null, 'revenue', 'credit'], '62' => ['6', 'revenue', 'credit'],
        ];
        $ids = [];
        foreach ($chart as $code => [$parent, $group, $normal]) {
            $ids[$code] = (int) DB::table('financial_accounts')->insertGetId([
                'tenant_id' => $tenant, 'parent_account_id' => $parent ? $ids[$parent] : null, 'code' => $code, 'name_ar' => 'حساب '.$code, 'name_en' => $code,
                'account_group' => $group, 'normal_balance' => $normal, 'is_active' => true, 'is_system_protected' => false,
                'catalog_source' => 'phinix', 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
        // Revenue points at the header account "6" (not a final account) - unusable.
        DB::table('sales_account_mappings')->insert(['tenant_id' => $tenant, 'mapping_key' => 'sales.revenue', 'financial_account_id' => $ids['6'], 'created_at' => now(), 'updated_at' => now()]);
        $before = collect($this->getJson('/api/v1/finance/account-mappings', $headers)->assertOk()->json('data'));
        $this->assertTrue($before->firstWhere('key', 'sales.revenue')['needsDefault']);
        $this->assertTrue($before->firstWhere('key', 'sales.cost_of_goods_sold')['needsDefault']);

        $this->postJson('/api/v1/finance/account-mappings/defaults', [], $headers)->assertOk();

        $after = collect($this->getJson('/api/v1/finance/account-mappings', $headers)->json('data'))->keyBy('key');
        foreach (['sales.revenue' => '41', 'sales.discount_given' => '43', 'sales.sales_returns' => '42', 'sales.tax_payable' => '225',
            'sales.cost_of_goods_sold' => '36', 'sales.inventory_asset' => '124', 'sales.accounts_receivable' => '121',
            'sales.customer_credit' => '226', 'inventory.variance' => '517', 'inventory.opening_equity' => '211',
            'cash.over' => '65', 'cash.short' => '510', 'cash.drawer' => '131'] as $key => $code) {
            $this->assertSame($code, $after[$key]['accountCode'], $key);
            $this->assertFalse($after[$key]['needsDefault'], $key);
        }
    }

    public function test_remap_adds_the_missing_phoenix_accounts_and_moves_cash_overage_from_61_to_65(): void
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Phoenix', 'slug' => 'phx-'.uniqid(), 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $chart = [
            '1' => [null, 'assets', 'debit'], '12' => ['1', 'assets', 'debit'], '124' => ['12', 'assets', 'debit'],
            '13' => ['1', 'assets', 'debit'], '131' => ['13', 'assets', 'debit'],
            '2' => [null, 'liabilities', 'credit'], '22' => ['2', 'liabilities', 'credit'],
            '3' => [null, 'cost_of_sales', 'debit'], '4' => [null, 'revenue', 'credit'], '41' => ['4', 'revenue', 'credit'],
            '5' => [null, 'expenses', 'debit'], '6' => [null, 'revenue', 'credit'],
        ];
        $ids = [];
        foreach ($chart as $code => [$parent, $group, $normal]) {
            $ids[$code] = (int) DB::table('financial_accounts')->insertGetId([
                'tenant_id' => $tenant, 'parent_account_id' => $parent ? $ids[$parent] : null, 'code' => $code, 'name_ar' => 'حساب '.$code, 'name_en' => $code,
                'account_group' => $group, 'normal_balance' => $normal, 'is_active' => true, 'is_system_protected' => false,
                'catalog_source' => 'phinix', 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
        // State left by the first remap: 61 was created as "cash overage" and the mapping pointed at it.
        $old = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $tenant, 'parent_account_id' => $ids['6'], 'code' => '61', 'name_ar' => 'إيراد زيادة صندوق', 'name_en' => 'x',
            'account_group' => 'revenue', 'normal_balance' => 'credit', 'is_active' => true, 'is_system_protected' => true,
            'catalog_source' => 'phinix', 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('sales_account_mappings')->insert(['tenant_id' => $tenant, 'mapping_key' => 'cash.over', 'financial_account_id' => $old, 'created_at' => now(), 'updated_at' => now()]);

        app(\App\Services\PhinixRemapService::class)->remapConfiguration($tenant, true);

        $code = fn (string $c) => DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $c)->first();
        foreach (['62', '621', '629', '63', '64', '65', '7', '71'] as $c) {
            $this->assertNotNull($code($c), $c);
        }
        $this->assertSame('إيرادات مختلفة', $code('61')->name_ar);
        $this->assertSame((int) $code('62')->id, (int) $code('621')->parent_account_id);
        $this->assertNull($code('7')->parent_account_id);
        $this->assertSame((int) $code('7')->id, (int) $code('71')->parent_account_id);
        $this->assertSame((int) $code('65')->id, (int) DB::table('sales_account_mappings')->where('tenant_id', $tenant)->where('mapping_key', 'cash.over')->value('financial_account_id'));
    }
}
