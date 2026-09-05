<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table): void {
            $table->boolean('inventory_controlled')->default(false);
            $table->string('consumption_type')->default('bar');
        });
        Schema::create('product_inventory_settings', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('product_id')->constrained(); $table->foreignId('branch_id')->constrained(); $table->foreignId('warehouse_id')->nullable()->constrained(); $table->timestamps();
            $table->unique(['tenant_id', 'product_id', 'branch_id']);
        });
        Schema::create('recipes', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('product_id')->constrained(); $table->string('name'); $table->unsignedInteger('version'); $table->boolean('is_active')->default(false); $table->decimal('yield_quantity', 15, 3)->default(1); $table->string('yield_unit')->default('piece'); $table->text('notes')->nullable(); $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete(); $table->timestamps();
            $table->unique(['tenant_id', 'product_id', 'version']); $table->index(['tenant_id', 'product_id', 'is_active']);
        });
        Schema::create('recipe_lines', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('recipe_id')->constrained()->cascadeOnDelete(); $table->foreignId('inventory_item_id')->constrained(); $table->decimal('quantity', 15, 3); $table->decimal('wastage_percentage', 7, 3)->default(0); $table->unsignedInteger('line_number'); $table->timestamps();
            $table->unique(['recipe_id', 'inventory_item_id']);
        });
        Schema::create('sale_consumptions', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('order_id')->constrained(); $table->foreignId('order_item_id')->constrained(); $table->foreignId('recipe_id')->nullable()->constrained(); $table->foreignId('branch_id')->constrained(); $table->foreignId('warehouse_id')->constrained(); $table->foreignId('payment_id')->nullable()->constrained(); $table->decimal('quantity_sold', 15, 3); $table->decimal('cogs_total', 15, 2)->default(0); $table->timestamp('consumed_at'); $table->timestamps();
            $table->unique(['tenant_id', 'order_item_id'], 'sale_consumptions_order_item_unique');
        });
        Schema::table('order_items', function (Blueprint $table): void { $table->foreignId('recipe_id')->nullable()->constrained(); $table->decimal('cogs_unit', 15, 2)->nullable(); $table->decimal('cogs_total', 15, 2)->nullable(); $table->decimal('gross_profit', 15, 2)->nullable(); });
        Schema::table('orders', function (Blueprint $table): void { $table->decimal('cogs_total', 15, 2)->nullable(); $table->decimal('gross_profit', 15, 2)->nullable(); $table->decimal('gross_margin_percentage', 9, 4)->nullable(); });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void { $table->dropColumn(['cogs_total', 'gross_profit', 'gross_margin_percentage']); });
        Schema::table('order_items', function (Blueprint $table): void { $table->dropConstrainedForeignId('recipe_id'); $table->dropColumn(['cogs_unit', 'cogs_total', 'gross_profit']); });
        Schema::dropIfExists('sale_consumptions'); Schema::dropIfExists('recipe_lines'); Schema::dropIfExists('recipes'); Schema::dropIfExists('product_inventory_settings');
        Schema::table('products', function (Blueprint $table): void { $table->dropColumn(['inventory_controlled', 'consumption_type']); });
    }
};
