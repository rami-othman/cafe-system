<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_movements', function (Blueprint $table): void {
            $table->string('input_unit', 40)->nullable()->after('quantity');
            $table->decimal('conversion_factor', 18, 6)->nullable()->after('input_unit');
            $table->decimal('base_quantity', 15, 3)->nullable()->after('conversion_factor');
            $table->string('idempotency_key', 120)->nullable()->after('reference_id');
            $table->unique(['tenant_id', 'idempotency_key'], 'stock_movements_tenant_idempotency_unique');
        });
    }
    public function down(): void
    {
        Schema::table('stock_movements', function (Blueprint $table): void {
            $table->dropUnique('stock_movements_tenant_idempotency_unique');
            $table->dropColumn(['input_unit', 'conversion_factor', 'base_quantity', 'idempotency_key']);
        });
    }
};
