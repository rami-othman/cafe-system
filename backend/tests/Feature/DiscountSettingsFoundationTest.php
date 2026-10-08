<?php

namespace Tests\Feature;

use App\Services\DefaultTenantRoleService;
use App\Services\DiscountSettingsService;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

class DiscountSettingsFoundationTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }

    private const URL = '/api/v1/cafe-configuration/discount-settings';

    public function test_two_first_saves_and_two_updates_serialize_without_lost_writes(): void
    {
        $this->assertSame('cafe_system_618_testing_migrations', DB::selectOne('select current_database() as name')->name);
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Race', 'slug' => 'settings-race']);
        $token = $this->authenticateTenantUser($tenant);
        foreach ([0, 1] as $version) {
            $workers = [];
            DB::beginTransaction();
            DB::select('select pg_advisory_xact_lock(?, ?)', [20402, $tenant]);
            $parentPid = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
            try {
                foreach (['priority', 'lowest_saving'] as $strategy) {
                    $workers[] = $this->worker($token, DiscountSettingsService::DEFAULTS + ['expectedVersion' => $version], $strategy);
                }
                // Both independent HTTP workers must be blocked on this exact
                // parent lock before release. Timing alone is never the barrier.
                foreach ($workers as $worker) {
                    $this->awaitBlocked($worker, $parentPid);
                }
                DB::commit();
                $results = array_map(fn ($worker) => $this->finish($worker), $workers);
                $statuses = array_column($results, 'status');
                sort($statuses);
                $this->assertSame([200, 409], $statuses);
                $winner = array_values(array_filter($results, fn ($r) => $r['status'] === 200))[0];
                $loser = array_values(array_filter($results, fn ($r) => $r['status'] === 409))[0];
                $this->assertSame('DISCOUNT_SETTINGS_VERSION_CONFLICT', $loser['body']['code']);
                $this->assertSame($version + 1, $winner['body']['data']['version']);
                $this->assertSame($winner['body']['data'], app(DiscountSettingsService::class)->read($tenant));
                $this->assertSame(1, DB::table('tenant_discount_settings')->where('tenant_id', $tenant)->count());
                $this->assertSame($version + 1, DB::table('activity_logs')->where('tenant_id', $tenant)->where('action', 'discount.settings.updated')->count());
            } finally {
                if (DB::transactionLevel()) {
                    DB::rollBack();
                }
                foreach ($workers as $worker) {
                    $this->terminate($worker);
                }
            }
        }
    }

    public function test_upgrade_preserves_legacy_paid_values_usage_and_reads_without_fabricated_metadata(): void
    {
        $migration = require database_path('migrations/2026_10_03_000002_extend_discount_runtime_foundation.php');
        $engine = require database_path('migrations/2026_10_03_000003_create_discount_engine_protocol.php');
        $engine->down();
        $migration->down();
        $scope = $this->legacy();
        $before = DB::table('orders')->where('id', $scope['order'])->first();
        $appliedBefore = DB::table('order_discounts')->where('id', $scope['applied'])->first();
        $usageBefore = DB::table('discount_usages')->where('id', $scope['usage'])->first();
        $paymentBefore = DB::table('payments')->where('id', $scope['payment'])->first();
        $migration->up();
        $engine->up();
        $this->assertEquals($before, DB::table('orders')->where('id', $scope['order'])->first());
        $applied = (array) DB::table('order_discounts')->where('id', $scope['applied'])->first();
        foreach (['source', 'stage', 'settings_version', 'calculation_metadata', 'policy_snapshot'] as $field) {
            $this->assertNull($applied[$field]);
            unset($applied[$field]);
        }
        $this->assertSame((array) $appliedBefore, $applied);
        $this->assertEquals($usageBefore, DB::table('discount_usages')->where('id', $scope['usage'])->first());
        $this->assertDatabaseCount('order_discount_allocations', 0);
        $this->assertDatabaseCount('order_discount_suppressions', 0);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($scope['tenant'])];
        $receiptBefore = $this->getJson('/api/v1/orders/'.$scope['order'].'/receipt', $headers)->assertOk()->json();
        $this->putJson(self::URL, array_replace(DiscountSettingsService::DEFAULTS, ['expectedVersion' => 0, 'combinationMode' => 'disjoint_items', 'orderDiscountBehavior' => 'after_items', 'maximumTotalDiscountPercent' => 1]), $headers)->assertOk();
        DB::table('discounts')->where('id', $scope['discount'])->update(['name' => 'Edited live policy', 'value' => 75]);
        $this->getJson('/api/v1/orders/'.$scope['order'].'/receipt', $headers)->assertOk()->assertExactJson($receiptBefore);
        $this->getJson('/api/v1/orders/'.$scope['order'], $headers)->assertOk();
        $this->assertEquals($before, DB::table('orders')->where('id', $scope['order'])->first());
        $this->assertEquals($paymentBefore, DB::table('payments')->where('id', $scope['payment'])->first());
        $this->assertSame('0.01', DB::table('order_discounts')->where('id', $scope['applied'])->value('discount_amount'));
    }

    public function test_composite_usage_and_tenant_safe_allocations_suppressions_and_actor_links(): void
    {
        $s = $this->legacy();
        $other = $this->legacy('other');
        $policy = DB::table('discounts')->insertGetId(['tenant_id' => $s['tenant'], 'name' => 'Second', 'type' => 'fixed', 'value' => 1]);
        $usage = ['tenant_id' => $s['tenant'], 'order_id' => $s['order'], 'discount_id' => $policy];
        DB::table('discount_usages')->insert($usage);
        $this->reject(fn () => DB::table('discount_usages')->insert($usage), '23505');
        $this->reject(fn () => DB::table('discount_usages')->insert(array_replace($usage, ['order_id' => $other['order']])), '23503');
        $this->reject(fn () => DB::table('discount_usages')->insert(array_replace($usage, ['discount_id' => $other['discount']])), '23503');
        $thirdPolicy = DB::table('discounts')->insertGetId(['tenant_id' => $s['tenant'], 'name' => 'Third', 'type' => 'fixed', 'value' => 1]);
        $this->reject(fn () => DB::table('discount_usages')->insert(array_replace($usage, ['discount_id' => $thirdPolicy, 'payment_id' => $other['payment']])), '23503');
        $allocation = ['tenant_id' => $s['tenant'], 'order_id' => $s['order'], 'order_discount_id' => $s['applied'], 'order_item_id' => $s['item'], 'amount' => '0.01'];
        DB::table('order_discount_allocations')->insert($allocation);
        $this->reject(fn () => DB::table('order_discount_allocations')->insert($allocation), '23505');
        $this->reject(fn () => DB::table('order_discount_allocations')->insert(array_replace($allocation, ['order_item_id' => $other['item']])), '23503');
        $this->reject(fn () => DB::table('order_discount_allocations')->insert(array_replace($allocation, ['order_discount_id' => $other['applied']])), '23503');
        $this->reject(fn () => DB::table('order_discount_allocations')->insert(array_replace($allocation, ['amount' => '-0.01'])), '23514');
        $sameTenantOrder = DB::table('orders')->insertGetId(['tenant_id' => $s['tenant'], 'branch_id' => $s['branch'], 'order_number' => 'same-tenant-other-order']);
        $item = DB::table('order_items')->insertGetId(['tenant_id' => $s['tenant'], 'order_id' => $sameTenantOrder, 'product_name' => 'Other order', 'quantity' => 1, 'unit_price' => 1, 'total' => 1]);
        $this->reject(fn () => DB::table('order_discount_allocations')->insert(array_replace($allocation, ['order_item_id' => $item])), '23503');
        $actorToken = $this->authenticateTenantUser($s['tenant']);
        $actor = DB::table('api_tokens')->where('token_hash', hash('sha256', $actorToken))->value('user_id');
        $otherToken = $this->authenticateTenantUser($other['tenant']);
        $otherActor = DB::table('api_tokens')->where('token_hash', hash('sha256', $otherToken))->value('user_id');
        $suppression = ['tenant_id' => $s['tenant'], 'order_id' => $s['order'], 'discount_id' => $s['discount'], 'suppressed_by' => $actor, 'reason' => 'Test metadata only'];
        DB::table('order_discount_suppressions')->insert($suppression);
        $this->reject(fn () => DB::table('order_discount_suppressions')->insert(array_replace($suppression, ['discount_id' => $policy, 'suppressed_by' => $otherActor])), '23503');
        $this->reject(fn () => DB::table('order_discount_suppressions')->insert(array_replace($suppression, ['discount_id' => $policy, 'reason' => '  '])), '23514');
        $settings = [];
        foreach (DiscountSettingsService::COLUMNS as $field => $column) {
            $settings[$column] = DiscountSettingsService::DEFAULTS[$field];
        }
        $this->reject(fn () => DB::table('tenant_discount_settings')->insert($settings + ['tenant_id' => $s['tenant'], 'version' => 1, 'updated_by' => $otherActor]), '23503');
        $validSettings = $settings + ['tenant_id' => $s['tenant'], 'version' => 1, 'updated_by' => $actor];
        $this->reject(fn () => DB::table('tenant_discount_settings')->insert(array_replace($validSettings, ['automatic_enabled' => true])), '23514');
        $this->reject(fn () => DB::table('tenant_discount_settings')->insert(array_replace($validSettings, ['order_discount_behavior' => 'after_items'])), '23514');
        DB::table('tenant_discount_settings')->insert($validSettings);
        $this->reject(fn () => DB::table('tenant_discount_settings')->insert($validSettings), '23505');
        $migration = require database_path('migrations/2026_10_03_000002_extend_discount_runtime_foundation.php');
        try {
            $migration->down();
            $this->fail('Multi-policy history must prevent restoring old uniqueness.');
        } catch (\RuntimeException $exception) {
            $this->assertStringContainsString('roll forward', $exception->getMessage());
        }
        $this->assertDatabaseCount('order_discount_allocations', 1);
        DB::table('discount_usages')->where('discount_id', $policy)->delete();
    }

    public function test_permission_upgrade_preserves_existing_revocations_and_initializes_manager_once(): void
    {
        $runtime = require database_path('migrations/2026_10_03_000002_extend_discount_runtime_foundation.php');
        $settings = require database_path('migrations/2026_10_03_000001_create_discount_settings_foundation.php');
        $engine = require database_path('migrations/2026_10_03_000003_create_discount_engine_protocol.php');
        $policy = require database_path('migrations/2026_10_11_000001_add_discount_v3_policy_settings.php');
        $policy->down();
        $engine->down();
        $runtime->down();
        $settings->down();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Upgrade', 'slug' => 'settings-upgrade']);
        app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
        DB::table('discount_role_permissions')->where('tenant_id', $tenant)->where('permission', 'discounts.manage')->delete();
        $settings->up();
        $runtime->up();
        $engine->up();
        $policy->up();
        $this->assertDatabaseMissing('discount_role_permissions', ['tenant_id' => $tenant, 'permission' => 'discounts.manage']);
        $this->assertDatabaseHas('discount_role_permissions', ['tenant_id' => $tenant, 'role' => 'manager', 'permission' => 'discounts.settings.manage']);
        $this->assertDatabaseMissing('discount_role_permissions', ['tenant_id' => $tenant, 'role' => 'employee', 'permission' => 'discounts.settings.manage']);
        DB::table('discount_role_permissions')->where('tenant_id', $tenant)->where('permission', 'discounts.settings.manage')->delete();
        app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
        $this->assertDatabaseMissing('discount_role_permissions', ['tenant_id' => $tenant, 'permission' => 'discounts.settings.manage']);
        $this->assertDatabaseMissing('discount_role_permissions', ['tenant_id' => $tenant, 'permission' => 'discounts.manage']);
    }

    private function legacy(string $suffix = 'main'): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Legacy', 'slug' => 'legacy-'.$suffix]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch', 'is_active' => true]);
        $discount = DB::table('discounts')->insertGetId(['tenant_id' => $tenant, 'name' => 'Legacy policy', 'type' => 'percentage', 'value' => 10]);
        $order = DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'order_number' => 'OLD-PAID', 'type' => 'takeaway', 'status' => 'paid', 'payment_status' => 'paid', 'subtotal' => '0.10', 'discount_total' => '0.01', 'tax_total' => '0.00', 'total' => '0.09', 'tax_rate' => 0]);
        $item = DB::table('order_items')->insertGetId(['tenant_id' => $tenant, 'order_id' => $order, 'product_name' => 'Historical', 'quantity' => 1, 'unit_price' => '0.10', 'total' => '0.10']);
        $applied = DB::table('order_discounts')->insertGetId(['tenant_id' => $tenant, 'order_id' => $order, 'discount_id' => $discount, 'discount_name' => 'Historical policy', 'discount_type' => 'percentage', 'discount_value' => 10, 'discount_amount' => '0.01']);
        $payment = DB::table('payments')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'order_id' => $order, 'amount' => '0.09', 'method' => 'cash', 'currency' => 'SYP', 'status' => 'completed', 'paid_at' => now()]);
        $usage = DB::table('discount_usages')->insertGetId(['tenant_id' => $tenant, 'order_id' => $order, 'discount_id' => $discount, 'payment_id' => $payment]);

        return compact('tenant', 'branch', 'discount', 'order', 'item', 'applied', 'usage', 'payment');
    }

    private function reject(callable $write, string $sqlState): void
    {
        try {
            DB::transaction($write);
            $this->fail('Database constraint did not reject the invalid relationship.');
        } catch (QueryException $exception) {
            $this->assertSame($sqlState, $exception->errorInfo[0]);
        }
    }

    private function worker(string $token, array $data, string $strategy): array
    {
        $name = uniqid('settings-worker-');
        $payload = ['workerName' => $name, 'token' => $token, 'path' => self::URL, 'method' => 'PUT', 'data' => array_replace($data, ['selectionStrategy' => $strategy])];
        $env = array_merge(getenv() ?: [], ['APP_ENV' => 'testing', 'DB_CONNECTION' => 'pgsql', 'DB_DATABASE' => 'cafe_system_618_testing_migrations', 'DB_URL' => '']);
        $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/DiscountVariantWorker.php'), base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
        $this->assertIsResource($process);

        return compact('name', 'process', 'pipes');
    }

    private function awaitBlocked(array $worker, int $parentPid): void
    {
        $deadline = microtime(true) + 15;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $state = DB::selectOne('select wait_event, ? = ANY(pg_blocking_pids(pid)) as parent_blocks from pg_stat_activity where datname = current_database() and application_name = ?', [$parentPid, $worker['name']]);
            if ($state && $state->wait_event === 'advisory' && $state->parent_blocks) {
                $this->assertTrue((bool) $state->parent_blocks);

                return;
            }
            if (! proc_get_status($worker['process'])['running']) {
                $this->fail('Worker exited before the database barrier.');
            }
        } while (microtime(true) < $deadline);
        $this->fail('Worker did not reach the database barrier.');
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
