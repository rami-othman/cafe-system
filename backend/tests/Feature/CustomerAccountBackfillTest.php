<?php

namespace Tests\Feature;

use App\Services\CustomerAccountBackfill;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class CustomerAccountBackfillTest extends TestCase
{
    use RefreshDatabase;

    public function test_missing_customers_get_distinct_visible_accounts_without_merging_or_touching_existing_links(): void
    {
        $tenant = $this->tenant('one');
        $otherTenant = $this->tenant('two');
        $one = $this->customer($tenant, 'ادارة تيرفور');
        $two = $this->customer($tenant, 'ادارة تيرفور');
        $walkIn = $this->customer($tenant, 'Cash', ['is_walk_in' => true, 'customer_type' => 'walk_in']);
        $inactive = $this->customer($tenant, 'Inactive', ['is_active' => false]);
        $deleted = $this->customer($tenant, 'Deleted', ['deleted_at' => now()]);
        $foreign = $this->customer($otherTenant, 'Other tenant');
        $existingAccount = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '121')->value('id');
        $existing = $this->customer($tenant, 'Already linked', ['financial_account_id' => $existingAccount]);
        $original = DB::table('customers')->orderBy('id')->get();
        $service = app(CustomerAccountBackfill::class);
        $this->assertSame([$one, $two], $service->run($tenant)['customerIds']);
        $this->assertEquals($original, DB::table('customers')->orderBy('id')->get());
        $result = $service->run($tenant, true, str_repeat('a', 64));
        $this->assertTrue($result['ledgerUnchanged']);
        $this->assertCount(2, $result['linked']);
        $this->assertNotSame($result['linked'][0]['accountId'], $result['linked'][1]['accountId']);
        foreach ([$one, $two] as $id) {
            $account = DB::table('financial_accounts')->where('id', DB::table('customers')->where('id', $id)->value('financial_account_id'))->first();
            $this->assertSame('P'.$id, $account->code);
            $this->assertSame($existingAccount, $account->parent_account_id);
            $this->assertSame('phinix', $account->catalog_source);
        }
        foreach ([$walkIn, $inactive, $deleted, $foreign] as $id) {
            $this->assertNull(DB::table('customers')->where('id', $id)->value('financial_account_id'));
        }
        $this->assertSame($existingAccount, DB::table('customers')->where('id', $existing)->value('financial_account_id'));
        $this->assertSame(0, DB::table('journal_entries')->count());
        $this->assertSame(0, $service->run($tenant, true, str_repeat('a', 64))['missing']);
        $this->assertSame(2, DB::table('activity_logs')->where('action', 'customer.financial_account_backfilled')->count());
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $this->getJson('/api/v1/finance/accounts/catalog', $headers)->assertOk()->assertJsonFragment(['code' => 'P'.$one]);
    }

    public function test_failure_rolls_back_prior_customer_links(): void
    {
        $tenant = $this->tenant('rollback');
        $one = $this->customer($tenant, 'First');
        $two = $this->customer($tenant, 'Second');
        // A conflicting code must fail rather than silently adopting an unrelated ledger.
        DB::table('financial_accounts')->insert(['tenant_id' => $tenant, 'code' => 'P'.$two, 'name_ar' => 'Existing', 'name_en' => 'Existing', 'account_group' => 'assets', 'normal_balance' => 'debit']);
        try {
            app(CustomerAccountBackfill::class)->run($tenant, true, str_repeat('a', 64));
            $this->fail('Expected a conflicting-code failure');
        } catch (QueryException $error) {
            $this->assertSame('23505', $error->errorInfo[0]);
        }
        $this->assertNull(DB::table('customers')->where('id', $one)->value('financial_account_id'));
        $this->assertFalse(DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', 'P'.$one)->exists());
        $this->assertSame(0, DB::table('activity_logs')->where('action', 'customer.financial_account_backfilled')->count());
    }

    private function tenant(string $slug): int
    {
        $id = DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'status' => 'active']);
        foreach (['121', '223'] as $code) {
            DB::table('financial_accounts')->insert(['tenant_id' => $id, 'code' => $code, 'name_ar' => $code, 'name_en' => $code,
                'account_group' => $code === '121' ? 'assets' : 'liabilities', 'normal_balance' => $code === '121' ? 'debit' : 'credit', 'catalog_source' => 'phinix']);
        }

        return $id;
    }

    private function customer(int $tenant, string $name, array $extra = []): int
    {
        return DB::table('customers')->insertGetId($extra + ['tenant_id' => $tenant, 'name' => $name, 'normalized_name' => $name, 'customer_number' => 'TEST-'.uniqid(), 'customer_type' => 'registered', 'is_active' => true, 'is_walk_in' => false]);
    }
}
