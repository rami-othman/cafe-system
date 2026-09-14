<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 5 reporting/aging additive indexes — none of these change data or
 * existing columns. `sales_invoices` already has [tenant_id, branch_id,
 * status, invoice_date]; a tenant-wide (all-branches) AR-aging scan by
 * due_date does not benefit from that composite, hence the extra one below.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sales_invoices', function (Blueprint $table): void {
            $table->index(['tenant_id', 'status', 'due_date'], 'sales_invoices_tenant_status_due_date_index');
        });
        Schema::table('customer_payments', function (Blueprint $table): void {
            $table->index(['tenant_id', 'customer_id', 'payment_date'], 'customer_payments_tenant_customer_date_index');
        });
        Schema::table('customer_refunds', function (Blueprint $table): void {
            $table->index(['tenant_id', 'customer_id', 'refund_date'], 'customer_refunds_tenant_customer_date_index');
        });
        Schema::table('sales_credit_notes', function (Blueprint $table): void {
            $table->index(['tenant_id', 'customer_id', 'credit_date'], 'sales_credit_notes_tenant_customer_date_index');
        });
    }

    public function down(): void
    {
        Schema::table('sales_invoices', fn (Blueprint $table) => $table->dropIndex('sales_invoices_tenant_status_due_date_index'));
        Schema::table('customer_payments', fn (Blueprint $table) => $table->dropIndex('customer_payments_tenant_customer_date_index'));
        Schema::table('customer_refunds', fn (Blueprint $table) => $table->dropIndex('customer_refunds_tenant_customer_date_index'));
        Schema::table('sales_credit_notes', fn (Blueprint $table) => $table->dropIndex('sales_credit_notes_tenant_customer_date_index'));
    }
};
