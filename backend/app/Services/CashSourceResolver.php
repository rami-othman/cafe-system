<?php

namespace App\Services;

use App\Models\User;
use App\Support\FinancialActor;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Resolves a physical cash location independently of the payment method. */
final class CashSourceResolver
{
    public function __construct(private readonly DefaultTenantRoleService $roles) {}

    public function mode(int $tenantId, int $actorId): string
    {
        $actor = User::query()->with('tenantRole')->where('tenant_id', $tenantId)->where('id', $actorId)
            ->where('is_active', true)->firstOrFail();
        return $this->roles->canonicalLegacyRole($actor->effectiveRoleCode()) === 'cashier' ? 'shift' : 'selectable';
    }

    public function allowedLocations(int $tenantId, int $actorId, int $branchId): array
    {
        FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId);
        if ($this->mode($tenantId, $actorId) === 'shift') return [];
        return DB::table('financial_locations as l')->join('financial_accounts as a', function ($join) use ($tenantId): void {
            $join->on('a.id', '=', 'l.financial_account_id')->where('a.tenant_id', '=', $tenantId);
        })->where('l.tenant_id', $tenantId)->where('l.kind', 'cash')->where('l.is_active', true)
            ->where('a.is_active', true)->whereNull('a.deleted_at')
            ->where(function ($q) use ($branchId): void {
                $q->where('l.branch_id', $branchId)
                    ->orWhere(fn ($global) => $global->whereNull('l.branch_id')->where('l.code', '!=', 'CASH-DRAWER'));
            })->orderBy('l.name')->get(['l.id', 'l.name', 'l.branch_id', 'l.type'])->map(fn ($l) => [
                'id' => (int) $l->id, 'name' => $l->name,
                'branchId' => $l->branch_id ? (int) $l->branch_id : null, 'type' => $l->type,
            ])->all();
    }

    /** @return object{location:object,shift:?object,mode:string} */
    public function resolve(int $tenantId, int $actorId, int $branchId, ?int $selectedLocationId = null, bool $lock = false): object
    {
        FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId);
        $mode = $this->mode($tenantId, $actorId);
        $shift = null;
        if ($mode === 'shift') {
            if ($selectedLocationId !== null) {
                throw ValidationException::withMessages(['financialLocationId' => 'لا يمكن للمستخدم تغيير صندوق الوردية.']);
            }
            $query = DB::table('shifts')->where('tenant_id', $tenantId)->where('branch_id', $branchId)
                ->where('user_id', $actorId)->where('status', 'open')->whereNull('deleted_at')
                ->orderByDesc('opened_at');
            if ($lock) $query->lockForUpdate();
            $shift = $query->first();
            if (! $shift || ! $shift->financial_location_id) {
                throw ValidationException::withMessages(['shift' => 'يجب فتح وردية بصندوق صالح قبل الحركة النقدية.']);
            }
            $selectedLocationId = (int) $shift->financial_location_id;
        } elseif ($selectedLocationId === null) {
            throw ValidationException::withMessages(['financialLocationId' => 'يرجى اختيار الصندوق.']);
        }

        $query = DB::table('financial_locations as l')->join('financial_accounts as a', function ($join) use ($tenantId): void {
            $join->on('a.id', '=', 'l.financial_account_id')->where('a.tenant_id', '=', $tenantId);
        })->where('l.tenant_id', $tenantId)->where('l.id', $selectedLocationId)
            ->where('l.kind', 'cash')->where('l.is_active', true)
            ->where('a.is_active', true)->whereNull('a.deleted_at')
            ->select('l.*', 'a.code as account_code');
        if ($lock) $query->lockForUpdate();
        $location = $query->first();
        if (! $location || ($mode === 'shift' && ((int) $location->branch_id !== $branchId || $location->type !== 'cash_drawer'))
            || ($mode === 'selectable' && ! collect($this->allowedLocations($tenantId, $actorId, $branchId))->contains('id', (int) $location->id))) {
            throw ValidationException::withMessages(['financialLocationId' => 'الصندوق المحدد غير متاح لهذا الفرع.']);
        }
        if ($mode === 'selectable' && $location->type === 'cash_drawer'
            && DB::table('shifts')->where('tenant_id', $tenantId)->where('financial_location_id', $location->id)
                ->where('status', 'open')->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages(['financialLocationId' => 'هذا الصندوق مرتبط بوردية مفتوحة. استخدم حركة نقدية معتمدة مرتبطة بالوردية.']);
        }
        return (object) ['location' => $location, 'shift' => $shift, 'mode' => $mode];
    }

    public function forPaymentMethod(int $tenantId, int $actorId, int $branchId, object $method, ?int $selectedLocationId, bool $lock = false): ?object
    {
        if ($method->type !== 'cash') return null;
        return $this->resolve($tenantId, $actorId, $branchId, $selectedLocationId, $lock);
    }
}
