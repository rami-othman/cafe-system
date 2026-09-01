<?php

namespace Tests\Feature;

use App\Models\Branch;
use App\Models\Tenant;
use App\Models\User;
use App\Services\BranchAccessService;
use App\Services\Menu\MenuPublishingService;
use App\Services\Staging\StagingInitializer;
use App\Services\UserBranchAssignmentService;
use DomainException;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class StagingInitializerTest extends TestCase
{
    use DatabaseMigrations;

    protected function tearDown(): void
    {
        app()->forgetInstance(MenuPublishingService::class);

        parent::tearDown();
    }

    public function test_publishing_is_invoked_outside_the_base_data_transaction(): void
    {
        $publisher = Mockery::mock(MenuPublishingService::class);
        $publisher->shouldReceive('publish')->once()->withArgs(function (int $tenantId, array $input): bool {
            $this->assertSame(0, DB::transactionLevel());
            $this->assertSame($this->stagingTenantId(), $tenantId);
            $this->assertSame(['branchId' => $this->stagingBranchId(), 'channel' => 'pos'], $input);

            return true;
        })->andReturn([]);
        app()->instance(MenuPublishingService::class, $publisher);

        $this->initialize();
    }

    public function test_successful_initialization_creates_one_current_published_version(): void
    {
        $tenant = $this->initialize();
        $branch = $this->stagingBranch($tenant);

        $this->assertSame(1, DB::table('menu_publications')->where('tenant_id', $tenant->id)->count());
        $this->assertSame(1, DB::table('published_menu_versions')->where('tenant_id', $tenant->id)->where('branch_id', $branch->id)->where('channel', 'pos')->where('status', 'current')->count());
    }

    public function test_manager_branch_pivot_has_the_initialized_tenant_id(): void
    {
        $tenant = $this->initialize();
        $manager = $this->stagingUser('staging-manager@cafe618.invalid');
        $branch = $this->stagingBranch($tenant);

        $this->assertDatabaseHas('user_branches', [
            'tenant_id' => $tenant->id,
            'user_id' => $manager->id,
            'branch_id' => $branch->id,
        ]);
    }

    public function test_employee_cashier_branch_pivot_has_the_initialized_tenant_id(): void
    {
        $tenant = $this->initialize();
        $employee = $this->stagingUser('staging-cashier@cafe618.invalid');
        $branch = $this->stagingBranch($tenant);

        $this->assertDatabaseHas('user_branches', [
            'tenant_id' => $tenant->id,
            'user_id' => $employee->id,
            'branch_id' => $branch->id,
        ]);
    }

    public function test_owner_uses_all_branches_semantics_without_a_branch_pivot(): void
    {
        $tenant = $this->initialize();
        $owner = $this->stagingUser('staging-owner@cafe618.invalid');
        $branch = $this->stagingBranch($tenant);

        $this->assertTrue($owner->isOwner());
        $this->assertDatabaseMissing('user_branches', ['user_id' => $owner->id]);
        $this->assertTrue(app(BranchAccessService::class)->canAccessBranch($owner, $branch));
    }

    public function test_re_running_initializer_is_idempotent(): void
    {
        $tenant = $this->initialize();
        $before = $this->tenantDomainCounts($tenant->id);

        $second = $this->initialize();

        $this->assertSame($tenant->id, $second->id);
        $this->assertSame($before, $this->tenantDomainCounts($tenant->id));
        $this->assertSame(1, $before['menu_publications']);
        $this->assertSame(1, $before['published_menu_versions']);
    }

    public function test_cross_tenant_branch_pivot_cannot_be_created(): void
    {
        $tenant = $this->initialize();
        $manager = $this->stagingUser('staging-manager@cafe618.invalid');
        $other = Tenant::query()->create(['name' => 'Other Cafe', 'slug' => 'other-cafe', 'status' => 'active']);
        $foreignBranch = Branch::query()->create([
            'tenant_id' => $other->id,
            'name' => 'Foreign',
            'timezone' => 'Asia/Damascus',
            'currency' => 'SYP',
            'is_active' => true,
        ]);

        $this->expectException(DomainException::class);
        try {
            app(UserBranchAssignmentService::class)->assign($manager, $foreignBranch);
        } finally {
            $this->assertDatabaseMissing('user_branches', [
                'user_id' => $manager->id,
                'branch_id' => $foreignBranch->id,
            ]);
        }
    }

    public function test_failed_initialization_rolls_back_the_staging_domain_transactionally(): void
    {
        $other = Tenant::query()->create(['name' => 'Other Cafe', 'slug' => 'other-cafe', 'status' => 'active']);
        User::query()->create([
            'tenant_id' => $other->id,
            'name' => 'Conflicting Owner',
            'email' => 'staging-owner@cafe618.invalid',
            'password' => 'password',
            'role' => 'owner',
            'is_active' => true,
        ]);

        $this->expectException(\LogicException::class);
        try {
            $this->initializer()->initialize($this->credentials());
        } finally {
            $this->assertDatabaseMissing('tenants', ['slug' => 'cafe-system-618-staging']);
            $this->assertSame(0, DB::table('branches')->count());
            $this->assertSame(0, DB::table('tenant_roles')->count());
            $this->assertSame(1, DB::table('users')->count());
            $this->assertSame(0, DB::table('user_branches')->count());
            $this->assertSame(0, DB::table('categories')->count());
            $this->assertSame(0, DB::table('products')->count());
            $this->assertSame(0, DB::table('product_variants')->count());
            $this->assertSame(0, DB::table('menus')->count());
            $this->assertSame(0, DB::table('menu_sections')->count());
            $this->assertSame(0, DB::table('menu_item_placements')->count());
            $this->assertSame(0, DB::table('menu_assignments')->count());
            $this->assertSame(0, DB::table('menu_publications')->count());
            $this->assertSame(0, DB::table('published_menu_versions')->count());
        }
    }

    public function test_publication_failure_leaves_committed_base_staging_data_intact(): void
    {
        $this->failingPublisher();

        try {
            $this->initialize();
            $this->fail('Expected publication to fail.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Publication failed.', $exception->getMessage());
        }

        $tenant = Tenant::query()->where('slug', 'cafe-system-618-staging')->firstOrFail();
        $counts = $this->tenantDomainCounts($tenant->id);
        $this->assertSame(3, $counts['users']);
        $this->assertSame(2, $counts['user_branches']);
        $this->assertSame(3, $counts['tenant_roles']);
        $this->assertSame(1, $counts['branches']);
        $this->assertSame(1, $counts['categories']);
        $this->assertSame(3, $counts['products']);
        $this->assertSame(3, $counts['product_variants']);
        $this->assertSame(1, $counts['menus']);
        $this->assertSame(3, $counts['menu_item_placements']);
        $this->assertSame(1, $counts['menu_assignments']);
        $this->assertSame(0, $counts['menu_publications']);
        $this->assertSame(0, $counts['published_menu_versions']);
    }

    public function test_rerun_after_publication_failure_recovers_without_duplicate_staging_data(): void
    {
        $this->failingPublisher();

        try {
            $this->initialize();
            $this->fail('Expected publication to fail.');
        } catch (RuntimeException) {
            // The committed base graph is intentionally retried below.
        }
        app()->forgetInstance(MenuPublishingService::class);

        $tenant = $this->initialize();

        $this->assertSame(3, DB::table('users')->where('tenant_id', $tenant->id)->count());
        $this->assertSame(2, DB::table('user_branches')->where('tenant_id', $tenant->id)->count());
        $this->assertSame(1, DB::table('menu_assignments')->where('tenant_id', $tenant->id)->count());
        $this->assertSame(1, DB::table('menu_publications')->where('tenant_id', $tenant->id)->count());
        $this->assertSame(1, DB::table('published_menu_versions')->where('tenant_id', $tenant->id)->where('status', 'current')->count());
    }

    private function initialize(): Tenant
    {
        return $this->initializer()->initialize($this->credentials());
    }

    private function initializer(): StagingInitializer
    {
        return app(StagingInitializer::class);
    }

    /** @return array{ownerPassword: string, managerPassword: string, employeePassword: string, ownerEmail: string, managerEmail: string, employeeEmail: string, employeeUsername: string} */
    private function credentials(): array
    {
        return [
            'ownerPassword' => 'OwnerPassword1',
            'managerPassword' => 'ManagerPassword1',
            'employeePassword' => 'CashierPassword1',
            'ownerEmail' => 'staging-owner@cafe618.invalid',
            'managerEmail' => 'staging-manager@cafe618.invalid',
            'employeeEmail' => 'staging-cashier@cafe618.invalid',
            'employeeUsername' => 'staging-cashier',
        ];
    }

    private function stagingUser(string $email): User
    {
        return User::query()->where('email', $email)->firstOrFail();
    }

    private function stagingBranch(Tenant $tenant): Branch
    {
        return Branch::query()->where('tenant_id', $tenant->id)->where('name', 'Downtown')->firstOrFail();
    }

    private function stagingTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-system-618-staging')->value('id');
    }

    private function stagingBranchId(): int
    {
        return (int) DB::table('branches')->where('tenant_id', $this->stagingTenantId())->where('name', 'Downtown')->value('id');
    }

    private function failingPublisher(): void
    {
        $publisher = Mockery::mock(MenuPublishingService::class);
        $publisher->shouldReceive('publish')->once()->andThrow(new RuntimeException('Publication failed.'));
        app()->instance(MenuPublishingService::class, $publisher);
    }

    /** @return array<string, int> */
    private function tenantDomainCounts(int $tenantId): array
    {
        return [
            'users' => DB::table('users')->where('tenant_id', $tenantId)->count(),
            'user_branches' => DB::table('user_branches')->where('tenant_id', $tenantId)->count(),
            'tenant_roles' => DB::table('tenant_roles')->where('tenant_id', $tenantId)->count(),
            'branches' => DB::table('branches')->where('tenant_id', $tenantId)->count(),
            'categories' => DB::table('categories')->where('tenant_id', $tenantId)->count(),
            'products' => DB::table('products')->where('tenant_id', $tenantId)->count(),
            'product_variants' => DB::table('product_variants')->where('tenant_id', $tenantId)->count(),
            'menus' => DB::table('menus')->where('tenant_id', $tenantId)->count(),
            'menu_sections' => DB::table('menu_sections')->where('tenant_id', $tenantId)->count(),
            'menu_item_placements' => DB::table('menu_item_placements')->where('tenant_id', $tenantId)->count(),
            'menu_assignments' => DB::table('menu_assignments')->where('tenant_id', $tenantId)->count(),
            'menu_publications' => DB::table('menu_publications')->where('tenant_id', $tenantId)->count(),
            'published_menu_versions' => DB::table('published_menu_versions')->where('tenant_id', $tenantId)->count(),
        ];
    }
}
