<?php

namespace Tests\Feature\Admin\MenuVersionHistory;

use App\Models\PublishedMenuVersion;
use App\Services\Menu\PublishedMenuVersionComparisonService;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PublishedMenuVersionHistoryApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_history_detail_comparison_and_rollback_are_tenant_safe(): void
    {
        $tenant = $this->tenant('alpha');
        $branch = $this->branch($tenant);
        [$publication, $one] = $this->version($tenant, $branch, 1, 'a', 'superseded');
        [, $two] = $this->version($tenant, $branch, 2, 'b', 'current');
        $this->getJson("/api/v1/admin/menu-management/versions?branchId={$branch}&channel=pos", $this->headers($tenant))->assertOk()->assertJsonPath('data.0.versionNumber', 2)->assertJsonMissing(['payload']);
        $this->getJson("/api/v1/admin/menu-management/versions/{$one}", $this->headers($tenant))->assertOk()->assertJsonPath('data.snapshotSummary.menuCount', 1)->assertJsonMissing(['payload']);
        $this->getJson("/api/v1/admin/menu-management/versions/{$one}?includePayload=true", $this->headers($tenant))->assertOk()->assertJsonPath('data.payload.menus.0.id', 1);
        $this->getJson("/api/v1/admin/menu-management/versions/{$one}/compare?againstVersionId={$one}", $this->headers($tenant))->assertOk()->assertJsonPath('data.sameChecksum', true);
        $rollback = $this->postJson("/api/v1/admin/menu-management/versions/{$one}/rollback", ['reason' => 'restore'], $this->headers($tenant))->assertOk()->assertJsonPath('data.rolledBack', true)->assertJsonPath('data.version.versionNumber', 3);
        $new = $rollback->json('data.version.id');
        $this->assertDatabaseHas('published_menu_versions', ['id' => $two, 'status' => 'rolled_back']);
        $this->assertDatabaseHas('published_menu_versions', ['id' => $new, 'checksum' => 'a', 'status' => 'current']);
        $this->assertSame(1, DB::table('published_menu_versions')->where('tenant_id', $tenant)->where('branch_id', $branch)->where('status', 'current')->count());
        $foreign = $this->tenant('beta');
        $this->getJson("/api/v1/admin/menu-management/versions/{$one}", $this->headers($foreign))->assertNotFound();
    }

    public function test_checksum_reuse_constraints_no_change_rollback_and_audits(): void
    {
        $tenant = $this->tenant('constraints');
        $branch = $this->branch($tenant);
        [$sourcePublication, $one] = $this->version($tenant, $branch, 1, 'same', 'superseded');
        [, $two] = $this->version($tenant, $branch, 2, 'current', 'current');
        $rollback = $this->postJson("/api/v1/admin/menu-management/versions/{$one}/rollback", ['reason' => 'restore exact'], $this->headers($tenant))->assertOk();
        $three = $rollback->json('data.version.id');
        $this->assertDatabaseHas('menu_publications', ['id' => $rollback->json('data.publicationId'), 'source_publication_id' => $sourcePublication]);
        $this->assertDatabaseHas('menu_audit_logs', ['menu_publication_id' => $rollback->json('data.publicationId'), 'action' => 'rollback_started']);
        $this->assertDatabaseHas('menu_audit_logs', ['menu_publication_id' => $rollback->json('data.publicationId'), 'action' => 'version_rolled_back']);
        $this->postJson("/api/v1/admin/menu-management/versions/{$three}/rollback", ['reason' => 'same'], $this->headers($tenant))->assertOk()->assertJsonPath('data.noChanges', true);
        $this->assertSame(3, DB::table('published_menu_versions')->where('tenant_id', $tenant)->count());
        $this->expectException(UniqueConstraintViolationException::class);
        DB::table('published_menu_versions')->insert(['tenant_id' => $tenant, 'menu_publication_id' => $sourcePublication, 'branch_id' => $branch, 'channel' => 'pos', 'version_number' => 3, 'payload_json' => '{}', 'checksum' => 'other', 'status' => 'superseded', 'published_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
    }

    public function test_recipe_comparison_is_typed_and_schema_v1_is_treated_as_no_recipe_data(): void
    {
        $tenant = $this->tenant('recipe-compare');
        $branch = $this->branch($tenant);
        [, $v1] = $this->version($tenant, $branch, 1, 'v1', 'superseded');
        [, $v2] = $this->version($tenant, $branch, 2, 'v2', 'current');
        $recipePayload = fn (array $base, array $adjustments) => ['context' => ['tenantId' => $tenant, 'schemaVersion' => 2], 'menus' => [['id' => 1, 'sections' => [['id' => 1, 'products' => [['placementId' => 1, 'productId' => 1, 'variants' => [['id' => 1, 'effectivePrice' => '4.00', 'baseRecipe' => $base, 'modifierRecipeAdjustments' => $adjustments]], 'modifierGroups' => []]]]]]]];
        DB::table('published_menu_versions')->where('id', $v2)->update(['payload_json' => json_encode($recipePayload([['materialId' => 1, 'quantity' => '18', 'unitCode' => 'g']], [['optionId' => 2, 'components' => [['materialId' => 1, 'operation' => 'add', 'quantity' => '18', 'unitCode' => 'g']]]]))]);
        $response = $this->getJson("/api/v1/admin/menu-management/versions/{$v1}/compare?againstVersionId={$v2}", $this->headers($tenant))->assertOk();
        $types = array_column($response->json('data.changes.recipeChanges'), 'type');
        $this->assertContains('base_component_added', $types);
        $this->assertContains('modifier_adjustment_added', $types);
        DB::table('published_menu_versions')->where('id', $v1)->update(['payload_json' => json_encode($recipePayload([['materialId' => 3, 'quantity' => '20', 'unitCode' => 'kg']], [['optionId' => 2, 'components' => [['materialId' => 1, 'operation' => 'remove', 'quantity' => '1', 'unitCode' => 'g']]]]))]);
        $types = array_column($this->getJson("/api/v1/admin/menu-management/versions/{$v1}/compare?againstVersionId={$v2}", $this->headers($tenant))->assertOk()->json('data.changes.recipeChanges'), 'type');
        foreach (['base_component_added', 'base_component_removed', 'modifier_adjustment_added', 'modifier_adjustment_removed'] as $type) {
            $this->assertContains($type, $types);
        }
    }

    public function test_recipe_comparison_covers_changed_categories_and_uses_a_deterministic_100_row_bound(): void
    {
        $tenant = $this->tenant('recipe-compare-bound');
        $branch = $this->branch($tenant);
        [, $from] = $this->version($tenant, $branch, 1, 'from', 'superseded');
        [, $to] = $this->version($tenant, $branch, 2, 'to', 'current');
        $payload = fn (array $base, array $adjustments) => ['context' => ['tenantId' => $tenant, 'schemaVersion' => 2], 'menus' => [['id' => 1, 'sections' => [['id' => 1, 'products' => [['placementId' => 1, 'productId' => 1, 'variants' => [['id' => 1, 'baseRecipe' => $base, 'modifierRecipeAdjustments' => $adjustments]], 'modifierGroups' => []]]]]]]];
        $fromBase = [['materialId' => 1, 'quantity' => '1', 'unitCode' => 'g'], ['materialId' => 2, 'quantity' => '1', 'unitCode' => 'g']];
        $toBase = [['materialId' => 2, 'quantity' => '2', 'unitCode' => 'g'], ['materialId' => 3, 'quantity' => '1', 'unitCode' => 'g']];
        $fromAdjustments = [['optionId' => 4, 'components' => [['materialId' => 1, 'operation' => 'add', 'quantity' => '1', 'unitCode' => 'g'], ['materialId' => 2, 'operation' => 'add', 'quantity' => '1', 'unitCode' => 'g']]]];
        $toAdjustments = [['optionId' => 4, 'components' => [['materialId' => 1, 'operation' => 'remove', 'quantity' => '2', 'unitCode' => 'kg'], ['materialId' => 2, 'operation' => 'add', 'quantity' => '2', 'unitCode' => 'kg'], ['materialId' => 3, 'operation' => 'add', 'quantity' => '1', 'unitCode' => 'g']]]];
        DB::table('published_menu_versions')->where('id', $from)->update(['payload_json' => json_encode($payload($fromBase, $fromAdjustments))]);
        DB::table('published_menu_versions')->where('id', $to)->update(['payload_json' => json_encode($payload($toBase, $toAdjustments))]);

        $response = $this->getJson("/api/v1/admin/menu-management/versions/{$from}/compare?againstVersionId={$to}", $this->headers($tenant))->assertOk();
        $changes = $response->json('data.changes.recipeChanges');
        $types = array_column($changes, 'type');
        foreach (['base_component_added', 'base_component_removed', 'base_component_changed', 'modifier_adjustment_added', 'modifier_adjustment_removed', 'modifier_adjustment_changed'] as $type) {
            $this->assertContains($type, $types);
        }
        $this->assertSame($changes, $this->getJson("/api/v1/admin/menu-management/versions/{$from}/compare?againstVersionId={$to}", $this->headers($tenant))->assertOk()->json('data.changes.recipeChanges'));

        $bounded = array_merge($toAdjustments, array_map(fn (int $id) => ['optionId' => $id, 'components' => [['materialId' => $id, 'operation' => 'add', 'quantity' => '1', 'unitCode' => 'g']]], range(10, 110)));
        DB::table('published_menu_versions')->where('id', $to)->update(['payload_json' => json_encode($payload($toBase, $bounded))]);
        $boundedResponse = $this->getJson("/api/v1/admin/menu-management/versions/{$from}/compare?againstVersionId={$to}", $this->headers($tenant))->assertOk();
        $this->assertLessThanOrEqual(100, count($boundedResponse->json('data.changes.recipeChanges')));
        $this->assertTrue($boundedResponse->json('data.truncated'));

        DB::table('published_menu_versions')->where('id', $to)->update(['payload_json' => json_encode($payload($fromBase, $fromAdjustments))]);
        $this->assertSame([], $this->getJson("/api/v1/admin/menu-management/versions/{$from}/compare?againstVersionId={$to}", $this->headers($tenant))->assertOk()->json('data.changes.recipeChanges'));
    }

    public function test_comparison_marks_truncation_only_when_a_bounded_category_omits_rows(): void
    {
        $from = new PublishedMenuVersion(['payload_json' => ['menus' => []], 'checksum' => 'from', 'version_number' => 1]);
        $from->id = 1;
        $menus = array_map(fn (int $id) => [
            'id' => $id,
            'sections' => [[
                'id' => $id,
                'products' => [[
                    'placementId' => $id,
                    'productId' => $id,
                    'variants' => [['id' => $id]],
                    'modifierGroups' => [],
                ]],
            ]],
        ], range(1, 60));
        $to = new PublishedMenuVersion(['payload_json' => ['menus' => $menus], 'checksum' => 'to', 'version_number' => 2]);
        $to->id = 2;

        $comparison = app(PublishedMenuVersionComparisonService::class)->compare($from, $to);

        $this->assertFalse($comparison['truncated']);
        $this->assertCount(60, $comparison['changes']['menusAdded']);
        $this->assertCount(60, $comparison['changes']['productsAdded']);
    }

    public function test_recipe_rollback_copies_historical_payload_without_reconstruction(): void
    {
        $tenant = $this->tenant('recipe-rollback');
        $branch = $this->branch($tenant);
        [$publication, $historical] = $this->version($tenant, $branch, 1, 'recipe-a', 'superseded');
        [, $current] = $this->version($tenant, $branch, 2, 'recipe-b', 'current');
        $a = ['context' => ['tenantId' => $tenant, 'schemaVersion' => 2], 'menus' => [['id' => 1, 'sections' => [['id' => 1, 'products' => [['placementId' => 1, 'productId' => 1, 'variants' => [['id' => 1, 'baseRecipe' => [['materialId' => 1, 'quantity' => '18', 'unitCode' => 'g']], 'modifierRecipeAdjustments' => [['optionId' => 2, 'components' => []]]]], 'modifierGroups' => []]]]]]]];
        DB::table('published_menu_versions')->where('id', $historical)->update(['payload_json' => json_encode($a)]);
        DB::table('published_menu_versions')->where('id', $current)->update(['payload_json' => json_encode(['context' => ['tenantId' => $tenant, 'schemaVersion' => 2], 'menus' => []])]);
        $rolled = $this->postJson("/api/v1/admin/menu-management/versions/{$historical}/rollback", ['reason' => 'recipe A'], $this->headers($tenant))->assertOk()->json('data.version.id');
        $this->assertSame($a, json_decode((string) DB::table('published_menu_versions')->where('id', $rolled)->value('payload_json'), true));
        $this->assertDatabaseHas('published_menu_versions', ['id' => $rolled, 'status' => 'current']);
        $this->assertDatabaseHas('published_menu_versions', ['id' => $current, 'status' => 'rolled_back']);
    }

    public function test_schema_v2_history_detail_compare_and_rollback_preserve_the_legacy_payload(): void
    {
        $tenant = $this->tenant('legacy-schema');
        $branch = $this->branch($tenant);
        [, $legacy] = $this->version($tenant, $branch, 1, 'legacy-v2', 'superseded');
        [, $current] = $this->version($tenant, $branch, 2, 'current-v3', 'current');
        $legacyPayload = ['context' => ['tenantId' => $tenant, 'branchId' => $branch, 'channel' => 'pos', 'schemaVersion' => 2], 'menus' => [['id' => 1, 'priority' => 100, 'sections' => []]]];
        $currentPayload = ['context' => ['tenantId' => $tenant, 'branchId' => $branch, 'channel' => 'pos', 'schemaVersion' => 3], 'menus' => [['id' => 1, 'scopeOrder' => 0, 'sections' => []]]];
        DB::table('published_menu_versions')->where('id', $legacy)->update(['payload_json' => json_encode($legacyPayload)]);
        DB::table('published_menu_versions')->where('id', $current)->update(['payload_json' => json_encode($currentPayload)]);

        $this->getJson("/api/v1/admin/menu-management/versions/{$legacy}?includePayload=true", $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.payload.context.schemaVersion', 2)
            ->assertJsonPath('data.payload.menus.0.priority', 100);
        $this->getJson("/api/v1/admin/menu-management/versions/{$legacy}/compare?againstVersionId={$current}", $this->headers($tenant))->assertOk();
        $rolled = $this->postJson("/api/v1/admin/menu-management/versions/{$legacy}/rollback", ['reason' => 'restore v2'], $this->headers($tenant))
            ->assertOk()
            ->json('data.version.id');

        $this->assertSame($legacyPayload, json_decode((string) DB::table('published_menu_versions')->where('id', $legacy)->value('payload_json'), true));
        $this->assertSame($legacyPayload, json_decode((string) DB::table('published_menu_versions')->where('id', $rolled)->value('payload_json'), true));
    }

    private function version(int $tenant, int $branch, int $number, string $checksum, string $status): array
    {
        $publication = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'change_summary' => '{}', 'created_at' => now(), 'updated_at' => now()]);
        $payload = ['context' => ['tenantId' => $tenant], 'menus' => [['id' => 1, 'sections' => [['id' => 1, 'products' => [['placementId' => 1, 'productId' => 1, 'variants' => [['id' => 1, 'effectivePrice' => '4.00']], 'modifierGroups' => []]]]]]]];

        return [$publication, DB::table('published_menu_versions')->insertGetId(['tenant_id' => $tenant, 'menu_publication_id' => $publication, 'branch_id' => $branch, 'channel' => 'pos', 'version_number' => $number, 'payload_json' => json_encode($payload), 'checksum' => $checksum, 'status' => $status, 'published_at' => now(), 'created_at' => now(), 'updated_at' => now()])];
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenant): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'B', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
