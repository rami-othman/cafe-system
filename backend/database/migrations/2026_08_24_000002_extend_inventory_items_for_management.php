<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->string('purchase_unit')->nullable()->after('unit');
            $table->string('consumption_unit')->nullable()->after('purchase_unit');
            $table->boolean('track_expiry')->default(false)->after('is_active');
            $table->boolean('track_batch')->default(false)->after('track_expiry');
            $table->decimal('last_purchase_cost', 15, 4)->default(0)->after('latest_unit_cost');
            $table->string('preferred_supplier_name')->nullable()->after('last_purchase_cost');
        });

        Schema::create('inventory_item_warehouses', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('inventory_item_id')->constrained('inventory_items')->cascadeOnDelete();
            $table->foreignId('warehouse_id')->constrained()->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['tenant_id', 'inventory_item_id', 'warehouse_id'], 'inventory_item_warehouse_unique');
            $table->index(['tenant_id', 'warehouse_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_item_warehouses');
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->dropColumn([
                'purchase_unit',
                'consumption_unit',
                'track_expiry',
                'track_batch',
                'last_purchase_cost',
                'preferred_supplier_name',
            ]);
        });
    }
};
