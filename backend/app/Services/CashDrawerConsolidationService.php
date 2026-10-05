<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/** Reviewed maintenance: preserves amounts and IDs while consolidating a drawer's references. */
final class CashDrawerConsolidationService
{
    private const LOCATIONS = [
        'branches' => ['pos_cash_financial_location_id', 'shift_close_destination_financial_location_id'],
        'shifts' => ['financial_location_id', 'close_destination_financial_location_id'],
        'journal_entry_lines' => ['financial_location_id'],
        'cash_transfers' => ['from_financial_location_id', 'to_financial_location_id'],
        'customer_payments' => ['financial_location_id'], 'customer_refunds' => ['financial_location_id'],
        'expenses' => ['paid_from_financial_location_id'], 'finance_documents' => ['financial_location_id'],
        'financial_reconciliations' => ['financial_location_id'], 'payment_methods' => ['financial_location_id'],
        'supplier_payments' => ['financial_location_id'],
    ];

    private const ACCOUNTS = [
        'journal_entry_lines' => ['financial_account_id'], 'finance_document_lines' => ['financial_account_id'],
        'supplier_invoice_lines' => ['financial_account_id'], 'supplier_invoices' => ['debit_account_id'],
        'financial_reconciliations' => ['financial_account_id'], 'payment_methods' => ['financial_account_id'],
    ];

    /** Historical locations retain their original provenance, including unlocated lines. */
    public function run(int $tenant, int $branch, int $fromAccount, int $toAccount, array $oldLocations, int $drawer, bool $apply = false, ?string $expected = null, ?string $backupHash = null, array $historicalLocations = [], bool $includePlan = false): array
    {
        return DB::transaction(function () use ($tenant, $branch, $fromAccount, $toAccount, $oldLocations, $drawer, $apply, $expected, $backupHash, $historicalLocations, $includePlan): array {
            $tables = array_unique([...array_keys(self::LOCATIONS), ...array_keys(self::ACCOUNTS), 'financial_accounts', 'financial_locations', 'journal_entries']);
            sort($tables);
            DB::statement("SET LOCAL lock_timeout = '5s'");
            DB::statement('LOCK TABLE '.implode(', ', $tables).' IN SHARE ROW EXCLUSIVE MODE');
            if (DB::table('activity_logs')->where('tenant_id', $tenant)->where('action', 'finance.cash_drawer_consolidated')->where('entity_id', $drawer)->exists()) {
                return ['alreadyApplied' => true];
            }
            $target = DB::table('financial_locations')->where('tenant_id', $tenant)->where('id', $drawer)->first();
            $account = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('id', $toAccount)->where('is_active', true)->whereNull('deleted_at')->first();
            $source = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('id', $fromAccount)->first();
            $this->require($target && $account && $source && $fromAccount !== $toAccount
                && (int) $target->financial_account_id === $toAccount && (int) $target->branch_id === $branch
                && $target->type === 'cash_drawer' && $target->is_active, 'Invalid consolidation target.');
            $sourceLocations = [...$oldLocations, ...$historicalLocations];
            $old = DB::table('financial_locations')->where('tenant_id', $tenant)->whereIn('id', $sourceLocations)->get();
            $this->require($old->count() === count($sourceLocations) && ! in_array($drawer, $sourceLocations, true), 'Invalid source locations.');
            foreach ($old as $row) {
                $this->require((int) $row->financial_account_id === $fromAccount
                    && ($row->branch_id === null || (int) $row->branch_id === $branch), 'Source drawer belongs to another account or branch.');
                if (in_array((int) $row->id, $historicalLocations, true)) {
                    $this->require($row->branch_id === null, 'Only an unassigned historical location can retain its identity.');
                    $this->require(! DB::table('shifts')->where('tenant_id', $tenant)->where('financial_location_id', $row->id)
                        ->where('status', 'open')->whereNull('deleted_at')->exists(), 'Historical location has an open shift.');
                }
            }
            $this->require(! DB::table('journal_entry_lines')->where('tenant_id', $tenant)->where('financial_account_id', $fromAccount)
                ->whereNotNull('financial_location_id')->whereNotIn('financial_location_id', [...$sourceLocations, $drawer])->exists(), 'Source account includes another branch; split its history first.');
            $this->require(DB::table('shifts')->where('tenant_id', $tenant)->whereIn('financial_location_id', [...$oldLocations, $drawer])
                ->where('status', 'open')->whereNull('deleted_at')->count() <= 1, 'Overlapping shifts must be reconciled first.');
            $before = [];
            $patches = [];
            foreach ($tables as $table) {
                foreach (DB::table($table)->where('tenant_id', $tenant)->orderBy('id')->get() as $row) {
                    $patch = [];
                    foreach (self::LOCATIONS[$table] ?? [] as $column) {
                        if (in_array((int) ($row->$column ?? 0), $oldLocations, true)) $patch[$column] = $drawer;
                    }
                    foreach (self::ACCOUNTS[$table] ?? [] as $column) {
                        if ((int) ($row->$column ?? 0) === $fromAccount) {
                            $patch[$column] = $toAccount;
                            if ($table === 'journal_entry_lines' && $historicalLocations === []) $patch['financial_location_id'] = $drawer;
                        }
                    }
                    if ($table === 'branches' && (int) $row->id === $branch) $patch['pos_cash_financial_location_id'] = $drawer;
                    if ($table === 'financial_locations' && in_array((int) $row->id, $sourceLocations, true)) {
                        $patch = ['is_active' => false, 'financial_account_id' => $toAccount];
                    }
                    if ($patch !== []) {
                        $before[$table][$row->id] = (array) $row;
                        $patches[$table][$row->id] = $patch;
                    }
                }
            }
            $fingerprint = hash('sha256', json_encode([$before, $patches], JSON_THROW_ON_ERROR));
            $net = $this->net($tenant, [$fromAccount, $toAccount]);
            $report = ['alreadyApplied' => false, 'fingerprint' => $fingerprint, 'changes' => array_map('count', $patches),
                'combinedBalance' => Money::decimal($net), 'sourceCode' => $source->code, 'targetCode' => $account->code];
            if ($historicalLocations !== []) $report['historicalLocationsRetained'] = $historicalLocations;
            if (! $apply) return $includePlan ? $report + ['beforeState' => $before, 'patches' => $patches] : $report;
            $this->require($expected && hash_equals($fingerprint, $expected) && $backupHash, 'Fresh dry-run fingerprint and backup hash required.');
            foreach ($patches as $table => $rows) {
                foreach ($rows as $id => $patch) DB::table($table)->where('tenant_id', $tenant)->where('id', $id)->update($patch);
            }
            $this->require($this->net($tenant, [$fromAccount, $toAccount]) === $net, 'Combined balance changed.');
            $this->require($this->net($tenant, [$fromAccount]) === 0, 'Source retains a posted balance.');
            app(OperationalAuditService::class)->recordContext($tenant, 'finance.cash_drawer_consolidated', 'financial_location', $drawer,
                ['report' => $report, 'patches' => $patches, 'backupSha256' => $backupHash], branchId: $branch, before: $before);

            return $report + ['applied' => true];
        });
    }

    private function net(int $tenant, array $accounts): int
    {
        $sum = DB::table('journal_entry_lines as l')->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')
            ->where('l.tenant_id', $tenant)->where('e.tenant_id', $tenant)->where('e.status', 'posted')
            ->whereIn('l.financial_account_id', $accounts)->selectRaw('COALESCE(SUM(l.debit-l.credit),0) as net')->first();
        return Money::cents($sum->net);
    }

    private function require(bool $condition, string $message): void
    {
        if (! $condition) throw new RuntimeException($message);
    }
}
