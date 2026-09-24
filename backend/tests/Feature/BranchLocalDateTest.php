<?php

namespace Tests\Feature;

use App\Support\BranchLocalDate;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * C6 — branch-local "today" must follow branches.timezone, independent of
 * the server's UTC storage/clock. Storage itself (created_at/updated_at,
 * journal entry_date columns, etc.) stays UTC; this only covers the
 * business-day default derivation this task explicitly touches.
 */
class BranchLocalDateTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_branch_local_today_crosses_midnight_ahead_of_utc(): void
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => 'BLD', 'slug' => 'bld-tz', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branchId = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Damascus Branch', 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        // UTC 2026-09-20 22:00 is already 2026-09-21 01:00 in Damascus (UTC+3).
        Carbon::setTestNow(Carbon::create(2026, 9, 20, 22, 0, 0, 'UTC'));

        $this->assertSame('2026-09-20', now('UTC')->toDateString(), 'Sanity check: UTC calendar date is the 20th.');
        $this->assertSame('2026-09-21', BranchLocalDate::today($branchId), 'Branch-local "today" must already be the 21st in Damascus.');
    }

    public function test_branch_local_today_falls_back_to_utc_when_branch_has_no_timezone(): void
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => 'BLD2', 'slug' => 'bld-tz-null', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branchId = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenantId, 'name' => 'No TZ Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        Carbon::setTestNow(Carbon::create(2026, 9, 20, 23, 30, 0, 'UTC'));

        $this->assertSame('2026-09-20', BranchLocalDate::today($branchId));
        $this->assertSame('2026-09-20', BranchLocalDate::today(null));
    }
}
