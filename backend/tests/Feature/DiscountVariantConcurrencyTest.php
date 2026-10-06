<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

class DiscountVariantConcurrencyTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }

    public function test_application_and_legacy_update_wait_for_complete_target_replacement(): void
    {
        $database = DB::selectOne('select current_database() as name')->name;
        $this->assertSame('cafe_system_618_testing_migrations', $database);
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Concurrent', 'slug' => uniqid('concurrent-')]);
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch', 'is_active' => true, 'timezone' => 'UTC']);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Product', 'is_active' => true]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Selected', 'is_active' => true]);
        $sibling = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Sibling', 'is_active' => true]);
        $payload = ['name' => 'Policy', 'applicationMode' => 'manual', 'type' => 'percentage', 'scope' => 'product', 'value' => 50, 'isActive' => true, 'appliesToAllBranches' => true, 'targetProductIds' => [$product], 'productVariantSelections' => [['productId' => $product, 'variantMode' => 'selected', 'variantIds' => [$variant]]]];
        $discount = $this->postJson('/api/v1/discounts', $payload, $headers)->assertCreated()->json('data.id');
        $order = DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'order_number' => 'CON-V1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 10, 'total' => 10, 'tax_rate' => 0]);
        DB::table('order_items')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'product_variant_id' => $variant, 'product_name' => 'Pinned', 'quantity' => 1, 'unit_price' => 10, 'total' => 10]);

        // Hold the policy lock while the selected rows are temporarily absent.
        // The independent application must wait, never observe that as all.
        DB::beginTransaction();
        DB::table('discounts')->where('id', $discount)->lockForUpdate()->first();
        DB::table('discount_product_target_variants')->where('discount_id', $discount)->delete();
        $worker = $this->worker($database, $token, "/api/v1/orders/$order/discounts/apply", 'POST', ['discountId' => $discount]);
        try {
            $this->assertBlockedOnPolicy($worker);
            $parent = DB::table('discount_targets')->where('discount_id', $discount)->where('target_type', 'product')->value('id');
            DB::table('discount_product_target_variants')->insert(['tenant_id' => $tenant, 'discount_id' => $discount, 'product_id' => $product, 'discount_target_id' => $parent, 'product_variant_id' => $sibling]);
            DB::commit();
            $result = $this->finish($worker);
            $this->assertSame(422, $result['status']);
            $this->assertSame('DISCOUNT_ITEMS_NOT_ELIGIBLE', $result['body']['code']);
            $this->assertDatabaseCount('order_discounts', 0);
        } finally {
            if (DB::transactionLevel()) {
                DB::rollBack();
            }
            $this->terminate($worker);
        }

        // A legacy update must read preserved selections AFTER obtaining the lock.
        unset($payload['productVariantSelections']);
        DB::beginTransaction();
        DB::table('discounts')->where('id', $discount)->lockForUpdate()->first();
        DB::table('discount_product_target_variants')->where('discount_id', $discount)->update(['product_variant_id' => $variant]);
        $worker = $this->worker($database, $token, "/api/v1/discounts/$discount", 'PUT', $payload);
        try {
            $this->assertBlockedOnPolicy($worker);
            DB::commit();
            $result = $this->finish($worker);
            $this->assertSame(200, $result['status']);
            $this->assertSame([$variant], $result['body']['data']['productVariantSelections'][0]['variantIds']);
        } finally {
            if (DB::transactionLevel()) {
                DB::rollBack();
            }
            $this->terminate($worker);
        }
    }

    private function worker(string $database, string $token, string $path, string $method, array $data): array
    {
        $name = uniqid('discount-worker-');
        $payload = ['workerName' => $name, 'token' => $token, 'path' => $path, 'method' => $method, 'data' => $data];
        $env = array_merge(getenv() ?: [], ['APP_ENV' => 'testing', 'DB_CONNECTION' => 'pgsql', 'DB_DATABASE' => $database, 'DB_URL' => '']);
        $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/DiscountVariantWorker.php'), base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
        $this->assertIsResource($process);

        return compact('name', 'process', 'pipes');
    }

    public function test_additive_migration_preserves_legacy_targets_and_paid_snapshots(): void
    {
        $this->assertSame('cafe_system_618_testing_migrations', DB::selectOne('select current_database() as name')->name);
        $migration = require database_path('migrations/2026_10_01_000001_create_discount_product_target_variants.php');
        $migration->down();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Legacy', 'slug' => uniqid('legacy-')]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch', 'is_active' => true]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Legacy product', 'is_active' => true]);
        $discount = DB::table('discounts')->insertGetId(['tenant_id' => $tenant, 'name' => 'Legacy policy', 'application_mode' => 'manual', 'scope' => 'product', 'type' => 'percentage', 'value' => 10, 'is_active' => true]);
        $target = DB::table('discount_targets')->insertGetId(['tenant_id' => $tenant, 'discount_id' => $discount, 'target_type' => 'product', 'target_id' => $product]);
        $order = DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'order_number' => 'OLD-PAID', 'type' => 'takeaway', 'status' => 'paid', 'payment_status' => 'paid', 'subtotal' => '0.10', 'discount_total' => '0.01', 'total' => '0.09', 'tax_rate' => 0]);
        DB::table('order_items')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'product_variant_id' => null, 'product_name' => 'Historical', 'quantity' => 1, 'unit_price' => '0.10', 'total' => '0.10']);
        DB::table('order_discounts')->insert(['tenant_id' => $tenant, 'order_id' => $order, 'discount_id' => $discount, 'discount_name' => 'Old snapshot', 'discount_type' => 'percentage', 'discount_value' => 10, 'discount_amount' => '0.01']);
        $before = [(array) DB::table('orders')->find($order), (array) DB::table('order_items')->where('order_id', $order)->first(), (array) DB::table('order_discounts')->where('order_id', $order)->first(), (array) DB::table('discount_targets')->find($target)];
        $migration->up();
        $after = [(array) DB::table('orders')->find($order), (array) DB::table('order_items')->where('order_id', $order)->first(), (array) DB::table('order_discounts')->where('order_id', $order)->first(), (array) DB::table('discount_targets')->find($target)];
        $this->assertSame($before, $after);
        $this->assertDatabaseCount('discount_product_target_variants', 0);
        $this->getJson("/api/v1/discounts/$discount", ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)])->assertOk()->assertJsonPath('data.productVariantSelections.0.variantMode', 'all');
    }

    private function assertBlockedOnPolicy(array $worker): void
    {
        $deadline = microtime(true) + 15;
        do {
            // Statistics snapshots are cached inside a PostgreSQL transaction.
            DB::select('select pg_stat_clear_snapshot()');
            $state = DB::table('pg_stat_activity')->where('datname', DB::raw('current_database()'))->where('application_name', $worker['name'])->first();
            if ($state && $state->wait_event_type === 'Lock') {
                $this->assertStringContainsString('discounts', $state->query);
                $this->assertStringContainsString('for update', strtolower($state->query));

                return;
            }
            if (! proc_get_status($worker['process'])['running']) {
                $this->fail('Worker exited before the lock: '.stream_get_contents($worker['pipes'][1]).stream_get_contents($worker['pipes'][2]));
            }
            usleep(10000);
        } while (microtime(true) < $deadline);
        $this->fail('The independent worker did not reach the policy row lock.');
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
