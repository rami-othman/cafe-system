<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\OperationalAuditService;
use App\Services\SalesCreditNotePostingService;
use App\Services\SalesCreditNoteService;
use App\Support\FinanceAccess;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class SalesCreditNoteController extends Controller
{
    public function __construct(private readonly SalesCreditNoteService $creditNotes, private readonly SalesCreditNotePostingService $posting, private readonly OperationalAuditService $audit) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $q = $this->rows($tenant)->whereIn('n.branch_id', FinancialActor::operationalBranchIds($actor, $tenant));
        foreach (['customerId' => 'n.customer_id', 'branchId' => 'n.branch_id', 'status' => 'n.status', 'originalSalesInvoiceId' => 'n.original_sales_invoice_id'] as $input => $column) {
            if ($request->filled($input)) $q->where($column, $request->input($input));
        }
        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        $p = $q->orderByDesc('n.credit_date')->orderByDesc('n.id')->paginate($this->perPage($request));

        return response()->json(['data' => collect($p->items())->map(fn (object $row) => $this->serialize($row) + ['allowedActions' => $this->actions($row, $permissions)])->values(), 'meta' => $this->meta($p)]);
    }

    /** Original invoice lines with returnable quantities — feeds the "Create Credit Note" UI (§33). */
    public function returnableLines(Request $request, int $invoice): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $row = DB::table('sales_invoices')->where('tenant_id', $tenant)->where('id', $invoice)->first();
        abort_unless($row, 404, 'Sales invoice not found.');
        FinancialActor::assertBranchAccess($actor, $tenant, (int) $row->branch_id);

        return response()->json(['data' => $this->creditNotes->returnableLines($tenant, $invoice)]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $data = $this->data($request);
        $invoiceRow = DB::table('sales_invoices')->where('tenant_id', $tenant)->where('id', $data['originalSalesInvoiceId'])->first();
        abort_unless($invoiceRow, 404, 'Sales invoice not found.');
        FinancialActor::assertBranchAccess($actor, $tenant, (int) $invoiceRow->branch_id);

        $note = $this->creditNotes->create($tenant, $actor, $data);
        $this->audit->record($request, $tenant, 'sales.credit_note.created', 'sales_credit_note', $note->id, [], ['creditNoteNumber' => $note->credit_note_number, 'status' => 'draft'], $note->branch_id, $actor);

        return response()->json(['data' => $this->one($request, $tenant, $note->id)], 201);
    }

    public function show(Request $request, int $creditNote): JsonResponse
    {
        return response()->json(['data' => $this->one($request, TenantContext::id($request), $creditNote)]);
    }

    public function cancel(Request $request, int $creditNote): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $before = $this->creditNotes->find($tenant, $creditNote);
        FinancialActor::assertBranchAccess($actor, $tenant, $before->branch_id);
        $after = $this->creditNotes->cancel($tenant, $creditNote, $actor);
        $this->audit->record($request, $tenant, 'sales.credit_note.cancelled', 'sales_credit_note', $creditNote, ['status' => 'draft'], ['status' => 'cancelled'], $after->branch_id, $actor);

        return response()->json(['data' => $this->one($request, $tenant, $creditNote)]);
    }

    public function postingPreview(Request $request, int $creditNote): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $draft = $this->creditNotes->find($tenant, $creditNote);
        FinancialActor::assertBranchAccess($actor, $tenant, $draft->branch_id);

        return response()->json(['data' => $this->posting->preview($tenant, $creditNote)]);
    }

    public function post(Request $request, int $creditNote): JsonResponse
    {
        $data = $request->validate(['idempotencyKey' => ['required', 'string', 'max:128']]);
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $before = $this->creditNotes->find($tenant, $creditNote);
        FinancialActor::assertBranchAccess($actor, $tenant, $before->branch_id);
        $this->posting->post($request, $tenant, $creditNote, $actor, $data);

        return response()->json(['data' => $this->one($request, $tenant, $creditNote)]);
    }

    private function one(Request $request, int $tenant, int $id): array
    {
        $note = $this->creditNotes->find($tenant, $id);
        FinancialActor::assertBranchAccess(FinancialActor::id($request, $tenant), $tenant, $note->branch_id);
        $movements = DB::table('sales_credit_note_costs as costs')->leftJoin('stock_movements as movements', 'movements.id', '=', 'costs.inventory_movement_id')
            ->leftJoin('inventory_items as items', 'items.id', '=', 'movements.inventory_item_id')->leftJoin('warehouses as warehouses', 'warehouses.id', '=', 'movements.warehouse_id')
            ->where('costs.tenant_id', $tenant)->where('costs.sales_credit_note_id', $id)
            ->get(['costs.sales_credit_note_line_id', 'costs.cost_amount', 'movements.quantity_in', 'movements.input_unit', 'items.name_ar as item_name', 'warehouses.name as warehouse_name']);
        $journal = $note->posted_journal_entry_id ? DB::table('journal_entries')->where('tenant_id', $tenant)->where('id', $note->posted_journal_entry_id)->first(['id', 'entry_number']) : null;
        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);

        return $this->serialize($note) + [
            'lines' => collect($note->lines)->map(fn (object $l) => ['id' => (int) $l->id, 'lineNumber' => (int) $l->line_number, 'originalSalesInvoiceLineId' => (int) $l->original_sales_invoice_line_id, 'productId' => (int) $l->product_id, 'productName' => $l->product_name, 'productSku' => $l->product_sku, 'quantity' => $l->quantity, 'unitPrice' => $l->unit_price, 'taxRate' => $l->tax_rate, 'subtotal' => $l->subtotal, 'taxTotal' => $l->tax_total, 'total' => $l->total, 'restock' => (bool) $l->restock, 'cogsTotal' => $l->cogs_total])->values(),
            'allowedActions' => $this->actions($note, $permissions),
            'journalEntryId' => $journal?->id, 'journalReference' => $journal?->entry_number,
            'inventoryImpacts' => $movements->map(fn (object $m) => ['lineId' => (int) $m->sales_credit_note_line_id, 'itemName' => $m->item_name, 'quantityIn' => $m->quantity_in, 'unit' => $m->input_unit, 'warehouseName' => $m->warehouse_name, 'costAmount' => $m->cost_amount])->values(),
        ];
    }

    private function rows(int $tenant)
    {
        return DB::table('sales_credit_notes as n')->join('customers as c', 'c.id', '=', 'n.customer_id')->join('branches as b', 'b.id', '=', 'n.branch_id')
            ->join('sales_invoices as i', 'i.id', '=', 'n.original_sales_invoice_id')->leftJoin('users as u', 'u.id', '=', 'n.created_by')
            ->where('n.tenant_id', $tenant)->select('n.*', 'c.name as customer_name', 'c.customer_number', 'b.name as branch_name', 'i.invoice_number as original_invoice_number', 'u.name as creator_name');
    }

    private function serialize(object $n): array
    {
        return [
            'id' => (int) $n->id, 'creditNoteNumber' => $n->credit_note_number, 'branchId' => (int) $n->branch_id, 'branchName' => $n->branch_name,
            'customerId' => (int) $n->customer_id, 'customerName' => $n->customer_name, 'customerNumber' => $n->customer_number,
            'originalSalesInvoiceId' => (int) $n->original_sales_invoice_id, 'originalInvoiceNumber' => $n->original_invoice_number,
            'creditDate' => $n->credit_date, 'reason' => $n->reason, 'status' => $n->status,
            'subtotal' => $n->subtotal, 'taxTotal' => $n->tax_total, 'total' => $n->total,
            'arReductionAmount' => $n->ar_reduction_amount, 'customerCreditAmount' => $n->customer_credit_amount,
            'createdBy' => $n->creator_name, 'createdAt' => $n->created_at, 'postedAt' => $n->posted_at,
        ];
    }

    private function actions(object $n, array $p): array
    {
        return [
            'canView' => isset($p['finance.sales_credit_notes.view']),
            'canCancel' => $n->status === 'draft' && isset($p['finance.sales_credit_notes.create']),
            'canPost' => $n->status === 'draft' && isset($p['finance.sales_credit_notes.post']),
        ];
    }

    private function data(Request $request): array
    {
        return $request->validate([
            'originalSalesInvoiceId' => ['required', 'integer'],
            'creditDate' => ['nullable', 'date'],
            'reason' => ['nullable', 'string', 'max:500'],
            'idempotencyKey' => ['nullable', 'string', 'max:128'],
            'lines' => ['required', 'array', 'min:1'],
            'lines.*.originalSalesInvoiceLineId' => ['required', 'integer'],
            'lines.*.quantity' => ['required', 'regex:/^\d+(\.\d+)?$/'],
            'lines.*.restock' => ['nullable', 'boolean'],
        ]);
    }

    private function perPage(Request $r): int { return min(max((int) $r->query('perPage', 50), 1), 100); }
    private function meta($p): array { return ['currentPage' => $p->currentPage(), 'perPage' => $p->perPage(), 'total' => $p->total(), 'lastPage' => $p->lastPage()]; }
}
