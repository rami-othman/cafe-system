<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $now = now();
        $permissions = ['finance.vouchers.view', 'finance.vouchers.create', 'finance.vouchers.edit', 'finance.vouchers.approve', 'finance.vouchers.post', 'finance.vouchers.reverse', 'finance.receipts.create', 'finance.payments.create', 'finance.transfers.create'];
        foreach (DB::table('users')->where('role', 'manager')->distinct()->pluck('tenant_id') as $tenantId) {
            foreach ($permissions as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'role' => 'manager', 'permission' => $permission],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            }
        }
    }

    public function down(): void
    {
        DB::table('finance_role_permissions')->whereIn('permission', ['finance.vouchers.view', 'finance.vouchers.create', 'finance.vouchers.edit', 'finance.vouchers.approve', 'finance.vouchers.post', 'finance.vouchers.reverse', 'finance.receipts.create', 'finance.payments.create', 'finance.transfers.create'])->delete();
    }
};
