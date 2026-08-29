<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('variant_recipes', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('product_variant_id')->constrained();
            $table->timestamps();
            $table->unique(['tenant_id', 'product_variant_id']);
        });
        Schema::create('variant_recipe_components', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('variant_recipe_id')->constrained()->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained();
            $table->decimal('quantity', 18, 6);
            $table->string('unit_code', 8);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
            $table->unique(['variant_recipe_id', 'inventory_item_id']);
            $table->index(['tenant_id', 'inventory_item_id']);
        });
        Schema::create('modifier_option_recipe_profiles', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('modifier_option_id')->constrained();
            $table->string('scope_type', 16);
            $table->foreignId('product_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('product_variant_id')->nullable()->constrained()->cascadeOnDelete();
            $table->timestamps();
            $table->index(['tenant_id', 'modifier_option_id']);
        });
        DB::statement("ALTER TABLE modifier_option_recipe_profiles ADD CONSTRAINT modifier_option_recipe_profiles_scope_check CHECK ((scope_type = 'global' AND product_id IS NULL AND product_variant_id IS NULL) OR (scope_type = 'product' AND product_id IS NOT NULL AND product_variant_id IS NULL) OR (scope_type = 'variant' AND product_id IS NULL AND product_variant_id IS NOT NULL))");
        DB::statement("CREATE UNIQUE INDEX modifier_option_recipe_profiles_global_unique ON modifier_option_recipe_profiles (tenant_id, modifier_option_id) WHERE scope_type = 'global'");
        DB::statement("CREATE UNIQUE INDEX modifier_option_recipe_profiles_product_unique ON modifier_option_recipe_profiles (tenant_id, modifier_option_id, product_id) WHERE scope_type = 'product'");
        DB::statement("CREATE UNIQUE INDEX modifier_option_recipe_profiles_variant_unique ON modifier_option_recipe_profiles (tenant_id, modifier_option_id, product_variant_id) WHERE scope_type = 'variant'");
        Schema::create('modifier_option_recipe_profile_components', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('modifier_option_recipe_profile_id', 'morpc_profile_fk')->constrained('modifier_option_recipe_profiles')->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained();
            $table->string('operation', 8);
            $table->decimal('quantity', 18, 6);
            $table->string('unit_code', 8);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
            $table->unique(['modifier_option_recipe_profile_id', 'inventory_item_id', 'operation'], 'morpc_unique');
            $table->index(['tenant_id', 'inventory_item_id']);
        });
        DB::statement("ALTER TABLE modifier_option_recipe_profile_components ADD CONSTRAINT morpc_operation_check CHECK (operation IN ('add', 'remove'))");
    }

    public function down(): void
    {
        Schema::dropIfExists('modifier_option_recipe_profile_components');
        Schema::dropIfExists('modifier_option_recipe_profiles');
        Schema::dropIfExists('variant_recipe_components');
        Schema::dropIfExists('variant_recipes');
    }
};
