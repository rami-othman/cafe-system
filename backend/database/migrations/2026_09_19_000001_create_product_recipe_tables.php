<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_recipes', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('product_id')->constrained();
            $table->timestamps();
            $table->unique(['tenant_id', 'product_id']);
        });

        Schema::create('product_recipe_components', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('product_recipe_id')->constrained()->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained();
            $table->decimal('quantity', 18, 6);
            $table->string('unit_code', 8);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
            $table->unique(['product_recipe_id', 'inventory_item_id']);
            $table->index(['tenant_id', 'inventory_item_id']);
        });

        require_once __DIR__.'/ProductRecipeBackfill.php';
        $counts = ProductRecipeBackfill::run();
        Log::info('product_recipe_backfill_completed', ['counts' => $counts]);
        if ($counts['rejectedInconsistencies'] > 0) {
            Log::warning('product_recipe_backfill_rejected_inconsistencies', ['counts' => $counts]);
        }
    }

    public function down(): void
    {
        // Development/testing only. Production recovery is roll-forward: fix the
        // source inconsistency and rerun the idempotent backfill; never roll back
        // configuration tables after deployment.
        Schema::dropIfExists('product_recipe_components');
        Schema::dropIfExists('product_recipes');
    }
};
