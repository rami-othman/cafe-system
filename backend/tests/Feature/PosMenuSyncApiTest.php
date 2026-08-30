<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PosMenuSyncApiTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();

        parent::tearDown();
    }

    public function test_no_publication_is_a_successful_business_state(): void
    {
        [$tenant, $branch] = $this->scope('no-publication');

        $this->getJson('/api/v1/pos/menu-sync?branchId='.$branch, $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.context.branchId', $branch)->assertJsonPath('data.context.channel', 'pos')
            ->assertJsonPath('data.upToDate', false)->assertJsonPath('data.version', null)->assertJsonPath('data.menu', null)->assertJsonPath('data.runtime', null);
    }

    public function test_sync_projects_only_the_published_snapshot_and_refreshes_operational_runtime(): void
    {
        [$tenant, $branch] = $this->scope('snapshot');
        [, $variant] = $this->catalog($tenant);
        $payload = $this->payload($branch);
        $payload['menus'][0]['sections'][0]['products'][0]['productId'] = $variant['productId'];
        $payload['menus'][0]['sections'][0]['products'][0]['variants'][0]['id'] = $variant['variantId'];
        $version = $this->version($tenant, $branch, $payload);

        $this->getJson('/api/v1/pos/menu-sync?branchId='.$branch, $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.upToDate', false)->assertJsonPath('data.version.id', $version)
            ->assertJsonPath('data.version.sourceSchemaVersion', 3)->assertJsonPath('data.version.runtimeContractVersion', 1)
            ->assertJsonPath('data.menu.menus.0.name.default', 'Breakfast')->assertJsonPath('data.menu.menus.0.sections.0.products.0.variants.0.effectivePrice', '4.50')
            ->assertJsonPath('data.runtime.variants.0.isSellable', true)->assertJsonMissingPath('data.menu.menus.0.availabilityRules');

        DB::table('product_variant_operational_availabilities')->insert(['tenant_id' => $tenant, 'product_variant_id' => $variant['variantId'], 'branch_id' => $branch, 'channel' => 'pos', 'status' => 'sold_out', 'reason' => 'Sold out today', 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/v1/pos/menu-sync?branchId='.$branch.'&knownVersionId='.$version, $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.upToDate', true)->assertJsonPath('data.menu', null)
            ->assertJsonPath('data.runtime.variants.0.isOperationallyAvailable', false)->assertJsonPath('data.runtime.variants.0.isSellable', false)
            ->assertJsonPath('data.runtime.variants.0.operationalStatus', 'sold_out');
    }

    public function test_v2_maps_to_runtime_contract_one_and_unknown_schemas_fail_safely(): void
    {
        [$tenant, $branch] = $this->scope('v2');
        $version = $this->version($tenant, $branch, $this->payload($branch, 2));
        $this->getJson('/api/v1/pos/menu-sync?branchId='.$branch, $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.version.id', $version)->assertJsonPath('data.version.sourceSchemaVersion', 2)
            ->assertJsonPath('data.menu.menus.0.scopeOrder', 0);

        DB::table('published_menu_versions')->where('id', $version)->update(['payload_json' => json_encode(['context' => ['schemaVersion' => 99], 'menus' => []])]);
        $this->getJson('/api/v1/pos/menu-sync?branchId='.$branch, $this->headers($tenant))
            ->assertStatus(409)->assertJsonPath('code', 'UNSUPPORTED_MENU_SNAPSHOT_SCHEMA');
    }

    public function test_a_stale_known_version_receives_the_new_current_static_projection(): void
    {
        [$tenant, $branch] = $this->scope('new-version');
        $old = $this->version($tenant, $branch, $this->payload($branch));
        DB::table('published_menu_versions')->where('id', $old)->update(['status' => 'superseded']);
        $payload = $this->payload($branch);
        $payload['menus'][0]['name'] = ['default' => 'Afternoon'];
        $current = $this->version($tenant, $branch, $payload, 2);

        $this->getJson('/api/v1/pos/menu-sync?branchId='.$branch.'&knownVersionId='.$old, $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.upToDate', false)->assertJsonPath('data.version.id', $current)
            ->assertJsonPath('data.menu.menus.0.name.default', 'Afternoon');
    }

    public function test_published_overnight_rules_are_evaluated_and_tenants_are_isolated(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-31 01:00:00', 'Asia/Damascus'));
        [$tenant, $branch] = $this->scope('overnight');
        $payload = $this->payload($branch);
        $payload['menus'][0]['availabilityRules'] = [['id' => 91, 'branchId' => $branch, 'channel' => 'pos', 'dayOfWeek' => 0, 'startTime' => '22:00:00', 'endTime' => '02:00:00', 'startDate' => null, 'endDate' => null, 'priority' => 0]];
        $this->version($tenant, $branch, $payload);
        $this->getJson('/api/v1/pos/menu-sync?branchId='.$branch, $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.runtime.menus.0.isScheduledAvailable', true)->assertJsonPath('data.runtime.menus.0.reason', 'matched_rule');

        [, $foreignBranch] = $this->scope('foreign');
        $this->getJson('/api/v1/pos/menu-sync?branchId='.$foreignBranch, $this->headers($tenant))
            ->assertUnprocessable()->assertJsonValidationErrors('branchId');
    }

    private function scope(string $slug): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Central', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return [$tenant, $branch];
    }

    private function version(int $tenant, int $branch, array $payload, int $number = 1): int
    {
        $publication = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_at' => now(), 'created_at' => now(), 'updated_at' => now()]);

        return DB::table('published_menu_versions')->insertGetId(['tenant_id' => $tenant, 'menu_publication_id' => $publication, 'branch_id' => $branch, 'channel' => 'pos', 'version_number' => $number, 'payload_json' => json_encode($payload), 'checksum' => str_repeat((string) $number, 64), 'status' => 'current', 'published_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
    }

    private function catalog(int $tenant): array
    {
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Latte', 'price' => 4, 'cost_price' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => 4, 'cost_price' => 1, 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return [$product, ['productId' => $product, 'variantId' => $variant]];
    }

    private function payload(int $branch, int $schema = 3): array
    {
        return ['context' => ['schemaVersion' => $schema], 'menus' => [[
            'id' => 10, 'scopeOrder' => 0, 'name' => ['default' => 'Breakfast', 'ar' => 'فطور', 'en' => 'Breakfast'], 'description' => ['default' => 'Published only'], 'availabilityRules' => [],
            'sections' => [['id' => 20, 'name' => ['default' => 'Coffee'], 'description' => null, 'sortOrder' => 0, 'products' => [[
                'placementId' => 40, 'productId' => 25, 'name' => ['default' => 'Latte'], 'description' => ['default' => 'Published description'], 'imageUrl' => null, 'sortOrder' => 0, 'isFeatured' => false, 'isVisible' => true, 'productAvailabilityRules' => [],
                'variants' => [['id' => 30, 'name' => ['default' => 'Regular'], 'sku' => 'LATTE-R', 'barcode' => null, 'sortOrder' => 0, 'isDefault' => true, 'basePrice' => '4.00', 'effectivePrice' => '4.50']], 'modifierGroups' => [],
            ]]]],
        ]]];
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
