<?php

namespace Tests\Feature;

use App\Services\AccountingPostingService;
use App\Services\PartyAccountService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** A supplier is also a customer, but has exactly one ledger account — under Suppliers. */
class SupplierSingleAccountTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private int $owner;

    private array $headers;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
        $this->tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $this->owner = (int) DB::table('users')->where('tenant_id', $this->tenant)->where('role', 'owner')->value('id');
        DB::table('api_tokens')->insert([
            'tenant_id' => $this->tenant, 'user_id' => $this->owner, 'name' => 'single-account-test',
            'token_hash' => hash('sha256', 'single-account-token'), 'expires_at' => now()->addDay(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->headers = ['Authorization' => 'Bearer single-account-token', 'X-Tenant-Id' => $this->tenant];
    }

    private function account(int $id): object
    {
        return DB::table('financial_accounts')->where('id', $id)->first();
    }

    private function codeId(string $code): int
    {
        return (int) DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', $code)->value('id');
    }

    private function journal(array $lines, string $sourceType = 'manual'): int
    {
        return app(AccountingPostingService::class)->post(Request::create('/x', 'POST'), $this->tenant, [
            'sourceType' => $sourceType, 'sourceId' => random_int(1000, 99999), 'sourceEvent' => 'TEST_POSTED',
            'entryDate' => now()->toDateString(), 'description' => 'اختبار', 'lines' => $lines,
        ], $this->owner);
    }

    public function test_new_supplier_gets_one_account_under_suppliers_and_is_a_customer(): void
    {
        $receivableChildren = DB::table('financial_accounts')->where('parent_account_id', $this->codeId('1200'))->count();
        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'مورد اختبار'], $this->headers)->assertCreated();
        $customerId = (int) $supplier->json('data.customerId');
        $accountId = (int) $supplier->json('data.financialAccountId');
        $this->assertGreaterThan(0, $customerId);

        $account = $this->account($accountId);
        $this->assertSame($this->codeId('2000'), (int) $account->parent_account_id);
        $this->assertSame('liabilities', $account->account_group);
        $this->assertSame('credit', $account->normal_balance);
        $this->assertSame('مورد اختبار', $account->name_ar);
        $customer = DB::table('customers')->where('id', $customerId)->first();
        $this->assertFalse((bool) $customer->is_walk_in);
        $this->assertSame($accountId, (int) $customer->financial_account_id);
        // Exactly one account for this person: nothing was created under receivables.
        $this->assertSame($receivableChildren, DB::table('financial_accounts')->where('parent_account_id', $this->codeId('1200'))->count());
    }

    public function test_existing_customer_becoming_supplier_moves_its_single_account_under_suppliers_keeping_postings(): void
    {
        $customer = $this->postJson('/api/v1/finance/customers', ['name' => 'Shared Person'], $this->headers)->assertCreated();
        $accountId = (int) $customer->json('data.financialAccountId');
        $this->assertSame($this->codeId('1200'), (int) $this->account($accountId)->parent_account_id);
        $entry = $this->journal([
            ['accountCode' => $this->account($accountId)->code, 'debit' => '30.00'],
            ['accountCode' => '4000', 'credit' => '30.00'],
        ], 'sales_invoice');

        $this->postJson('/api/v1/finance/suppliers', [
            'name' => 'Shared Person', 'customerId' => (int) $customer->json('data.id'),
        ], $this->headers)->assertCreated()->assertJsonPath('data.financialAccountId', $accountId);

        $account = $this->account($accountId);
        $this->assertSame($this->codeId('2000'), (int) $account->parent_account_id);
        $this->assertSame('liabilities', $account->account_group);
        $this->assertSame('credit', $account->normal_balance);
        $this->assertNull($account->deleted_at);
        $this->assertSame(1, DB::table('journal_entry_lines')->where('journal_entry_id', $entry)->where('financial_account_id', $accountId)->count());
    }

    public function test_sale_to_a_supplier_debits_its_single_account_and_shows_as_net_asset(): void
    {
        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'مورد يشتري منا'], $this->headers)->assertCreated();
        $accountId = (int) $supplier->json('data.financialAccountId');
        $code = $this->account($accountId)->code;

        $this->journal([
            ['accountCode' => $code, 'debit' => '75.00'],
            ['accountCode' => '4000', 'credit' => '75.00'],
        ], 'sales_invoice');

        $balance = $this->getJson('/api/v1/finance/accounts/'.$accountId, $this->headers)->assertOk();
        $this->assertSame('75.00', $balance->json('data.totalDebit'));
        $sheet = $this->getJson('/api/v1/finance/reports/balance-sheet?asOfDate='.now()->toDateString(), $this->headers)
            ->assertOk()->json('data');
        $this->assertTrue($sheet['integrity']['balanced']);
        $this->assertTrue(collect($sheet['assets']['accounts'])
            ->contains(fn (array $row): bool => $row['id'] === $accountId && $row['normalisedBalance'] === '75.00'));
    }

    public function test_imported_supplier_account_with_the_same_name_is_adopted_instead_of_duplicated(): void
    {
        $this->artisan('finance:import-phinix-accounts', ['tenantId' => $this->tenant, '--apply' => true])->assertExitCode(0);
        $imported = DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', '22321')->first();
        $this->assertFalse((bool) $imported->is_active);

        // The customer already exists with an account (with postings) under the customers parent (121).
        $customer = $this->postJson('/api/v1/finance/customers', ['name' => 'محمصة أرت للبن المختص'], $this->headers)->assertCreated();
        $legacyId = (int) $customer->json('data.financialAccountId');
        $this->assertSame($this->codeId('121'), (int) $this->account($legacyId)->parent_account_id);
        $entry = $this->journal([
            ['accountCode' => $this->account($legacyId)->code, 'debit' => '10.00'],
            ['accountCode' => '4000', 'credit' => '10.00'],
        ], 'sales_invoice');

        $supplier = $this->postJson('/api/v1/finance/suppliers', [
            'name' => 'محمصة ارت للبن المختص', 'customerId' => (int) $customer->json('data.id'),
        ], $this->headers)->assertCreated();

        $this->assertSame((int) $imported->id, (int) $supplier->json('data.financialAccountId'));
        $adopted = $this->account((int) $imported->id);
        $this->assertTrue((bool) $adopted->is_active);
        $this->assertSame('22321', $adopted->code);
        $this->assertSame(1, DB::table('journal_entry_lines')->where('journal_entry_id', $entry)->where('financial_account_id', $imported->id)->count());
        $this->assertNotNull($this->account($legacyId)->deleted_at, 'the old duplicate account is retired');
        $this->assertSame((int) $imported->id, (int) DB::table('customers')->where('id', $customer->json('data.id'))->value('financial_account_id'));
        $catalog = collect($this->getJson('/api/v1/finance/accounts/catalog', $this->headers)->assertOk()->json('data'));
        $this->assertSame(1, $catalog->filter(fn (array $a): bool => str_contains($a['nameAr'], 'ارت للبن'))->count());
    }

    public function test_repair_command_and_service_fix_legacy_supplier_accounts(): void
    {
        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'مورد قديم'], $this->headers)->assertCreated();
        $accountId = (int) $supplier->json('data.financialAccountId');
        // Legacy state: the shared account was created under the receivables parent.
        $parent = DB::table('financial_accounts')->where('id', $this->codeId('1200'))->first();
        DB::table('financial_accounts')->where('id', $accountId)->update([
            'parent_account_id' => $parent->id, 'account_group' => 'assets', 'normal_balance' => 'debit',
        ]);

        $service = app(PartyAccountService::class);
        $this->assertSame(1, $service->consolidateSuppliers($this->tenant, false));
        $this->assertSame($this->codeId('1200'), (int) $this->account($accountId)->parent_account_id, 'dry run changes nothing');
        $this->artisan('finance:consolidate-supplier-accounts', ['tenantId' => $this->tenant, '--apply' => true])->assertExitCode(0);
        $this->assertSame($this->codeId('2000'), (int) $this->account($accountId)->parent_account_id);
        $this->assertSame('credit', $this->account($accountId)->normal_balance);
        $this->assertSame(0, $service->consolidateSuppliers($this->tenant, false));
    }

    public function test_payables_integrity_ignores_sales_side_postings_on_a_shared_account(): void
    {
        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'مورد وعميل'], $this->headers)->assertCreated();
        $code = $this->account((int) $supplier->json('data.financialAccountId'))->code;
        $this->journal([['accountCode' => $code, 'debit' => '20.00'], ['accountCode' => '4000', 'credit' => '20.00']], 'sales_invoice');

        $result = app(\App\Services\FinancialIntegrityService::class)->inspect($this->tenant);
        $check = collect($result['checks'] ?? $result['results'] ?? [])->firstWhere('code', 'ACCOUNTS_PAYABLE_RECONCILIATION_MISMATCH');
        $this->assertNotNull($check, 'AP check present');
        $this->assertSame(0, $check['count']);
    }

    public function test_renaming_the_supplier_renames_its_customer_and_single_account(): void
    {
        $supplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'اسم قديم'], $this->headers)->assertCreated();
        $id = (int) $supplier->json('data.id');
        $this->patchJson('/api/v1/finance/suppliers/'.$id, ['name' => 'اسم جديد'], $this->headers)->assertOk();

        $this->assertSame('اسم جديد', DB::table('customers')->where('id', $supplier->json('data.customerId'))->value('name'));
        $this->assertSame('اسم جديد', $this->account((int) $supplier->json('data.financialAccountId'))->name_ar);
    }

    public function test_legacy_supplier_without_customer_becomes_searchable_customer_after_repair(): void
    {
        $id = DB::table('suppliers')->insertGetId([
            'tenant_id' => $this->tenant, 'supplier_number' => 'SUP-09999', 'name' => 'معمل ياسمين السوادي للحلى',
            'is_active' => true, 'payment_terms_days' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->getJson('/api/v1/customers?search='.rawurlencode('ياسمين'), $this->headers)->assertOk()->assertJsonCount(0, 'data');

        $this->artisan('finance:consolidate-supplier-accounts', ['tenantId' => $this->tenant, '--apply' => true])->assertExitCode(0);

        $found = $this->getJson('/api/v1/customers?search='.rawurlencode('ياسمين'), $this->headers)->assertOk();
        $this->assertSame(['معمل ياسمين السوادي للحلى'], $found->json('data.*.name'));
        $customerId = (int) DB::table('suppliers')->where('id', $id)->value('customer_id');
        $this->assertSame($customerId, (int) $found->json('data.0.id'));
        $this->assertNotNull(DB::table('customers')->where('id', $customerId)->value('financial_account_id'));
    }
}
