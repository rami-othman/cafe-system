<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Safe reference data required to create a voucher, not a chart-of-accounts workspace. */
final class CashierFinanceOptionsController extends Controller
{
    public function vouchers(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $branches = FinancialActor::operationalBranchIds($actor, $tenant);

        $accounts = DB::table('financial_accounts')
            ->where('tenant_id', $tenant)->where('is_active', true)->whereNull('deleted_at')
            ->orderBy('code')->get()
            ->map(fn (object $a) => ['id' => (int) $a->id, 'code' => $a->code, 'nameAr' => $a->name_ar, 'nameEn' => $a->name_en, 'accountGroup' => $a->account_group, 'normalBalance' => $a->normal_balance, 'isActive' => true, 'isSystemProtected' => (bool) $a->is_system_protected]);
        $locations = DB::table('financial_locations as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
            ->leftJoin('branches as b', 'b.id', '=', 'l.branch_id')->where('l.tenant_id', $tenant)->where('l.is_active', true)
            ->select('l.*', 'a.code as account_code', 'a.name_ar as account_name_ar', 'b.name as branch_name')
            ->where(fn ($q) => $q->whereNull('l.branch_id')->orWhereIn('l.branch_id', $branches))->orderBy('l.code')->get()
            ->map(fn (object $l) => ['id' => (int) $l->id, 'branchId' => $l->branch_id ? (int) $l->branch_id : null, 'branchName' => $l->branch_name, 'financialAccountId' => (int) $l->financial_account_id, 'financialAccountCode' => $l->account_code, 'financialAccountNameAr' => $l->account_name_ar, 'code' => $l->code, 'name' => $l->name, 'kind' => $l->kind, 'type' => $l->type, 'bankName' => $l->bank_name, 'maskedReference' => $l->masked_reference, 'isActive' => true, 'balance' => '0.00', 'todayIncoming' => '0.00', 'todayOutgoing' => '0.00']);
        $branchRows = DB::table('branches')->where('tenant_id', $tenant)->where('is_active', true)->whereIn('id', $branches)->orderBy('name')->get()
            ->map(fn (object $b) => ['id' => (int) $b->id, 'name' => $b->name, 'currency' => $b->currency ?? 'SYP', 'timezone' => $b->timezone ?? '', 'isActive' => true, 'taxRate' => (float) ($b->tax_rate ?? 0)]);

        return response()->json(['data' => compact('accounts', 'locations', 'branchRows')]);
    }
}
