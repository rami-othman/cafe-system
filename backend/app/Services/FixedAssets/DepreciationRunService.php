<?php

namespace App\Services\FixedAssets;

use App\Services\AccountingPostingService;
use App\Services\JournalEntryService;
use App\Services\OperationalAuditService;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Depreciation runs ("مذكرة اهتلاك"): computes every due asset up to a date, posts ONE journal
 * entry grouped by (expense account, accumulated account, branch) and keeps the per-asset detail
 * in fixed_asset_transactions. A run can be reversed only while it is the latest movement of
 * every asset it touched.
 */
final class DepreciationRunService
{
    public function __construct(
        private readonly AssetBook $book,
        private readonly DepreciationCalculator $calculator,
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
    ) {}

    /**
     * @param  array{periodEnd:string, branchId?:?int, companyOnly?:bool, categoryId?:?int, assetId?:?int}  $filters
     * @return array<int, array<string,mixed>>
     */
    public function preview(int $tenantId, array $filters): array
    {
        $rows = [];
        foreach ($this->candidates($tenantId, $filters, false) as $asset) {
            $book = $this->book->totals($tenantId, (int) $asset->id);
            $calc = $this->calculator->forPeriod($asset, $book, $filters['periodEnd']);
            if ($calc === null) {
                continue;
            }
            $rows[] = [
                'asset' => $asset,
                'book' => $book,
                'calc' => $calc,
            ];
        }

        return $rows;
    }

    public function previewPayload(int $tenantId, array $filters): array
    {
        $rows = $this->preview($tenantId, $filters);
        $names = $this->branchNames($tenantId);
        $lines = array_map(fn (array $r) => $this->lineView($r['asset'], $r['book'], $r['calc'], $names), $rows);

        return ['periodEnd' => $filters['periodEnd'], 'lines' => $lines, 'total' => Money::decimal(array_sum(array_map(fn ($r) => $r['calc']['amount'], $rows))), 'assetsCount' => count($rows)];
    }

    /** @return int the run id */
    public function run(Request $request, int $tenantId, array $filters, ?int $actorId, string $trigger = 'manual', bool $allowEmpty = false): ?int
    {
        $periodEnd = $filters['periodEnd'];
        if ($trigger === 'manual' && CarbonImmutable::parse($periodEnd)->gt(CarbonImmutable::today())) {
            throw ValidationException::withMessages(['periodEnd' => 'لا يمكن الاهتلاك لتاريخ مستقبلي.']);
        }

        $work = function () use ($request, $tenantId, $filters, $actorId, $trigger, $allowEmpty, $periodEnd): ?int {
            $assets = $this->candidates($tenantId, $filters, true);
            $items = [];
            foreach ($assets as $asset) {
                $book = $this->book->totals($tenantId, (int) $asset->id);
                $calc = $this->calculator->forPeriod($asset, $book, $periodEnd);
                if ($calc === null) {
                    continue;
                }
                $accounts = $this->book->requireAccounts($tenantId, $asset, ['accumulated', 'expense']);
                $items[] = compact('asset', 'book', 'calc', 'accounts');
            }
            if ($items === []) {
                if ($allowEmpty) {
                    return null;
                }
                throw ValidationException::withMessages(['periodEnd' => 'لا يوجد اهتلاك مستحق حتى هذا التاريخ.']);
            }

            $now = now();
            $total = array_sum(array_map(fn ($i) => $i['calc']['amount'], $items));
            $runId = (int) DB::table('depreciation_runs')->insertGetId([
                'tenant_id' => $tenantId,
                'run_number' => DocumentNumber::next($tenantId, 'depreciation_runs', 'run_number', 'DEP-'),
                'period_end' => $periodEnd,
                'branch_id' => $filters['branchId'] ?? null,
                'category_id' => $filters['categoryId'] ?? null,
                'fixed_asset_id' => $filters['assetId'] ?? null,
                'filter_company_only' => (bool) ($filters['companyOnly'] ?? false),
                'status' => 'posted',
                'trigger' => $trigger,
                'total_amount' => Money::decimal($total),
                'assets_count' => count($items),
                'description' => $filters['description'] ?? null,
                'created_by' => $actorId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $groups = [];
            foreach ($items as $item) {
                $branch = $item['asset']->branch_id ? (int) $item['asset']->branch_id : null;
                $key = $item['accounts']['expense'].'|'.$item['accounts']['accumulated'].'|'.($branch ?? 'c');
                $groups[$key] ??= ['expense' => $item['accounts']['expense'], 'accumulated' => $item['accounts']['accumulated'], 'branch' => $branch, 'amount' => 0];
                $groups[$key]['amount'] += $item['calc']['amount'];
            }
            $lines = [];
            foreach ($groups as $group) {
                $lines[] = ['accountId' => $group['expense'], 'branchId' => $group['branch'], 'debit' => Money::decimal($group['amount']), 'credit' => '0.00', 'description' => 'مصروف اهتلاك حتى '.$periodEnd];
                $lines[] = ['accountId' => $group['accumulated'], 'branchId' => $group['branch'], 'debit' => '0.00', 'credit' => Money::decimal($group['amount']), 'description' => 'مجمع اهتلاك حتى '.$periodEnd];
            }
            $branchIds = array_unique(array_map(fn ($g) => $g['branch'], $groups));
            $journalId = $this->posting->post($request, $tenantId, [
                'sourceType' => 'asset_depreciation',
                'sourceId' => $runId,
                'sourceEvent' => 'POSTED',
                'branchId' => count($branchIds) === 1 ? reset($branchIds) : null,
                'entryDate' => $periodEnd,
                'description' => 'مذكرة اهتلاك حتى تاريخ '.$periodEnd.($filters['description'] ?? '' ? ' — '.$filters['description'] : ''),
                'lines' => $lines,
            ], $actorId);

            foreach ($items as $item) {
                $asset = $item['asset'];
                DB::table('fixed_asset_transactions')->insert([
                    'tenant_id' => $tenantId,
                    'fixed_asset_id' => $asset->id,
                    'type' => 'depreciation',
                    'transaction_date' => $periodEnd,
                    'depreciation_amount' => Money::decimal($item['calc']['amount']),
                    'branch_id' => $asset->branch_id,
                    'journal_entry_id' => $journalId,
                    'depreciation_run_id' => $runId,
                    'period_from' => $item['calc']['from'],
                    'period_to' => $item['calc']['to'],
                    'previous_depreciated_until' => $asset->depreciated_until,
                    'previous_status' => $asset->status,
                    'created_by' => $actorId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                DB::table('fixed_assets')->where('id', $asset->id)->update([
                    'depreciated_until' => $periodEnd,
                    'status' => $item['calc']['fullyDepreciated'] ? 'fully_depreciated' : $asset->status,
                    'updated_at' => $now,
                ]);
            }
            DB::table('depreciation_runs')->where('id', $runId)->update(['journal_entry_id' => $journalId, 'updated_at' => $now]);
            $this->audit->record($request, $tenantId, 'asset_depreciation.posted', 'depreciation_run', $runId, [], ['total' => Money::decimal($total), 'assets' => count($items)], $filters['branchId'] ?? null, $actorId);

            return $runId;
        };

        return DB::transactionLevel() > 0 ? $work() : DB::transaction($work);
    }

    public function reverse(Request $request, int $tenantId, int $runId, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $runId, $actorId): void {
            $run = DB::table('depreciation_runs')->where('tenant_id', $tenantId)->where('id', $runId)->lockForUpdate()->first();
            abort_unless($run, 404, 'المذكرة غير موجودة.');
            if ($run->status !== 'posted') {
                throw ValidationException::withMessages(['run' => 'المذكرة معكوسة مسبقًا.']);
            }
            $txs = DB::table('fixed_asset_transactions')->where('tenant_id', $tenantId)->where('depreciation_run_id', $runId)->whereNull('voided_at')->get();
            foreach ($txs as $tx) {
                $latest = $this->book->latestTransaction($tenantId, (int) $tx->fixed_asset_id);
                if ($latest && (int) $latest->id !== (int) $tx->id) {
                    $name = DB::table('fixed_assets')->where('id', $tx->fixed_asset_id)->value('name_ar');
                    throw ValidationException::withMessages(['run' => "لا يمكن عكس المذكرة: الأصل «{$name}» له حركات أحدث. اعكس الحركات الأحدث أولًا."]);
                }
            }
            $reversal = $run->journal_entry_id ? $this->entries->reverse($request, $tenantId, (int) $run->journal_entry_id, $actorId, true, $run->period_end) : null;
            $now = now();
            foreach ($txs as $tx) {
                DB::table('fixed_asset_transactions')->where('id', $tx->id)->update(['voided_at' => $now, 'voided_by' => $actorId, 'reversal_journal_entry_id' => $reversal, 'updated_at' => $now]);
                DB::table('fixed_assets')->where('id', $tx->fixed_asset_id)->update(['depreciated_until' => $tx->previous_depreciated_until, 'status' => $tx->previous_status ?? 'active', 'updated_at' => $now]);
            }
            DB::table('depreciation_runs')->where('id', $runId)->update(['status' => 'reversed', 'reversal_journal_entry_id' => $reversal, 'reversed_by' => $actorId, 'reversed_at' => $now, 'updated_at' => $now]);
            $this->audit->record($request, $tenantId, 'asset_depreciation.reversed', 'depreciation_run', $runId, [], ['reversalJournalId' => $reversal], $run->branch_id, $actorId);
        });
    }

    public function show(int $tenantId, int $runId): array
    {
        $run = DB::table('depreciation_runs')->where('tenant_id', $tenantId)->where('id', $runId)->first();
        abort_unless($run, 404, 'المذكرة غير موجودة.');
        $names = $this->branchNames($tenantId);
        $lines = DB::table('fixed_asset_transactions as t')->join('fixed_assets as a', 'a.id', '=', 't.fixed_asset_id')
            ->where('t.tenant_id', $tenantId)->where('t.depreciation_run_id', $runId)->orderBy('a.code')
            ->get(['t.*', 'a.code', 'a.name_ar', 'a.acquisition_cost'])->map(fn ($t) => [
                'assetId' => (int) $t->fixed_asset_id, 'assetCode' => $t->code, 'assetName' => $t->name_ar,
                'branchName' => $t->branch_id ? ($names[(int) $t->branch_id] ?? null) : 'الإدارة العامة',
                'from' => $t->period_from, 'to' => $t->period_to, 'amount' => Money::decimal(Money::cents((string) $t->depreciation_amount)),
                'voided' => $t->voided_at !== null,
            ])->values()->all();

        return $this->runView($run) + ['lines' => $lines];
    }

    public function runView(object $run): array
    {
        $journal = $run->journal_entry_id ? DB::table('journal_entries')->where('id', $run->journal_entry_id)->value('entry_number') : null;

        return [
            'id' => (int) $run->id, 'runNumber' => $run->run_number, 'periodEnd' => $run->period_end, 'status' => $run->status,
            'trigger' => $run->trigger, 'branchId' => $run->branch_id ? (int) $run->branch_id : null, 'categoryId' => $run->category_id ? (int) $run->category_id : null,
            'assetId' => $run->fixed_asset_id ? (int) $run->fixed_asset_id : null, 'total' => Money::decimal(Money::cents((string) $run->total_amount)),
            'assetsCount' => (int) $run->assets_count, 'description' => $run->description,
            'journalEntryId' => $run->journal_entry_id ? (int) $run->journal_entry_id : null, 'journalNumber' => $journal,
            'reversalJournalEntryId' => $run->reversal_journal_entry_id ? (int) $run->reversal_journal_entry_id : null,
            'createdAt' => (string) $run->created_at, 'reversedAt' => $run->reversed_at,
        ];
    }

    private function candidates(int $tenantId, array $filters, bool $lock)
    {
        $query = DB::table('fixed_assets')->where('tenant_id', $tenantId)->whereNull('deleted_at')
            ->where('status', 'active')->whereIn('method', DepreciationCalculator::DEPRECIATING)
            ->where('depreciation_start_date', '<=', $filters['periodEnd'])
            ->when(! empty($filters['assetId']), fn ($q) => $q->where('id', (int) $filters['assetId']))
            ->when(! empty($filters['categoryId']), fn ($q) => $q->where('category_id', (int) $filters['categoryId']))
            ->when(! empty($filters['branchId']), fn ($q) => $q->where('branch_id', (int) $filters['branchId']))
            ->when(! empty($filters['companyOnly']), fn ($q) => $q->whereNull('branch_id'))
            ->orderBy('id');

        return $lock ? $query->lockForUpdate()->get() : $query->get();
    }

    private function branchNames(int $tenantId): array
    {
        return DB::table('branches')->where('tenant_id', $tenantId)->pluck('name', 'id')->mapWithKeys(fn ($n, $id) => [(int) $id => $n])->all();
    }

    private function lineView(object $asset, array $book, array $calc, array $names): array
    {
        return [
            'assetId' => (int) $asset->id, 'assetCode' => $asset->code, 'assetName' => $asset->name_ar,
            'branchName' => $asset->branch_id ? ($names[(int) $asset->branch_id] ?? null) : 'الإدارة العامة',
            'from' => $calc['from'], 'to' => $calc['to'], 'days' => $calc['days'],
            'cost' => Money::decimal($book['cost']), 'salvage' => Money::decimal(Money::cents((string) $asset->salvage_value)),
            'accumulatedBefore' => Money::decimal($book['accumulated']), 'amount' => Money::decimal($calc['amount']),
            'bookValueAfter' => Money::decimal($book['cost'] - $book['accumulated'] - $calc['amount']),
        ];
    }
}
