<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\JournalEntryRequest;
use App\Services\JournalEntryService;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class JournalEntryController extends Controller
{
    public function __construct(private readonly JournalEntryService $entries) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $query = DB::table('journal_entries as entries')->leftJoin('branches', 'branches.id', '=', 'entries.branch_id')->where('entries.tenant_id', $tenantId)->select('entries.*', 'branches.name as branch_name');
        foreach (['status' => 'entries.status', 'sourceType' => 'entries.source_type', 'branchId' => 'entries.branch_id'] as $parameter => $column) {
            if ($request->filled($parameter)) {
                $query->where($column, $request->query($parameter));
            }
        }
        if ($request->filled('from')) {
            $query->whereDate('entries.entry_date', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('entries.entry_date', '<=', $request->query('to'));
        }
        if ($request->filled('accountId')) {
            $query->whereExists(fn (Builder $lines) => $lines->selectRaw('1')->from('journal_entry_lines')->whereColumn('journal_entry_lines.journal_entry_id', 'entries.id')->where('journal_entry_lines.tenant_id', $tenantId)->where('journal_entry_lines.financial_account_id', $request->query('accountId')));
        }
        $paginator = $query->orderByDesc('entries.entry_date')->orderByDesc('entries.id')->paginate($this->perPage($request));

        return response()->json(['data' => collect($paginator->items())->map(fn (object $entry) => $this->serializeSummary($tenantId, $entry))->values(), 'meta' => $this->meta($paginator)]);
    }

    public function show(Request $request, int $entry): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        return response()->json(['data' => $this->serializeDetail($tenantId, $this->entries->find($tenantId, $entry))]);
    }

    public function store(JournalEntryRequest $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $id = $this->entries->createDraft($request, $tenantId, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serializeDetail($tenantId, $this->entries->find($tenantId, $id))], 201);
    }

    public function post(Request $request, int $entry): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->entries->post($request, $tenantId, $entry, FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->serializeDetail($tenantId, $this->entries->find($tenantId, $entry))]);
    }

    private function serializeSummary(int $tenantId, object $entry): array
    {
        [$debit, $credit] = $this->entries->totals($tenantId, $entry->id);

        return ['id' => (int) $entry->id, 'entryNumber' => $entry->entry_number, 'entryDate' => $entry->entry_date, 'branchId' => $entry->branch_id ? (int) $entry->branch_id : null, 'branchName' => $entry->branch_name ?? null, 'sourceType' => $entry->source_type, 'sourceId' => $entry->source_id ? (int) $entry->source_id : null, 'description' => $entry->description, 'status' => $entry->status, 'debitTotal' => Money::decimal($debit), 'creditTotal' => Money::decimal($credit), 'postedAt' => $entry->posted_at];
    }

    private function serializeDetail(int $tenantId, object $entry): array
    {
        $summary = $this->serializeSummary($tenantId, $entry);
        $summary['lines'] = DB::table('journal_entry_lines as lines')->join('financial_accounts as accounts', 'accounts.id', '=', 'lines.financial_account_id')->where('lines.tenant_id', $tenantId)->where('lines.journal_entry_id', $entry->id)->orderBy('lines.line_number')->get(['lines.*', 'accounts.code as account_code', 'accounts.name_ar as account_name_ar', 'accounts.name_en as account_name_en'])->map(fn (object $line) => ['id' => (int) $line->id, 'lineNumber' => (int) $line->line_number, 'accountId' => (int) $line->financial_account_id, 'accountCode' => $line->account_code, 'accountNameAr' => $line->account_name_ar, 'accountNameEn' => $line->account_name_en, 'description' => $line->description, 'debit' => $line->debit, 'credit' => $line->credit])->values();

        return $summary;
    }

    private function perPage(Request $request): int
    {
        return min(max((int) $request->query('perPage', 25), 1), 100);
    }

    private function meta($paginator): array
    {
        return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()];
    }
}
