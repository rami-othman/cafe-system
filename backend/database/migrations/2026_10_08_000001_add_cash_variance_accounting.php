<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('branches', function (Blueprint $table): void {
            $table->foreignId('cash_variance_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
        });

        Schema::table('shifts', function (Blueprint $table): void {
            $table->foreignId('cash_variance_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
        });

        Schema::table('daily_closings', function (Blueprint $table): void {
            $table->foreignId('cash_variance_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->string('cash_difference_reason', 40)->nullable();
            $table->text('cash_difference_reason_detail')->nullable();
        });

        $now = now();
        foreach (DB::table('tenants')->pluck('id') as $tenantId) {
            if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '6180')->exists()) {
                DB::table('financial_accounts')->insert([
                    'tenant_id' => $tenantId,
                    'code' => '6180',
                    'name_ar' => 'عجز وزيادة الصندوق',
                    'name_en' => 'Cash Over / Short',
                    'account_group' => 'expenses',
                    'normal_balance' => 'debit',
                    'is_active' => true,
                    'is_system_protected' => true,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('daily_closings', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('cash_variance_journal_entry_id');
            $table->dropColumn(['cash_difference_reason', 'cash_difference_reason_detail']);
        });

        Schema::table('shifts', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('cash_variance_journal_entry_id');
        });

        Schema::table('branches', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('cash_variance_account_id');
        });
    }
};
