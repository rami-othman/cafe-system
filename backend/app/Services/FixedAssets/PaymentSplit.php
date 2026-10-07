<?php

namespace App\Services\FixedAssets;

use App\Support\Money;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * An outlay (acquisition, addition, maintenance, expense) may be paid from several accounts.
 * Normalises the request ("payments": [{accountId, amount}] or the legacy single account), checks the
 * parts add up to the total to the cent, and builds the credit lines of the journal entry.
 */
final class PaymentSplit
{
    /**
     * @param  array<int, array{accountId?:mixed, amount?:mixed}>|null  $payments
     * @return list<array{accountId:int, cents:int}> merged per account
     */
    public function normalize(int $tenantId, ?array $payments, ?int $singleAccountId, int $totalCents, string $field = 'payments'): array
    {
        if ($payments === null || $payments === []) {
            if (! $singleAccountId) {
                throw ValidationException::withMessages([$field => 'حدد حساب الدفع.']);
            }
            $payments = [['accountId' => $singleAccountId, 'amount' => Money::decimal($totalCents)]];
        }
        $merged = [];
        foreach ($payments as $i => $payment) {
            $accountId = (int) ($payment['accountId'] ?? 0);
            $cents = Money::cents((string) ($payment['amount'] ?? '0'), "{$field}.{$i}.amount");
            if ($cents <= 0) {
                throw ValidationException::withMessages(["{$field}.{$i}.amount" => 'مبلغ الدفعة يجب أن يكون أكبر من صفر.']);
            }
            if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->where('is_active', true)->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(["{$field}.{$i}.accountId" => 'حساب الدفع غير موجود أو غير مفعّل.']);
            }
            $merged[$accountId] = ($merged[$accountId] ?? 0) + $cents;
        }
        $sum = array_sum($merged);
        if ($sum !== $totalCents) {
            throw ValidationException::withMessages([$field => 'مجموع الدفعات ('.Money::decimal($sum).') لا يساوي المبلغ ('.Money::decimal($totalCents).').']);
        }

        return array_map(fn ($accountId, $cents) => ['accountId' => (int) $accountId, 'cents' => (int) $cents], array_keys($merged), array_values($merged));
    }

    /** Credit journal lines, one per paying account. */
    public function creditLines(array $split, ?int $branch): array
    {
        return array_map(fn (array $p) => ['accountId' => $p['accountId'], 'branchId' => $branch, 'debit' => '0.00', 'credit' => Money::decimal($p['cents'])], $split);
    }

    /** Persists the split against a ledger transaction. */
    public function store(int $tenantId, int $assetId, ?int $transactionId, array $split): void
    {
        $now = now();
        foreach ($split as $p) {
            DB::table('fixed_asset_payments')->insert([
                'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'transaction_id' => $transactionId,
                'account_id' => $p['accountId'], 'amount' => Money::decimal($p['cents']), 'created_at' => $now, 'updated_at' => $now,
            ]);
        }
    }
}
