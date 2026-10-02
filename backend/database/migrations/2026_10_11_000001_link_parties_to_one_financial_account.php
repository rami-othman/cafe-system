<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            $table->foreignId('financial_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
        });
        Schema::table('suppliers', function (Blueprint $table): void {
            $table->foreignId('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->unique(['tenant_id', 'customer_id']);
        });
    }

    public function down(): void
    {
        Schema::table('suppliers', function (Blueprint $table): void {
            $table->dropUnique(['tenant_id', 'customer_id']);
            $table->dropConstrainedForeignId('customer_id');
        });
        Schema::table('customers', fn (Blueprint $table) => $table->dropConstrainedForeignId('financial_account_id'));
    }
};
