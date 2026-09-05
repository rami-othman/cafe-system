<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryPostingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/**
 * Phase 10 test areas #8-24 (Net Sales, COGS/Gross Profit) and #32-33
 * (Operating Profit reliability).
 */
class FinanceDashboardSalesAndCogsTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_gross_sale_discount_and_net_sales_breakdown(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'sales-basic');
        $branch = $this->branchId($tenant);
        $date = '2030-04-01';

        DB::table('orders')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'order_number' => 'GS-1', 'type' => 'takeaway', 'status' => 'closed', 'payment_status' => 'paid', 'subtotal' => '100.00', 'discount_total' => '10.00', 'tax_total' => '5.00', 'service_total' => '0.00', 'total' => '95.00', 'closed_at' => $date.' 12:00:00', 'created_at' => now(), 'updated_at' => now()]);

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $breakdown = $data['kpis']['netSales']['breakdown'];
        $this->assertSame('105.00', $breakdown['grossSales']); // subtotal + tax + service
        $this->assertSame('10.00', $breakdown['discounts']);
        $this->assertSame('0.00', $breakdown['refunds']);
        $this->assertSame('95.00', $breakdown['netSales']);
    }

    public function test_refund_and_partial_refund_reduce_net_sales_once(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'sales-refund');
        $branch = $this->branchId($tenant);
        $date = '2030-04-02';

        $order = $this->makeOrder($tenant, $branch, '100.00', $date.' 12:00:00');
        $payment = $this->makePayment($tenant, $branch, $order, '100.00', $date.' 12:00:00');
        $this->makeRefund($tenant, $branch, $order, $payment, '20.00', $date.' 13:00:00');
        $this->makeRefund($tenant, $branch, $order, $payment, '5.00', $date.' 14:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('25.00', $data['kpis']['netSales']['breakdown']['refunds']);
        $this->assertSame('75.00', $data['kpis']['netSales']['current']);
    }

    public function test_multiple_payment_legs_never_double_count_order_revenue(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'sales-multi-pay');
        $branch = $this->branchId($tenant);
        $date = '2030-04-03';

        $order = $this->makeOrder($tenant, $branch, '150.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '100.00', $date.' 12:00:00', 'cash');
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 12:00:00', 'cash');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('150.00', $data['kpis']['netSales']['current']);
    }

    public function test_another_period_branch_and_tenant_are_excluded_from_net_sales(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'sales-scope');
        $branch = $this->branchId($tenant);
        $otherBranch = $this->branchId($tenant, 'Mall');
        $date = '2030-04-04';

        $otherPeriodOrder = $this->makeOrder($tenant, $branch, '10.00', '2030-04-05 12:00:00');
        $this->makePayment($tenant, $branch, $otherPeriodOrder, '10.00', '2030-04-05 12:00:00');
        $otherBranchOrder = $this->makeOrder($tenant, $otherBranch, '20.00', $date.' 12:00:00');
        $this->makePayment($tenant, $otherBranch, $otherBranchOrder, '20.00', $date.' 12:00:00');
        $foreignTenant = (int) DB::table('tenants')->insertGetId(['name' => 'Foreign Dash', 'slug' => 'dash-foreign-sales', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $foreignBranch = (int) DB::table('branches')->insertGetId(['tenant_id' => $foreignTenant, 'name' => 'FB', 'currency' => 'USD', 'timezone' => 'UTC', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $foreignOrder = $this->makeOrder($foreignTenant, $foreignBranch, '999.00', $date.' 12:00:00');
        $this->makePayment($foreignTenant, $foreignBranch, $foreignOrder, '999.00', $date.' 12:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('0.00', $data['kpis']['netSales']['current']);
    }

    public function test_cogs_from_authoritative_sale_consumption_and_wac_change_does_not_rewrite_history(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cogs-real');
        $branch = $this->branchId($tenant);
        $date = '2030-04-05';

        // Force the order's cogs_total directly, the same authoritative field SaleConsumptionService writes.
        $orderId = $this->makeOrder($tenant, $branch, '100.00', $date.' 12:00:00');
        DB::table('orders')->where('id', $orderId)->update(['cogs_total' => '40.00', 'gross_profit' => '60.00']);
        $this->makePayment($tenant, $branch, $orderId, '100.00', $date.' 12:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('40.00', $data['kpis']['grossProfit']['cogs']['amount']);
        $this->assertSame('60.00', $data['kpis']['grossProfit']['current']);
        $this->assertTrue($data['kpis']['grossProfit']['reliable']);
        $this->assertSame('complete', $data['kpis']['grossProfit']['cogs']['coverageStatus']);

        // A later WAC/inventory-item cost change must never retroactively change this stored historical cogs_total.
        DB::table('inventory_items')->where('tenant_id', $tenant)->update(['latest_unit_cost' => '999.0000']);
        $again = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('40.00', $again['kpis']['grossProfit']['cogs']['amount']);
    }

    public function test_complete_cogs_coverage_reports_reliable_gross_profit(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cogs-complete');
        $branch = $this->branchId($tenant);
        $date = '2030-04-06';

        for ($i = 0; $i < 3; $i++) {
            $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 1'.$i.':00:00');
            DB::table('orders')->where('id', $order)->update(['cogs_total' => '20.00']);
            $this->makePayment($tenant, $branch, $order, '50.00', $date.' 1'.$i.':00:00');
        }

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('complete', $data['kpis']['grossProfit']['cogs']['coverageStatus']);
        $this->assertSame(3, $data['kpis']['grossProfit']['cogs']['coveredSalesCount']);
        $this->assertSame(0, $data['kpis']['grossProfit']['cogs']['uncoveredSalesCount']);
        $this->assertSame(100.0, (float) $data['kpis']['grossProfit']['cogs']['coveragePercentage']);
    }

    public function test_incomplete_cogs_coverage_is_marked_partial_or_unavailable_and_gross_profit_unreliable(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cogs-partial');
        $branch = $this->branchId($tenant);
        $date = '2030-04-07';

        $covered = $this->makeOrder($tenant, $branch, '50.00', $date.' 10:00:00');
        DB::table('orders')->where('id', $covered)->update(['cogs_total' => '20.00']);
        $this->makePayment($tenant, $branch, $covered, '50.00', $date.' 10:00:00');
        // Left with cogs_total = NULL (never processed) — an uncovered sale.
        $uncovered = $this->makeOrder($tenant, $branch, '30.00', $date.' 11:00:00');
        $this->makePayment($tenant, $branch, $uncovered, '30.00', $date.' 11:00:00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('partial', $data['kpis']['grossProfit']['cogs']['coverageStatus']);
        $this->assertFalse($data['kpis']['grossProfit']['reliable']);
        $this->assertNull($data['kpis']['grossProfit']['marginPercentage']);

        // Now make coverage fully absent (unavailable).
        DB::table('orders')->where('id', $covered)->update(['cogs_total' => null]);
        $unavailable = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('unavailable', $unavailable['kpis']['grossProfit']['cogs']['coverageStatus']);
        $this->assertFalse($unavailable['kpis']['grossProfit']['reliable']);
    }

    public function test_zero_sales_margin_is_safely_null_not_infinite(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cogs-zero');
        $branch = $this->branchId($tenant);
        $date = '2030-04-08';

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('0.00', $data['kpis']['netSales']['current']);
        $this->assertSame('complete', $data['kpis']['grossProfit']['cogs']['coverageStatus']);
        $this->assertNull($data['kpis']['grossProfit']['cogs']['coveragePercentage']);
        $this->assertNull($data['kpis']['grossProfit']['marginPercentage']);
    }

    public function test_generic_inventory_accounting_waste_never_duplicates_into_cogs(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'cogs-waste');
        $branch = $this->branchId($tenant);
        $date = '2030-04-09';

        $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 10:00:00');
        DB::table('orders')->where('id', $order)->update(['cogs_total' => '15.00']);
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 10:00:00');
        // A large waste movement on the same day/branch — must never inflate this order's COGS figure.
        $this->makeStockMovementRaw($tenant, $branch, 'waste', '500.00', $date.' 11:00:00', '1.000');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertSame('15.00', $data['kpis']['grossProfit']['cogs']['amount']);
    }

    public function test_operating_profit_correct_when_data_complete_and_unreliable_when_cogs_incomplete(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'opprofit');
        $branch = $this->branchId($tenant);
        $date = '2030-04-10';

        $order = $this->makeOrder($tenant, $branch, '100.00', $date.' 10:00:00');
        DB::table('orders')->where('id', $order)->update(['cogs_total' => '30.00']);
        $this->makePayment($tenant, $branch, $order, '100.00', $date.' 10:00:00');
        $this->postExpense($tenant, $branch, $date, '20.00');

        $data = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        // grossProfit=70, expenses=20 -> operatingProfit=50
        $this->assertSame('50.00', $data['kpis']['operatingProfit']['current']);
        $this->assertTrue($data['kpis']['operatingProfit']['reliable']);

        $uncovered = $this->makeOrder($tenant, $branch, '10.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $uncovered, '10.00', $date.' 12:00:00');
        $unreliable = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk()->json('data');
        $this->assertFalse($unreliable['kpis']['operatingProfit']['reliable']);
    }
}
