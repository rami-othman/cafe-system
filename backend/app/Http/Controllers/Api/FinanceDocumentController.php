<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinanceDocumentService;
use App\Support\FinancialActor;
use App\Support\FinanceAccess;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class FinanceDocumentController extends Controller
{
    public function __construct(private readonly FinanceDocumentService $documents) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $actorId = FinancialActor::id($request, $tenantId);
        $query = DB::table('finance_documents as documents')
            ->leftJoin('branches', 'branches.id', '=', 'documents.branch_id')
            ->leftJoin('financial_locations as locations', 'locations.id', '=', 'documents.financial_location_id')
            ->where('documents.tenant_id', $tenantId)
            ->select('documents.*', 'branches.name as branch_name', 'locations.name as location_name');
        if (DB::table('users')->where('tenant_id', $tenantId)->where('id', $actorId)->value('role') !== 'owner') {
            $query->where(fn (Builder $scope) => $scope->whereNull('documents.branch_id')->orWhereIn('documents.branch_id', FinancialActor::operationalBranchIds($actorId, $tenantId)));
        }
        foreach (['type' => 'documents.document_type', 'status' => 'documents.status', 'branchId' => 'documents.branch_id', 'financialLocationId' => 'documents.financial_location_id'] as $input => $column) {
            if ($request->filled($input)) $query->where($column, $request->query($input));
        }
        if ($request->filled('from')) $query->whereDate('documents.document_date', '>=', $request->query('from'));
        if ($request->filled('to')) $query->whereDate('documents.document_date', '<=', $request->query('to'));
        if ($request->filled('search')) {
            $term = '%'.strtolower((string) $request->query('search')).'%';
            $query->where(fn (Builder $items) => $items->whereRaw('LOWER(documents.document_number) LIKE ?', [$term])->orWhereRaw('LOWER(COALESCE(documents.description, \'\')) LIKE ?', [$term])->orWhereRaw('LOWER(COALESCE(documents.external_reference, \'\')) LIKE ?', [$term]));
        }
        $paginator = $query->orderByDesc('documents.document_date')->orderByDesc('documents.id')->paginate($this->perPage($request));
        return response()->json(['data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row, false, $request))->values(), 'meta' => $this->meta($paginator)]);
    }

    public function show(Request $request, int $document): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $row = $this->documents->find($tenantId, $document);
        FinancialActor::assertBranchAccess(FinancialActor::id($request, $tenantId), $tenantId, $row->branch_id ? (int) $row->branch_id : null);
        return response()->json(['data' => $this->serialize($row, true, $request)]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        FinanceAccess::authorize($request, $data['documentType'] === 'receipt' ? 'finance.receipts.create' : 'finance.payments.create');
        $tenantId = TenantContext::id($request);
        $row = $this->documents->createDraft($request, $tenantId, $data, FinancialActor::id($request, $tenantId));
        return response()->json(['data' => $this->serialize($row, true, $request)], 201);
    }

    public function post(Request $request, int $document): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $row = $this->documents->post($request, $tenantId, $document, FinancialActor::id($request, $tenantId));
        return response()->json(['data' => $this->serialize($row, true, $request)]);
    }

    public function reverse(Request $request, int $document): JsonResponse
    {
        $data = $request->validate(['reason' => ['required', 'string', 'max:1000']]);
        $tenantId = TenantContext::id($request);
        $row = $this->documents->reverse($request, $tenantId, $document, $data['reason'], FinancialActor::id($request, $tenantId));
        return response()->json(['data' => $this->serialize($row, true, $request)]);
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'documentType' => ['required', 'in:receipt,payment'],
            'documentDate' => ['required', 'date_format:Y-m-d'],
            'branchId' => ['nullable', 'integer'],
            'financialLocationId' => ['required', 'integer'],
            'counterpartyType' => ['nullable', 'string', 'max:30'],
            'counterpartyId' => ['nullable', 'integer'],
            'currencyCode' => ['nullable', 'string', 'size:3'],
            'exchangeRate' => ['nullable', 'regex:/^\d+(\.\d{1,6})?$/'],
            'amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'externalReference' => ['nullable', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:4000'],
            'notes' => ['nullable', 'string', 'max:4000'],
            'idempotencyKey' => ['nullable', 'string', 'max:120'],
            'lines' => ['required', 'array', 'min:1', 'max:100'],
            'lines.*.accountId' => ['required', 'integer'],
            'lines.*.amount' => ['required', 'regex:/^\d+(\.\d{1,2})?$/'],
            'lines.*.description' => ['nullable', 'string', 'max:1000'],
            'lines.*.costCenter' => ['nullable', 'string', 'max:120'],
            'lines.*.reference' => ['nullable', 'string', 'max:120'],
        ]);
    }

    private function serialize(object $row, bool $detail, Request $request): array
    {
        $tenantId = (int) $row->tenant_id;
        $data = [
            'id' => (int) $row->id, 'documentNumber' => $row->document_number, 'documentType' => $row->document_type,
            'status' => $row->status, 'documentDate' => $row->document_date, 'branchId' => $row->branch_id ? (int) $row->branch_id : null,
            'amount' => Money::decimal(Money::cents($row->amount)), 'currencyCode' => $row->currency_code,
            'financialLocationId' => (int) $row->financial_location_id, 'description' => $row->description,
            'externalReference' => $row->external_reference, 'journalEntryId' => $row->journal_entry_id ? (int) $row->journal_entry_id : null,
            'reversalJournalEntryId' => $row->reversal_journal_entry_id ? (int) $row->reversal_journal_entry_id : null,
            'createdAt' => $row->created_at, 'postedAt' => $row->posted_at ?? null, 'reversedAt' => $row->reversed_at,
            'allowedActions' => $this->actions($row, $request),
        ];
        if (isset($row->branch_name)) $data['branchName'] = $row->branch_name;
        if (isset($row->location_name)) $data['financialLocationName'] = $row->location_name;
        if ($detail) {
            $data += ['notes' => $row->notes, 'counterpartyType' => $row->counterparty_type, 'counterpartyId' => $row->counterparty_id, 'exchangeRate' => $row->exchange_rate, 'reversalReason' => $row->reversal_reason,
                'lines' => DB::table('finance_document_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')->where('lines.tenant_id', $tenantId)->where('lines.finance_document_id', $row->id)->orderBy('lines.line_number')->get(['lines.line_number', 'lines.description', 'lines.debit', 'lines.credit', 'lines.cost_center', 'lines.reference', 'accounts.id as account_id', 'accounts.code as account_code', 'accounts.name_ar as account_name_ar'])->map(fn (object $line) => ['lineNumber' => $line->line_number, 'accountId' => (int) $line->account_id, 'accountCode' => $line->account_code, 'accountNameAr' => $line->account_name_ar, 'description' => $line->description, 'debit' => $line->debit, 'credit' => $line->credit, 'costCenter' => $line->cost_center, 'reference' => $line->reference])->values()];
        }
        return $data;
    }

    private function actions(object $row, Request $request): array
    {
        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        $actions = [];
        if ($row->status === 'draft' && isset($permissions['finance.vouchers.post'])) $actions[] = 'post';
        if ($row->status === 'posted' && ! $row->reversal_journal_entry_id && isset($permissions['finance.vouchers.reverse'])) $actions[] = 'reverse';
        return $actions;
    }
    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 25), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }
}
