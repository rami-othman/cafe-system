<?php

namespace App\Services\FixedAssets;

use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/** Read models: asset list/register, the card with its ledger, schedule, operations report. */
final class AssetQueryService
{
    public const STATUS_LABELS = ['draft' => 'مسودة', 'active' => 'فعّال', 'fully_depreciated' => 'مهتلك بالكامل', 'disposed' => 'مستبعد'];

    public const TYPE_LABELS = ['opening' => 'رصيد افتتاحي', 'acquisition' => 'إدخال', 'addition' => 'إضافة', 'maintenance' => 'صيانة', 'expense' => 'مصروف', 'depreciation' => 'اهتلاك', 'disposal' => 'بيع/استبعاد', 'transfer' => 'نقل'];

    public function __construct(private readonly AssetBook $book, private readonly DepreciationCalculator $calculator, private readonly ComponentBook $componentBook) {}

    /** Register / list. Filters: q, status, categoryId, branchId ('company' = head office), asOf. */
    public function register(int $tenantId, array $filters, array $authorizedBranchIds, bool $owner): array
    {
        $asOf = $filters['asOf'] ?? null;
        $query = DB::table('fixed_assets as a')->leftJoin('asset_categories as c', 'c.id', '=', 'a.category_id')
            ->leftJoin('branches as b', 'b.id', '=', 'a.branch_id')->leftJoin('asset_locations as l', 'l.id', '=', 'a.location_id')
            ->where('a.tenant_id', $tenantId)->whereNull('a.deleted_at')
            ->when(! empty($filters['status']), fn ($q) => $q->where('a.status', $filters['status']), fn ($q) => empty($filters['includeDisposed']) ? $q->where('a.status', '!=', 'disposed') : $q)
            ->when(! empty($filters['categoryId']), fn ($q) => $q->where('a.category_id', (int) $filters['categoryId']))
            ->when(($filters['branchId'] ?? null) === 'company', fn ($q) => $q->whereNull('a.branch_id'))
            ->when(! empty($filters['branchId']) && $filters['branchId'] !== 'company', fn ($q) => $q->where('a.branch_id', (int) $filters['branchId']))
            ->when(! $owner, fn ($q) => $q->where(fn ($w) => $w->whereIn('a.branch_id', $authorizedBranchIds)->orWhereNull('a.branch_id')))
            ->when(! empty($filters['q']), function ($q) use ($filters) {
                $term = '%'.mb_strtolower(trim($filters['q'])).'%';
                $q->where(fn ($w) => $w->whereRaw('LOWER(a.name_ar) LIKE ?', [$term])->orWhereRaw('LOWER(a.code) LIKE ?', [$term])
                    ->orWhereRaw('LOWER(COALESCE(a.barcode, \'\')) LIKE ?', [$term])->orWhereRaw('LOWER(COALESCE(a.serial_number, \'\')) LIKE ?', [$term]));
            })
            ->orderByRaw("CASE WHEN a.code ~ '^[0-9]+$' THEN LPAD(a.code, 20, '0') ELSE a.code END");
        $rows = $query->get(['a.*', 'c.name_ar as category_name', 'b.name as branch_name', 'l.name as location_name']);
        $totals = $this->book->totalsMany($tenantId, $rows->pluck('id')->map(fn ($v) => (int) $v)->all(), $asOf);
        $sum = ['cost' => 0, 'accumulated' => 0, 'bookValue' => 0];
        $items = $rows->map(function ($a) use ($totals, &$sum) {
            $t = $totals[(int) $a->id] ?? ['cost' => $a->status === 'draft' ? Money::cents((string) $a->acquisition_cost) : 0, 'accumulated' => 0, 'lifeChange' => 0];
            if ($a->status !== 'draft') {
                $sum['cost'] += $t['cost'];
                $sum['accumulated'] += $t['accumulated'];
                $sum['bookValue'] += $t['cost'] - $t['accumulated'];
            }

            return $this->summary($a, $t);
        })->values()->all();

        return ['items' => $items, 'totals' => array_map(fn ($v) => Money::decimal($v), $sum), 'asOf' => $asOf, 'count' => count($items)];
    }

    public function card(int $tenantId, int $assetId): array
    {
        $a = DB::table('fixed_assets as a')->leftJoin('asset_categories as c', 'c.id', '=', 'a.category_id')
            ->leftJoin('branches as b', 'b.id', '=', 'a.branch_id')->leftJoin('asset_locations as l', 'l.id', '=', 'a.location_id')
            ->leftJoin('suppliers as s', 's.id', '=', 'a.supplier_id')
            ->where('a.tenant_id', $tenantId)->where('a.id', $assetId)->whereNull('a.deleted_at')
            ->first(['a.*', 'c.name_ar as category_name', 'b.name as branch_name', 'l.name as location_name', 's.name as supplier_name']);
        abort_unless($a, 404, 'الأصل غير موجود.');
        $t = $this->book->totals($tenantId, $assetId);
        if ($a->status === 'draft') {
            $t['cost'] = Money::cents((string) $a->acquisition_cost);
            $t['accumulated'] = Money::cents((string) $a->opening_accumulated);
        }
        $accounts = $this->book->accounts($tenantId, $a);
        $names = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('id', array_filter(array_merge(array_values($accounts), [$a->funding_account_id])))->get(['id', 'code', 'name_ar'])->keyBy('id');
        $acc = fn ($id) => $id && isset($names[$id]) ? ['id' => (int) $id, 'code' => $names[$id]->code, 'name' => $names[$id]->name_ar] : null;
        $overrides = [];
        foreach (AssetBook::ACCOUNT_FIELDS as $field) {
            $overrides[$field] = (bool) $a->{$field};
        }
        $lastTx = $this->book->latestTransaction($tenantId, $assetId);
        $period = DB::table('fixed_asset_transactions')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->whereNull('voided_at')
            ->whereYear('transaction_date', now()->year)->selectRaw("
                COALESCE(SUM(CASE WHEN type IN ('addition','maintenance','expense') THEN cost_amount ELSE 0 END),0) additions,
                COALESCE(SUM(CASE WHEN type IN ('maintenance','expense') THEN expense_amount ELSE 0 END),0) expenses,
                COALESCE(SUM(CASE WHEN type='disposal' THEN -cost_amount ELSE 0 END),0) disposals,
                COALESCE(SUM(CASE WHEN type='depreciation' THEN depreciation_amount ELSE 0 END),0) depreciation")->first();
        $before = DB::table('fixed_asset_transactions')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->whereNull('voided_at')
            ->whereYear('transaction_date', '<', now()->year)->selectRaw("
                COALESCE(SUM(CASE WHEN type IN ('addition','maintenance','expense') THEN cost_amount ELSE 0 END),0) additions,
                COALESCE(SUM(CASE WHEN type IN ('maintenance','expense') THEN expense_amount ELSE 0 END),0) expenses,
                COALESCE(SUM(CASE WHEN type='disposal' THEN -cost_amount ELSE 0 END),0) disposals,
                COALESCE(SUM(CASE WHEN type IN ('depreciation','opening') THEN depreciation_amount ELSE 0 END),0) depreciation")->first();
        $next = $a->status === 'active' ? $this->calculator->forPeriod($a, $t, now()->endOfMonth()->toDateString()) : null;

        return $this->summary($a, $t) + [
            'nameEn' => $a->name_en, 'barcode' => $a->barcode, 'serialNumber' => $a->serial_number, 'manufacturer' => $a->manufacturer,
            'warrantyEndDate' => $a->warranty_end_date, 'notes' => $a->notes, 'supplierId' => $a->supplier_id ? (int) $a->supplier_id : null,
            'supplierName' => $a->supplier_name, 'supplierInvoiceId' => $a->supplier_invoice_id ? (int) $a->supplier_invoice_id : null,
            'fundingAccount' => $acc($a->funding_account_id), 'isOpening' => (bool) $a->is_opening,
            'openingAccumulated' => Money::decimal(Money::cents((string) $a->opening_accumulated)),
            'accounts' => ['asset' => $acc($accounts['asset']), 'accumulated' => $acc($accounts['accumulated']), 'expense' => $acc($accounts['expense']), 'gain' => $acc($accounts['gain']), 'loss' => $acc($accounts['loss'])],
            'accountOverrides' => $overrides,
            'yearSummary' => [
                'previous' => ['additions' => $this->dec($before->additions), 'expenses' => $this->dec($before->expenses), 'disposals' => $this->dec($before->disposals), 'depreciation' => $this->dec($before->depreciation)],
                'current' => ['additions' => $this->dec($period->additions), 'expenses' => $this->dec($period->expenses), 'disposals' => $this->dec($period->disposals), 'depreciation' => $this->dec($period->depreciation)],
            ],
            'nextMonthDepreciation' => $next ? Money::decimal($next['amount']) : null,
            'lastTransactionId' => $lastTx ? (int) $lastTx->id : null,
            'components' => $this->components($tenantId, $assetId),
            'transactions' => $this->transactions($tenantId, $assetId),
        ];
    }

    public function transactions(int $tenantId, int $assetId): array
    {
        $branches = DB::table('branches')->where('tenant_id', $tenantId)->pluck('name', 'id');
        $runs = DB::table('depreciation_runs')->where('tenant_id', $tenantId)->pluck('run_number', 'id');
        $journals = DB::table('fixed_asset_transactions as t')->join('journal_entries as e', 'e.id', '=', 't.journal_entry_id')->where('t.fixed_asset_id', $assetId)->pluck('e.entry_number', 't.id');
        $payments = $this->payments($tenantId, $assetId, true);
        $expenseAccounts = DB::table('financial_accounts')->where('tenant_id', $tenantId)->pluck('name_ar', 'id');
        $cost = 0;
        $acc = 0;

        return DB::table('fixed_asset_transactions')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)
            ->orderBy('transaction_date')->orderBy('id')->get()->map(function ($t) use ($branches, $runs, $journals, $payments, $expenseAccounts, &$cost, &$acc) {
                if (! $t->voided_at) {
                    $cost += Money::cents((string) $t->cost_amount);
                    $acc += Money::cents((string) $t->depreciation_amount);
                }
                $branch = fn ($id) => $id ? ($branches[$id] ?? null) : 'الإدارة العامة';

                return [
                    'id' => (int) $t->id, 'type' => $t->type, 'typeLabel' => self::TYPE_LABELS[$t->type] ?? $t->type, 'date' => $t->transaction_date,
                    'costAmount' => $this->dec($t->cost_amount), 'depreciationAmount' => $this->dec($t->depreciation_amount),
                    'lifeChangeMonths' => (int) $t->life_change_months, 'proceeds' => $t->proceeds !== null ? $this->dec($t->proceeds) : null,
                    'gainLoss' => $t->gain_loss !== null ? $this->dec($t->gain_loss) : null,
                    'branchName' => $branch($t->branch_id), 'toBranchName' => $t->type === 'transfer' ? $branch($t->to_branch_id) : null,
                    'periodFrom' => $t->period_from, 'periodTo' => $t->period_to,
                    'runId' => $t->depreciation_run_id ? (int) $t->depreciation_run_id : null, 'runNumber' => $t->depreciation_run_id ? ($runs[$t->depreciation_run_id] ?? null) : null,
                    'journalEntryId' => $t->journal_entry_id ? (int) $t->journal_entry_id : null, 'journalNumber' => $journals[$t->id] ?? null,
                    'description' => $t->description, 'voided' => $t->voided_at !== null,
                    'expenseAmount' => $this->dec($t->expense_amount), 'expenseAccountName' => $t->expense_account_id ? ($expenseAccounts[$t->expense_account_id] ?? null) : null,
                    'componentScope' => $t->component_scope, 'payments' => $payments[(int) $t->id] ?? [],
                    'costAfter' => Money::decimal($cost), 'accumulatedAfter' => Money::decimal($acc), 'bookValueAfter' => Money::decimal($cost - $acc),
                ];
            })->values()->all();
    }

    public function schedule(int $tenantId, int $assetId): array
    {
        $asset = $this->book->asset($tenantId, $assetId);
        $book = $this->book->totals($tenantId, $assetId);
        if ($asset->status === 'draft') {
            $book['cost'] = Money::cents((string) $asset->acquisition_cost);
            $book['accumulated'] = Money::cents((string) $asset->opening_accumulated);
        }
        if (! in_array($asset->status, ['draft', 'active'], true)) {
            return ['rows' => []];
        }

        return ['rows' => array_map(fn ($r) => ['periodEnd' => $r['periodEnd'], 'amount' => Money::decimal($r['amount']), 'accumulated' => Money::decimal($r['accumulated']), 'bookValue' => Money::decimal($r['bookValue'])], $this->calculator->schedule($asset, $book))];
    }

    /** Operations report between dates. */
    public function operations(int $tenantId, array $filters): array
    {
        $branches = DB::table('branches')->where('tenant_id', $tenantId)->pluck('name', 'id');
        $rows = DB::table('fixed_asset_transactions as t')->join('fixed_assets as a', 'a.id', '=', 't.fixed_asset_id')
            ->where('t.tenant_id', $tenantId)->whereNull('t.voided_at')
            ->whereBetween('t.transaction_date', [$filters['dateFrom'], $filters['dateTo']])
            ->when(! empty($filters['type']), fn ($q) => $q->where('t.type', $filters['type']))
            ->when(! empty($filters['assetId']), fn ($q) => $q->where('t.fixed_asset_id', (int) $filters['assetId']))
            ->when(($filters['branchId'] ?? null) === 'company', fn ($q) => $q->whereNull('t.branch_id'))
            ->when(! empty($filters['branchId']) && $filters['branchId'] !== 'company', fn ($q) => $q->where(fn ($w) => $w->where('t.branch_id', (int) $filters['branchId'])->orWhere('t.to_branch_id', (int) $filters['branchId'])))
            ->orderBy('t.transaction_date')->orderBy('t.id')
            ->get(['t.*', 'a.code', 'a.name_ar']);
        $totals = [];
        $items = $rows->map(function ($t) use ($branches, &$totals) {
            $totals[$t->type] = ($totals[$t->type] ?? 0) + abs(Money::cents((string) ($t->type === 'depreciation' ? $t->depreciation_amount : ($t->type === 'expense' && Money::cents((string) $t->cost_amount) === 0 ? $t->expense_amount : $t->cost_amount))));

            return [
                'id' => (int) $t->id, 'assetId' => (int) $t->fixed_asset_id, 'assetCode' => $t->code, 'assetName' => $t->name_ar,
                'type' => $t->type, 'typeLabel' => self::TYPE_LABELS[$t->type] ?? $t->type, 'date' => $t->transaction_date,
                'costAmount' => $this->dec($t->cost_amount), 'depreciationAmount' => $this->dec($t->depreciation_amount), 'expenseAmount' => $this->dec($t->expense_amount),
                'proceeds' => $t->proceeds !== null ? $this->dec($t->proceeds) : null, 'gainLoss' => $t->gain_loss !== null ? $this->dec($t->gain_loss) : null,
                'branchName' => $t->branch_id ? ($branches[$t->branch_id] ?? null) : 'الإدارة العامة',
                'toBranchName' => $t->type === 'transfer' ? ($t->to_branch_id ? ($branches[$t->to_branch_id] ?? null) : 'الإدارة العامة') : null,
                'description' => $t->description,
            ];
        })->values()->all();

        return ['items' => $items, 'totals' => array_map(fn ($v) => Money::decimal($v), $totals)];
    }

    /**
     * Alerts for the register: warranties ending (or ended) within $days, and straight-line assets whose
     * useful life (incl. life added by maintenance) ends within $days. Disposed and draft assets are ignored.
     */
    public function alerts(int $tenantId, int $days, array $authorizedBranchIds, bool $owner): array
    {
        $today = CarbonImmutable::today();
        $until = $today->addDays($days);
        $rows = DB::table('fixed_assets as a')->leftJoin('branches as b', 'b.id', '=', 'a.branch_id')
            ->where('a.tenant_id', $tenantId)->whereNull('a.deleted_at')->whereIn('a.status', ['active', 'fully_depreciated'])
            ->when(! $owner, fn ($q) => $q->where(fn ($w) => $w->whereIn('a.branch_id', $authorizedBranchIds)->orWhereNull('a.branch_id')))
            ->get(['a.*', 'b.name as branch_name']);
        $totals = $this->book->totalsMany($tenantId, $rows->pluck('id')->map(fn ($v) => (int) $v)->all());
        $item = function ($a, string $date) use ($today, $totals) {
            $t = $totals[(int) $a->id] ?? ['cost' => 0, 'accumulated' => 0, 'lifeChange' => 0];

            return ['id' => (int) $a->id, 'code' => $a->code, 'nameAr' => $a->name_ar, 'branchName' => $a->branch_id ? $a->branch_name : 'الإدارة العامة',
                'date' => $date, 'daysLeft' => (int) $today->diffInDays(CarbonImmutable::parse($date), false), 'bookValue' => Money::decimal($t['cost'] - $t['accumulated'])];
        };
        $warranty = $rows->filter(fn ($a) => $a->warranty_end_date && $a->warranty_end_date <= $until->toDateString() && $a->warranty_end_date >= $today->subDays(30)->toDateString())
            ->sortBy('warranty_end_date')->map(fn ($a) => $item($a, $a->warranty_end_date) + ['expired' => $a->warranty_end_date < $today->toDateString()])->values()->all();
        $endOfLife = $rows->filter(fn ($a) => $a->status === 'active' && DepreciationCalculator::depreciates($a->method) && (int) $a->useful_life_months > 0)
            ->map(function ($a) use ($totals, $item) {
                $end = CarbonImmutable::parse($a->depreciation_start_date)->addMonths((int) $a->useful_life_months + (int) ($totals[(int) $a->id]['lifeChange'] ?? 0))->toDateString();

                return $item($a, $end);
            })->filter(fn ($i) => $i['daysLeft'] >= 0 && $i['daysLeft'] <= $days)->sortBy('date')->values()->all();

        return ['days' => $days, 'warranty' => $warranty, 'endOfLife' => $endOfLife, 'count' => count($warranty) + count($endOfLife)];
    }

    /** Items of the asset with their current cost and the expenses booked against them. */
    public function components(int $tenantId, int $assetId): array
    {
        return array_map(fn ($c) => [
            'id' => $c->id, 'name' => $c->name, 'baseCost' => Money::decimal($c->base), 'cost' => Money::decimal($c->cost), 'expenses' => Money::decimal($c->expenses),
        ], $this->componentBook->active($tenantId, $assetId));
    }

    /**
     * Payment legs. $byTransaction = true → map transaction id => legs; null → the legs of the draft card
     * (not yet attached to a transaction) as a flat list.
     */
    public function payments(int $tenantId, int $assetId, ?bool $byTransaction): array
    {
        $rows = DB::table('fixed_asset_payments as p')->join('financial_accounts as f', 'f.id', '=', 'p.account_id')
            ->where('p.tenant_id', $tenantId)->where('p.fixed_asset_id', $assetId)
            ->when($byTransaction === null, fn ($q) => $q->whereNull('p.transaction_id'))
            ->orderBy('p.id')->get(['p.transaction_id', 'p.account_id', 'p.amount', 'f.code', 'f.name_ar']);
        $leg = fn ($r) => ['accountId' => (int) $r->account_id, 'accountCode' => $r->code, 'accountName' => $r->name_ar, 'amount' => $this->dec($r->amount)];
        if ($byTransaction === null) {
            return $rows->map($leg)->values()->all();
        }
        $map = [];
        foreach ($rows as $r) {
            $map[(int) $r->transaction_id][] = $leg($r);
        }

        return $map;
    }

    private function summary(object $a, array $t): array
    {
        return [
            'id' => (int) $a->id, 'code' => $a->code, 'nameAr' => $a->name_ar, 'status' => $a->status, 'statusLabel' => self::STATUS_LABELS[$a->status] ?? $a->status,
            'categoryId' => $a->category_id ? (int) $a->category_id : null, 'categoryName' => $a->category_name ?? null,
            'branchId' => $a->branch_id ? (int) $a->branch_id : null, 'branchName' => $a->branch_id ? ($a->branch_name ?? null) : 'الإدارة العامة',
            'locationId' => $a->location_id ? (int) $a->location_id : null, 'locationName' => $a->location_name ?? null,
            'acquisitionDate' => $a->acquisition_date, 'depreciationStartDate' => $a->depreciation_start_date,
            'acquisitionCost' => $this->dec($a->acquisition_cost), 'salvageValue' => $this->dec($a->salvage_value),
            'usefulLifeMonths' => (int) $a->useful_life_months, 'lifeChangeMonths' => (int) $t['lifeChange'], 'method' => $a->method,
            'depreciatedUntil' => $a->depreciated_until,
            'cost' => Money::decimal($t['cost']), 'accumulated' => Money::decimal($t['accumulated']), 'bookValue' => Money::decimal($t['cost'] - $t['accumulated']),
        ];
    }

    private function dec(mixed $value): string
    {
        return Money::decimal(Money::cents((string) $value));
    }
}
