<?php

namespace App\Services\Partners;

use App\Services\AccountingPostingService;
use App\Services\JournalEntryService;
use App\Services\OperationalAuditService;
use App\Services\SystemAccounts;
use App\Support\BranchScope;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Partners (the company itself + investors), their three ledger accounts (capital, current,
 * drawings), effective-dated branch ownership, money movements and the partner statement.
 */
final class PartnerService
{
    public const TYPES = [
        'capital_in' => 'إيداع رأس مال', 'capital_out' => 'سحب من رأس المال',
        'withdrawal' => 'مسحوبات شخصية', 'payout' => 'صرف أرباح (من الحساب الجاري)', 'deposit' => 'إيداع في الحساب الجاري',
    ];

    public function __construct(
        private readonly SystemAccounts $system,
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
    ) {}

    // ------------------------------------------------------------ partners

    public function list(int $tenantId): array
    {
        $this->ensureCompanyPartner($tenantId);
        $partners = DB::table('partners')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderByRaw("CASE WHEN kind='company' THEN 0 ELSE 1 END")->orderBy('name')->get();
        $balances = $this->balances($tenantId, $partners->flatMap(fn ($p) => array_filter([$p->capital_account_id, $p->current_account_id, $p->drawings_account_id]))->all());
        $today = now()->toDateString();
        $shares = DB::table('branch_ownerships as o')->join('branches as b', 'b.id', '=', 'o.branch_id')->where('o.tenant_id', $tenantId)
            ->where('o.effective_from', '<=', $today)->where(fn ($q) => $q->whereNull('o.effective_to')->orWhere('o.effective_to', '>=', $today))
            ->get(['o.partner_id', 'o.branch_id', 'b.name', 'o.share_percent'])->groupBy('partner_id');

        return $partners->map(fn ($p) => $this->view($p, $balances) + [
            'branches' => ($shares[$p->id] ?? collect())->map(fn ($s) => ['branchId' => (int) $s->branch_id, 'branchName' => $s->name, 'sharePercent' => $this->pct($s->share_percent)])->values()->all(),
        ])->values()->all();
    }

    public function find(int $tenantId, int $partnerId): object
    {
        $partner = DB::table('partners')->where('tenant_id', $tenantId)->where('id', $partnerId)->whereNull('deleted_at')->first();
        abort_unless($partner, 404, 'الشريك غير موجود.');

        return $partner;
    }

    public function save(Request $request, int $tenantId, array $data, ?int $id, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $data, $id, $actorId): int {
            $name = trim((string) $data['name']);
            if ($name === '') {
                throw ValidationException::withMessages(['name' => 'اسم الشريك مطلوب.']);
            }
            $now = now();
            if ($id) {
                $partner = $this->find($tenantId, $id);
                $userId = array_key_exists('userId', $data) ? $this->assertLinkableUser($tenantId, $data['userId'] ? (int) $data['userId'] : null, $id) : $partner->user_id;
                DB::table('partners')->where('id', $id)->update(['name' => $name, 'phone' => $data['phone'] ?? $partner->phone, 'notes' => $data['notes'] ?? $partner->notes,
                    'is_active' => (bool) ($data['isActive'] ?? $partner->is_active), 'user_id' => $userId, 'updated_at' => $now]);

                return $id;
            }
            $kind = ($data['kind'] ?? 'investor') === 'company' ? 'company' : 'investor';
            if ($kind === 'company' && DB::table('partners')->where('tenant_id', $tenantId)->where('kind', 'company')->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(['kind' => 'الشركة مسجّلة كشريك مسبقًا.']);
            }
            $capital = ! empty($data['capitalAccountId']) ? $this->adoptAccount($tenantId, (int) $data['capitalAccountId'], 'equity', 'capitalAccountId')
                : $this->system->createChild($tenantId, $this->system->id($tenantId, 'partners.capital_parent'), 'رأس مال '.$name);
            $current = ! empty($data['currentAccountId']) ? $this->adoptAccount($tenantId, (int) $data['currentAccountId'], 'liabilities', 'currentAccountId')
                : $this->system->createChild($tenantId, $this->system->id($tenantId, 'partners.current_parent'), 'جاري '.$name);
            $drawings = ! empty($data['drawingsAccountId']) ? $this->adoptAccount($tenantId, (int) $data['drawingsAccountId'], null, 'drawingsAccountId')
                : $this->system->createChild($tenantId, $this->system->id($tenantId, 'partners.drawings_parent'), 'مسحوبات '.$name);
            $id = (int) DB::table('partners')->insertGetId([
                'tenant_id' => $tenantId, 'name' => $name, 'kind' => $kind, 'user_id' => $this->assertLinkableUser($tenantId, ! empty($data['userId']) ? (int) $data['userId'] : null, null), 'phone' => $data['phone'] ?? null, 'notes' => $data['notes'] ?? null,
                'capital_account_id' => $capital, 'current_account_id' => $current, 'drawings_account_id' => $drawings,
                'is_active' => true, 'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $this->audit->record($request, $tenantId, 'partner.created', 'partner', $id, [], ['name' => $name, 'kind' => $kind], null, $actorId);

            return $id;
        });
    }

    /** The company itself as a partner (named after the tenant), created on first use. */
    public function ensureCompanyPartner(int $tenantId): int
    {
        $existing = DB::table('partners')->where('tenant_id', $tenantId)->where('kind', 'company')->whereNull('deleted_at')->value('id');
        if ($existing) {
            return (int) $existing;
        }
        $name = (string) (DB::table('tenants')->where('id', $tenantId)->value('name') ?: 'الشركة');

        return $this->save(request(), $tenantId, ['name' => $name, 'kind' => 'company'], null, null);
    }

    // ------------------------------------------------------------ ownership

    public function ownership(int $tenantId, int $branchId): array
    {
        $this->assertBranch($tenantId, $branchId);
        $this->ensureCompanyPartner($tenantId);
        $rows = DB::table('branch_ownerships as o')->join('partners as p', 'p.id', '=', 'o.partner_id')->where('o.tenant_id', $tenantId)->where('o.branch_id', $branchId)
            ->orderByDesc('o.effective_from')->orderBy('p.name')->get(['o.*', 'p.name', 'p.kind']);
        $periods = $rows->groupBy('effective_from')->map(fn ($group, $from) => [
            'effectiveFrom' => $from, 'effectiveTo' => $group->first()->effective_to,
            'shares' => $group->map(fn ($r) => ['partnerId' => (int) $r->partner_id, 'partnerName' => $r->name, 'kind' => $r->kind, 'sharePercent' => $this->pct($r->share_percent)])->values()->all(),
        ])->values()->all();
        $settings = DB::table('branch_profit_settings')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->first();
        $companyId = $this->ensureCompanyPartner($tenantId);

        return [
            'branchId' => $branchId,
            'branchName' => DB::table('branches')->where('id', $branchId)->value('name'),
            'current' => $this->sharesAt($tenantId, $branchId, now()->toDateString()),
            'history' => $periods,
            'settings' => [
                'managementFeeType' => $settings->management_fee_type ?? 'none',
                'managementFeePercent' => $this->pct($settings->management_fee_percent ?? 0),
                'managementFeePartnerId' => (int) ($settings->management_fee_partner_id ?? $companyId),
                'carryForwardLosses' => (bool) ($settings->carry_forward_losses ?? false),
            ],
            'lastDistributionTo' => DB::table('profit_distributions')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('status', 'posted')->max('period_to'),
        ];
    }

    /** @return array<int, array{partnerId:int, partnerName:string, kind:string, sharePercent:string}> (empty = 100% company) */
    public function sharesAt(int $tenantId, int $branchId, string $date): array
    {
        return DB::table('branch_ownerships as o')->join('partners as p', 'p.id', '=', 'o.partner_id')->where('o.tenant_id', $tenantId)->where('o.branch_id', $branchId)
            ->where('o.effective_from', '<=', $date)->where(fn ($q) => $q->whereNull('o.effective_to')->orWhere('o.effective_to', '>=', $date))
            ->orderByDesc('o.share_percent')->get(['o.partner_id', 'p.name', 'p.kind', 'o.share_percent'])
            ->map(fn ($r) => ['partnerId' => (int) $r->partner_id, 'partnerName' => $r->name, 'kind' => $r->kind, 'sharePercent' => $this->pct($r->share_percent)])->values()->all();
    }

    public function setOwnership(Request $request, int $tenantId, int $branchId, array $data, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $branchId, $data, $actorId): void {
            $this->assertBranch($tenantId, $branchId);
            DB::table('branches')->where('id', $branchId)->lockForUpdate()->first();
            $from = $data['effectiveFrom'];
            $shares = [];
            $total = 0;
            foreach ($data['shares'] as $i => $share) {
                $partner = (int) $share['partnerId'];
                $this->find($tenantId, $partner);
                if (isset($shares[$partner])) {
                    throw ValidationException::withMessages(["shares.$i.partnerId" => 'الشريك مكرر.']);
                }
                $units = (int) round(((float) $share['sharePercent']) * 10000);
                if ($units <= 0) {
                    throw ValidationException::withMessages(["shares.$i.sharePercent" => 'النسبة يجب أن تكون أكبر من صفر.']);
                }
                $shares[$partner] = $units;
                $total += $units;
            }
            if ($total !== 1000000) {
                throw ValidationException::withMessages(['shares' => 'مجموع النسب يجب أن يساوي 100% (الحالي '.rtrim(rtrim(number_format($total / 10000, 4, '.', ''), '0'), '.').'%).']);
            }
            $lastDistribution = DB::table('profit_distributions')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('status', 'posted')->max('period_to');
            if ($lastDistribution && $from <= $lastDistribution) {
                throw ValidationException::withMessages(['effectiveFrom' => "يوجد توزيع أرباح حتى {$lastDistribution}؛ تاريخ النسب الجديدة يجب أن يكون بعده."]);
            }
            $later = DB::table('branch_ownerships')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('effective_from', '>', $from)->exists();
            if ($later) {
                throw ValidationException::withMessages(['effectiveFrom' => 'توجد نسب بتاريخ لاحق؛ عدّل الأحدث أو اختر تاريخًا بعده.']);
            }
            DB::table('branch_ownerships')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('effective_from', $from)->delete();
            DB::table('branch_ownerships')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('effective_from', '<', $from)
                ->where(fn ($q) => $q->whereNull('effective_to')->orWhere('effective_to', '>=', $from))
                ->update(['effective_to' => CarbonImmutable::parse($from)->subDay()->toDateString(), 'updated_at' => now()]);
            $now = now();
            foreach ($shares as $partner => $units) {
                DB::table('branch_ownerships')->insert(['tenant_id' => $tenantId, 'branch_id' => $branchId, 'partner_id' => $partner,
                    'share_percent' => number_format($units / 10000, 4, '.', ''), 'effective_from' => $from, 'effective_to' => null,
                    'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now]);
            }
            if (isset($data['settings'])) {
                $this->saveSettings($tenantId, $branchId, $data['settings']);
            }
            $this->audit->record($request, $tenantId, 'branch_ownership.set', 'branch', $branchId, [], ['effectiveFrom' => $from, 'shares' => $shares], $branchId, $actorId);
        });
    }

    public function saveSettings(int $tenantId, int $branchId, array $settings): void
    {
        $type = $settings['managementFeeType'] ?? 'none';
        if (! in_array($type, ['none', 'revenue_percent', 'profit_percent'], true)) {
            throw ValidationException::withMessages(['settings.managementFeeType' => 'نوع أتعاب الإدارة غير مدعوم.']);
        }
        $percent = (float) ($settings['managementFeePercent'] ?? 0);
        if ($percent < 0 || $percent > 100 || ($type !== 'none' && $percent <= 0)) {
            throw ValidationException::withMessages(['settings.managementFeePercent' => 'نسبة أتعاب الإدارة بين 0 و100.']);
        }
        $feePartner = ! empty($settings['managementFeePartnerId']) ? (int) $settings['managementFeePartnerId'] : $this->ensureCompanyPartner($tenantId);
        $this->find($tenantId, $feePartner);
        DB::table('branch_profit_settings')->updateOrInsert(['branch_id' => $branchId], [
            'tenant_id' => $tenantId, 'management_fee_type' => $type, 'management_fee_percent' => $type === 'none' ? 0 : $percent,
            'management_fee_partner_id' => $feePartner, 'carry_forward_losses' => (bool) ($settings['carryForwardLosses'] ?? false),
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    // ------------------------------------------------------------ money movements

    public function transaction(Request $request, int $tenantId, int $partnerId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $partnerId, $data, $actorId): int {
            $partner = $this->find($tenantId, $partnerId);
            $type = $data['type'];
            $amount = Money::cents((string) $data['amount'], 'amount');
            if ($amount <= 0) {
                throw ValidationException::withMessages(['amount' => 'المبلغ يجب أن يكون أكبر من صفر.']);
            }
            $counter = (int) $data['counterAccountId'];
            if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $counter)->where('is_active', true)->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(['counterAccountId' => 'الحساب المقابل غير متاح.']);
            }
            $branch = ! empty($data['branchId']) ? (int) $data['branchId'] : null;
            if ($branch) {
                $this->assertBranch($tenantId, $branch);
            }
            $partnerAccount = match ($type) {
                'capital_in', 'capital_out' => (int) $partner->capital_account_id,
                'withdrawal' => (int) $partner->drawings_account_id,
                'payout', 'deposit' => (int) $partner->current_account_id,
                default => throw ValidationException::withMessages(['type' => 'نوع العملية غير معروف.']),
            };
            $partnerDebit = in_array($type, ['capital_out', 'withdrawal', 'payout'], true);
            $now = now();
            $id = (int) DB::table('partner_transactions')->insertGetId([
                'tenant_id' => $tenantId, 'partner_id' => $partnerId, 'branch_id' => $branch, 'type' => $type, 'transaction_date' => $data['date'],
                'amount' => Money::decimal($amount), 'counter_account_id' => $counter, 'description' => $data['description'] ?? null,
                'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $label = self::TYPES[$type].' — '.$partner->name;
            $journal = $this->posting->post($request, $tenantId, [
                'sourceType' => 'partner_transaction', 'sourceId' => $id, 'sourceEvent' => 'POSTED', 'branchId' => $branch, 'entryDate' => $data['date'],
                'description' => $label.(! empty($data['description']) ? ' — '.$data['description'] : ''),
                'lines' => [
                    ['accountId' => $partnerAccount, 'branchId' => $branch, 'debit' => $partnerDebit ? Money::decimal($amount) : '0.00', 'credit' => $partnerDebit ? '0.00' : Money::decimal($amount)],
                    ['accountId' => $counter, 'branchId' => $branch, 'debit' => $partnerDebit ? '0.00' : Money::decimal($amount), 'credit' => $partnerDebit ? Money::decimal($amount) : '0.00'],
                ],
            ], $actorId);
            DB::table('partner_transactions')->where('id', $id)->update(['journal_entry_id' => $journal]);
            $this->audit->record($request, $tenantId, 'partner.transaction', 'partner', $partnerId, [], ['type' => $type, 'amount' => Money::decimal($amount)], $branch, $actorId);

            return $id;
        });
    }

    public function reverseTransaction(Request $request, int $tenantId, int $transactionId, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $transactionId, $actorId): void {
            $tx = DB::table('partner_transactions')->where('tenant_id', $tenantId)->where('id', $transactionId)->lockForUpdate()->first();
            abort_unless($tx, 404, 'العملية غير موجودة.');
            if ($tx->reversed_at) {
                throw ValidationException::withMessages(['transaction' => 'العملية معكوسة مسبقًا.']);
            }
            $reversal = $tx->journal_entry_id ? $this->entries->reverse($request, $tenantId, (int) $tx->journal_entry_id, $actorId, true) : null;
            DB::table('partner_transactions')->where('id', $transactionId)->update(['reversed_at' => now(), 'reversal_journal_entry_id' => $reversal, 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'partner.transaction_reversed', 'partner', (int) $tx->partner_id, [], ['transactionId' => $transactionId], $tx->branch_id, $actorId);
        });
    }

    public function transactions(int $tenantId, ?int $partnerId = null): array
    {
        $branches = DB::table('branches')->where('tenant_id', $tenantId)->pluck('name', 'id');

        return DB::table('partner_transactions as t')->join('partners as p', 'p.id', '=', 't.partner_id')->leftJoin('financial_accounts as a', 'a.id', '=', 't.counter_account_id')
            ->where('t.tenant_id', $tenantId)->when($partnerId, fn ($q) => $q->where('t.partner_id', $partnerId))
            ->orderByDesc('t.transaction_date')->orderByDesc('t.id')->limit(500)->get(['t.*', 'p.name as partner_name', 'a.code as account_code', 'a.name_ar as account_name'])
            ->map(fn ($t) => ['id' => (int) $t->id, 'partnerId' => (int) $t->partner_id, 'partnerName' => $t->partner_name, 'type' => $t->type, 'typeLabel' => self::TYPES[$t->type] ?? $t->type,
                'date' => $t->transaction_date, 'amount' => Money::decimal(Money::cents((string) $t->amount)), 'branchId' => $t->branch_id ? (int) $t->branch_id : null,
                'branchName' => $t->branch_id ? ($branches[$t->branch_id] ?? null) : 'الإدارة العامة', 'counterAccount' => $t->account_code ? $t->account_code.' - '.$t->account_name : null,
                'description' => $t->description, 'reversed' => $t->reversed_at !== null, 'journalEntryId' => $t->journal_entry_id ? (int) $t->journal_entry_id : null])->values()->all();
    }

    // ------------------------------------------------------------ investor portal

    /** Active users of the tenant that can be linked to an investor. */
    public function linkableUsers(int $tenantId): array
    {
        $linked = DB::table('partners')->where('tenant_id', $tenantId)->whereNull('deleted_at')->whereNotNull('user_id')->pluck('name', 'user_id');

        return DB::table('users')->where('tenant_id', $tenantId)->where('is_active', true)->orderBy('name')->get(['id', 'name', 'email'])
            ->map(fn ($u) => ['id' => (int) $u->id, 'name' => $u->name, 'email' => $u->email, 'linkedPartner' => $linked[$u->id] ?? null])->values()->all();
    }

    /**
     * Read-only view of the partner(s) linked to this user: their own shares, balances, statement and
     * distributions. Nothing about other partners or the rest of the books is returned.
     */
    public function portal(int $tenantId, int $userId, string $from, string $to): array
    {
        $mine = collect($this->list($tenantId))->filter(fn ($p) => $p['userId'] === $userId && $p['isActive'])->values();
        abort_if($mine->isEmpty(), 404, 'لا يوجد حساب مستثمر مرتبط بمستخدمك.');

        return $mine->map(fn ($p) => [
            'partner' => $p,
            'statement' => $this->statement($tenantId, (int) $p['id'], ['dateFrom' => $from, 'dateTo' => $to]),
        ])->all();
    }

    private function assertLinkableUser(int $tenantId, ?int $userId, ?int $partnerId): ?int
    {
        if ($userId === null) {
            return null;
        }
        if (! DB::table('users')->where('tenant_id', $tenantId)->where('id', $userId)->where('is_active', true)->exists()) {
            throw ValidationException::withMessages(['userId' => 'المستخدم غير موجود.']);
        }
        $taken = DB::table('partners')->where('tenant_id', $tenantId)->where('user_id', $userId)->whereNull('deleted_at')->when($partnerId, fn ($q) => $q->where('id', '!=', $partnerId))->exists();
        if ($taken) {
            throw ValidationException::withMessages(['userId' => 'هذا المستخدم مرتبط بشريك آخر.']);
        }

        return $userId;
    }

    // ------------------------------------------------------------ statement

    /** Movements on the partner's three accounts, optionally for one branch ('company' = head office). */
    public function statement(int $tenantId, int $partnerId, array $filters): array
    {
        $partner = $this->find($tenantId, $partnerId);
        $accounts = array_filter(['capital' => $partner->capital_account_id, 'current' => $partner->current_account_id, 'drawings' => $partner->drawings_account_id]);
        $kindOf = array_flip(array_map('intval', $accounts));
        $branch = $filters['branchId'] ?? null;
        $base = fn () => $this->scopedLines($tenantId, array_values($accounts), $branch);
        $openingRows = $base()->where('entries.entry_date', '<', $filters['dateFrom'])->groupBy('lines.financial_account_id')
            ->selectRaw('lines.financial_account_id, SUM(lines.credit) - SUM(lines.debit) net')->pluck('net', 'financial_account_id');
        $opening = ['capital' => 0, 'current' => 0, 'drawings' => 0];
        foreach ($openingRows as $accountId => $net) {
            $opening[$kindOf[(int) $accountId]] += Money::cents((string) $net);
        }
        $branches = DB::table('branches')->where('tenant_id', $tenantId)->pluck('name', 'id');
        $running = array_sum($opening);
        $lines = $base()->whereBetween('entries.entry_date', [$filters['dateFrom'], $filters['dateTo']])
            ->orderBy('entries.entry_date')->orderBy('entries.id')->orderBy('lines.id')
            ->get(['lines.id', 'lines.financial_account_id', 'lines.debit', 'lines.credit', 'lines.description as line_description', 'entries.id as entry_id',
                'entries.entry_number', 'entries.entry_date', 'entries.source_type', 'entries.description', DB::raw('COALESCE(lines.branch_id, entries.branch_id) as eff_branch')])
            ->map(function ($l) use (&$running, $kindOf, $branches) {
                $net = Money::cents((string) $l->credit) - Money::cents((string) $l->debit);
                $running += $net;

                return ['date' => $l->entry_date, 'journalEntryId' => (int) $l->entry_id, 'journalNumber' => $l->entry_number, 'sourceType' => $l->source_type,
                    'account' => $kindOf[(int) $l->financial_account_id], 'description' => $l->line_description ?: $l->description,
                    'branchName' => $l->eff_branch ? ($branches[$l->eff_branch] ?? null) : 'الإدارة العامة',
                    'debit' => Money::decimal(Money::cents((string) $l->debit)), 'credit' => Money::decimal(Money::cents((string) $l->credit)), 'balance' => Money::decimal($running)];
            })->values()->all();
        $closing = $base()->where('entries.entry_date', '<=', $filters['dateTo'])->groupBy('lines.financial_account_id')
            ->selectRaw('lines.financial_account_id, SUM(lines.credit) - SUM(lines.debit) net')->pluck('net', 'financial_account_id');
        $closingByKind = ['capital' => 0, 'current' => 0, 'drawings' => 0];
        foreach ($closing as $accountId => $net) {
            $closingByKind[$kindOf[(int) $accountId]] += Money::cents((string) $net);
        }

        return [
            'partner' => $this->view($partner, []),
            'dateFrom' => $filters['dateFrom'], 'dateTo' => $filters['dateTo'], 'branchId' => $branch,
            'opening' => array_map(fn ($v) => Money::decimal($v), $opening) + ['total' => Money::decimal(array_sum($opening))],
            'lines' => $lines,
            'closing' => array_map(fn ($v) => Money::decimal($v), $closingByKind) + ['total' => Money::decimal(array_sum($closingByKind))],
            'distributions' => DB::table('profit_distribution_lines as l')->join('profit_distributions as d', 'd.id', '=', 'l.profit_distribution_id')
                ->join('branches as b', 'b.id', '=', 'd.branch_id')->where('l.tenant_id', $tenantId)->where('l.partner_id', $partnerId)->where('d.status', 'posted')
                ->when($branch && $branch !== 'company', fn ($q) => $q->where('d.branch_id', (int) $branch))
                ->orderByDesc('d.period_to')->get(['d.id', 'd.distribution_number', 'd.period_from', 'd.period_to', 'b.name', 'l.kind', 'l.share_percent', 'l.amount'])
                ->map(fn ($r) => ['distributionId' => (int) $r->id, 'number' => $r->distribution_number, 'periodFrom' => $r->period_from, 'periodTo' => $r->period_to,
                    'branchName' => $r->name, 'kind' => $r->kind, 'sharePercent' => $this->pct($r->share_percent), 'amount' => Money::decimal(Money::cents((string) $r->amount))])->values()->all(),
        ];
    }

    // ------------------------------------------------------------ helpers

    private function scopedLines(int $tenantId, array $accountIds, mixed $branch)
    {
        $q = DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->where('lines.tenant_id', $tenantId)->where('entries.status', 'posted')->whereIn('lines.financial_account_id', $accountIds);
        if ($branch === 'company') {
            return $q->whereRaw('COALESCE(lines.branch_id, entries.branch_id) IS NULL');
        }
        if ($branch) {
            return BranchScope::applyJournalLines($q, (int) $branch, []);
        }

        return $q;
    }

    private function balances(int $tenantId, array $accountIds): array
    {
        if ($accountIds === []) {
            return [];
        }

        return DB::table('journal_entry_lines as lines')->join('journal_entries as entries', 'entries.id', '=', 'lines.journal_entry_id')
            ->where('lines.tenant_id', $tenantId)->where('entries.status', 'posted')->whereIn('lines.financial_account_id', $accountIds)
            ->groupBy('lines.financial_account_id')->selectRaw('lines.financial_account_id, SUM(lines.credit) - SUM(lines.debit) net')
            ->pluck('net', 'financial_account_id')->mapWithKeys(fn ($v, $k) => [(int) $k => Money::cents((string) $v)])->all();
    }

    private function view(object $p, array $balances): array
    {
        $codes = DB::table('financial_accounts')->whereIn('id', array_filter([$p->capital_account_id, $p->current_account_id, $p->drawings_account_id]))->pluck('code', 'id');
        $bal = fn ($id) => Money::decimal($balances[(int) $id] ?? 0);
        $capital = $balances[(int) $p->capital_account_id] ?? 0;
        $current = $balances[(int) $p->current_account_id] ?? 0;
        $drawings = $balances[(int) $p->drawings_account_id] ?? 0;

        return [
            'id' => (int) $p->id, 'userId' => $p->user_id ? (int) $p->user_id : null, 'name' => $p->name, 'kind' => $p->kind, 'phone' => $p->phone, 'notes' => $p->notes, 'isActive' => (bool) $p->is_active,
            'capitalAccount' => ['id' => (int) $p->capital_account_id, 'code' => $codes[$p->capital_account_id] ?? null, 'balance' => $bal($p->capital_account_id)],
            'currentAccount' => ['id' => (int) $p->current_account_id, 'code' => $codes[$p->current_account_id] ?? null, 'balance' => $bal($p->current_account_id)],
            'drawingsAccount' => ['id' => (int) $p->drawings_account_id, 'code' => $codes[$p->drawings_account_id] ?? null, 'balance' => $bal($p->drawings_account_id)],
            'netPosition' => Money::decimal($capital + $current + $drawings),
        ];
    }

    private function adoptAccount(int $tenantId, int $accountId, ?string $group, string $field): int
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->where('is_active', true)->whereNull('deleted_at')->first();
        if (! $account || ($group !== null && $account->account_group !== $group)) {
            throw ValidationException::withMessages([$field => 'الحساب غير مناسب.']);
        }
        if (DB::table('partners')->where('tenant_id', $tenantId)->whereNull('deleted_at')
            ->where(fn ($q) => $q->where('capital_account_id', $accountId)->orWhere('current_account_id', $accountId)->orWhere('drawings_account_id', $accountId))->exists()) {
            throw ValidationException::withMessages([$field => 'الحساب مرتبط بشريك آخر.']);
        }

        return $accountId;
    }

    private function assertBranch(int $tenantId, int $branchId): void
    {
        abort_unless(DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->exists(), 404, 'الفرع غير موجود.');
    }

    private function pct(mixed $value): string
    {
        return rtrim(rtrim(number_format((float) $value, 4, '.', ''), '0'), '.') ?: '0';
    }
}
