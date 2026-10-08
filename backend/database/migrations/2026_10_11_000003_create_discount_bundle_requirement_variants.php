<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Discount System V3 Phase 1: variant-level Package / Bundle requirements.
 *
 * Mirrors discount_product_target_variants. A requirement with no rows here
 * means "all variants", so no historical requirement needs a backfill. The
 * composite foreign keys make wrong-product and cross-tenant variants
 * impossible at the storage level, not only in request validation.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('discount_bundle_requirements', function (Blueprint $table): void {
            $table->unique(['id', 'tenant_id', 'discount_id', 'product_id'], 'discount_bundle_requirement_variant_parent_unique');
        });
        Schema::create('discount_bundle_requirement_variants', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('tenant_id');
            $table->unsignedBigInteger('discount_id');
            $table->unsignedBigInteger('product_id');
            $table->unsignedBigInteger('product_variant_id');
            $table->unsignedBigInteger('discount_bundle_requirement_id');
            $table->timestamps();
            $table->unique(['discount_bundle_requirement_id', 'product_variant_id'], 'discount_bundle_variant_unique');
            $table->index(['tenant_id', 'discount_id'], 'discount_bundle_variant_discount_index');
            $table->index(['product_variant_id', 'tenant_id', 'product_id'], 'discount_bundle_variant_identity_index');
            $table->foreign(['discount_bundle_requirement_id', 'tenant_id', 'discount_id', 'product_id'], 'discount_bundle_variant_parent_fk')
                ->references(['id', 'tenant_id', 'discount_id', 'product_id'])->on('discount_bundle_requirements')->cascadeOnDelete();
            // A hard deletion must not silently convert selected into all.
            $table->foreign(['product_variant_id', 'tenant_id', 'product_id'], 'discount_bundle_variant_identity_fk')
                ->references(['id', 'tenant_id', 'product_id'])->on('product_variants')->restrictOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('discount_bundle_requirement_variants');
        Schema::table('discount_bundle_requirements', fn (Blueprint $table) => $table->dropUnique('discount_bundle_requirement_variant_parent_unique'));
    }
};
