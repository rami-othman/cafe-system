<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('menu_variant_prices', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_id')->constrained();
            $table->foreignId('product_variant_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->string('channel');
            $table->decimal('price', 12, 2);
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['tenant_id', 'menu_id', 'product_variant_id', 'branch_id', 'channel'], 'menu_variant_prices_identity_unique');
            $table->index(['tenant_id', 'menu_id', 'branch_id', 'channel'], 'menu_variant_prices_context_index');
        });
        DB::statement('ALTER TABLE menu_variant_prices ADD CONSTRAINT menu_variant_prices_positive_price CHECK (price > 0)');

        Schema::create('menu_price_adjustments', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->string('channel');
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('operation');
            $table->string('amount', 64)->nullable();
            $table->string('rounding_mode');
            $table->string('rounding_step', 64)->nullable();
            $table->string('status')->default('previewed');
            $table->string('fingerprint', 64)->unique();
            $table->string('dependency_fingerprint', 64);
            $table->json('summary');
            $table->timestamp('expires_at');
            $table->boolean('confirmed_reviewed_results')->default(false);
            $table->boolean('acknowledged_opposite_direction')->default(false);
            $table->timestamp('applied_at')->nullable();
            $table->timestamps();
            $table->index(['tenant_id', 'menu_id', 'branch_id', 'channel', 'status'], 'menu_price_adjustments_context_status_index');
        });

        Schema::create('menu_price_adjustment_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_price_adjustment_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_variant_id')->constrained();
            $table->string('action');
            $table->string('original_effective_price', 64);
            $table->string('original_source');
            $table->boolean('had_menu_override');
            $table->string('previous_override_price', 64)->nullable();
            $table->string('previous_override_revision', 64)->nullable();
            $table->string('raw_calculated_price', 128)->nullable();
            $table->string('final_new_price', 64);
            $table->string('final_source');
            $table->string('difference', 64);
            $table->string('final_movement');
            $table->boolean('opposite_direction')->default(false);
            $table->string('configuration_effect');
            $table->string('dependency_fingerprint', 64);
            $table->timestamps();
            $table->unique(['menu_price_adjustment_id', 'product_variant_id'], 'menu_price_adjustment_item_variant_unique');
            $table->index(['tenant_id', 'product_variant_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('menu_price_adjustment_items');
        Schema::dropIfExists('menu_price_adjustments');
        Schema::dropIfExists('menu_variant_prices');
    }
};
