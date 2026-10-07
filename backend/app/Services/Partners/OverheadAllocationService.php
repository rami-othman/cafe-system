<?php

namespace App\Services\Partners;

use App\Services\AccountingPostingService;
use App\Services\FinancialReportQueryService;
use App\Services\FixedAssets\DocumentNumber;
use App\Services\JournalEntryService;
use App\Services\OperationalAuditService;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Charges head-office expenses (journal lines with no branch) to branches for a period.
 * The amount per expense account is the head office's NET balance in the period, so running it
 * again (or after a partial run) only moves what is still sitting on the head office.
 * Shares: by branch revenue in the period, equally, or manual percentages.
 */
final class OverheadAllocationService
{
    public function __construct(
        private readonly FinancialReportQueryService $reports,
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
    ) {}

    /**
     * @param array{basis?:string, branchIds?:array<int>, percents?:array<int,float|string>, accountIds?:array<int>} $options
     */
    public function preview(int $tenantId, int $actorId, string $from, string $to, array $options = []): array
    {
        if ($from > $to) {
            throw ValidationException::withMessages(['dateTo' => 'نهاية الفترة قبل بدايتها.']);
        }
        $basis = $options['basis'] ?? 'revenue';
        $accounts = $this->headOfficeExpenses($tenantId, $from, $to, $options['accountIds'] ?? []);
        $total = array_sum(array_column($accounts, 'amountCents'));

        $branches = DB::table('branches')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('name')->get(['id', 'name']);
        if (! empty($options['branchIds'])) {
            $wanted = array_map('intval', $options['branchIds']);
            $branches = $branches->filter(fn ($b) => in_array((int) $b->id, $wanted, true))->values();
        }
        $weights = [];
        $revenues = [];
        foreach ($branches as $b) {
            $ctx = $this->reports->context($tenantId, $actorId, ['branchId' => (int) $b->id, 'dateFrom' => $from, 'dateTo' => $to, 'comparison' => 'none']);
            $revenues[(int) $b->id] = Money::cents($this->reports->profitAndLoss($ctx)['totals']['revenue']);
        }
        $warnings = [];
        if ($basis === 'manual') {
            foreach ($branches as $b) {
                $p = (float) ($options['percents'][(int) $b->id] ?? 0);
                if ($p > 0) {
                    $weights[(int) $b->id] = $p;
                }
            }
            if (abs(array_sum($weights) - 100) > 0.0001) {
                throw ValidationException::withMessages(['percents' => 'مجموع النسب اليدوية يجب أن يساوي 100%.']);
            }
        } elseif ($basis === 'equal') {
            foreach ($branches as $b) {
                $weights[(int) $b->id] = 1.0;
            }
        } else {
            foreach ($branches as $b) {
                if ($revenues[(int) $b->id] > 0) {
                    $weights[(int) $b->id] = (float) $revenues[(int) $b->id];
                }
            }
            if ($weights === [] && $total > 0) {
                $warnings[] = 'لا توجد إيرادات للفروع بهذه الفترة؛ اختر «بالتساوي» أو نسبًا يدوية.';
            }
        }
        $sum = array_sum($weights);
        $names = $branches->pluck('name', 'id')->all();
        $shares = [];
        foreach ($weights as $branchId => $w) {
            $shares[] = ['branchId' => $branchId, 'branchName' => $names[$branchId], 'percent' => $sum > 0 ? round($w / $sum * 100, 4) : 0.0, 'revenue' => Money::decimal($revenues[$branchId] ?? 0)];
        }

        // Per account: largest-remainder split, the last branch takes the rounding difference.
        $branchTotals = array_fill_keys(array_keys($weights), 0);
        $matrix = [];
        foreach ($accounts as $acc) {
            $allocated = 0;
            $ids = array_keys($weights);
            foreach ($ids as $i => $branchId) {
                $cents = $i === count($ids) - 1 ? $acc['amountCents'] - $allocated : (int) round($acc['amountCents'] * $weights[$branchId] / $sum);
                $allocated += $cents;
                $branchTotals[$branchId] += $cents;
                $matrix[] = ['accountId' => $acc['accountId'], 'branchId' => $branchId, 'amountCents' => $cents];
            }
        }
        foreach ($shares as &$share) {
            $share['amount'] = Money::decimal($branchTotals[$share['branchId']] ?? 0);
        }
        unset($share);
        if ($accounts === []) {
            $warnings[] = 'لا توجد مصاريف على الإدارة العامة بهذه الفترة.';
        }

        return [
            'periodFrom' => $from, 'periodTo' => $to, 'basis' => $basis, 'total' => Money::decimal($total),
            'accounts' => array_map(fn ($a) => ['accountId' => $a['accountId'], 'code' => $a['code'], 'name' => $a['name'], 'amount' => Money::decimal($a['amountCents'])], $accounts),
            'branches' => $shares, 'matrix' => $matrix, 'totalCents' => $weights === [] ? 0 : $total,
            'warnings' => $warnings, 'blocking' => $total <= 0 || $weights === [],
        ];
    }

    public function post(Request $request, int $tenantId, int $actorId, array $data): int
    {
        return DB::transaction(function () use ($request, $tenantId, $actorId, $data): int {
            DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->first();
            $preview = $this->preview($tenantId, $actorId, $data['periodFrom'], $data['periodTo'], $data);
            if ($preview['blocking']) {
                throw ValidationException::withMessages(['period' => $preview['warnings'] !== [] ? implode(' ', $preview['warnings']) : 'لا يوجد ما يُوزَّع.']);
            }
            $now = now();
            $id = (int) DB::table('overhead_allocations')->insertGetId([
                'tenant_id' => $tenantId, 'allocation_number' => DocumentNumber::next($tenantId, 'overhead_allocations', 'allocation_number', 'OH-'),
                'period_from' => $data['periodFrom'], 'period_to' => $data['periodTo'], 'basis' => $preview['basis'], 'total_amount' => $preview['total'],
                'status' => 'posted', 'notes' => $data['notes'] ?? null, 'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            foreach ($preview['branches'] as $b) {
                DB::table('overhead_allocation_branches')->insert(['tenant_id' => $tenantId, 'overhead_allocation_id' => $id, 'branch_id' => $b['branchId'],
                    'share_percent' => $b['percent'], 'amount' => $b['amount'], 'created_at' => $now, 'updated_at' => $now]);
            }
            foreach ($preview['accounts'] as $a) {
                DB::table('overhead_allocation_accounts')->insert(['tenant_id' => $tenantId, 'overhead_allocation_id' => $id, 'financial_account_id' => $a['accountId'],
                    'amount' => $a['amount'], 'created_at' => $now, 'updated_at' => $now]);
            }
            $lines = [];
            $byAccount = [];
            foreach ($preview['matrix'] as $m) {
                if ($m['amountCents'] === 0) {
                    continue;
                }
                $byAccount[$m['accountId']] = ($byAccount[$m['accountId']] ?? 0) + $m['amountCents'];
                $lines[] = ['accountId' => $m['accountId'], 'branchId' => $m['branchId'], 'debit' => Money::decimal($m['amountCents']), 'credit' => '0.00', 'description' => 'حصة من مصاريف الإدارة العامة'];
            }
            foreach ($byAccount as $accountId => $cents) {
                $lines[] = ['accountId' => $accountId, 'branchId' => null, 'debit' => '0.00', 'credit' => Money::decimal($cents), 'description' => 'تحميل مصاريف الإدارة العامة على الفروع'];
            }
            $journalId = $this->posting->post($request, $tenantId, [
                'sourceType' => 'overhead_allocation', 'sourceId' => $id, 'sourceEvent' => 'POSTED', 'branchId' => null, 'entryDate' => $data['periodTo'],
                'description' => 'توزيع مصاريف الإدارة العامة '.$data['periodFrom'].' — '.$data['periodTo'], 'lines' => $lines, 'autoBalanceBranches' => true,
            ], $actorId);
            DB::table('overhead_allocations')->where('id', $id)->update(['journal_entry_id' => $journalId]);
            $this->audit->record($request, $tenantId, 'overhead_allocation.posted', 'overhead_allocation', $id, [], ['total' => $preview['total']], null, $actorId);

            return $id;
        });
    }

    public function reverse(Request $request, int $tenantId, int $id, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $id, $actorId): void {
            $row = DB::table('overhead_allocations')->where('tenant_id', $tenantId)->where('id', $id)->lockForUpdate()->first();
            abort_unless($row, 404, 'التوزيع غير موجود.');
            if ($row->status !== 'posted') {
                throw ValidationException::withMessages(['allocation' => 'التوزيع معكوس مسبقًا.']);
            }
            $reversal = $row->journal_entry_id ? $this->entries->reverse($request, $tenantId, (int) $row->journal_entry_id, $actorId, true, $row->period_to) : null;
            DB::table('overhead_allocations')->where('id', $id)->update(['status' => 'reversed', 'reversal_journal_entry_id' => $reversal, 'reversed_by' => $actorId, 'reversed_at' => now(), 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'overhead_allocation.reversed', 'overhead_allocation', $id, [], [], null, $actorId);
        });
    }

    public function list(int $tenantId): array
    {
        return DB::table('overhead_allocations')->where('tenant_id', $tenantId)->orderByDesc('period_to')->orderByDesc('id')->get()
            ->map(fn ($a) => $this->view($a))->values()->all();
    }

    public function show(int $tenantId, int $id): array
    {
        $a = DB::table('overhead_allocations')->where('tenant_id', $tenantId)->where('id', $id)->first();
        abort_unless($a, 404, 'التوزيع غير موجود.');
        $branches = DB::table('overhead_allocation_branches as l')->join('branches as b', 'b.id', '=', 'l.branch_id')->where('l.overhead_allocation_id', $id)->orderBy('l.id')
            ->get(['l.*', 'b.name'])->map(fn ($l) => ['branchId' => (int) $l->branch_id, 'branchName' => $l->name, 'percent' => rtrim(rtrim((string) $l->share_percent, '0'), '.'), 'amount' => $l->amount])->all();
        $accounts = DB::table('overhead_allocation_accounts as l')->join('financial_accounts as f', 'f.id', '=', 'l.financial_account_id')->where('l.overhead_allocation_id', $id)->orderBy('f.code')
            ->get(['l.*', 'f.code', 'f.name_en'])->map(fn ($l) => ['accountId' => (int) $l->financial_account_id, 'code' => $l->code, 'name' => $l->name_en, 'amount' => $l->amount])->all();

        return $this->view($a) + ['branches' => $branches, 'accounts' => $accounts];
    }

    /** @return array<int, array{accountId:int, code:string, name:string, amountCents:int}> head-office net expense per account */
    private function headOfficeExpenses(int $tenantId, string $from, string $to, array $accountIds): array
    {
        $rows = DB::table('journal_entry_lines as lines')
            ->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->join('financial_accounts as f', 'f.id', '=', 'lines.financial_account_id')
            ->where('lines.tenant_id', $tenantId)->where('entries.tenant_id', $tenantId)->where('entries.status', 'posted')
            ->whereNull('lines.branch_id')
            ->whereDate('entries.entry_date', '>=', $from)->whereDate('entries.entry_date', '<=', $to)
            ->whereIn('f.account_group', ['expenses', 'expense'])
            ->when($accountIds !== [], fn ($q) => $q->whereIn('lines.financial_account_id', array_map('intval', $accountIds)))
            ->groupBy('f.id', 'f.code', 'f.name_en')->orderBy('f.code')
            ->selectRaw('f.id, f.code, f.name_en, COALESCE(SUM(lines.debit),0) debit, COALESCE(SUM(lines.credit),0) credit')->get();
        $out = [];
        foreach ($rows as $r) {
            $net = Money::cents($r->debit) - Money::cents($r->credit);
            if ($net > 0) {
                $out[] = ['accountId' => (int) $r->id, 'code' => $r->code, 'name' => $r->name_en, 'amountCents' => $net];
            }
        }

        return $out;
    }

    private function view(object $a): array
    {
        return ['id' => (int) $a->id, 'number' => $a->allocation_number, 'periodFrom' => $a->period_from, 'periodTo' => $a->period_to, 'basis' => $a->basis,
            'total' => $a->total_amount, 'status' => $a->status, 'journalEntryId' => $a->journal_entry_id ? (int) $a->journal_entry_id : null,
            'notes' => $a->notes, 'createdAt' => (string) $a->created_at];
    }
}
