<?php

namespace App\Services\Staging;

use App\Models\Branch;
use App\Models\Category;
use App\Models\Menu;
use App\Models\MenuAssignment;
use App\Models\MenuItemPlacement;
use App\Models\MenuSection;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\Tenant;
use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Services\Menu\MenuPublishingService;
use App\Services\UserBranchAssignmentService;
use Illuminate\Support\Facades\DB;

class StagingInitializer
{
    public function __construct(
        private readonly DefaultTenantRoleService $roles,
        private readonly MenuPublishingService $publishing,
        private readonly UserBranchAssignmentService $branches,
    ) {}

    /** @param array{ownerPassword: string, managerPassword: string, employeePassword: string, ownerEmail: string, managerEmail: string, employeeEmail: string, employeeUsername: string} $credentials */
    public function initialize(array $credentials): Tenant
    {
        [$tenant, $branch] = DB::transaction(function () use ($credentials): array {
            $tenant = $this->restoreOrCreate(Tenant::withTrashed()->where('slug', 'cafe-system-618-staging')->first(), Tenant::class, [
                'name' => 'Cafe System 618 staging', 'slug' => 'cafe-system-618-staging', 'status' => 'active', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP',
            ]);
            $roles = $this->roles->ensureForTenant($tenant->id);
            $branch = $this->restoreOrCreate(Branch::withTrashed()->where('tenant_id', $tenant->id)->where('name', 'Downtown')->first(), Branch::class, [
                'tenant_id' => $tenant->id, 'name' => 'Downtown', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'is_active' => true,
            ]);

            $this->user($tenant, $roles['owner']->id, 'Owner', $credentials['ownerEmail'], null, 'owner', $credentials['ownerPassword'], $branch);
            $this->user($tenant, $roles['manager']->id, 'Manager', $credentials['managerEmail'], null, 'manager', $credentials['managerPassword'], $branch);
            $this->user($tenant, $roles['employee']->id, 'Employee / Cashier', $credentials['employeeEmail'], $credentials['employeeUsername'], 'cashier', $credentials['employeePassword'], $branch);

            $category = $this->restoreOrCreate(Category::withTrashed()->where('tenant_id', $tenant->id)->where('name', 'Coffee')->first(), Category::class, [
                'tenant_id' => $tenant->id, 'name' => 'Coffee', 'sort_order' => 0, 'is_active' => true,
            ]);
            $products = collect([
                ['Espresso', 'Regular', '2.50'],
                ['Latte', 'Regular', '4.00'],
                ['Cappuccino', 'Regular', '4.00'],
            ])->map(function (array $item) use ($tenant, $category): Product {
                [$name, $variantName, $price] = $item;
                $product = $this->restoreOrCreate(Product::withTrashed()->where('tenant_id', $tenant->id)->where('name', $name)->first(), Product::class, [
                    'tenant_id' => $tenant->id, 'category_id' => $category->id, 'name' => $name, 'product_type' => 'standard', 'price' => $price, 'cost_price' => '0.00', 'is_active' => true, 'is_stock_tracked' => false,
                ]);
                $this->restoreOrCreate(ProductVariant::withTrashed()->where('product_id', $product->id)->where('name', $variantName)->first(), ProductVariant::class, [
                    'tenant_id' => $tenant->id, 'product_id' => $product->id, 'name' => $variantName, 'base_price' => $price, 'cost_price' => '0.00', 'is_default' => true, 'is_active' => true, 'sort_order' => 0,
                ]);

                return $product;
            });

            $menu = $this->restoreOrCreate(Menu::withTrashed()->where('tenant_id', $tenant->id)->where('name', 'Staging POS Menu')->first(), Menu::class, [
                'tenant_id' => $tenant->id, 'name' => 'Staging POS Menu', 'status' => 'active', 'priority' => 0,
            ]);
            $section = $this->restoreOrCreate(MenuSection::withTrashed()->where('menu_id', $menu->id)->where('name', 'Coffee')->first(), MenuSection::class, [
                'tenant_id' => $tenant->id, 'menu_id' => $menu->id, 'name' => 'Coffee', 'sort_order' => 0, 'is_active' => true,
            ]);
            $products->each(function (Product $product, int $index) use ($tenant, $section): void {
                $this->restoreOrCreate(MenuItemPlacement::withTrashed()->where('menu_section_id', $section->id)->where('product_id', $product->id)->first(), MenuItemPlacement::class, [
                    'tenant_id' => $tenant->id, 'menu_section_id' => $section->id, 'product_id' => $product->id, 'sort_order' => $index, 'is_visible' => true, 'is_featured' => false,
                ]);
            });
            $this->restoreOrCreate(MenuAssignment::query()->where('tenant_id', $tenant->id)->where('menu_id', $menu->id)->where('branch_id', $branch->id)->where('channel', 'pos')->first(), MenuAssignment::class, [
                'tenant_id' => $tenant->id, 'menu_id' => $menu->id, 'branch_id' => $branch->id, 'channel' => 'pos', 'priority' => 0, 'is_active' => true,
            ]);

            return [$tenant, $branch];
        });

        // Publishing owns its transaction, isolation level, and advisory lock.
        // The base staging graph is committed first so a publish failure can be
        // retried safely without reopening that caller-owned transaction.
        if (! DB::table('published_menu_versions')->where('tenant_id', $tenant->id)->where('branch_id', $branch->id)->where('channel', 'pos')->where('status', 'current')->exists()) {
            $this->publishing->publish($tenant->id, ['branchId' => $branch->id, 'channel' => 'pos']);
        }

        return $tenant;
    }

    private function user(Tenant $tenant, int $roleId, string $name, string $email, ?string $username, string $legacyRole, string $password, Branch $branch): void
    {
        $user = User::withTrashed()->where('email', $email)->first();
        if ($user && $user->tenant_id !== $tenant->id) {
            throw new \LogicException("Staging identity {$email} already belongs to a different tenant.");
        }
        $creating = ! $user;
        $user ??= new User;
        if ($user->trashed()) {
            $user->restore();
        }
        $user->fill([
            'tenant_id' => $tenant->id, 'tenant_role_id' => $roleId, 'name' => $name, 'email' => $email, 'username' => $username, 'role' => $legacyRole, 'is_active' => true, 'must_change_password' => true,
        ]);
        if ($creating) {
            $user->password = $password;
        }
        $user->save();
        // Owners have explicit all-branches access and intentionally do not
        // receive a user_branches row. Manager and Employee assignments must
        // use the production service so the pivot tenant is server-derived
        // from this initialized tenant and the branch boundary is validated.
        if ($legacyRole !== DefaultTenantRoleService::OWNER) {
            $this->branches->assign($user, $branch);
        }
    }

    /** @template T of \Illuminate\Database\Eloquent\Model @param T|null $model @param class-string<T> $class @param array<string, mixed> $attributes @return T */
    private function restoreOrCreate($model, string $class, array $attributes)
    {
        $model ??= new $class;
        if (method_exists($model, 'trashed') && $model->trashed()) {
            $model->restore();
        }
        $model->fill($attributes);
        $model->save();

        return $model;
    }
}
