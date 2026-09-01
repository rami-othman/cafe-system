<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SnapshotAwarePosOrderApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_snapshot_order_uses_published_prices_and_persists_version_variant_and_placement(): void
    {
        $scope = $this->scope();
        $response = $this->postOrder($scope, $scope['version'], ['unitPrice' => 99999, 'lineTotal' => 99999]);

        $response->assertCreated()
            ->assertJsonPath('data.publishedMenuVersionId', $scope['version'])
            ->assertJsonPath('data.items.0.unitPrice', 6.5)
            ->assertJsonPath('data.items.0.lineTotal', 13)
            ->assertJsonPath('data.items.0.variantId', $scope['variant'])
            ->assertJsonPath('data.items.0.placementId', $scope['placement']);
        $this->assertDatabaseHas('orders', ['id' => $response->json('data.id'), 'published_menu_version_id' => $scope['version']]);
        $this->assertDatabaseHas('order_items', ['order_id' => $response->json('data.id'), 'product_variant_id' => $scope['variant'], 'menu_item_placement_id' => $scope['placement'], 'unit_price' => 6.5, 'total' => 13]);
        $this->assertDatabaseHas('order_item_modifiers', ['order_item_id' => $response->json('data.items.0.id'), 'modifier_option_id' => $scope['option'], 'price_delta' => 1.5]);

        // Draft Catalog mutations after publish cannot leak into the order path.
        DB::table('products')->where('id', $scope['product'])->update(['price' => 70]);
        DB::table('product_variants')->where('id', $scope['variant'])->update(['base_price' => 70]);
        DB::table('modifier_options')->where('id', $scope['option'])->update(['price_delta' => 20]);
        $this->postOrder($scope, $scope['version'])->assertCreated()
            ->assertJsonPath('data.items.0.unitPrice', 6.5)
            ->assertJsonPath('data.items.0.lineTotal', 13);
    }

    public function test_new_order_rejects_a_stale_version_but_existing_pinned_order_keeps_its_price(): void
    {
        $scope = $this->scope();
        $oldOrder = $this->postOrder($scope, $scope['version'])->assertCreated();
        DB::table('published_menu_versions')->where('id', $scope['version'])->update(['status' => 'superseded']);
        $newVersion = $this->version($scope, '6.00', 2);

        $this->postOrder($scope, $scope['version'])->assertUnprocessable()
            ->assertJsonValidationErrors('publishedMenuVersionId');
        $this->postOrder($scope, $newVersion)->assertCreated()->assertJsonPath('data.items.0.unitPrice', 7.5);

        $this->postJson('/api/v1/orders/'.$oldOrder->json('data.id').'/items', $this->line($scope, 1), $this->headers($scope))
            ->assertCreated()->assertJsonPath('data.publishedMenuVersionId', $scope['version'])
            ->assertJsonPath('data.items.1.unitPrice', 6.5);
    }

    public function test_snapshot_order_rejects_invalid_membership_required_modifier_and_live_sold_out(): void
    {
        $scope = $this->scope();
        $missingModifier = $this->line($scope);
        $missingModifier['modifierOptionIds'] = [];
        $this->postOrder($scope, $scope['version'], [], $missingModifier)->assertUnprocessable()->assertJsonValidationErrors('modifierOptionIds');

        $wrongVariant = $this->line($scope);
        $wrongVariant['variantId'] = 999999;
        $this->postOrder($scope, $scope['version'], [], $wrongVariant)->assertUnprocessable()->assertJsonValidationErrors('variantId');

        DB::table('product_variant_operational_availabilities')->insert([
            'tenant_id' => $scope['tenant'], 'product_variant_id' => $scope['variant'], 'branch_id' => $scope['branch'], 'channel' => 'pos',
            'status' => 'sold_out', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->postOrder($scope, $scope['version'])->assertUnprocessable()->assertJsonValidationErrors('items');
    }

    public function test_snapshot_version_is_tenant_scoped_and_uses_its_frozen_schedule(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-30 12:00:00', 'Asia/Damascus'));
        $tenantA = $this->scope();
        $tenantB = $this->scope();
        $this->postOrder($tenantA, $tenantB['version'])->assertUnprocessable()
            ->assertJsonValidationErrors('publishedMenuVersionId');

        $payload = json_decode((string) DB::table('published_menu_versions')->where('id', $tenantA['version'])->value('payload_json'), true);
        $payload['menus'][0]['sections'][0]['products'][0]['productAvailabilityRules'] = [[
            'id' => 77, 'branchId' => $tenantA['branch'], 'channel' => 'pos', 'productVariantId' => null,
            'dayOfWeek' => 1, 'startTime' => null, 'endTime' => null, 'startDate' => null, 'endDate' => null, 'priority' => 0,
        ]];
        DB::table('published_menu_versions')->where('id', $tenantA['version'])->update(['payload_json' => json_encode($payload)]);
        $this->postOrder($tenantA, $tenantA['version'])->assertUnprocessable()->assertJsonValidationErrors('items');
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();

        parent::tearDown();
    }

    private function postOrder(array $scope, int $version, array $extra = [], ?array $line = null)
    {
        return $this->postJson('/api/v1/orders', [
            'branchId' => $scope['branch'], 'orderType' => 'takeaway', 'publishedMenuVersionId' => $version,
            'items' => [array_merge($line ?? $this->line($scope), $extra)],
        ], $this->headers($scope));
    }

    private function line(array $scope, int $quantity = 2): array
    {
        return ['productId' => $scope['product'], 'placementId' => $scope['placement'], 'variantId' => $scope['variant'], 'quantity' => $quantity, 'modifierOptionIds' => [$scope['option']]];
    }

    private function scope(): array
    {
        $now = now();
        $slug = 'snapshot-'.uniqid();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Snapshot cafe', 'slug' => $slug, 'created_at' => $now, 'updated_at' => $now]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Central', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Live Latte', 'price' => 5, 'cost_price' => 1, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => 5, 'cost_price' => 1, 'is_default' => true, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'created_at' => $now, 'updated_at' => $now]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Hot', 'created_at' => $now, 'updated_at' => $now]);
        $placement = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'created_at' => $now, 'updated_at' => $now]);
        $group = DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenant, 'name' => 'Milk', 'selection_type' => 'single', 'group_type' => 'choice', 'is_required' => true, 'min_selections' => 1, 'max_selections' => 1, 'allow_quantity' => false, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $option = DB::table('modifier_options')->insertGetId(['tenant_id' => $tenant, 'modifier_group_id' => $group, 'name' => 'Oat', 'price_delta' => 1.5, 'cost_delta' => 0, 'is_default' => false, 'is_active' => true, 'is_available' => true, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $product, 'modifier_group_id' => $group, 'created_at' => $now, 'updated_at' => $now]);
        $scope = compact('tenant', 'branch', 'product', 'variant', 'placement', 'group', 'option');
        $scope['version'] = $this->version($scope, '5.00', 1);

        return $scope;
    }

    private function version(array $scope, string $price, int $number): int
    {
        $now = now();
        $publication = DB::table('menu_publications')->insertGetId(['tenant_id' => $scope['tenant'], 'status' => 'published', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $payload = [
            'context' => ['schemaVersion' => 3],
            'menus' => [[
                'id' => 1,
                'availabilityRules' => [],
                'sections' => [[
                    'id' => 1,
                    'products' => [[
                        'placementId' => $scope['placement'],
                        'productId' => $scope['product'],
                        'name' => ['default' => 'Published Latte'],
                        'isVisible' => true,
                        'productAvailabilityRules' => [],
                        'variants' => [['id' => $scope['variant'], 'name' => ['default' => 'Regular'], 'effectivePrice' => $price]],
                        'modifierGroups' => [[
                            'id' => $scope['group'], 'name' => ['default' => 'Milk'], 'selectionType' => 'single',
                            'isRequired' => true, 'minSelections' => 1, 'maxSelections' => 1,
                            'options' => [['id' => $scope['option'], 'name' => ['default' => 'Oat'], 'priceDelta' => '1.50', 'isAvailable' => true]],
                        ]],
                    ]],
                ]],
            ]],
        ];

        return DB::table('published_menu_versions')->insertGetId(['tenant_id' => $scope['tenant'], 'menu_publication_id' => $publication, 'branch_id' => $scope['branch'], 'channel' => 'pos', 'version_number' => $number, 'payload_json' => json_encode($payload), 'checksum' => str_repeat((string) $number, 64), 'status' => 'current', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
    }

    private function headers(array $scope): array
    {
        return ['Authorization' => 'Bearer '.$this->authenticateTenantUser($scope['tenant'])];
    }
}
