<?php

namespace Tests\Feature;

use App\Services\DiscountResolutionService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

/**
 * Discount V3 Phase 1: two clients obtain the same short code, one saves first.
 * The loser is an independent PHP process that has already passed request
 * validation and is parked on the tenant policy lock when the winner commits,
 * so the unique index is exercised on the real create/update persistence path.
 */
class DiscountV3CouponSaveRaceTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }

    private function payload(string $name, string $code): array
    {
        return ['name' => $name, 'applicationMode' => 'code', 'code' => $code, 'type' => 'percentage', 'scope' => 'order', 'value' => 10, 'isActive' => true, 'appliesToAllBranches' => true];
    }

    private function rival(int $tenant, string $code): int
    {
        return DB::table('discounts')->insertGetId(['tenant_id' => $tenant, 'name' => 'Client A', 'code' => $code, 'application_mode' => 'code', 'type' => 'percentage', 'value' => 10, 'scope' => 'order', 'minimum_order_amount' => 0, 'is_active' => true, 'used_count' => 0, 'created_at' => now(), 'updated_at' => now()]);
    }

    /** Runs $request in a worker that is validated but blocked, lets the rival commit, then returns the worker's response. */
    private function race(int $tenant, string $token, string $path, string $method, array $data, string $code): array
    {
        $database = DB::selectOne('select current_database() as name')->name;
        DB::beginTransaction();
        app(DiscountResolutionService::class)->lock($tenant);
        $worker = $this->worker($database, $token, $path, $method, $data);
        try {
            $this->assertBlockedOnTenantLock($worker);
            // Client A wins the race while client B is already past validation.
            $this->rival($tenant, $code);
            DB::commit();

            return $this->finish($worker);
        } finally {
            if (DB::transactionLevel()) {
                DB::rollBack();
            }
            $this->terminate($worker);
        }
    }

    public function test_second_save_of_the_same_generated_code_is_a_clean_validation_error_on_create_and_update(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Race', 'slug' => uniqid('race-')]);
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        // Both clients hold this code: the endpoint does not reserve it.
        $code = $this->postJson('/api/v1/discounts/generate-code', [], $headers)->assertOk()->json('data.code');

        // Create: B posts the code in a different case, after A saved it.
        $result = $this->race($tenant, $token, '/api/v1/discounts', 'POST', $this->payload('Client B', strtolower($code)), $code);
        $this->assertSame(422, $result['status'], json_encode($result['body']));
        $this->assertArrayHasKey('code', $result['body']['errors']);
        $this->assertArrayNotHasKey('exception', $result['body']);
        $this->assertSame(1, DB::table('discounts')->where('tenant_id', $tenant)->whereRaw('LOWER(code) = ?', [strtolower($code)])->count());
        $this->assertSame(0, DB::table('discounts')->where('name', 'Client B')->count());

        // The client then asks for a replacement code and saves it.
        $replacement = $this->postJson('/api/v1/discounts/generate-code', [], $headers)->assertOk()->json('data.code');
        $this->assertNotSame($code, $replacement);
        $this->postJson('/api/v1/discounts', $this->payload('Client B', $replacement), $headers)->assertCreated()->assertJsonPath('data.code', $replacement);

        // Update: B edits an existing discount onto a code A has just taken.
        $second = $this->postJson('/api/v1/discounts/generate-code', [], $headers)->json('data.code');
        $existing = $this->postJson('/api/v1/discounts', $this->payload('Edited', 'EDIT2'), $headers)->assertCreated()->json('data.id');
        $result = $this->race($tenant, $token, "/api/v1/discounts/$existing", 'PUT', $this->payload('Edited', $second), $second);
        $this->assertSame(422, $result['status'], json_encode($result['body']));
        $this->assertArrayHasKey('code', $result['body']['errors']);
        $this->assertSame('EDIT2', DB::table('discounts')->where('id', $existing)->value('code'));
        $this->assertSame(1, DB::table('discounts')->where('tenant_id', $tenant)->whereRaw('LOWER(code) = ?', [strtolower($second)])->count());
    }

    private function worker(string $database, string $token, string $path, string $method, array $data): array
    {
        $name = uniqid('coupon-race-');
        $payload = ['workerName' => $name, 'token' => $token, 'path' => $path, 'method' => $method, 'data' => $data];
        $env = array_merge(getenv() ?: [], ['APP_ENV' => 'testing', 'DB_CONNECTION' => 'pgsql', 'DB_DATABASE' => $database, 'DB_URL' => '']);
        $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/DiscountVariantWorker.php'), base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
        $this->assertIsResource($process);

        return compact('name', 'process', 'pipes');
    }

    private function assertBlockedOnTenantLock(array $worker): void
    {
        $deadline = microtime(true) + 20;
        do {
            // Statistics snapshots are cached inside a PostgreSQL transaction.
            DB::select('select pg_stat_clear_snapshot()');
            $state = DB::table('pg_stat_activity')->where('datname', DB::raw('current_database()'))->where('application_name', $worker['name'])->first();
            if ($state && $state->wait_event_type === 'Lock') {
                $this->assertStringContainsString('pg_advisory_xact_lock', $state->query);

                return;
            }
            if (! proc_get_status($worker['process'])['running']) {
                $this->fail('Worker exited before the lock: '.stream_get_contents($worker['pipes'][1]).stream_get_contents($worker['pipes'][2]));
            }
            usleep(10000);
        } while (microtime(true) < $deadline);
        $this->fail('The independent worker did not reach the tenant policy lock.');
    }

    private function finish(array $worker): array
    {
        $stdout = stream_get_contents($worker['pipes'][1]);
        $stderr = stream_get_contents($worker['pipes'][2]);
        fclose($worker['pipes'][1]);
        fclose($worker['pipes'][2]);
        $this->assertSame(0, proc_close($worker['process']), $stderr);

        return json_decode($stdout, true, 512, JSON_THROW_ON_ERROR);
    }

    private function terminate(array $worker): void
    {
        if (is_resource($worker['process'])) {
            proc_terminate($worker['process']);
            proc_close($worker['process']);
        }
        foreach ($worker['pipes'] as $pipe) {
            if (is_resource($pipe)) {
                fclose($pipe);
            }
        }
    }
}
