<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Manufacturing module schema. Extends the existing inventory/costing/finance
 * architecture — no parallel stock ledger, no parallel costing engine.
 *
 * - inventory_items.item_type gains 'semi_finished_good' (application-level
 *   enum only, see InventoryItemRequest; the column has no DB check
 *   constraint to alter).
 * - stock_movements.type gains 'production_consumption', 'production_output',
 *   'conversion_consumption', 'conversion_output' (same: application-level
 *   Rule::in in StockMovementRequest, no DB constraint here either).
 * - Every stock/cost effect of Manufacturing flows through the existing
 *   InventoryPostingService::post() (WAC engine) — these tables never store
 *   their own balances.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('manufacturing_recipes', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('product_item_id')->constrained('inventory_items');
            $table->string('status', 20)->default('active'); // active | inactive
            $table->foreignId('current_version_id')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['tenant_id', 'product_item_id'], 'manufacturing_recipes_tenant_product_unique');
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('manufacturing_recipe_versions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('manufacturing_recipe_id')->constrained('manufacturing_recipes')->cascadeOnDelete();
            $table->unsignedInteger('version_number');
            $table->decimal('output_quantity', 15, 3);
            $table->string('output_unit', 30);
            $table->unsignedInteger('shelf_life_value')->nullable();
            $table->string('shelf_life_unit', 10)->nullable(); // hours | days
            // Estimate-only, never capitalized/posted — see ManufacturingRecipeService docblock.
            $table->json('estimated_extra_costs')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('created_at')->nullable();

            $table->unique(['tenant_id', 'manufacturing_recipe_id', 'version_number'], 'manufacturing_recipe_versions_unique');
        });

        Schema::create('manufacturing_recipe_version_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('manufacturing_recipe_version_id')->constrained('manufacturing_recipe_versions')->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained();
            $table->decimal('quantity', 15, 6);
            $table->string('unit', 30);
            $table->unsignedInteger('sort_order')->default(0);

            $table->index(['tenant_id', 'manufacturing_recipe_version_id'], 'manufacturing_recipe_version_lines_version_idx');
            $table->index(['tenant_id', 'inventory_item_id'], 'manufacturing_recipe_version_lines_item_idx');
        });

        Schema::table('manufacturing_recipes', function (Blueprint $table): void {
            $table->foreign('current_version_id')->references('id')->on('manufacturing_recipe_versions')->nullOnDelete();
        });

        // One row per tenant+prefix+day. PR-20260925-000001 / CV-20260925-000001 style
        // references, generated the safe way (CustomerNumberGenerator's row-lock
        // pattern), never by the frontend.
        Schema::create('manufacturing_reference_counters', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('prefix', 10);
            $table->date('date_bucket');
            $table->unsignedBigInteger('next_value')->default(1);
            $table->timestamps();

            $table->unique(['tenant_id', 'prefix', 'date_bucket'], 'manufacturing_reference_counters_unique');
        });

        Schema::create('manufacturing_orders', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('warehouse_id')->constrained();
            $table->foreignId('manufacturing_recipe_id')->constrained('manufacturing_recipes');
            $table->foreignId('manufacturing_recipe_version_id')->constrained('manufacturing_recipe_versions');
            $table->foreignId('output_item_id')->constrained('inventory_items');
            $table->string('status', 20)->default('draft'); // draft | completed | reversed
            $table->string('reference', 40)->nullable(); // assigned only on completion

            $table->decimal('planned_quantity', 15, 3);
            $table->string('planned_unit', 30);
            $table->decimal('expected_material_cost', 15, 2)->nullable();
            $table->decimal('expected_unit_cost', 15, 4)->nullable();

            $table->decimal('actual_quantity', 15, 3)->nullable();
            $table->decimal('actual_material_cost', 15, 2)->nullable();
            $table->decimal('actual_unit_cost', 15, 4)->nullable();
            // Managerial memo only (labor/electricity/other) — never capitalized into
            // inventory value, never posted to Finance. See ManufacturingProductionService.
            $table->json('additional_managerial_costs')->nullable();

            $table->decimal('waste_quantity', 15, 3)->nullable();
            $table->string('waste_unit', 30)->nullable();
            $table->string('waste_reason', 40)->nullable();
            $table->text('waste_notes')->nullable();

            $table->date('production_date')->nullable();
            $table->date('expiry_date')->nullable(); // server-computed from recipe version shelf life

            $table->foreignId('output_movement_id')->nullable()->constrained('stock_movements')->nullOnDelete();

            $table->text('reverse_reason')->nullable();
            $table->timestamp('reversed_at')->nullable();
            $table->foreignId('reversed_by')->nullable()->constrained('users')->nullOnDelete();

            $table->string('idempotency_key', 120)->nullable();
            $table->string('idempotency_hash', 64)->nullable();
            $table->string('complete_idempotency_key', 120)->nullable();
            $table->string('complete_idempotency_hash', 64)->nullable();
            $table->string('reverse_idempotency_key', 120)->nullable();

            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['tenant_id', 'reference'], 'manufacturing_orders_tenant_reference_unique');
            $table->unique(['tenant_id', 'idempotency_key'], 'manufacturing_orders_idempotency_unique');
            $table->unique(['tenant_id', 'complete_idempotency_key'], 'manufacturing_orders_complete_idempotency_unique');
            $table->unique(['tenant_id', 'reverse_idempotency_key'], 'manufacturing_orders_reverse_idempotency_unique');
            $table->index(['tenant_id', 'warehouse_id', 'status']);
            $table->index(['tenant_id', 'output_item_id', 'status']);
            $table->index(['tenant_id', 'status', 'production_date']);
        });

        // Actual (vs planned) per-ingredient consumption lines — immutable once
        // the order is completed. This is what "materials consumed" reads from,
        // not the recipe version (recipe may later change; history must not).
        Schema::create('manufacturing_order_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('manufacturing_order_id')->constrained('manufacturing_orders')->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained();
            $table->decimal('planned_quantity', 15, 3);
            $table->decimal('actual_quantity', 15, 3)->nullable();
            $table->string('unit', 30);
            $table->decimal('unit_cost', 15, 4)->nullable(); // WAC snapshot at consumption time
            $table->decimal('total_cost', 15, 2)->nullable();
            $table->foreignId('consumption_movement_id')->nullable()->constrained('stock_movements')->nullOnDelete();

            $table->index(['tenant_id', 'manufacturing_order_id'], 'manufacturing_order_lines_order_idx');
        });

        Schema::create('manufacturing_conversions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('warehouse_id')->constrained();
            $table->string('status', 20)->default('completed'); // completed | reversed
            $table->string('reference', 40);

            $table->foreignId('source_item_id')->constrained('inventory_items');
            $table->decimal('source_quantity', 15, 3);
            $table->string('source_unit', 30);
            $table->decimal('source_unit_cost', 15, 4)->nullable();

            $table->foreignId('target_item_id')->constrained('inventory_items');
            $table->decimal('target_quantity', 15, 3);
            $table->string('target_unit', 30);

            $table->decimal('total_cost', 15, 2);
            $table->decimal('result_unit_cost', 15, 4);

            $table->foreignId('source_movement_id')->nullable()->constrained('stock_movements')->nullOnDelete();
            $table->foreignId('target_movement_id')->nullable()->constrained('stock_movements')->nullOnDelete();

            $table->text('reverse_reason')->nullable();
            $table->timestamp('reversed_at')->nullable();
            $table->foreignId('reversed_by')->nullable()->constrained('users')->nullOnDelete();

            $table->string('idempotency_key', 120)->nullable();
            $table->string('reverse_idempotency_key', 120)->nullable();

            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['tenant_id', 'reference'], 'manufacturing_conversions_tenant_reference_unique');
            $table->unique(['tenant_id', 'idempotency_key'], 'manufacturing_conversions_idempotency_unique');
            $table->unique(['tenant_id', 'reverse_idempotency_key'], 'manufacturing_conversions_reverse_idempotency_unique');
            $table->index(['tenant_id', 'warehouse_id', 'status']);
        });

        // Manufacturing-specific audit trail, same shape as MenuAuditLog/CatalogAuditService
        // (no generic cross-module audit table exists yet to extend instead).
        Schema::create('manufacturing_audit_logs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('entity_type', 60);
            $table->unsignedBigInteger('entity_id');
            $table->string('action', 60);
            $table->json('before_data')->nullable();
            $table->json('after_data')->nullable();
            $table->foreignId('changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('created_at')->nullable();

            $table->index(['tenant_id', 'entity_type', 'entity_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('manufacturing_audit_logs');
        Schema::dropIfExists('manufacturing_conversions');
        Schema::dropIfExists('manufacturing_order_lines');
        Schema::dropIfExists('manufacturing_orders');
        Schema::dropIfExists('manufacturing_reference_counters');
        Schema::table('manufacturing_recipes', function (Blueprint $table): void {
            $table->dropForeign(['current_version_id']);
        });
        Schema::dropIfExists('manufacturing_recipe_version_lines');
        Schema::dropIfExists('manufacturing_recipe_versions');
        Schema::dropIfExists('manufacturing_recipes');
    }
};
