<?php

use App\Support\FinanceAccess;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $now = now();
        foreach (DB::table('users')->select('tenant_id')->where('role', 'manager')->distinct()->pluck('tenant_id') as $tenantId) {
            foreach (FinanceAccess::defaultPermissionsForRole('manager') as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'role' => 'manager', 'permission' => $permission],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            }
        }

        $driver = DB::getDriverName();
        if (in_array($driver, ['pgsql', 'sqlite'], true)) {
            DB::statement('CREATE UNIQUE INDEX IF NOT EXISTS finance_approval_rules_active_global_unique ON finance_approval_rules (tenant_id, action_type, role) WHERE is_active = true AND branch_id IS NULL');
            DB::statement('CREATE UNIQUE INDEX IF NOT EXISTS finance_approval_rules_active_branch_unique ON finance_approval_rules (tenant_id, action_type, role, branch_id) WHERE is_active = true AND branch_id IS NOT NULL');
        }
    }

    public function down(): void
    {
        if (in_array(DB::getDriverName(), ['pgsql', 'sqlite'], true)) {
            DB::statement('DROP INDEX IF EXISTS finance_approval_rules_active_global_unique');
            DB::statement('DROP INDEX IF EXISTS finance_approval_rules_active_branch_unique');
        }
    }
};
