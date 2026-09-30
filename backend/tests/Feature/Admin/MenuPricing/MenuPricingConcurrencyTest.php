<?php

namespace Tests\Feature\Admin\MenuPricing;

use App\Models\User;
use App\Services\Menu\MenuPriceAdjustmentService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

class MenuPricingConcurrencyTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }

    public function test_same_adjustment_concurrent_applies_serialize_to_one_durable_outcome_without_duplicate_prices(): void
    {
        $scope = $this->scope();
        $preview = $this->preview($scope);
        $results = $this->runWorkers([
            $this->applyPayload($scope, $preview),
            $this->applyPayload($scope, $preview),
        ]);

        $this->assertCount(2, array_filter($results, fn (array $result): bool => $result['ok']));
        $this->assertSame(['applied'], collect($results)->pluck('result.status')->unique()->values()->all());
        $this->assertSame('applied', DB::table('menu_price_adjustments')->where('id', $preview['id'])->value('status'));
        $this->assertSame(2, DB::table('menu_variant_prices')->count());
        $this->assertSame(2, DB::table('menu_variant_prices')->select('product_variant_id')->distinct()->count());
    }

    public function test_product_archive_racing_apply_has_a_serialized_outcome_with_no_partial_price_writes(): void
    {
        $scope = $this->scope();
        $preview = $this->preview($scope);
        $results = $this->runWorkers([
            $this->applyPayload($scope, $preview),
            ['action' => 'archive', 'tenantId' => $scope['tenant'], 'productId' => $scope['product']],
        ]);

        $apply = collect($results)->first(fn (array $result): bool => array_key_exists('result', $result) && isset($result['result']['status']) || (($result['message'] ?? '') !== '' && str_contains($result['message'], 'MENU_PRICING')));
        $this->assertTrue((bool) collect($results)->firstWhere('ok', true));
        $this->assertFalse((bool) DB::table('products')->where('id', $scope['product'])->value('is_active'));
        $priceCount = DB::table('menu_variant_prices')->count();
        if (($apply['ok'] ?? false) === true) {
            $this->assertSame('applied', $apply['result']['status']);
            $this->assertSame(2, $priceCount);
        } else {
            $this->assertContains($apply['message'], ['MENU_PRICING_PREVIEW_STALE', 'MENU_PRICING_TARGET_NO_LONGER_ELIGIBLE']);
            $this->assertSame(0, $priceCount);
        }
    }

    public function test_shared_override_sync_and_apply_follow_the_branch_before_product_order_without_an_fk_deadlock(): void
    {
        $scope = $this->scope();
        $preview = $this->preview($scope);
        $workers = [];
        $releaseGate = random_int(1, PHP_INT_MAX);
        $applyGate = random_int(1, PHP_INT_MAX);
        DB::select('select pg_advisory_lock(?)', [$releaseGate]);
        DB::select('select pg_advisory_lock(?)', [$applyGate]);
        try {
            // A dedicated worker holds the product first. Sync then acquires the
            // branch and waits for that product; apply is released only after that.
            // The former product-first sync order formed the exact FK deadlock here.
            $workers[] = $this->startWorker(['action' => 'hold_product', 'productId' => $scope['product'], 'releaseBarrier' => $releaseGate]);
            $this->waitForWorkers(1);
            $workers[] = $this->startWorker($this->sharedOverridePayload($scope));
            $this->waitForLockWaiters(1);
            $workers[] = $this->startWorker($this->applyPayload($scope, $preview) + ['barrier' => $applyGate]);
            DB::select('select pg_advisory_unlock(?)', [$applyGate]);
            $this->waitForLockWaiters(2);
            DB::select('select pg_advisory_unlock(?)', [$releaseGate]);
        } catch (\Throwable $exception) {
            DB::select('select pg_advisory_unlock(?)', [$releaseGate]);
            DB::select('select pg_advisory_unlock(?)', [$applyGate]);
            foreach ($workers as $worker) {
                if (is_resource($worker['process'])) {
                    proc_terminate($worker['process']);
                }
                fclose($worker['pipes'][1]);
                fclose($worker['pipes'][2]);
                proc_close($worker['process']);
            }
            throw $exception;
        }

        $results = array_map(fn (array $worker): array => $this->finishWorker($worker), $workers);
        [, $sync, $apply] = $results;

        $this->assertTrue((bool) ($sync['ok'] ?? false));
        $this->assertFalse((bool) ($apply['ok'] ?? false));
        $this->assertSame('MENU_PRICING_PREVIEW_STALE', $apply['message']);
        $this->assertDatabaseHas('product_variant_price_overrides', ['tenant_id' => $scope['tenant'], 'product_variant_id' => $scope['variant'], 'branch_id' => $scope['branch'], 'channel' => 'pos', 'override_price' => '15.00', 'deleted_at' => null]);
        $this->assertSame(0, DB::table('menu_variant_prices')->count());
        $this->assertStringNotContainsString('40P01', (string) ($apply['message'] ?? ''));
    }

    private function preview(array $scope): array
    {
        $result = app(MenuPriceAdjustmentService::class)->preview($scope['tenant'], $scope['actor'], $scope['menu'], ['branchId' => $scope['branch'], 'channel' => 'pos', 'operation' => 'fixed_increase', 'amount' => '1', 'roundingMode' => 'no_rounding', 'roundingStep' => null]);
        return ['id' => $result['id'], 'fingerprint' => $result['fingerprint']];
    }

    private function applyPayload(array $scope, array $preview): array
    {
        return ['action' => 'apply', 'tenantId' => $scope['tenant'], 'actorId' => $scope['actor'], 'menuId' => $scope['menu'], 'adjustmentId' => $preview['id'], 'fingerprint' => $preview['fingerprint']];
    }

    private function sharedOverridePayload(array $scope): array
    {
        return ['action' => 'sync_shared_override', 'tenantId' => $scope['tenant'], 'variantId' => $scope['variant'], 'branchId' => $scope['branch'], 'channel' => 'pos', 'overridePrice' => '15.00'];
    }

    private function runWorkers(array $payloads): array
    {
        $barrier = random_int(1, PHP_INT_MAX);
        DB::select('select pg_advisory_lock(?)', [$barrier]);
        $workers = [];
        try {
            foreach ($payloads as $payload) {
                $payload['barrier'] = $barrier;
                $pipes = [];
                $environment = array_merge(getenv() ?: [], ['DB_DATABASE' => (string) config('database.connections.pgsql_migrations.database')]);
                $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/ConcurrentMenuPricingWorker.php'), base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $environment);
                if (! is_resource($process)) throw new RuntimeException('Could not start concurrent menu pricing worker.');
                $workers[] = compact('process', 'pipes');
            }
            $this->waitForWorkers(count($workers));
            DB::select('select pg_advisory_unlock(?)', [$barrier]);
            $barrier = null;
            return array_map(function (array $worker): array {
                $stdout = stream_get_contents($worker['pipes'][1]); $stderr = stream_get_contents($worker['pipes'][2]);
                fclose($worker['pipes'][1]); fclose($worker['pipes'][2]); $exit = proc_close($worker['process']);
                $result = json_decode($stdout, true);
                if (! is_array($result)) throw new RuntimeException("Concurrent menu pricing worker did not return JSON (exit {$exit}): {$stderr}");
                return $result;
            }, $workers);
        } finally {
            if ($barrier !== null) DB::select('select pg_advisory_unlock(?)', [$barrier]);
            foreach ($workers as $worker) if (is_resource($worker['process'])) proc_terminate($worker['process']);
        }
    }

    private function startWorker(array $payload): array
    {
        $pipes = [];
        $environment = array_merge(getenv() ?: [], ['DB_DATABASE' => (string) config('database.connections.pgsql_migrations.database')]);
        $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/ConcurrentMenuPricingWorker.php'), base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $environment);
        if (! is_resource($process)) {
            throw new RuntimeException('Could not start concurrent menu pricing worker.');
        }

        return compact('process', 'pipes');
    }

    private function finishWorker(array $worker): array
    {
        $stdout = stream_get_contents($worker['pipes'][1]);
        $stderr = stream_get_contents($worker['pipes'][2]);
        fclose($worker['pipes'][1]);
        fclose($worker['pipes'][2]);
        $exit = proc_close($worker['process']);
        $result = json_decode($stdout, true);
        if (! is_array($result)) {
            throw new RuntimeException("Concurrent menu pricing worker did not return JSON (exit {$exit}): {$stderr}");
        }

        return $result;
    }

    private function waitForWorkers(int $expected): void
    {
        $deadline = microtime(true) + 10;
        do {
            $waiting = (int) DB::table('pg_stat_activity')->where('datname', DB::raw('current_database()'))->where('wait_event_type', 'Lock')->where('wait_event', 'advisory')->whereRaw("query ilike '%pg_advisory_lock%'")->count();
            if ($waiting >= $expected) return;
            usleep(10_000);
        } while (microtime(true) < $deadline);
        throw new RuntimeException("Only {$waiting} workers reached the PostgreSQL start barrier.");
    }

    private function waitForLockWaiters(int $expected): void
    {
        $deadline = microtime(true) + 10;
        do {
            $waiting = (int) DB::table('pg_stat_activity')
                ->where('datname', DB::raw('current_database()'))
                ->where('pid', '!=', DB::raw('pg_backend_pid()'))
                ->where('wait_event_type', 'Lock')
                ->where('wait_event', '!=', 'advisory')
                ->count();
            if ($waiting >= $expected) {
                return;
            }
            usleep(10_000);
        } while (microtime(true) < $deadline);

        throw new RuntimeException("Only {$waiting} workers reached the deterministic PostgreSQL lock interleaving.");
    }

    private function scope(): array
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Pricing', 'slug' => 'pricing-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $actor = User::query()->create(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => 'pricing-'.uniqid().'@example.test', 'password' => 'testing-password', 'role' => 'owner', 'is_active' => true, 'must_change_password' => false])->id;
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'price' => '10.00', 'is_active' => true, 'product_type' => 'standard', 'created_at' => $now, 'updated_at' => $now]);
        foreach ([['Regular', true, '10.00'], ['Large', false, '12.00']] as [$name, $default, $price]) DB::table('product_variants')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'name' => $name, 'base_price' => $price, 'is_default' => $default, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $variant = (int) DB::table('product_variants')->where('product_id', $product)->orderBy('id')->value('id');
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'status' => 'draft', 'created_at' => $now, 'updated_at' => $now]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('menu_item_placements')->insert(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'is_visible' => true, 'created_at' => $now, 'updated_at' => $now]);
        return compact('tenant', 'actor', 'branch', 'menu', 'product', 'variant');
    }
}
