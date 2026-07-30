<?php

namespace Tests\Unit\MenuDomain;

use App\Models\Menu;
use App\Models\MenuAssignment;
use App\Models\MenuItemPlacement;
use App\Models\MenuPublication;
use App\Models\MenuSection;
use App\Models\ModifierGroup;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\PublishedMenuVersion;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuModelRelationshipsTest extends TestCase
{
    use RefreshDatabase;

    public function test_core_menu_domain_relationships_resolve(): void
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Relationships', 'slug' => 'relationships', 'created_at' => $now, 'updated_at' => $now]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'created_at' => $now, 'updated_at' => $now]);
        $product = Product::create(['tenant_id' => $tenant, 'name' => 'Coffee', 'price' => 3.5]);
        $variant = ProductVariant::create(['tenant_id' => $tenant, 'product_id' => $product->id, 'name' => 'Regular', 'base_price' => 3.5, 'is_default' => true]);
        $group = ModifierGroup::create(['tenant_id' => $tenant, 'name' => 'Milk']);
        $product->modifierGroups()->attach($group->id, ['tenant_id' => $tenant]);
        $menu = Menu::create(['tenant_id' => $tenant, 'name' => 'All Day']);
        $section = MenuSection::create(['tenant_id' => $tenant, 'menu_id' => $menu->id, 'name' => 'Coffee']);
        $placement = MenuItemPlacement::create(['tenant_id' => $tenant, 'menu_section_id' => $section->id, 'product_id' => $product->id]);
        $assignment = MenuAssignment::create(['tenant_id' => $tenant, 'menu_id' => $menu->id, 'branch_id' => $branch, 'channel' => 'pos']);
        $publication = MenuPublication::create(['tenant_id' => $tenant]);
        $version = PublishedMenuVersion::create(['tenant_id' => $tenant, 'menu_publication_id' => $publication->id, 'branch_id' => $branch, 'channel' => 'pos', 'version_number' => 1, 'payload_json' => [], 'checksum' => str_repeat('b', 64), 'published_at' => $now]);

        $this->assertTrue($product->variants->contains($variant));
        $this->assertTrue($product->modifierGroups->contains($group));
        $this->assertTrue($menu->sections->contains($section));
        $this->assertTrue($section->placements->contains($placement));
        $this->assertSame($product->id, $placement->product->id);
        $this->assertTrue($menu->assignments->contains($assignment));
        $this->assertTrue($publication->publishedMenuVersions->contains($version));
    }
}
