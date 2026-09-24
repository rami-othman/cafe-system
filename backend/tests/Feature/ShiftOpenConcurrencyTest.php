<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

/**
 * A2.1 scenario 3 — real concurrent shift opens from independent PHP/PDO
 * processes released through a PostgreSQL barrier. One physical drawer admits
 * exactly one open shift; different drawers proceed in parallel.
 */
final class ShiftOpenConcurrencyTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }

    public function test_03_concurrent_opens_on_one_drawer_yield_exactly_one_open_shift(): void
    {
        [$tenant, $branchA] = $this->scope();
        $payload = ['tenantId' => $tenant, 'request' => ['branchId' => $branchA, 'openingCash' => '0.00']];

        $results = $this->runConcurrently([$payload, $payload, $payload]);

        $this->assertCount(1, array_filter($results, fn (array $r): bool => $r['ok']));
        foreach (array_filter($results, fn (array $r): bool => ! $r['ok']) as $loser) {
            $this->assertSame(422, $loser['status']);
            $this->assertSame('يوجد وردية مفتوحة بالفعل على صندوق النقدية هذا.', $loser['errors']['branchId'][0]);
        }
        $drawer = (int) DB::table('branches')->where('id', $branchA)->value('pos_cash_financial_location_id');
        $this->assertSame(1, DB::table('shifts')->where('tenant_id', $tenant)->where('financial_location_id', $drawer)->where('status', 'open')->count());
    }

    public function test_05b_concurrent_opens_on_different_drawers_all_succeed(): void
    {
        [$tenant, $branchA, $branchB] = $this->scope();

        $results = $this->runConcurrently([
            ['tenantId' => $tenant, 'request' => ['branchId' => $branchA, 'openingCash' => '0.00']],
            ['tenantId' => $tenant, 'request' => ['branchId' => $branchB, 'openingCash' => '0.00']],
        ]);

        $this->assertCount(2, array_filter($results, fn (array $r): bool => $r['ok']), json_encode($results));
        $numbers = DB::table('shifts')->where('tenant_id', $tenant)->where('status', 'open')->pluck('shift_number')->all();
        $this->assertCount(2, array_unique($numbers));
    }

    private function scope(): array
    {
        $this->assertStringContainsString('testing', (string) config('database.connections.pgsql_migrations.database'));
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'A2 Race', 'slug' => 'a2-race-'.uniqid(), 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $a = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Race A', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $b = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Race B', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        User::query()->create(['tenant_id' => $tenant, 'name' => 'Race Owner', 'email' => 'a2-race-'.uniqid().'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);

        return [$tenant, $a, $b];
    }

    /** @return list<array<string, mixed>> */
    private function runConcurrently(array $payloads): array
    {
        $barrier = random_int(1, PHP_INT_MAX);
        DB::select('select pg_advisory_lock(?)', [$barrier]);
        $workers = [];
        try {
            foreach ($payloads as $payload) {
                $payload['barrier'] = $barrier;
                $payload['accessToken'] = $this->authenticateTenantUser((int) $payload['tenantId']);
                $pipes = [];
                $env = array_merge(getenv() ?: [], ['DB_DATABASE' => (string) config('database.connections.pgsql_migrations.database')]);
                $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/ConcurrentFinancialWorker.php'), 'shift-open', base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))],
                    [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
                if (! is_resource($process)) {
                    throw new RuntimeException('Could not start concurrent shift worker.');
                }
                $workers[] = compact('process', 'pipes');
            }
            $this->waitForBarrier(count($workers));
            DB::select('select pg_advisory_unlock(?)', [$barrier]);
            $barrier = null;

            return array_map(function (array $worker): array {
                $stdout = stream_get_contents($worker['pipes'][1]);
                $stderr = stream_get_contents($worker['pipes'][2]);
                fclose($worker['pipes'][1]);
                fclose($worker['pipes'][2]);
                $exit = proc_close($worker['process']);
                $result = json_decode($stdout, true);
                if (! is_array($result)) {
                    throw new RuntimeException("Shift worker did not return JSON (exit {$exit}): {$stderr}");
                }

                return $result;
            }, $workers);
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

    private function waitForBarrier(int $expected): void
    {
        $deadline = microtime(true) + 15;
        do {
            $waiting = (int) DB::table('pg_stat_activity')->where('datname', DB::raw('current_database()'))
                ->where('wait_event_type', 'Lock')->where('wait_event', 'advisory')
                ->whereRaw("query ilike '%pg_advisory_lock%'")->count();
            if ($waiting >= $expected) {
                return;
            }
            usleep(10_000);
        } while (microtime(true) < $deadline);

        throw new RuntimeException("Only {$waiting} of {$expected} workers reached the barrier.");
    }
}
