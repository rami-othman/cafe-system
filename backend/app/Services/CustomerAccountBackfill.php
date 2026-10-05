<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use RuntimeException;

final class CustomerAccountBackfill
{
    public function run(int $tenantId, bool $apply = false, ?string $backupHash = null): array
    {
        return DB::transaction(function () use ($tenantId, $apply, $backupHash): array {
            DB::statement("SET LOCAL lock_timeout = '5s'");
            DB::statement('LOCK TABLE customers, financial_accounts, suppliers, journal_entries, journal_entry_lines, finance_document_lines IN SHARE ROW EXCLUSIVE MODE');
            foreach (['121', '223'] as $code) {
                if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', $code)
                    ->where('catalog_source', 'phinix')->where('is_active', true)->whereNull('deleted_at')->exists()) {
                    throw new RuntimeException("Active Phinix parent {$code} is required.");
                }
            }
            $customers = DB::table('customers')->where('tenant_id', $tenantId)->whereNull('deleted_at')
                ->where('is_active', true)->where('is_walk_in', false)->where('customer_type', 'registered')
                ->whereNull('financial_account_id')->orderBy('id')->get();
            $report = ['missing' => $customers->count(), 'linked' => [], 'customerIds' => $customers->pluck('id')->all()];
            if (! $apply || $customers->isEmpty()) {
                return $report;
            }
            if (! $backupHash || ! preg_match('/^[a-f0-9]{64}$/', $backupHash)) {
                throw new RuntimeException('A backup SHA-256 is required before applying.');
            }
            // Backfill creates account identities, never historical ledger movements or opening balances.
            $originalLedger = $this->ledgerHash($tenantId);
            foreach ($customers as $customer) {
                $id = app(PartyAccountService::class)->ensureForCustomer($tenantId, (int) $customer->id);
                $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $id)->first();
                $parent = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $account->parent_account_id)->first();
                $supplier = DB::table('suppliers')->where('tenant_id', $tenantId)->where('customer_id', $customer->id)->whereNull('deleted_at')->exists();
                if ($account->catalog_source !== 'phinix' || ! $account->is_active || $parent?->code !== ($supplier ? '223' : '121')) {
                    throw new RuntimeException('Unexpected account placement; the backfill has been rolled back.');
                }
                $updated = (array) DB::table('customers')->where('id', $customer->id)->first();
                $before = (array) $customer;
                unset($before['financial_account_id'], $before['updated_at'], $updated['financial_account_id'], $updated['updated_at']);
                if ($before !== $updated) {
                    throw new RuntimeException('Unexpected customer changes; the backfill has been rolled back.');
                }
                $report['linked'][] = ['customerId' => (int) $customer->id, 'accountId' => $id, 'accountCode' => $account->code, 'parentCode' => $parent->code];
                app(OperationalAuditService::class)->recordContext($tenantId, 'customer.financial_account_backfilled', 'customer', (int) $customer->id,
                    after: ['financialAccountId' => $id, 'accountCode' => $account->code, 'backupSha256' => $backupHash],
                    before: ['financialAccountId' => null, 'updatedAt' => $customer->updated_at]);
            }
            if ($originalLedger !== $this->ledgerHash($tenantId)) {
                throw new RuntimeException('Ledger changed during identity backfill; rolling back.');
            }
            $report['ledgerUnchanged'] = true;

            return $report;
        });
    }

    private function ledgerHash(int $tenantId): array
    {
        $hashes = [];
        foreach (['journal_entries', 'journal_entry_lines', 'finance_document_lines'] as $table) {
            $hashes[$table] = DB::selectOne("SELECT md5(COALESCE(string_agg(to_jsonb(t)::text, '' ORDER BY id), '')) AS hash FROM {$table} t WHERE tenant_id = ?", [$tenantId])->hash;
        }

        return $hashes;
    }
}
