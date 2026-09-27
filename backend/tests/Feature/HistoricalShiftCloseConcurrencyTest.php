<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialSetupService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

final class HistoricalShiftCloseConcurrencyTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }

    public function test_two_concurrent_closes_return_one_continuation_and_one_result(): void
    {
        [$tenant, $branch, $shift, $token, $order] = $this->scope();
        $preview = $this->getJson("/api/v1/shifts/{$shift}/close-preview?closingDate=2026-09-26", ['Authorization' => 'Bearer '.$token])->assertOk()->json('data');
        $payload = ['mode' => 'shift-close', 'accessToken' => $token, 'shiftId' => $shift, 'nowUtc' => '2026-09-27 08:00:00',
            'request' => ['closingDate' => '2026-09-26', 'closingCash' => '0.00', 'cashCountBasis' => 'period_recorded', 'barCountBasis' => 'period_recorded', 'previewVersion' => $preview['period']['version']]];
        $results = $this->runWorkers([$payload, $payload]);
        $this->assertTrue($results[0]['ok'], json_encode($results));
        $this->assertTrue($results[1]['ok'], json_encode($results));
        $next = DB::table('shifts')->where('continuation_of_shift_id', $shift)->first();
        $this->assertSame(1, DB::table('shifts')->where('continuation_of_shift_id', $shift)->count());
        $this->assertSame((int) $next->id, (int) DB::table('orders')->where('id', $order)->value('shift_id'));
        $this->assertSame(1, DB::table('shift_period_reassignments')->where('from_shift_id', $shift)->count());
        $this->assertSame(0, DB::table('cash_transfers')->where('tenant_id', $tenant)->count());
    }

    public function test_order_creation_and_historical_close_preserve_one_current_assignment(): void
    {
        [$tenant, $branch, $shift, $token] = $this->scope();
        $preview = $this->getJson("/api/v1/shifts/{$shift}/close-preview?closingDate=2026-09-26", ['Authorization' => 'Bearer '.$token])->assertOk()->json('data');
        $results = $this->runWorkers([
            ['mode' => 'shift-close', 'accessToken' => $token, 'shiftId' => $shift, 'nowUtc' => '2026-09-27 08:00:00',
                'request' => ['closingDate' => '2026-09-26', 'closingCash' => 0, 'cashCountBasis' => 'period_recorded', 'barCountBasis' => 'period_recorded', 'previewVersion' => $preview['period']['version']]],
            ['mode' => 'order-create', 'accessToken' => $token, 'nowUtc' => '2026-09-27 08:00:00',
                'request' => ['branchId' => $branch, 'shiftId' => $shift, 'type' => 'takeaway']],
        ]);
        if ($results[0]['ok']) {
            $next = DB::table('shifts')->where('continuation_of_shift_id', $shift)->first();
            $this->assertNotNull($next);
            $this->assertSame(0, DB::table('orders')->where('tenant_id', $tenant)->where('shift_id', $shift)->count());
            $this->assertSame(1, DB::table('shifts')->where('tenant_id', $tenant)->where('status', 'open')->count());
        } else {
            $this->assertTrue($results[1]['ok'], json_encode($results));
            $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
            $this->assertSame(0, DB::table('shifts')->where('continuation_of_shift_id', $shift)->count());
            $this->assertContains($results[0]['status'] ?? null, [409, 422], json_encode($results));
        }
        $this->assertSame($results[1]['ok'] ? 2 : 1, DB::table('orders')->where('tenant_id', $tenant)->count());
    }

    private function scope(): array
    {
        $this->travelTo(CarbonImmutable::parse('2026-09-27 08:00:00', 'UTC'));
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Historical race', 'slug' => uniqid('historical-race-'), 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Race branch', 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch);
        $owner = User::query()->create(['tenant_id' => $tenant, 'name' => 'Race owner', 'email' => uniqid('history-race-').'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);
        $drawer = DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $safe = DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $shift = DB::table('shifts')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $owner->id, 'financial_location_id' => $drawer, 'close_destination_financial_location_id' => $safe, 'closing_float_amount' => 0, 'opening_cash' => 0, 'status' => 'open', 'shift_number' => 'SH-RACE-HISTORICAL', 'opened_at' => '2026-09-26 07:00:00', 'created_at' => '2026-09-26 07:00:00', 'updated_at' => '2026-09-26 07:00:00']);
        $order = DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'shift_id' => $shift, 'order_number' => 'H-RACE-OPEN', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'total' => 0, 'opened_at' => now(), 'created_at' => now(), 'updated_at' => now()]);

        return [$tenant, $branch, $shift, $this->authenticateTenantUser($tenant, $owner), $order];
    }

    private function runWorkers(array $payloads): array
    {
        $barrier = random_int(1, PHP_INT_MAX);
        DB::select('select pg_advisory_lock(?)', [$barrier]);
        $workers = [];
        try {
            foreach ($payloads as $payload) {
                $payload['barrier'] = $barrier;
                $mode = $payload['mode'];
                unset($payload['mode']);
                $pipes = [];
                $env = array_merge(getenv() ?: [], ['DB_DATABASE' => (string) config('database.connections.pgsql_migrations.database')]);
                $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/ConcurrentFinancialWorker.php'), $mode, base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
                if (! is_resource($process)) {
                    throw new RuntimeException('Could not start historical close worker.');
                }
                $workers[] = compact('process', 'pipes');
            }
            $deadline = microtime(true) + 15;
            do {
                $waiting = DB::table('pg_stat_activity')->where('datname', DB::raw('current_database()'))->where('wait_event_type', 'Lock')->where('wait_event', 'advisory')->whereRaw("query ilike '%pg_advisory_lock%'")->count();
                if ($waiting >= count($workers)) {
                    break;
                }
                usleep(10000);
            } while (microtime(true) < $deadline);
            if ($waiting < count($workers)) {
                throw new RuntimeException('Historical close workers did not reach the barrier.');
            }
            DB::select('select pg_advisory_unlock(?)', [$barrier]);
            $barrier = null;
            $results = [];
            foreach ($workers as $worker) {
                $stdout = stream_get_contents($worker['pipes'][1]);
                $stderr = stream_get_contents($worker['pipes'][2]);
                fclose($worker['pipes'][1]);
                fclose($worker['pipes'][2]);
                proc_close($worker['process']);
                $result = json_decode($stdout, true);
                if (! is_array($result)) {
                    throw new RuntimeException('Historical worker returned invalid JSON: '.$stderr);
                }
                $results[] = $result;
            }

            return $results;
        } finally {
            if ($barrier !== null) {
                DB::select('select pg_advisory_unlock(?)', [$barrier]);
            }
            foreach ($workers as $worker) {
                if (is_resource($worker['process'])) {
                    proc_terminate($worker['process']);
                }
            }
        }
    }
}
