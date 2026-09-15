<?php

use App\Support\FinanceAccess;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $now = now();
        foreach (DB::table('users')->whereIn('role', ['cashier', 'employee'])->distinct()->pluck('tenant_id') as $tenantId) {
            foreach (FinanceAccess::defaultPermissionsForRole('cashier') as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'role' => 'cashier', 'permission' => $permission],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            }
        }
    }

    public function down(): void
    {
        DB::table('finance_role_permissions')
            ->where('role', 'cashier')
            ->whereIn('permission', FinanceAccess::defaultPermissionsForRole('cashier'))
            ->delete();
    }
};
