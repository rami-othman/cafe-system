<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const DEFAULT_MAPPINGS = [
        'sales.revenue' => '4000', 'sales.tax_payable' => '2010', 'sales.cost_of_goods_sold' => '5000', 'sales.inventory_asset' => '1100',
    ];

    public function up(): void
    {
        Schema::create('customer_receivables', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->foreignId('sales_invoice_id')->constrained()->restrictOnDelete();
            $table->foreignId('journal_entry_id')->constrained()->restrictOnDelete();
            $table->decimal('original_amount', 14, 2);
            $table->date('due_date')->nullable();
            $table->timestamp('posted_at');
            $table->timestamps();
            $table->unique(['tenant_id', 'sales_invoice_id']);
            $table->index(['tenant_id', 'customer_id', 'due_date']);
        });

        Schema::create('sales_invoice_postings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_invoice_id')->constrained()->cascadeOnDelete();
            $table->string('idempotency_key', 128);
            $table->string('request_fingerprint', 64);
            $table->foreignId('journal_entry_id')->constrained()->restrictOnDelete();
            $table->foreignId('posted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['tenant_id', 'sales_invoice_id']);
            $table->unique(['tenant_id', 'idempotency_key']);
        });

        $now = now();
        DB::table('tenants')->orderBy('id')->each(function (object $tenant) use ($now): void {
            foreach (self::DEFAULT_MAPPINGS as $key => $code) {
                if (DB::table('sales_account_mappings')->where('tenant_id', $tenant->id)->where('mapping_key', $key)->exists()) continue;
                $accountId = DB::table('financial_accounts')->where('tenant_id', $tenant->id)->where('code', $code)->value('id');
                if ($accountId) DB::table('sales_account_mappings')->insert(['tenant_id' => $tenant->id, 'mapping_key' => $key, 'financial_account_id' => $accountId, 'created_at' => $now, 'updated_at' => $now]);
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sales_invoice_postings');
        Schema::dropIfExists('customer_receivables');
        DB::table('sales_account_mappings')->whereIn('mapping_key', array_keys(self::DEFAULT_MAPPINGS))->delete();
    }
};
