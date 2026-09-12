<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private const PERMISSIONS = [
        'finance.customer_payments.view', 'finance.customer_payments.create', 'finance.customer_payments.reverse',
    ];

    public function up(): void
    {
        $now = now();
        DB::table('users')->where('role', 'manager')->select('tenant_id')->distinct()->orderBy('tenant_id')->each(function (object $row) use ($now): void {
            foreach (self::PERMISSIONS as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(
                    ['tenant_id' => $row->tenant_id, 'role' => 'manager', 'permission' => $permission],
                    ['updated_at' => $now, 'created_at' => $now],
                );
            }
        });
    }

    public function down(): void
    {
        DB::table('finance_role_permissions')->where('role', 'manager')->whereIn('permission', self::PERMISSIONS)->delete();
    }
};
