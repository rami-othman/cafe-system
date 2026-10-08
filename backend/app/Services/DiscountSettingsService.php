<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class DiscountSettingsService
{
    public const STACKING_MODES = ['different_items_only', 'same_item_allowed'];

    public const CONFLICT_RESOLUTIONS = ['best_saving', 'priority'];

    public const MAX_DISCOUNTS_PER_ORDER_LIMIT = 10;

    /**
     * Discount System V3 Cafe Discount Policy. Enforced by the engine for
     * explicit multi-discount sets (see DiscountResolutionService); the defaults
     * describe the legacy single-discount behavior. The total-percent limit is
     * the legacy maximumTotalDiscountPercent field, shared with V3 so there is
     * a single source of truth.
     */
    public const POLICY_DEFAULTS = [
        'allowMultipleDiscounts' => false,
        'stackingMode' => 'different_items_only',
        'allowMultipleCoupons' => false,
        'allowCouponWithConfigured' => false,
        'allowOrderAfterItemDiscounts' => false,
        'maximumDiscountsPerOrder' => 1,
        'conflictResolution' => 'best_saving',
    ];

    public const POLICY_COLUMNS = [
        'allowMultipleDiscounts' => 'allow_multiple_discounts',
        'stackingMode' => 'stacking_mode',
        'allowMultipleCoupons' => 'allow_multiple_coupons',
        'allowCouponWithConfigured' => 'allow_coupon_with_configured',
        'allowOrderAfterItemDiscounts' => 'allow_order_after_item_discounts',
        'maximumDiscountsPerOrder' => 'maximum_discounts_per_order',
        'conflictResolution' => 'conflict_resolution',
    ];

    /**
     * Legacy engine-oriented fields. Still authoritative for the current
     * runtime and still written by existing clients; not part of the public V3
     * vocabulary and slated for removal from public UI in Phase 3.
     * maximumTotalDiscountPercent is kept here because V3 shares it.
     */
    public const LEGACY_DEFAULTS = [
        'automaticEnabled' => false,
        'selectionStrategy' => 'highest_saving',
        'combinationMode' => 'single',
        'orderDiscountBehavior' => 'exclusive',
        'couponBehavior' => 'exclusive',
        'manualBehavior' => 'exclusive',
        'maximumTotalDiscountPercent' => null,
        'allowAutomaticSuppression' => true,
    ];

    // The sole default authority; persistence requires explicit field values.
    public const DEFAULTS = self::LEGACY_DEFAULTS + self::POLICY_DEFAULTS;

    public const COLUMNS = [
        'automaticEnabled' => 'automatic_enabled',
        'selectionStrategy' => 'selection_strategy',
        'combinationMode' => 'combination_mode',
        'orderDiscountBehavior' => 'order_discount_behavior',
        'couponBehavior' => 'coupon_behavior',
        'manualBehavior' => 'manual_behavior',
        'maximumTotalDiscountPercent' => 'maximum_total_discount_percent',
        'allowAutomaticSuppression' => 'allow_automatic_suppression',
    ];

    public function __construct(private readonly OperationalAuditService $audit) {}

    public function read(int $tenantId): array
    {
        return $this->serialize(DB::table('tenant_discount_settings')->where('tenant_id', $tenantId)->first());
    }

    public function save(Request $request, int $tenantId, array $data): array
    {
        return DB::transaction(function () use ($request, $tenantId, $data): array {
            // A tenant-key advisory lock covers the absent-row case without
            // creating a row on GET or locking unrelated orders/payment paths.
            DB::select('select pg_advisory_xact_lock(?, ?)', [20402, $tenantId]);
            $row = DB::table('tenant_discount_settings')->where('tenant_id', $tenantId)->lockForUpdate()->first();
            $before = $this->serialize($row);
            if ($before['version'] !== $data['expectedVersion']) {
                throw new HttpException(409, 'DISCOUNT_SETTINGS_VERSION_CONFLICT');
            }
            $values = [];
            foreach (self::COLUMNS as $field => $column) {
                $values[$column] = $data[$field];
            }
            // V3 policy fields are optional for existing clients: an omitted
            // field keeps its saved (or default) value instead of resetting it.
            foreach (self::POLICY_COLUMNS as $field => $column) {
                $values[$column] = array_key_exists($field, $data) ? $data[$field] : $before[$field];
            }
            $actorId = (int) $request->attributes->get('auth_user')->id;
            $values += ['version' => $before['version'] + 1, 'updated_by' => $actorId, 'updated_at' => now()];
            if ($row) {
                DB::table('tenant_discount_settings')->where('id', $row->id)->update($values);
                $id = (int) $row->id;
            } else {
                $id = DB::table('tenant_discount_settings')->insertGetId($values + ['tenant_id' => $tenantId, 'created_at' => now()]);
            }
            $after = $this->read($tenantId);
            $this->audit->record($request, $tenantId, 'discount.settings.updated', 'tenant_discount_settings', $id, $before, $after, actorId: $actorId);

            return $after;
        });
    }

    /**
     * The runtime view of the saved policy. The saved maximumDiscountsPerOrder
     * is never rewritten: while multiple discounts are disabled it is dormant
     * and the effective maximum is 1.
     */
    public static function effectivePolicy(array $settings): array
    {
        $multiple = (bool) $settings['allowMultipleDiscounts'];

        return [
            'allowMultipleDiscounts' => $multiple,
            'effectiveMaximumDiscounts' => $multiple ? (int) $settings['maximumDiscountsPerOrder'] : 1,
            'stackingMode' => $settings['stackingMode'],
            'allowMultipleCoupons' => (bool) $settings['allowMultipleCoupons'],
            'allowCouponWithConfigured' => (bool) $settings['allowCouponWithConfigured'],
            'allowOrderAfterItemDiscounts' => (bool) $settings['allowOrderAfterItemDiscounts'],
            'maximumTotalDiscountPercent' => $settings['maximumTotalDiscountPercent'],
            'conflictResolution' => $settings['conflictResolution'],
            'settingsVersion' => (int) $settings['version'],
        ];
    }

    private function serialize(?object $row): array
    {
        $data = self::DEFAULTS;
        if ($row) {
            foreach (self::COLUMNS as $field => $column) {
                $data[$field] = $row->$column;
            }
            $data['maximumTotalDiscountPercent'] = $row->maximum_total_discount_percent === null ? null : (float) $row->maximum_total_discount_percent;
            foreach (self::POLICY_COLUMNS as $field => $column) {
                $data[$field] = $row->$column;
            }
            $data['maximumDiscountsPerOrder'] = (int) $row->maximum_discounts_per_order;
        }

        return $data + ['version' => $row ? (int) $row->version : 0, 'engineReady' => false];
    }
}
