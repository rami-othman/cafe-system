<?php

namespace Tests\Feature\Admin\MenuVersionHistory;

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
