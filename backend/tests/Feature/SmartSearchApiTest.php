<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Application-wide smart search: Arabic/Latin normalization, typo tolerance,
 * multi-term matching, relevance ranking, full-dataset pagination, and
 * tenant isolation — exercised against the endpoints that adopted
 * App\Support\Search\SmartSearch first (products, customers, suppliers,
 * inventory items).
 */
class SmartSearchApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_arabic_normalization_matches_alef_and_diacritic_variants(): void
    {
        $tenant = $this->createTenant('search-ar');
        $headers = $this->headers($tenant);
        $this->insertProduct($tenant, 'أكواب ورقية');

        foreach (['اكواب', 'أكواب', 'أَكْوَاب', 'إكواب', 'آكواب'] as $query) {
            $this->getJson('/api/v1/menu/products?search='.urlencode($query), $headers)
                ->assertOk()
                ->assertJsonPath('data.0.name', 'أكواب ورقية');
        }
    }

    public function test_latin_case_is_ignored(): void
    {
        $tenant = $this->createTenant('search-case');
        $headers = $this->headers($tenant);
        $this->insertProduct($tenant, 'Latte');

        foreach (['LATTE', 'Latte', 'latte'] as $query) {
            $this->getJson('/api/v1/menu/products?search='.urlencode($query), $headers)
                ->assertOk()
                ->assertJsonPath('data.0.name', 'Latte');
        }
    }

    public function test_multi_word_search_matches_any_order_and_partial_tokens(): void
    {
        $tenant = $this->createTenant('search-multi');
        $headers = $this->headers($tenant);
        $this->insertProduct($tenant, 'Paper Cup 12 oz');

        foreach (['paper', '12', 'paper 12', '12 cup'] as $query) {
            $this->getJson('/api/v1/menu/products?search='.urlencode($query), $headers)
                ->assertOk()
                ->assertJsonFragment(['name' => 'Paper Cup 12 oz']);
        }
    }

    public function test_typo_tolerance_finds_near_matches(): void
    {
        $tenant = $this->createTenant('search-typo');
        $headers = $this->headers($tenant);
        $this->insertProduct($tenant, 'Cappuccino');

        $this->getJson('/api/v1/menu/products?search=Capuccino', $headers)
            ->assertOk()
            ->assertJsonFragment(['name' => 'Cappuccino']);
    }

    public function test_ranking_puts_exact_match_before_partial_matches(): void
    {
        $tenant = $this->createTenant('search-rank');
        $headers = $this->headers($tenant);
        $this->insertProduct($tenant, 'Vanilla Latte');
        $this->insertProduct($tenant, 'Latte Cup');
        $this->insertProduct($tenant, 'Latte');
        $this->insertProduct($tenant, 'Latter');

        $response = $this->getJson('/api/v1/menu/products?search=Latte', $headers)->assertOk();
        $this->assertSame('Latte', $response->json('data.0.name'));
    }

    public function test_tenant_isolation_is_never_broadened_by_search(): void
    {
        $tenantA = $this->createTenant('search-tenant-a');
        $tenantB = $this->createTenant('search-tenant-b');
        $this->insertCustomer($tenantA, 'Unique Customer Name', '0944111111');
        $this->insertCustomer($tenantB, 'Unique Customer Name', '0944222222');

        $response = $this->getJson('/api/v1/customers?search=Unique', $this->headers($tenantA))->assertOk();
        $this->assertCount(1, $response->json('data'));
        $this->assertSame('0944111111', $response->json('data.0.phone'));
    }

    public function test_search_reaches_records_beyond_the_first_page(): void
    {
        $tenant = $this->createTenant('search-paging');
        $headers = $this->headers($tenant);
        for ($i = 1; $i <= 120; $i++) {
            $this->insertSupplier($tenant, "Generic Supplier $i", 'SUP-GEN-'.str_pad((string) $i, 4, '0', STR_PAD_LEFT));
        }
        $this->insertSupplier($tenant, 'Findable Roasters', 'SUP-FIND-0001');

        $this->getJson('/api/v1/finance/suppliers?search=Findable', $headers)
            ->assertOk()
            ->assertJsonFragment(['name' => 'Findable Roasters']);
    }

    public function test_phone_search_ignores_formatting_differences(): void
    {
        $tenant = $this->createTenant('search-phone');
        $headers = $this->headers($tenant);
        $this->insertCustomer($tenant, 'Formatted Phone Customer', '+963 944 123 456');

        foreach (['0944123456', '944123456', '123456'] as $query) {
            $this->getJson('/api/v1/customers?search='.urlencode($query), $headers)
                ->assertOk()
                ->assertJsonFragment(['name' => 'Formatted Phone Customer']);
        }
    }

    public function test_empty_search_returns_normal_listing_without_error(): void
    {
        $tenant = $this->createTenant('search-empty');
        $headers = $this->headers($tenant);
        $this->insertProduct($tenant, 'Anything');

        $this->getJson('/api/v1/menu/products', $headers)->assertOk();
    }

    private function insertProduct(int $tenant, string $name): int
    {
        return (int) DB::table('products')->insertGetId([
            'tenant_id' => $tenant,
            'name' => $name,
            'price' => 10,
            'is_active' => true,
            'sort_order' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertCustomer(int $tenant, string $name, string $phone): int
    {
        return (int) DB::table('customers')->insertGetId([
            'tenant_id' => $tenant,
            'name' => $name,
            'phone' => $phone,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertSupplier(int $tenant, string $name, string $number): int
    {
        return (int) DB::table('suppliers')->insertGetId([
            'tenant_id' => $tenant,
            'supplier_number' => $number,
            'name' => $name,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function createTenant(string $slug): int
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Central Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return (int) $tenantId;
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Search Owner', 'email' => "search-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $plainToken = "search-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'search-feature-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken"];
    }
}
