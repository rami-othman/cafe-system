<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class CashVarianceService
{
    public function __construct(private readonly AccountingPostingService $posting) {}

    /** الحساب المحدد من المدير للفرع، وإلا 6180. */
    public function account(int $tenantId, int $branchId): object
    {
        $id = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->value('cash_variance_account_id');
        $query = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at');
        $account = $id ? (clone $query)->where('id', $id)->first() : (clone $query)->where('code', '6180')->first();
        if (! $account) {
            throw ValidationException::withMessages(['cashVarianceAccount' => __('shifts.variance_account_missing')]);
        }

        return $account;
    }

    /**
     * $differenceCents = المعدود − المتوقع. سالب = عجز، موجب = زيادة. يرجع رقم القيد أو null إذا الفرق صفر.
     */
    public function post(
        Request $request,
        int $tenantId,
        int $branchId,
        int $locationId,
        int $differenceCents,
        string $entryDate,
        string $sourceType,
        int $sourceId,
        string $description,
        ?int $actorId,
    ): ?int {
        if ($differenceCents === 0) {
            return null;
        }
        $account = $this->account($tenantId, $branchId);
        $locationAccountCode = DB::table('financial_locations as l')
            ->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
            ->where('l.tenant_id', $tenantId)->where('l.id', $locationId)->value('a.code');
        $amount = Money::decimal(abs($differenceCents));
        $short = $differenceCents < 0;

        return $this->posting->post($request, $tenantId, [
            'branchId' => $branchId,
            'sourceType' => $sourceType,
            'sourceId' => $sourceId,
            'sourceEvent' => 'CASH_VARIANCE_POSTED',
            'entryDate' => $entryDate,
            'description' => $description,
            'lines' => [
                ['accountCode' => $account->code, 'debit' => $short ? $amount : '0.00', 'credit' => $short ? '0.00' : $amount, 'description' => $description],
                ['accountCode' => $locationAccountCode, 'debit' => $short ? '0.00' : $amount, 'credit' => $short ? $amount : '0.00', 'financialLocationId' => $locationId, 'description' => $description],
            ],
        ], $actorId);
    }
}
