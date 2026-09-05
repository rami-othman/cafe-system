<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinancialReportQueryService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class FinancialReportController extends Controller
{
    public function __construct(private readonly FinancialReportQueryService $reports) {}
    public function index(): JsonResponse { return response()->json(['data' => ['reports' => ['profitLoss', 'balanceSheet', 'cashFlow', 'trialBalance', 'generalLedger', 'supplierAging', 'supplierStatement'], 'filters' => ['dateFrom', 'dateTo', 'asOfDate', 'branchId', 'comparison']]]); }
    public function profitLoss(Request $request): JsonResponse { return response()->json(['data' => $this->reports->profitAndLoss($this->context($request))]); }
    public function balanceSheet(Request $request): JsonResponse { $ctx = $this->context($request); $asOf = $request->validate(['asOfDate' => ['nullable', 'date_format:Y-m-d']])['asOfDate'] ?? $ctx['dateTo']; return response()->json(['data' => $this->reports->balanceSheet($ctx, $asOf)]); }
    public function cashFlow(Request $request): JsonResponse { return response()->json(['data' => $this->reports->cashFlow($this->context($request))]); }
    public function trialBalance(Request $request): JsonResponse { $ctx = $this->context($request); $include = filter_var($request->query('includeZero', false), FILTER_VALIDATE_BOOLEAN); return response()->json(['data' => $this->reports->trialBalance($ctx, $include)]); }
    public function generalLedger(Request $request): JsonResponse { $data = $request->validate(['accountId' => ['required', 'integer'], 'page' => ['nullable', 'integer', 'min:1'], 'perPage' => ['nullable', 'integer', 'min:1', 'max:100']]); return response()->json(['data' => $this->reports->generalLedger($this->context($request), (int) $data['accountId'], (int) ($data['page'] ?? 1), (int) ($data['perPage'] ?? 50))]); }
    public function supplierAging(Request $request): JsonResponse { $data = $request->validate(['asOfDate' => ['nullable', 'date_format:Y-m-d'], 'supplierId' => ['nullable', 'integer']]); $ctx = $this->context($request); return response()->json(['data' => $this->reports->supplierAging($ctx, $data['asOfDate'] ?? $ctx['dateTo'], isset($data['supplierId']) ? (int) $data['supplierId'] : null)]); }
    public function supplierStatement(Request $request): JsonResponse { $data = $request->validate(['supplierId' => ['required', 'integer']]); $ctx = $this->context($request); return response()->json(['data' => $this->reports->supplierStatement($ctx, (int) $data['supplierId'])]); }
    private function context(Request $request): array { $tenant = TenantContext::id($request); $filters = $request->validate(['dateFrom' => ['nullable', 'date_format:Y-m-d'], 'dateTo' => ['nullable', 'date_format:Y-m-d'], 'branchId' => ['nullable', 'integer'], 'comparison' => ['nullable', 'in:previous_period,none']]); return $this->reports->context($tenant, FinancialActor::id($request, $tenant), $filters); }
}
