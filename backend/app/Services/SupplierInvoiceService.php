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
            [$subtotal, $tax] = $built !== null ? $this->totalsFromLines($built) : $this->money($data);

            $id = (int) DB::table('supplier_invoices')->insertGetId($this->draftPayload($data, $debitAccountId, $subtotal, $tax) + [
                'tenant_id' => $tenantId,
                'internal_reference' => $this->nextReference($tenantId),
                'status' => 'draft',
                'idempotency_key' => $key,
                'idempotency_fingerprint' => $fingerprint,
                'created_by' => $actorId,
                'updated_by' => $actorId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            if ($built !== null) {
                $this->replaceLines($tenantId, $id, $built['rows']);
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
            [$subtotal, $tax] = $built !== null ? $this->totalsFromLines($built) : $this->money($data);

            DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $id)
                ->update($this->draftPayload($data, $debitAccountId, $subtotal, $tax) + ['updated_by' => $actorId, 'updated_at' => now()]);
            if ($built !== null) {
                $this->replaceLines($tenantId, $id, $built['rows']);
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
                abort(409, 'This idempotency key was already used to post a different supplier invoice.');
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
            $journalId = $this->posting->postSupplierInvoice($request, $tenantId, [
                'branchId' => $invoice->branch_id,
                'sourceId' => $invoice->id,
                'sourceEvent' => 'SUPPLIER_INVOICE_POSTED',
                'entryDate' => $invoice->invoice_date,
                'description' => "Supplier Invoice {$invoice->internal_reference} — {$supplier->name}",
                'lines' => [
                    ['accountCode' => $debitAccount->code, 'debit' => Money::decimal($total), 'credit' => '0.00'],
                    ['accountCode' => '2000', 'debit' => '0.00', 'credit' => Money::decimal($total)],
                ],
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
            abort(409, 'This idempotency key was already used for a different supplier invoice request.');
        }
    }

    private function assertPostingFingerprint(object $invoice, string $fingerprint): void
    {
        if (! $invoice->posting_idempotency_fingerprint || ! hash_equals($invoice->posting_idempotency_fingerprint, $fingerprint)) {
            abort(409, 'This idempotency key was already used for a different posting request.');
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
        $lineNumber = 0;
        foreach ($lines as $line) {
            $lineNumber++;
            $quantityUnits = InventoryDecimal::units($line['quantity'] ?? '1', 'lines');
            if ($quantityUnits <= 0) {
                throw ValidationException::withMessages(['lines' => 'Line quantity must be greater than zero.']);
            }
            $unitPriceUnits = InventoryDecimal::cost($line['unitPrice'] ?? '0', 'lines');
            if ($unitPriceUnits <= 0) {
                throw ValidationException::withMessages(['lines' => 'Line unit price must be greater than zero.']);
            }
            $grossCents = Money::cents(InventoryDecimal::totalCost($quantityUnits, $unitPriceUnits), 'lines');
            $discountCents = Money::cents($line['discountAmount'] ?? '0', 'lines');
            $lineTaxCents = Money::cents($line['taxAmount'] ?? '0', 'lines');
            if ($discountCents < 0 || $lineTaxCents < 0) {
                throw ValidationException::withMessages(['lines' => 'Discount and tax amounts cannot be negative.']);
            }
            $netCents = $grossCents - $discountCents;
            if ($netCents < 0) {
                throw ValidationException::withMessages(['lines' => 'Discount cannot exceed the line amount.']);
            }

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
                'discount_amount' => Money::decimal($discountCents),
                'tax_amount' => Money::decimal($lineTaxCents),
                'line_total' => Money::decimal($netCents + $lineTaxCents),
                'warehouse_id' => $warehouseId,
                'received_quantity' => '0.000',
            ];
            $subtotalCents += $netCents;
            $taxCents += $lineTaxCents;
        }

        return ['lineType' => $lineType, 'subtotalCents' => $subtotalCents, 'taxCents' => $taxCents, 'rows' => $rows];
    }

    private function totalsFromLines(array $built): array
    {
        if ($built['subtotalCents'] <= 0) {
            throw ValidationException::withMessages(['lines' => 'The invoice subtotal must be greater than zero.']);
        }

        return [$built['subtotalCents'], $built['taxCents']];
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

    private function draftPayload(array $data, int $debitAccountId, int $subtotal, int $tax): array
    {
        return [
            'branch_id' => $data['branchId'] ?? null,
            'supplier_id' => (int) $data['supplierId'],
            'invoice_number' => $data['invoiceNumber'],
            'invoice_date' => $data['invoiceDate'],
            'due_date' => $data['dueDate'],
            'invoice_type' => $data['invoiceType'],
            'invoice_type_id' => $data['invoiceTypeId'],
            'expense_category_id' => $data['invoiceType'] === 'expense' ? (int) $data['expenseCategoryId'] : null,
            'debit_account_id' => $debitAccountId,
            'subtotal' => Money::decimal($subtotal),
            'tax_amount' => Money::decimal($tax),
            'total_amount' => Money::decimal($subtotal + $tax),
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
            if (! $account) throw ValidationException::withMessages(['invoiceTypeId' => 'A non-financial invoice requires the active Inventory Asset system account.']);
            return (int) $account->id;
        }

        throw ValidationException::withMessages(['invoiceType' => 'Invoice type must be expense, inventory, or other.']);
    }

    private function withResolvedType(int $tenantId, array $data): array
    {
        $query = DB::table('invoice_types as t')->join('invoice_groups as g', 'g.id', '=', 't.invoice_group_id')
            ->where('t.tenant_id', $tenantId)->where('g.tenant_id', $tenantId)->where('t.is_active', true)->where('g.is_active', true);
        if (! empty($data['invoiceTypeId'])) $query->where('t.id', (int) $data['invoiceTypeId']);
        else $query->where('t.code', $data['invoiceType'] ?? '');
        $type = $query->select('t.*', 'g.is_active as group_is_active')->first();
        if (! $type) throw ValidationException::withMessages(['invoiceTypeId' => 'Select an active configured invoice type.']);
        return array_merge($data, ['invoiceTypeId' => (int) $type->id, 'invoiceType' => $type->posting_behavior]);
    }

    private function typeForInvoice(int $tenantId, object $invoice): object
    {
        $type = DB::table('invoice_types as t')->join('invoice_groups as g', 'g.id', '=', 't.invoice_group_id')
            ->where('t.tenant_id', $tenantId)->where('t.id', $invoice->invoice_type_id)
            ->select('t.*', 'g.is_active as group_is_active')->lockForUpdate()->first();
        if (! $type) throw ValidationException::withMessages(['invoiceTypeId' => 'This invoice type no longer exists.']);
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
        $last = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->lockForUpdate()->orderByDesc('id')->value('internal_reference');
        $number = $last && preg_match('/(\d+)$/', $last, $match) ? ((int) $match[1] + 1) : 1;

        return 'AP-'.str_pad((string) $number, 6, '0', STR_PAD_LEFT);
    }
}
