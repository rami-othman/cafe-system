<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

class FinanceDashboardSmokeTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_dashboard_endpoint_returns_a_full_contract_for_a_quiet_tenant(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'dash-smoke');

        $response = $this->getJson('/api/v1/finance/dashboard?date_from=2030-08-01&date_to=2030-08-31', $headers)->assertOk();
        $data = $response->json('data');
        $this->assertArrayHasKey('context', $data);
        $this->assertArrayHasKey('kpis', $data);
        $this->assertArrayHasKey('dataQuality', $data);
        $this->assertArrayHasKey('alerts', $data);
        $this->assertArrayHasKey('recentTransactions', $data);
        $this->assertSame('0.00', $data['kpis']['netSales']['current']);
        $this->assertSame('complete', $data['dataQuality']['cogs']);
    }

    public function test_trends_endpoint_returns_a_contract(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'dash-trends-smoke');

        $response = $this->getJson('/api/v1/finance/dashboard/trends?date_from=2030-08-01&date_to=2030-08-31', $headers)->assertOk();
        $data = $response->json('data');
        $this->assertArrayHasKey('revenueVsExpenses', $data);
        $this->assertArrayHasKey('salesCogsGrossProfit', $data);
        $this->assertSame('day', $data['revenueVsExpenses']['granularity']);
    }

    public function test_branches_endpoint_returns_a_contract(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'dash-branches-smoke');

        $response = $this->getJson('/api/v1/finance/dashboard/branches?date_from=2030-08-01&date_to=2030-08-31', $headers)->assertOk();
        $data = $response->json('data');
        $this->assertArrayHasKey('branches', $data);
        $this->assertArrayHasKey('unallocatedCompanyExpenses', $data);
        $this->assertGreaterThanOrEqual(1, count($data['branches']));
    }

    public function test_dashboard_with_real_sale_expense_and_supplier_data(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'dash-real');
        $branch = $this->branchId($tenant);
        $date = '2030-09-15';

        $order = $this->makeOrder($tenant, $branch, '100.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '100.00', $date.' 12:00:00', 'cash');
        $this->makeExpense($tenant, $branch, '20.00', $date, 'paid', 'CASH-DRAWER');
        $supplier = $this->supplierId($tenant);
        $this->makeSupplierInvoice($tenant, $branch, $supplier, '50.00', $date);

        $response = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)->assertOk();
        $data = $response->json('data');
        $this->assertSame('100.00', $data['kpis']['netSales']['current']);
    }
}
