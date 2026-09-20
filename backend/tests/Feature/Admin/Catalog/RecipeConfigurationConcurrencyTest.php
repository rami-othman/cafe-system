<?php

namespace Tests\Feature\Admin\Catalog;

use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use PDO;
use RuntimeException;
use Tests\TestCase;

class RecipeConfigurationConcurrencyTest extends TestCase
{
    use DatabaseMigrations;

    protected function setUp(): void
    {
        parent::setUp();

        $this->assertSame('pgsql', config('database.default'));
        $this->assertSame('cafe_system_618_testing', config('database.connections.pgsql.database'));
    }

    public function test_competing_first_replace_requests_leave_one_complete_parent_and_do_not_cross_tenants(): void
    {
        [$tenant, $product, $variant, $firstMaterial, $secondMaterial] = $this->graph('concurrent-first-replace');
        [$foreignTenant, $foreignProduct] = $this->foreignGraph();

        $results = $this->runConcurrently([
            ['tenantId' => $tenant, 'variantId' => $variant, 'mode' => 'replace', 'materialId' => $firstMaterial, 'quantity' => '18'],
            ['tenantId' => $tenant, 'variantId' => $variant, 'mode' => 'replace', 'materialId' => $secondMaterial, 'quantity' => '25'],
        ]);

        $this->assertCount(2, $results);
        $this->assertNotEmpty(array_filter($results, fn (array $result): bool => $result['ok']));
        $this->assertSame(1, DB::table('product_variants')->where('id', $variant)->count());
        $parents = DB::table('variant_recipes')->where('tenant_id', $tenant)->where('product_variant_id', $variant)->get();
        $this->assertCount(1, $parents);
        $components = DB::table('variant_recipe_components')->where('tenant_id', $tenant)->where('variant_recipe_id', $parents->first()->id)->get();
        $this->assertCount(1, $components);
        $this->assertContains((int) $components->first()->inventory_item_id, [$firstMaterial, $secondMaterial]);
        $this->assertContains((string) $components->first()->quantity, ['18.000000', '25.000000']);
        $this->assertSame(0, DB::table('variant_recipes')->where('tenant_id', $foreignTenant)->where('product_variant_id', $foreignProduct)->count());
    }

    public function test_replace_and_clear_converge_to_absence_or_one_complete_recipe(): void
    {
        [$tenant, $product, $variant, $firstMaterial, $secondMaterial] = $this->graph('concurrent-replace-clear');
        app(\App\Services\Catalog\RecipeConfigurationService::class)->replaceRecipe(
            \App\Models\ProductVariant::findOrFail($variant),
            [['materialId' => $firstMaterial, 'quantity' => '10', 'unitCode' => 'g']],
        );

        $results = $this->runConcurrently([
            ['tenantId' => $tenant, 'variantId' => $variant, 'mode' => 'replace', 'materialId' => $secondMaterial, 'quantity' => '20'],
            ['tenantId' => $tenant, 'variantId' => $variant, 'mode' => 'clear', 'materialId' => $secondMaterial, 'quantity' => '20'],
        ]);

        $this->assertCount(2, array_filter($results, fn (array $result): bool => $result['ok']));
        $parents = DB::table('variant_recipes')->where('tenant_id', $tenant)->where('product_variant_id', $variant)->get();
        $this->assertLessThanOrEqual(1, $parents->count());
        if ($parents->isEmpty()) {
            $this->assertSame(0, DB::table('variant_recipe_components')->where('tenant_id', $tenant)->whereIn('variant_recipe_id', $parents->pluck('id'))->count());
        } else {
            $components = DB::table('variant_recipe_components')->where('tenant_id', $tenant)->where('variant_recipe_id', $parents->first()->id)->get();
            $this->assertCount(1, $components);
            $this->assertSame($secondMaterial, (int) $components->first()->inventory_item_id);
            $this->assertSame('20.000000', (string) $components->first()->quantity);
        }
        $this->assertSame(0, DB::table('variant_recipes')->where('tenant_id', $tenant)->where('product_variant_id', $variant)->whereNotExists(function ($query): void {
            $query->selectRaw('1')->from('variant_recipe_components')->whereColumn('variant_recipe_components.variant_recipe_id', 'variant_recipes.id');
        })->count());
    }

    /** @return list<array{ok: bool, result?: array, message?: string}> */
    private function runConcurrently(array $payloads): array
    {
        $barrier = random_int(1, PHP_INT_MAX);
        DB::select('select pg_advisory_lock(?)', [$barrier]);
        $workers = [];

        try {
            foreach ($payloads as $payload) {
                $payload['barrier'] = $barrier;
                $pipes = [];
                $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/ConcurrentRecipeConfigurationWorker.php'), base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path());
                if (! is_resource($process)) {
                    throw new RuntimeException('Could not start concurrent recipe worker.');
                }
                $workers[] = compact('process', 'pipes');
            }

            $this->waitForBarrierWorkers(count($workers));
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
                    throw new RuntimeException("Concurrent recipe worker did not return JSON (exit {$exit}): {$stderr}");
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

    private function waitForBarrierWorkers(int $expected): void
    {
        $deadline = microtime(true) + 10;
        do {
            $waiting = (int) DB::table('pg_stat_activity')
                ->where('datname', DB::raw('current_database()'))
                ->where('wait_event_type', 'Lock')
                ->where('wait_event', 'advisory')
                ->whereRaw("query ilike '%pg_advisory_lock%'")
                ->count();
            if ($waiting >= $expected) {
                return;
            }
            usleep(10_000);
        } while (microtime(true) < $deadline);

        throw new RuntimeException("Only {$waiting} of {$expected} workers reached the PostgreSQL start barrier.");
    }

    /** @return array{int, int, int, int, int} */
    private function graph(string $slug): array
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug.'-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => $slug, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => $slug, 'price' => 4, 'cost_price' => 1, 'is_active' => true, 'is_stock_tracked' => true, 'created_at' => $now, 'updated_at' => $now]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => 4, 'cost_price' => 1, 'is_default' => true, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $firstMaterial = $this->material($tenant, $slug.'-first');
        $secondMaterial = $this->material($tenant, $slug.'-second');

        return [$tenant, $product, $variant, $firstMaterial, $secondMaterial];
    }

    /** @return array{int, int} */
    private function foreignGraph(): array
    {
        [$tenant, $product, $variant] = array_slice($this->graph('concurrent-foreign'), 0, 3);

        return [$tenant, $product];
    }

    private function material(int $tenant, string $sku): int
    {
        return DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => $sku, 'sku' => $sku, 'item_type' => 'other', 'unit' => 'gram', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }
}
