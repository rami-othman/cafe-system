<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SupplierInvoiceService;
use App\Services\SupplierPayableQueryService;
use App\Support\FinancialActor;
use App\Support\FinanceAccess;
use App\Support\InventoryDecimal;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Purchasing Center — a filtered, enriched READ of the existing
 * `supplier_invoices` domain. This controller is read-only and creates no
 * new financial source of truth: every mutation (create/update/post/reverse)
 * still goes through SupplierInvoiceController -> SupplierInvoiceService
 * exactly as before, gated by the pre-existing finance.supplier_invoices.*
 * permissions — those remain the sole authority over what a caller may
 * actually change, which is why `allowedActions` below is computed from
 * them (not from finance.purchases.edit/post) and why this controller
 * defines no store/update/post/reverse method of its own.
 *
 * "Purchase" here means any supplier invoice whose configured invoice type
 * is flagged `is_purchase` (see the 2026_09_12_000002 migration) — which,
 * today, is every postable type (inventory/expense/other) a tenant has
 * configured; a non-financial "test" type is excluded.
 */
class PurchaseController extends Controller
{
    public function __construct(
        private readonly SupplierInvoiceService $invoices,
        private readonly SupplierPayableQueryService $payable,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $q = $this->rows($tenant);
        if (DB::table('users')->where('tenant_id', $tenant)->where('id', $actor)->value('role') !== 'owner') {
            $q->where(fn ($scope) => $scope->whereIn('i.branch_id', FinancialActor::operationalBranchIds($actor, $tenant))->orWhereNull('i.branch_id'));
        }
        foreach (['supplierId' => 'i.supplier_id', 'branchId' => 'i.branch_id'] as $input => $column) {
            if ($request->filled($input)) {
                $q->where($column, $request->input($input));
            }
        }
        if ($request->filled('documentStatus')) {
            $documentStatus = $request->input('documentStatus');
            if (in_array($documentStatus, ['draft', 'cancelled'], true)) {
                $q->where('i.status', $documentStatus);
            } elseif ($documentStatus === 'posted') {
                $q->whereIn('i.status', ['posted', 'partially_paid', 'paid']);
            }
        }
        if ($request->filled('paymentStatus')) {
            $status = match ($request->input('paymentStatus')) {
                'unpaid' => 'posted',
                'partial' => 'partially_paid',
                'paid' => 'paid',
                default => null,
            };
            if ($status !== null) {
                $q->where('i.status', $status);
            }
        }
        if ($request->filled('receiptStatus')) {
            $q->where('i.receipt_status', $request->input('receiptStatus'));
        }
        if ($request->filled('purchaseType')) {
            $q->whereRaw('COALESCE((SELECT sl.line_type FROM supplier_invoice_lines sl WHERE sl.supplier_invoice_id = i.id ORDER BY sl.line_number LIMIT 1), i.invoice_type) = ?', [$request->input('purchaseType')]);
        }
        if ($request->filled('from')) {
            $q->whereDate('i.invoice_date', '>=', $request->input('from'));
        }
        if ($request->filled('to')) {
            $q->whereDate('i.invoice_date', '<=', $request->input('to'));
        }
        if ($request->filled('search')) {
            $term = '%'.$request->input('search').'%';
            $q->where(fn ($scope) => $scope->where('i.internal_reference', 'like', $term)->orWhere('i.invoice_number', 'like', $term)->orWhere('s.name', 'like', $term));
        }

        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);
        $paginator = $q->orderByDesc('i.invoice_date')->orderByDesc('i.id')->paginate($this->perPage($request));

        return response()->json([
            'data' => collect($paginator->items())->map(fn (object $row) => $this->serialize($row) + ['allowedActions' => $this->actions($row, $permissions)])->values(),
            'meta' => $this->meta($paginator),
        ]);
    }

    public function show(Request $request, int $purchase): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $row = $this->rows($tenant)->where('i.id', $purchase)->first();
        abort_unless($row, 404);
        $actor = FinancialActor::id($request, $tenant);
        FinancialActor::assertBranchAccess($actor, $tenant, $row->branch_id ? (int) $row->branch_id : null);

        $lines = $this->invoices->lines($tenant, $purchase);
        $payments = DB::table('payment_allocations as a')
            ->join('supplier_payments as p', 'p.id', '=', 'a.supplier_payment_id')
            ->where('a.tenant_id', $tenant)->where('a.supplier_invoice_id', $purchase)
            ->orderByDesc('p.payment_date')
            ->select('p.id', 'p.payment_number', 'p.payment_date', 'p.status', 'a.amount')
            ->get()->map(fn (object $p) => [
                'paymentId' => (int) $p->id,
                'paymentNumber' => $p->payment_number,
                'paymentDate' => $p->payment_date,
                'status' => $p->status,
                'amount' => Money::decimal(Money::cents($p->amount)),
            ])->values();

        $receipts = DB::table('purchase_receipts as r')
            ->leftJoin('branches as b', 'b.id', '=', 'r.branch_id')
            ->leftJoin('users as u', 'u.id', '=', 'r.created_by')
            ->where('r.tenant_id', $tenant)->where('r.supplier_invoice_id', $purchase)
            ->orderByDesc('r.id')
            ->select('r.id', 'r.receipt_number', 'r.receipt_date', 'r.status', 'b.name as branch_name', 'u.name as created_by_name', DB::raw('(SELECT COUNT(*) FROM purchase_receipt_lines pl WHERE pl.purchase_receipt_id = r.id) as line_count'))
            ->get()->map(fn (object $r) => [
                'id' => (int) $r->id,
                'receiptNumber' => $r->receipt_number,
                'receiptDate' => $r->receipt_date,
                'status' => $r->status,
                'branchName' => $r->branch_name ?? 'المستودع المركزي',
                'createdByName' => $r->created_by_name,
                'lineCount' => (int) $r->line_count,
            ])->values();

        $permissions = array_fill_keys(FinanceAccess::capabilities($request), true);

        return response()->json(['data' => $this->serialize($row)
            + ['lines' => array_map(function (object $l): array {
                $ordered = $l->line_type === 'inventory' ? InventoryDecimal::units($l->base_quantity ?? '0') : null;
                $received = $l->line_type === 'inventory' ? InventoryDecimal::units($l->received_quantity ?? '0') : null;

                return [
                    'id' => (int) $l->id,
                    'lineNumber' => (int) $l->line_number,
                    'lineType' => $l->line_type,
                    'description' => $l->description,
                    'inventoryItemId' => $l->inventory_item_id ? (int) $l->inventory_item_id : null,
                    'inventoryItemName' => $l->inventory_item_name,
                    'purchaseUnit' => $l->purchase_unit,
                    'baseUnit' => $l->inventory_item_base_unit,
                    'quantity' => $l->quantity,
                    'conversionFactor' => $l->conversion_factor,
                    'baseQuantity' => $l->base_quantity,
                    'unitPrice' => $l->unit_price,
                    'discountAmount' => $l->discount_amount,
                    'taxAmount' => $l->tax_amount,
                    'lineTotal' => $l->line_total,
                    'warehouseId' => $l->warehouse_id ? (int) $l->warehouse_id : null,
                    'receivedQuantity' => $l->received_quantity,
                    // remainingQuantity is null for non-inventory lines — there is
                    // nothing to receive against a service/asset line.
                    'remainingQuantity' => $ordered === null ? null : InventoryDecimal::quantity(max(0, $ordered - $received)),
                ];
            }, $lines)]
            + ['receipts' => $receipts]
            + ['payments' => $payments]
            + ['allowedActions' => $this->actions($row, $permissions)]]);
    }

    private function perPage(Request $request): int { return min(max((int) $request->query('perPage', 50), 1), 100); }
    private function meta($paginator): array { return ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]; }

    private function rows(int $tenant)
    {
        return DB::table('supplier_invoices as i')
            ->join('suppliers as s', 's.id', '=', 'i.supplier_id')
            ->join('financial_accounts as a', 'a.id', '=', 'i.debit_account_id')
            ->leftJoin('branches as b', 'b.id', '=', 'i.branch_id')
            ->leftJoin('invoice_types as t', 't.id', '=', 'i.invoice_type_id')
            ->leftJoin('invoice_groups as g', 'g.id', '=', 't.invoice_group_id')
            ->leftJoin('users as u', 'u.id', '=', 'i.created_by')
            ->where('i.tenant_id', $tenant)->whereNull('i.deleted_at')
            ->where(fn ($scope) => $scope->where('t.is_purchase', true)->orWhereNull('t.id'))
            ->select(
                'i.*', 's.name as supplier_name', 's.supplier_number',
                'a.code as debit_account_code', 'a.name_ar as debit_account_name', 'a.account_group as debit_account_group',
                'b.name as branch_name', 'u.name as created_by_name',
                't.name as invoice_type_name', 'g.name as invoice_group_name',
                DB::raw('(SELECT sl.line_type FROM supplier_invoice_lines sl WHERE sl.supplier_invoice_id = i.id ORDER BY sl.line_number LIMIT 1) as line_type'),
            );
    }

    private function actions(object $row, array $permissions): array
    {
        $can = fn (string $permission): bool => isset($permissions[$permission]);
        $actions = [];
        if ($row->status === 'draft' && $can('finance.supplier_invoices.edit')) $actions[] = 'edit';
        if ($row->status === 'draft' && $can('finance.supplier_invoices.post')) $actions[] = 'post';
        if (in_array($row->status, ['posted', 'partially_paid'], true) && $can('finance.supplier_invoices.reverse')) $actions[] = 'reverse';
        // "receive" only when the invoice is financially postable (Phase 2's
        // no-GRNI restriction) and its receipt status isn't already fully
        // received — the client still needs a fresh remaining-quantity check
        // per line, this is a coarse show/hide signal only.
        if ($row->line_type === 'inventory' && in_array($row->status, ['posted', 'partially_paid', 'paid'], true) && $row->receipt_status !== 'received' && $can('finance.purchases.receive')) $actions[] = 'receive';

        return $actions;
    }

    private function serialize(object $row): array
    {
        $remaining = $this->payable->invoiceRemainingCents((int) $row->tenant_id, (int) $row->id);
        $totalCents = Money::cents($row->total_amount);
        $paidCents = in_array($row->status, ['draft', 'cancelled'], true) ? 0 : max(0, $totalCents - $remaining);
        $isOverdue = in_array($row->status, ['posted', 'partially_paid'], true) && $remaining > 0 && $row->due_date < now()->toDateString();
        $purchaseType = $row->line_type ?? $row->invoice_type;

        return [
            'id' => (int) $row->id,
            'internalReference' => $row->internal_reference,
            'invoiceNumber' => $row->invoice_number,
            'supplierId' => (int) $row->supplier_id,
            'supplierName' => $row->supplier_name,
            'supplierNumber' => $row->supplier_number,
            'branchId' => $row->branch_id ? (int) $row->branch_id : null,
            'branchName' => $row->branch_name,
            'invoiceDate' => $row->invoice_date,
            'dueDate' => $row->due_date,
            'purchaseType' => $purchaseType,
            'invoiceTypeId' => $row->invoice_type_id ? (int) $row->invoice_type_id : null,
            'invoiceTypeName' => $row->invoice_type_name,
            'invoiceGroupName' => $row->invoice_group_name,
            'debitAccountId' => (int) $row->debit_account_id,
            'debitAccountCode' => $row->debit_account_code,
            'debitAccountName' => $row->debit_account_name,
            'subtotal' => Money::decimal(Money::cents($row->subtotal)),
            'taxAmount' => Money::decimal(Money::cents($row->tax_amount)),
            'totalAmount' => Money::decimal($totalCents),
            'paidAmount' => Money::decimal($paidCents),
            'remainingAmount' => Money::decimal($remaining),
            // documentStatus: the lifecycle of the document itself.
            // paymentStatus: derived from the very same underlying `status`
            // column — never a second stored value — split out here purely
            // so the Purchasing list can show two columns instead of
            // overloading one, per the Phase 0 status-model decision.
            'documentStatus' => in_array($row->status, ['posted', 'partially_paid', 'paid'], true) ? 'posted' : $row->status,
            'paymentStatus' => match ($row->status) {
                'posted' => 'unpaid',
                'partially_paid' => 'partial',
                'paid' => 'paid',
                default => 'not_applicable',
            },
            // receiptStatus: an entirely independent dimension from both of
            // the above — null/"not_applicable" for non-inventory purchases,
            // else not_received|partially_received|received, maintained by
            // PurchaseReceivingService::recomputeReceiptStatus(). Never
            // conflated with paymentStatus.
            'receiptStatus' => $row->receipt_status ?? ($row->line_type === 'inventory' ? 'not_received' : 'not_applicable'),
            'status' => $row->status,
            'isOverdue' => $isOverdue,
            'description' => $row->description,
            'notes' => $row->notes,
            'createdByName' => $row->created_by_name,
            'journalEntryId' => $row->journal_entry_id ? (int) $row->journal_entry_id : null,
            'reversalJournalEntryId' => $row->reversal_journal_entry_id ? (int) $row->reversal_journal_entry_id : null,
            'postedAt' => $row->posted_at,
            'createdAt' => $row->created_at,
        ];
    }
}
