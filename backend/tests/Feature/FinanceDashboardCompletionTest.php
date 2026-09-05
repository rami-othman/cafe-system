<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryAccountingMapper;
use App\Domain\Inventory\InventoryPostingService;
use App\Services\FinancialSetupService;
use App\Services\SupplierPayableQueryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

class FinanceDashboardCompletionTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_dashboard_reuses_daily_closing_reconciliation_policy_for_required_cash_and_card(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'dashboard-reconciliation');
        $date = now()->toDateString();

        $cashOrder = $this->makeOrder($tenant, $branch, '40.00', $date.' 10:00:00');
        $this->makePayment($tenant, $branch, $cashOrder, '40.00', $date.' 10:00:00');
        $card = $this->makeCardPaymentMethod($tenant, 'DASH-CARD');
        $cardOrder = $this->makeOrder($tenant, $branch, '30.00', $date.' 11:00:00');
        $this->makePayment($tenant, $branch, $cardOrder, '30.00', $date.' 11:00:00', 'card', $card['methodId']);

        $data = $this->dashboard($headers, $date, $branch);
        $this->assertSame(1, $data['reconciliation']['cash']['requiredCount']);
        $this->assertSame(1, $data['reconciliation']['cash']['incompleteRequiredCount']);
        $this->assertSame(1, $data['reconciliation']['card']['incompleteRequiredCount']);
        $this->assertContains('RECONCILIATION_INCOMPLETE', $this->alertCodes($data));

        $this->completeCashReconciliation($tenant, $branch, $date);
        $resolved = $this->dashboard($headers, $date, $branch);
        $this->assertSame(0, $resolved['reconciliation']['cash']['incompleteRequiredCount']);
        $this->assertSame(1, $resolved['reconciliation']['card']['incompleteRequiredCount']);
    }

    public function test_daily_closing_blocked_deduplicates_its_cash_reconciliation_alert(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'dashboard-dedup');
        $date = now()->subDay()->toDateString();
        $order = $this->makeOrder($tenant, $branch, '40.00', $date.' 10:00:00');
        $this->makePayment($tenant, $branch, $order, '40.00', $date.' 10:00:00');
        DB::table('daily_closings')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'business_date' => $date, 'reference' => 'DASH-CLOSE-'.uniqid(), 'status' => 'open', 'actual_cash' => '40.00', 'created_at' => now(), 'updated_at' => now()]);

        $data = $this->dashboard($headers, $date, $branch);
        $this->assertContains('DAILY_CLOSING_BLOCKED', $this->alertCodes($data));
        $this->assertSame(0, collect($data['alerts'])->where('code', 'RECONCILIATION_INCOMPLETE')->count());
    }

    public function test_dashboard_alerts_cover_existing_operational_domains_and_finance_setup(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'dashboard-alerts');
        $date = now()->toDateString();

        $this->makeExpense($tenant, $branch, '12.00', $date, 'pending_approval');
        $supplier = $this->supplierId($tenant);
        $invoice = $this->makeSupplierInvoice($tenant, $branch, $supplier, '25.00', now()->subDays(10)->toDateString());
        DB::table('supplier_invoices')->where('id', $invoice)->update(['due_date' => now()->subDay()->toDateString()]);
        $this->makeStockMovementRaw($tenant, $branch, 'waste', '8.00', $date.' 10:00:00', '1.000');
        $this->makeJournal($tenant, $branch, $date, 'draft', $date.' 12:00:00');
        DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->update(['is_active' => false]);

        $data = $this->dashboard($headers, $date, $branch);
        $codes = $this->alertCodes($data);
        $this->assertContains('PENDING_EXPENSE_APPROVAL', $codes);
        $this->assertContains('SUPPLIER_INVOICE_OVERDUE', $codes);
        $this->assertContains('UNPOSTED_INVENTORY_FINANCIAL_EVENT', $codes);
        $this->assertContains('DRAFT_JOURNAL_ENTRIES', $codes);
        $this->assertContains('FINANCE_CONFIGURATION_REQUIRED', $codes);
    }

    public function test_supplier_payables_snapshot_uses_cutoff_events_not_current_invoice_status(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $supplier = $this->supplierId($tenant);
        $cutoff = '2030-10-10';

        $afterCutoff = $this->makeSupplierInvoice($tenant, $branch, $supplier, '100.00', '2030-10-01');
        $afterPayment = $this->makeSupplierPayment($tenant, $branch, $supplier, '100.00', '2030-10-15');
        DB::table('payment_allocations')->insert(['tenant_id' => $tenant, 'supplier_payment_id' => $afterPayment, 'supplier_invoice_id' => $afterCutoff, 'amount' => '100.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('supplier_invoices')->where('id', $afterCutoff)->update(['status' => 'paid']);

        $partial = $this->makeSupplierInvoice($tenant, $branch, $supplier, '80.00', '2030-10-01');
        $partialPayment = $this->makeSupplierPayment($tenant, $branch, $supplier, '30.00', '2030-10-05');
        DB::table('payment_allocations')->insert(['tenant_id' => $tenant, 'supplier_payment_id' => $partialPayment, 'supplier_invoice_id' => $partial, 'amount' => '30.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('supplier_invoices')->where('id', $partial)->update(['status' => 'partially_paid']);

        $paid = $this->makeSupplierInvoice($tenant, $branch, $supplier, '50.00', '2030-10-01');
        $paidPayment = $this->makeSupplierPayment($tenant, $branch, $supplier, '50.00', '2030-10-05');
        DB::table('payment_allocations')->insert(['tenant_id' => $tenant, 'supplier_payment_id' => $paidPayment, 'supplier_invoice_id' => $paid, 'amount' => '50.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('supplier_invoices')->where('id', $paid)->update(['status' => 'paid']);

        $this->makeSupplierInvoice($tenant, $branch, $supplier, '999.00', '2030-10-11');
        $snapshot = app(SupplierPayableQueryService::class)->snapshotAsOf($tenant, $cutoff);
        $this->assertSame('150.00', $snapshot['outstanding']);
        $this->assertSame(2, $snapshot['openInvoiceCount']);
    }

    public function test_supplier_payables_as_of_respects_later_reversals_and_invoice_cancellation_events(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $supplier = $this->supplierId($tenant);
        $payable = app(SupplierPayableQueryService::class);

        $invoice = $this->makeSupplierInvoice($tenant, $branch, $supplier, '70.00', '2030-11-01');
        $payment = $this->makeSupplierPayment($tenant, $branch, $supplier, '70.00', '2030-11-02');
        DB::table('supplier_payment_allocation_history')->insert(['tenant_id' => $tenant, 'supplier_payment_id' => $payment, 'supplier_invoice_id' => $invoice, 'amount' => '70.00', 'payment_date' => '2030-11-02', 'reversed_at' => '2030-11-20 10:00:00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('supplier_payments')->where('id', $payment)->update(['status' => 'reversed', 'reversed_at' => '2030-11-20 10:00:00']);

        $original = $this->makeJournal($tenant, $branch, '2030-11-01', 'posted', '2030-11-01 10:00:00');
        $reversal = $this->makeJournal($tenant, $branch, '2030-11-15', 'posted', '2030-11-15 10:00:00');
        $cancelled = $this->makeSupplierInvoice($tenant, $branch, $supplier, '40.00', '2030-11-01');
        DB::table('supplier_invoices')->where('id', $cancelled)->update(['status' => 'cancelled', 'journal_entry_id' => $original, 'reversal_journal_entry_id' => $reversal]);

        $beforeReversal = $payable->snapshotAsOf($tenant, '2030-11-10');
        $this->assertSame('40.00', $beforeReversal['outstanding']);
        $afterReversal = $payable->snapshotAsOf($tenant, '2030-11-20');
        $this->assertSame('70.00', $afterReversal['outstanding']);
    }

    public function test_recent_dashboard_activity_uses_unified_financial_transactions_and_scope(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $otherBranch = $this->branchId($tenant, 'Mall');
        $headers = $this->headers($tenant, 'owner', 'dashboard-recent');
        $date = '2030-10-20';
        $visible = $this->makeJournal($tenant, $branch, $date, 'posted', $date.' 12:00:00');
        $hidden = $this->makeJournal($tenant, $otherBranch, $date, 'posted', $date.' 12:00:00');
        foreach ([$visible, $hidden] as $id) {
            DB::table('journal_entry_lines')->insert([
                ['tenant_id' => $tenant, 'journal_entry_id' => $id, 'financial_account_id' => $this->accountId($tenant, '1010'), 'line_number' => 1, 'debit' => '10.00', 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now()],
                ['tenant_id' => $tenant, 'journal_entry_id' => $id, 'financial_account_id' => $this->accountId($tenant, '3000'), 'line_number' => 2, 'debit' => '0.00', 'credit' => '10.00', 'created_at' => now(), 'updated_at' => now()],
            ]);
        }

        $data = $this->dashboard($headers, $date, $branch);
        $references = collect($data['recentTransactions'])->pluck('reference')->all();
        $this->assertContains(DB::table('journal_entries')->where('id', $visible)->value('entry_number'), $references);
        $this->assertNotContains(DB::table('journal_entries')->where('id', $hidden)->value('entry_number'), $references);
    }

    public function test_dashboard_alerts_on_late_financial_activity_after_a_real_daily_close(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'dashboard-late-close');
        $date = '2030-12-01';

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => '0.00'], $headers)->assertOk();
        $closed = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", [], $headers)->assertOk()->json('data');
        $lateJournal = $this->makeJournal($tenant, $branch, $date, 'posted', now()->parse($closed['closedAt'])->addHour()->toDateTimeString());
        DB::table('journal_entry_lines')->insert([
            ['tenant_id' => $tenant, 'journal_entry_id' => $lateJournal, 'financial_account_id' => $this->accountId($tenant, '1010'), 'line_number' => 1, 'debit' => '12.00', 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now()],
            ['tenant_id' => $tenant, 'journal_entry_id' => $lateJournal, 'financial_account_id' => $this->accountId($tenant, '3000'), 'line_number' => 2, 'debit' => '0.00', 'credit' => '12.00', 'created_at' => now(), 'updated_at' => now()],
        ]);

        $data = $this->dashboard($headers, $date, $branch);
        $alert = collect($data['alerts'])->firstWhere('code', 'LATE_FINANCIAL_ACTIVITY_AFTER_CLOSE');
        $this->assertNotNull($alert);
        $this->assertSame($lateJournal, $alert['sourceId']);
        $this->assertSame('critical', $alert['severity']);
        $this->assertSame('12.00', $alert['amount']);
        $this->assertSame($date, $alert['metadata']['businessDate']);
    }

    public function test_dashboard_alerts_are_isolated_between_tenants(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'dashboard-local-alerts');
        $date = now()->toDateString();

        $foreignTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Foreign Dashboard Alerts', 'slug' => 'foreign-dashboard-alerts', 'status' => 'active', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $foreignBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $foreignTenant, 'name' => 'Foreign Branch', 'currency' => 'USD', 'timezone' => 'UTC', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $foreignHeaders = $this->headers($foreignTenant, 'owner', 'dashboard-foreign-alerts');
        $foreignActor = (int) DB::table('users')->where('tenant_id', $foreignTenant)->where('email', "dashboard-foreign-alerts-owner-$foreignTenant@test.local")->value('id');
        app(FinancialSetupService::class)->ensureForTenant($foreignTenant, $foreignBranch, $foreignActor);
        $this->makeExpense($foreignTenant, $foreignBranch, '66.00', $date, 'pending_approval');

        $local = $this->dashboard($headers, $date, $branch);
        $foreign = $this->dashboard($foreignHeaders, $date, $foreignBranch);
        $foreignAlert = collect($foreign['alerts'])->firstWhere('code', 'PENDING_EXPENSE_APPROVAL');

        $this->assertNotNull($foreignAlert);
        $this->assertSame('66.00', $foreignAlert['amount']);
        $this->assertSame($foreignBranch, $foreignAlert['branch']['id']);
        $this->assertFalse(collect($local['alerts'])->contains(fn (array $alert): bool => $alert['code'] === 'PENDING_EXPENSE_APPROVAL' && $alert['amount'] === '66.00'));
        $this->assertTrue(collect($local['alerts'])->every(fn (array $alert): bool => $alert['branch'] === null || $alert['branch']['id'] !== $foreignBranch));
    }

    public function test_dashboard_does_not_alert_for_a_not_applicable_internal_warehouse_transfer(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $sourceBranch = $this->branchId($tenant);
        $destinationBranch = $this->branchId($tenant, 'Mall');
        $headers = $this->headers($tenant, 'owner', 'dashboard-transfer');
        $actor = (int) DB::table('users')->where('tenant_id', $tenant)->where('email', "dashboard-transfer-owner-$tenant@test.local")->value('id');
        $sourceWarehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-$sourceBranch-MAIN")->value('id');
        $destinationWarehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-$destinationBranch-MAIN")->value('id');
        $item = $this->inventoryItemId($tenant);
        foreach ([$sourceWarehouse, $destinationWarehouse] as $warehouse) {
            DB::table('inventory_item_warehouses')->insertOrIgnore(['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'created_at' => now(), 'updated_at' => now()]);
        }
        app(InventoryPostingService::class)->post(Request::create('/inventory-test', 'POST'), $tenant, [
            'warehouseId' => $sourceWarehouse, 'itemId' => $item, 'type' => 'stock_in', 'quantity' => '3.000', 'unit' => 'unit', 'unitCost' => '5.0000', 'idempotencyKey' => 'dashboard-transfer-stock',
        ], $actor);

        $transfer = (int) $this->postJson('/api/v1/inventory/transfers', [
            'sourceWarehouseId' => $sourceWarehouse, 'destinationWarehouseId' => $destinationWarehouse, 'idempotencyKey' => 'dashboard-transfer-create',
            'lines' => [['itemId' => $item, 'requestedQuantity' => '2.000', 'unit' => 'unit']],
        ], $headers)->assertCreated()->json('data.id');
        foreach (['submit', 'approve', 'dispatch'] as $action) {
            $this->postJson("/api/v1/inventory/transfers/$transfer/$action", ['idempotencyKey' => "dashboard-transfer-$action"], $headers)->assertOk();
        }
        $this->postJson("/api/v1/inventory/transfers/$transfer/receive", [
            'idempotencyKey' => 'dashboard-transfer-receive', 'lines' => [['itemId' => $item, 'receivedQuantity' => '2.000', 'unit' => 'unit']],
        ], $headers)->assertOk()->assertJsonPath('data.status', 'received');

        $transferIn = DB::table('stock_movements')->where('tenant_id', $tenant)->where('type', 'transfer_in')->where('reference_type', 'warehouse_transfer_receipt')->first();
        $this->assertNotNull($transferIn);
        $this->assertSame('NOT_APPLICABLE', app(InventoryAccountingMapper::class)->impactForMovement($tenant, $transferIn)['status']);
        $data = $this->dashboard($headers, now()->toDateString(), $destinationBranch);
        $this->assertNotContains('UNPOSTED_INVENTORY_FINANCIAL_EVENT', $this->alertCodes($data));
    }

    private function dashboard(array $headers, string $date, int $branch): array
    {
        return $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
    }

    private function alertCodes(array $data): array
    {
        return collect($data['alerts'])->pluck('code')->all();
    }
}
