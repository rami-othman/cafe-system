<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Automatic Discounts rollout: a cafe may now turn Automatic promotions on.
 *
 * Only the `NOT automatic_enabled` term is removed from the existing settings
 * CHECK; every other rule is kept verbatim. No row is updated: every cafe stays
 * off until it opts in through the versioned settings API.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::transaction(function (): void {
            DB::statement("SET LOCAL lock_timeout = '5s'");
            DB::statement('ALTER TABLE tenant_discount_settings DROP CONSTRAINT discount_settings_values_check');
            DB::statement("ALTER TABLE tenant_discount_settings ADD CONSTRAINT discount_settings_values_check CHECK (
                version > 0
                AND selection_strategy IN ('highest_saving','lowest_saving','priority')
                AND combination_mode IN ('single','disjoint_items')
                AND order_discount_behavior IN ('exclusive','after_items')
                AND coupon_behavior IN ('exclusive','follow_combination_rules')
                AND manual_behavior IN ('exclusive','follow_combination_rules')
                AND (maximum_total_discount_percent IS NULL OR (maximum_total_discount_percent > 0 AND maximum_total_discount_percent <= 100))
                AND (order_discount_behavior <> 'after_items' OR combination_mode = 'disjoint_items'))");
        });
    }

    public function down(): void
    {
        // Never switch a cafe's promotions off silently: roll forward instead.
        if (DB::table('tenant_discount_settings')->where('automatic_enabled', true)->exists()) {
            throw new RuntimeException('Automatic promotions are enabled for at least one cafe. Turn them off through the settings API before rolling back.');
        }
        DB::transaction(function (): void {
            DB::statement("SET LOCAL lock_timeout = '5s'");
            DB::statement('ALTER TABLE tenant_discount_settings DROP CONSTRAINT discount_settings_values_check');
            DB::statement("ALTER TABLE tenant_discount_settings ADD CONSTRAINT discount_settings_values_check CHECK (
                version > 0 AND NOT automatic_enabled
                AND selection_strategy IN ('highest_saving','lowest_saving','priority')
                AND combination_mode IN ('single','disjoint_items')
                AND order_discount_behavior IN ('exclusive','after_items')
                AND coupon_behavior IN ('exclusive','follow_combination_rules')
                AND manual_behavior IN ('exclusive','follow_combination_rules')
                AND (maximum_total_discount_percent IS NULL OR (maximum_total_discount_percent > 0 AND maximum_total_discount_percent <= 100))
                AND (order_discount_behavior <> 'after_items' OR combination_mode = 'disjoint_items'))");
        });
    }
};
