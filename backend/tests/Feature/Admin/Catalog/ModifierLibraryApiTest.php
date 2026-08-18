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

    public function test_group_list_returns_a_bounded_ordered_option_preview_without_full_options(): void
    {
        $tenant = $this->tenant('preview');
        $groupId = $this->group($tenant, 'Milk Type');
        foreach (['Whole Milk', 'Oat Milk', 'Almond Milk', 'Soy Milk', 'Coconut Milk'] as $sort => $name) {
            DB::table('modifier_options')->insert([
                'tenant_id' => $tenant,
                'modifier_group_id' => $groupId,
                'name' => $name,
                'price_delta' => $sort === 1 ? '0.50' : ($sort === 2 ? '-0.50' : '0.00'),
                'cost_delta' => 0,
                'is_default' => $sort === 0,
                'is_active' => true,
                'is_available' => true,
                'sort_order' => $sort,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $group = $this->getJson('/api/v1/admin/catalog/modifier-groups', $this->headers($tenant))
            ->assertOk()
            ->json('data.0');

        $this->assertSame($groupId, $group['id']);
        $this->assertSame(5, $group['optionCount']);
        $this->assertSame(['Whole Milk', 'Oat Milk', 'Almond Milk'], array_column($group['optionPreview'], 'name'));
        $this->assertNotNull($group['optionPreview'][0]['id']);
        $this->assertEquals([0.0, 0.5, -0.5], array_column($group['optionPreview'], 'priceDelta'));
        $this->assertSame(2, $group['remainingOptionCount']);
        $this->assertArrayNotHasKey('costDelta', $group['optionPreview'][0]);
        $this->assertArrayNotHasKey('updatedAt', $group['optionPreview'][0]);
        $this->assertArrayNotHasKey('options', $group);
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

    public function test_modifier_group_lifecycle_filters_keep_inactive_separate_from_archived(): void
    {
        $tenant = $this->tenant('modifier-lifecycle');
        $headers = $this->headers($tenant);
        $active = $this->group($tenant, 'Active');
        $inactive = $this->group($tenant, 'Inactive');
        DB::table('modifier_groups')->where('id', $inactive)->update(['is_active' => false]);
        $archived = $this->group($tenant, 'Archived', archived: true);
        foreach (['active' => [$active], 'inactive' => [$inactive], 'archived' => [$archived], 'all' => [$active, $inactive, $archived]] as $status => $expected) {
            $ids = array_column($this->getJson("/api/v1/admin/catalog/modifier-groups?status={$status}", $headers)->assertOk()->json('data'), 'id');
            sort($ids);
            sort($expected);
            $this->assertSame($expected, $ids);
        }
    }

    public function test_multi_select_group_creation_is_atomic_and_tenant_scoped(): void
    {
        $tenant = $this->tenant('multi-select');
        $created = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Add-ons', 'selectionType' => 'multiple', 'isRequired' => false,
            'minSelections' => 0, 'maxSelections' => 3,
            'options' => [
                ['name' => 'Extra Shot', 'priceDelta' => 0.5],
                ['name' => 'Whipped Cream', 'priceDelta' => 0.75],
                ['name' => 'Caramel Drizzle', 'priceDelta' => 0.6],
            ],
        ], $this->headers($tenant))->assertCreated();
        $groupId = $created->json('data.id');

        $this->assertCount(3, $created->json('data.options'));
        $this->assertSame(['Extra Shot', 'Whipped Cream', 'Caramel Drizzle'], array_column($created->json('data.options'), 'name'));
        $this->assertDatabaseCount('modifier_options', 3);
        $this->assertDatabaseHas('modifier_groups', ['id' => $groupId, 'min_selections' => 0, 'max_selections' => 3, 'selection_type' => 'multiple']);
        $this->getJson("/api/v1/admin/catalog/modifier-groups/{$groupId}", $this->headers($this->tenant('other-tenant')))->assertNotFound();

        $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Repeatable Add-ons', 'selectionType' => 'multiple', 'allowQuantity' => true,
            'minSelections' => 0, 'maxSelections' => 5,
            'options' => [
                ['name' => 'Extra Shot'],
                ['name' => 'Whipped Cream'],
            ],
        ], $this->headers($tenant))->assertCreated()->assertJsonPath('data.allowQuantity', true);

        $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Invalid Add-ons', 'selectionType' => 'multiple', 'maxSelections' => 3,
            'options' => [['name' => 'Only option']],
        ], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('modifierGroup');
        $this->assertDatabaseMissing('modifier_groups', ['name' => 'Invalid Add-ons']);

        $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Invalid Defaults', 'selectionType' => 'multiple', 'maxSelections' => 2,
            'options' => [
                ['name' => 'One', 'isDefault' => true],
                ['name' => 'Two', 'isDefault' => true],
                ['name' => 'Three', 'isDefault' => true],
            ],
        ], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('modifierGroup');
        $this->assertDatabaseMissing('modifier_groups', ['name' => 'Invalid Defaults']);
    }

    public function test_signed_price_adjustments_are_supported_for_group_and_option_lifecycle(): void
    {
        $tenant = $this->tenant('signed-price-adjustments');
        $created = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Milk choices',
            'options' => [
                ['name' => 'Oat Milk', 'priceDelta' => '0.75'],
                ['name' => 'Regular Milk', 'priceDelta' => '0.00'],
                ['name' => 'No Side', 'priceDelta' => '-0.50'],
            ],
        ], $this->headers($tenant))->assertCreated();

        $options = $created->json('data.options');
        $this->assertEquals(0.75, $options[0]['priceDelta']);
        $this->assertEquals(0.0, $options[1]['priceDelta']);
        $this->assertEquals(-0.5, $options[2]['priceDelta']);
        $this->assertEquals(-0.5, (float) DB::table('modifier_options')->where('id', $options[2]['id'])->value('price_delta'));

        $groupId = $this->group($tenant, 'Standalone signed options');
        $createdOption = $this->postJson("/api/v1/admin/catalog/modifier-groups/{$groupId}/options", [
            'name' => 'Discounted side', 'priceDelta' => '-0.50',
        ], $this->headers($tenant))->assertCreated()->assertJsonPath('data.priceDelta', -0.5);
        $optionId = $createdOption->json('data.id');

        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$optionId}", ['priceDelta' => '0.75'], $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.priceDelta', 0.75);
        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$optionId}", ['priceDelta' => '-0.50'], $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.priceDelta', -0.5);

        $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Invalid signed adjustment',
            'options' => [['name' => 'Broken', 'priceDelta' => '1..5']],
        ], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('options.0.priceDelta');
        $this->postJson("/api/v1/admin/catalog/modifier-groups/{$groupId}/options", [
            'name' => 'Broken', 'priceDelta' => 'abc',
        ], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('priceDelta');
    }

    public function test_option_mutations_validate_the_prospective_group_and_preserve_failed_state(): void
    {
        $tenant = $this->tenant('option-invariants');
        $groupId = $this->postJson('/api/v1/admin/catalog/modifier-groups', [
            'name' => 'Required extras', 'selectionType' => 'multiple', 'isRequired' => true,
            'minSelections' => 2, 'maxSelections' => 2,
            'options' => [['name' => 'One'], ['name' => 'Two'], ['name' => 'Three']],
        ], $this->headers($tenant))->assertCreated()->json('data.id');
        $options = $this->getJson("/api/v1/admin/catalog/modifier-groups/{$groupId}", $this->headers($tenant))->json('data.options');
        $first = (int) $options[0]['id'];
        $second = (int) $options[1]['id'];
        $third = (int) $options[2]['id'];

        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$first}", ['name' => 'Renamed'], $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.name', 'Renamed');
        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$first}", ['isActive' => false], $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.isActive', false);

        $this->postJson("/api/v1/admin/catalog/modifier-options/{$first}/archive", [], $this->headers($tenant))
            ->assertOk();
        $this->postJson("/api/v1/admin/catalog/modifier-options/{$second}/archive", [], $this->headers($tenant))
            ->assertUnprocessable()->assertJsonValidationErrors('modifierGroup');
        $this->assertDatabaseHas('modifier_options', ['id' => $second, 'is_active' => true, 'deleted_at' => null]);

        $this->postJson("/api/v1/admin/catalog/modifier-options/{$first}/restore", [], $this->headers($tenant))
            ->assertOk()->assertJsonPath('data.isActive', true);
        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$first}", ['isDefault' => true], $this->headers($tenant))->assertOk();
        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$second}", ['isDefault' => true], $this->headers($tenant))->assertOk();
        $this->patchJson("/api/v1/admin/catalog/modifier-options/{$third}", ['isDefault' => true], $this->headers($tenant))
            ->assertUnprocessable()->assertJsonValidationErrors('modifierGroup');
        $this->assertDatabaseHas('modifier_options', ['id' => $third, 'is_default' => false]);
    }

    public function test_modifier_group_reorder_requires_complete_contiguous_active_set(): void
    {
        $alpha = $this->tenant('reorder-alpha');
        $beta = $this->tenant('reorder-beta');
        $first = $this->group($alpha, 'First');
        $second = $this->group($alpha, 'Second');
        $third = $this->group($alpha, 'Third');
        $foreign = $this->group($beta, 'Foreign');

        $this->postJson('/api/v1/admin/catalog/modifier-groups/reorder', ['items' => [
            ['id' => $third, 'sortOrder' => 0], ['id' => $first, 'sortOrder' => 1], ['id' => $second, 'sortOrder' => 2],
        ]], $this->headers($alpha))->assertOk();
        $this->assertDatabaseHas('modifier_groups', ['id' => $third, 'sort_order' => 0]);
        $this->assertDatabaseHas('modifier_groups', ['id' => $first, 'sort_order' => 1]);

        foreach ([
            [['id' => $third, 'sortOrder' => 0], ['id' => $third, 'sortOrder' => 1], ['id' => $second, 'sortOrder' => 2]],
            [['id' => $third, 'sortOrder' => 0], ['id' => $first, 'sortOrder' => 2]],
            [['id' => $third, 'sortOrder' => 1], ['id' => $first, 'sortOrder' => 2], ['id' => $second, 'sortOrder' => 3]],
            [['id' => $third, 'sortOrder' => 0], ['id' => $first, 'sortOrder' => 1], ['id' => $foreign, 'sortOrder' => 2]],
        ] as $items) {
            $this->postJson('/api/v1/admin/catalog/modifier-groups/reorder', ['items' => $items], $this->headers($alpha))
                ->assertUnprocessable()->assertJsonValidationErrors('items');
        }

        $this->postJson("/api/v1/admin/catalog/modifier-groups/{$second}/archive", [], $this->headers($alpha))->assertOk();
        $this->postJson('/api/v1/admin/catalog/modifier-groups/reorder', ['items' => [
            ['id' => $third, 'sortOrder' => 0], ['id' => $first, 'sortOrder' => 1], ['id' => $second, 'sortOrder' => 2],
        ]], $this->headers($alpha))->assertUnprocessable()->assertJsonValidationErrors('items');
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
