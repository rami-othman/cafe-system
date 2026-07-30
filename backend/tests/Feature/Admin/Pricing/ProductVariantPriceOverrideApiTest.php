<?php

namespace Tests\Feature\Admin\Pricing;

use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ProductVariantPriceOverrideApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_tenant_scoped_listing_and_all_valid_scopes(): void
    {
        $tenantId = $this->tenant('alpha');
        $variantId = $this->variant($tenantId, 'Latte', 4);
        $branchId = $this->branch($tenantId);
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [
            ['scopeType' => 'branch', 'branchId' => $branchId, 'channel' => null, 'overridePrice' => 4.5],
            ['scopeType' => 'channel', 'branchId' => null, 'channel' => 'delivery', 'overridePrice' => 4.75],
            ['scopeType' => 'branch_channel', 'branchId' => $branchId, 'channel' => 'delivery', 'overridePrice' => 5, 'isActive' => true],
        ]], $this->headers($tenantId))->assertOk()->assertJsonPath('data.variantId', $variantId)->assertJsonCount(3, 'data.overrides');

        $this->getJson($this->overridesUrl($variantId), $this->headers($tenantId))
            ->assertOk()
            ->assertJsonPath('data.basePrice', 4)
            ->assertJsonPath('data.overrides.0.scopeType', 'branch');
        $this->assertDatabaseHas('product_variant_price_overrides', ['product_variant_id' => $variantId, 'scope_key' => "branch:{$branchId}|channel:*"]);
        $this->assertDatabaseHas('menu_audit_logs', ['tenant_id' => $tenantId, 'action' => 'synchronized', 'menu_publication_id' => null]);

        $otherTenantId = $this->tenant('beta');
        $this->getJson($this->overridesUrl($variantId), $this->headers($otherTenantId))->assertNotFound();
        $this->putJson($this->overridesUrl($variantId), ['overrides' => []], $this->headers($otherTenantId))->assertNotFound();
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [[
            'scopeType' => 'branch', 'branchId' => $this->branch($this->tenant('gamma')), 'overridePrice' => 7,
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('overrides.0.branchId');
    }

    public function test_scope_and_input_validation_rejects_invalid_or_duplicate_submissions(): void
    {
        $tenantId = $this->tenant('alpha');
        $variantId = $this->variant($tenantId, 'Tea', 3);
        $branchId = $this->branch($tenantId);

        $this->putJson($this->overridesUrl($variantId), ['overrides' => [[
            'scopeType' => 'branch', 'branchId' => $branchId, 'channel' => 'delivery', 'overridePrice' => 3,
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('overrides.0.scopeType');
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [[
            'scopeType' => 'channel', 'channel' => 'unknown', 'overridePrice' => 3,
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('overrides.0.channel');
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [[
            'scopeType' => 'channel', 'channel' => 'delivery', 'overridePrice' => -1,
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('overrides.0.overridePrice');
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [[
            'scopeType' => 'channel', 'channel' => 'delivery', 'overridePrice' => 3, 'scopeKey' => 'forbidden',
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('overrides.0.scopeKey');
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [
            ['scopeType' => 'branch', 'branchId' => $branchId, 'overridePrice' => 3],
            ['scopeType' => 'branch', 'branchId' => $branchId, 'overridePrice' => 4],
        ]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('overrides.1.scopeType');
        DB::table('branches')->where('id', $branchId)->update(['deleted_at' => now()]);
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [[
            'scopeType' => 'branch', 'branchId' => $branchId, 'overridePrice' => 3,
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('overrides.0.branchId');
    }

    public function test_synchronization_updates_archives_restores_and_preserves_database_uniqueness(): void
    {
        $tenantId = $this->tenant('alpha');
        $variantId = $this->variant($tenantId, 'Mocha', 4);
        $branchId = $this->branch($tenantId);
        $payload = ['scopeType' => 'branch', 'branchId' => $branchId, 'overridePrice' => 4.5];
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [$payload]], $this->headers($tenantId))->assertOk();
        $overrideId = DB::table('product_variant_price_overrides')->where('product_variant_id', $variantId)->value('id');
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [array_replace($payload, ['overridePrice' => 5])]], $this->headers($tenantId))->assertOk();
        $this->assertDatabaseHas('product_variant_price_overrides', ['id' => $overrideId, 'override_price' => 5, 'deleted_at' => null]);
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [
            array_replace($payload, ['overridePrice' => 8]),
            ['scopeType' => 'branch', 'branchId' => $this->branch($this->tenant('foreign')), 'overridePrice' => 9],
        ]], $this->headers($tenantId))->assertUnprocessable();
        $this->assertDatabaseHas('product_variant_price_overrides', ['id' => $overrideId, 'override_price' => 5, 'deleted_at' => null]);

        $this->putJson($this->overridesUrl($variantId), ['overrides' => []], $this->headers($tenantId))->assertOk()->assertJsonCount(0, 'data.overrides');
        $this->assertSoftDeleted('product_variant_price_overrides', ['id' => $overrideId]);
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [$payload]], $this->headers($tenantId))->assertOk();
        $this->assertDatabaseHas('product_variant_price_overrides', ['id' => $overrideId, 'deleted_at' => null, 'override_price' => 4.5]);

        $this->expectException(UniqueConstraintViolationException::class);
        DB::table('product_variant_price_overrides')->insert([
            'tenant_id' => $tenantId, 'product_variant_id' => $variantId, 'scope_type' => 'branch',
            'scope_key' => "branch:{$branchId}|channel:*", 'branch_id' => $branchId, 'override_price' => 5,
            'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    public function test_effective_price_uses_approved_priority_and_ignores_inactive_or_other_branch_scopes(): void
    {
        $tenantId = $this->tenant('alpha');
        $variantId = $this->variant($tenantId, 'Americano', 4);
        $branchId = $this->branch($tenantId);
        $otherBranchId = $this->branch($tenantId, 'Airport');
        $this->putJson($this->overridesUrl($variantId), ['overrides' => [
            ['scopeType' => 'channel', 'channel' => 'delivery', 'overridePrice' => 4.75],
            ['scopeType' => 'branch', 'branchId' => $branchId, 'overridePrice' => 4.5],
            ['scopeType' => 'branch_channel', 'branchId' => $branchId, 'channel' => 'delivery', 'overridePrice' => 5],
            ['scopeType' => 'branch', 'branchId' => $otherBranchId, 'overridePrice' => 6],
        ]], $this->headers($tenantId))->assertOk();
        $url = "/api/v1/admin/catalog/product-variants/{$variantId}/effective-price?branchId={$branchId}&channel=delivery";
        $this->getJson($url, $this->headers($tenantId))->assertOk()->assertJsonPath('data.effectivePrice', 5)->assertJsonPath('data.matchedScope', 'branch_channel');

        $this->putJson($this->overridesUrl($variantId), ['overrides' => [
            ['scopeType' => 'channel', 'channel' => 'delivery', 'overridePrice' => 4.75],
            ['scopeType' => 'branch', 'branchId' => $branchId, 'overridePrice' => 4.5],
            ['scopeType' => 'branch', 'branchId' => $otherBranchId, 'overridePrice' => 6],
        ]], $this->headers($tenantId))->assertOk();
        $this->getJson($url, $this->headers($tenantId))->assertOk()->assertJsonPath('data.effectivePrice', 4.5)->assertJsonPath('data.matchedScope', 'branch');

        $this->putJson($this->overridesUrl($variantId), ['overrides' => [
            ['scopeType' => 'channel', 'channel' => 'delivery', 'overridePrice' => 4.75],
            ['scopeType' => 'branch', 'branchId' => $branchId, 'overridePrice' => 4.5, 'isActive' => false],
            ['scopeType' => 'branch', 'branchId' => $otherBranchId, 'overridePrice' => 6],
        ]], $this->headers($tenantId))->assertOk();
        $this->getJson($url, $this->headers($tenantId))->assertOk()->assertJsonPath('data.effectivePrice', 4.75)->assertJsonPath('data.matchedScope', 'channel');

        $this->putJson($this->overridesUrl($variantId), ['overrides' => []], $this->headers($tenantId))->assertOk();
        $this->getJson($url, $this->headers($tenantId))->assertOk()->assertJsonPath('data.effectivePrice', 4)->assertJsonPath('data.matchedScope', 'base');
    }

    public function test_price_overrides_do_not_change_base_legacy_pos_or_existing_order_values(): void
    {
        $tenantId = $this->tenant('alpha');
        $variantId = $this->variant($tenantId, 'Flat White', 4);
        $productId = (int) DB::table('product_variants')->where('id', $variantId)->value('product_id');
        $branchId = $this->branch($tenantId);
        $orderId = DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_number' => 'PRICE-001',
            'subtotal' => 4, 'tax_total' => 0, 'tax_rate' => 0, 'total' => 4, 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('order_items')->insert([
            'tenant_id' => $tenantId, 'order_id' => $orderId, 'product_id' => $productId, 'product_variant_id' => $variantId,
            'product_name' => 'Flat White', 'variant_name' => 'Regular', 'unit_price' => 4, 'total' => 4,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->putJson($this->overridesUrl($variantId), ['overrides' => [[
            'scopeType' => 'branch_channel', 'branchId' => $branchId, 'channel' => 'delivery', 'overridePrice' => 6,
        ]]], $this->headers($tenantId))->assertOk();
        $this->assertDatabaseHas('products', ['id' => $productId, 'price' => 4]);
        $this->assertDatabaseHas('product_variants', ['id' => $variantId, 'base_price' => 4]);
        $this->assertDatabaseHas('orders', ['id' => $orderId, 'total' => 4]);
        $this->assertDatabaseHas('order_items', ['order_id' => $orderId, 'unit_price' => 4, 'total' => 4]);
        $this->getJson("/api/v1/menu/products/{$productId}", $this->headers($tenantId))->assertOk()->assertJsonPath('data.basePrice', 4);
    }

    private function overridesUrl(int $variantId): string
    {
        return "/api/v1/admin/catalog/product-variants/{$variantId}/price-overrides";
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenantId, string $name = 'Downtown'): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenantId, 'name' => $name, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function variant(int $tenantId, string $name, float $price): int
    {
        $productId = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => $name,
            'variants' => [['name' => 'Regular', 'basePrice' => $price, 'isDefault' => true, 'isActive' => true]],
        ], $this->headers($tenantId))->assertCreated()->json('data.id');

        return (int) DB::table('product_variants')->where('product_id', $productId)->value('id');
    }

    private function headers(int $tenantId): array
    {
        return ['X-Tenant-Id' => (string) $tenantId];
    }
}
