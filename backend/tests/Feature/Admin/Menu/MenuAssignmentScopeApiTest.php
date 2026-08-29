<?php

namespace Tests\Feature\Admin\Menu;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuAssignmentScopeApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_scope_get_validates_context_filters_exactly_and_returns_archived_menu_diagnostics(): void
    {
        $tenant = $this->tenant('alpha');
        $branch = $this->branch($tenant, 'Main');
        $otherBranch = $this->branch($tenant, 'Airport');
        $first = $this->menu($tenant, 'Breakfast');
        $archived = $this->menu($tenant, 'Seasonal');
        $otherBranchMenu = $this->menu($tenant, 'Airport only');
        $otherChannelMenu = $this->menu($tenant, 'Kiosk only');
        $this->postJson("/api/v1/admin/menus/{$archived}/archive", [], $this->headers($tenant))->assertOk();

        $this->assignment($tenant, $first, $branch, 'pos', 4, true);
        $this->assignment($tenant, $archived, $branch, 'pos', 1, false);
        $this->assignment($tenant, $otherBranchMenu, $otherBranch, 'pos', 0, true);
        $this->assignment($tenant, $otherChannelMenu, $branch, 'kiosk', 0, true);

        $this->getJson('/api/v1/admin/menu-management/assignments', $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors(['branchId', 'channel']);
        $this->getJson("/api/v1/admin/menu-management/assignments?branchId={$branch}&channel=invalid", $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('channel');
        $foreignBranch = $this->branch($this->tenant('beta'), 'Foreign');
        $this->getJson("/api/v1/admin/menu-management/assignments?branchId={$foreignBranch}&channel=pos", $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('branchId');

        $response = $this->getJson("/api/v1/admin/menu-management/assignments?branchId={$branch}&channel=pos", $this->headers($tenant));
        $response->assertOk()->assertJsonCount(2, 'data')->assertJsonPath('data.0.menuId', $archived)->assertJsonPath('data.0.priority', 1)->assertJsonPath('data.0.menu.archivedAt', fn ($value) => $value !== null)->assertJsonPath('data.1.menuId', $first);
        $this->assertArrayNotHasKey('tenantId', $response->json('data.0'));
        $this->assertArrayNotHasKey('tenantId', $response->json('data.0.menu'));
    }

    public function test_complete_scope_sync_is_atomic_normalized_and_isolated(): void
    {
        $tenant = $this->tenant('alpha');
        $branch = $this->branch($tenant, 'Main');
        $otherBranch = $this->branch($tenant, 'Airport');
        $first = $this->menu($tenant, 'Breakfast');
        $second = $this->menu($tenant, 'Lunch');
        $other = $this->menu($tenant, 'Elsewhere');
        $section = $this->postJson("/api/v1/admin/menus/{$first}/sections", ['name' => 'Coffee'], $this->headers($tenant))->assertCreated()->json('data.id');
        $this->assignment($tenant, $other, $otherBranch, 'pos', 9, true);
        $this->assignment($tenant, $other, $branch, 'kiosk', 8, true);

        $response = $this->putJson('/api/v1/admin/menu-management/assignments', [
            'branchId' => $branch,
            'channel' => 'pos',
            'assignments' => [
                ['menuId' => $second, 'priority' => 91, 'isActive' => false],
                ['menuId' => $first, 'priority' => -3, 'isActive' => true],
            ],
        ], $this->headers($tenant));
        $response->assertOk()->assertJsonPath('data.0.menuId', $second)->assertJsonPath('data.0.priority', 0)->assertJsonPath('data.0.isActive', false)->assertJsonPath('data.1.menuId', $first)->assertJsonPath('data.1.priority', 1);
        $this->assertDatabaseHas('menu_sections', ['id' => $section, 'menu_id' => $first, 'deleted_at' => null]);
        $this->assertDatabaseHas('menus', ['id' => $first, 'deleted_at' => null]);

        $this->putJson('/api/v1/admin/menu-management/assignments', [
            'branchId' => $branch,
            'channel' => 'pos',
            'assignments' => [['menuId' => $first, 'isActive' => false]],
        ], $this->headers($tenant))->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.isActive', false);
        $this->assertDatabaseMissing('menu_assignments', ['menu_id' => $second, 'branch_id' => $branch, 'channel' => 'pos']);
        $this->assertDatabaseHas('menu_assignments', ['menu_id' => $other, 'branch_id' => $otherBranch, 'channel' => 'pos', 'priority' => 9]);
        $this->assertDatabaseHas('menu_assignments', ['menu_id' => $other, 'branch_id' => $branch, 'channel' => 'kiosk', 'priority' => 8]);

        $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branch, 'channel' => 'pos', 'assignments' => [['menuId' => $first], ['menuId' => $first]]], $this->headers($tenant))->assertUnprocessable();
        $foreign = $this->menu($this->tenant('beta'), 'Foreign');
        $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branch, 'channel' => 'pos', 'assignments' => [['menuId' => $foreign]]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('assignments');
        $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branch, 'channel' => 'pos', 'assignments' => [['menuId' => 999999]]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('assignments');

        $archived = $this->menu($tenant, 'Archived');
        $this->postJson("/api/v1/admin/menus/{$archived}/archive", [], $this->headers($tenant))->assertOk();
        $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branch, 'channel' => 'pos', 'assignments' => [['menuId' => $archived]]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('menu');
        // A mixed invalid submission is rejected before the transaction, so it
        // cannot remove the previously saved assignment or create the valid Menu.
        $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branch, 'channel' => 'pos', 'assignments' => [['menuId' => $second], ['menuId' => 999999]]], $this->headers($tenant))->assertUnprocessable();
        $this->assertDatabaseHas('menu_assignments', ['menu_id' => $first, 'branch_id' => $branch, 'channel' => 'pos', 'is_active' => false]);
        $this->assertDatabaseMissing('menu_assignments', ['menu_id' => $second, 'branch_id' => $branch, 'channel' => 'pos']);

        // Repeating the same complete set is idempotent and remains one row.
        foreach ([true, true] as $_) {
            $this->putJson('/api/v1/admin/menu-management/assignments', ['branchId' => $branch, 'channel' => 'pos', 'assignments' => [['menuId' => $first, 'isActive' => false]]], $this->headers($tenant))->assertOk();
        }
        $this->assertDatabaseCount('menu_assignments', 3);
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenant, string $name): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function menu(int $tenant, string $name): int
    {
        return $this->postJson('/api/v1/admin/menus', ['name' => $name], $this->headers($tenant))->assertCreated()->json('data.id');
    }

    private function assignment(int $tenant, int $menu, int $branch, string $channel, int $priority, bool $active): void
    {
        DB::table('menu_assignments')->insert(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => $channel, 'priority' => $priority, 'is_active' => $active, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
