<?php

namespace Tests\Feature;

use Database\Seeders\Cafe618ReportsDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class Cafe618ReportsDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_idempotent_report_ready_sales_cash_and_shift_history(): void
    {
        $this->travelTo('2026-09-06 12:00:00');

        try {
            $this->seed();
            $this->seed(Cafe618ReportsDemoSeeder::class);

            $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
            $this->assertGreaterThanOrEqual(14, DB::table('orders')->where('tenant_id', $tenantId)->where('idempotency_key', 'like', 'cafe-618-pos-20260906-%')->count());
            $this->assertGreaterThan(0, DB::table('orders')->where('tenant_id', $tenantId)->where('order_number', 'like', 'RPT-%')->count());
            $this->assertGreaterThan(0, DB::table('payments')->where('tenant_id', $tenantId)->count());
            $this->assertGreaterThan(0, DB::table('payment_refunds')->where('tenant_id', $tenantId)->count());
            $this->assertGreaterThan(0, DB::table('shifts')->where('tenant_id', $tenantId)->where('status', 'closed')->count());
            $this->assertGreaterThanOrEqual(2, DB::table('cash_transfers')->where('tenant_id', $tenantId)->count());
            $this->assertGreaterThanOrEqual(2, DB::table('daily_closings')->where('tenant_id', $tenantId)->where('status', 'closed')->count());
            $this->assertGreaterThanOrEqual(1, DB::table('expenses')->where('tenant_id', $tenantId)->whereNull('branch_id')->count());

            $before = collect(['orders', 'payments', 'payment_refunds', 'shifts', 'cash_transfers', 'daily_closings', 'expenses'])
                ->mapWithKeys(fn (string $table) => [$table => DB::table($table)->where('tenant_id', $tenantId)->count()])
                ->all();

            $this->seed(Cafe618ReportsDemoSeeder::class);

            foreach ($before as $table => $count) {
                $this->assertSame($count, DB::table($table)->where('tenant_id', $tenantId)->count(), $table.' must not duplicate on rerun.');
            }
        } finally {
            $this->travelBack();
        }
    }
}
