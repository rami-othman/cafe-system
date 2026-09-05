<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinanceDashboardContext;
use App\Services\FinancialTransactionQueryService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

final class FinancialTransactionController extends Controller
{
    public function __construct(
        private readonly FinancialTransactionQueryService $transactions,
        private readonly FinanceDashboardContext $context,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request); $actorId = FinancialActor::id($request, $tenantId);
        return response()->json($this->transactions->list($request, $tenantId, $actorId, $this->filters($request)));
    }

    /** The actor's authorized branches for the Transactions global branch selector — never the tenant's full branch list. */
    public function branches(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request); $actorId = FinancialActor::id($request, $tenantId);
        $context = $this->context->resolve($tenantId, $actorId, []);

        return response()->json(['data' => ['branches' => $context['authorizedBranches']]]);
    }

    public function summary(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request); $actorId = FinancialActor::id($request, $tenantId);
        return response()->json(['data' => $this->transactions->summary($request, $tenantId, $actorId, $this->filters($request))]);
    }

    public function show(Request $request, int $transaction): JsonResponse
    {
        $tenantId = TenantContext::id($request); $actorId = FinancialActor::id($request, $tenantId);
        return response()->json(['data' => $this->transactions->detail($request, $tenantId, $actorId, $transaction)]);
    }

    private function filters(Request $request): array
    {
        $data = $request->validate([
            'date_from' => ['nullable', 'date'], 'date_to' => ['nullable', 'date', 'after_or_equal:date_from'],
            'branch_id' => ['nullable', 'integer'], 'source_type' => ['nullable', Rule::in(['sale', 'refund', 'expense', 'cash_transfer', 'supplier_invoice', 'supplier_payment', 'inventory_waste', 'stock_count_variance', 'manual_journal', 'journal_reversal', 'pos_order', 'payment_refund', 'manual', 'inventory_movement'])],
            'status' => ['nullable', Rule::in(['draft', 'posted'])], 'account_id' => ['nullable', 'integer'], 'account_code' => ['nullable', 'string', 'max:40'],
            'payment_method_id' => ['nullable', 'integer'], 'search' => ['nullable', 'string', 'max:120'],
            'reversal_state' => ['nullable', Rule::in(['none', 'original_reversed', 'reversal_entry'])],
            'has_cash_effect' => ['nullable', 'boolean'],
            'page' => ['nullable', 'integer', 'min:1'], 'per_page' => ['nullable', 'integer', 'min:1', 'max:100'], 'perPage' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);
        return ['dateFrom' => $data['date_from'] ?? null, 'dateTo' => $data['date_to'] ?? null, 'branchId' => $data['branch_id'] ?? null, 'sourceType' => $data['source_type'] ?? null, 'status' => $data['status'] ?? null, 'accountId' => $data['account_id'] ?? null, 'accountCode' => $data['account_code'] ?? null, 'paymentMethodId' => $data['payment_method_id'] ?? null, 'search' => $data['search'] ?? null, 'reversalState' => $data['reversal_state'] ?? null, 'hasCashEffect' => $data['has_cash_effect'] ?? null, 'perPage' => $data['perPage'] ?? $data['per_page'] ?? 10];
    }
}
