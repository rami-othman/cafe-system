<?php

namespace App\Services\Partners;

use App\Services\AccountingPostingService;
use App\Services\FinancialReportQueryService;
use App\Services\FixedAssets\DocumentNumber;
use App\Services\JournalEntryService;
use App\Services\OperationalAuditService;
use App\Services\SystemAccounts;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Allocates a branch's net profit (or loss) for a period to its partners:
 *   net profit (branch P&L, line-level branch) − carried loss (optional) − management fee
 *   → split by the ownership shares effective over the whole period.
 * Journal: Dr توزيعات أرباح الفروع (equity) / Cr each partner's current account
 * (reversed signs for a loss). The fee goes to the fee partner's current account (default: company).
 */
final class ProfitDistributionService
{
    public function __construct(
        private readonly PartnerService $partners,
        private readonly FinancialReportQueryService $reports,
        private readonly SystemAccounts $system,
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
    ) {}

    public function preview(int $tenantId, int $actorId, int $branchId, string $from, string $to): array
    {
        if ($from > $to) {
            throw ValidationException::withMessages(['dateTo' => 'نهاية الفترة قبل بدايتها.']);
        }
        $overlap = DB::table('profit_distributions')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('status', 'posted')
            ->where('period_from', '<=', $to)->where('period_to', '>=', $from)->first();
        $startShares = $this->partners->sharesAt($tenantId, $branchId, $from);
        $endShares = $this->partners->sharesAt($tenantId, $branchId, $to);
        $changed = DB::table('branch_ownerships')->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('effective_from', '>', $from)->where('effective_from', '<=', $to)->min('effective_from');
        $ownership = $this->partners->ownership($tenantId, $branchId);
        $settings = $ownership['settings'];

        $ctx = $this->reports->context($tenantId, $actorId, ['branchId' => $branchId, 'dateFrom' => $from, 'dateTo' => $to, 'comparison' => 'none']);
        $pnl = $this->reports->profitAndLoss($ctx);
        $revenue = Money::cents($pnl['totals']['revenue']);
        $profit = Money::cents($pnl['totals']['netOperatingProfit']);

        $carried = 0;
        if ($settings['carryForwardLosses'] && $profit > 0) {
            $carried = $this->openLoss($tenantId, $branchId, $from);
            $carried = min($carried, $profit);
        }
        $fee = 0;
        $feePercent = (float) $settings['managementFeePercent'];
        if ($settings['managementFeeType'] === 'revenue_percent') {
            $fee = (int) round($revenue * $feePercent / 100);
        } elseif ($settings['managementFeeType'] === 'profit_percent' && $profit - $carried > 0) {
            $fee = (int) round(($profit - $carried) * $feePercent / 100);
        }
        $distributable = $settings['carryForwardLosses'] && $profit < 0 ? 0 : $profit - $carried - $fee;

        $shares = $endShares !== [] ? $endShares : [['partnerId' => $this->partners->ensureCompanyPartner($tenantId), 'partnerName' => DB::table('partners')->where('tenant_id', $tenantId)->where('kind', 'company')->value('name'), 'kind' => 'company', 'sharePercent' => '100']];
        $lines = [];
        $allocated = 0;
        foreach ($shares as $i => $share) {
            $amount = $i === count($shares) - 1 ? $distributable - $allocated : (int) round($distributable * ((float) $share['sharePercent']) / 100);
            $allocated += $amount;
            $lines[] = ['partnerId' => $share['partnerId'], 'partnerName' => $share['partnerName'], 'kind' => 'share', 'sharePercent' => $share['sharePercent'], 'amountCents' => $amount];
        }
        if ($fee !== 0) {
            $feePartner = $this->partners->find($tenantId, (int) $settings['managementFeePartnerId']);
            array_unshift($lines, ['partnerId' => (int) $feePartner->id, 'partnerName' => $feePartner->name, 'kind' => 'management_fee', 'sharePercent' => $settings['managementFeePercent'], 'amountCents' => $fee]);
        }

        $warnings = [];
        if ($overlap) {
            $warnings[] = "يوجد توزيع ({$overlap->distribution_number}) يغطي جزءًا من هذه الفترة.";
        }
        if ($changed) {
            $warnings[] = "تغيّرت نسب الملكية بتاريخ {$changed} داخل الفترة؛ قسّم التوزيع عند هذا التاريخ.";
        }
        if ($startShares === [] && $endShares === []) {
            $warnings[] = 'لا توجد نسب ملكية لهذا الفرع؛ يُعتبر ملك الشركة 100%.';
        }
        if ($settings['carryForwardLosses'] && $profit < 0) {
            $warnings[] = 'الفرع خاسر والخسارة تُرحَّل للفترات القادمة (لا توزيع).';
        }

        return [
            'branchId' => $branchId, 'branchName' => $ownership['branchName'], 'periodFrom' => $from, 'periodTo' => $to,
            'revenue' => Money::decimal($revenue), 'netProfit' => Money::decimal($profit), 'carriedLoss' => Money::decimal($carried),
            'managementFee' => Money::decimal($fee), 'managementFeeType' => $settings['managementFeeType'], 'distributable' => Money::decimal($distributable),
            'lines' => array_map(fn ($l) => array_diff_key($l, ['amountCents' => 1]) + ['amount' => Money::decimal($l['amountCents'])], $lines),
            'linesCents' => $lines,
            'blocking' => $overlap !== null || $changed !== null,
            'warnings' => $warnings,
            'pnl' => $pnl['totals'],
        ];
    }

    public function post(Request $request, int $tenantId, int $actorId, int $branchId, array $data): int
    {
        return DB::transaction(function () use ($request, $tenantId, $actorId, $branchId, $data): int {
            DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->lockForUpdate()->first();
            $preview = $this->preview($tenantId, $actorId, $branchId, $data['periodFrom'], $data['periodTo']);
            if ($preview['blocking']) {
                throw ValidationException::withMessages(['period' => implode(' ', $preview['warnings'])]);
            }
            $now = now();
            $id = (int) DB::table('profit_distributions')->insertGetId([
                'tenant_id' => $tenantId, 'branch_id' => $branchId,
                'distribution_number' => DocumentNumber::next($tenantId, 'profit_distributions', 'distribution_number', 'PD-'),
                'period_from' => $data['periodFrom'], 'period_to' => $data['periodTo'],
                'revenue' => $preview['revenue'], 'net_profit' => $preview['netProfit'], 'carried_loss' => $preview['carriedLoss'],
                'management_fee' => $preview['managementFee'], 'distributable' => $preview['distributable'], 'status' => 'posted',
                'notes' => $data['notes'] ?? null, 'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $journalLines = [];
            $totalToPartners = 0;
            foreach ($preview['linesCents'] as $line) {
                DB::table('profit_distribution_lines')->insert(['tenant_id' => $tenantId, 'profit_distribution_id' => $id, 'partner_id' => $line['partnerId'],
                    'kind' => $line['kind'], 'share_percent' => $line['sharePercent'], 'amount' => Money::decimal($line['amountCents']), 'created_at' => $now, 'updated_at' => $now]);
                if ($line['amountCents'] === 0) {
                    continue;
                }
                $partner = $this->partners->find($tenantId, $line['partnerId']);
                $cents = $line['amountCents'];
                $totalToPartners += $cents;
                $journalLines[] = ['accountId' => (int) $partner->current_account_id, 'branchId' => $branchId,
                    'debit' => $cents < 0 ? Money::decimal(-$cents) : '0.00', 'credit' => $cents > 0 ? Money::decimal($cents) : '0.00',
                    'description' => ($line['kind'] === 'management_fee' ? 'أتعاب إدارة' : 'حصة أرباح '.$line['sharePercent'].'%').' — '.$partner->name];
            }
            $journalId = null;
            if ($totalToPartners !== 0) {
                $distribution = $this->system->id($tenantId, 'partners.distribution');
                array_unshift($journalLines, ['accountId' => $distribution, 'branchId' => $branchId,
                    'debit' => $totalToPartners > 0 ? Money::decimal($totalToPartners) : '0.00', 'credit' => $totalToPartners < 0 ? Money::decimal(-$totalToPartners) : '0.00',
                    'description' => 'توزيع نتيجة الفرع '.$data['periodFrom'].' → '.$data['periodTo']]);
                $journalId = $this->posting->post($request, $tenantId, [
                    'sourceType' => 'profit_distribution', 'sourceId' => $id, 'sourceEvent' => 'POSTED', 'branchId' => $branchId, 'entryDate' => $data['periodTo'],
                    'description' => 'توزيع أرباح '.$preview['branchName'].' للفترة '.$data['periodFrom'].' — '.$data['periodTo'], 'lines' => $journalLines,
                ], $actorId);
            }
            DB::table('profit_distributions')->where('id', $id)->update(['journal_entry_id' => $journalId]);
            $this->audit->record($request, $tenantId, 'profit_distribution.posted', 'profit_distribution', $id, [], ['net' => $preview['netProfit'], 'fee' => $preview['managementFee']], $branchId, $actorId);

            return $id;
        });
    }

    public function reverse(Request $request, int $tenantId, int $id, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $id, $actorId): void {
            $row = DB::table('profit_distributions')->where('tenant_id', $tenantId)->where('id', $id)->lockForUpdate()->first();
            abort_unless($row, 404, 'التوزيع غير موجود.');
            if ($row->status !== 'posted') {
                throw ValidationException::withMessages(['distribution' => 'التوزيع معكوس مسبقًا.']);
            }
            $later = DB::table('profit_distributions')->where('tenant_id', $tenantId)->where('branch_id', $row->branch_id)->where('status', 'posted')->where('period_to', '>', $row->period_to)->exists();
            if ($later) {
                throw ValidationException::withMessages(['distribution' => 'يوجد توزيع أحدث لهذا الفرع؛ اعكسه أولًا.']);
            }
            $reversal = $row->journal_entry_id ? $this->entries->reverse($request, $tenantId, (int) $row->journal_entry_id, $actorId, true, $row->period_to) : null;
            DB::table('profit_distributions')->where('id', $id)->update(['status' => 'reversed', 'reversal_journal_entry_id' => $reversal, 'reversed_by' => $actorId, 'reversed_at' => now(), 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'profit_distribution.reversed', 'profit_distribution', $id, [], [], (int) $row->branch_id, $actorId);
        });
    }

    public function list(int $tenantId, ?int $branchId = null): array
    {
        return DB::table('profit_distributions as d')->join('branches as b', 'b.id', '=', 'd.branch_id')->where('d.tenant_id', $tenantId)
            ->when($branchId, fn ($q) => $q->where('d.branch_id', $branchId))->orderByDesc('d.period_to')->orderByDesc('d.id')->get(['d.*', 'b.name as branch_name'])
            ->map(fn ($d) => $this->view($d))->values()->all();
    }

    public function show(int $tenantId, int $id): array
    {
        $d = DB::table('profit_distributions as d')->join('branches as b', 'b.id', '=', 'd.branch_id')->where('d.tenant_id', $tenantId)->where('d.id', $id)->first(['d.*', 'b.name as branch_name']);
        abort_unless($d, 404, 'التوزيع غير موجود.');
        $lines = DB::table('profit_distribution_lines as l')->join('partners as p', 'p.id', '=', 'l.partner_id')->where('l.profit_distribution_id', $id)->orderBy('l.id')
            ->get(['l.*', 'p.name'])->map(fn ($l) => ['partnerId' => (int) $l->partner_id, 'partnerName' => $l->name, 'kind' => $l->kind,
                'sharePercent' => rtrim(rtrim((string) $l->share_percent, '0'), '.'), 'amount' => Money::decimal(Money::cents((string) $l->amount))])->values()->all();

        return $this->view($d) + ['lines' => $lines];
    }

    /** Branch summary for a period: P&L figures + current owners, for every branch. */
    public function branchesOverview(int $tenantId, int $actorId, string $from, string $to): array
    {
        $out = [];
        foreach (DB::table('branches')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('name')->get(['id', 'name']) as $branch) {
            $ctx = $this->reports->context($tenantId, $actorId, ['branchId' => (int) $branch->id, 'dateFrom' => $from, 'dateTo' => $to, 'comparison' => 'none']);
            $totals = $this->reports->profitAndLoss($ctx)['totals'];
            $out[] = ['branchId' => (int) $branch->id, 'branchName' => $branch->name, 'revenue' => $totals['revenue'], 'costOfSales' => $totals['costOfSales'],
                'operatingExpenses' => $totals['operatingExpenses'], 'netProfit' => $totals['netOperatingProfit'],
                'owners' => $this->partners->sharesAt($tenantId, (int) $branch->id, $to),
                'lastDistributionTo' => DB::table('profit_distributions')->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('status', 'posted')->max('period_to')];
        }

        return $out;
    }

    /** Losses distributed as zero (carry-forward) not yet absorbed by later profits. */
    private function openLoss(int $tenantId, int $branchId, string $before): int
    {
        $rows = DB::table('profit_distributions')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('status', 'posted')->where('period_to', '<', $before)->orderBy('period_to')->get();
        $open = 0;
        foreach ($rows as $row) {
            $net = Money::cents((string) $row->net_profit);
            if ($net < 0 && Money::cents((string) $row->distributable) === 0) {
                $open += -$net;
            } else {
                $open = max(0, $open - Money::cents((string) $row->carried_loss));
            }
        }

        return $open;
    }

    private function view(object $d): array
    {
        return ['id' => (int) $d->id, 'number' => $d->distribution_number, 'branchId' => (int) $d->branch_id, 'branchName' => $d->branch_name,
            'periodFrom' => $d->period_from, 'periodTo' => $d->period_to, 'revenue' => Money::decimal(Money::cents((string) $d->revenue)),
            'netProfit' => Money::decimal(Money::cents((string) $d->net_profit)), 'carriedLoss' => Money::decimal(Money::cents((string) $d->carried_loss)),
            'managementFee' => Money::decimal(Money::cents((string) $d->management_fee)), 'distributable' => Money::decimal(Money::cents((string) $d->distributable)),
            'status' => $d->status, 'journalEntryId' => $d->journal_entry_id ? (int) $d->journal_entry_id : null, 'notes' => $d->notes, 'createdAt' => (string) $d->created_at];
    }
}
