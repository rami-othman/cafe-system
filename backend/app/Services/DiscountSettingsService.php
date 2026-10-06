<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class DiscountSettingsService
{
    // The sole default authority; persistence requires explicit field values.
    public const DEFAULTS = [
        'automaticEnabled' => false,
        'selectionStrategy' => 'highest_saving',
        'combinationMode' => 'single',
        'orderDiscountBehavior' => 'exclusive',
        'couponBehavior' => 'exclusive',
        'manualBehavior' => 'exclusive',
        'maximumTotalDiscountPercent' => null,
        'allowAutomaticSuppression' => true,
    ];

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

    private function serialize(?object $row): array
    {
        $data = self::DEFAULTS;
        if ($row) {
            foreach (self::COLUMNS as $field => $column) {
                $data[$field] = $row->$column;
            }
            $data['maximumTotalDiscountPercent'] = $row->maximum_total_discount_percent === null ? null : (float) $row->maximum_total_discount_percent;
        }

        return $data + ['version' => $row ? (int) $row->version : 0, 'engineReady' => false];
    }
}
