<?php

namespace Tests\Feature\MenuDomain;

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class MenuDomainSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_menu_domain_tables_and_legacy_columns_exist(): void
    {
        foreach (['reporting_categories', 'kitchen_stations', 'product_variants', 'menus', 'menu_sections', 'menu_item_placements', 'menu_assignments', 'product_variant_price_overrides', 'menu_availability_rules', 'product_availability_rules', 'product_operational_availabilities', 'product_variant_operational_availabilities', 'menu_publications', 'published_menu_versions', 'menu_audit_logs'] as $table) {
            $this->assertTrue(Schema::hasTable($table), "Missing {$table} table.");
        }
        $this->assertTrue(Schema::hasColumns('products', ['name', 'description', 'sku', 'barcode', 'price', 'cost_price', 'image_url', 'is_active', 'is_stock_tracked', 'sort_order', 'name_ar', 'name_en', 'description_ar', 'description_en', 'product_type', 'reporting_category_id', 'kitchen_station_id', 'preparation_time_minutes']));
        $this->assertTrue(Schema::hasColumns('categories', ['name', 'name_ar', 'name_en']));
        $this->assertTrue(Schema::hasColumns('modifier_groups', ['selection_type', 'is_required', 'min_selections', 'max_selections', 'group_type', 'allow_quantity']));
        $this->assertTrue(Schema::hasColumns('modifier_options', ['price_delta', 'is_available', 'cost_delta', 'is_active']));
        $this->assertTrue(Schema::hasColumns('order_items', ['product_name', 'unit_price', 'total', 'product_variant_id', 'variant_name']));
        $this->assertTrue(Schema::hasColumns('orders', ['published_menu_version_id']));
        $this->assertTrue(Schema::hasColumn('order_item_modifiers', 'quantity'));
    }

    public function test_menu_domain_unique_constraints_are_enforced(): void
    {
        $ids = $this->ids();
        DB::table('menu_item_placements')->insert(['tenant_id' => $ids['tenant'], 'menu_section_id' => $ids['section'], 'product_id' => $ids['product'], 'created_at' => now(), 'updated_at' => now()]);
        $this->expectException(QueryException::class);
        DB::table('menu_item_placements')->insert(['tenant_id' => $ids['tenant'], 'menu_section_id' => $ids['section'], 'product_id' => $ids['product'], 'created_at' => now(), 'updated_at' => now()]);
    }

    public function test_foreign_keys_reject_missing_menu_and_product_references(): void
    {
        $ids = $this->ids();
        $this->assertConstraintViolation(fn () => DB::table('menu_sections')->insert(['tenant_id' => $ids['tenant'], 'menu_id' => 999999, 'name' => 'Invalid', 'created_at' => now(), 'updated_at' => now()]));
        $this->assertConstraintViolation(fn () => DB::table('menu_item_placements')->insert(['tenant_id' => $ids['tenant'], 'menu_section_id' => $ids['section'], 'product_id' => 999999, 'created_at' => now(), 'updated_at' => now()]));
    }

    public function test_variant_sku_and_barcode_are_unique_per_tenant_but_nullable(): void
    {
        $ids = $this->ids();
        DB::table('product_variants')->insert(['tenant_id' => $ids['tenant'], 'product_id' => $ids['product'], 'name' => 'No codes', 'base_price' => 3.5, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('product_variants')->where('id', $ids['variant'])->update(['sku' => 'COFFEE-REGULAR', 'barcode' => '123456']);
        $this->assertConstraintViolation(fn () => DB::table('product_variants')->insert(['tenant_id' => $ids['tenant'], 'product_id' => $ids['product'], 'name' => 'Duplicate SKU', 'sku' => 'COFFEE-REGULAR', 'base_price' => 3.5, 'created_at' => now(), 'updated_at' => now()]));
        $this->assertConstraintViolation(fn () => DB::table('product_variants')->insert(['tenant_id' => $ids['tenant'], 'product_id' => $ids['product'], 'name' => 'Duplicate barcode', 'barcode' => '123456', 'base_price' => 3.5, 'created_at' => now(), 'updated_at' => now()]));
    }

    public function test_assignment_override_availability_and_version_constraints_are_enforced(): void
    {
        $ids = $this->ids();
        DB::table('menu_assignments')->insert(['tenant_id' => $ids['tenant'], 'menu_id' => $ids['menu'], 'branch_id' => $ids['branch'], 'channel' => 'pos', 'created_at' => now(), 'updated_at' => now()]);
        $this->assertConstraintViolation(fn () => DB::table('menu_assignments')->insert(['tenant_id' => $ids['tenant'], 'menu_id' => $ids['menu'], 'branch_id' => $ids['branch'], 'channel' => 'pos', 'created_at' => now(), 'updated_at' => now()]));
        DB::table('product_variant_price_overrides')->insert(['tenant_id' => $ids['tenant'], 'product_variant_id' => $ids['variant'], 'scope_type' => 'branch', 'scope_key' => 'branch:'.$ids['branch'].'|channel:*', 'branch_id' => $ids['branch'], 'override_price' => 4, 'created_at' => now(), 'updated_at' => now()]);
        $this->assertConstraintViolation(fn () => DB::table('product_variant_price_overrides')->insert(['tenant_id' => $ids['tenant'], 'product_variant_id' => $ids['variant'], 'scope_type' => 'branch', 'scope_key' => 'branch:'.$ids['branch'].'|channel:*', 'branch_id' => $ids['branch'], 'override_price' => 5, 'created_at' => now(), 'updated_at' => now()]));
        DB::table('product_operational_availabilities')->insert(['tenant_id' => $ids['tenant'], 'product_id' => $ids['product'], 'branch_id' => $ids['branch'], 'channel' => 'all', 'created_at' => now(), 'updated_at' => now()]);
        $this->assertConstraintViolation(fn () => DB::table('product_operational_availabilities')->insert(['tenant_id' => $ids['tenant'], 'product_id' => $ids['product'], 'branch_id' => $ids['branch'], 'channel' => 'all', 'created_at' => now(), 'updated_at' => now()]));
        $publication = DB::table('menu_publications')->insertGetId(['tenant_id' => $ids['tenant'], 'created_at' => now(), 'updated_at' => now()]);
        $version = ['tenant_id' => $ids['tenant'], 'menu_publication_id' => $publication, 'branch_id' => $ids['branch'], 'channel' => 'pos', 'version_number' => 1, 'payload_json' => '{}', 'checksum' => str_repeat('a', 64), 'published_at' => now(), 'created_at' => now(), 'updated_at' => now()];
        DB::table('published_menu_versions')->insert($version);
        $this->assertConstraintViolation(fn () => DB::table('published_menu_versions')->insert($version));
    }

    private function assertConstraintViolation(callable $callback): void
    {
        try {
            DB::transaction($callback);
            $this->fail('Expected a database constraint violation.');
        } catch (QueryException) {
            // PostgreSQL errors abort the current transaction; the nested transaction rolls back to a savepoint.
            $this->addToAssertionCount(1);
        }
    }

    private function ids(): array
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Menu Tenant', 'slug' => 'menu-tenant', 'created_at' => $now, 'updated_at' => $now]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'created_at' => $now, 'updated_at' => $now]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'price' => 3.5, 'created_at' => $now, 'updated_at' => $now]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => 3.5, 'is_default' => true, 'created_at' => $now, 'updated_at' => $now]);
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'All Day', 'created_at' => $now, 'updated_at' => $now]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'created_at' => $now, 'updated_at' => $now]);

        return compact('tenant', 'branch', 'product', 'variant', 'menu', 'section');
    }
}
