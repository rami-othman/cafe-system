<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use App\Support\FinanceAccess;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Row-level regression coverage for the canonical Finance branch-sensitive
 * routes.  Each rejected mutation asserts the persisted row/journal count is
 * unchanged, rather than treating a 403/404 response as sufficient proof.
 */
final class FinanceBranchIsolationTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;
    private int $branchA;
    private int $branchB;
    private array $owner;
    private array $managerA;
    private array $managerB;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
        $this->tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branches = DB::table('branches')->where('tenant_id', $this->tenant)->orderBy('id')->pluck('id')->map(fn ($id) => (int) $id)->all();
        $this->branchA = $branches[0];
        $this->branchB = $branches[1] ?? $this->newBranch('Branch B');
        $this->owner = $this->headers($this->ownerId());
        $this->managerA = $this->managerHeaders($this->branchA, 'a');
        $this->managerB = $this->managerHeaders($this->branchB, 'b');
    }

    public function test_transactions_and_journals_are_filtered_and_other_branch_mutations_are_side_effect_free(): void
    {
        $account = $this->account('1010'); $offset = $this->account('3000');
        $a = $this->journal($this->branchA, 'BRANCH-A-JOURNAL', $account, $offset, '10.00');
        $b = $this->journal($this->branchB, 'BRANCH-B-JOURNAL', $account, $offset, '90.00');

        $ids = collect($this->getJson('/api/v1/finance/transactions?perPage=100', $this->managerA)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($a)); $this->assertFalse($ids->contains($b));
        $this->getJson('/api/v1/finance/transactions/'.$b, $this->managerA)->assertNotFound();
        $this->getJson('/api/v1/finance/transactions?branch_id='.$this->branchB, $this->managerA)->assertForbidden();

        $journalIds = collect($this->getJson('/api/v1/finance/journal-entries?perPage=100', $this->managerA)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($journalIds->contains($a)); $this->assertFalse($journalIds->contains($b));
        $this->getJson('/api/v1/finance/journal-entries/'.$b, $this->managerA)->assertForbidden();
        $before = DB::table('journal_entries')->where('id', $b)->first();
        $this->postJson('/api/v1/finance/journal-entries/'.$b.'/post', [], $this->managerA)->assertForbidden();
        $this->assertSame($before->status, DB::table('journal_entries')->where('id', $b)->value('status'));
        $this->assertNull(DB::table('journal_entries')->where('reversal_of_id', $b)->value('id'));
        $this->getJson('/api/v1/finance/journal-entries/'.$b, $this->owner)->assertOk();

        DB::table('journal_entries')->whereIn('id', [$a, $b])->update(['status' => 'posted', 'posted_at' => now(), 'posted_by' => $this->ownerId()]);
        $ledger = $this->getJson('/api/v1/finance/reports/general-ledger?accountId='.$account.'&dateFrom=2026-09-01&dateTo=2026-09-01', $this->managerA)->assertOk();
        $reportJournals = collect($ledger->json('data.lines'))->pluck('journal.id');
        $this->assertTrue($reportJournals->contains($a)); $this->assertFalse($reportJournals->contains($b));
        $this->getJson('/api/v1/finance/dashboard?branch_id='.$this->branchB, $this->managerA)->assertForbidden();
        $this->getJson('/api/v1/finance/dashboard/branches?date_from=2026-09-01&date_to=2026-09-01', $this->managerA)->assertOk()->assertJsonMissing(['id' => $this->branchB]);
    }

    public function test_cash_bank_locations_and_transfers_cannot_cross_branch_or_tenant(): void
    {
        [$cashA, $cashA2, $bankA, $cashB, $bankB] = $this->locations();
        $cashIds = collect($this->getJson('/api/v1/finance/cash-accounts?perPage=100', $this->managerA)->assertOk()->json('data'))->pluck('id');
        $bankIds = collect($this->getJson('/api/v1/finance/bank-accounts?perPage=100', $this->managerA)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($cashIds->contains($cashA)); $this->assertFalse($cashIds->contains($cashB));
        $this->assertTrue($bankIds->contains($bankA)); $this->assertFalse($bankIds->contains($bankB));
        foreach (["cash-accounts/$cashB", "cash-accounts/$cashB/transactions", "bank-accounts/$bankB", "bank-accounts/$bankB/transactions"] as $path) $this->getJson('/api/v1/finance/'.$path, $this->managerA)->assertForbidden();
        $this->getJson('/api/v1/finance/cash-accounts/'.$bankA, $this->managerA)->assertNotFound();
        $this->getJson('/api/v1/finance/bank-accounts/'.$cashA, $this->managerA)->assertNotFound();

        $transfers = DB::table('cash_transfers')->where('tenant_id', $this->tenant)->count(); $journals = DB::table('journal_entries')->where('tenant_id', $this->tenant)->count();
        $this->postJson('/api/v1/finance/cash-transfers', ['fromFinancialLocationId' => $cashB, 'toFinancialLocationId' => $cashA, 'amount' => '5.00', 'transferDate' => '2026-09-01', 'idempotencyKey' => 'blocked-cross-branch-transfer'], $this->managerA)->assertForbidden();
        $this->assertSame($transfers, DB::table('cash_transfers')->where('tenant_id', $this->tenant)->count()); $this->assertSame($journals, DB::table('journal_entries')->where('tenant_id', $this->tenant)->count());
        $this->postJson('/api/v1/finance/cash-transfers', ['fromFinancialLocationId' => $cashA, 'toFinancialLocationId' => $cashA2, 'amount' => '5.00', 'transferDate' => '2026-09-01', 'idempotencyKey' => 'allowed-branch-a-transfer'], $this->managerA)->assertCreated();

        $other = $this->otherTenantHeaders();
        $this->getJson('/api/v1/finance/cash-accounts/'.$cashA, $other)->assertNotFound();
        $this->getJson('/api/v1/finance/bank-accounts/'.$bankA, $other)->assertNotFound();
    }

    public function test_expenses_supplier_invoices_and_payments_hide_other_branch_rows_and_reject_actions_without_side_effects(): void
    {
        [$expenseA, $expenseB] = $this->expenses(); [$invoiceA, $invoiceB] = $this->invoices(); [$paymentA, $paymentB] = $this->payments($invoiceA, $invoiceB);
        foreach ([['expenses', $expenseA, $expenseB], ['supplier-invoices', $invoiceA, $invoiceB], ['supplier-payments', $paymentA, $paymentB]] as [$path, $a, $b]) {
            $ids = collect($this->getJson('/api/v1/finance/'.$path.'?perPage=100', $this->managerA)->assertOk()->json('data'))->pluck('id');
            $this->assertTrue($ids->contains($a)); $this->assertFalse($ids->contains($b));
            $this->getJson('/api/v1/finance/'.$path.'/'.$b, $this->managerA)->assertForbidden();
        }
        $expenseBefore = DB::table('expenses')->where('id', $expenseB)->first(); $journalCount = DB::table('journal_entries')->where('tenant_id', $this->tenant)->count();
        $this->postJson('/api/v1/finance/expenses/'.$expenseB.'/submit', [], $this->managerA)->assertForbidden();
        $this->assertSame($expenseBefore->status, DB::table('expenses')->where('id', $expenseB)->value('status')); $this->assertSame($journalCount, DB::table('journal_entries')->where('tenant_id', $this->tenant)->count());
        $invoiceBefore = DB::table('supplier_invoices')->where('id', $invoiceB)->first();
        $this->postJson('/api/v1/finance/supplier-invoices/'.$invoiceB.'/post', ['idempotencyKey' => 'blocked-invoice-post'], $this->managerA)->assertForbidden();
        $this->assertSame($invoiceBefore->status, DB::table('supplier_invoices')->where('id', $invoiceB)->value('status')); $this->assertNull(DB::table('supplier_invoices')->where('id', $invoiceB)->value('journal_entry_id'));
        $this->postJson('/api/v1/finance/supplier-payments/'.$paymentB.'/reverse', [], $this->managerA)->assertForbidden();
        $this->assertSame('posted', DB::table('supplier_payments')->where('id', $paymentB)->value('status')); $this->assertNull(DB::table('supplier_payments')->where('id', $paymentB)->value('reversal_journal_entry_id'));
    }

    public function test_reconciliations_and_daily_closings_protect_rows_and_mutations(): void
    {
        [$cashA, , , $cashB] = $this->locations();
        $recA = $this->reconciliation($cashA, $this->branchA, 'REC-A'); $recB = $this->reconciliation($cashB, $this->branchB, 'REC-B');
        $ids = collect($this->getJson('/api/v1/finance/reconciliations?perPage=100', $this->managerA)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($recA)); $this->assertFalse($ids->contains($recB));
        $this->getJson('/api/v1/finance/reconciliations/'.$recB, $this->managerA)->assertNotFound();
        $lines = DB::table('financial_reconciliation_statement_lines')->where('financial_reconciliation_id', $recB)->count();
        $this->postJson('/api/v1/finance/reconciliations/'.$recB.'/statement-lines', ['transactionDate' => '2026-09-01', 'description' => 'blocked', 'amount' => '1.00', 'direction' => 'inflow'], $this->managerA)->assertForbidden();
        $this->assertSame($lines, DB::table('financial_reconciliation_statement_lines')->where('financial_reconciliation_id', $recB)->count());
        $before = DB::table('financial_reconciliations')->where('id', $recB)->first();
        $this->patchJson('/api/v1/finance/reconciliations/'.$recB, ['actualCashCount' => '1.00'], $this->managerA)->assertForbidden();
        $this->assertSame($before->actual_cash_count, DB::table('financial_reconciliations')->where('id', $recB)->value('actual_cash_count'));

        $closeA = $this->closing($this->branchA, '2026-09-10'); $closeB = $this->closing($this->branchB, '2026-09-10');
        $closeIds = collect($this->getJson('/api/v1/finance/daily-closings?perPage=100', $this->managerA)->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($closeIds->contains($closeA)); $this->assertFalse($closeIds->contains($closeB));
        $this->getJson('/api/v1/finance/daily-closings/'.$closeB, $this->managerA)->assertForbidden();
        $this->patchJson('/api/v1/finance/daily-closings/'.$closeB, ['actualCash' => '1.00'], $this->managerA)->assertForbidden();
        $this->assertNull(DB::table('daily_closings')->where('id', $closeB)->value('actual_cash'));
    }

    public function test_tenant_wide_period_accounts_and_settings_follow_permission_and_tenant_contracts(): void
    {
        $period = (int) DB::table('accounting_periods')->where('tenant_id', $this->tenant)->value('id');
        if (! $period) $period = (int) DB::table('accounting_periods')->insertGetId(['tenant_id'=>$this->tenant,'name'=>'Tenant-wide contract period','start_date'=>'2026-01-01','end_date'=>'2026-12-31','status'=>'open','created_at'=>now(),'updated_at'=>now()]);
        $this->getJson('/api/v1/finance/accounting-periods/'.$period, $this->managerA)->assertOk();
        $this->getJson('/api/v1/finance/accounts', $this->managerA)->assertOk();
        $this->getJson('/api/v1/finance/payment-methods', $this->managerA)->assertOk();
        $this->getJson('/api/v1/finance/expense-categories', $this->managerA)->assertOk();
        $this->getJson('/api/v1/finance/settings/approval-rules', $this->managerA)->assertOk();
        $this->getJson('/api/v1/finance/settings/role-permissions', $this->managerA)->assertOk();
        $other = $this->otherTenantHeaders();
        $this->getJson('/api/v1/finance/accounting-periods/'.$period, $other)->assertNotFound();
        $this->getJson('/api/v1/finance/accounts', $other)->assertOk()->assertJsonMissing(['id' => $this->account('1010')]);
    }

    private function locations(): array { return [$this->location($this->branchA, 'cash', 'A-CASH-1'), $this->location($this->branchA, 'cash', 'A-CASH-2'), $this->location($this->branchA, 'bank', 'A-BANK'), $this->location($this->branchB, 'cash', 'B-CASH'), $this->location($this->branchB, 'bank', 'B-BANK')]; }
    private function location(int $branch, string $kind, string $code): int { $account = (int) DB::table('financial_accounts')->insertGetId(['tenant_id'=>$this->tenant,'code'=>$code.'-ACCOUNT','name_ar'=>$code,'name_en'=>$code,'account_group'=>'assets','normal_balance'=>'debit','is_active'=>true,'created_at'=>now(),'updated_at'=>now()]); return (int) DB::table('financial_locations')->insertGetId(['tenant_id'=>$this->tenant,'branch_id'=>$branch,'financial_account_id'=>$account,'code'=>$code,'name'=>$code,'kind'=>$kind,'type'=>$kind==='bank'?'bank':'cash_drawer','bank_name'=>$kind==='bank'?'Bank':'' ,'is_active'=>true,'created_at'=>now(),'updated_at'=>now()]); }
    private function journal(int $branch, string $number, int $debit, int $credit, string $amount): int { $id=(int)DB::table('journal_entries')->insertGetId(['tenant_id'=>$this->tenant,'branch_id'=>$branch,'entry_number'=>$number,'entry_date'=>'2026-09-01','source_type'=>'manual','description'=>$number,'status'=>'draft','created_by'=>$this->ownerId(),'created_at'=>now(),'updated_at'=>now()]); foreach ([[1,$debit,$amount,'0.00'],[2,$credit,'0.00',$amount]] as [$line,$account,$d,$c]) DB::table('journal_entry_lines')->insert(['tenant_id'=>$this->tenant,'journal_entry_id'=>$id,'financial_account_id'=>$account,'line_number'=>$line,'debit'=>$d,'credit'=>$c,'created_at'=>now(),'updated_at'=>now()]); return $id; }
    private function expenses(): array { $category=(int)DB::table('expense_categories')->where('tenant_id',$this->tenant)->value('id'); if(!$category)$category=(int)DB::table('expense_categories')->insertGetId(['tenant_id'=>$this->tenant,'code'=>'BRANCH-TEST','name'=>'Branch test','financial_account_id'=>$this->account('1010'),'is_active'=>true,'created_at'=>now(),'updated_at'=>now()]); $make=function(int $branch,string $number)use($category):int{return(int)DB::table('expenses')->insertGetId(['tenant_id'=>$this->tenant,'branch_id'=>$branch,'expense_number'=>$number,'expense_category_id'=>$category,'amount'=>'10.00','tax_amount'=>'0.00','total_amount'=>'10.00','expense_date'=>'2026-09-01','description'=>$number,'status'=>'draft','payment_status'=>'unpaid','created_by'=>$this->ownerId(),'created_at'=>now(),'updated_at'=>now()]);}; return[$make($this->branchA,'EXP-A'),$make($this->branchB,'EXP-B')]; }
    private function invoices(): array { $supplier=(int)DB::table('suppliers')->where('tenant_id',$this->tenant)->value('id');if(!$supplier)$supplier=(int)DB::table('suppliers')->insertGetId(['tenant_id'=>$this->tenant,'supplier_number'=>'SUP-BRANCH','name'=>'Branch supplier','is_active'=>true,'created_by'=>$this->ownerId(),'created_at'=>now(),'updated_at'=>now()]);$account=$this->account('1010');$make=function(int $branch,string $ref)use($supplier,$account):int{return(int)DB::table('supplier_invoices')->insertGetId(['tenant_id'=>$this->tenant,'branch_id'=>$branch,'supplier_id'=>$supplier,'internal_reference'=>$ref,'invoice_number'=>$ref,'invoice_date'=>'2026-09-01','due_date'=>'2026-09-30','invoice_type'=>'other','debit_account_id'=>$account,'subtotal'=>'10.00','tax_amount'=>'0.00','total_amount'=>'10.00','status'=>'draft','created_by'=>$this->ownerId(),'created_at'=>now(),'updated_at'=>now()]);};return[$make($this->branchA,'INV-A'),$make($this->branchB,'INV-B')]; }
    private function payments(int $invoiceA,int $invoiceB): array { [$cashA,,, $cashB]=$this->locations();$supplier=(int)DB::table('suppliers')->where('tenant_id',$this->tenant)->value('id');$method=(int)DB::table('payment_methods')->where('tenant_id',$this->tenant)->value('id');$make=function(int $branch,int $location,string $number)use($supplier,$method):int{return(int)DB::table('supplier_payments')->insertGetId(['tenant_id'=>$this->tenant,'branch_id'=>$branch,'supplier_id'=>$supplier,'payment_number'=>$number,'payment_date'=>'2026-09-01','amount'=>'1.00','payment_method_id'=>$method,'financial_location_id'=>$location,'status'=>'posted','created_by'=>$this->ownerId(),'created_at'=>now(),'updated_at'=>now()]);};return[$make($this->branchA,$cashA,'PAY-A'),$make($this->branchB,$cashB,'PAY-B')]; }
    private function reconciliation(int $location,int $branch,string $reference):int{$account=(int)DB::table('financial_locations')->where('id',$location)->value('financial_account_id');return(int)DB::table('financial_reconciliations')->insertGetId(['tenant_id'=>$this->tenant,'branch_id'=>$branch,'financial_account_id'=>$account,'financial_location_id'=>$location,'reference'=>$reference,'type'=>'cash','status'=>'draft','date_from'=>'2026-09-01','date_to'=>'2026-09-01','book_opening_balance'=>'0.00','book_closing_balance'=>'0.00','created_by'=>$this->ownerId(),'created_at'=>now(),'updated_at'=>now()]);}
    private function closing(int $branch,string $date):int{return(int)DB::table('daily_closings')->insertGetId(['tenant_id'=>$this->tenant,'branch_id'=>$branch,'business_date'=>$date,'reference'=>'DC-'.$branch,'status'=>'open','created_by'=>$this->ownerId(),'calculated_at'=>now(),'created_at'=>now(),'updated_at'=>now()]);}
    private function account(string $code):int{return(int)DB::table('financial_accounts')->where('tenant_id',$this->tenant)->where('code',$code)->value('id');}
    private function ownerId():int{return(int)DB::table('users')->where('tenant_id',$this->tenant)->where('role','owner')->value('id');}
    private function managerHeaders(int $branch,string $suffix):array{$id=(int)DB::table('users')->insertGetId(['tenant_id'=>$this->tenant,'name'=>'Manager '.$suffix,'email'=>'branch-'.$suffix.'-'.uniqid().'@test.local','password'=>bcrypt('x'),'role'=>'manager','is_active'=>true,'created_at'=>now(),'updated_at'=>now()]);foreach(FinanceAccess::defaultPermissionsForRole('manager')as$p)DB::table('finance_role_permissions')->updateOrInsert(['tenant_id'=>$this->tenant,'role'=>'manager','permission'=>$p],['created_at'=>now(),'updated_at'=>now()]);DB::table('user_branches')->insert(['tenant_id'=>$this->tenant,'user_id'=>$id,'branch_id'=>$branch,'created_at'=>now(),'updated_at'=>now()]);return $this->headers($id);}
    private function headers(int $user):array{$token='branch-isolation-'.$this->tenant.'-'.$user;DB::table('api_tokens')->updateOrInsert(['tenant_id'=>$this->tenant,'user_id'=>$user,'name'=>'branch-isolation'],['token_hash'=>hash('sha256',$token),'expires_at'=>now()->addDay(),'created_at'=>now(),'updated_at'=>now()]);return['Authorization'=>"Bearer $token",'X-Tenant-Id'=>$this->tenant];}
    private function newBranch(string $name):int{return(int)DB::table('branches')->insertGetId(['tenant_id'=>$this->tenant,'name'=>$name,'is_active'=>true,'created_at'=>now(),'updated_at'=>now()]);}
    private function otherTenantHeaders():array{$tenant=(int)DB::table('tenants')->insertGetId(['name'=>'Other','slug'=>'branch-isolation-other','status'=>'active','created_at'=>now(),'updated_at'=>now()]);DB::table('branches')->insert(['tenant_id'=>$tenant,'name'=>'Other branch','is_active'=>true,'created_at'=>now(),'updated_at'=>now()]);app(FinancialSetupService::class)->ensureForTenant($tenant);$user=(int)DB::table('users')->insertGetId(['tenant_id'=>$tenant,'name'=>'Other owner','email'=>'other-'.uniqid().'@test.local','password'=>bcrypt('x'),'role'=>'owner','is_active'=>true,'created_at'=>now(),'updated_at'=>now()]);$token='other-'.$tenant;DB::table('api_tokens')->insert(['tenant_id'=>$tenant,'user_id'=>$user,'name'=>'other','token_hash'=>hash('sha256',$token),'expires_at'=>now()->addDay(),'created_at'=>now(),'updated_at'=>now()]);return['Authorization'=>"Bearer $token",'X-Tenant-Id'=>$tenant];}
}
