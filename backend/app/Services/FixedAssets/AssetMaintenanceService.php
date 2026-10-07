<?php

namespace App\Services\FixedAssets;

use App\Services\OperationalAuditService;
use App\Support\FinancialActor;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Maintenance side of an asset: ordinary expenses classified against it (no journal effect) and service contracts.
 * The cost of an asset (book value) is never touched here — capitalised maintenance stays in AssetBook / FixedAssetService.
 */
final class AssetMaintenanceService
{
    public const KINDS = ['maintenance' => 'صيانة دورية', 'repair' => 'إصلاح', 'other' => 'أخرى'];

    public const BILLING = ['monthly' => 'شهري', 'quarterly' => 'ربع سنوي', 'yearly' => 'سنوي', 'one_time' => 'دفعة واحدة'];

    public const CONTRACT_STATUS = ['active' => 'ساري', 'expired' => 'منتهي', 'cancelled' => 'ملغى'];

    /** Expense statuses that count as money actually spent / not yet spent (rejected and reversed are ignored). */
    private const SPENT = ['paid'];

    private const PENDING = ['draft', 'pending_approval', 'approved'];

    public function __construct(private readonly OperationalAuditService $audit) {}

    /** Validates an asset reference for tagging an expense. Returns the kind to store (default maintenance). */
    public function assertLinkable(int $tenantId, int $assetId, ?string $kind): string
    {
        $asset = DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('id', $assetId)->whereNull('deleted_at')->first(['id', 'status']);
        if (! $asset) {
            throw ValidationException::withMessages(['fixedAssetId' => 'الأصل غير موجود.']);
        }
        if ($asset->status === 'disposed') {
            throw ValidationException::withMessages(['fixedAssetId' => 'لا يمكن ربط مصروف بأصل مستبعد.']);
        }
        $kind = $kind ?: 'maintenance';
        if (! isset(self::KINDS[$kind])) {
            throw ValidationException::withMessages(['assetExpenseKind' => 'نوع المصروف غير صالح.']);
        }

        return $kind;
    }

    public function linkExpense(Request $request, int $tenantId, int $assetId, int $expenseId, ?string $kind, ?int $actorId): array
    {
        return DB::transaction(function () use ($request, $tenantId, $assetId, $expenseId, $kind, $actorId): array {
            $expense = $this->expense($tenantId, $expenseId, true);
            FinancialActor::assertBranchAccess($actorId, $tenantId, $expense->branch_id ? (int) $expense->branch_id : null);
            if (in_array($expense->status, ['rejected', 'reversed'], true)) {
                throw ValidationException::withMessages(['expenseId' => 'لا يمكن ربط مصروف مرفوض أو معكوس.']);
            }
            $kind = $this->assertLinkable($tenantId, $assetId, $kind);
            DB::table('expenses')->where('tenant_id', $tenantId)->where('id', $expenseId)->update(['fixed_asset_id' => $assetId, 'asset_expense_kind' => $kind, 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'expense.asset_linked', 'expense', $expenseId, ['fixed_asset_id' => $expense->fixed_asset_id], ['fixed_asset_id' => $assetId, 'asset_expense_kind' => $kind], $expense->branch_id, $actorId);

            return $this->summary($tenantId, $assetId);
        });
    }

    public function unlinkExpense(Request $request, int $tenantId, int $assetId, int $expenseId, ?int $actorId): array
    {
        return DB::transaction(function () use ($request, $tenantId, $assetId, $expenseId, $actorId): array {
            $expense = $this->expense($tenantId, $expenseId, true);
            FinancialActor::assertBranchAccess($actorId, $tenantId, $expense->branch_id ? (int) $expense->branch_id : null);
            if ((int) $expense->fixed_asset_id !== $assetId) {
                throw ValidationException::withMessages(['expenseId' => 'هذا المصروف غير مرتبط بهذا الأصل.']);
            }
            DB::table('expenses')->where('tenant_id', $tenantId)->where('id', $expenseId)->update(['fixed_asset_id' => null, 'asset_expense_kind' => null, 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'expense.asset_unlinked', 'expense', $expenseId, ['fixed_asset_id' => $assetId], ['fixed_asset_id' => null], $expense->branch_id, $actorId);

            return $this->summary($tenantId, $assetId);
        });
    }

    /** What the asset's «Maintenance» tab shows: tagged expenses with totals per kind, and its contracts. */
    public function summary(int $tenantId, int $assetId): array
    {
        $exists = DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('id', $assetId)->whereNull('deleted_at')->exists();
        abort_unless($exists, 404, 'الأصل غير موجود.');
        $rows = DB::table('expenses as e')->join('expense_categories as c', 'c.id', '=', 'e.expense_category_id')->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('e.tenant_id', $tenantId)->where('e.fixed_asset_id', $assetId)->whereNull('e.deleted_at')
            ->orderByDesc('e.expense_date')->orderByDesc('e.id')
            ->get(['e.id', 'e.expense_number', 'e.expense_date', 'e.description', 'e.total_amount', 'e.status', 'e.asset_expense_kind', 'c.name as category_name', 'b.name as branch_name']);
        $spent = ['maintenance' => 0, 'repair' => 0, 'other' => 0];
        $pending = 0;
        $items = $rows->map(function ($r) use (&$spent, &$pending) {
            $cents = Money::cents((string) $r->total_amount);
            if (in_array($r->status, self::SPENT, true)) {
                $spent[$r->asset_expense_kind ?? 'other'] = ($spent[$r->asset_expense_kind ?? 'other'] ?? 0) + $cents;
            } elseif (in_array($r->status, self::PENDING, true)) {
                $pending += $cents;
            }

            return ['id' => (int) $r->id, 'number' => $r->expense_number, 'date' => $r->expense_date, 'description' => $r->description, 'amount' => Money::decimal($cents),
                'status' => $r->status, 'kind' => $r->asset_expense_kind, 'kindLabel' => self::KINDS[$r->asset_expense_kind] ?? null, 'categoryName' => $r->category_name, 'branchName' => $r->branch_name];
        })->values()->all();

        return [
            'assetId' => $assetId,
            'expenses' => $items,
            'totals' => ['maintenance' => Money::decimal($spent['maintenance']), 'repair' => Money::decimal($spent['repair']), 'other' => Money::decimal($spent['other']),
                'paid' => Money::decimal(array_sum($spent)), 'pending' => Money::decimal($pending)],
            'contracts' => $this->contracts($tenantId, $assetId),
        ];
    }

    // ------------------------------------------------------------------ contracts

    public function contracts(int $tenantId, ?int $assetId = null): array
    {
        $today = CarbonImmutable::today();
        $rows = DB::table('asset_maintenance_contracts as k')->join('fixed_assets as a', 'a.id', '=', 'k.fixed_asset_id')->leftJoin('suppliers as s', 's.id', '=', 'k.supplier_id')
            ->where('k.tenant_id', $tenantId)->when($assetId, fn ($q) => $q->where('k.fixed_asset_id', $assetId))
            ->orderBy('k.end_date')->orderBy('k.id')
            ->get(['k.*', 'a.code as asset_code', 'a.name_ar as asset_name', 's.name as supplier_name']);

        return $rows->map(function ($k) use ($today) {
            $left = (int) $today->diffInDays(CarbonImmutable::parse($k->end_date), false);
            $status = $k->status === 'active' && $left < 0 ? 'expired' : $k->status;

            return ['id' => (int) $k->id, 'assetId' => (int) $k->fixed_asset_id, 'assetCode' => $k->asset_code, 'assetName' => $k->asset_name,
                'supplierId' => $k->supplier_id ? (int) $k->supplier_id : null, 'supplierName' => $k->supplier_name, 'contractNo' => $k->contract_no,
                'startDate' => $k->start_date, 'endDate' => $k->end_date, 'annualCost' => Money::decimal(Money::cents((string) $k->annual_cost)),
                'billing' => $k->billing, 'billingLabel' => self::BILLING[$k->billing] ?? $k->billing, 'renewalNoticeDays' => (int) $k->renewal_notice_days,
                'status' => $status, 'statusLabel' => self::CONTRACT_STATUS[$status] ?? $status, 'daysLeft' => $left,
                'renewalDue' => $status === 'active' && $left <= (int) $k->renewal_notice_days, 'notes' => $k->notes];
        })->values()->all();
    }

    public function saveContract(int $tenantId, int $assetId, array $data, ?int $contractId, ?int $actorId): array
    {
        $asset = DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('id', $assetId)->whereNull('deleted_at')->first(['id']);
        if (! $asset) {
            throw ValidationException::withMessages(['assetId' => 'الأصل غير موجود.']);
        }
        if (! empty($data['supplierId']) && ! DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $data['supplierId'])->exists()) {
            throw ValidationException::withMessages(['supplierId' => 'المورد غير موجود.']);
        }
        if ($data['endDate'] < $data['startDate']) {
            throw ValidationException::withMessages(['endDate' => 'تاريخ نهاية العقد قبل بدايته.']);
        }
        $payload = ['supplier_id' => $data['supplierId'] ?? null, 'contract_no' => $data['contractNo'] ?? null, 'start_date' => $data['startDate'], 'end_date' => $data['endDate'],
            'annual_cost' => Money::decimal(Money::cents((string) ($data['annualCost'] ?? '0'))), 'billing' => $data['billing'] ?? 'yearly',
            'renewal_notice_days' => (int) ($data['renewalNoticeDays'] ?? 30), 'status' => $data['status'] ?? 'active', 'notes' => $data['notes'] ?? null, 'updated_at' => now()];
        if ($contractId) {
            $found = DB::table('asset_maintenance_contracts')->where('tenant_id', $tenantId)->where('id', $contractId)->where('fixed_asset_id', $assetId)->exists();
            abort_unless($found, 404, 'العقد غير موجود.');
            DB::table('asset_maintenance_contracts')->where('id', $contractId)->update($payload);
        } else {
            DB::table('asset_maintenance_contracts')->insert($payload + ['tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'created_by' => $actorId, 'created_at' => now()]);
        }

        return $this->contracts($tenantId, $assetId);
    }

    /** Returns the asset id the deleted contract belonged to. */
    public function deleteContract(int $tenantId, int $contractId): int
    {
        $row = DB::table('asset_maintenance_contracts')->where('tenant_id', $tenantId)->where('id', $contractId)->first(['fixed_asset_id']);
        abort_unless($row, 404, 'العقد غير موجود.');
        DB::table('asset_maintenance_contracts')->where('id', $contractId)->delete();

        return (int) $row->fixed_asset_id;
    }

    // ------------------------------------------------------------------ report + alerts

    /**
     * Maintenance cost report: per asset, paid expenses by kind within the period (+ pending) and the yearly cost of its active contracts.
     * Filters: dateFrom, dateTo, branchId ('company' = head office), kind.
     */
    public function report(int $tenantId, array $filters, array $authorizedBranchIds, bool $owner): array
    {
        $rows = DB::table('expenses as e')->join('fixed_assets as a', 'a.id', '=', 'e.fixed_asset_id')->leftJoin('branches as b', 'b.id', '=', 'a.branch_id')
            ->where('e.tenant_id', $tenantId)->whereNull('e.deleted_at')->whereNotIn('e.status', ['rejected', 'reversed'])
            ->whereDate('e.expense_date', '>=', $filters['dateFrom'])->whereDate('e.expense_date', '<=', $filters['dateTo'])
            ->when(! empty($filters['kind']), fn ($q) => $q->where('e.asset_expense_kind', $filters['kind']))
            ->when(($filters['branchId'] ?? null) === 'company', fn ($q) => $q->whereNull('a.branch_id'))
            ->when(! empty($filters['branchId']) && $filters['branchId'] !== 'company', fn ($q) => $q->where('a.branch_id', (int) $filters['branchId']))
            ->when(! $owner, fn ($q) => $q->where(fn ($w) => $w->whereIn('a.branch_id', $authorizedBranchIds)->orWhereNull('a.branch_id')))
            ->get(['a.id as asset_id', 'a.code', 'a.name_ar', 'a.branch_id', 'b.name as branch_name', 'e.total_amount', 'e.status', 'e.asset_expense_kind']);
        $byAsset = [];
        foreach ($rows as $r) {
            $slot = &$byAsset[(int) $r->asset_id];
            $slot ??= ['assetId' => (int) $r->asset_id, 'code' => $r->code, 'nameAr' => $r->name_ar, 'branchName' => $r->branch_id ? $r->branch_name : 'الإدارة العامة',
                'maintenance' => 0, 'repair' => 0, 'other' => 0, 'pending' => 0, 'count' => 0];
            $cents = Money::cents((string) $r->total_amount);
            $slot['count']++;
            if ($r->status === 'paid') {
                $slot[$r->asset_expense_kind ?? 'other'] += $cents;
            } else {
                $slot['pending'] += $cents;
            }
            unset($slot);
        }
        $contracts = DB::table('asset_maintenance_contracts')->where('tenant_id', $tenantId)->where('status', 'active')->whereDate('end_date', '>=', now()->toDateString())
            ->whereIn('fixed_asset_id', array_keys($byAsset) ?: [0])->selectRaw('fixed_asset_id, SUM(annual_cost) as total')->groupBy('fixed_asset_id')->pluck('total', 'fixed_asset_id');
        $totals = ['maintenance' => 0, 'repair' => 0, 'other' => 0, 'pending' => 0, 'contracts' => 0];
        $items = collect($byAsset)->map(function ($s) use ($contracts, &$totals) {
            $contract = Money::cents((string) ($contracts[$s['assetId']] ?? '0'));
            $paid = $s['maintenance'] + $s['repair'] + $s['other'];
            foreach (['maintenance', 'repair', 'other', 'pending'] as $k) {
                $totals[$k] += $s[$k];
            }
            $totals['contracts'] += $contract;

            return ['assetId' => $s['assetId'], 'code' => $s['code'], 'nameAr' => $s['nameAr'], 'branchName' => $s['branchName'], 'count' => $s['count'],
                'maintenance' => Money::decimal($s['maintenance']), 'repair' => Money::decimal($s['repair']), 'other' => Money::decimal($s['other']),
                'paid' => Money::decimal($paid), 'pending' => Money::decimal($s['pending']), 'activeContractsAnnual' => Money::decimal($contract)];
        })->sortByDesc(fn ($i) => (float) $i['paid'])->values()->all();
        $totals['paid'] = $totals['maintenance'] + $totals['repair'] + $totals['other'];

        return ['items' => $items, 'totals' => array_map(fn ($v) => Money::decimal($v), $totals), 'dateFrom' => $filters['dateFrom'], 'dateTo' => $filters['dateTo']];
    }

    /** Contracts ending (or ended in the last 30 days) within $days — merged into AssetQueryService::alerts. */
    public function contractAlerts(int $tenantId, int $days, array $authorizedBranchIds, bool $owner): array
    {
        $today = CarbonImmutable::today();
        $rows = DB::table('asset_maintenance_contracts as k')->join('fixed_assets as a', 'a.id', '=', 'k.fixed_asset_id')->leftJoin('branches as b', 'b.id', '=', 'a.branch_id')
            ->leftJoin('suppliers as s', 's.id', '=', 'k.supplier_id')
            ->where('k.tenant_id', $tenantId)->where('k.status', 'active')->whereNull('a.deleted_at')->where('a.status', '!=', 'disposed')
            ->whereDate('k.end_date', '<=', $today->addDays($days)->toDateString())->whereDate('k.end_date', '>=', $today->subDays(30)->toDateString())
            ->when(! $owner, fn ($q) => $q->where(fn ($w) => $w->whereIn('a.branch_id', $authorizedBranchIds)->orWhereNull('a.branch_id')))
            ->orderBy('k.end_date')->get(['k.*', 'a.code', 'a.name_ar', 'a.branch_id', 'b.name as branch_name', 's.name as supplier_name']);

        return $rows->map(fn ($k) => ['id' => (int) $k->fixed_asset_id, 'contractId' => (int) $k->id, 'code' => $k->code, 'nameAr' => $k->name_ar,
            'branchName' => $k->branch_id ? $k->branch_name : 'الإدارة العامة', 'supplierName' => $k->supplier_name, 'contractNo' => $k->contract_no,
            'date' => $k->end_date, 'daysLeft' => (int) $today->diffInDays(CarbonImmutable::parse($k->end_date), false), 'expired' => $k->end_date < $today->toDateString()])->values()->all();
    }

    private function expense(int $tenantId, int $expenseId, bool $lock = false): object
    {
        $q = DB::table('expenses')->where('tenant_id', $tenantId)->where('id', $expenseId)->whereNull('deleted_at');
        if ($lock) {
            $q->lockForUpdate();
        }
        $row = $q->first();
        abort_unless($row, 404, 'المصروف غير موجود.');

        return $row;
    }
}
