<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Resolves a POS/refund payment to the tenant-configured Payment Method
 * (Phase 2) that determines which financial account is debited/credited.
 * Never hard-codes an account: every resolution goes through an active,
 * tenant-scoped `payment_methods` row joined to an active `financial_accounts`
 * row, exactly like AccountingPostingService resolves accounts by code.
 */
final class SalePaymentMethodResolver
{
    /**
     * Explicit selection (a `paymentMethodId` sent by the caller): must
     * resolve to a valid, active, tenant-owned mapping or the operation is
     * rejected outright — a caller that names a specific method is asserting
     * it is safe to post against, so a broken mapping must fail loudly rather
     * than silently degrade.
     */
    public static function resolveExplicit(int $tenantId, int $paymentMethodId): object
    {
        $resolved = self::lookup($tenantId, fn ($query) => $query->where('pm.id', $paymentMethodId));
        if ($resolved === null) {
            throw ValidationException::withMessages(['paymentMethodId' => 'Select an active payment method with a valid Finance account mapping for this tenant.']);
        }

        return $resolved;
    }

    /**
     * Legacy fallback: no `paymentMethodId` was sent (an older client, or a
     * method the tenant has not yet configured in Finance). Resolves by the
     * legacy `method` string against a payment method sharing its canonical
     * code (e.g. "cash" -> code "CASH"). Returns null — not an error — when
     * unresolvable, so the payment itself still succeeds; only its automatic
     * ledger posting is skipped until Finance is configured for that method.
     */
    public static function resolveByLegacyMethod(int $tenantId, string $method): ?object
    {
        return self::lookup($tenantId, fn ($query) => $query->where('pm.code', strtoupper($method)));
    }

    /**
     * Non-throwing lookup by a *known-good, already-used* payment method id
     * (e.g. the method a past payment was made with). Used for refunds: the
     * mapping the original sale used may have since been deactivated, and a
     * refund must never be blocked by that — it degrades to no automatic
     * posting instead, exactly like an unresolved legacy method does.
     */
    public static function resolveById(int $tenantId, int $paymentMethodId): ?object
    {
        return self::lookup($tenantId, fn ($query) => $query->where('pm.id', $paymentMethodId));
    }

    private static function lookup(int $tenantId, callable $constrain): ?object
    {
        $query = DB::table('payment_methods as pm')
            ->join('financial_accounts as a', 'a.id', '=', 'pm.financial_account_id')
            ->where('pm.tenant_id', $tenantId)
            ->where('pm.is_active', true)
            ->where('a.is_active', true)
            ->whereNull('a.deleted_at')
            ->select('pm.id', 'pm.code', 'pm.name', 'pm.type', 'a.code as account_code');
        $constrain($query);

        $row = $query->first();

        return $row === null ? null : (object) [
            'paymentMethodId' => (int) $row->id,
            'code' => $row->code,
            'name' => $row->name,
            'type' => $row->type,
            'accountCode' => $row->account_code,
        ];
    }
}
