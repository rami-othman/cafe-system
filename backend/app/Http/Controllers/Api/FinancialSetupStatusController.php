<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinancialSetupService;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\SupplierPayableQueryService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FinancialSetupStatusController extends Controller
{
    public function __construct(private readonly FinancialSetupService $setup, private readonly FinancialAccountBalanceQuery $balances, private readonly SupplierPayableQueryService $payable) {}

    public function show(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $requiredCodes = collect($this->setup->defaultAccounts())->pluck('code');
        $accountsReady = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')->whereIn('code', $requiredCodes)->count() === $requiredCodes->count();
        $centralReady = DB::table('warehouses')->where('tenant_id', $tenantId)->where('type', 'central')->where('is_active', true)->whereNull('deleted_at')->exists();
        $branches = DB::table('branches')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->orderBy('id')->get();
        $missingBranchWarehouses = $branches->filter(fn (object $branch) => ! DB::table('warehouses')->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('type', 'branch_main')->where('is_active', true)->whereNull('deleted_at')->exists())->map(fn (object $branch) => ['id' => (int) $branch->id, 'name' => $branch->name])->values();
        $branchCoverageReady = $missingBranchWarehouses->isEmpty();
        $accounts = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at');
        $accountCount = (clone $accounts)->count();
        $activeAccountCount = (clone $accounts)->where('is_active', true)->count();
        $systemAccountCount = (clone $accounts)->where('is_system_protected', true)->count();
        $journals = DB::table('journal_entries')->where('tenant_id', $tenantId);
        $journalCount = (clone $journals)->count();
        $draftJournalCount = (clone $journals)->where('status', 'draft')->count();
        $postedJournalCount = (clone $journals)->where('status', 'posted')->count();
        $reversedOriginalCount = (clone $journals)->whereExists(fn ($query) => $query->selectRaw('1')->from('journal_entries as reversals')->whereColumn('reversals.reversal_of_id', 'journal_entries.id')->where('reversals.tenant_id', $tenantId))->count();
        $defaultAccounts = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')->whereIn('code', $requiredCodes)->orderBy('code')->get(['code', 'name_ar', 'account_group', 'is_active'])->map(fn (object $account) => ['code' => $account->code, 'nameAr' => $account->name_ar, 'accountGroup' => $account->account_group, 'isActive' => (bool) $account->is_active])->values();
        $financialLocations = DB::table('financial_locations')->where('tenant_id', $tenantId)->get();
        $cashBankBalanceCents = $financialLocations->sum(fn (object $location) => \App\Support\Money::cents($this->balances->summary($tenantId, (int) $location->financial_account_id)['balance']));
        $expenses = DB::table('expenses')->where('tenant_id', $tenantId)->whereNull('deleted_at');
        $expensesToday = (clone $expenses)->whereDate('expense_date', now()->toDateString())->sum('total_amount');
        $expensesThisMonth = (clone $expenses)->whereBetween('expense_date', [now()->startOfMonth()->toDateString(), now()->endOfMonth()->toDateString()])->sum('total_amount');

        return response()->json(['data' => [
            'systemAccountsReady' => $accountsReady,
            'centralWarehouseReady' => $centralReady,
            'branchWarehouseCoverageReady' => $branchCoverageReady,
            'financialSetupReady' => $accountsReady && $centralReady && $branchCoverageReady,
            'requiredAccountCount' => $requiredCodes->count(),
            'configuredAccountCount' => $accountCount,
            'accountCount' => $accountCount,
            'activeAccountCount' => $activeAccountCount,
            'inactiveAccountCount' => $accountCount - $activeAccountCount,
            'systemAccountCount' => $systemAccountCount,
            'journalCount' => $journalCount,
            'draftJournalCount' => $draftJournalCount,
            'postedJournalCount' => $postedJournalCount,
            'reversedOriginalCount' => $reversedOriginalCount,
            'journalEngineReady' => true,
            'journalReversalReady' => true,
            'postingInfrastructureReady' => true,
            'defaultAccounts' => $defaultAccounts,
            'cashBankAccountCount' => $financialLocations->count(),
            'cashBankBalance' => \App\Support\Money::decimal($cashBankBalanceCents),
            'activePaymentMethodCount' => DB::table('payment_methods')->where('tenant_id', $tenantId)->where('is_active', true)->count(),
            'expensesToday' => \App\Support\Money::decimal(\App\Support\Money::cents((string) $expensesToday)),
            'expensesThisMonth' => \App\Support\Money::decimal(\App\Support\Money::cents((string) $expensesThisMonth)),
            'pendingExpenseCount' => (clone $expenses)->where('status', 'pending_approval')->count(),
            'unpaidExpenseCount' => (clone $expenses)->where('payment_status', 'unpaid')->count(),
            'totalPayables' => \App\Support\Money::decimal(array_sum(array_map(fn (string $v) => \App\Support\Money::cents($v), $this->payable->outstandingBySupplier($tenantId)))),
            'overduePayables' => $this->payable->overdueOutstanding($tenantId),
            'openSupplierInvoiceCount' => $this->payable->openInvoiceCount($tenantId),
            'activeSupplierCount' => DB::table('suppliers')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at')->count(),
            'activeBranchCount' => $branches->count(),
            'missingBranchWarehouses' => $missingBranchWarehouses,
        ]]);
    }
}
