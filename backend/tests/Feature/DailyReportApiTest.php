<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DailyReportApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_daily_report_uses_seeded_pos_data(): void
    {
        $this->seed();

        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')
            ->where('tenant_id', $tenantId)
            ->where('name', 'Downtown')
            ->value('id');

        $response = $this->getJson(
            '/api/v1/reports/daily?branchId='.$branchId.'&date='.now()->toDateString(),
            ['X-Tenant-Id' => $tenantId],
        );

        $response->assertOk()
            ->assertJsonPath('data.hasData', true)
            ->assertJsonPath('data.branch.id', $branchId)
            ->assertJsonPath('data.kpis.totalOrders', 1)
            ->assertJsonPath('data.refunds.0.reason', 'Customer Request')
            ->assertJsonPath('data.discounts.0.name', 'Student Discount')
            ->assertJsonPath('data.transactions.0.payment', 'card');

        $this->assertCount(24, $response->json('data.hourlySales'));
        $this->assertCount(1, array_filter(
            $response->json('data.hourlySales'),
            fn (array $point) => $point['isPeak'],
        ));
    }
}
