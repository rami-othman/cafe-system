<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        foreach (['supplier_invoices', 'sales_invoices', 'sales_credit_notes'] as $table) {
            Schema::table($table, function (Blueprint $t): void {
                $t->text('backdate_reason')->nullable();
                $t->foreignId('backdated_by')->nullable()->constrained('users')->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        foreach (['supplier_invoices', 'sales_invoices', 'sales_credit_notes'] as $table) {
            Schema::table($table, function (Blueprint $t): void {
                $t->dropConstrainedForeignId('backdated_by');
                $t->dropColumn('backdate_reason');
            });
        }
    }
};
