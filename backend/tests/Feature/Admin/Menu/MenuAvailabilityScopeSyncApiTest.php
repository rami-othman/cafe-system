<?php

namespace Tests\Feature\Admin\Menu;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuAvailabilityScopeSyncApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_complete_menu_rule_sync_preserves_every_non_edited_scope_when_sent_back(): void
    {
        $tenant = $this->tenant('alpha');
        $branch = $this->branch($tenant, 'Main');
        $otherBranch = $this->branch($tenant, 'Airport');
        $menu = $this->menu($tenant, 'Breakfast');
        $otherMenu = $this->menu($tenant, 'Lunch');
        $global = $this->rule($tenant, $menu, null, null, null, '08:00', '12:00', 1, true);
        $branchRule = $this->rule($tenant, $menu, $branch, null, 1, '09:00', '13:00', 2, true);
        $channelRule = $this->rule($tenant, $menu, null, 'delivery', 2, '10:00', '14:00', 3, true);
        $otherScope = $this->rule($tenant, $menu, $otherBranch, 'pos', 3, '11:00', '15:00', 4, false);
        $exact = $this->rule($tenant, $menu, $branch, 'pos', 4, '18:00', '02:00', 5, true, '2026-08-01', '2026-08-31');
        $this->rule($tenant, $otherMenu, $branch, 'pos', 5, '06:00', '07:00', 0, true);

        // This is the exact contract the Flutter Cubit uses: submit all Menu
        // rules, replace only the exact scope entry, and preserve every other
        // scope verbatim in the all-rules complete-sync request.
        $rules = [
            ['startTime' => '08:00', 'endTime' => '12:00', 'priority' => 1, 'isActive' => true],
            ['branchId' => $branch, 'dayOfWeek' => 1, 'startTime' => '09:00', 'endTime' => '13:00', 'priority' => 2, 'isActive' => true],
            ['channel' => 'delivery', 'dayOfWeek' => 2, 'startTime' => '10:00', 'endTime' => '14:00', 'priority' => 3, 'isActive' => true],
            ['branchId' => $otherBranch, 'channel' => 'pos', 'dayOfWeek' => 3, 'startTime' => '11:00', 'endTime' => '15:00', 'priority' => 4, 'isActive' => false],
            ['branchId' => $branch, 'channel' => 'pos', 'dayOfWeek' => 4, 'startTime' => '18:00', 'endTime' => '02:00', 'startDate' => '2026-08-02', 'endDate' => '2026-08-31', 'priority' => 9, 'isActive' => true],
        ];
        $response = $this->putJson("/api/v1/admin/menus/{$menu}/availability-rules", ['rules' => $rules], $this->headers($tenant));
        $response->assertOk()->assertJsonCount(5, 'data')->assertJsonPath('data.4.startTime', '18:00')->assertJsonPath('data.4.endTime', '02:00')->assertJsonPath('data.4.startDate', '2026-08-02')->assertJsonPath('data.4.priority', 9);
        foreach ([$global, $branchRule, $channelRule, $otherScope, $exact] as $id) {
            $this->assertSoftDeleted('menu_availability_rules', ['id' => $id]);
        }
        $this->assertDatabaseHas('menu_availability_rules', ['menu_id' => $menu, 'branch_id' => null, 'channel' => null, 'start_time' => '08:00:00', 'deleted_at' => null]);
        $this->assertDatabaseHas('menu_availability_rules', ['menu_id' => $menu, 'branch_id' => $branch, 'channel' => null, 'day_of_week' => 1, 'deleted_at' => null]);
        $this->assertDatabaseHas('menu_availability_rules', ['menu_id' => $menu, 'branch_id' => null, 'channel' => 'delivery', 'day_of_week' => 2, 'deleted_at' => null]);
        $this->assertDatabaseHas('menu_availability_rules', ['menu_id' => $menu, 'branch_id' => $otherBranch, 'channel' => 'pos', 'day_of_week' => 3, 'is_active' => false, 'deleted_at' => null]);
        $this->assertDatabaseHas('menu_availability_rules', ['menu_id' => $otherMenu, 'branch_id' => $branch, 'channel' => 'pos', 'deleted_at' => null]);

        $this->putJson("/api/v1/admin/menus/{$menu}/availability-rules", ['rules' => [['branchId' => $branch, 'channel' => 'pos', 'dayOfWeek' => 7]]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('rules.0.dayOfWeek');
        $this->putJson("/api/v1/admin/menus/{$menu}/availability-rules", ['rules' => [['branchId' => $branch, 'channel' => 'pos', 'startDate' => '2026-08-02', 'endDate' => '2026-08-01']]], $this->headers($tenant))->assertUnprocessable()->assertJsonValidationErrors('rules.0.endDate');
        // Invalid complete sync is rejected before the transaction and leaves
        // the prior multi-scope schedule untouched.
        $this->assertDatabaseCount('menu_availability_rules', 11);
    }

    public function test_rule_routes_are_menu_and_tenant_isolated(): void
    {
        $tenant = $this->tenant('alpha');
        $branch = $this->branch($tenant, 'Main');
        $menu = $this->menu($tenant, 'Breakfast');
        $foreign = $this->menu($this->tenant('beta'), 'Foreign');
        $this->rule($tenant, $menu, $branch, 'pos', 0, '18:00', '02:00', 7, false, '2026-08-01', '2026-08-31');

        $this->getJson("/api/v1/admin/menus/{$foreign}/availability-rules", $this->headers($tenant))->assertNotFound();
        $this->getJson("/api/v1/admin/menus/{$menu}/availability-rules", $this->headers($tenant))->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.priority', 7)->assertJsonPath('data.0.isActive', false)->assertJsonPath('data.0.startTime', '18:00')->assertJsonPath('data.0.endTime', '02:00');
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

    private function rule(int $tenant, int $menu, ?int $branch, ?string $channel, ?int $day, string $start, string $end, int $priority, bool $active, ?string $startDate = null, ?string $endDate = null): int
    {
        return DB::table('menu_availability_rules')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => $channel, 'day_of_week' => $day, 'start_time' => $start, 'end_time' => $end, 'start_date' => $startDate, 'end_date' => $endDate, 'priority' => $priority, 'is_active' => $active, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }
}
