<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('discount_targets', function (Blueprint $table): void {
            $table->unique(['id', 'tenant_id', 'discount_id', 'target_id', 'target_type'], 'discount_target_variant_parent_unique');
        });
        Schema::table('product_variants', function (Blueprint $table): void {
            $table->unique(['id', 'tenant_id', 'product_id'], 'discount_variant_identity_unique');
        });
        Schema::create('discount_product_target_variants', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('tenant_id');
            $table->unsignedBigInteger('discount_id');
            $table->unsignedBigInteger('product_id');
            $table->unsignedBigInteger('product_variant_id');
            $table->unsignedBigInteger('discount_target_id');
            $table->string('target_type')->default('product');
            $table->timestamps();
            $table->unique(['tenant_id', 'discount_id', 'product_id', 'product_variant_id'], 'discount_product_variant_unique');
            $table->index(['discount_target_id', 'tenant_id', 'discount_id', 'product_id', 'target_type'], 'discount_variant_parent_index');
            $table->index(['product_variant_id', 'tenant_id', 'product_id'], 'discount_variant_identity_index');
            $table->foreign(['discount_target_id', 'tenant_id', 'discount_id', 'product_id', 'target_type'], 'discount_variant_parent_fk')
                ->references(['id', 'tenant_id', 'discount_id', 'target_id', 'target_type'])->on('discount_targets')->cascadeOnDelete();
            // A hard deletion must not silently convert selected into all.
            $table->foreign(['product_variant_id', 'tenant_id', 'product_id'], 'discount_variant_identity_fk')
                ->references(['id', 'tenant_id', 'product_id'])->on('product_variants')->restrictOnDelete();
        });
        DB::statement("ALTER TABLE discount_product_target_variants ADD CONSTRAINT discount_variant_product_only CHECK (target_type = 'product')");
    }

    public function down(): void
    {
        Schema::dropIfExists('discount_product_target_variants');
        Schema::table('product_variants', fn (Blueprint $table) => $table->dropUnique('discount_variant_identity_unique'));
        Schema::table('discount_targets', fn (Blueprint $table) => $table->dropUnique('discount_target_variant_parent_unique'));
    }
};
