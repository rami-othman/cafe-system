<?php

namespace Tests\Feature\Admin\MenuPublishing;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuPublishingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_publish_creates_immutable_current_snapshot_and_no_change_attempt(): void
    {
        [$tenant, $branch, $menu, $product, $variant, $section, $placement] = $this->graph();
        DB::table('product_variant_price_overrides')->insert(['tenant_id' => $tenant, 'product_variant_id' => $variant, 'scope_type' => 'branch_channel', 'scope_key' => "branch:{$branch}|channel:pos", 'branch_id' => $branch, 'channel' => 'pos', 'override_price' => 5, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $first = $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.published', true)->assertJsonPath('data.version.versionNumber', 1);
        $version = $first->json('data.version.id');
        $payload = DB::table('published_menu_versions')->where('id', $version)->value('payload_json');
        $this->assertStringContainsString('effectivePrice', $payload);
        $this->assertStringContainsString('5.00', $payload);
        $this->assertStringNotContainsString('isOperationallyAvailable', $payload);
        $this->assertStringNotContainsString('isSellable', $payload);
        $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.published', false)->assertJsonPath('data.noChanges', true)->assertJsonPath('data.version.id', $version);
        $this->assertSame(1, DB::table('published_menu_versions')->count());
        $this->getJson('/api/v1/admin/menu-management/current-version?branchId='.$branch.'&channel=pos', $this->headers($tenant))->assertOk()->assertJsonPath('data.id', $version)->assertJsonMissing(['payloadJson']);
    }

    public function test_changed_snapshot_supersedes_previous_and_validation_failure_is_recorded(): void
    {
        [$tenant, $branch, $menu, $product, $variant, $section, $placement] = $this->graph();
        $first = $this->publish($tenant, $branch)->assertOk()->json('data.version.id');
        DB::table('products')->where('id', $product)->update(['name' => 'Changed']);
        $second = $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.version.versionNumber', 2)->json('data.version.id');
        $this->assertDatabaseHas('published_menu_versions', ['id' => $first, 'status' => 'superseded']);
        $this->assertDatabaseHas('published_menu_versions', ['id' => $second, 'status' => 'current']);
        DB::table('menu_assignments')->where('menu_id', $menu)->delete();
        $this->publish($tenant, $branch)->assertUnprocessable()->assertJsonValidationErrors('publish');
        $this->assertDatabaseHas('menu_publications', ['tenant_id' => $tenant, 'status' => 'failed']);
        $this->assertSame(2, DB::table('published_menu_versions')->count());
    }

    public function test_tenant_scoping_and_independent_scope_sequences(): void
    {
        [$tenant, $branch] = $this->graph();
        $otherBranch = $this->branch($tenant, 'Airport');
        $this->publish($tenant, $branch)->assertOk()->assertJsonPath('data.version.versionNumber', 1);
        $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $otherBranch, 'channel' => 'pos'], $this->headers($tenant))->assertUnprocessable();
        $foreign = $this->tenant('foreign');
        [, , $foreignMenu] = $this->graph($foreign);
        $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $branch, 'channel' => 'pos', 'menuIds' => [$foreignMenu]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menuIds');
        $this->getJson('/api/v1/admin/menu-management/current-version?branchId='.$branch.'&channel=pos', $this->headers($foreign))->assertUnprocessable()->assertJsonValidationErrors('branchId');
    }

    private function publish(int $tenant, int $branch)
    {
        return $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $branch, 'channel' => 'pos'], $this->headers($tenant));
    }

    private function graph(?int $tenant = null): array
    {
        $tenant ??= $this->tenant('alpha');
        $branch = $this->branch($tenant);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'category_id' => $category, 'name' => 'Latte', 'price' => 4, 'cost_price' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => 4, 'cost_price' => 1, 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'status' => 'draft', 'created_at' => now(), 'updated_at' => now()]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $placement = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'is_visible' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_assignments')->insert(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => 'pos', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);

        return [$tenant, $branch, $menu, $product, $variant, $section, $placement];
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenant, string $name = 'Downtown'): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
