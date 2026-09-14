<?php

namespace App\Http\Controllers\Api;

use App\Domain\Purchasing\PurchaseReceivingService;
use App\Http\Controllers\Controller;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use App\Support\WarehousePresentation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Goods Receipt API — Purchasing Phase 2. Every mutation goes through
 * PurchaseReceivingService, which is the only caller allowed to move a
 * receipt's lines into `stock_movements` (via InventoryPostingService). This
 * controller performs reads, request shaping, and permission checks only.
 */
class PurchaseReceiptController extends Controller
{
    public function __construct(private readonly PurchaseReceivingService $receiving) {}

    /** GET /finance/purchase-receipts — "الاستلامات" tenant-wide list. */
    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $q = $this->rows($tenant);
        if (DB::table('users')->where('tenant_id', $tenant)->where('id', $actor)->value('role') !== 'owner') {
            $q->where(fn ($scope) => $scope->whereIn('r.branch_id', FinancialActor::operationalBranchIds($actor, $tenant))->orWhereNull('r.branch_id'));
        }
        foreach (['branchId' => 'r.branch_id', 'supplierInvoiceId' => 'r.supplier_invoice_id', 'status' => 'r.status'] as $input => $column) {
            if ($request->filled($input)) {
                $q->where($column, $request->input($input));
            }
        }
        if ($request->filled('supplierId')) {
            $q->where('i.supplier_id', $request->input('supplierId'));
        }
        if ($request->filled('warehouseId')) {
            $q->whereExists(fn ($scope) => $scope->selectRaw('1')->from('purchase_receipt_lines as pl')->whereColumn('pl.purchase_receipt_id', 'r.id')->where('pl.warehouse_id', $request->input('warehouseId')));
        }
        if ($request->filled('invoiceNumber')) {
            $q->where(fn ($scope) => $scope->where('i.invoice_number', 'like', '%'.$request->input('invoiceNumber').'%')->orWhere('i.internal_reference', 'like', '%'.$request->input('invoiceNumber').'%'));
        }
        if ($request->filled('receiptNumber')) {
            $q->where('r.receipt_number', 'like', '%'.$request->input('receiptNumber').'%');
        }
        if ($request->filled('from')) {
            $q->whereDate('r.receipt_date', '>=', $request->input('from'));
        }
        if ($request->filled('to')) {
            $q->whereDate('r.receipt_date', '<=', $request->input('to'));
        }

        $paginator = $q->orderByDesc('r.receipt_date')->orderByDesc('r.id')->paginate(min(max((int) $request->query('perPage', 50), 1), 100));

        return response()->json([
            'data' => collect($paginator->items())->map(fn (object $row) => $this->serializeSummary($row))->values(),
            'meta' => ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()],
        ]);
    }

    public function show(Request $request, int $receipt): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $row = $this->rows($tenant)->where('r.id', $receipt)->first();
        abort_unless($row, 404);
        $actor = FinancialActor::id($request, $tenant);
        FinancialActor::assertBranchAccess($actor, $tenant, $row->branch_id ? (int) $row->branch_id : null);

        return response()->json(['data' => $this->serializeSummary($row) + ['lines' => $this->serializeLines($this->receiving->lines($tenant, $receipt))]]);
    }

    /** GET /finance/purchases/{purchase}/receipts — receipt history for one invoice ("سجل الاستلامات"). */
    public function forInvoice(Request $request, int $purchase): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $invoice = DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('id', $purchase)->whereNull('deleted_at')->first();
        abort_unless($invoice, 404);
        $actor = FinancialActor::id($request, $tenant);
        FinancialActor::assertBranchAccess($actor, $tenant, $invoice->branch_id ? (int) $invoice->branch_id : null);

        $rows = $this->rows($tenant)->where('r.supplier_invoice_id', $purchase)->orderByDesc('r.id')->get();

        return response()->json(['data' => $rows->map(fn (object $row) => $this->serializeSummary($row))->values()]);
    }

    public function store(Request $request, int $purchase): JsonResponse
    {
        $data = $this->draftData($request);
        $tenant = TenantContext::id($request);
        $receipt = $this->receiving->create($request, $tenant, $purchase, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serializeSummary($this->rows($tenant)->where('r.id', $receipt->id)->first()) + ['lines' => $this->serializeLines($this->receiving->lines($tenant, $receipt->id))]], 201);
    }

    public function update(Request $request, int $receipt): JsonResponse
    {
        $data = $this->draftData($request);
        $tenant = TenantContext::id($request);
        $updated = $this->receiving->update($request, $tenant, $receipt, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serializeSummary($this->rows($tenant)->where('r.id', $updated->id)->first()) + ['lines' => $this->serializeLines($this->receiving->lines($tenant, $updated->id))]]);
    }

    public function post(Request $request, int $receipt): JsonResponse
    {
        $data = $request->validate(['idempotencyKey' => ['required', 'string', 'max:120']]);
        $tenant = TenantContext::id($request);
        $posted = $this->receiving->post($request, $tenant, $receipt, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->serializeSummary($this->rows($tenant)->where('r.id', $posted->id)->first()) + ['lines' => $this->serializeLines($this->receiving->lines($tenant, $posted->id))]]);
    }

    private function draftData(Request $request): array
    {
        return $request->validate([
            'receiptDate' => ['nullable', 'date'],
            'reference' => ['nullable', 'string', 'max:120'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'idempotencyKey' => ['nullable', 'string', 'max:120'],
            'lines' => ['required', 'array', 'min:1'],
            'lines.*.supplierInvoiceLineId' => ['required', 'integer'],
            'lines.*.quantity' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'],
            'lines.*.warehouseId' => ['nullable', 'integer'],
        ]);
    }

    private function rows(int $tenant)
    {
        return DB::table('purchase_receipts as r')
            ->join('supplier_invoices as i', 'i.id', '=', 'r.supplier_invoice_id')
            ->join('suppliers as s', 's.id', '=', 'i.supplier_id')
            ->leftJoin('branches as b', 'b.id', '=', 'r.branch_id')
            ->leftJoin('users as u', 'u.id', '=', 'r.created_by')
            ->where('r.tenant_id', $tenant)
            ->select(
                'r.*', 'i.invoice_number', 'i.internal_reference as invoice_reference', 'i.supplier_id',
                's.name as supplier_name', 'b.name as branch_name', 'u.name as created_by_name',
                DB::raw('(SELECT COUNT(*) FROM purchase_receipt_lines pl WHERE pl.purchase_receipt_id = r.id) as line_count'),
            );
    }

    private function serializeSummary(object $row): array
    {
        return [
            'id' => (int) $row->id,
            'receiptNumber' => $row->receipt_number,
            'receiptDate' => $row->receipt_date,
            'status' => $row->status,
            'reference' => $row->reference,
            'notes' => $row->notes,
            'supplierInvoiceId' => (int) $row->supplier_invoice_id,
            'invoiceNumber' => $row->invoice_number,
            'invoiceReference' => $row->invoice_reference,
            'supplierId' => (int) $row->supplier_id,
            'supplierName' => $row->supplier_name,
            'branchId' => $row->branch_id ? (int) $row->branch_id : null,
            'branchName' => $row->branch_name ?? 'المستودع المركزي',
            'lineCount' => (int) $row->line_count,
            'createdByName' => $row->created_by_name,
            'postedAt' => $row->posted_at,
            'createdAt' => $row->created_at,
            'allowedActions' => $this->actions($row),
        ];
    }

    /** @param array<int, object> $lines */
    private function serializeLines(array $lines): array
    {
        return array_map(fn (object $l): array => [
            'id' => (int) $l->id,
            'supplierInvoiceLineId' => (int) $l->supplier_invoice_line_id,
            'inventoryItemId' => (int) $l->inventory_item_id,
            'itemName' => $l->item_name_en ?: $l->item_name_ar,
            'warehouseId' => (int) $l->warehouse_id,
            'warehouseName' => WarehousePresentation::displayName($l->warehouse_branch_name, $l->warehouse_type),
            'receivedUnit' => $l->received_unit,
            'baseUnit' => $l->base_unit,
            'receivedQuantity' => $l->received_quantity,
            'conversionFactor' => $l->conversion_factor,
            'baseQuantity' => $l->base_quantity,
            'unitCost' => $l->unit_cost,
            'stockMovementId' => $l->stock_movement_id ? (int) $l->stock_movement_id : null,
        ], $lines);
    }

    /**
     * Route middleware already gates finance.purchases.receive for every
     * mutating action reachable here, so allowedActions only needs to
     * reflect draft/posted state, not permission — a viewer with only
     * finance.purchases.view never reaches store/update/post at all.
     */
    private function actions(object $row): array
    {
        return $row->status === 'draft' ? ['edit', 'post'] : [];
    }
}
