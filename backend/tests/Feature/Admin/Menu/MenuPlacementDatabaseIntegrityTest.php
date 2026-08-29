<?php

namespace Tests\Feature\Admin\Menu;

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuPlacementDatabaseIntegrityTest extends TestCase
{
    use RefreshDatabase;

    public function test_partial_unique_index_allows_archived_history_but_rejects_duplicate_active_placements(): void
    {
        $tenantId = $this->tenant('alpha');
        $productId = $this->product($tenantId);
        $menuId = $this->postJson('/api/v1/admin/menus', ['name' => 'Main'], $this->headers($tenantId))->json('data.id');
        $sectionId = $this->postJson("/api/v1/admin/menus/{$menuId}/sections", ['name' => 'Coffee'], $this->headers($tenantId))->json('data.id');
        $placementId = $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $productId], $this->headers($tenantId))->json('data.id');

        $this->postJson("/api/v1/admin/menu-item-placements/{$placementId}/archive", [], $this->headers($tenantId))->assertOk();
        $historicalId = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenantId, 'menu_section_id' => $sectionId, 'product_id' => $productId, 'deleted_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson("/api/v1/admin/menu-sections/{$sectionId}/placements", ['productId' => $productId], $this->headers($tenantId))->assertCreated()->assertJsonPath('data.id', $placementId);
        $this->assertDatabaseCount('menu_item_placements', 2);
        $this->assertTrue(DB::table('menu_item_placements')->where('id', $historicalId)->whereNotNull('deleted_at')->exists());

        $this->assertConstraintViolation(fn () => DB::table('menu_item_placements')->insert(['tenant_id' => $tenantId, 'menu_section_id' => $sectionId, 'product_id' => $productId, 'created_at' => now(), 'updated_at' => now()]));

        $this->postJson("/api/v1/admin/menu-item-placements/{$placementId}/archive", [], $this->headers($tenantId))->assertOk();
        $activeDuplicateId = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenantId, 'menu_section_id' => $sectionId, 'product_id' => $productId, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson("/api/v1/admin/menu-item-placements/{$placementId}/restore", [], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('placement');
        $this->assertDatabaseHas('menu_item_placements', ['id' => $activeDuplicateId, 'deleted_at' => null]);
    }

    private function assertConstraintViolation(callable $callback): void
    {
        try {
            DB::transaction($callback);
            $this->fail('Expected the partial unique index to reject a duplicate active placement.');
        } catch (QueryException) {
            $this->addToAssertionCount(1);
        }
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function product(int $tenantId): int
    {
        return $this->postJson('/api/v1/admin/catalog/products', ['name' => 'Latte', 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenantId))->assertCreated()->json('data.id');
    }

    private function headers(int $tenantId): array
    {
        return ['X-Tenant-Id' => (string) $tenantId];
    }
}
