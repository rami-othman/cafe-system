<?php

namespace Tests\Feature;

use App\Services\Menu\MenuValidationService;
use App\Services\Menu\PublishedMenuSnapshotBuilder;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use PDO;
use RuntimeException;
use Tests\TestCase;

class MenuPublishConcurrencyTest extends TestCase
{
    use DatabaseMigrations;

    protected function setUp(): void
    {
        parent::setUp();

        $this->assertSame('pgsql', config('database.default'));
        $this->assertSame('cafe_system_618_testing', config('database.connections.pgsql.database'));
    }

    public function test_same_scope_publishers_serialize_to_one_current_version_and_one_no_change_result(): void
    {
        [$tenant, $branch] = $this->graph();

        $results = $this->runConcurrently([
            ['tenantId' => $tenant, 'input' => ['branchId' => $branch, 'channel' => 'pos']],
            ['tenantId' => $tenant, 'input' => ['branchId' => $branch, 'channel' => 'pos']],
        ]);

        $this->assertCount(2, array_filter($results, fn (array $result): bool => $result['ok']));
        $versions = collect($results)->pluck('result.version.versionNumber')->unique()->values();
        $this->assertSame([1], $versions->all());
        $this->assertCount(1, array_filter($results, fn (array $result): bool => $result['result']['published']));
        $this->assertCount(1, array_filter($results, fn (array $result): bool => $result['result']['noChanges']));
        $this->assertSame(1, DB::table('published_menu_versions')->count());
        $this->assertSame(1, DB::table('published_menu_versions')->where('status', 'current')->count());
    }

    public function test_validation_and_snapshot_share_one_repeatable_read_state_when_another_connection_edits_between_them(): void
    {
        [$tenant, $branch, $product] = $this->graph();
        $validation = app(MenuValidationService::class);
        $snapshots = app(PublishedMenuSnapshotBuilder::class);

        DB::transaction(function () use ($tenant, $branch, $product, $validation, $snapshots): void {
            DB::statement('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
            DB::select('SELECT pg_advisory_xact_lock(hashtext(?))', ["menu-publish:{$tenant}:{$branch}:pos"]);
            $scope = $validation->branch($tenant, $branch);
            $menuIds = $validation->assignedMenuIds($tenant, $branch, 'pos');
            $this->assertSame(0, $validation->validateCollection($tenant, $scope, 'pos', null, null)->toArray()['errorCount']);

            // A separate PostgreSQL connection commits a publish-relevant
            // change after validation. The open publish transaction must
            // still build from its validated snapshot, never a hybrid state.
            $this->independentConnection()->prepare('update products set is_active = false where id = ?')->execute([$product]);

            $payload = $snapshots->build($tenant, $scope, 'pos', $menuIds);
            $this->assertSame($product, $payload['menus'][0]['sections'][0]['products'][0]['productId']);
        });

        $this->assertFalse((bool) DB::table('products')->where('id', $product)->value('is_active'));
    }

    public function test_cross_scope_publishers_keep_independent_version_sequences(): void
    {
        [$tenant, $downtown] = $this->graph();
        $mall = $this->branch($tenant, 'Mall');
        DB::table('menu_assignments')->insert([
            'tenant_id' => $tenant,
            'menu_id' => DB::table('menu_assignments')->where('branch_id', $downtown)->value('menu_id'),
            'branch_id' => $mall,
            'channel' => 'pos',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('menu_assignments')->insert([
            'tenant_id' => $tenant,
            'menu_id' => DB::table('menu_assignments')->where('branch_id', $downtown)->value('menu_id'),
            'branch_id' => $downtown,
            'channel' => 'waiter_app',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $results = $this->runConcurrently([
            ['tenantId' => $tenant, 'input' => ['branchId' => $downtown, 'channel' => 'pos']],
            ['tenantId' => $tenant, 'input' => ['branchId' => $mall, 'channel' => 'pos']],
            ['tenantId' => $tenant, 'input' => ['branchId' => $downtown, 'channel' => 'waiter_app']],
        ]);

        $this->assertCount(3, array_filter($results, fn (array $result): bool => $result['ok']));
        $this->assertSame([1, 1, 1], collect($results)->pluck('result.version.versionNumber')->sort()->values()->all());
        $this->assertSame(3, DB::table('published_menu_versions')->where('status', 'current')->count());
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
                $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/ConcurrentMenuPublishWorker.php'), base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path());
                if (! is_resource($process)) {
                    throw new RuntimeException('Could not start concurrent menu publish worker.');
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
                    throw new RuntimeException("Concurrent menu worker did not return JSON (exit {$exit}): {$stderr}");
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
            $waiting = (int) DB::table('pg_stat_activity')->where('datname', DB::raw('current_database()'))->where('wait_event_type', 'Lock')->where('wait_event', 'advisory')->whereRaw("query ilike '%pg_advisory_lock%'")->count();
            if ($waiting >= $expected) {
                return;
            }
            usleep(10_000);
        } while (microtime(true) < $deadline);

        throw new RuntimeException("Only {$waiting} of {$expected} workers reached the PostgreSQL start barrier.");
    }

    private function independentConnection(): PDO
    {
        $connection = config('database.connections.pgsql');
        $pdo = new PDO("pgsql:host={$connection['host']};port={$connection['port']};dbname={$connection['database']}", $connection['username'], $connection['password'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        $pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, true);

        return $pdo;
    }

    private function graph(): array
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Alpha', 'slug' => 'alpha-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $branch = $this->branch($tenant, 'Downtown');
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Latte', 'price' => 4, 'cost_price' => 1, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('product_variants')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => 4, 'cost_price' => 1, 'is_default' => true, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'status' => 'draft', 'created_at' => $now, 'updated_at' => $now]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('menu_item_placements')->insert(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'is_visible' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('menu_assignments')->insert(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => 'pos', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);

        return [$tenant, $branch, $product];
    }

    private function branch(int $tenant, string $name): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }
}
