<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PartyAccountApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_and_supplier_share_one_account_and_supplier_posting_appears_in_ledger(): void
    {
        $this->seed();
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $user = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        $token = 'party-account-test-token';
        DB::table('api_tokens')->insert([
            'tenant_id' => $tenant, 'user_id' => $user, 'name' => 'party-test',
            'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $headers = ['Authorization' => 'Bearer '.$token, 'X-Tenant-Id' => $tenant];

        $customer = $this->postJson('/api/v1/finance/customers', ['name' => 'Shared Person'], $headers)->assertCreated();
        $customerId = (int) $customer->json('data.id');
        $accountId = (int) $customer->json('data.financialAccountId');
        $this->assertGreaterThan(0, $accountId);

        $supplier = $this->postJson('/api/v1/finance/suppliers', [
            'name' => 'Shared Person', 'customerId' => $customerId,
        ], $headers)->assertCreated()->assertJsonPath('data.customerId', $customerId)
            ->assertJsonPath('data.financialAccountId', $accountId);
        $supplierId = (int) $supplier->json('data.id');
        $this->postJson('/api/v1/finance/suppliers', [
            'name' => 'Duplicate', 'customerId' => $customerId,
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('customerId');

        $expenseAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6100')->value('id');
        $category = $this->postJson('/api/v1/finance/expense-categories', [
            'code' => 'PARTYTEST', 'name' => 'Party expense', 'financialAccountId' => $expenseAccount, 'isActive' => true,
        ], $headers)->assertCreated();
        $date = now()->toDateString();
        $invoice = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'PARTY-1',
            'invoiceDate' => $date, 'dueDate' => now()->addDays(30)->toDateString(),
            'invoiceType' => 'expense', 'expenseCategoryId' => $category->json('data.id'),
            'subtotal' => '40.00',
        ], $headers)->assertCreated();
        $posted = $this->postJson('/api/v1/finance/supplier-invoices/'.$invoice->json('data.id').'/post', [
            'idempotencyKey' => 'party-invoice-1',
        ], $headers)->assertOk();
        $credit = DB::table('journal_entry_lines')->where('journal_entry_id', $posted->json('data.journalEntryId'))
            ->where('financial_account_id', $accountId)->value('credit');
        $this->assertSame(40.0, (float) $credit);
        $this->getJson('/api/v1/finance/accounts/'.$accountId.'/transactions', $headers)
            ->assertOk()->assertJsonFragment(['credit' => '40.00']);
        $sheet = $this->getJson('/api/v1/finance/reports/balance-sheet?asOfDate='.$date, $headers)
            ->assertOk()->json('data');
        $this->assertTrue($sheet['integrity']['balanced']);
        $this->assertTrue(collect($sheet['liabilities']['accounts'])
            ->contains(fn (array $row): bool => $row['id'] === $accountId && $row['normalisedBalance'] === '40.00'));

        $newSupplier = $this->postJson('/api/v1/finance/suppliers', ['name' => 'Supplier First'], $headers)
            ->assertCreated();
        $this->assertGreaterThan(0, (int) $newSupplier->json('data.customerId'));
        $this->assertGreaterThan(0, (int) $newSupplier->json('data.financialAccountId'));
        $this->getJson('/api/v1/finance/customers/'.$newSupplier->json('data.customerId'), $headers)
            ->assertOk()->assertJsonPath('data.financialAccountId', $newSupplier->json('data.financialAccountId'));
    }
}
