<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->string('barcode')->nullable();
            $table->string('item_type')->default('other');
            $table->string('category')->nullable();
            $table->decimal('reorder_level', 15, 3)->default(0);
            $table->decimal('latest_unit_cost', 15, 4)->default(0);
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->unique(['tenant_id', 'sku'], 'inventory_items_tenant_sku_unique');
            $table->unique(['tenant_id', 'barcode'], 'inventory_items_tenant_barcode_unique');
            $table->index(['tenant_id', 'item_type', 'is_active']);
        });

        DB::table('inventory_items')->orderBy('id')->each(function (object $item): void {
            DB::table('inventory_items')->where('id', $item->id)->update([
                'name_ar' => $item->name,
                'name_en' => $item->name,
                'item_type' => 'other',
                'reorder_level' => $item->minimum_stock,
                'latest_unit_cost' => $item->cost_per_unit,
                'updated_at' => now(),
            ]);
        });

        Schema::create('stock_balances', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('warehouse_id')->constrained();
            $table->foreignId('inventory_item_id')->constrained();
            $table->decimal('quantity_on_hand', 15, 3)->default(0);
            $table->decimal('reserved_quantity', 15, 3)->default(0);
            $table->decimal('average_unit_cost', 15, 4)->default(0);
            $table->timestamp('last_movement_at')->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'warehouse_id', 'inventory_item_id'], 'stock_balances_scope_unique');
            $table->index(['tenant_id', 'warehouse_id']);
            $table->index(['tenant_id', 'inventory_item_id']);
        });

        Schema::table('stock_movements', function (Blueprint $table): void {
            $table->decimal('quantity_in', 15, 3)->default(0);
            $table->decimal('quantity_out', 15, 3)->default(0);
            $table->decimal('quantity_before', 15, 3)->default(0);
            $table->decimal('quantity_after', 15, 3)->default(0);
            $table->timestamp('occurred_at')->nullable();
            $table->index(['tenant_id', 'warehouse_id', 'occurred_at']);
            $table->index(['tenant_id', 'inventory_item_id', 'occurred_at']);
        });

        DB::table('stock_movements')->orderBy('id')->each(function (object $movement): void {
            $incoming = in_array($movement->type, ['opening_balance', 'stock_in', 'adjustment_in', 'transfer_in', 'return_in'], true);
            DB::table('stock_movements')->where('id', $movement->id)->update([
                'quantity_in' => $incoming ? $movement->quantity : 0,
                'quantity_out' => $incoming ? 0 : $movement->quantity,
                'occurred_at' => $movement->created_at,
            ]);
        });

        Schema::create('stock_counts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('warehouse_id')->constrained();
            $table->date('count_date');
            $table->string('status')->default('draft');
            $table->text('notes')->nullable();
            $table->foreignId('counted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('posted_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();
            $table->index(['tenant_id', 'warehouse_id', 'status']);
        });

        Schema::create('stock_count_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('stock_count_id')->constrained()->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained();
            $table->decimal('expected_quantity', 15, 3)->default(0);
            $table->decimal('counted_quantity', 15, 3)->default(0);
            $table->decimal('variance_quantity', 15, 3)->default(0);
            $table->text('reason')->nullable();
            $table->timestamps();
            $table->unique(['stock_count_id', 'inventory_item_id'], 'stock_count_lines_item_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_count_lines');
        Schema::dropIfExists('stock_counts');
        Schema::table('stock_movements', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'warehouse_id', 'occurred_at']);
            $table->dropIndex(['tenant_id', 'inventory_item_id', 'occurred_at']);
            $table->dropColumn(['quantity_in', 'quantity_out', 'quantity_before', 'quantity_after', 'occurred_at']);
        });
        Schema::dropIfExists('stock_balances');
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->dropUnique('inventory_items_tenant_sku_unique');
            $table->dropUnique('inventory_items_tenant_barcode_unique');
            $table->dropIndex(['tenant_id', 'item_type', 'is_active']);
            $table->dropConstrainedForeignId('created_by');
            $table->dropConstrainedForeignId('updated_by');
            $table->dropColumn(['name_ar', 'name_en', 'barcode', 'item_type', 'category', 'reorder_level', 'latest_unit_cost', 'notes']);
        });
    }
};
