<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class BranchPosCashDrawer
{
    public function resolve(int $tenantId, int $branchId, bool $lock = false): object
    {
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)
            ->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $branch || ! $branch->pos_cash_financial_location_id) {
            throw ValidationException::withMessages(['cashSource' => 'لا يمكن فتح الوردية لأن صندوق نقطة البيع غير محدد لهذا الفرع.']);
        }
        $query = DB::table('financial_locations as locations')
            ->join('financial_accounts as accounts', function ($join) use ($tenantId): void {
                $join->on('accounts.id', '=', 'locations.financial_account_id')->where('accounts.tenant_id', '=', $tenantId);
            })
            ->where('locations.tenant_id', $tenantId)->where('locations.id', $branch->pos_cash_financial_location_id)
            ->where('locations.branch_id', $branchId)->where('locations.kind', 'cash')
            ->where('locations.type', 'cash_drawer')->where('locations.is_active', true)
            ->where('accounts.is_active', true)->whereNull('accounts.deleted_at')
            ->select('locations.*', 'accounts.code as account_code');
        if ($lock) $query->lockForUpdate();
        $location = $query->first();
        if (! $location) {
            throw ValidationException::withMessages(['cashSource' => 'إعدادات صندوق نقطة البيع غير مكتملة لهذا الفرع.']);
        }
        return $location;
    }
}
