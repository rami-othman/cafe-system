<?php

namespace App\Domain\Purchasing;

use App\Domain\Inventory\InventoryPostingService;
use App\Services\OperationalAuditService;
use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\InventoryDecimal;
use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Goods Receipt — the sole owner of "stock moved because of a purchase".
 *
 * Accounting boundary (see docs/purchasing/PURCHASING_IMPLEMENTATION_PLAN.md
 * Phase 2): a Supplier Invoice owns 100% of the AP liability and its one
 * journal entry (SupplierInvoiceService, unchanged by this class). A Goods
 * Receipt owns 100% of the physical stock/WAC effect and posts ZERO journal
 * entries — it calls InventoryPostingService::post(type:'stock_in') exactly
 * the way the existing manual stock_in screen already does, and
 * InventoryAccountingMapper already, intentionally, treats stock_in as
 * NOT_APPLICABLE for GL posting. This class must never call
 * AccountingPostingService or JournalEntryService directly.
 *
 * Phase 2 safe restriction (no GRNI yet): receiving requires the underlying
 * Supplier Invoice to already be posted (status posted|partially_paid|paid).
 * Goods received before any invoice exists is explicitly out of scope until
 * a GRNI accrual account/flow is built (Phase 4 of the plan).
 */
final class PurchaseReceivingService
{
    private const RECEIVABLE_INVOICE_STATUSES = ['posted', 'partially_paid', 'paid'];

    public function __construct(
        private readonly InventoryPostingService $posting,
        private readonly OperationalAuditService $audit,
    ) {}

    public function create(Request $request, int $tenantId, int $invoiceId, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'] ?? null;
        $fingerprint = $key ? IdempotencyFingerprint::from($data) : null;
        if ($key && ($existing = $this->byKey($tenantId, $key))) {
            $this->assertFingerprint($existing, $fingerprint);

            return $this->find($tenantId, (int) $existing->id);
        }

        return DB::transaction(function () use ($request, $tenantId, $invoiceId, $data, $actorId, $key, $fingerprint): object {
            if ($key && ($existing = $this->byKey($tenantId, $key, true))) {
                $this->assertFingerprint($existing, $fingerprint);

                return $this->find($tenantId, (int) $existing->id);
            }

            $invoice = $this->receivableInvoice($tenantId, $invoiceId);
            FinancialActor::assertBranchAccess($actorId, $tenantId, $invoice->branch_id ? (int) $invoice->branch_id : null);

            $rows = $this->buildLines($tenantId, $invoiceId, $data['lines'] ?? []);

            $id = (int) DB::table('purchase_receipts')->insertGetId([
                'tenant_id' => $tenantId,
                'branch_id' => $invoice->branch_id,
                'supplier_invoice_id' => $invoiceId,
                'receipt_number' => $this->nextReceiptNumber($tenantId, $data['receiptDate'] ?? now()->toDateString()),
                'receipt_date' => $data['receiptDate'] ?? now()->toDateString(),
                'status' => 'draft',
                'reference' => $data['reference'] ?? null,
                'notes' => $data['notes'] ?? null,
                'idempotency_key' => $key,
                'idempotency_fingerprint' => $fingerprint,
                'created_by' => $actorId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $this->insertLines($tenantId, $id, $rows);
            $receipt = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'purchase_receipt.created', 'purchase_receipt', $id, [], (array) $receipt, $invoice->branch_id ? (int) $invoice->branch_id : null, $actorId);

            return $receipt;
        });
    }

    public function update(Request $request, int $tenantId, int $id, array $data, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $data, $actorId): object {
            $before = $this->row($tenantId, $id, true);
            if ($before->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'Only a draft goods receipt can be edited.']);
            }
            FinancialActor::assertBranchAccess($actorId, $tenantId, $before->branch_id ? (int) $before->branch_id : null);

            $rows = $this->buildLines($tenantId, (int) $before->supplier_invoice_id, $data['lines'] ?? [], (int) $id);

            DB::table('purchase_receipts')->where('tenant_id', $tenantId)->where('id', $id)->update([
                'receipt_date' => $data['receiptDate'] ?? $before->receipt_date,
                'reference' => array_key_exists('reference', $data) ? $data['reference'] : $before->reference,
                'notes' => array_key_exists('notes', $data) ? $data['notes'] : $before->notes,
                'updated_at' => now(),
            ]);
            DB::table('purchase_receipt_lines')->where('tenant_id', $tenantId)->where('purchase_receipt_id', $id)->delete();
            $this->insertLines($tenantId, $id, $rows);
            $receipt = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'purchase_receipt.updated', 'purchase_receipt', $id, (array) $before, (array) $receipt, $before->branch_id ? (int) $before->branch_id : null, $actorId);

            return $receipt;
        });
    }

    /**
     * The one and only place a Goods Receipt touches physical inventory.
     * Every line calls InventoryPostingService::post(type:'stock_in') inside
     * this single transaction, so a partial failure never leaves a posted
     * receipt without stock or stock without a posted receipt (docs §16).
     */
    public function post(Request $request, int $tenantId, int $id, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'];
        $fingerprint = IdempotencyFingerprint::from($data);

        return DB::transaction(function () use ($request, $tenantId, $id, $actorId, $key, $fingerprint): object {
            $used = DB::table('purchase_receipts')->where('tenant_id', $tenantId)->where('posting_idempotency_key', $key)->lockForUpdate()->first();
            if ($used && (int) $used->id !== $id) {
                abort(409, 'This idempotency key was already used to post a different goods receipt.');
            }
            $receipt = $this->row($tenantId, $id, true);
            if ($receipt->status === 'posted' && $receipt->posting_idempotency_key === $key) {
                $this->assertPostingFingerprint($receipt, $fingerprint);

                return $this->find($tenantId, $id);
            }
            if ($receipt->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'Only a draft goods receipt can be posted.']);
            }
            FinancialActor::assertBranchAccess($actorId, $tenantId, $receipt->branch_id ? (int) $receipt->branch_id : null);

            $invoice = $this->receivableInvoice($tenantId, (int) $receipt->supplier_invoice_id);

            $lines = DB::table('purchase_receipt_lines')->where('tenant_id', $tenantId)->where('purchase_receipt_id', $id)->get();
            if ($lines->isEmpty()) {
                throw ValidationException::withMessages(['lines' => 'This goods receipt has no lines to post.']);
            }

            foreach ($lines as $line) {
                // Re-validated here, under a row lock, at the moment of
                // posting: two concurrently-posted receipts against the same
                // invoice line can never both succeed in over-receiving it,
                // even if both passed the (unlocked) check at draft-creation
                // time.
                $invoiceLine = DB::table('supplier_invoice_lines')
                    ->where('tenant_id', $tenantId)->where('id', $line->supplier_invoice_line_id)->lockForUpdate()->first();
                if (! $invoiceLine) {
                    throw ValidationException::withMessages(['lines' => 'The referenced purchase invoice line no longer exists.']);
                }
                $remaining = InventoryDecimal::units($invoiceLine->base_quantity) - InventoryDecimal::units($invoiceLine->received_quantity);
                $thisBase = InventoryDecimal::units($line->base_quantity);
                if ($thisBase <= 0) {
                    throw ValidationException::withMessages(['lines' => 'A goods receipt line must have a positive quantity.']);
                }
                if ($thisBase > $remaining) {
                    throw ValidationException::withMessages(['lines' => 'The received quantity exceeds the remaining quantity on the purchase invoice line.']);
                }

                $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $line->inventory_item_id)->first();
                $movement = $this->posting->post($request, $tenantId, [
                    'warehouseId' => $line->warehouse_id,
                    // The movement's branch is always the destination
                    // warehouse's own branch (InventoryPostingService
                    // defaults this internally) — never the invoice
                    // header's branch, which may legitimately differ (e.g.
                    // an invoice raised centrally can still receive into a
                    // specific branch's own warehouse).
                    'itemId' => $line->inventory_item_id,
                    'type' => 'stock_in',
                    // Quantity is expressed directly in the item's own base
                    // unit using the frozen base_quantity computed at
                    // receipt-creation time — never re-resolved from
                    // inventory_item_unit_conversions — so a later change to
                    // the item's unit configuration can never rewrite this
                    // historical receipt's stock effect.
                    'quantity' => InventoryDecimal::quantity($thisBase),
                    'unit' => $item->unit,
                    'unitCost' => $line->unit_cost,
                    'referenceType' => 'purchase_receipt_line',
                    'referenceId' => $line->id,
                    'occurredAt' => $receipt->receipt_date,
                    'idempotencyKey' => "purchase-receipt-{$id}-line-{$line->id}",
                ], $actorId);

                DB::table('purchase_receipt_lines')->where('id', $line->id)->update(['stock_movement_id' => $movement->movementId, 'updated_at' => now()]);
                DB::table('supplier_invoice_lines')->where('id', $invoiceLine->id)->update([
                    'received_quantity' => InventoryDecimal::quantity(InventoryDecimal::units($invoiceLine->received_quantity) + $thisBase),
                    'updated_at' => now(),
                ]);
            }

            $this->recomputeReceiptStatus($tenantId, (int) $invoice->id);

            $now = now();
            DB::table('purchase_receipts')->where('tenant_id', $tenantId)->where('id', $id)->update([
                'status' => 'posted',
                'posting_idempotency_key' => $key,
                'posting_idempotency_fingerprint' => $fingerprint,
                'posted_by' => $actorId,
                'posted_at' => $now,
                'updated_at' => $now,
            ]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'purchase_receipt.posted', 'purchase_receipt', $id, (array) $receipt, (array) $result, $receipt->branch_id ? (int) $receipt->branch_id : null, $actorId);

            return $result;
        });
    }

    public function find(int $tenantId, int $id): object
    {
        $receipt = $this->row($tenantId, $id);
        $receipt->lines = $this->lines($tenantId, $id);

        return $receipt;
    }

    /** @return array<int, object> */
    public function lines(int $tenantId, int $receiptId): array
    {
        return DB::table('purchase_receipt_lines as l')
            ->join('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')
            ->join('warehouses as w', 'w.id', '=', 'l.warehouse_id')
            ->leftJoin('branches as b', 'b.id', '=', 'w.branch_id')
            ->where('l.tenant_id', $tenantId)->where('l.purchase_receipt_id', $receiptId)
            ->select('l.*', 'i.name_ar as item_name_ar', 'i.name_en as item_name_en', 'i.unit as base_unit', 'w.name as warehouse_name', 'w.type as warehouse_type', 'b.name as warehouse_branch_name')
            ->orderBy('l.id')->get()->all();
    }

    public function row(int $tenantId, int $id, bool $lock = false): object
    {
        $query = DB::table('purchase_receipts')->where('tenant_id', $tenantId)->where('id', $id);
        if ($lock) {
            $query->lockForUpdate();
        }
        $row = $query->first();
        abort_unless($row, 404, 'Goods receipt not found.');

        return $row;
    }

    /**
     * Compares SUM(base_quantity) vs SUM(received_quantity) across every
     * inventory-type line on the invoice — the same derive-don't-store
     * approach SupplierPaymentService already uses for payment status.
     * Invoices with no inventory lines keep receipt_status = null
     * (not applicable), never a fabricated "not_received" state.
     */
    public function recomputeReceiptStatus(int $tenantId, int $invoiceId): void
    {
        $totals = DB::table('supplier_invoice_lines')
            ->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId)->where('line_type', 'inventory')
            ->selectRaw('COALESCE(SUM(base_quantity), 0) as ordered, COALESCE(SUM(received_quantity), 0) as received')
            ->first();
        $status = null;
        if ($totals && InventoryDecimal::units($totals->ordered) > 0) {
            $ordered = InventoryDecimal::units($totals->ordered);
            $received = InventoryDecimal::units($totals->received);
            $status = $received <= 0 ? 'not_received' : ($received >= $ordered ? 'received' : 'partially_received');
        }
        DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->update(['receipt_status' => $status, 'updated_at' => now()]);
    }

    /**
     * Validates and shapes receipt lines against their invoice lines.
     * Enforces: the invoice line belongs to this invoice/tenant, only
     * line_type='inventory' lines are receivable, quantity is positive, a
     * destination warehouse resolves (line input, else the invoice line's
     * own default), and the requested quantity does not exceed the
     * currently-known remaining quantity (a non-locked, UX-level check —
     * the authoritative, row-locked check happens again in post()).
     */
    private function buildLines(int $tenantId, int $invoiceId, array $lines, ?int $excludeReceiptId = null): array
    {
        if (! is_array($lines) || count($lines) === 0) {
            throw ValidationException::withMessages(['lines' => 'At least one line item is required.']);
        }

        $rows = [];
        foreach ($lines as $input) {
            $invoiceLineId = (int) ($input['supplierInvoiceLineId'] ?? 0);
            $invoiceLine = DB::table('supplier_invoice_lines')
                ->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId)->where('id', $invoiceLineId)->first();
            if (! $invoiceLine) {
                throw ValidationException::withMessages(['lines' => 'Select a valid line from this purchase invoice.']);
            }
            if ($invoiceLine->line_type !== 'inventory') {
                throw ValidationException::withMessages(['lines' => 'Only inventory-type purchase lines can be received.']);
            }

            $quantityUnits = InventoryDecimal::units($input['quantity'] ?? '0', 'lines');
            if ($quantityUnits <= 0) {
                throw ValidationException::withMessages(['lines' => 'The received quantity must be greater than zero.']);
            }
            $factor = InventoryDecimal::factor($invoiceLine->conversion_factor ?? '1.000000');
            $baseQuantity = InventoryDecimal::applyFactor($quantityUnits, $factor);

            $alreadyReceived = InventoryDecimal::units($invoiceLine->received_quantity);
            $orderedBase = InventoryDecimal::units($invoiceLine->base_quantity);
            $reservedByOtherDraftLines = $this->reservedByOtherDrafts($tenantId, $invoiceLine->id, $excludeReceiptId);
            $remaining = $orderedBase - $alreadyReceived - $reservedByOtherDraftLines;
            if ($baseQuantity > $remaining) {
                throw ValidationException::withMessages(['lines' => 'The received quantity exceeds the remaining quantity on the purchase invoice line.']);
            }

            $warehouseId = (int) ($input['warehouseId'] ?? $invoiceLine->warehouse_id ?? 0);
            if ($warehouseId <= 0) {
                throw ValidationException::withMessages(['lines' => 'Select a destination warehouse for this line.']);
            }
            $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $warehouse) {
                throw ValidationException::withMessages(['lines' => 'Select an active warehouse that belongs to this tenant.']);
            }

            // Unit cost per base unit, derived once from the invoice line's
            // own unit_price ÷ conversion_factor using exact decimal
            // arithmetic (no floating point). Discount/tax are intentionally
            // excluded from the inventory cost basis, matching the existing
            // manual stock_in workflow and InventoryPostingService's own
            // unitCost contract (cost per base unit).
            $unitCost = BigDecimal::of($invoiceLine->unit_price)
                ->dividedBy(BigDecimal::of($invoiceLine->conversion_factor ?? '1.000000'), 4, RoundingMode::HALF_UP)
                ->__toString();

            $rows[] = [
                'supplier_invoice_line_id' => $invoiceLine->id,
                'inventory_item_id' => $invoiceLine->inventory_item_id,
                'warehouse_id' => $warehouseId,
                'received_unit' => $invoiceLine->purchase_unit,
                'received_quantity' => InventoryDecimal::quantity($quantityUnits),
                'conversion_factor' => InventoryDecimal::conversionFactor($factor),
                'base_quantity' => InventoryDecimal::quantity($baseQuantity),
                'unit_cost' => $unitCost,
            ];
        }

        return $rows;
    }

    /**
     * Other still-draft receipts against the same invoice line already
     * "claim" part of the remaining quantity even though they have not
     * posted yet — counting them here prevents two drafts from both being
     * created for more than what's left, without needing a row lock (the
     * authoritative, locked check is in post()).
     */
    private function reservedByOtherDrafts(int $tenantId, int $invoiceLineId, ?int $excludeReceiptId): int
    {
        $query = DB::table('purchase_receipt_lines as l')
            ->join('purchase_receipts as r', 'r.id', '=', 'l.purchase_receipt_id')
            ->where('l.tenant_id', $tenantId)->where('l.supplier_invoice_line_id', $invoiceLineId)->where('r.status', 'draft');
        if ($excludeReceiptId !== null) {
            $query->where('r.id', '!=', $excludeReceiptId);
        }

        return $query->get(['l.base_quantity'])->sum(fn (object $l): int => InventoryDecimal::units($l->base_quantity));
    }

    private function insertLines(int $tenantId, int $receiptId, array $rows): void
    {
        $now = now();
        foreach ($rows as $row) {
            DB::table('purchase_receipt_lines')->insert($row + ['tenant_id' => $tenantId, 'purchase_receipt_id' => $receiptId, 'created_at' => $now, 'updated_at' => $now]);
        }
    }

    /**
     * Phase 2's safe restriction: no GRNI yet, so a Goods Receipt may only
     * be created/posted against an invoice that is already financially
     * posted. See docs/purchasing/PURCHASING_IMPLEMENTATION_PLAN.md
     * "Inventory Receiving — Explicit Decision (the GRNI question)".
     */
    private function receivableInvoice(int $tenantId, int $invoiceId): object
    {
        $invoice = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->whereNull('deleted_at')->first();
        abort_unless($invoice, 404, 'Supplier invoice not found.');
        if (! in_array($invoice->status, self::RECEIVABLE_INVOICE_STATUSES, true)) {
            throw ValidationException::withMessages(['supplierInvoiceId' => 'لا يمكن ترحيل استلام المخزون قبل ترحيل فاتورة الشراء.']);
        }

        return $invoice;
    }

    private function byKey(int $tenantId, string $key, bool $lock = false): ?object
    {
        $query = DB::table('purchase_receipts')->where('tenant_id', $tenantId)->where('idempotency_key', $key);
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    private function assertFingerprint(object $receipt, ?string $fingerprint): void
    {
        if (! $receipt->idempotency_fingerprint || ! $fingerprint || ! hash_equals($receipt->idempotency_fingerprint, $fingerprint)) {
            abort(409, 'This idempotency key was already used for a different goods receipt request.');
        }
    }

    private function assertPostingFingerprint(object $receipt, string $fingerprint): void
    {
        if (! $receipt->posting_idempotency_fingerprint || ! hash_equals($receipt->posting_idempotency_fingerprint, $fingerprint)) {
            abort(409, 'This idempotency key was already used for a different posting request.');
        }
    }

    private function nextReceiptNumber(int $tenantId, string $receiptDate): string
    {
        $year = substr($receiptDate, 0, 4) ?: now()->format('Y');
        $prefix = "GRN-{$year}-";
        $last = DB::table('purchase_receipts')->where('tenant_id', $tenantId)->where('receipt_number', 'like', "{$prefix}%")
            ->lockForUpdate()->orderByDesc('id')->value('receipt_number');
        $number = $last && preg_match('/(\d+)$/', $last, $match) ? ((int) $match[1] + 1) : 1;

        return $prefix.str_pad((string) $number, 6, '0', STR_PAD_LEFT);
    }
}
