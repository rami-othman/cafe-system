<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Maintenance tracking for fixed assets.
 *  - expenses.fixed_asset_id / asset_expense_kind: a plain classification of an ordinary expense against an asset
 *    (no journal effect — the expense keeps posting to its own category account).
 *  - asset_maintenance_contracts: service/warranty contracts with renewal alerts.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('expenses', function (Blueprint $table): void {
            $table->foreignId('fixed_asset_id')->nullable()->after('cost_center_id')->constrained('fixed_assets')->nullOnDelete();
            $table->string('asset_expense_kind', 20)->nullable()->after('fixed_asset_id'); // maintenance|repair|other
            $table->index(['tenant_id', 'fixed_asset_id']);
        });

        Schema::create('asset_maintenance_contracts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('fixed_asset_id')->constrained('fixed_assets')->cascadeOnDelete();
            $table->foreignId('supplier_id')->nullable()->constrained('suppliers')->nullOnDelete();
            $table->string('contract_no', 60)->nullable();
            $table->date('start_date');
            $table->date('end_date');
            $table->decimal('annual_cost', 14, 2)->default(0);
            $table->string('billing', 20)->default('yearly'); // monthly|quarterly|yearly|one_time
            $table->unsignedInteger('renewal_notice_days')->default(30);
            $table->string('status', 20)->default('active'); // active|expired|cancelled
            $table->text('notes')->nullable();
            $table->string('attachment_path')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index(['tenant_id', 'fixed_asset_id']);
            $table->index(['tenant_id', 'status', 'end_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('asset_maintenance_contracts');
        Schema::table('expenses', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'fixed_asset_id']);
            $table->dropConstrainedForeignId('fixed_asset_id');
            $table->dropColumn('asset_expense_kind');
        });
    }
};
