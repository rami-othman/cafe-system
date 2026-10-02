<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class CashVarianceService
{
    public function __construct(private readonly AccountingPostingService $posting, private readonly FinanceAccountMap $accountMap) {}

    /** حساب العجز (مصروف): المحدد من المدير للفرع، وإلا المربوط في إعدادات الحسابات (cash.short). */
    public function account(int $tenantId, int $branchId): object
    {
        return $this->resolve($tenantId, $branchId, 'cash_variance_account_id', 'cash.short', 'cashVarianceAccount');
    }

    /** حساب الزيادة (إيراد): المحدد من المدير للفرع، وإلا المربوط في إعدادات الحسابات (cash.over). الزيادة لا تُخلط بالعجز في حساب واحد. */
    public function overAccount(int $tenantId, int $branchId): object
    {
        return $this->resolve($tenantId, $branchId, 'cash_over_account_id', 'cash.over', 'cashOverAccount');
    }

    /** الحساب المناسب لإشارة الفرق: سالب = عجز، موجب = زيادة. */
    public function accountFor(int $tenantId, int $branchId, int $differenceCents): object
    {
        return $differenceCents > 0 ? $this->overAccount($tenantId, $branchId) : $this->account($tenantId, $branchId);
    }

    private function resolve(int $tenantId, int $branchId, string $column, string $defaultKey, string $field): object
    {
        $id = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->value($column);
        $account = $id
            ? DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->where('id', $id)->first()
            : $this->accountMap->account($tenantId, $defaultKey);
        if (! $account) {
            throw ValidationException::withMessages([$field => __($field === 'cashOverAccount' ? 'shifts.over_account_missing' : 'shifts.variance_account_missing')]);
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
        $account = $this->accountFor($tenantId, $branchId, $differenceCents);
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
