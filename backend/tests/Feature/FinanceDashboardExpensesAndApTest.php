<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/** Phase 10 test areas #25-31 (Operating Expenses lifecycle) and #39-43 (Supplier Payables / AP). */
class FinanceDashboardExpensesAndApTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_only_accounting_effective_paid_expense_is_counted(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'exp-effective');
        $branch = $this->branchId($tenant);
        $date = '2030-05-01';

        $this->postExpense($tenant, $branch, $date, '40.00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('40.00', $data['kpis']['operatingExpenses']['current']);
        $this->assertSame(1, $data['kpis']['operatingExpenses']['expenseCount']);
    }

    public function test_draft_and_rejected_expenses_are_excluded(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'exp-draft-rejected');
        $branch = $this->branchId($tenant);
        $date = '2030-05-02';

        $this->makeExpense($tenant, $branch, '10.00', $date, 'draft', null);
        $this->makeExpense($tenant, $branch, '20.00', $date, 'rejected', null);
        $this->makeExpense($tenant, $branch, '30.00', $date, 'approved', null); // approved but unpaid — no journal yet

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('0.00', $data['kpis']['operatingExpenses']['current']);
    }

    public function test_supplier_payment_is_never_counted_as_an_operating_expense(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'exp-supplier-payment');
        $branch = $this->branchId($tenant);
        $date = '2030-05-03';
        $supplier = $this->supplierId($tenant);

        // A supplier payment moves AP -> Cash; neither side touches an expenses-group account.
        $this->makeSupplierPayment($tenant, $branch, $supplier, '75.00', $date, 'CASH-DRAWER');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('0.00', $data['kpis']['operatingExpenses']['current']);
    }

    public function test_cash_paid_and_bank_paid_expense_are_each_counted_once_not_twice(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'exp-cash-bank');
        $branch = $this->branchId($tenant);
        $date = '2030-05-04';

        $this->postExpense($tenant, $branch, $date, '15.00', 'CASH-DRAWER');
        $this->postExpense($tenant, $branch, $date, '25.00', 'BANK');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('40.00', $data['kpis']['operatingExpenses']['current']);
        $this->assertSame(2, $data['kpis']['operatingExpenses']['expenseCount']);
    }

    public function test_company_wide_expense_is_included_tenant_wide_but_not_arbitrarily_assigned_to_one_branch(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $ownerHeaders = $this->headers($tenant, 'owner', 'exp-company');
        $branch = $this->branchId($tenant);
        $date = '2030-05-05';

        // A journal-only, branch_id=NULL expense-group posting (company-wide).
        $this->postCompanyWideExpenseJournal($tenant, $date, '60.00');

        $tenantWide = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date", $ownerHeaders)->assertOk()->json('data');
        $this->assertSame('60.00', $tenantWide['kpis']['operatingExpenses']['current']);

        $singleBranch = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $ownerHeaders)->assertOk()->json('data');
        $this->assertSame('0.00', $singleBranch['kpis']['operatingExpenses']['current']);
    }

    public function test_posted_supplier_invoice_increases_outstanding(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'ap-invoice');
        $branch = $this->branchId($tenant);
        $date = now()->addDays(10)->toDateString();
        $supplier = $this->supplierId($tenant);

        $this->makeSupplierInvoice($tenant, $branch, $supplier, '500.00', now()->toDateString());
        DB::table('supplier_invoices')->where('supplier_id', $supplier)->update(['due_date' => $date]);

        $data = $this->getJson('/api/v1/finance/dashboard?date_from='.now()->subDay()->toDateString().'&date_to='.now()->toDateString(), $headers)->assertOk()->json('data');
        $this->assertSame('500.00', $data['kpis']['supplierPayables']['outstanding']);
        $this->assertSame(1, $data['kpis']['supplierPayables']['openInvoiceCount']);
    }

    public function test_partial_and_full_payment_reduce_and_clear_outstanding(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'ap-partial-full');
        $branch = $this->branchId($tenant);
        $supplier = $this->supplierId($tenant);
        $today = now()->toDateString();

        $invoiceId = $this->makeSupplierInvoice($tenant, $branch, $supplier, '300.00', $today);
        $method = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $location = $this->locationId($tenant, 'CASH-DRAWER');

        $paymentId = $this->makeSupplierPayment($tenant, $branch, $supplier, '100.00', $today, 'CASH-DRAWER');
        DB::table('payment_allocations')->insert(['tenant_id' => $tenant, 'supplier_payment_id' => $paymentId, 'supplier_invoice_id' => $invoiceId, 'amount' => '100.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('supplier_invoices')->where('id', $invoiceId)->update(['status' => 'partially_paid']);

        $partial = $this->getJson("/api/v1/finance/dashboard?date_from=$today&date_to=$today", $headers)->assertOk()->json('data');
        $this->assertSame('200.00', $partial['kpis']['supplierPayables']['outstanding']);

        $fullPaymentId = $this->makeSupplierPayment($tenant, $branch, $supplier, '200.00', $today, 'CASH-DRAWER');
        DB::table('payment_allocations')->insert(['tenant_id' => $tenant, 'supplier_payment_id' => $fullPaymentId, 'supplier_invoice_id' => $invoiceId, 'amount' => '200.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('supplier_invoices')->where('id', $invoiceId)->update(['status' => 'paid']);

        $full = $this->getJson("/api/v1/finance/dashboard?date_from=$today&date_to=$today", $headers)->assertOk()->json('data');
        $this->assertSame('0.00', $full['kpis']['supplierPayables']['outstanding']);
    }

    public function test_overdue_amount_is_correct(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'ap-overdue');
        $branch = $this->branchId($tenant);
        $supplier = $this->supplierId($tenant);
        $today = now()->toDateString();

        $overdueInvoice = $this->makeSupplierInvoice($tenant, $branch, $supplier, '150.00', now()->subDays(20)->toDateString());
        DB::table('supplier_invoices')->where('id', $overdueInvoice)->update(['due_date' => now()->subDays(5)->toDateString()]);
        $notYetDueInvoice = $this->makeSupplierInvoice($tenant, $branch, $supplier, '90.00', $today);
        DB::table('supplier_invoices')->where('id', $notYetDueInvoice)->update(['due_date' => now()->addDays(5)->toDateString()]);

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$today&date_to=$today", $headers)->assertOk()->json('data');
        $this->assertSame('150.00', $data['kpis']['supplierPayables']['overdue']);
        $this->assertSame('240.00', $data['kpis']['supplierPayables']['outstanding']);
        $this->assertSame(1, $data['kpis']['supplierPayables']['overdueInvoiceCount']);
    }

    public function test_supplier_payment_is_not_double_counted_as_an_expense_in_the_ap_view(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'ap-not-expense');
        $branch = $this->branchId($tenant);
        $supplier = $this->supplierId($tenant);
        $today = now()->toDateString();

        $invoiceId = $this->makeSupplierInvoice($tenant, $branch, $supplier, '80.00', $today);
        $paymentId = $this->makeSupplierPayment($tenant, $branch, $supplier, '80.00', $today, 'CASH-DRAWER');
        DB::table('payment_allocations')->insert(['tenant_id' => $tenant, 'supplier_payment_id' => $paymentId, 'supplier_invoice_id' => $invoiceId, 'amount' => '80.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('supplier_invoices')->where('id', $invoiceId)->update(['status' => 'paid']);

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$today&date_to=$today&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('0.00', $data['kpis']['operatingExpenses']['current']);
        $this->assertSame('0.00', $data['kpis']['supplierPayables']['outstanding']);
    }

    private function postCompanyWideExpenseJournal(int $tenant, string $date, string $amount): int
    {
        $expenseAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6190')->value('id');
        $cashAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $journalId = (int) DB::table('journal_entries')->insertGetId(['tenant_id' => $tenant, 'branch_id' => null, 'entry_number' => 'CW-'.uniqid(), 'entry_date' => $date, 'source_type' => 'manual', 'status' => 'posted', 'posted_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $expenseAccountId, 'line_number' => 1, 'debit' => $amount, 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('journal_entry_lines')->insert(['tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $cashAccountId, 'line_number' => 2, 'debit' => '0.00', 'credit' => $amount, 'created_at' => now(), 'updated_at' => now()]);

        return $journalId;
    }
}
