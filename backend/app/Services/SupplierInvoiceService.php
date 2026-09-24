<?php

namespace App\Services;

use App\Domain\Inventory\UnitConversionResolver;
use App\Support\FinancialActor;
use App\Support\IdempotencyFingerprint;
use App\Support\InventoryDecimal;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * A Supplier Invoice is the Accounts Payable business record — it is not the
 * journal entry itself (mirrors ExpenseService's Phase 3 principle). Posting
 * only ever debits the invoice's own frozen debit account and credits the
 * tenant's Accounts Payable account (2000); it never creates a stock
 * movement or inventory quantity, even for invoiceType "inventory" — that is
 * a Goods Receipt's job, and no such workflow exists yet (see docs §10/§40).
 *
 * Purchasing Phase 1 adds optional line items (`supplier_invoice_lines`),
 * subordinate to this same header — never a second AP/Purchase Invoice
 * table. When lines are present, the header's subtotal/tax/total are always
 * server-derived from them (never trusted from the client); when absent,
 * behavior is byte-for-byte identical to the pre-Purchasing header-only
 * path. Posting still emits exactly one journal entry from the header's own
 * resolved debit account — a line's `line_type` only has to agree with that
 * one resolved account family (see assertLinesMatchInvoiceType()); mixing
 * line types that would require more than one debit account per invoice is
 * explicitly deferred to a later phase.
 */
class SupplierInvoiceService
{
    private const LINE_TYPES = ['inventory', 'expense', 'asset', 'other'];

    public function __construct(
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
        private readonly UnitConversionResolver $unitConversion,
        private readonly PosNumberGenerator $numbers,
    ) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'] ?? null;
        $fingerprint = $key ? IdempotencyFingerprint::from($data) : null;
        if ($key && ($existing = $this->byKey($tenantId, $key))) {
            $this->assertFingerprint($existing, $fingerprint);

            return $existing;
        }

        return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $key, $fingerprint): object {
            if ($key && ($existing = $this->byKey($tenantId, $key, true))) {
                $this->assertFingerprint($existing, $fingerprint);

                return $existing;
            }
            $data = $this->withResolvedType($tenantId, $data);
            $this->assertSupplierAndBranch($tenantId, $data, $actorId);
            $debitAccountId = $this->resolveDebitAccount($tenantId, $data);
            $built = $this->buildLines($tenantId, $data);
            if ($built !== null) {
                $this->assertLinesMatchInvoiceType($tenantId, $built['lineType'], $data['invoiceType'], $debitAccountId);
            }
            $totals = $this->resolveTotals($tenantId, $data, $built);

            $supplierCode = (string) DB::table('suppliers')->where('tenant_id', $tenantId)
                ->where('id', $data['supplierId'])->value('supplier_number');

            $id = (int) DB::table('supplier_invoices')->insertGetId($this->draftPayload($data, $debitAccountId, $totals) + [
                'tenant_id' => $tenantId,
                'internal_reference' => $this->nextReference($tenantId),
                'supplier_internal_reference' => $this->numbers->nextSupplierInvoiceNumber($tenantId, (int) $data['supplierId'], $supplierCode),
                'status' => 'draft',
                'idempotency_key' => $key,
                'idempotency_fingerprint' => $fingerprint,
                'created_by' => $actorId,
                'updated_by' => $actorId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            if ($built !== null) {
                $this->replaceLines($tenantId, $id, $totals['rows']);
                $this->replaceCharges($tenantId, $id, $totals['chargeRows']);
            }
            $invoice = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_invoice.created', 'supplier_invoice', $id, [], (array) $invoice, $invoice->branch_id, $actorId);

            return $invoice;
        });
    }

    public function update(Request $request, int $tenantId, int $id, array $data, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $data, $actorId): object {
            $before = $this->find($tenantId, $id, true);
            $this->assertBranch($actorId, $tenantId, $before->branch_id);
            if ($before->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'Only draft supplier invoices can be edited.']);
            }
            if ((int) $before->supplier_id !== (int) $data['supplierId']) {
                throw ValidationException::withMessages(['supplierId' => 'A saved invoice cannot change supplier. Create a new draft for the other supplier.']);
            }
            $data = $this->withResolvedType($tenantId, $data);
            $this->assertSupplierAndBranch($tenantId, $data, $actorId);
            $debitAccountId = $this->resolveDebitAccount($tenantId, $data);

            $built = $this->buildLines($tenantId, $data);
            if ($built === null && $this->lineCount($tenantId, $id) > 0) {
                // Once an invoice has real lines, a PATCH can never silently
                // change its total without also resending the lines that
                // total is derived from — that would either strand the
                // header total out of sync with its own lines, or silently
                // discard a header subtotal the client thought was applied.
                throw ValidationException::withMessages(['lines' => 'This invoice has line items; resend the full lines array to update it.']);
            }
            if ($built !== null) {
                $this->assertLinesMatchInvoiceType($tenantId, $built['lineType'], $data['invoiceType'], $debitAccountId);
            }
            $totals = $this->resolveTotals($tenantId, $data, $built);

            DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)
                ->update($this->draftPayload($data, $debitAccountId, $totals) + ['updated_by' => $actorId, 'updated_at' => now()]);
            if ($built !== null) {
                $this->replaceLines($tenantId, $id, $totals['rows']);
                $this->replaceCharges($tenantId, $id, $totals['chargeRows']);
            }
            $invoice = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_invoice.updated', 'supplier_invoice', $id, (array) $before, (array) $invoice, $invoice->branch_id, $actorId);

            return $invoice;
        });
    }

    /** @return array<int, object> */
    public function lines(int $tenantId, int $invoiceId): array
    {
        return DB::table('supplier_invoice_lines as l')
            ->leftJoin('inventory_items as i', 'i.id', '=', 'l.inventory_item_id')
            ->where('l.tenant_id', $tenantId)->where('l.supplier_invoice_id', $invoiceId)
            ->orderBy('l.line_number')
            ->select('l.*', 'i.name as inventory_item_name', 'i.unit as inventory_item_base_unit')
            ->get()->all();
    }

    public function post(Request $request, int $tenantId, int $id, array $data, ?int $actorId): object
    {
        $key = $data['idempotencyKey'];
        $fingerprint = IdempotencyFingerprint::from($data);

        return DB::transaction(function () use ($request, $tenantId, $id, $actorId, $key, $fingerprint): object {
            $used = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('posting_idempotency_key', $key)->lockForUpdate()->first();
            if ($used && (int) $used->id !== $id) {
                abort(409, 'تم استخدام مفتاح العملية هذا مسبقًا لترحيل فاتورة مورد مختلفة.');
            }
            $invoice = $this->find($tenantId, $id, true);
            $this->assertBranch($actorId, $tenantId, $invoice->branch_id);
            if ($invoice->status === 'posted' && $invoice->posting_idempotency_key === $key) {
                $this->assertPostingFingerprint($invoice, $fingerprint);

                return $invoice;
            }
            if ($invoice->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'Only a draft supplier invoice can be posted.']);
            }
            $type = $this->typeForInvoice($tenantId, $invoice);
            if (! $type->is_active || ! $type->group_is_active || ! $type->is_postable || $type->posting_behavior === 'none') {
                throw ValidationException::withMessages(['invoiceTypeId' => 'This invoice type is non-financial and cannot be posted.']);
            }

            $debitAccount = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $invoice->debit_account_id)->where('is_active', true)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $debitAccount) {
                throw ValidationException::withMessages(['debitAccountId' => 'The invoice debit account must remain active before posting.']);
            }
            $supplier = DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $invoice->supplier_id)->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $supplier) {
                throw ValidationException::withMessages(['supplierId' => 'The supplier must remain active before posting.']);
            }

            $total = Money::cents($invoice->total_amount);
            $journalLines = $this->postingLines($tenantId, $invoice, $debitAccount, $total);
            $journalId = $this->posting->postSupplierInvoice($request, $tenantId, [
                'branchId' => $invoice->branch_id,
                'sourceId' => $invoice->id,
                'sourceEvent' => 'SUPPLIER_INVOICE_POSTED',
                'entryDate' => $invoice->invoice_date,
                'description' => "Supplier Invoice {$invoice->internal_reference} — {$supplier->name}",
                'lines' => $journalLines,
            ], $actorId);

            $now = now();
            DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)->update([
                'status' => 'posted',
                'journal_entry_id' => $journalId,
                'posting_idempotency_key' => $key,
                'posting_idempotency_fingerprint' => $fingerprint,
                'posted_by' => $actorId,
                'posted_at' => $now,
                'updated_at' => $now,
            ]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_invoice.posted', 'supplier_invoice', $id, (array) $invoice, (array) $result, $result->branch_id, $actorId);

            return $result;
        });
    }

    /**
     * One debit line for the invoice's own resolved account (its lines' net
     * + their tax, plus any capitalized charge's amount + tax — capitalized
     * charges roll into the exact same inventory/expense/asset bucket the
     * lines already post to), one more debit line per distinct account used
     * by a standalone-expense charge, and a single AP credit for the grand
     * total. Charge tax is folded into whichever account absorbs that
     * charge's principal — this mirrors how line tax has always been folded
     * into the invoice's one account rather than a separate recoverable-tax
     * account, so a landed-cost charge's tax does not silently disappear.
     */
    private function postingLines(int $tenantId, object $invoice, object $debitAccount, int $total): array
    {
        $linesTaxCents = Money::cents((string) DB::table('supplier_invoice_lines')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoice->id)->sum('tax_amount'));
        $charges = DB::table('supplier_invoice_charges as c')
            ->join('expense_categories as e', 'e.id', '=', 'c.expense_category_id')
            ->join('financial_accounts as a', 'a.id', '=', 'e.financial_account_id')
            ->where('c.tenant_id', $tenantId)->where('c.supplier_invoice_id', $invoice->id)->where('c.treatment', 'expense')
            ->select('a.code', 'c.amount', 'c.tax_amount')->get();
        $capitalized = DB::table('supplier_invoice_charges')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoice->id)->where('treatment', 'capitalize')
            ->selectRaw('COALESCE(SUM(amount), 0) as amount, COALESCE(SUM(tax_amount), 0) as tax_amount')->first();

        $mainAccountCents = Money::cents($invoice->subtotal) + $linesTaxCents + Money::cents((string) $capitalized->amount) + Money::cents((string) $capitalized->tax_amount);
        $expenseTotalsByCode = [];
        foreach ($charges as $charge) {
            $expenseTotalsByCode[$charge->code] = ($expenseTotalsByCode[$charge->code] ?? 0) + Money::cents($charge->amount) + Money::cents($charge->tax_amount);
        }

        $lines = [['accountCode' => $debitAccount->code, 'debit' => Money::decimal($mainAccountCents), 'credit' => '0.00']];
        foreach ($expenseTotalsByCode as $code => $cents) {
            $lines[] = ['accountCode' => $code, 'debit' => Money::decimal($cents), 'credit' => '0.00'];
        }
        $lines[] = ['accountCode' => '2000', 'debit' => '0.00', 'credit' => Money::decimal($total)];

        return $lines;
    }

    public function reverse(Request $request, int $tenantId, int $id, ?int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId): object {
            $invoice = $this->find($tenantId, $id, true);
            $this->assertBranch($actorId, $tenantId, $invoice->branch_id);
            if ($invoice->status !== 'posted' || ! $invoice->journal_entry_id) {
                throw ValidationException::withMessages(['status' => 'Only a posted, unpaid supplier invoice can be reversed.']);
            }
            $hasAllocations = DB::table('payment_allocations')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $id)->exists();
            if ($hasAllocations) {
                throw ValidationException::withMessages(['status' => 'This invoice already has payments allocated to it; reverse those payments first.']);
            }
            if (DB::table('purchase_receipts')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $id)->where('status', 'posted')->exists()) {
                throw ValidationException::withMessages(['status' => 'Received inventory must be reversed before cancelling this purchase.']);
            }

            $reversal = $this->entries->reverse($request, $tenantId, (int) $invoice->journal_entry_id, $actorId);
            DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)->update(['status' => 'cancelled', 'reversal_journal_entry_id' => $reversal, 'updated_at' => now()]);
            $result = $this->find($tenantId, $id);
            $this->audit->record($request, $tenantId, 'supplier_invoice.reversed', 'supplier_invoice', $id, (array) $invoice, (array) $result, $result->branch_id, $actorId);

            return $result;
        });
    }

    public function find(int $tenantId, int $id, bool $lock = false): object
    {
        $query = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at');
        if ($lock) {
            $query->lockForUpdate();
        }
        $row = $query->first();
        abort_unless($row, 404, 'Supplier invoice not found.');

        return $row;
    }

    private function byKey(int $tenantId, string $key, bool $lock = false): ?object
    {
        $query = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('idempotency_key', $key)->whereNull('deleted_at');
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    private function assertFingerprint(object $invoice, string $fingerprint): void
    {
        if (! $invoice->idempotency_fingerprint || ! hash_equals($invoice->idempotency_fingerprint, $fingerprint)) {
            abort(409, 'تم استخدام مفتاح العملية هذا مسبقًا لطلب فاتورة مورد مختلفة.');
        }
    }

    private function assertPostingFingerprint(object $invoice, string $fingerprint): void
    {
        if (! $invoice->posting_idempotency_fingerprint || ! hash_equals($invoice->posting_idempotency_fingerprint, $fingerprint)) {
            abort(409, 'تم استخدام مفتاح العملية هذا مسبقًا لطلب ترحيل مختلف.');
        }
    }

    private function money(array $data): array
    {
        $subtotal = Money::cents($data['subtotal'], 'subtotal');
        $tax = Money::cents($data['taxAmount'] ?? '0', 'taxAmount');
        if ($subtotal <= 0) {
            throw ValidationException::withMessages(['subtotal' => 'Subtotal must be greater than zero.']);
        }

        return [$subtotal, $tax];
    }

    /**
     * Parses and totals `lines[]` into insertable rows. Returns null when the
     * caller did not supply `lines` at all (the legacy header-only path is
     * left completely untouched). Never trusts a client-supplied subtotal or
     * total when lines are present — every cent is recomputed here from
     * quantity × unit price (via InventoryDecimal, the same fixed-point
     * engine Inventory already uses for cost math) minus discount, plus tax
     * (via Money, the same cents engine every other Finance amount uses).
     */
    private function buildLines(int $tenantId, array $data): ?array
    {
        if (! array_key_exists('lines', $data) || $data['lines'] === null) {
            return null;
        }
        $lines = $data['lines'];
        if (! is_array($lines) || count($lines) === 0) {
            throw ValidationException::withMessages(['lines' => 'At least one line item is required.']);
        }

        $distinctTypes = collect($lines)->pluck('lineType')->unique()->values();
        if ($distinctTypes->count() > 1) {
            throw ValidationException::withMessages(['lines' => 'All lines on one purchase invoice must share the same line type in this phase.']);
        }
        $lineType = (string) $distinctTypes->first();
        if (! in_array($lineType, self::LINE_TYPES, true)) {
            throw ValidationException::withMessages(['lines' => 'Unknown line type.']);
        }

        $subtotalCents = 0;
        $taxCents = 0;
        $rows = [];
        $netCentsList = [];
        $lineNumber = 0;
        foreach ($lines as $line) {
            $lineNumber++;
            $quantityUnits = InventoryDecimal::units($line['quantity'] ?? '1', 'lines');
            if ($quantityUnits <= 0) {
                throw ValidationException::withMessages(['lines' => 'Line quantity must be greater than zero.']);
            }
            if (array_key_exists('unitCost', $line) && $line['unitCost'] !== null && trim((string) $line['unitCost']) !== '') {
                $enteredUnitCost = InventoryDecimal::cost($line['unitCost'], 'lines');
                $grossCents = Money::cents(InventoryDecimal::totalCost($quantityUnits, $enteredUnitCost), 'lines');
            } else {
                // Compatibility for older API clients. Modern clients send
                // unitCost and never control the derived gross amount.
                $grossCents = Money::cents($line['lineGrossAmount'] ?? '0', 'lines');
            }
            if ($grossCents <= 0) {
                throw ValidationException::withMessages(['lines' => 'Line total must be greater than zero.']);
            }
            $discountType = $line['discountType'] ?? 'fixed';
            if (! in_array($discountType, ['fixed', 'percentage'], true)) {
                $discountType = 'fixed';
            }
            $discountValue = $line['discountValue'] ?? '0';
            if ($discountType === 'percentage') {
                $percentBasisPoints = Money::cents($discountValue, 'lines');
                if ($percentBasisPoints < 0 || $percentBasisPoints > 10000) {
                    throw ValidationException::withMessages(['lines' => 'Discount percentage must be between 0 and 100.']);
                }
                $discountCents = intdiv($grossCents * $percentBasisPoints + 5000, 10000);
            } else {
                $discountCents = Money::cents($discountValue, 'lines');
                if ($discountCents < 0) {
                    throw ValidationException::withMessages(['lines' => 'Discount amount cannot be negative.']);
                }
            }
            $lineTaxCents = Money::cents($line['taxAmount'] ?? '0', 'lines');
            if ($lineTaxCents < 0) {
                throw ValidationException::withMessages(['lines' => 'Tax amount cannot be negative.']);
            }
            $netCents = $grossCents - $discountCents;
            if ($netCents < 0) {
                throw ValidationException::withMessages(['lines' => 'Discount cannot exceed the line amount.']);
            }
            // Unit cost is derived, never entered — this is what makes the
            // purchase-invoice cost basis (and everything downstream: WAC via
            // the Goods Receipt, which reads unit_price) automatically net of
            // the line discount without a separate reconciliation step.
            $unitPriceUnits = InventoryDecimal::unitCostFromTotal($netCents, $quantityUnits, 'lines');

            $inventoryItemId = null;
            $purchaseUnit = null;
            $conversionFactor = null;
            $baseQuantity = null;
            $warehouseId = null;

            if ($lineType === 'inventory') {
                $inventoryItemId = (int) ($line['inventoryItemId'] ?? 0);
                $item = DB::table('inventory_items')->where('tenant_id', $tenantId)->where('id', $inventoryItemId)->whereNull('deleted_at')->first();
                if (! $item) {
                    throw ValidationException::withMessages(['lines' => 'Select a valid inventory item that belongs to this tenant.']);
                }
                $resolved = $this->unitConversion->resolve($tenantId, $item, InventoryDecimal::quantity($quantityUnits), $line['purchaseUnit'] ?? null);
                $purchaseUnit = $resolved['inputUnit'];
                $conversionFactor = InventoryDecimal::conversionFactor($resolved['factor']);
                $baseQuantity = InventoryDecimal::quantity($resolved['baseQuantity']);
                if (! empty($line['warehouseId'])) {
                    if (! DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $line['warehouseId'])->whereNull('deleted_at')->exists()) {
                        throw ValidationException::withMessages(['lines' => 'Select a warehouse that belongs to this tenant.']);
                    }
                    $warehouseId = (int) $line['warehouseId'];
                }
            } elseif (! empty($line['inventoryItemId']) || ! empty($line['warehouseId'])) {
                throw ValidationException::withMessages(['lines' => 'Inventory item and warehouse selection only apply to inventory-type lines.']);
            }

            $description = trim((string) ($line['description'] ?? ''));
            if ($description === '') {
                throw ValidationException::withMessages(['lines' => 'Every line requires a description.']);
            }

            $rows[] = [
                'line_number' => $lineNumber,
                'line_type' => $lineType,
                'inventory_item_id' => $inventoryItemId,
                'expense_category_id' => null,
                'financial_account_id' => null,
                'description' => $description,
                'purchase_unit' => $purchaseUnit,
                'quantity' => InventoryDecimal::quantity($quantityUnits),
                'conversion_factor' => $conversionFactor,
                'base_quantity' => $baseQuantity,
                'unit_price' => InventoryDecimal::unitCost($unitPriceUnits),
                'line_gross_amount' => Money::decimal($grossCents),
                'discount_type' => $discountType,
                'discount_value' => (string) $discountValue,
                'discount_amount' => Money::decimal($discountCents),
                'tax_amount' => Money::decimal($lineTaxCents),
                'line_total' => Money::decimal($netCents + $lineTaxCents),
                'warehouse_id' => $warehouseId,
                'received_quantity' => '0.000',
                'allocated_discount' => '0.00',
                'allocated_landed_cost' => '0.00',
            ];
            $netCentsList[] = $netCents;
            $subtotalCents += $netCents;
            $taxCents += $lineTaxCents;
        }

        return ['lineType' => $lineType, 'subtotalCents' => $subtotalCents, 'taxCents' => $taxCents, 'rows' => $rows, 'netCentsList' => $netCentsList];
    }

    /**
     * Combines built lines (or the legacy header path), additional charges,
     * and the invoice-level discount into one consistent set of totals and
     * final row data — the single place create()/update() go for "what does
     * this invoice actually add up to".
     */
    private function resolveTotals(int $tenantId, array $data, ?array $built): array
    {
        if ($built === null) {
            [$subtotal, $tax] = $this->money($data);

            return [
                'subtotal' => $subtotal, 'tax' => $tax, 'discountType' => 'fixed', 'discountValue' => null,
                'discountAmount' => 0, 'chargesAmount' => 0, 'rows' => [], 'chargeRows' => [],
            ];
        }

        if ($built['subtotalCents'] <= 0) {
            throw ValidationException::withMessages(['lines' => 'The invoice subtotal must be greater than zero.']);
        }

        $chargesBuilt = $this->buildCharges($tenantId, $data, $built['lineType'] === 'inventory');
        [$discountType, $discountValue, $discountCents] = $this->invoiceDiscount($data, $built['subtotalCents']);
        $rows = $this->allocateAndFinalize($built, $discountCents, $chargesBuilt);

        return [
            'subtotal' => $built['subtotalCents'] - $discountCents,
            'tax' => $built['taxCents'] + $chargesBuilt['taxCents'],
            'discountType' => $discountType,
            'discountValue' => $discountValue,
            'discountAmount' => $discountCents,
            'chargesAmount' => $chargesBuilt['amountCents'],
            'rows' => $rows,
            'chargeRows' => $chargesBuilt['rows'],
        ];
    }

    /**
     * Additional charges (freight, hospitality, ...) attached to a
     * lines-based invoice. A `capitalize` charge is only meaningful when the
     * invoice's own lines are inventory — it layers onto the same inventory
     * cost basis those lines already use (see allocateAndFinalize()); an
     * `expense` charge always posts standalone to its own configured
     * expense-category account and never touches inventory cost, regardless
     * of the invoice's line type.
     */
    private function buildCharges(int $tenantId, array $data, bool $allowCapitalize): array
    {
        $charges = $data['charges'] ?? [];
        if (! is_array($charges) || count($charges) === 0) {
            return ['rows' => [], 'capitalizableCents' => 0, 'expenseTotalsByAccount' => [], 'amountCents' => 0, 'taxCents' => 0];
        }

        $rows = [];
        $capitalizableCents = 0;
        $expenseTotalsByAccount = [];
        $amountCents = 0;
        $taxCents = 0;
        $chargeNumber = 0;
        foreach ($charges as $charge) {
            $chargeNumber++;
            $description = trim((string) ($charge['description'] ?? ''));
            if ($description === '') {
                throw ValidationException::withMessages(['charges' => 'Every additional charge requires a description.']);
            }
            $treatment = $charge['treatment'] ?? 'expense';
            if (! in_array($treatment, ['capitalize', 'expense'], true)) {
                throw ValidationException::withMessages(['charges' => 'Unknown charge treatment.']);
            }
            if ($treatment === 'capitalize' && ! $allowCapitalize) {
                throw ValidationException::withMessages(['charges' => 'Only an inventory purchase invoice can capitalize an additional charge into inventory cost.']);
            }
            $chargeCents = Money::cents($charge['amount'] ?? '0', 'charges');
            if ($chargeCents <= 0) {
                throw ValidationException::withMessages(['charges' => 'Charge amount must be greater than zero.']);
            }
            $chargeTaxCents = Money::cents($charge['taxAmount'] ?? '0', 'charges');
            if ($chargeTaxCents < 0) {
                throw ValidationException::withMessages(['charges' => 'Charge tax cannot be negative.']);
            }

            $expenseCategoryId = null;
            if ($treatment === 'expense') {
                $expenseCategoryId = (int) ($charge['expenseCategoryId'] ?? 0);
                [$accountId, $accountCode] = $this->resolveExpenseCategoryAccount($tenantId, $expenseCategoryId);
                if (! isset($expenseTotalsByAccount[$accountId])) {
                    $expenseTotalsByAccount[$accountId] = ['code' => $accountCode, 'cents' => 0];
                }
                $expenseTotalsByAccount[$accountId]['cents'] += $chargeCents + $chargeTaxCents;
            } else {
                $capitalizableCents += $chargeCents;
            }

            $rows[] = [
                'charge_number' => $chargeNumber,
                'description' => $description,
                'treatment' => $treatment,
                'expense_category_id' => $expenseCategoryId,
                'amount' => Money::decimal($chargeCents),
                'tax_amount' => Money::decimal($chargeTaxCents),
            ];
            $amountCents += $chargeCents;
            $taxCents += $chargeTaxCents;
        }

        return [
            'rows' => $rows,
            'capitalizableCents' => $capitalizableCents,
            'expenseTotalsByAccount' => $expenseTotalsByAccount,
            'amountCents' => $amountCents,
            'taxCents' => $taxCents,
        ];
    }

    private function resolveExpenseCategoryAccount(int $tenantId, int $categoryId): array
    {
        $category = DB::table('expense_categories as c')->join('financial_accounts as a', 'a.id', '=', 'c.financial_account_id')
            ->where('c.tenant_id', $tenantId)->where('c.id', $categoryId)
            ->where('c.is_active', true)->where('a.is_active', true)->whereNull('c.deleted_at')->whereNull('a.deleted_at')
            ->select('a.id', 'a.code')->first();
        if (! $category) {
            throw ValidationException::withMessages(['charges' => 'Select an active tenant expense category for this charge.']);
        }

        return [(int) $category->id, $category->code];
    }

    /** @return array{0: string, 1: string|null, 2: int} [type, rawValue, resolvedCents] */
    private function invoiceDiscount(array $data, int $subtotalCents): array
    {
        $discountType = $data['discountType'] ?? 'fixed';
        if (! in_array($discountType, ['fixed', 'percentage'], true)) {
            $discountType = 'fixed';
        }
        $discountValue = $data['discountValue'] ?? '0';
        if ($discountType === 'percentage') {
            $percentBasisPoints = Money::cents($discountValue, 'discountValue');
            if ($percentBasisPoints < 0 || $percentBasisPoints > 10000) {
                throw ValidationException::withMessages(['discountValue' => 'Invoice discount percentage must be between 0 and 100.']);
            }
            $discountCents = intdiv($subtotalCents * $percentBasisPoints + 5000, 10000);
        } else {
            $discountCents = Money::cents($discountValue, 'discountValue');
            if ($discountCents < 0) {
                throw ValidationException::withMessages(['discountValue' => 'Invoice discount amount cannot be negative.']);
            }
        }
        if ($discountCents > $subtotalCents) {
            throw ValidationException::withMessages(['discountValue' => 'Invoice discount cannot exceed the items net total.']);
        }

        return [$discountType, (string) $discountValue, $discountCents];
    }

    /**
     * Spreads the invoice-level discount and any capitalizable charges across
     * the eligible (inventory) lines proportionally by each line's own net
     * value — the same "by value" default the landed-cost section of the
     * spec calls for. Discount reduces both the line's commercial total and
     * its cost basis; a capitalized charge only raises the cost basis (never
     * the commercial line_total — that's a separate AP-payable concept). The
     * rounding remainder of each allocation always lands on the last line so
     * the allocated amounts sum to exactly the discount/charge total.
     */
    private function allocateAndFinalize(array $built, int $invoiceDiscountCents, array $chargesBuilt): array
    {
        $rows = $built['rows'];
        $netCentsList = $built['netCentsList'];
        $capitalizableCents = $chargesBuilt['capitalizableCents'];

        if ($built['lineType'] !== 'inventory' || ($invoiceDiscountCents === 0 && $capitalizableCents === 0)) {
            return $rows;
        }

        $totalNet = array_sum($netCentsList);
        $count = count($rows);
        $discountRemaining = $invoiceDiscountCents;
        $landedRemaining = $capitalizableCents;
        foreach ($rows as $i => $row) {
            $isLast = $i === $count - 1;
            $allocatedDiscount = $isLast ? $discountRemaining : $this->proportionalShare($invoiceDiscountCents, $netCentsList[$i], $totalNet);
            $allocatedLanded = $isLast ? $landedRemaining : $this->proportionalShare($capitalizableCents, $netCentsList[$i], $totalNet);
            $discountRemaining -= $allocatedDiscount;
            $landedRemaining -= $allocatedLanded;

            $quantityUnits = InventoryDecimal::units($row['quantity']);
            $adjustedNet = max($netCentsList[$i] - $allocatedDiscount + $allocatedLanded, 0);
            $unitPriceUnits = InventoryDecimal::unitCostFromTotal($adjustedNet, $quantityUnits);
            $lineTaxCents = Money::cents($row['tax_amount']);

            $rows[$i]['unit_price'] = InventoryDecimal::unitCost($unitPriceUnits);
            $rows[$i]['allocated_discount'] = Money::decimal($allocatedDiscount);
            $rows[$i]['allocated_landed_cost'] = Money::decimal($allocatedLanded);
            $rows[$i]['line_total'] = Money::decimal(($netCentsList[$i] - $allocatedDiscount) + $lineTaxCents);
        }

        return $rows;
    }

    /** Round-half-up integer proportional share of $total by $part/$whole — never a float. */
    private function proportionalShare(int $total, int $part, int $whole): int
    {
        if ($whole <= 0 || $total === 0) {
            return 0;
        }

        return intdiv($total * $part * 2 + $whole, $whole * 2);
    }

    private function replaceCharges(int $tenantId, int $invoiceId, array $rows): void
    {
        DB::table('supplier_invoice_charges')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId)->delete();
        $now = now();
        foreach ($rows as $row) {
            DB::table('supplier_invoice_charges')->insert($row + ['tenant_id' => $tenantId, 'supplier_invoice_id' => $invoiceId, 'created_at' => $now, 'updated_at' => $now]);
        }
    }

    /** @return array<int, object> */
    public function charges(int $tenantId, int $invoiceId): array
    {
        return DB::table('supplier_invoice_charges as c')
            ->leftJoin('expense_categories as e', 'e.id', '=', 'c.expense_category_id')
            ->where('c.tenant_id', $tenantId)->where('c.supplier_invoice_id', $invoiceId)
            ->orderBy('c.charge_number')
            ->select('c.*', 'e.name as expense_category_name')
            ->get()->all();
    }

    /**
     * A line's declared type must resolve to the same posting-account family
     * the header's invoice type already resolved to — this is what keeps
     * "one invoice, one debit account, one journal entry" true even with
     * line detail attached. 'asset' and 'other' both currently resolve to
     * the header's 'other' posting_behavior (see resolveDebitAccount()); the
     * account-group check below is what actually tells them apart for the
     * Purchasing UI, without touching resolveDebitAccount() itself.
     */
    private function assertLinesMatchInvoiceType(int $tenantId, string $lineType, string $postingBehavior, int $debitAccountId): void
    {
        $expected = match ($lineType) {
            'inventory' => 'inventory',
            'expense' => 'expense',
            'asset', 'other' => 'other',
            default => throw ValidationException::withMessages(['lines' => 'Unknown line type.']),
        };
        if ($expected !== $postingBehavior) {
            throw ValidationException::withMessages(['invoiceTypeId' => 'The selected invoice type does not match the line type of these lines.']);
        }
        if ($lineType === 'asset' || $lineType === 'other') {
            $isAssetAccount = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $debitAccountId)->where('account_group', 'assets')->exists();
            if ($lineType === 'asset' && ! $isAssetAccount) {
                throw ValidationException::withMessages(['debitAccountId' => 'Asset-type lines require an asset-group account (e.g. Fixed Assets).']);
            }
            if ($lineType === 'other' && $isAssetAccount) {
                throw ValidationException::withMessages(['debitAccountId' => 'Use line type "asset" when the destination account is an asset-group account.']);
            }
        }
    }

    private function replaceLines(int $tenantId, int $invoiceId, array $rows): void
    {
        DB::table('supplier_invoice_lines')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId)->delete();
        $now = now();
        foreach ($rows as $row) {
            DB::table('supplier_invoice_lines')->insert($row + ['tenant_id' => $tenantId, 'supplier_invoice_id' => $invoiceId, 'created_at' => $now, 'updated_at' => $now]);
        }
    }

    private function lineCount(int $tenantId, int $invoiceId): int
    {
        return DB::table('supplier_invoice_lines')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId)->count();
    }

    private function draftPayload(array $data, int $debitAccountId, array $totals): array
    {
        return [
            'branch_id' => $data['branchId'] ?? null,
            'receipt_mode' => $data['receiptMode'] ?? null,
            'supplier_id' => (int) $data['supplierId'],
            // The existing schema uses internal_reference for the generated
            // system PI number and invoice_number for the supplier reference.
            'invoice_number' => $data['supplierInvoiceNumber'] ?? $data['invoiceNumber'] ?? null,
            'invoice_date' => $data['invoiceDate'],
            'due_date' => $data['dueDate'],
            'invoice_type' => $data['invoiceType'],
            'invoice_type_id' => $data['invoiceTypeId'],
            'expense_category_id' => $data['invoiceType'] === 'expense' ? (int) $data['expenseCategoryId'] : null,
            'debit_account_id' => $debitAccountId,
            'subtotal' => Money::decimal($totals['subtotal']),
            'tax_amount' => Money::decimal($totals['tax']),
            'discount_type' => $totals['discountType'],
            'discount_value' => $totals['discountValue'],
            'discount_amount' => Money::decimal($totals['discountAmount']),
            'charges_amount' => Money::decimal($totals['chargesAmount']),
            'total_amount' => Money::decimal($totals['subtotal'] + $totals['tax'] + $totals['chargesAmount']),
            'description' => $data['description'] ?? null,
            'notes' => $data['notes'] ?? null,
            'updated_at' => now(),
        ];
    }

    private function resolveDebitAccount(int $tenantId, array $data): int
    {
        $type = $data['invoiceType'];
        if ($type === 'expense') {
            $category = DB::table('expense_categories as c')->join('financial_accounts as a', 'a.id', '=', 'c.financial_account_id')
                ->where('c.tenant_id', $tenantId)->where('c.id', $data['expenseCategoryId'] ?? null)
                ->where('c.is_active', true)->where('a.is_active', true)->whereNull('c.deleted_at')->whereNull('a.deleted_at')
                ->select('a.id')->first();
            if (! $category) {
                throw ValidationException::withMessages(['expenseCategoryId' => 'Select an active tenant expense category.']);
            }

            return (int) $category->id;
        }

        if ($type === 'inventory') {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1100')->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $account) {
                throw ValidationException::withMessages(['invoiceType' => 'The Inventory Asset account is not active for this tenant.']);
            }

            return (int) $account->id;
        }

        if ($type === 'other') {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $data['debitAccountId'] ?? null)
                ->where('is_active', true)->whereNull('deleted_at')
                ->whereIn('account_group', ['expenses', 'assets', 'cost_of_sales'])
                ->where('code', '!=', '1100')
                ->first();
            if (! $account) {
                throw ValidationException::withMessages(['debitAccountId' => 'Select an active tenant expense, asset, or cost-of-sales account (not Inventory Asset — use invoice type "inventory" for that).']);
            }

            return (int) $account->id;
        }

        if ($type === 'none') {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1100')->where('is_active', true)->whereNull('deleted_at')->first();
            if (! $account) {
                throw ValidationException::withMessages(['invoiceTypeId' => 'A non-financial invoice requires the active Inventory Asset system account.']);
            }

            return (int) $account->id;
        }

        throw ValidationException::withMessages(['invoiceType' => 'Invoice type must be expense, inventory, or other.']);
    }

    private function withResolvedType(int $tenantId, array $data): array
    {
        $query = DB::table('invoice_types as t')->join('invoice_groups as g', 'g.id', '=', 't.invoice_group_id')
            ->where('t.tenant_id', $tenantId)->where('g.tenant_id', $tenantId)->where('t.is_active', true)->where('g.is_active', true);
        if (! empty($data['invoiceTypeId'])) {
            $query->where('t.id', (int) $data['invoiceTypeId']);
        } else {
            $query->where('t.code', $data['invoiceType'] ?? '');
        }
        $type = $query->select('t.*', 'g.is_active as group_is_active')->first();
        if (! $type) {
            throw ValidationException::withMessages(['invoiceTypeId' => 'Select an active configured invoice type.']);
        }

        return array_merge($data, ['invoiceTypeId' => (int) $type->id, 'invoiceType' => $type->posting_behavior]);
    }

    private function typeForInvoice(int $tenantId, object $invoice): object
    {
        $type = DB::table('invoice_types as t')->join('invoice_groups as g', 'g.id', '=', 't.invoice_group_id')
            ->where('t.tenant_id', $tenantId)->where('t.id', $invoice->invoice_type_id)
            ->select('t.*', 'g.is_active as group_is_active')->lockForUpdate()->first();
        if (! $type) {
            throw ValidationException::withMessages(['invoiceTypeId' => 'This invoice type no longer exists.']);
        }

        return $type;
    }

    private function assertSupplierAndBranch(int $tenantId, array $data, ?int $actorId): void
    {
        $supplier = DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $data['supplierId'] ?? null)->where('is_active', true)->whereNull('deleted_at')->exists();
        if (! $supplier) {
            throw ValidationException::withMessages(['supplierId' => 'Select an active tenant supplier.']);
        }
        if (! empty($data['branchId'])) {
            if (! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $data['branchId'])->where('is_active', true)->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(['branchId' => 'The branch does not belong to this tenant.']);
            }
            $this->assertBranch($actorId, $tenantId, (int) $data['branchId']);
        }
        if (isset($data['dueDate'], $data['invoiceDate']) && $data['dueDate'] < $data['invoiceDate']) {
            throw ValidationException::withMessages(['dueDate' => 'Due date cannot be before the invoice date.']);
        }
    }

    private function assertBranch(?int $actorId, int $tenantId, mixed $branchId): void
    {
        FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId ? (int) $branchId : null);
    }

    private function nextReference(int $tenantId): string
    {
        return $this->numbers->nextPurchaseInvoiceNumber($tenantId);
    }
}
