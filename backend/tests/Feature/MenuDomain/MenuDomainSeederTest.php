<?php

namespace Tests\Feature\MenuDomain;

use Database\Seeders\MenuCatalogSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuDomainSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_demo_products_receive_a_matching_regular_default_variant_idempotently(): void
    {
        $this->seed([TenantAccessSeeder::class, MenuCatalogSeeder::class]);
        $this->seed(MenuCatalogSeeder::class);
        $product = DB::table('products')->where('name', 'Cappuccino')->first();
        $variant = DB::table('product_variants')->where('product_id', $product->id)->where('is_default', true)->first();

        $this->assertSame(1, DB::table('product_variants')->where('product_id', $product->id)->where('is_default', true)->count());
        $this->assertSame('Regular', $variant->name);
        $this->assertEquals($product->price, $variant->base_price);
        $this->assertEquals($product->cost_price, $variant->cost_price);
        $this->assertEquals($product->is_active, $variant->is_active);
        $this->assertNull($variant->sku);
        $this->assertNull($variant->barcode);
    }
}
