<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/**
 * Phase 9 remaining gaps #9-#10: close concurrency/idempotency and the
 * historical-snapshot-vs-current-ledger distinction. True parallel threads
 * aren't available in this single-process PHPUnit/SQLite harness, but the
 * close() transaction's row lock means a second real concurrent attempt
 * behaves exactly like a second sequential call that observes the row
 * already 'closed' (or the unique constraint on a fresh insert race) — so
 * sequential calls exercise the same code path a real race would hit.
 */
class DailyClosingConcurrencyTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_duplicate_close_retry_is_idempotent_and_does_not_duplicate_audit_or_rows(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'dup-close');
        $branch = $this->branchId($tenant);
        $date = '2030-07-01';

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => '0.00'], $headers)->assertOk();
        $first = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", [], $headers)->assertOk()->json('data');
        $second = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", [], $headers)->assertOk()->json('data');

        $this->assertSame($first['status'], $second['status']);
        $this->assertSame($first['closedAt'], $second['closedAt']);
        $this->assertSame($first['closedBy'], $second['closedBy']);
        $this->assertSame(1, DB::table('daily_closings')->where('tenant_id', $tenant)->where('branch_id', $branch)->whereDate('business_date', $date)->count());
        $this->assertSame(1, DB::table('activity_logs')->where('tenant_id', $tenant)->where('entity_type', 'daily_closing')->where('entity_id', $preview['id'])->where('action', 'daily_closing.closed')->count());
    }

    public function test_concurrent_getorcreate_never_produces_two_rows_for_the_same_tenant_branch_date(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'race-create');
        $branch = $this->branchId($tenant);
        $date = '2030-07-02';

        $first = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data.id');
        $second = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data.id');

        $this->assertSame($first, $second);
        $this->assertSame(1, DB::table('daily_closings')->where('tenant_id', $tenant)->where('branch_id', $branch)->whereDate('business_date', $date)->count());
    }

    public function test_a_true_duplicate_insert_race_is_rejected_by_the_unique_constraint(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $date = '2030-07-03';
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');

        DB::table('daily_closings')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'business_date' => $date, 'reference' => 'DC-RACE-1', 'status' => 'open', 'created_by' => $owner, 'created_at' => now(), 'updated_at' => now()]);

        $this->expectException(\Illuminate\Database\QueryException::class);
        DB::table('daily_closings')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'business_date' => $date, 'reference' => 'DC-RACE-2', 'status' => 'open', 'created_by' => $owner, 'created_at' => now(), 'updated_at' => now()]);
    }

    public function test_close_ignores_client_supplied_totals_and_always_uses_backend_calculated_values(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'tamper');
        $branch = $this->branchId($tenant);
        $date = '2030-07-04';

        $order = $this->makeOrder($tenant, $branch, '50.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '50.00', $date.' 12:00:00', 'cash');
        $this->completeCashReconciliation($tenant, $branch, $date);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertSame('50.00', $preview['cash']['expectedCash']);

        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => '50.00', 'grossSales' => '999999.00', 'expectedCash' => '1.00', 'netSales' => '1.00'], $headers)->assertOk();
        $closed = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", ['expensesTotal' => '777.00', 'expectedCash' => '1.00', 'actualCash' => '50.00'], $headers)->assertOk()->json('data');

        $this->assertSame('50.00', $closed['cash']['expectedCash']);
        $this->assertSame('50.00', $closed['cash']['actualCash']);
        $this->assertSame('50.00', $closed['sales']['grossSales']);
        $this->assertSame('0.00', $closed['operations']['expensesTotal']);
    }

    public function test_historical_snapshot_is_frozen_even_after_new_legitimate_data_lands_on_the_same_business_date(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'snapshot-frozen');
        $branch = $this->branchId($tenant);
        $date = '2030-07-05';

        $order = $this->makeOrder($tenant, $branch, '40.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '40.00', $date.' 12:00:00', 'cash');
        $this->completeCashReconciliation($tenant, $branch, $date);

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => '40.00'], $headers)->assertOk();
        $closed = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", [], $headers)->assertOk()->json('data');
        $this->assertSame('40.00', $closed['sales']['grossSales']);

        // New, entirely legitimate sale dated on the already-closed business date.
        $lateOrder = $this->makeOrder($tenant, $branch, '500.00', $date.' 13:00:00');
        $this->makePayment($tenant, $branch, $lateOrder, '500.00', $date.' 13:00:00', 'cash');

        $detail = $this->getJson("/api/v1/finance/daily-closings/{$preview['id']}", $headers)->assertOk()->json('data');
        $this->assertSame('40.00', $detail['sales']['grossSales']);
        $this->assertSame('closed', $detail['status']);

        // The live ledger for that date, by contrast, now reflects both sales — proving this is a snapshot freeze, not a broken read.
        $liveTotal = (float) DB::table('payments')->where('tenant_id', $tenant)->where('branch_id', $branch)->whereDate('paid_at', $date)->sum('amount');
        $this->assertSame(540.0, $liveTotal);
    }
}
