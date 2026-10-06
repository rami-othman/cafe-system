<?php

// Loaded through artisan tinker only after the existing compose override.
// Add a dedicated test tenant; never reset databases or modify existing users.
use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Services\FinancialSetupService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

$expectedDatabase = getenv('DISCOUNT_PLAN2_FIXTURE_DATABASE') ?: 'cafe_system_618_testing';
if (! in_array($expectedDatabase, ['cafe_system_618_testing', 'cafe_discount_acceptance_testing'], true)
    || ! app()->environment('testing')
    || config('database.connections.pgsql.host') !== 'accept-postgres'
    || DB::selectOne('select current_database() as name')->name !== $expectedDatabase
    || ($expectedDatabase === 'cafe_system_618_testing' && ! config('discount_engine.isolated_automatic'))) {
    throw new RuntimeException('Isolated Automatic acceptance identity required.');
}
$ids = DB::transaction(function (): array {
    $tenant = DB::table('tenants')->where('slug', 'discount-plan2-live-20261004')->value('id');
    if (! $tenant) {
        $tenant = DB::table('tenants')->insertGetId([
            'name' => 'Plan 2 Acceptance', 'slug' => 'discount-plan2-live-20261004',
            'currency' => 'SYP', 'timezone' => 'Asia/Damascus',
        ]);
    }
    $roles = app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
    $users = [];
    foreach (['owner', 'manager', 'employee'] as $role) {
        $email = 'plan2-'.$role.'@acceptance.invalid';
        $user = User::query()->where('tenant_id', $tenant)->where('email', $email)->first();
        if (! $user) {
            $user = User::query()->create([
                'tenant_id' => $tenant, 'tenant_role_id' => $roles[$role]->id,
                'name' => 'Plan 2 '.$role, 'email' => $email,
                'username' => 'plan2-'.$role,
                // Explicit hashing as in TenantEmployeeService; User's hashed
                // cast also enforces this boundary. No existing hash is read.
                'password' => Hash::make($role === 'employee' ? '642618' : 'Plan2-acceptance-only'),
                'role' => $role === 'employee' ? 'cashier' : $role,
                'is_active' => true, 'must_change_password' => false,
            ]);
        }
        $users[$role] = $user->id;
    }
    $branch = DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Plan 2 branch')->value('id');
    if (! $branch) {
        $branch = DB::table('branches')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'Plan 2 branch', 'is_active' => true,
            'timezone' => 'Asia/Damascus',
        ]);
    }
    foreach (['manager', 'employee'] as $role) {
        if (! DB::table('user_branches')->where('user_id', $users[$role])->where('branch_id', $branch)->exists()) {
            DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $users[$role], 'branch_id' => $branch]);
        }
    }
    app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $users['owner']);
    return compact('tenant', 'branch', 'users');
});
echo json_encode($ids, JSON_THROW_ON_ERROR).PHP_EOL;
