<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OperationalAuditService
{
    /** Never persisted, at any nesting depth, for any entity. */
    private const SECRET_KEYS = [
        'password', 'password_confirmation', 'token', 'access_token', 'refresh_token', 'token_hash',
        'remember_token', 'secret', 'api_key', 'authorization', 'pin',
    ];

    /**
     * Coupon text is a redeemable secret. A bare `code` is only a secret on
     * Discount entities: Finance and Sales rows legitimately carry a `code`.
     */
    private const COUPON_KEYS = ['code', 'coupon', 'coupon_code', 'couponcode', 'couponcodes'];

    public function record(Request $request, int $tenantId, string $action, string $entityType, int $entityId, array $before = [], array $after = [], ?int $branchId = null, ?int $actorId = null): void
    {
        DB::table('activity_logs')->insert([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'user_id' => $actorId,
            'action' => $action,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'description' => $this->description($action),
            'ip_address' => $request->ip(),
            'before_state' => json_encode($this->redact($before, $this->isDiscountScope($action, $entityType))),
            'after_state' => json_encode($this->redact($after, $this->isDiscountScope($action, $entityType))),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function recordContext(int $tenantId, string $action, string $entityType, int $entityId, array $after = [], ?int $actorId = null, ?int $branchId = null, bool $deduplicate = true, array $before = []): void
    {
        if ($deduplicate && DB::table('activity_logs')->where('tenant_id', $tenantId)->where('action', $action)->where('entity_type', $entityType)->where('entity_id', $entityId)->exists()) {
            return;
        }

        DB::table('activity_logs')->insert([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'user_id' => $actorId,
            'action' => $action,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'description' => $this->description($action),
            'ip_address' => null,
            'before_state' => json_encode($this->redact($before, $this->isDiscountScope($action, $entityType))),
            'after_state' => json_encode($this->redact($after, $this->isDiscountScope($action, $entityType))),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function description(string $action): string
    {
        return str_replace('.', ' ', $action);
    }

    private function isDiscountScope(string $action, string $entityType): bool
    {
        return str_starts_with($action, 'discount.') || str_starts_with($entityType, 'discount') || str_starts_with($entityType, 'order_discount');
    }

    private function redact(array $state, bool $discountScope = false): array
    {
        foreach ($state as $key => $value) {
            $name = strtolower(str_replace('-', '_', (string) $key));
            if (in_array($name, self::SECRET_KEYS, true) || ($discountScope && in_array($name, self::COUPON_KEYS, true))) {
                $state[$key] = '[redacted]';
            } elseif (is_array($value)) {
                $state[$key] = $this->redact($value, $discountScope);
            }
        }

        return $state;
    }
}
