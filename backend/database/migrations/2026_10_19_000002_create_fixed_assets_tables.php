<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Fixed assets: categories (with default accounts + depreciation policy), sub-locations inside a
 * branch, the asset card, an append-only asset ledger (fixed_asset_transactions) and
 * depreciation runs. Book value is always derived from the ledger, never stored as a fact.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fixed_asset_settings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->unique()->constrained();
            $table->string('depreciation_frequency', 20)->default('monthly'); // monthly|quarterly|semiannual|annual
            $table->string('default_method', 30)->default('straight_line');
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('asset_categories', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('parent_id')->nullable()->constrained('asset_categories')->nullOnDelete();
            $table->string('code', 40);
            $table->string('name_ar');
            $table->string('name_en')->nullable();
            $table->foreignId('asset_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('accumulated_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('expense_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('gain_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('loss_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->string('default_method', 30)->default('straight_line'); // straight_line|none
            $table->unsignedInteger('default_life_months')->nullable();
            $table->decimal('default_salvage_percent', 5, 2)->default(0);
            $table->boolean('is_active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'code']);
        });

        Schema::create('asset_locations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->index(['tenant_id', 'branch_id']);
        });

        Schema::create('fixed_assets', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('code', 40);
            $table->string('name_ar');
            $table->string('name_en')->nullable();
            $table->string('barcode', 80)->nullable();
            $table->string('serial_number', 120)->nullable();
            $table->foreignId('category_id')->nullable()->constrained('asset_categories')->nullOnDelete();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('location_id')->nullable()->constrained('asset_locations')->nullOnDelete();
            $table->string('status', 30)->default('draft'); // draft|active|fully_depreciated|disposed
            $table->date('acquisition_date');
            $table->date('depreciation_start_date');
            $table->decimal('acquisition_cost', 14, 2);
            $table->decimal('salvage_value', 14, 2)->default(0);
            $table->unsignedInteger('useful_life_months')->default(0);
            $table->string('method', 30)->default('straight_line');
            $table->foreignId('asset_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('accumulated_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('expense_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('gain_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('loss_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('funding_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->unsignedBigInteger('supplier_id')->nullable();
            $table->unsignedBigInteger('supplier_invoice_id')->nullable();
            $table->unsignedBigInteger('supplier_invoice_line_id')->nullable();
            $table->boolean('is_opening')->default(false);
            $table->decimal('opening_accumulated', 14, 2)->default(0);
            $table->date('depreciated_until')->nullable();
            $table->string('manufacturer')->nullable();
            $table->date('warranty_end_date')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('activated_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'status', 'branch_id']);
            $table->index(['tenant_id', 'supplier_invoice_line_id']);
        });

        Schema::create('depreciation_runs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('run_number', 40);
            $table->date('period_end');
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('category_id')->nullable()->constrained('asset_categories')->nullOnDelete();
            $table->foreignId('fixed_asset_id')->nullable()->constrained('fixed_assets')->nullOnDelete();
            $table->boolean('filter_company_only')->default(false);
            $table->string('status', 20)->default('posted'); // posted|reversed
            $table->string('trigger', 30)->default('manual'); // manual|addition|disposal|transfer
            $table->decimal('total_amount', 14, 2)->default(0);
            $table->unsignedInteger('assets_count')->default(0);
            $table->text('description')->nullable();
            $table->unsignedBigInteger('journal_entry_id')->nullable();
            $table->unsignedBigInteger('reversal_journal_entry_id')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reversed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reversed_at')->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'run_number']);
        });

        Schema::create('fixed_asset_transactions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('fixed_asset_id')->constrained('fixed_assets');
            $table->string('type', 30); // opening|acquisition|addition|depreciation|disposal|transfer
            $table->date('transaction_date');
            $table->decimal('cost_amount', 14, 2)->default(0);          // signed effect on cost
            $table->decimal('depreciation_amount', 14, 2)->default(0);  // signed effect on accumulated depreciation
            $table->integer('life_change_months')->default(0);
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('to_branch_id')->nullable()->constrained('branches')->nullOnDelete();
            $table->unsignedBigInteger('from_location_id')->nullable();
            $table->unsignedBigInteger('to_location_id')->nullable();
            $table->decimal('proceeds', 14, 2)->nullable();
            $table->decimal('gain_loss', 14, 2)->nullable();
            $table->foreignId('counter_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->unsignedBigInteger('journal_entry_id')->nullable();
            $table->unsignedBigInteger('reversal_journal_entry_id')->nullable();
            $table->foreignId('depreciation_run_id')->nullable()->constrained('depreciation_runs')->nullOnDelete();
            $table->date('period_from')->nullable();
            $table->date('period_to')->nullable();
            $table->date('previous_depreciated_until')->nullable();
            $table->string('previous_status', 30)->nullable();
            $table->text('description')->nullable();
            $table->timestamp('voided_at')->nullable();
            $table->foreignId('voided_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index(['tenant_id', 'fixed_asset_id', 'transaction_date']);
            $table->index(['tenant_id', 'type', 'transaction_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fixed_asset_transactions');
        Schema::dropIfExists('depreciation_runs');
        Schema::dropIfExists('fixed_assets');
        Schema::dropIfExists('asset_locations');
        Schema::dropIfExists('asset_categories');
        Schema::dropIfExists('fixed_asset_settings');
    }
};
