<?php

namespace Tests\Feature\Customer;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerSearchPaginationTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_search_is_bounded_stable_and_status_filtered_with_camel_case_meta(): void
    {
        [$tenant, $token] = $this->admin();
        for ($i = 1; $i <= 35; $i++) {
            $name = sprintf('Customer %02d', 36 - $i);
            DB::table('customers')->insert(['tenant_id' => $tenant, 'name' => $name, 'customer_number' => 'C-'.str_pad((string) $i, 6, '0', STR_PAD_LEFT), 'normalized_name' => strtolower($name), 'is_active' => $i % 3 !== 0, 'deleted_at' => $i === 35 ? now() : null, 'created_at' => now(), 'updated_at' => now()]);
        }
        $response = $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers?perPage=30')->assertOk();
        $response->assertJsonPath('meta.currentPage', 1)->assertJsonPath('meta.perPage', 30)->assertJsonPath('meta.total', 34)->assertJsonPath('meta.lastPage', 2);
        $this->assertCount(30, $response->json('data'));
        $names = collect($response->json('data'))->pluck('name')->all();
        $this->assertSame($names, collect($names)->sort()->values()->all());
        $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers?status=archived')->assertOk()->assertJsonPath('meta.total', 1);
    }

    public function test_search_matches_normalized_name_phone_email_and_escapes_wildcards(): void
    {
        [$tenant, $token] = $this->admin();
        $id = DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => 'أَحْمَد', 'customer_number' => 'C-010001', 'normalized_name' => 'احمد', 'phone' => '091234567', 'email' => 'literal%mail@example.test', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('customer_phones')->insert(['tenant_id' => $tenant, 'customer_id' => $id, 'raw_number' => '091234567', 'normalized_number' => '091234567', 'is_primary' => true, 'type' => 'mobile', 'validation_status' => 'unverified', 'created_at' => now(), 'updated_at' => now()]);
        $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers?search=احمد')->assertOk()->assertJsonPath('meta.total', 1);
        $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers?search=091234')->assertOk()->assertJsonPath('meta.total', 1);
        $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers?search=0912%20345-67')->assertOk()->assertJsonPath('meta.total', 1);
        $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers?search=_')->assertOk()->assertJsonPath('meta.total', 0);
    }

    public function test_opt_in_100k_query_plan_benchmark(): void
    {
        if (env('RUN_CUSTOMER_PERF_BENCHMARK') !== '1') {
            $this->markTestSkipped('Set RUN_CUSTOMER_PERF_BENCHMARK=1 to run the 100,000-row PostgreSQL customer benchmark.');
        }
        [$tenant, $token] = $this->admin();
        DB::statement("INSERT INTO customers (tenant_id, name, customer_number, normalized_name, is_active, created_at, updated_at) SELECT ?, 'Benchmark Customer ' || series, 'C-' || lpad(series::text, 6, '0'), 'benchmark customer ' || series, true, now(), now() FROM generate_series(1, 100000) AS series", [$tenant]);
        DB::statement('ANALYZE customers');

        $operationalSamples = $this->measure(20, fn () => $this->withToken($token)->getJson('/api/v1/customers?search=Benchmark%20Customer%209999')->assertOk());
        $administrativeSamples = $this->measure(20, fn () => $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers?search=Benchmark%20Customer%209999')->assertOk());
        $plan = json_encode(DB::select('EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT id FROM customers WHERE tenant_id = ? AND is_active = true AND deleted_at IS NULL ORDER BY normalized_name, id LIMIT 30', [$tenant]));
        $operationalP95 = $this->p95($operationalSamples);
        $administrativeP95 = $this->p95($administrativeSamples);
        fwrite(STDOUT, sprintf("\n100k customer benchmark p95: operational=%.2f ms, administrative=%.2f ms\n", $operationalP95, $administrativeP95));

        $this->assertLessThanOrEqual(200.0, $operationalP95, 'Operational lookup p95 exceeded 200 ms.');
        $this->assertLessThanOrEqual(300.0, $administrativeP95, 'Administrative search p95 exceeded 300 ms.');
        $this->assertStringContainsString('Index', $plan);
        $this->assertStringNotContainsString('Seq Scan', $plan);
    }

    private function measure(int $runs, callable $operation): array
    {
        $samples = [];
        for ($i = 0; $i < $runs; $i++) {
            $started = hrtime(true);
            $operation();
            $samples[] = (hrtime(true) - $started) / 1_000_000;
        }

        return $samples;
    }

    private function p95(array $samples): float
    {
        sort($samples, SORT_NUMERIC);

        return $samples[(int) ceil(count($samples) * 0.95) - 1];
    }

    private function admin(): array
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Search Tenant', 'slug' => 'search-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $owner = User::query()->create(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true, 'must_change_password' => false]);

        return [$tenant, $this->authenticateTenantUser($tenant, $owner)];
    }
}
