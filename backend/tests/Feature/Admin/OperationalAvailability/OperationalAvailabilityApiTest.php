<?php

namespace Tests\Feature\Admin\OperationalAvailability;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class OperationalAvailabilityApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_temporary_unavailability_interprets_offsetless_time_in_branch_timezone(): void
    {
        $tenant = $this->tenant('timezone');
        [$product] = $this->product($tenant, 'Timezone Latte');
        $branch = $this->branch($tenant, 'Dubai', 'Asia/Dubai');
        $this->putJson($this->productUrl($product), [
            'branchId' => $branch, 'channel' => 'pos', 'status' => 'temporarily_unavailable',
            'unavailableUntil' => '2030-01-15T18:00:00',
        ], $this->headers($tenant))->assertOk();
        $this->assertDatabaseHas('product_operational_availabilities', ['product_id' => $product, 'unavailable_until' => '2030-01-15 14:00:00+00']);
        $this->putJson($this->productUrl($product), [
            'branchId' => $branch, 'channel' => 'pos', 'status' => 'temporarily_unavailable',
            'unavailableUntil' => '2030-01-15T18:00:00+04:00',
        ], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('unavailableUntil');
    }

    public function test_paris_standard_and_daylight_times_round_trip_as_branch_local_wall_clock(): void
    {
        $tenant = $this->tenant('paris');
        [$product] = $this->product($tenant, 'Paris Latte');
        $branch = $this->branch($tenant, 'Paris', 'Europe/Paris');
        foreach ([['2030-01-15T18:00:00', '2030-01-15 17:00:00+00', '+01:00'], ['2030-07-15T18:00:00', '2030-07-15 16:00:00+00', '+02:00']] as [$local, $utc, $offset]) {
            $this->putJson($this->productUrl($product), ['branchId' => $branch, 'channel' => 'pos', 'status' => 'temporarily_unavailable', 'unavailableUntil' => $local], $this->headers($tenant))->assertOk();
            $this->assertDatabaseHas('product_operational_availabilities', ['product_id' => $product, 'unavailable_until' => $utc]);
            $this->getJson('/api/v1/admin/catalog/operational-availability?branchId='.$branch, $this->headers($tenant))->assertOk()->assertJsonPath('data.0.unavailableUntil', $local.$offset);
        }
    }

    public function test_product_scopes_upsert_clear_and_validation_are_tenant_safe(): void
    {
        $tenant = $this->tenant('alpha');
        [$product] = $this->product($tenant, 'Latte');
        $branch = $this->branch($tenant);
        $payload = ['branchId' => $branch, 'channel' => 'delivery', 'status' => 'sold_out', 'remainingQuantity' => 0, 'reason' => 'Milk unavailable'];
        $this->putJson($this->productUrl($product), $payload, $this->headers($tenant))->assertOk()->assertJsonPath('data.status', 'sold_out');
        $this->putJson($this->productUrl($product), [...$payload, 'status' => 'available', 'reason' => 'discarded'], $this->headers($tenant))->assertOk()->assertJsonPath('data.reason', null);
        $this->assertDatabaseCount('product_operational_availabilities', 1);
        $this->deleteJson($this->productUrl($product).'?branchId='.$branch.'&channel=delivery', [], $this->headers($tenant))->assertOk()->assertJsonPath('data.cleared', true);
        $this->deleteJson($this->productUrl($product).'?branchId='.$branch.'&channel=delivery', [], $this->headers($tenant))->assertOk()->assertJsonPath('data.cleared', false);
        $foreign = $this->tenant('beta');
        $this->putJson($this->productUrl($product), $payload, $this->headers($foreign))->assertNotFound();
        $this->putJson($this->productUrl($product), [...$payload, 'branchId' => $this->branch($foreign)], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $this->putJson($this->productUrl($product), [...$payload, 'channel' => 'all-channels'], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('channel');
        $this->putJson($this->productUrl($product), [...$payload, 'remainingQuantity' => -1], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('remainingQuantity');
        $this->putJson($this->productUrl($product), [...$payload, 'status' => 'temporarily_unavailable'], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('unavailableUntil');
        $this->putJson($this->productUrl($product), [...$payload, 'tenantId' => $foreign], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('tenantId');
    }

    public function test_variant_precedence_and_expiration_use_operational_overlay_only(): void
    {
        $tenant = $this->tenant('alpha');
        [$product, $variant] = $this->product($tenant, 'Tea');
        $branch = $this->branch($tenant, 'Downtown', 'Asia/Damascus');
        $putProduct = fn (array $data) => $this->putJson($this->productUrl($product), ['branchId' => $branch] + $data, $this->headers($tenant))->assertOk();
        $putVariant = fn (array $data) => $this->putJson($this->variantUrl($variant), ['branchId' => $branch] + $data, $this->headers($tenant))->assertOk();
        $putProduct(['channel' => 'all', 'status' => 'sold_out']);
        $this->preview($tenant, $product, $branch, 'delivery', $variant)->assertJsonPath('data.matchedLevel', 'product')->assertJsonPath('data.matchedScope', 'all_channels');
        $putProduct(['channel' => 'delivery', 'status' => 'temporarily_unavailable', 'unavailableUntil' => now('Asia/Damascus')->addHour()->format('Y-m-d\\TH:i:s')]);
        $putVariant(['channel' => 'all', 'status' => 'sold_out']);
        $putVariant(['channel' => 'delivery', 'status' => 'available']);
        $this->preview($tenant, $product, $branch, 'delivery', $variant)->assertJsonPath('data.status', 'available')->assertJsonPath('data.matchedLevel', 'variant')->assertJsonPath('data.matchedScope', 'exact_channel');
        $this->deleteJson($this->variantUrl($variant).'?branchId='.$branch.'&channel=delivery', [], $this->headers($tenant))->assertOk();
        $this->preview($tenant, $product, $branch, 'delivery', $variant)->assertJsonPath('data.status', 'sold_out')->assertJsonPath('data.matchedScope', 'all_channels');
        $putVariant(['channel' => 'pos', 'status' => 'temporarily_unavailable', 'unavailableUntil' => now('Asia/Damascus')->addMinute()->format('Y-m-d\\TH:i:s')]);
        DB::table('product_variant_operational_availabilities')->where('product_variant_id', $variant)->where('channel', 'pos')->update(['unavailable_until' => now()->subSecond()]);
        $this->preview($tenant, $product, $branch, 'pos', $variant)->assertJsonPath('data.status', 'sold_out')->assertJsonPath('data.matchedScope', 'all_channels');
    }

    public function test_variant_tenant_and_archived_resources_are_rejected(): void
    {
        $tenant = $this->tenant('alpha');
        [$product, $variant] = $this->product($tenant, 'Mocha');
        $branch = $this->branch($tenant);
        $payload = ['branchId' => $branch, 'channel' => 'all', 'status' => 'sold_out'];
        $foreign = $this->tenant('beta');
        [, $foreignVariant] = $this->product($foreign, 'Foreign');
        $this->putJson($this->variantUrl($foreignVariant), $payload, $this->headers($tenant))->assertNotFound();
        DB::table('products')->where('id', $product)->update(['deleted_at' => now(), 'is_active' => false]);
        $this->putJson($this->productUrl($product), $payload, $this->headers($tenant))->assertNotFound();
        DB::table('products')->where('id', $product)->update(['deleted_at' => null, 'is_active' => true]);
        DB::table('product_variants')->where('id', $variant)->update(['deleted_at' => now(), 'is_active' => false]);
        $this->putJson($this->variantUrl($variant), $payload, $this->headers($tenant))->assertNotFound();
        DB::table('branches')->where('id', $branch)->update(['deleted_at' => now(), 'is_active' => false]);
        $this->putJson($this->productUrl($product), $payload, $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('branchId');
    }

    public function test_list_is_paginated_filtered_and_does_not_leak_internal_fields(): void
    {
        $tenant = $this->tenant('alpha');
        [$product, $variant] = $this->product($tenant, 'Americano');
        $branch = $this->branch($tenant);
        $this->putJson($this->productUrl($product), ['branchId' => $branch, 'channel' => 'all', 'status' => 'sold_out'], $this->headers($tenant))->assertOk();
        $this->putJson($this->variantUrl($variant), ['branchId' => $branch, 'channel' => 'delivery', 'status' => 'temporarily_unavailable', 'unavailableUntil' => now('UTC')->addHour()->format('Y-m-d\\TH:i:s')], $this->headers($tenant))->assertOk();
        $response = $this->getJson('/api/v1/admin/catalog/operational-availability?branchId='.$branch.'&level=variant&status=temporarily_unavailable&perPage=1', $this->headers($tenant))->assertOk()->assertJsonCount(1, 'data');
        $this->assertArrayNotHasKey('tenant_id', $response->json('data.0'));
        $this->assertArrayNotHasKey('updated_by', $response->json('data.0'));
    }

    private function preview(int $tenant, int $product, int $branch, string $channel, ?int $variant = null)
    {
        return $this->getJson('/api/v1/admin/catalog/products/'.$product.'/operational-availability-preview?'.http_build_query(['branchId' => $branch, 'channel' => $channel, 'productVariantId' => $variant]), $this->headers($tenant))->assertOk();
    }

    private function productUrl(int $id): string
    {
        return '/api/v1/admin/catalog/products/'.$id.'/operational-availability';
    }

    private function variantUrl(int $id): string
    {
        return '/api/v1/admin/catalog/product-variants/'.$id.'/operational-availability';
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenant, string $name = 'Downtown', string $timezone = 'UTC'): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'timezone' => $timezone, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function product(int $tenant, string $name): array
    {
        $id = $this->postJson('/api/v1/admin/catalog/products', ['name' => $name, 'variants' => [['name' => 'Regular', 'basePrice' => 4, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenant))->assertCreated()->json('data.id');

        return [$id, (int) DB::table('product_variants')->where('product_id', $id)->value('id')];
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
