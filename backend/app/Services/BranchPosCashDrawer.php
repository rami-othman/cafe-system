<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Resolves a branch's configured POS drawer using the canonical readiness rules. */
final class BranchPosCashDrawer
{
    public function __construct(private readonly ShiftDrawerReadinessService $readiness) {}

    public function resolve(int $tenantId, int $branchId, bool $lock = false): object
    {
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)
            ->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $branch || ! $branch->pos_cash_financial_location_id) {
            throw ValidationException::withMessages([ShiftDrawerReadinessService::FIELD_DRAWER => __('shifts.drawer_not_configured')]);
        }
        $location = $this->readiness->drawerLocation($tenantId, $branchId, (int) $branch->pos_cash_financial_location_id, $lock);
        if (! $location) {
            throw ValidationException::withMessages([ShiftDrawerReadinessService::FIELD_DRAWER => __('shifts.drawer_invalid')]);
        }

        return $location;
    }
}
