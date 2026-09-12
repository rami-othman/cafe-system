<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CustomerReceivableQueryService;
use App\Services\OperationalAuditService;
use App\Services\SalesInvoiceService;
use App\Services\SalesInvoicePostingService;
use App\Support\FinanceAccess;
use App\Support\FinancialActor;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class SalesInvoiceController extends Controller
{
    public function __construct(private readonly SalesInvoiceService $invoices, private readonly SalesInvoicePostingService $posting, private readonly CustomerReceivableQueryService $receivables, private readonly OperationalAuditService $audit) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant);
        if ($request->filled('branchId')) FinancialActor::assertBranchAccess($actor, $tenant, (int) $request->input('branchId'));
        $q = $this->rows($tenant)->whereIn('i.branch_id', FinancialActor::operationalBranchIds($actor, $tenant));
        foreach (['customerId' => 'i.customer_id', 'branchId' => 'i.branch_id', 'status' => 'i.status'] as $input => $column) if ($request->filled($input)) $q->where($column, $request->input($input));
        if ($request->filled('from')) $q->whereDate('i.invoice_date', '>=', $request->input('from'));
        if ($request->filled('to')) $q->whereDate('i.invoice_date', '<=', $request->input('to'));
        if ($request->filled('search')) { $like = '%'.strtolower($request->input('search')).'%'; $q->where(fn ($x) => $x->whereRaw('LOWER(i.invoice_number) LIKE ?', [$like])->orWhereRaw('LOWER(c.name) LIKE ?', [$like])->orWhereRaw('LOWER(COALESCE(i.reference, \'\')) LIKE ?', [$like])); }
        $summary = (clone $q)->where('i.status', 'draft')->selectRaw('COUNT(*) as count, COALESCE(SUM(i.total), 0) as total')->first();
        $p = $q->orderByDesc('i.invoice_date')->orderByDesc('i.id')->paginate($this->perPage($request)); $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        $items = collect($p->items());
        $postedIds = $items->where('status', 'posted')->pluck('id')->map(fn ($id) => (int) $id)->values()->all();
        $allocated = $this->receivables->allocatedCentsForInvoices($tenant, $postedIds);
        $creditedAr = $this->receivables->creditedArCentsForInvoices($tenant, $postedIds);
        $creditedTotal = $this->receivables->creditedTotalCentsForInvoices($tenant, $postedIds);
        $rows = $items->map(function (object $row) use ($allocated, $creditedAr, $creditedTotal, $permissions): array {
            $id = (int) $row->id;

            return $this->serialize($row, $allocated[$id] ?? null, $creditedAr[$id] ?? 0, $creditedTotal[$id] ?? 0) + ['allowedActions' => $this->actions($row, $permissions, $allocated[$id] ?? null, $creditedAr[$id] ?? 0)];
        })->values();
        return response()->json(['data' => $rows, 'meta' => $this->meta($p), 'summary' => ['draftInvoiceCount' => (int) $summary->count, 'draftInvoiceTotal' => Money::decimal(Money::cents($summary->total))]]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant); $data = $this->data($request, true); FinancialActor::assertBranchAccess($actor, $tenant, (int) $data['branchId']);
        $invoice = $this->invoices->create($tenant, $actor, $data); $this->audit->record($request, $tenant, 'sales.invoice.created', 'sales_invoice', $invoice->id, [], ['invoiceNumber' => $invoice->invoice_number, 'status' => 'draft'], $invoice->branch_id, $actor);
        return response()->json(['data' => $this->one($request, $tenant, $invoice->id)], 201);
    }

    public function show(Request $request, int $invoice): JsonResponse { return response()->json(['data' => $this->one($request, TenantContext::id($request), $invoice)]); }

    public function update(Request $request, int $invoice): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant); $data = $this->data($request, false); if (isset($data['branchId'])) FinancialActor::assertBranchAccess($actor, $tenant, (int) $data['branchId']);
        $before = $this->invoices->find($tenant, $invoice); FinancialActor::assertBranchAccess($actor, $tenant, $before->branch_id);
        $after = $this->invoices->update($tenant, $invoice, $actor, $data); $this->audit->record($request, $tenant, 'sales.invoice.updated', 'sales_invoice', $invoice, ['total' => $before->total], ['total' => $after->total], $after->branch_id, $actor);
        return response()->json(['data' => $this->one($request, $tenant, $invoice)]);
    }

    public function cancel(Request $request, int $invoice): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant); $before = $this->invoices->find($tenant, $invoice); FinancialActor::assertBranchAccess($actor, $tenant, $before->branch_id);
        $after = $this->invoices->cancel($tenant, $invoice, $actor, $request->validate(['reason' => ['nullable', 'string', 'max:500']])['reason'] ?? null); $this->audit->record($request, $tenant, 'sales.invoice.cancelled', 'sales_invoice', $invoice, ['status' => 'draft'], ['status' => 'cancelled'], $after->branch_id, $actor);
        return response()->json(['data' => $this->one($request, $tenant, $invoice)]);
    }

    public function post(Request $request, int $invoice): JsonResponse
    {
        $data = $request->validate(['idempotencyKey' => ['required', 'string', 'max:128']]);
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant);
        $before = $this->invoices->find($tenant, $invoice); FinancialActor::assertBranchAccess($actor, $tenant, $before->branch_id);
        $this->posting->post($request, $tenant, $invoice, $actor, $data);
        return response()->json(['data' => $this->one($request, $tenant, $invoice)]);
    }

    public function postingPreview(Request $request, int $invoice): JsonResponse
    {
        $tenant = TenantContext::id($request); $actor = FinancialActor::id($request, $tenant);
        $draft = $this->invoices->find($tenant, $invoice); FinancialActor::assertBranchAccess($actor, $tenant, $draft->branch_id);
        return response()->json(['data' => $this->posting->preview($tenant, $invoice)]);
    }

    public function products(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request); $q = DB::table('products as p')->leftJoin('categories as c', 'c.id', '=', 'p.category_id')->where('p.tenant_id', $tenant)->where('p.is_active', true)->whereNull('p.deleted_at');
        if ($request->filled('search')) { $like = '%'.strtolower($request->input('search')).'%'; $q->where(fn ($x) => $x->whereRaw('LOWER(p.name) LIKE ?', [$like])->orWhereRaw('LOWER(COALESCE(p.name_ar, \'\')) LIKE ?', [$like])->orWhereRaw('LOWER(COALESCE(p.sku, \'\')) LIKE ?', [$like])); }
        $p = $q->orderBy('p.name')->paginate($this->perPage($request), ['p.id', 'p.name', 'p.name_ar', 'p.sku', 'p.price', 'p.is_stock_tracked', 'c.name as category_name']);
        $variants = DB::table('product_variants')->where('tenant_id', $tenant)->whereIn('product_id', collect($p->items())->pluck('id'))->where('is_active', true)->whereNull('deleted_at')->orderByDesc('is_default')->orderBy('id')->get(['id','product_id','name','is_default'])->groupBy('product_id');
        return response()->json(['data' => collect($p->items())->map(fn (object $row) => ['id' => (int) $row->id, 'name' => $row->name_ar ?: $row->name, 'sku' => $row->sku, 'salePrice' => Money::decimal(Money::cents($row->price)), 'isStockTracked' => (bool) $row->is_stock_tracked, 'categoryName' => $row->category_name, 'variants' => ($variants[(int) $row->id] ?? collect())->map(fn (object $v) => ['id' => (int) $v->id, 'name' => $v->name, 'isDefault' => (bool) $v->is_default])->values()])->values(), 'meta' => $this->meta($p)]);
    }

    private function one(Request $request, int $tenant, int $id): array {
        $invoice = $this->invoices->find($tenant, $id); FinancialActor::assertBranchAccess(FinancialActor::id($request, $tenant), $tenant, $invoice->branch_id);
        $costs = DB::table('sales_invoice_costs as costs')->leftJoin('stock_movements as movements', 'movements.id', '=', 'costs.inventory_movement_id')->leftJoin('inventory_items as items', 'items.id', '=', 'movements.inventory_item_id')->leftJoin('warehouses as warehouses', 'warehouses.id', '=', 'movements.warehouse_id')->where('costs.tenant_id', $tenant)->where('costs.sales_invoice_id', $id)->get(['costs.sales_invoice_line_id', 'costs.cost_amount', 'movements.id as movement_id', 'movements.quantity_out', 'movements.input_unit', 'items.name_ar as item_name', 'warehouses.name as warehouse_name']);
        $receivable = DB::table('customer_receivables')->where('tenant_id', $tenant)->where('sales_invoice_id', $id)->first();
        $journal = $invoice->posted_journal_entry_id ? DB::table('journal_entries')->where('tenant_id', $tenant)->where('id', $invoice->posted_journal_entry_id)->first(['id','entry_number']) : null;
        $allocatedCents = $invoice->status === 'posted' ? $this->receivables->invoiceAllocatedCents($tenant, $id) : null;
        $creditedArCents = $invoice->status === 'posted' ? $this->receivables->invoiceCreditedArCents($tenant, $id) : 0;
        $creditedTotalCents = $invoice->status === 'posted' ? $this->receivables->invoiceCreditedTotalCents($tenant, $id) : 0;
        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        $collections = DB::table('customer_payment_allocations as a')->join('customer_payments as p', 'p.id', '=', 'a.customer_payment_id')->join('payment_methods as pm', 'pm.id', '=', 'p.payment_method_id')
            ->where('a.tenant_id', $tenant)->where('a.sales_invoice_id', $id)->where('p.status', 'posted')
            ->orderBy('p.payment_date')->orderBy('p.id')
            ->get(['p.id as payment_id', 'p.payment_number', 'p.payment_date', 'pm.name as payment_method_name', 'a.amount']);
        $creditNotes = DB::table('sales_credit_notes')->where('tenant_id', $tenant)->where('original_sales_invoice_id', $id)->where('status', 'posted')
            ->orderBy('credit_date')->orderBy('id')
            ->get(['id', 'credit_note_number', 'credit_date', 'reason', 'total', 'ar_reduction_amount', 'customer_credit_amount']);
        return $this->serialize($invoice, $allocatedCents, $creditedArCents, $creditedTotalCents) + ['lines' => collect($invoice->lines)->map(fn (object $l) => ['id' => (int) $l->id, 'lineNumber' => (int) $l->line_number, 'productId' => (int) $l->product_id, 'variantId' => $l->product_variant_id ? (int) $l->product_variant_id : null, 'productName' => $l->product_name, 'productSku' => $l->product_sku, 'quantity' => $l->quantity, 'unitPrice' => $l->unit_price, 'discountTotal' => $l->discount_total, 'taxRate' => $l->tax_rate, 'taxTotal' => $l->tax_total, 'subtotal' => $l->subtotal, 'total' => $l->total, 'cogsTotal' => $l->cogs_total])->values(),
            'allowedActions' => $this->actions($invoice, $permissions, $allocatedCents, $creditedArCents),
            'accountingStatus' => $invoice->status === 'posted' ? 'posted' : 'unposted',
            'inventoryStatus' => $invoice->status !== 'posted' ? 'not_consumed' : ($costs->isEmpty() ? 'not_applicable' : 'consumed'),
            'journalEntryId' => $journal?->id, 'journalReference' => $journal?->entry_number, 'receivableAmount' => $receivable?->original_amount,
            'inventoryImpacts' => $costs->map(fn (object $c) => ['lineId' => (int) $c->sales_invoice_line_id, 'movementId' => $c->movement_id ? (int) $c->movement_id : null, 'itemName' => $c->item_name, 'quantityOut' => $c->quantity_out, 'unit' => $c->input_unit, 'warehouseName' => $c->warehouse_name, 'costAmount' => $c->cost_amount])->values(),
            'collections' => $collections->map(fn (object $c) => ['paymentId' => (int) $c->payment_id, 'paymentNumber' => $c->payment_number, 'paymentDate' => $c->payment_date, 'paymentMethodName' => $c->payment_method_name, 'amount' => Money::decimal(Money::cents($c->amount))])->values(),
            'creditNotes' => $creditNotes->map(fn (object $n) => ['id' => (int) $n->id, 'creditNoteNumber' => $n->credit_note_number, 'creditDate' => $n->credit_date, 'reason' => $n->reason, 'total' => $n->total, 'arReductionAmount' => $n->ar_reduction_amount, 'customerCreditAmount' => $n->customer_credit_amount])->values(),
        ];
    }
    private function rows(int $tenant) { return DB::table('sales_invoices as i')->join('customers as c', 'c.id', '=', 'i.customer_id')->join('branches as b', 'b.id', '=', 'i.branch_id')->leftJoin('users as u', 'u.id', '=', 'i.created_by')->where('i.tenant_id', $tenant)->select('i.*', 'c.name as customer_name', 'c.customer_number', 'b.name as branch_name', 'u.name as creator_name'); }
    /** $allocatedCents is null for a non-posted invoice (payment status is not applicable until AR exists). */
    private function serialize(object $i, ?int $allocatedCents = null, int $creditedArCents = 0, int $creditedTotalCents = 0): array {
        $totalCents = Money::cents($i->total);
        // Outstanding AR is net of both payments and credit notes — the real
        // amount still owed, and what payment allocation is limited by.
        // Payment STATUS (unpaid/partial/paid) and credit STATUS stay
        // distinct concepts (§37): an invoice fully written off by a Credit
        // Note with zero real payment is "unpaid" + "fully_credited", never
        // reported as "paid" — that word is reserved for actual collection.
        $remainingCents = $allocatedCents === null ? null : $totalCents - $allocatedCents - $creditedArCents;
        $paidOnlyRemainingCents = $allocatedCents === null ? null : $totalCents - $allocatedCents;
        $isOverdue = $remainingCents !== null && $remainingCents > 0 && $i->due_date !== null && $i->due_date < now()->toDateString();
        $paymentStatus = $paidOnlyRemainingCents === null ? 'not_applicable' : ($isOverdue ? 'overdue' : $this->receivables->paymentStatus($totalCents, $paidOnlyRemainingCents));
        $creditStatus = $this->receivables->creditStatus($totalCents, $creditedTotalCents);
        return ['id' => (int) $i->id, 'invoiceNumber' => $i->invoice_number, 'branchId' => (int) $i->branch_id, 'branchName' => $i->branch_name, 'customerId' => (int) $i->customer_id, 'customerName' => $i->customer_name, 'customerNumber' => $i->customer_number, 'invoiceDate' => $i->invoice_date, 'dueDate' => $i->due_date, 'currencyCode' => $i->currency_code, 'reference' => $i->reference, 'notes' => $i->notes, 'status' => $i->status, 'subtotal' => $i->subtotal, 'discountTotal' => $i->discount_total, 'taxRate' => $i->tax_rate, 'taxTotal' => $i->tax_total, 'total' => $i->total, 'paidAmount' => $allocatedCents === null ? null : Money::decimal($allocatedCents), 'remainingAmount' => $remainingCents === null ? null : Money::decimal($remainingCents), 'paymentStatus' => $paymentStatus, 'isOverdue' => $isOverdue, 'creditedAmount' => $allocatedCents === null ? null : Money::decimal($creditedTotalCents), 'creditStatus' => $allocatedCents === null ? 'not_applicable' : $creditStatus, 'createdBy' => $i->creator_name, 'createdAt' => $i->created_at, 'updatedAt' => $i->updated_at]; }
    private function actions(object $i, array $p, ?int $allocatedCents = null, int $creditedArCents = 0): array {
        $remainingCents = $allocatedCents === null ? null : Money::cents($i->total) - $allocatedCents - $creditedArCents;
        return ['canView' => isset($p['finance.sales.view']), 'canEdit' => $i->status === 'draft' && isset($p['finance.sales.edit']), 'canCancel' => $i->status === 'draft' && isset($p['finance.sales.edit']), 'canPost' => $i->status === 'draft' && isset($p['finance.sales.post']), 'canRegisterPayment' => $i->status === 'posted' && $remainingCents !== null && $remainingCents > 0 && isset($p['finance.customer_payments.create']), 'canCreateCreditNote' => $i->status === 'posted' && isset($p['finance.sales_credit_notes.create'])];
    }
    private function data(Request $request, bool $creating): array { return $request->validate(['branchId' => [$creating ? 'required' : 'sometimes', 'integer'], 'customerId' => [$creating ? 'required' : 'sometimes', 'integer'], 'invoiceDate' => [$creating ? 'required' : 'sometimes', 'date'], 'dueDate' => ['nullable', 'date'], 'reference' => ['nullable', 'string', 'max:128'], 'notes' => ['nullable', 'string', 'max:5000'], 'idempotencyKey' => [$creating ? 'nullable' : 'prohibited', 'string', 'max:128'], 'lines' => [$creating ? 'required' : 'sometimes', 'array', 'min:1'], 'lines.*.productId' => ['required_with:lines', 'integer'], 'lines.*.variantId' => ['nullable', 'integer'], 'lines.*.quantity' => ['required_with:lines', 'regex:/^\d+(\.\d+)?$/']]); }
    private function perPage(Request $r): int { return min(max((int) $r->query('perPage', 50), 1), 100); } private function meta($p): array { return ['currentPage' => $p->currentPage(), 'perPage' => $p->perPage(), 'total' => $p->total(), 'lastPage' => $p->lastPage()]; }
}
