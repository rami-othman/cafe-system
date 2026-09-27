<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('factory_currency_settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tenant_id')->constrained('tenants');
            $table->foreignId('branch_id')->constrained('branches');
            $table->string('default_currency', 3)->default('SYP');
            $table->decimal('usd_to_syp', 18, 6)->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'branch_id']);
        });
        foreach (['supplier_invoices', 'sales_invoices', 'supplier_payments', 'finance_documents'] as $name) {
            Schema::table($name, fn (Blueprint $table) => $table->json('factory_currency')->nullable());
        }
    }

    public function down(): void
    {
        foreach (['supplier_invoices', 'sales_invoices', 'supplier_payments', 'finance_documents'] as $name) {
            Schema::table($name, fn (Blueprint $table) => $table->dropColumn('factory_currency'));
        }
        Schema::dropIfExists('factory_currency_settings');
    }
};
