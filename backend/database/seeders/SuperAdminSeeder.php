<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class SuperAdminSeeder extends Seeder
{
    public function run(): void
    {
        if (app()->environment('production')) {
            return;
        }
        $now = now();
        $permissions = ['dashboard.view', 'tenants.view', 'tenants.create', 'tenants.update', 'tenants.suspend', 'tenants.restore', 'branches.manage', 'tenant_users.manage', 'plans.manage', 'subscriptions.manage', 'analytics.view', 'audit_logs.view', 'announcements.manage', 'system_health.view', 'platform_settings.manage', 'exports.create', 'platform_admins.manage'];
        foreach ($permissions as $permission) {
            DB::table('platform_permissions')->updateOrInsert(['key' => $permission], ['name' => str_replace('.', ' ', $permission), 'created_at' => $now, 'updated_at' => $now]);
        }
        $roles = ['super_admin' => true, 'operations_admin' => false, 'support_admin' => false, 'finance_admin' => false, 'read_only_admin' => false];
        foreach ($roles as $code => $root) {
            DB::table('platform_roles')->updateOrInsert(['code' => $code], ['name' => ucwords(str_replace('_', ' ', $code)), 'is_root' => $root, 'created_at' => $now, 'updated_at' => $now]);
        }
        $rootRole = DB::table('platform_roles')->where('code', 'super_admin')->value('id');
        foreach (DB::table('platform_permissions')->pluck('id') as $permissionId) {
            DB::table('platform_permission_role')->updateOrInsert(['platform_permission_id' => $permissionId, 'platform_role_id' => $rootRole], ['created_at' => $now, 'updated_at' => $now]);
        }
        foreach ([['code' => 'starter', 'name' => 'Starter', 'monthly' => 19, 'yearly' => 190], ['code' => 'growth', 'name' => 'Growth', 'monthly' => 49, 'yearly' => 490], ['code' => 'enterprise', 'name' => 'Enterprise', 'monthly' => 149, 'yearly' => 1490]] as $index => $plan) {
            DB::table('plans')->updateOrInsert(['code' => $plan['code']], ['name' => $plan['name'], 'monthly_price' => $plan['monthly'], 'yearly_price' => $plan['yearly'], 'currency' => 'USD', 'is_active' => true, 'display_order' => $index, 'created_at' => $now, 'updated_at' => $now]);
        }
        $userId = DB::table('users')->updateOrInsert(['email' => env('SUPER_ADMIN_EMAIL', 'admin@cafe618.local')], ['tenant_id' => null, 'name' => env('SUPER_ADMIN_NAME', 'Cafe 618 Platform Admin'), 'password' => Hash::make(env('SUPER_ADMIN_PASSWORD', 'change-me-local-only')), 'role' => 'platform_admin', 'is_active' => true, 'email_verified_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $userId = DB::table('users')->where('email', env('SUPER_ADMIN_EMAIL', 'admin@cafe618.local'))->value('id');
        DB::table('platform_role_user')->updateOrInsert(['platform_role_id' => $rootRole, 'user_id' => $userId], ['created_at' => $now, 'updated_at' => $now]);
    }
}
