<?php

namespace App\Services;

use App\Models\User;
use App\Support\FinancialActor;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class PurchaseCashSourceResolver
{
    public function __construct(private readonly DefaultTenantRoleService $roles) {}

    /** @return object{location:object,method:object,shift:?object} */
    public function resolve(int $tenantId, int $actorId, int $branchId, bool $lock = false): object
    {
        FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId);
        $actor = User::query()->with('tenantRole')->where('tenant_id', $tenantId)->where('id', $actorId)->where('is_active', true)->firstOrFail();
        $role = $this->roles->canonicalLegacyRole($actor->effectiveRoleCode());

        $shiftQuery = DB::table('shifts')->where('tenant_id', $tenantId)->where('user_id', $actorId)
            ->where('branch_id', $branchId)->where('status', 'open')->whereNull('deleted_at')->latest('opened_at');
        if ($lock) {
            $shiftQuery->lockForUpdate();
        }
        $shift = $shiftQuery->first();
        if ($role === 'cashier' && ! $shift) {
            throw ValidationException::withMessages(['shift' => 'يجب فتح وردية قبل ترحيل فاتورة شراء نقدية.']);
        }

        $locations = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('kind', 'cash')->where('type', 'cash_drawer')->where('is_active', true)->get();
        if ($locations->count() !== 1) {
            throw ValidationException::withMessages(['cashSource' => 'The branch must have exactly one active cash drawer.']);
        }
        $branchDrawerId = (int) $locations->first()->id;
        $location = null;
        if ($shift?->financial_location_id) {
            $location = $this->location($tenantId, (int) $shift->financial_location_id, $branchId, $lock);
            if ((int) ($location?->id ?? 0) !== $branchDrawerId) {
                throw ValidationException::withMessages(['cashSource' => 'The open shift is linked to a different cash drawer.']);
            }
        } else {
            $location = $this->location($tenantId, $branchDrawerId, $branchId, $lock);
            if ($shift) {
                DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shift->id)->update([
                    'financial_location_id' => $location->id,
                    'updated_at' => now(),
                ]);
                $shift->financial_location_id = $location->id;
            }
        }

        if (! $location) {
            throw ValidationException::withMessages(['cashSource' => 'لا يمكن ترحيل فاتورة الشراء لأنه لا يوجد صندوق نقدي/وردية مفتوحة صالحة لهذا المستخدم.']);
        }
        $methodQuery = DB::table('payment_methods')->where('tenant_id', $tenantId)->where('type', 'cash')
            ->where('financial_account_id', $location->financial_account_id)->where('is_active', true)
            ->where(fn ($query) => $query->where('financial_location_id', $location->id)->orWhereNull('financial_location_id'));
        if ($lock) {
            $methodQuery->lockForUpdate();
        }
        $methods = $methodQuery->get();
        if ($methods->count() !== 1) {
            throw ValidationException::withMessages(['cashSource' => 'لا يمكن ترحيل فاتورة الشراء لأن طريقة الدفع النقدي المرتبطة بالصندوق غير صالحة.']);
        }

        return (object) ['location' => $location, 'method' => $methods->first(), 'shift' => $shift];
    }

    private function location(int $tenantId, int $id, int $branchId, bool $lock): ?object
    {
        $query = DB::table('financial_locations as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
            ->where('l.tenant_id', $tenantId)->where('l.id', $id)->where('l.branch_id', $branchId)
            ->where('l.kind', 'cash')->where('l.type', 'cash_drawer')->where('l.is_active', true)->where('a.is_active', true)->whereNull('a.deleted_at')
            ->select('l.*', 'a.code as account_code');
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }
}
