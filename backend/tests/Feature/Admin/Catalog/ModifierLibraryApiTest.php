<?php

namespace Tests\Feature\Admin\Catalog;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ModifierLibraryApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_group_resources_count_only_active_non_archived_options_and_hide_tenant_data(): void
    {
        $alpha = $this->tenant('alpha');
        $beta = $this->tenant('beta');
        $groupId = $this->group($alpha, 'Milk');
        $this->option($alpha, $groupId, 'Active', active: true);
        $this->option($alpha, $groupId, 'Inactive', active: false);
        $archivedOptionId = $this->option($alpha, $groupId, 'Archived', active: true, archived: true);
        $archivedGroupId = $this->group($alpha, 'Archived group', archived: true);
        $foreignGroupId = $this->group($beta, 'Foreign');

        $list = $this->getJson('/api/v1/admin/catalog/modifier-groups?status=all', $this->headers($alpha))
            ->assertOk()
            ->assertJsonMissingPath('data.0.tenantId')
            ->json('data');
        $active = collect($list)->firstWhere('id', $groupId);
        $archived = collect($list)->firstWhere('id', $archivedGroupId);
        $this->assertSame(1, $active['activeOptionCount']);
        $this->assertNull($active['archivedAt']);
        $this->assertNotNull($archived['archivedAt']);
        $this->assertNotContains($foreignGroupId, array_column($list, 'id'));

        $detail = $this->getJson("/api/v1/admin/catalog/modifier-groups/{$groupId}?includeArchived=true", $this->headers($alpha))
            ->assertOk()
            ->assertJsonMissingPath('data.tenantId')
            ->json('data');
        $this->assertSame(1, $detail['activeOptionCount']);
        $this->assertNotNull(collect($detail['options'])->firstWhere('id', $archivedOptionId)['archivedAt']);
        $this->getJson("/api/v1/admin/catalog/modifier-groups/{$foreignGroupId}", $this->headers($alpha))->assertNotFound();
    }

    public function test_group_detail_only_includes_its_tenant_options_when_archived_options_are_requested(): void
    {
        $alpha = $this->tenant('alpha');
        $beta = $this->tenant('beta');
        $groupId = $this->group($alpha, 'Syrups');
        $activeId = $this->option($alpha, $groupId, 'Vanilla');
        $archivedId = $this->option($alpha, $groupId, 'Hazelnut', archived: true);
        $otherGroupId = $this->group($alpha, 'Other');
        $otherArchivedId = $this->option($alpha, $otherGroupId, 'Other archived', archived: true);
        $foreignArchivedId = $this->option($beta, $groupId, 'Foreign archived', archived: true);

        foreach ([null, 'false', '0'] as $value) {
            $suffix = $value === null ? '' : "?includeArchived={$value}";
            $options = $this->getJson("/api/v1/admin/catalog/modifier-groups/{$groupId}{$suffix}", $this->headers($alpha))
                ->assertOk()
                ->json('data.options');
            $this->assertSame([$activeId], array_column($options, 'id'));
            $this->assertNull($options[0]['archivedAt']);
            $this->assertSame($groupId, $options[0]['modifierGroupId']);
        }

        foreach (['true', '1'] as $value) {
            $options = $this->getJson("/api/v1/admin/catalog/modifier-groups/{$groupId}?includeArchived={$value}", $this->headers($alpha))
                ->assertOk()
                ->json('data.options');
            $this->assertSame([$activeId, $archivedId], array_column($options, 'id'));
            $this->assertNotNull(collect($options)->firstWhere('id', $archivedId)['archivedAt']);
            $this->assertNotContains($otherArchivedId, array_column($options, 'id'));
            $this->assertNotContains($foreignArchivedId, array_column($options, 'id'));
            $this->assertSame([$groupId], array_values(array_unique(array_column($options, 'modifierGroupId'))));
        }

        $this->getJson("/api/v1/admin/catalog/modifier-groups/{$groupId}?includeArchived=invalid", $this->headers($alpha))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('includeArchived');
    }

    public function test_create_and_update_is_active_without_changing_archive_state_or_product_assignments(): void
    {
        $tenant = $this->tenant('alpha');
        $created = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Temperature', 'selectionType' => 'single', 'minSelections' => 0, 'maxSelections' => 1,
            'isActive' => false, 'options' => [['name' => 'Hot', 'isActive' => true]],
        ], $this->headers($tenant))->assertCreated()->assertJsonPath('data.isActive', false);
        $groupId = $created->json('data.id');
        $this->assertDatabaseHas('modifier_groups', ['id' => $groupId, 'is_active' => false, 'deleted_at' => null]);

        $productId = $this->product($tenant, 'Tea');
        DB::table('product_modifier_group')->insert(['tenant_id' => $tenant, 'product_id' => $productId, 'modifier_group_id' => $groupId, 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);
        foreach ([true, false] as $active) {
            $this->patchJson("/api/v1/admin/catalog/modifier-groups/{$groupId}", ['isActive' => $active], $this->headers($tenant))
                ->assertOk()
                ->assertJsonPath('data.isActive', $active)
                ->assertJsonPath('data.archivedAt', null);
            $this->assertDatabaseHas('modifier_groups', ['id' => $groupId, 'is_active' => $active, 'deleted_at' => null]);
            $this->assertDatabaseHas('product_modifier_group', ['tenant_id' => $tenant, 'product_id' => $productId, 'modifier_group_id' => $groupId]);
        }

        $this->patchJson("/api/v1/admin/catalog/modifier-groups/{$groupId}", ['isActive' => 'invalid'], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('isActive');
        $this->postJson("/api/v1/admin/catalog/modifier-groups/{$groupId}/archive", [], $this->headers($tenant))->assertOk()->assertJsonPath('data.isActive', false)->assertJsonPath('data.archivedAt', fn ($value) => $value !== null);
        $this->assertDatabaseHas('product_modifier_group', ['tenant_id' => $tenant, 'product_id' => $productId, 'modifier_group_id' => $groupId]);
        $this->postJson("/api/v1/admin/catalog/modifier-groups/{$groupId}/restore", [], $this->headers($tenant))->assertOk()->assertJsonPath('data.isActive', true)->assertJsonPath('data.archivedAt', null);
        $this->assertDatabaseHas('product_modifier_group', ['tenant_id' => $tenant, 'product_id' => $productId, 'modifier_group_id' => $groupId]);
    }

    public function test_option_lifecycle_reorder_and_cross_tenant_access_remain_tenant_scoped(): void
    {
        $alpha = $this->tenant('alpha');
        $beta = $this->tenant('beta');
        $groupId = $this->group($alpha, 'Extras');
        $firstId = $this->option($alpha, $groupId, 'Cream');
        $created = $this->postJson("/api/v1/admin/catalog/modifier-groups/{$groupId}/options", ['name' => 'Syrup', 'priceDelta' => 0, 'isActive' => true, 'sortOrder' => 1], $this->headers($alpha))
            ->assertCreated()
            ->assertJsonPath('data.modifierGroupId', $groupId)
            ->assertJsonPath('data.archivedAt', null);
        $optionId = $created->json('data.id');
        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$optionId}", ['name' => 'Vanilla syrup'], $this->headers($alpha))->assertOk()->assertJsonPath('data.name', 'Vanilla syrup');
        $this->postJson("/api/v1/admin/catalog/modifier-options/{$optionId}/archive", [], $this->headers($alpha))->assertOk()->assertJsonPath('data.archivedAt', fn ($value) => $value !== null);
        $this->postJson("/api/v1/admin/catalog/modifier-options/{$optionId}/restore", [], $this->headers($alpha))->assertOk()->assertJsonPath('data.archivedAt', null);
        $this->postJson("/api/v1/admin/catalog/modifier-groups/{$groupId}/options/reorder", ['items' => [['id' => $optionId, 'sortOrder' => 0], ['id' => $firstId, 'sortOrder' => 1]]], $this->headers($alpha))->assertOk();
        $this->assertDatabaseHas('modifier_options', ['id' => $optionId, 'sort_order' => 0]);
        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$optionId}", ['name' => 'Foreign'], $this->headers($beta))->assertNotFound();
    }

    private function group(int $tenantId, string $name, bool $archived = false): int
    {
        $now = now();

        return DB::table('modifier_groups')->insertGetId(['tenant_id' => $tenantId, 'name' => $name, 'group_type' => 'choice', 'selection_type' => 'single', 'is_required' => false, 'min_selections' => 0, 'max_selections' => 1, 'allow_quantity' => false, 'is_active' => ! $archived, 'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now, 'deleted_at' => $archived ? $now : null]);
    }

    private function option(int $tenantId, int $groupId, string $name, bool $active = true, bool $archived = false): int
    {
        $now = now();

        return DB::table('modifier_options')->insertGetId(['tenant_id' => $tenantId, 'modifier_group_id' => $groupId, 'name' => $name, 'price_delta' => 0, 'cost_delta' => 0, 'is_default' => false, 'is_active' => $active && ! $archived, 'is_available' => true, 'sort_order' => $name === 'Vanilla' ? 0 : 1, 'created_at' => $now, 'updated_at' => $now, 'deleted_at' => $archived ? $now : null]);
    }

    private function product(int $tenantId, string $name): int
    {
        return $this->postJson('/api/v1/admin/catalog/products', ['name' => $name, 'variants' => [['name' => 'Regular', 'basePrice' => 3, 'isDefault' => true, 'isActive' => true]]], $this->headers($tenantId))->assertCreated()->json('data.id');
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenantId): array
    {
        return ['X-Tenant-Id' => (string) $tenantId];
    }
}
