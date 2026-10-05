<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/** Explicit maintenance operation for a restored local database, never an automatic migration. */
final class PhinixHistoryConsolidation
{
    public const ACTION = 'finance.phinix_history_consolidated';

    private const REFERENCES = [
        'journal_entry_lines' => ['financial_account_id'],
        'finance_document_lines' => ['financial_account_id'],
        'supplier_invoice_lines' => ['financial_account_id'],
        'supplier_invoices' => ['debit_account_id'],
        'financial_reconciliations' => ['financial_account_id'],
        'payment_methods' => ['financial_account_id'],
        'financial_locations' => ['financial_account_id'],
        'expense_categories' => ['financial_account_id'],
        'sales_account_mappings' => ['financial_account_id'],
        'customers' => ['financial_account_id'],
        'branches' => ['cash_variance_account_id', 'cash_over_account_id'],
    ];

    public function run(int $tenantId, array $documentOverrides, bool $apply = false, ?string $expected = null, ?string $backupHash = null): array
    {
        return DB::transaction(function () use ($tenantId, $documentOverrides, $apply, $expected, $backupHash): array {
            DB::statement("SET LOCAL lock_timeout = '5s'");
            // Maintenance must see a stable source and prevent postings between validation and commit.
            $tables = array_unique([...array_keys(self::REFERENCES), 'journal_entries', 'financial_accounts', 'finance_documents', 'activity_logs', 'accounting_periods']);
            sort($tables);
            DB::statement('LOCK TABLE '.implode(', ', $tables).' IN SHARE ROW EXCLUSIVE MODE');
            if (DB::table('activity_logs')->where('tenant_id', $tenantId)->where('action', self::ACTION)->exists()) {
                return ['alreadyApplied' => true];
            }
            $this->require(app(PhinixRemapService::class)->isPhinixTenant($tenantId), 'Missing Phinix chart.');
            $this->require(! DB::table('accounting_periods')->where('tenant_id', $tenantId)->whereIn('status', ['locked', 'closed'])->exists(), 'Closed accounting periods require a separate reviewed procedure.');

            $before = [];
            foreach ($tables as $table) {
                if ($table !== 'activity_logs') {
                    $before[$table] = DB::table($table)->where('tenant_id', $tenantId)->orderBy('id')->get()->map(fn ($r) => (array) $r)->all();
                }
            }
            $accounts = array_column($before['financial_accounts'], null, 'code');
            $map = [];
            foreach (PhinixRemapService::LEGACY_TO_NEW as $from => $to) {
                if (! isset($accounts[$from])) {
                    continue;
                }
                $target = $accounts[$to] ?? null;
                $this->require($target && $target['is_active'] && ! $target['deleted_at'], "Missing active target account {$to}.");
                $map[$accounts[$from]['id']] = $target['id'];
            }
            $entries = array_column($before['journal_entries'], null, 'id');
            $transfers = [];
            foreach ($entries as $entry) {
                if ($entry['source_type'] !== 'legacy_reclassification') {
                    continue;
                }
                $this->require(in_array($entry['source_event'], ['LEGACY_TO_PHINIX', 'SERVICES_EXPENSE_SPLIT'], true)
                    && $entry['status'] === 'posted' && (int) $entry['source_id'] === $tenantId && ! $entry['reversal_of_id'], 'Unexpected reclassification entry.');
                $transfers[] = $entry['id'];
            }
            $this->require(count($transfers) === 2 && count(array_unique(array_column(array_intersect_key($entries, array_flip($transfers)), 'source_event'))) === 2, 'Expected exactly the two reviewed transfer events.');
            foreach ($entries as $entry) {
                $this->require(! in_array($entry['reversal_of_id'], $transfers, true), 'A transfer has already been reversed.');
            }
            // Refuse to supersede a journal that any business document depends on.
            foreach (DB::select("SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public' AND column_name LIKE '%journal_entry_id'") as $reference) {
                if ($reference->table_name === 'journal_entry_lines') {
                    continue;
                }
                $this->require(! DB::table($reference->table_name)->whereIn($reference->column_name, $transfers)->exists(), "Transfer referenced by {$reference->table_name}.");
            }
            $documents = array_column($before['finance_documents'], null, 'id');
            $serviceId = $accounts['6120']['id'] ?? null;
            foreach ($documentOverrides as $id => $code) {
                $this->require(isset($documents[$id], $accounts[$code]) && in_array((string) $code, ['511', '5043'], true), 'Invalid service document override.');
                $this->require($accounts[$code]['is_active'] && ! $accounts[$code]['deleted_at'], 'Inactive service target.');
                $this->require(collect($before['finance_document_lines'])->contains(fn ($line) => (int) $line['finance_document_id'] === (int) $id && $line['financial_account_id'] === $serviceId), 'Override has no legacy service line.');
            }
            $targetForDocument = function ($id) use ($documentOverrides, $accounts): int {
                $this->require(isset($documentOverrides[$id]), "Service document {$id} needs an explicit reviewed account.");

                return $accounts[$documentOverrides[$id]]['id'];
            };
            $after = $before;
            $changes = [];
            foreach (self::REFERENCES as $table => $columns) {
                foreach ($after[$table] as &$row) {
                    if ($table === 'journal_entry_lines' && in_array($row['journal_entry_id'], $transfers, true)) {
                        continue; // Preserve every transfer line exactly as recorded.
                    }
                    foreach ($columns as $column) {
                        $old = $row[$column];
                        if (! isset($map[$old])) {
                            continue;
                        }
                        $new = $map[$old];
                        if ($old === $serviceId) {
                            if ($table === 'finance_document_lines') {
                                $new = $targetForDocument($row['finance_document_id']);
                            } elseif ($table === 'journal_entry_lines') {
                                $entry = $entries[$row['journal_entry_id']];
                                $seen = [];
                                while ($entry['reversal_of_id']) {
                                    $this->require(! isset($seen[$entry['id']]) && isset($entries[$entry['reversal_of_id']]), 'Broken reversal ancestry.');
                                    $seen[$entry['id']] = true;
                                    $entry = $entries[$entry['reversal_of_id']];
                                }
                                $this->require($entry['source_type'] === 'finance_document', 'Unclassified legacy service journal.');
                                $new = $targetForDocument($entry['source_id']);
                            } else {
                                throw new RuntimeException("Service reference in {$table} needs separate review.");
                            }
                        }
                        $row[$column] = $new;
                        $changes[$table][$row['id']][$column] = $new;
                    }
                }
                unset($row);
            }
            foreach ($after['journal_entries'] as &$entry) {
                if (in_array($entry['id'], $transfers, true)) {
                    $entry['status'] = 'superseded';
                    $changes['journal_entries'][$entry['id']] = ['status' => 'superseded'];
                }
            }
            unset($entry);
            // Keep legacy accounts for audit, but prevent new manual postings to them.
            foreach ($after['financial_accounts'] as &$account) {
                if (isset($map[$account['id']]) && $account['is_active']) {
                    $account['is_active'] = false;
                    $changes['financial_accounts'][$account['id']] = ['is_active' => false];
                }
            }
            unset($account);
            $balancesBefore = $this->balances($before);
            $balancesAfter = $this->balances($after);
            $this->require($balancesBefore === $balancesAfter, 'Account/location balances would change. No changes applied.');
            $fingerprint = hash('sha256', json_encode([$before, $documentOverrides], JSON_THROW_ON_ERROR));
            $report = ['alreadyApplied' => false, 'fingerprint' => $fingerprint, 'changes' => array_map('count', $changes), 'supersededEntries' => $transfers,
                'journalsPreserved' => count($entries), 'linesPreserved' => count($before['journal_entry_lines']), 'balancesMatch' => true];
            if (! $apply) {
                return $report;
            }
            $this->require($expected !== null && hash_equals($fingerprint, $expected), 'Source changed or expected fingerprint missing. Run a new preview.');
            $this->require($backupHash !== null && preg_match('/^[a-f0-9]{64}$/', $backupHash) === 1, 'Verified backup hash required.');
            foreach ($changes as $table => $rows) {
                foreach ($rows as $id => $patch) {
                    $this->require(DB::table($table)->where('tenant_id', $tenantId)->where('id', $id)->update($patch) === 1, 'Unexpected update count.');
                }
            }
            // Full-row equality proves no number, date, amount, source link or unplanned field was touched.
            foreach ($after as $table => $rows) {
                $actual = DB::table($table)->where('tenant_id', $tenantId)->orderBy('id')->get()->map(fn ($r) => (array) $r)->all();
                $this->require($rows === $actual, "Unexpected data change in {$table}; rolling back.");
            }
            $originalRows = [];
            foreach ($changes as $table => $rows) {
                $originalRows[$table] = array_values(array_filter($before[$table], fn ($row) => isset($rows[$row['id']])));
            }
            app(OperationalAuditService::class)->recordContext($tenantId, self::ACTION, 'tenant', $tenantId,
                after: $report + ['backupSha256' => $backupHash, 'documentOverrides' => $documentOverrides, 'patches' => $changes],
                before: ['rows' => $originalRows]);

            return $report;
        });
    }

    private function balances(array $state): array
    {
        $entries = array_column($state['journal_entries'], null, 'id');
        $balances = [];
        $entryTotals = [];
        foreach ($state['journal_entry_lines'] as $line) {
            $this->require(isset($entries[$line['journal_entry_id']]), 'Missing tenant-scoped journal.');
            if ($entries[$line['journal_entry_id']]['status'] !== 'posted') {
                continue;
            }
            $net = Money::cents($line['debit']) - Money::cents($line['credit']);
            $key = $line['financial_account_id'].':'.($line['financial_location_id'] ?? 'null');
            $balances[$key] = ($balances[$key] ?? 0) + $net;
            $entryTotals[$line['journal_entry_id']] = ($entryTotals[$line['journal_entry_id']] ?? 0) + $net;
        }
        $this->require(array_filter($entryTotals) === [], 'Unbalanced posted journal.');
        $balances = array_filter($balances, fn ($value) => $value !== 0);
        ksort($balances);

        return $balances;
    }

    private function require(bool $condition, string $message): void
    {
        if (! $condition) {
            throw new RuntimeException($message);
        }
    }
}
