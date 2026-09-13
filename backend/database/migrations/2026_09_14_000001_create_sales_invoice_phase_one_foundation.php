<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            $table->string('customer_number', 64)->nullable()->after('tenant_id');
            $table->string('customer_type', 32)->default('registered')->after('name');
            $table->string('tax_number', 128)->nullable()->after('email');
            $table->unsignedInteger('default_credit_terms_days')->default(0)->after('tax_number');
            $table->boolean('is_walk_in')->default(false)->after('is_active');
            $table->boolean('is_system_protected')->default(false)->after('is_walk_in');
            $table->foreignId('created_by')->nullable()->after('is_system_protected')->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->after('created_by')->constrained('users')->nullOnDelete();
            $table->unique(['tenant_id', 'customer_number'], 'customers_tenant_customer_number_unique');
            $table->index(['tenant_id', 'is_active'], 'customers_tenant_active_index');
        });

        Schema::create('sales_account_mappings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->string('mapping_key', 120);
            $table->foreignId('financial_account_id')->constrained('financial_accounts')->restrictOnDelete();
            $table->timestamps();
            $table->unique(['tenant_id', 'mapping_key']);
        });

        Schema::create('sales_invoices', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('branch_id')->constrained()->restrictOnDelete();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->string('invoice_number', 64);
            $table->date('invoice_date');
            $table->date('due_date')->nullable();
            $table->string('currency_code', 3)->default('SYP');
            $table->string('reference', 128)->nullable();
            $table->text('notes')->nullable();
            $table->string('status', 32)->default('draft');
            $table->decimal('tax_rate', 8, 6)->default(0);
            $table->decimal('subtotal', 14, 2)->default(0);
            $table->decimal('discount_total', 14, 2)->default(0);
            $table->decimal('tax_total', 14, 2)->default(0);
            $table->decimal('total', 14, 2)->default(0);
            $table->string('idempotency_key', 128)->nullable();
            $table->string('request_fingerprint', 64)->nullable();
            $table->foreignId('posted_journal_entry_id')->nullable()->constrained('journal_entries')->restrictOnDelete();
            $table->foreignId('reversal_journal_entry_id')->nullable()->constrained('journal_entries')->restrictOnDelete();
            $table->foreignId('reversal_of_invoice_id')->nullable()->constrained('sales_invoices')->restrictOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('cancelled_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('cancelled_at')->nullable();
            $table->string('cancellation_reason', 500)->nullable();
            $table->timestamp('posted_at')->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'invoice_number']);
            $table->unique(['tenant_id', 'idempotency_key']);
            $table->index(['tenant_id', 'branch_id', 'status', 'invoice_date']);
            $table->index(['tenant_id', 'customer_id', 'invoice_date']);
        });

        Schema::create('sales_invoice_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_invoice_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('line_number');
            $table->string('product_name', 255);
            $table->string('product_sku', 128)->nullable();
            $table->text('description')->nullable();
            $table->decimal('quantity', 15, 3);
            $table->decimal('unit_price', 14, 2);
            $table->decimal('discount_total', 14, 2)->default(0);
            $table->decimal('tax_rate', 8, 6)->default(0);
            $table->decimal('tax_total', 14, 2)->default(0);
            $table->decimal('subtotal', 14, 2)->default(0);
            $table->decimal('total', 14, 2)->default(0);
            $table->foreignId('inventory_movement_id')->nullable()->constrained('stock_movements')->restrictOnDelete();
            $table->decimal('cogs_total', 14, 2)->nullable();
            $table->timestamps();
            $table->unique(['sales_invoice_id', 'line_number']);
        });

        Schema::create('sales_invoice_costs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_invoice_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_invoice_line_id')->nullable()->constrained('sales_invoice_lines')->cascadeOnDelete();
            $table->foreignId('inventory_movement_id')->nullable()->constrained('stock_movements')->restrictOnDelete();
            $table->decimal('cost_amount', 14, 2);
            $table->timestamps();
            $table->index(['tenant_id', 'sales_invoice_id']);
        });

        $now = now();
        DB::table('tenants')->orderBy('id')->each(function (object $tenant) use ($now): void {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenant->id)->where('code', '1200')->first();
            if ($account && ($account->account_group !== 'assets' || $account->normal_balance !== 'debit')) {
                throw new RuntimeException("Tenant {$tenant->id} has an incompatible account 1200; expected an asset account with debit normal balance.");
            }
            if (! $account) {
                $accountId = DB::table('financial_accounts')->insertGetId([
                    'tenant_id' => $tenant->id, 'code' => '1200', 'name_ar' => 'الذمم المدينة', 'name_en' => 'Accounts Receivable',
                    'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true, 'is_system_protected' => true,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
            } else {
                $accountId = $account->id;
            }
            DB::table('sales_account_mappings')->updateOrInsert(
                ['tenant_id' => $tenant->id, 'mapping_key' => 'sales.accounts_receivable'],
                ['financial_account_id' => $accountId, 'updated_at' => $now, 'created_at' => $now],
            );
            if (! DB::table('customers')->where('tenant_id', $tenant->id)->where('is_walk_in', true)->exists()) {
                DB::table('customers')->insert([
                    'tenant_id' => $tenant->id, 'customer_number' => 'CASH-CUSTOMER', 'name' => 'عميل نقدي', 'customer_type' => 'walk_in',
                    'default_credit_terms_days' => 0, 'is_active' => true, 'is_walk_in' => true, 'is_system_protected' => true,
                    'total_spent' => 0, 'visits_count' => 0, 'created_at' => $now, 'updated_at' => $now,
                ]);
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sales_invoice_costs');
        Schema::dropIfExists('sales_invoice_lines');
        Schema::dropIfExists('sales_invoices');
        Schema::dropIfExists('sales_account_mappings');
        Schema::table('customers', function (Blueprint $table): void {
            $table->dropUnique('customers_tenant_customer_number_unique');
            $table->dropIndex('customers_tenant_active_index');
            $table->dropConstrainedForeignId('updated_by');
            $table->dropConstrainedForeignId('created_by');
            $table->dropColumn(['customer_number', 'customer_type', 'tax_number', 'default_credit_terms_days', 'is_walk_in', 'is_system_protected']);
        });
    }
};
