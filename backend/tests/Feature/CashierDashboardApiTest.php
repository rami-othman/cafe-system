<?php

namespace Tests\Feature;

use App\Services\DefaultTenantRoleService;
use App\Services\PosInventoryWarehouseResolver;
use App\Support\FinanceAccess;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Covers the Cashier operational surface end to end: what it reports, what it
 * scopes to, and — just as importantly — what it must never disclose.
 *
 * The negative assertions are the point of several of these tests. A Cashier
 * must not be able to reach profit, cost, valuation, ledger or company-wide
 * finance data, and must not see another branch's or tenant's numbers, so each
 * of those is asserted against the response body rather than only against a
 * status code.
 */
final class CashierDashboardApiTest extends TestCase
{
    use RefreshDatabase;

    private const DASHBOARD = '/api/v1/cashier/dashboard';

    private const INVENTORY = '/api/v1/cashier/inventory';

    private int $tenant;

    private int $branchA;

    private int $branchB;

    private int $cashierA;

    private int $cashierB;

    private array $cashierAHeaders;

    private array $cashierBHeaders;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
        $this->tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branches = DB::table('branches')->where('tenant_id', $this->tenant)->whereNull('deleted_at')->orderBy('id')->pluck('id')->map(fn ($id) => (int) $id)->all();
        $this->branchA = $branches[0];
        $this->branchB = $branches[1] ?? $this->newBranch('Second Branch');
        $this->cashierA = $this->employee($this->branchA, 'a');
        $this->cashierB = $this->employee($this->branchB, 'b');
        $this->cashierAHeaders = $this->headers($this->cashierA);
        $this->cashierBHeaders = $this->headers($this->cashierB);
    }

    public function test_the_dashboard_requires_authentication(): void
    {
        $this->getJson(self::DASHBOARD, ['Authorization' => 'Bearer not-a-real-token'])->assertUnauthorized();
        $this->getJson(self::INVENTORY, ['Authorization' => 'Bearer not-a-real-token'])->assertUnauthorized();
    }

    public function test_a_cashier_reads_their_own_operational_dashboard(): void
    {
        $shift = $this->openShift($this->cashierA, $this->branchA, '50000.00');

        $response = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk();

        $response->assertJsonPath('data.scope.kind', 'current_shift');
        $response->assertJsonPath('data.scope.branchId', $this->branchA);
        $response->assertJsonPath('data.scope.cashierId', $this->cashierA);
        $response->assertJsonPath('data.shift.id', $shift);
        $response->assertJsonPath('data.shift.status', 'open');
        $this->assertIsInt($response->json('data.shift.durationSeconds'));
        $response->assertJsonPath('data.cashDrawer.available', true);
        $response->assertJsonPath('data.cashDrawer.openingCash', '50000.00');
    }

    public function test_expected_cash_uses_the_current_shift_and_excludes_card_payments(): void
    {
        $shift = $this->openShift($this->cashierA, $this->branchA, '100.00');
        $this->cashPayment($shift, '40.00');
        $this->cardPayment($shift, '500.00');

        $response = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk();

        // Opening 100 + cash 40. The 500 card payment is not drawer cash and
        // must not move the expected figure.
        $response->assertJsonPath('data.cashDrawer.cashSales', '40.00');
        $response->assertJsonPath('data.cashDrawer.expectedCash', '140.00');
        $response->assertJsonPath('data.cashDrawer.cashSaleCount', 1);
        // Card money is still reported as sales, just not as drawer cash.
        $this->assertSame(
            '500.00',
            collect($response->json('data.sales.byMethod'))->firstWhere('method', 'card')['amount'] ?? null,
        );
    }

    public function test_a_cash_refund_reduces_expected_drawer_cash(): void
    {
        $shift = $this->openShift($this->cashierA, $this->branchA, '100.00');
        $payment = $this->cashPayment($shift, '60.00');
        $this->cashRefund($shift, $payment, '25.00');

        $response = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk();

        $response->assertJsonPath('data.cashDrawer.cashRefunds', '25.00');
        $response->assertJsonPath('data.cashDrawer.expectedCash', '135.00');
        $response->assertJsonPath('data.cashDrawer.cashRefundCount', 1);
    }

    /**
     * ShiftCashSummaryService is the single authority on drawer cash, and it
     * deliberately excludes vouchers. The dashboard reports voucher totals
     * beside the expected figure rather than folding them in, so this asserts
     * the two stay separate instead of silently disagreeing.
     */
    public function test_cash_vouchers_are_reported_beside_expected_cash_not_inside_it(): void
    {
        $shift = $this->openShift($this->cashierA, $this->branchA, '100.00');
        // FinanceAccess keys permissions by the canonical legacy role code,
        // which is "cashier" for the employee tenant role.
        $this->grantFinance(DefaultTenantRoleService::EMPLOYEE, ['finance.vouchers.view']);
        $this->voucher('receipt', '30.00');
        $this->voucher('payment', '10.00');

        $response = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk();

        $response->assertJsonPath('data.finance.receiptVouchers.count', 1);
        $response->assertJsonPath('data.finance.receiptVouchers.cashTotal', '30.00');
        $response->assertJsonPath('data.finance.paymentVouchers.count', 1);
        $response->assertJsonPath('data.finance.paymentVouchers.cashTotal', '10.00');
        $response->assertJsonPath('data.cashDrawer.expectedCash', '100.00');
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
    }

    public function test_finance_blocks_stay_null_without_the_matching_permission(): void
    {
        $this->openShift($this->cashierA, $this->branchA, '0.00');
        $this->voucher('receipt', '30.00');

        $response = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk();

        $response->assertJsonPath('data.finance.capabilities.vouchers', false);
        $response->assertJsonPath('data.finance.receiptVouchers', null);
        $response->assertJsonPath('data.finance.paymentVouchers', null);
        $response->assertJsonPath('data.finance.purchaseDocumentCount', null);
        $response->assertJsonPath('data.finance.salesInvoiceCount', null);
    }

    public function test_no_open_shift_returns_a_stated_branch_only_state(): void
    {
        $response = $this->getJson(self::DASHBOARD.'?branchId='.$this->branchA, $this->cashierAHeaders)->assertOk();

        $response->assertJsonPath('data.scope.kind', 'branch_only');
        $response->assertJsonPath('data.shift', null);
        $response->assertJsonPath('data.cashDrawer.available', false);
        $response->assertJsonPath('data.cashDrawer.expectedCash', null);
        $response->assertJsonPath('data.sales.available', false);
        $response->assertJsonPath('data.sales.netSales', null);
        $this->assertContains('NO_OPEN_SHIFT', collect($response->json('data.alerts'))->pluck('code')->all());
        // Branch inventory is still meaningful without a shift.
        $response->assertJsonPath('data.inventory.configured', true);
    }

    public function test_another_cashiers_open_shift_is_never_adopted(): void
    {
        $this->openShift($this->cashierB, $this->branchB, '999.00');

        $response = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk();

        $response->assertJsonPath('data.shift', null);
        $response->assertJsonPath('data.cashDrawer.openingCash', null);
    }

    public function test_branch_scope_is_enforced_for_a_named_branch(): void
    {
        $this->openShift($this->cashierB, $this->branchB, '999.00');

        $this->getJson(self::DASHBOARD.'?branchId='.$this->branchB, $this->cashierAHeaders)->assertForbidden();
        $this->getJson(self::INVENTORY.'?branchId='.$this->branchB, $this->cashierAHeaders)->assertForbidden();
    }

    public function test_tenant_scope_is_enforced_and_a_foreign_branch_reads_as_missing(): void
    {
        $foreign = $this->otherTenantBranch();

        $this->getJson(self::DASHBOARD.'?branchId='.$foreign, $this->cashierAHeaders)->assertNotFound();
        $this->getJson(self::INVENTORY.'?branchId='.$foreign, $this->cashierAHeaders)->assertNotFound();
    }

    public function test_one_branchs_sales_never_appear_on_another_branchs_dashboard(): void
    {
        $shiftA = $this->openShift($this->cashierA, $this->branchA, '0.00');
        $shiftB = $this->openShift($this->cashierB, $this->branchB, '0.00');
        $this->cashPayment($shiftA, '11.00', $this->branchA);
        $this->cashPayment($shiftB, '77.00', $this->branchB);

        $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk()
            ->assertJsonPath('data.cashDrawer.cashSales', '11.00');
        $this->getJson(self::DASHBOARD, $this->cashierBHeaders)->assertOk()
            ->assertJsonPath('data.cashDrawer.cashSales', '77.00');
    }

    public function test_the_effective_pos_warehouse_is_the_one_a_sale_consumes_from(): void
    {
        $this->openShift($this->cashierA, $this->branchA, '0.00');
        $resolver = app(PosInventoryWarehouseResolver::class);
        $warehouse = $resolver->forBranch($this->tenant, $this->branchA);

        // With no explicit `pos_inventory_warehouse_id` configured, the Bar is
        // the branch's operational POS warehouse (the same rule a sale's
        // consumption uses) — never the branch-main store, which exists for
        // purchasing/replenishment, not for the till.
        $this->assertSame('bar', $warehouse->type, 'This branch is seeded with a Bar, so it must be preferred over branch-main.');

        $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk()
            ->assertJsonPath('data.inventory.warehouseId', (int) $warehouse->id);
    }

    public function test_a_branch_without_a_main_store_reports_a_configuration_alert(): void
    {
        $branch = $this->newBranch('Unprovisioned');
        DB::table('user_branches')->insert(['tenant_id' => $this->tenant, 'user_id' => $this->cashierA, 'branch_id' => $branch, 'created_at' => now(), 'updated_at' => now()]);

        $response = $this->getJson(self::DASHBOARD.'?branchId='.$branch, $this->cashierAHeaders)->assertOk();

        $response->assertJsonPath('data.inventory.configured', false);
        $response->assertJsonPath('data.inventory.warehouseId', null);
        $this->assertContains('POS_WAREHOUSE_NOT_CONFIGURED', collect($response->json('data.alerts'))->pluck('code')->all());
    }

    public function test_negative_stock_is_reported_and_does_not_block_the_dashboard(): void
    {
        $this->openShift($this->cashierA, $this->branchA, '0.00');
        $warehouse = app(PosInventoryWarehouseResolver::class)->forBranch($this->tenant, $this->branchA)->id;
        $item = $this->stockedItem($warehouse, '-5.000');

        $response = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk();
        $this->assertGreaterThanOrEqual(1, $response->json('data.inventory.negativeStockCount'));
        $this->assertContains('NEGATIVE_STOCK_ITEMS', collect($response->json('data.alerts'))->pluck('code')->all());

        $rows = $this->getJson(self::INVENTORY.'?state=negative', $this->cashierAHeaders)->assertOk()->json('data.items');
        $this->assertContains($item, collect($rows)->pluck('itemId')->all());
        $this->assertSame('negative', collect($rows)->firstWhere('itemId', $item)['state']);
    }

    public function test_the_stock_list_exposes_quantities_and_never_valuation(): void
    {
        $this->openShift($this->cashierA, $this->branchA, '0.00');
        $warehouse = app(PosInventoryWarehouseResolver::class)->forBranch($this->tenant, $this->branchA)->id;
        $item = $this->stockedItem($warehouse, '7.000');
        $sku = DB::table('inventory_items')->where('id', $item)->value('sku');

        // The seeded tenant's catalog has far more than one page of items, and
        // this new item sorts after every zero/low-stock one under the state
        // ordering (see CashierInventoryQueryService::list). Searching by its
        // own unique SKU finds it deterministically regardless of catalog size.
        $response = $this->getJson(self::INVENTORY.'?perPage=100&search='.$sku, $this->cashierAHeaders)->assertOk();

        $row = collect($response->json('data.items'))->firstWhere('itemId', $item);
        $this->assertNotNull($row, 'The seeded item must appear in the POS warehouse list.');
        $this->assertSame('7.000', $row['quantity']);
        $this->assertSame('kg', $row['unit']);
        $this->assertSame('normal', $row['state']);
        foreach (['averageUnitCost', 'average_unit_cost', 'totalValue', 'unitCost', 'cost', 'value'] as $forbidden) {
            $this->assertArrayNotHasKey($forbidden, $row, "The Cashier stock list must not expose {$forbidden}.");
        }
    }

    public function test_no_profit_cost_or_ledger_value_is_present_anywhere_in_the_payload(): void
    {
        $shift = $this->openShift($this->cashierA, $this->branchA, '100.00');
        $this->cashPayment($shift, '40.00');
        $this->grantFinance(DefaultTenantRoleService::EMPLOYEE, FinanceAccess::CATALOG);

        $body = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk()->getContent();

        foreach ([
            'profit', 'grossProfit', 'netProfit', 'margin', 'cogs', 'costOfGoods',
            'averageUnitCost', 'unitCost', 'totalCost', 'valuation', 'inventoryValue',
            'accountBalance', 'ledger', 'trialBalance', 'balanceSheet', 'payable',
            'receivable', 'ebitda',
        ] as $forbidden) {
            $this->assertStringNotContainsStringIgnoringCase(
                $forbidden,
                $body,
                "The Cashier dashboard payload must never contain \"{$forbidden}\".",
            );
        }
    }

    public function test_a_cashier_cannot_reach_management_finance_or_inventory_endpoints(): void
    {
        // Frontend hiding is not the boundary; these must be refused server side.
        $this->getJson('/api/v1/finance/dashboard', $this->cashierAHeaders)->assertForbidden();
        $this->getJson('/api/v1/finance/reports/profit-loss?dateFrom=2026-09-01&dateTo=2026-09-30', $this->cashierAHeaders)->assertForbidden();
        $this->getJson('/api/v1/finance/reports/balance-sheet?asOf=2026-09-30', $this->cashierAHeaders)->assertForbidden();
        $this->getJson('/api/v1/finance/reports/sales-profitability?dateFrom=2026-09-01&dateTo=2026-09-30', $this->cashierAHeaders)->assertForbidden();
        $this->getJson('/api/v1/finance/accounts', $this->cashierAHeaders)->assertForbidden();
        $this->getJson('/api/v1/finance/journal-entries', $this->cashierAHeaders)->assertForbidden();
        $this->getJson('/api/v1/reports/overview', $this->cashierAHeaders)->assertForbidden();
        $this->postJson('/api/v1/warehouses', ['name' => 'Rogue', 'type' => 'bar', 'branchId' => $this->branchA], $this->cashierAHeaders)->assertForbidden();
        $this->postJson('/api/v1/inventory/movements', [], $this->cashierAHeaders)->assertForbidden();
    }

    public function test_owner_behaviour_is_unchanged_and_the_owner_may_also_read_the_surface(): void
    {
        $owner = $this->headers((int) DB::table('users')->where('tenant_id', $this->tenant)->where('role', 'owner')->value('id'));

        $this->getJson('/api/v1/finance/dashboard', $owner)->assertOk();
        $this->getJson('/api/v1/inventory/dashboard', $owner)->assertOk();
        // The Cashier surface is scope-limited, not role-limited: an Owner sees
        // their own shift state through it, and nothing wider.
        $this->getJson(self::DASHBOARD.'?branchId='.$this->branchA, $owner)->assertOk()
            ->assertJsonPath('data.shift', null);
    }

    public function test_shift_order_counts_report_what_blocks_a_close(): void
    {
        $shift = $this->openShift($this->cashierA, $this->branchA, '0.00');
        $this->order($shift, 'draft', 'unpaid', '10.00');
        $this->order($shift, 'held', 'unpaid', '20.00');
        $this->order($shift, 'paid', 'paid', '30.00');

        $response = $this->getJson(self::DASHBOARD, $this->cashierAHeaders)->assertOk();

        $response->assertJsonPath('data.orders.active', 1);
        $response->assertJsonPath('data.orders.held', 1);
        $response->assertJsonPath('data.orders.completed', 1);
        $response->assertJsonPath('data.orders.blockingCount', 2);
        $response->assertJsonPath('data.sales.orderCount', 1);
        $response->assertJsonPath('data.sales.grossSales', '30.00');
        $this->assertContains('ORDERS_BLOCKING_SHIFT_CLOSE', collect($response->json('data.alerts'))->pluck('code')->all());
    }

    // --- fixtures -------------------------------------------------------

    private function employee(int $branch, string $suffix): int
    {
        $role = DB::table('tenant_roles')->where('tenant_id', $this->tenant)->where('code', 'employee')->value('id');
        $id = (int) DB::table('users')->insertGetId([
            'tenant_id' => $this->tenant, 'name' => 'Cashier '.$suffix,
            'email' => 'cashier-'.$suffix.'-'.uniqid().'@test.local', 'password' => bcrypt('x'),
            'role' => 'cashier', 'tenant_role_id' => $role, 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('user_branches')->insert(['tenant_id' => $this->tenant, 'user_id' => $id, 'branch_id' => $branch, 'created_at' => now(), 'updated_at' => now()]);

        return $id;
    }

    private function headers(int $user): array
    {
        $token = 'cashier-dashboard-'.$this->tenant.'-'.$user;
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $this->tenant, 'user_id' => $user, 'name' => 'cashier-dashboard'],
            ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $this->tenant];
    }

    private function newBranch(string $name): int
    {
        return (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => $name, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function otherTenantBranch(): int
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Other', 'slug' => 'cashier-other-'.uniqid(), 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);

        return (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Other branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function openShift(int $user, int $branch, string $openingCash): int
    {
        return (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $branch, 'user_id' => $user,
            'opening_cash' => $openingCash, 'status' => 'open',
            'opened_at' => now()->subHours(2), 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function order(int $shift, string $status, string $paymentStatus, string $total, ?int $branch = null): int
    {
        return (int) DB::table('orders')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $branch ?? $this->branchA, 'shift_id' => $shift,
            'order_number' => 'CD-'.uniqid(), 'type' => 'dine_in', 'status' => $status,
            'payment_status' => $paymentStatus, 'subtotal' => $total, 'total' => $total,
            'opened_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function cashPayment(int $shift, string $amount, ?int $branch = null): int
    {
        return $this->payment($shift, $amount, 'cash', $branch);
    }

    private function cardPayment(int $shift, string $amount, ?int $branch = null): int
    {
        return $this->payment($shift, $amount, 'card', $branch);
    }

    private function payment(int $shift, string $amount, string $method, ?int $branch): int
    {
        $branch ??= $this->branchA;
        $order = $this->order($shift, 'paid', 'paid', $amount, $branch);

        return (int) DB::table('payments')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $branch, 'order_id' => $order,
            'shift_id' => $shift, 'method' => $method, 'amount' => $amount,
            'currency' => 'SYP', 'status' => 'completed', 'paid_at' => now(),
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function cashRefund(int $shift, int $payment, string $amount): int
    {
        $orderId = (int) DB::table('payments')->where('id', $payment)->value('order_id');

        return (int) DB::table('payment_refunds')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $this->branchA, 'order_id' => $orderId,
            'payment_id' => $payment, 'shift_id' => $shift, 'refund_number' => 'RF-'.uniqid(),
            'type' => 'partial', 'amount' => $amount, 'status' => 'completed',
            'refunded_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function voucher(string $type, string $amount): int
    {
        $location = (int) DB::table('financial_locations')->where('tenant_id', $this->tenant)->where('kind', 'cash')->orderBy('id')->value('id');

        return (int) DB::table('finance_documents')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $this->branchA,
            'document_number' => strtoupper($type).'-'.uniqid(), 'document_type' => $type,
            'status' => 'posted', 'document_date' => now()->toDateString(),
            'financial_location_id' => $location, 'currency_code' => 'SYP',
            'exchange_rate' => 1, 'amount' => $amount, 'created_by' => $this->cashierA,
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    /** @param list<string> $permissions */
    private function grantFinance(string $roleCode, array $permissions): void
    {
        $role = app(DefaultTenantRoleService::class)->canonicalLegacyRole($roleCode);
        foreach ($permissions as $permission) {
            DB::table('finance_role_permissions')->updateOrInsert(
                ['tenant_id' => $this->tenant, 'role' => $role, 'permission' => $permission],
                ['created_at' => now(), 'updated_at' => now()],
            );
        }
    }

    private function stockedItem(int $warehouse, string $quantity): int
    {
        $item = (int) DB::table('inventory_items')->insertGetId([
            'tenant_id' => $this->tenant, 'sku' => 'CD-'.strtoupper(uniqid()),
            'name' => 'Cashier test item', 'name_ar' => 'مادة اختبار', 'name_en' => 'Cashier test item',
            'unit' => 'kg', 'item_type' => 'other', 'minimum_stock' => '2.000', 'reorder_level' => '4.000',
            'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('stock_balances')->insert([
            'tenant_id' => $this->tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item,
            'quantity_on_hand' => $quantity, 'reserved_quantity' => '0.000',
            'average_unit_cost' => '3.0000', 'last_movement_at' => now(),
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return $item;
    }
}
