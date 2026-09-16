<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sales_invoices', function (Blueprint $table): void {
            $table->decimal('gross_subtotal', 14, 2)->default(0)->after('subtotal');
            $table->decimal('line_discount_total', 14, 2)->default(0)->after('gross_subtotal');
            $table->string('invoice_discount_type', 16)->nullable()->after('line_discount_total');
            $table->decimal('invoice_discount_value', 14, 2)->default(0)->after('invoice_discount_type');
            $table->decimal('invoice_discount_total', 14, 2)->default(0)->after('invoice_discount_value');
            $table->decimal('additional_charges_total', 14, 2)->default(0)->after('invoice_discount_total');
            $table->decimal('manual_adjustment', 14, 2)->default(0)->after('additional_charges_total');
            $table->decimal('taxable_amount', 14, 2)->default(0)->after('manual_adjustment');
        });

        Schema::table('sales_invoice_lines', function (Blueprint $table): void {
            $table->decimal('base_unit_price', 14, 2)->default(0)->after('unit_price');
            $table->string('discount_type', 16)->nullable()->after('base_unit_price');
            $table->decimal('discount_value', 14, 2)->default(0)->after('discount_type');
            $table->decimal('discount_amount', 14, 2)->default(0)->after('discount_value');
            $table->decimal('line_subtotal', 14, 2)->default(0)->after('discount_amount');
        });

        Schema::create('sales_invoice_charges', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_invoice_id')->constrained()->cascadeOnDelete();
            $table->string('name', 255);
            $table->decimal('amount', 14, 2);
            $table->boolean('taxable')->default(true);
            $table->decimal('tax_total', 14, 2)->default(0);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
            $table->index(['tenant_id', 'sales_invoice_id']);
        });

        // A customer-billed service/charge is revenue, never an operating
        // expense. The mapping is tenant configurable after this safe default.
        $now = now();
        DB::table('tenants')->orderBy('id')->each(function (object $tenant) use ($now): void {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenant->id)->where('code', '4030')->first();
            if (! $account) {
                $accountId = DB::table('financial_accounts')->insertGetId([
                    'tenant_id' => $tenant->id, 'code' => '4030',
                    'name_ar' => 'إيرادات الخدمات والرسوم', 'name_en' => 'Service and Charge Revenue',
                    'account_group' => 'revenue', 'normal_balance' => 'credit',
                    'is_active' => true, 'is_system_protected' => true,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
            } else {
                if ($account->account_group !== 'revenue' || $account->normal_balance !== 'credit') {
                    throw new RuntimeException("Tenant {$tenant->id} has an incompatible account 4030.");
                }
                $accountId = $account->id;
            }
            foreach (['sales.additional_charge_revenue', 'sales.manual_adjustment'] as $key) {
                DB::table('sales_account_mappings')->updateOrInsert(
                    ['tenant_id' => $tenant->id, 'mapping_key' => $key],
                    ['financial_account_id' => $accountId, 'updated_at' => $now, 'created_at' => $now],
                );
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sales_invoice_charges');
        Schema::table('sales_invoice_lines', function (Blueprint $table): void {
            $table->dropColumn(['base_unit_price', 'discount_type', 'discount_value', 'discount_amount', 'line_subtotal']);
        });
        Schema::table('sales_invoices', function (Blueprint $table): void {
            $table->dropColumn(['gross_subtotal', 'line_discount_total', 'invoice_discount_type', 'invoice_discount_value', 'invoice_discount_total', 'additional_charges_total', 'manual_adjustment', 'taxable_amount']);
        });
        DB::table('sales_account_mappings')->whereIn('mapping_key', ['sales.additional_charge_revenue', 'sales.manual_adjustment'])->delete();
    }
};
