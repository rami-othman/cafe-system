<?php

namespace Tests\Feature;

use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DailyReportApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_daily_report_uses_seeded_pos_data(): void
    {
        // PosDemoSeeder intentionally creates activity one to three hours ago.
        // A fixed midday clock keeps every seeded event on the report date.
        Carbon::setTestNow('2030-06-15 12:00:00');
        $this->seed();

        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')
            ->where('tenant_id', $tenantId)
            ->where('name', 'Downtown')
            ->value('id');

        $response = $this->getJson(
            '/api/v1/reports/daily?branchId='.$branchId.'&date='.now()->toDateString(),
            $this->headers($tenantId),
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
        Carbon::setTestNow();
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = 'daily-report-test-token';
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'daily-report-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
