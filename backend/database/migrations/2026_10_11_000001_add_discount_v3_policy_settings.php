<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Discount System V3 Phase 1: Cafe Discount Policy contract.
 *
 * Additive only. The legacy engine columns stay readable and authoritative for
 * today's single-discount runtime; the V3 columns are persisted contract that
 * Phase 2 will enforce. maximum_total_discount_percent already exists and is
 * deliberately reused as the single source of truth for that limit.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenant_discount_settings', function (Blueprint $table): void {
            // Defaults also back-fill every existing row with the safe,
            // current-behavior values (single discount, no stacking).
            $table->boolean('allow_multiple_discounts')->default(false);
            $table->string('stacking_mode', 30)->default('different_items_only');
            $table->boolean('allow_multiple_coupons')->default(false);
            $table->boolean('allow_coupon_with_configured')->default(false);
            $table->boolean('allow_order_after_item_discounts')->default(false);
            $table->unsignedSmallInteger('maximum_discounts_per_order')->default(1);
            $table->string('conflict_resolution', 30)->default('best_saving');
        });
        DB::statement("ALTER TABLE tenant_discount_settings ADD CONSTRAINT discount_settings_v3_policy_check CHECK (
            stacking_mode IN ('different_items_only','same_item_allowed')
            AND conflict_resolution IN ('best_saving','priority')
            AND maximum_discounts_per_order BETWEEN 1 AND 10)");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE tenant_discount_settings DROP CONSTRAINT IF EXISTS discount_settings_v3_policy_check');
        Schema::table('tenant_discount_settings', function (Blueprint $table): void {
            $table->dropColumn([
                'allow_multiple_discounts', 'stacking_mode', 'allow_multiple_coupons', 'allow_coupon_with_configured',
                'allow_order_after_item_discounts', 'maximum_discounts_per_order', 'conflict_resolution',
            ]);
        });
    }
};
