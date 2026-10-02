<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Cash overage and cash shortage must never share one account: a shortage is an expense (6180),
 * an overage is income (4040). Each branch may pick its own account for each direction.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('branches', function (Blueprint $table): void {
            $table->foreignId('cash_over_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
        });

        $now = now();
        foreach (DB::table('tenants')->pluck('id') as $tenantId) {
            // Rename only while it still carries the old combined default name.
            DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '6180')
                ->where('name_ar', 'عجز وزيادة الصندوق')
                ->update(['name_ar' => 'عجز الصندوق', 'name_en' => 'Cash Shortage', 'updated_at' => $now]);
            if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '4040')->exists()) {
                DB::table('financial_accounts')->insert([
                    'tenant_id' => $tenantId, 'code' => '4040', 'name_ar' => 'زيادة الصندوق', 'name_en' => 'Cash Overage',
                    'account_group' => 'revenue', 'normal_balance' => 'credit', 'is_active' => true,
                    'is_system_protected' => true, 'created_at' => $now, 'updated_at' => $now,
                ]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('branches', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('cash_over_account_id');
        });
    }
};
