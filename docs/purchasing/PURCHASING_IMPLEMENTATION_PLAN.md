# Purchasing Implementation Plan

Planning only. Nothing in this document has been built. Read `PURCHASING_FORENSIC_AUDIT.md` first — every recommendation below is anchored to a specific finding in that document. This plan follows the same phase format the repository already uses (`docs/finance/FINANCE_IMPLEMENTATION_PLAN.md`): each phase lists scope, database changes, backend files, endpoints, Flutter changes, permissions, accounting/inventory impact, tests, acceptance criteria, and dependencies.

---

## A. Architecture Options — Evaluated Against This Repository

### Option A — Extend `supplier_invoices` in place (add lines directly on the header table / as a header-owned child)

**Fit**: `supplier_invoices` already has everything a Purchase Invoice's *financial* shell needs — supplier, branch, date, type classification via `invoice_types`, idempotency, posting, reversal, and it already appears correctly in AP aging/statement reports. Adding a **child** `supplier_invoice_lines` table (not new header columns) costs nothing at the header level and is fully backward-compatible: an invoice with zero lines keeps behaving exactly as it does today (single `debit_account_id`/`expense_category_id`, single subtotal).

**Risk**: none structural, if scoped to a child table only. The risk described in the prompt ("Supplier Invoice and Purchase Invoice must not independently post the same AP liability") applies to a *header* duplication, which this option avoids entirely.

### Option B — New `purchases`/`purchase_invoices` domain, linked to `supplier_invoices`

**Fit**: gives Purchasing its own purpose-built header (better UX field names, purchase-specific statuses) without touching the AP table at all.

**Risk (confirmed against this repo's own stated principle, Purchasing Forensic Audit §8)**: this creates a **second header record** for the same financial event — a `purchase_invoices` row and a `supplier_invoices` row would both describe "we owe the supplier $X for this." Any place that only updates one side (a cancelled purchase whose linked supplier invoice isn't also cancelled, a supplier invoice edited directly via `SupplierInvoiceController` bypassing the purchase header) creates permanent drift between two records describing one liability. This is exactly the anti-pattern the task explicitly forbids. Rejected as the header strategy, though its *reporting-friendly read model* idea is worth keeping (see §B below).

### Option C — Full procurement architecture: PO → Goods Receipt → existing Supplier Invoice/AP → existing Supplier Payment

**Fit**: this is the textbook-correct separation of concerns, and it maps cleanly onto the domain-ownership table in the audit (§4): Purchase Order owns commitment (no financial effect), Goods Receipt owns the physical stock event, Supplier Invoice keeps owning AP liability, Supplier Payment keeps owning cash-out. Nothing in this option requires touching or duplicating any existing AP/payment logic — it only adds new, purely additive upstream/parallel documents.

**Risk**: it is the largest option to build in full (a mandatory PO for every purchase is real friction for a café buying milk on a Tuesday), and Phase-1-of-C alone (PO+Receipt+Invoice+Payment, all four new/wired at once) would be too large a first slice.

### Recommended hybrid — Option A for the invoice's own line items, Option C's separation of concerns for receiving, PO deferred

Extend `supplier_invoices` with a **subordinate** `supplier_invoice_lines` table (Option A, applied strictly at the line level, never duplicating the header). Add a **new, independent Goods Receipt domain** (`purchase_receipts`/`purchase_receipt_lines`) that references `supplier_invoice_lines` and is the **only** trigger for `InventoryPostingService::post(type='stock_in', ...)` (Option C's separation, without a mandatory PO). Purchase Orders are deferred to Phase 4 as a genuinely optional upstream document — a receipt can exist against an invoice directly (the common café case) or, later, against a PO line (for a more disciplined procurement flow). No new `purchases`/`purchase_invoices` header table is created at any phase — the "Purchasing Center" list view (§B) is a **read-model query**, not a new source of truth.

This resolves the domain-ownership requirement exactly: `supplier_invoices` still owns 100% of the AP liability and its one journal entry; the new Goods Receipt owns 100% of the physical stock effect and posts **zero** journal entries (preserving `InventoryAccountingMapper`'s existing, tested treatment of `stock_in`); `supplier_payments` is untouched.

### B. The Purchasing Center list — how it avoids a second ledger

"جميع المشتريات" is a **filtered, joined read of `supplier_invoices`**, not a new table. The existing `invoice_groups`/`invoice_types` catalog already supports adding a `code='purchases'` group with types like `purchase_inventory` (`posting_behavior='inventory'`), `purchase_service` (`posting_behavior='expense'`), `purchase_asset` (`posting_behavior='other'`, pointed at account `1500`). A single additive boolean column, `invoice_types.is_purchase`, lets the Purchasing Center query be `WHERE it.is_purchase = true` regardless of tenant-customized naming — this is the entire "no separate purchasing ledger" mechanism: Purchasing invoices already are supplier invoices, tagged for a friendlier UI and a dedicated nav destination, and they already flow into Supplier Aging/Statement, Trial Balance, and the Financial Transactions list with zero extra reporting work.

---

## Purchase Types — How Each Maps to the Existing Schema (no new posting logic needed for the header)

| Purchase type | Invoice-type `posting_behavior` | Debit account | Creates stock? | New code needed |
|---|---|---|---|---|
| Inventory purchase (beans, milk, cups, packaging) | `inventory` | `1100` (fixed, existing) | Yes — via Goods Receipt (Phase 2) | Lines + receipt |
| Service/operating purchase (internet, maintenance, marketing) | `expense` | `expense_categories.financial_account_id` (existing) | No | None — already works today; only needs an `is_purchase`-flagged invoice type so it shows in the Purchasing Center instead of only Expenses-adjacent supplier invoices |
| Asset purchase (espresso machine, fridge, laptop) | `other` | `1500` "Fixed Assets" (already seeded, confirmed in audit §5) | No | None — already representable today; Purchasing UI should default the debit-account picker to `1500` for this invoice type rather than accepting any non-1100 account, to keep asset purchases from accidentally landing in an operating-expense account |
| Mixed (beans + cleaning supplies + delivery in one invoice) | N/A — spans multiple lines with different resolved accounts | Multiple, one per distinct line account | Only inventory-type lines | Requires `SupplierInvoiceService::post()` to build **one debit line per distinct resolved account, summed**, instead of always exactly one — deferred to Phase 2 (see below); **not** supported in Phase 1 |

Mixed-line invoices are explicitly **deferred past Phase 1**: Phase 1 requires every line on one invoice to resolve to the *same* invoice type (and therefore the same debit account), matching today's one-debit-line posting exactly. Phase 2 lifts this restriction once `SupplierInvoiceService::post()` is extended to group lines by resolved account.

---

## Line Model — Reconciled Against Existing Types

```
supplier_invoice_lines
  id, tenant_id, supplier_invoice_id (FK supplier_invoices, cascadeOnDelete), line_number,
  line_type            varchar(20)   -- 'inventory' | 'service' | 'asset', mirrors the resolved
                                          invoice_type's posting_behavior for this line
  inventory_item_id    FK inventory_items, nullable (required if line_type='inventory')
  expense_category_id  FK expense_categories, nullable (required if line_type='service')
  financial_account_id FK financial_accounts, nullable (required if line_type='asset')
  description          string
  purchase_unit         string, nullable      -- only for line_type='inventory'
  quantity              decimal(15,3), nullable
  conversion_factor      decimal(18,6), nullable  -- snapshot from UnitConversionResolver at entry time
  base_quantity          decimal(15,3), nullable  -- quantity converted to the item's base unit
  unit_price             decimal(14,4)
  discount_amount        decimal(14,2) default 0
  tax_amount             decimal(14,2) default 0
  line_total             decimal(14,2)          -- server-recomputed and validated, never trusted from client
  warehouse_id           FK warehouses, nullable  -- required if line_type='inventory'; see warehouse
                                                     placement decision below
  received_quantity      decimal(15,3) default 0  -- cached rollup, updated transactionally by
                                                     PurchaseReceivingService, never edited directly
  timestamps
  unique(supplier_invoice_id, line_number)
```

Column choices are reconciled against confirmed existing conventions, not invented fresh:
- `decimal(15,3)` for quantities matches `stock_movements.quantity_in`/`quantity_out` and `stock_balances.quantity_on_hand` exactly (audit backend evidence).
- `decimal(18,6)` for `conversion_factor` matches `inventory_item_unit_conversions.factor` exactly.
- `decimal(14,2)`/`decimal(14,4)` money/cost columns match `supplier_invoices.subtotal`/`total_amount` (14,2) and `inventory_items.latest_unit_cost`/`last_purchase_cost` (15,4) conventions respectively — `unit_price` uses (14,4) to match the item cost precision rather than the coarser (14,2) invoice-total precision, since a purchase unit price (e.g. per-gram coffee) can need more than 2 decimal places even though the invoice `total_amount` itself stays (14,2).
- `base_quantity`/`conversion_factor` are **snapshotted at entry time**, exactly like `warehouse_transfer_lines.unit_cost` is snapshotted from source WAC at dispatch time — never recomputed later from a possibly-changed conversion row.

### Warehouse placement: **on each line**, not the header, not only the receipt

A café can receive different items from one invoice into different physical locations (e.g., beans to Central Warehouse, cups directly to a branch's Bar Stock) — `stock_movements` itself is already per-row/per-warehouse, and `InventoryPostingService::post()` takes exactly one `warehouseId` per call. Putting warehouse only on the header would force one warehouse per invoice, which is an artificial constraint the underlying posting primitive doesn't have. Putting it only on the receipt (and not the line) would leave the *invoice* unable to express intended destination before receiving happens, which matters for a Purchase Order later (Phase 4) where the destination should be plannable before any receipt exists. Recommendation: **`warehouse_id` lives on `supplier_invoice_lines`** as the default/expected destination, and is **copied (snapshotted) onto `purchase_receipt_lines`** at receiving time (mirroring how `warehouse_transfer_lines` snapshots `unit_cost` from source WAC rather than re-reading it later) — so a receipt can, if the operator corrects it, receive into a different warehouse than originally planned without mutating the invoice line. Phase 1 UI ships a single "apply to all lines" warehouse picker as a speed shortcut; the underlying schema is never restricted to one warehouse per invoice.

---

## Inventory Receiving — Explicit Decision (the GRNI question)

Restating the audit's core finding: today, an inventory-type Supplier Invoice posts `Dr 1100 / Cr 2000` for the **entire invoice amount** at post-time, and `stock_in` posts **no journal at all**. This is not a placeholder — it's the complete, tested, current behavior. The safest way to add physical receiving without breaking this is to keep the invoice's own journal as the **sole** source of the Inventory-Asset GL debit and let the Goods Receipt be a **pure inventory-quantity event** with zero GL effect, for as long as receiving is scoped to *only* happen against an already-existing invoice line.

| Flow | Phase 1-3 behavior | Why |
|---|---|---|
| **1 — Invoice and goods received together** (the normal café case: owner enters the bill and receives the beans in the same sitting) | Supported. Invoice posts `Dr 1100/Cr 2000` for the full amount (unchanged, existing code); Goods Receipt (new) calls `InventoryPostingService::post(type='stock_in')` per inventory line, no journal. | Financial and physical effects both happen, from two different, non-overlapping owners, in one guided workflow. |
| **2 — Invoice exists before goods are received** (bill arrives, delivery comes later) | Supported. Invoice can be posted (AP recognized) with `receipt_status='not_received'`; Goods Receipt is created later against the same invoice's lines. | No accounting change needed — `1100` is already debited at invoice-post time regardless of physical timing; the *quantity* simply catches up later. This is a deliberate simplification: the GL already reflects the asset before the physical count does, which is acceptable for a small café's materiality and avoids inventing an accrual account for Phase 1-3. |
| **3 — Goods arrive before any invoice exists** | **Not supported in Phase 1-3.** The operator must either (a) wait for the supplier's invoice before recording receipt, or (b) use "شراء سريع" (Quick Purchase, below) to create a same-day placeholder invoice immediately alongside the receipt. | This is the one flow that genuinely requires GRNI (a liability for goods owed-for-but-not-yet-billed) to avoid either understating AP or overstating inventory without an offsetting liability. Building GRNI correctly needs a new account, a new posting adapter, and a change to how the eventual invoice's posting behaves (it must debit GRNI instead of `1100` when clearing an accrual) — real, non-trivial work that is explicitly deferred to Phase 4, bundled with Purchase Orders (which is where "goods arrive before the bill" naturally starts to matter for a growing business). Restricting this in Phase 1-3 is the safe, explicit choice this plan makes rather than silently getting the accounting wrong. |
| **4 — Partial delivery** | Supported. `purchase_receipt_lines.received_quantity` can be less than the invoice line's `quantity`; multiple receipts may be created against the same invoice line until fully received. `supplier_invoice_lines.received_quantity` is a rolled-up cache updated transactionally on each receipt. | Mirrors the already-proven `warehouse_transfer_lines` partial-receive pattern (`requested_quantity`/`dispatched_quantity`/`received_quantity`, `partially_received` state) — same idempotency-key-guarded, row-locked approach. |
| **5 — Multiple receipts against one order** | Supported for invoice-referenced receipts in Phase 1-3 (§4 above generalizes to N receipts). Multiple receipts against a **Purchase Order** (rather than an invoice) is Phase 4 scope, once POs exist. | Same mechanism as partial delivery, just repeated. |

---

## Quick Purchase (شراء سريع) — Safest Orchestration

Example: 5 KG coffee beans at $16/KG = $80, paid cash immediately.

A **new, thin orchestration service** (`QuickPurchaseService`) runs inside one `DB::transaction()` and calls only existing/new services that each keep owning exactly one responsibility — it never writes to `journal_entries`, `stock_movements`, or `payment_allocations` directly itself:

1. Resolve or create the supplier — for a first-time/local shop, resolve the tenant's seeded "Cash Supplier" (see below) instead of forcing full onboarding.
2. `SupplierInvoiceService::store()` + `::post()` — one invoice, one line (`line_type='inventory'`, qty 5, unit_price 16, warehouse = chosen destination) → posts `Dr 1100 / Cr 2000` for $80 (**existing service, unchanged**).
3. `PurchaseReceivingService::receive()` (new, Phase 2) — one receipt line, qty 5 → calls `InventoryPostingService::post(type='stock_in', unitCost=16, quantity=5 [converted to base unit])` → updates `stock_balances`/WAC/`latest_unit_cost`/`last_purchase_cost` (**existing engine**, zero journal entries, per the audit's confirmed `InventoryAccountingMapper` mapping).
4. `SupplierPaymentService::store()` — one payment, fully allocated to the new invoice, from the chosen cash location → posts `Dr 2000 / Cr Cash` for $80 (**existing service, unchanged**).

One idempotency key covers the whole orchestration (passed through to each step's own idempotency field) so a retried "شراء سريع" tap cannot create a second invoice/receipt/payment. Net ledger effect: exactly two journal entries (`Dr1100/Cr2000` then `Dr2000/CrCash`) — the same two entries that would result from doing steps 2 and 4 manually today, plus a receiving step that (by design, per the GRNI decision above) contributes zero additional journal entries. **Zero duplicate financial impact by construction**, because no new code in this orchestration ever calls `AccountingPostingService` directly — only the two already-tested services do.

---

## Credit / Cash / Partial Payment

No new payment engine. `SupplierPaymentService`/`payment_allocations`/`SupplierPayableQueryService` already fully support unpaid (`posted`), partially paid (`partially_paid`), and fully paid (`paid`) — derived, not stored redundantly, from `SUM(payment_allocations.amount)` vs. `total_amount` (`SupplierPayableQueryService::invoiceRemainingCents()`, confirmed in the audit). The Purchasing Center's "حالة الدفع" column and KPIs must read `supplier_invoices.status`/`remainingAmount` exactly as `SuppliersScreen`/`SupplierProfileScreen` already do today — **the source of truth for payment status is, and remains, `supplier_invoices.status` as derived by `SupplierPaymentService::recomputeInvoiceStatus()`.** Purchasing never computes or caches its own copy of this.

---

## One-Time / Cash Vendor

**Recommendation: a tenant-level, auto-seeded generic "Cash Supplier"** (Arabic: "مورد نقدي"), not a one-time-vendor free-text field and not forcing full supplier onboarding.

Why: `supplier_invoices.supplier_id` is a `restrictOnDelete` **foreign key**, and every AP report (aging, statement, `SupplierPayableQueryService`) is keyed off a real `suppliers.id`. A free-text/nullable vendor field would either (a) require every report and query to special-case a null/text vendor, doubling the maintenance surface for a rarely-used edge case, or (b) silently break aging/statement totals the moment such a purchase goes unpaid past its due date. A real `suppliers` row costs nothing extra to create (it's exactly the same table every registered supplier uses) and keeps 100% of existing AP machinery correct with zero special-casing. Seed it idempotently per tenant the same way `FinancialSetupService` seeds the default chart of accounts (`updateOrInsert` on a well-known `supplier_number`, e.g. `CASH-001`) so it always exists and is never duplicated.

---

## Purchase Returns and Reversals

| Scenario | Behavior |
|---|---|
| Cancel a draft (invoice not yet posted, nothing received) | Existing: delete/edit the draft invoice directly (`SupplierInvoiceController::update`) — no accounting or stock has happened yet, nothing new needed. |
| Reverse a posted purchase before any receipt and before any payment | Existing: `SupplierInvoiceController::reverse()` already works exactly as today — **new rule**: reversal must additionally check `receipt_status='not_received'`; if any receipt exists, reversal must be blocked with a clear error directing the operator to return the goods first (see next row), because reversing the invoice without also reversing the physical stock would let the ledger and the warehouse disagree. |
| Invoice already received (fully or partially) — needs correction/return | New `PurchaseReturnService` (Phase 5): posts a `return_out` stock movement (existing movement type, already excluded from GL posting by `InventoryAccountingMapper`, so it needs its **own** correcting journal, unlike `stock_in`) and a correcting journal `Dr 2000 AP (or a new Purchase Returns contra account) / Cr 1100 Inventory Asset` via a new `AccountingPostingService::postPurchaseReturn()` adapter, reducing the invoice's remaining/receivable quantities. Only after the return is posted may the underlying invoice itself be reversed. |
| Invoice already paid | The existing, correct sequence must be followed in order: (1) `SupplierPaymentService::reverse()` (existing — already tested to restore invoice balance and cash), (2) `PurchaseReturnService` for any received stock, (3) `SupplierInvoiceService::reverse()`. This plan does not allow skipping steps or reversing out of order — each existing reversal keeps its own tested guarantees. |
| Full purchase return | Same mechanism as partial, with `return_out` quantity equal to the full received quantity across all lines. |
| Damaged goods returned to supplier | Modeled identically to a purchase return — no separate "damage" concept; the `PurchaseReturnService`'s `reason`/`notes` field records why, but the accounting/stock treatment is the same `return_out` + correcting journal. |
| Stock already consumed (sold/wasted) before the invoice needed correction | **Not reversible via a stock return** — the physical goods are gone. Phase 1-5 explicitly does not attempt to "unwind" consumption; the correction becomes a manual adjustment (existing `adjustment_out`/`waste` movement type, already supported, already correctly excluded from silently double-posting) plus, if the AP amount itself was wrong, a manual journal correction by an accountant via the existing, untouched `JournalEntryController` — this is called out explicitly so no phase attempts to auto-reverse consumed stock. |

Never delete a `stock_movements` row (already enforced — the table is insert-only, per the audit). Never mutate a posted `journal_entries` row (already enforced by `JournalEntryService::reverse()`'s "new entry, original untouched" design) — Purchasing inherits both guarantees for free by only ever calling these existing primitives.

---

## Status Model

Two additive dimensions, kept deliberately separate from the existing, already-overloaded `supplier_invoices.status`:

- **`supplier_invoices.status`** (existing, unchanged): `draft` → `posted` → (`partially_paid` → `paid`) — document + payment lifecycle, exactly as today.
- **`supplier_invoices.receipt_status`** (new column, only meaningful when the invoice has `line_type='inventory'` lines): `not_received` → `partially_received` → `received`. Derived the same way `recomputeInvoiceStatus()` derives payment status today — a `recomputeReceiptStatus()` method comparing `SUM(supplier_invoice_lines.received_quantity)` against `SUM(supplier_invoice_lines.base_quantity)`, called after every `PurchaseReceivingService::receive()`.
- **Purchase Order approval status** (Phase 4 only, lives on `purchase_orders`, never on `supplier_invoices`): `draft` → `pending_approval` → `approved`/`rejected`. This is a genuinely separate lifecycle (a commitment being approved, before any liability exists) and must not be merged into either of the two dimensions above.

No single field is ever asked to represent more than one of these three questions ("is it approved to buy," "is the money settled," "did the goods arrive") at once — exactly the minimal-but-extensible model the task requires.

---

## Permissions

Extend the existing, DB-backed `FinanceAccess::CATALOG` (`app/Support/FinanceAccess.php`) — the correct precedent per the audit, not `InventoryAccess`'s hardcoded array. New strings, following the confirmed `finance.<subdomain>.<action>` convention exactly:

```
finance.purchases.view       -- list/read the Purchasing Center (backed by finance.supplier_invoices.view
                                 under the hood for the underlying invoice reads)
finance.purchases.create     -- create a purchase invoice + lines
finance.purchases.edit       -- edit a draft purchase invoice/lines
finance.purchases.post       -- post a purchase invoice (delegates to the same posting path as
                                 finance.supplier_invoices.post)
finance.purchases.receive    -- create/edit Goods Receipts (NEW capability — nothing in the existing
                                 catalog covers "receive stock for a purchase")
finance.purchases.approve    -- approve a Purchase Order (Phase 4 only)
finance.purchases.return     -- create a Purchase Return (Phase 5 only)
```

`finance.purchases.receive` additionally inherits the inventory-side checks Purchasing calls into for free: `InventoryPostingService::post()` already enforces `InventoryWarehouseAssignment::assertAssigned()` (item must be assigned to the target warehouse) and `FinancialActor::assertBranchAccess()` (actor must have branch access to the destination warehouse) internally — no separate `inventory.*` permission needs to be granted to a Purchasing role; owning `finance.purchases.receive` plus the existing branch/warehouse-assignment rules is sufficient, and this is enforced **backend-side**, not by the Flutter client (matching the audit's confirmed "no client-side permission system" convention — action buttons gate on a server-supplied `allowedActions` list, exactly like every other Finance screen already does).

Seed default role grants in `finance_role_permissions` the same way the existing Finance roles are seeded (owner gets the full catalog automatically per `FinanceAccess::permissions()`; Accountant/Branch-Manager roles get an explicit subset — Branch Manager plausibly gets `view/create/receive` but not `post`/`approve`, mirroring the existing Expense approval-separation pattern).

---

## Tenant / Branch / Warehouse Rules

Purchasing does not introduce any new authorization primitive. A Goods Receipt's warehouse must satisfy the same rule `InventoryPostingService::post()` already enforces for a manual `stock_in`: **Central Warehouse and Branch Main Stock are valid receiving destinations for any actor with access to that warehouse's branch (or central access, for owner/manager roles); Bar Stock is a valid destination only if the item is explicitly assigned to it via `inventory_item_warehouses`** (the existing `InventoryWarehouseAssignment::assertAssigned()` check) — receiving directly into Bar Stock should be the exception, not the default, for a purchase (most purchases logically land in Central or Branch Main Stock and move to the bar via the existing, separate Warehouse Transfer flow). The Purchase line's warehouse picker (Phase 1/2 Flutter) should default to the actor's Central/Branch-Main warehouse and only surface Bar/Kitchen warehouses the item is already assigned to, matching the existing item-warehouse-assignment UI pattern already used elsewhere in Inventory.

---

## Accounting Matrix

| # | Business event | Debit | Credit | Owning service | New service required? |
|---|---|---|---|---|---|
| 1 | Inventory purchase on credit | `1100` Inventory Asset | `2000` Accounts Payable | `SupplierInvoiceService::post()` (existing) | No |
| 2 | Inventory purchase paid immediately | `1100` (invoice) then `2000` (payment) | `2000` (invoice) then Cash/Bank (payment) | `SupplierInvoiceService` + `SupplierPaymentService` (existing), orchestrated by new `QuickPurchaseService` | Orchestration only |
| 3 | Operating/service purchase on credit | `expense_categories.financial_account_id` | `2000` | `SupplierInvoiceService::post()` (existing, `invoiceType=expense`) | No |
| 4 | Operating/service purchase paid immediately | expense account then `2000` | `2000` then Cash/Bank | `SupplierInvoiceService` + `SupplierPaymentService` (existing) | No |
| 5 | Fixed asset purchase | `1500` Fixed Assets (existing account) | `2000` | `SupplierInvoiceService::post()` (existing, `invoiceType=other`) | No |
| 6 | Supplier payment (any type, any amount) | `2000` | Cash/Bank (`financial_locations.account_code`) | `SupplierPaymentService` (existing) | No |
| 7 | Purchase return (received stock, returned to supplier) | `2000` (reduce liability) or a new Purchase-Returns contra account | `1100` (reduce asset) | New `PurchaseReturnService` | Yes — new adapter `postPurchaseReturn()` |
| 8 | Cash purchase (specific case of #2/#4 where the location `kind='cash'`) | Same as #2/#4 | Same as #2/#4 | Same as #2/#4 | No |
| 9 | Partial supplier payment | `2000` (partial amount) | Cash/Bank (partial amount) | `SupplierPaymentService` (existing) — invoice status recomputed to `partially_paid` | No |

**How double posting is prevented, concretely:**
1. `AccountingPostingService`'s DB-level unique constraint on `(tenant_id, source_type, source_id, source_event)` makes a second attempt to post the same business event (e.g., posting the same invoice twice) fail at the database layer, not just the application layer.
2. `InventoryAccountingMapper` keeps `stock_in`/`return_in`/`return_out` as `NOT_APPLICABLE` — a Goods Receipt (event #1/#2 above) and a Purchase Return (#7) never independently post an Inventory Asset entry; only the Invoice (for receipt) and the new `PurchaseReturnService` (for return) do, and they do so exactly once each, at two different, non-overlapping moments in the document's life.
3. No new code in this plan ever calls `JournalEntryService` directly — every posting goes through `AccountingPostingService`, which is the single choke point the audit confirmed is already the convention for every existing poster (Sale, Refund, Expense, Supplier Invoice, Supplier Payment, Inventory Adjustment, Waste, Cash Transfer).

---

## Daily Closing

No new closing calculation is introduced. `DailyClosingSummaryService`'s existing `supplier` aggregate (keyed off `supplier_payments`, `status='posted'`, joined to `financial_locations.kind` for the cash-vs-bank split) already, correctly, picks up every Purchasing-driven cash payment with zero changes, because Purchasing payments are ordinary `supplier_payments` rows. Supplier invoices (Purchasing or not) correctly have **no** cash effect and are correctly never referenced by `DailyClosingSummaryService` — this stays true for Purchasing invoices too. `DailyClosingReadinessService`'s existing "unposted draft journal entries" blocker (`DRAFT_JOURNALS`) already protects against a half-posted Purchase invoice/payment closing the day inconsistently, since both post through the same `journal_entries` table. The only **optional** new signal (Phase 6, non-blocking) is surfacing "posted purchase invoices still `not_received` past N days" as an informational alert — additive, not a hard close-blocker, and not a new calculation engine (a simple `WHERE receipt_status != 'received' AND status='posted'` count).

---

## Financial Reports

Because Purchasing invoices *are* `supplier_invoices` rows (tagged via `invoice_types.is_purchase`), they already flow into every report that reads `supplier_invoices`/`journal_entries` today with **zero new report logic**: Supplier Aging, Supplier Statement, Trial Balance, General Ledger, P&L (via the resolved expense/COGS-adjacent accounts), Cash Flow (via `supplier_payments`), and Financial Transactions. The only new report-adjacent element is the Purchasing Center's own list/KPI view, which is a filtered read of the same data (§B above) — not a second ledger, not a new aggregation engine.

---

## Flutter Architecture

New feature module, mirroring the confirmed repo convention exactly (feature-first, `Cubit`+`Equatable` via `get_it`, a single `Repository` wrapping `DioApiClient`):

```
lib/features/purchasing/
  controllers/purchasing_cubit.dart, purchasing_state.dart
  models/purchasing_models.dart        -- SupplierInvoiceLine, PurchaseReceipt, PurchaseReceiptLine
                                            (PurchaseOrder/PurchaseReturn added in their own phases)
  repositories/purchasing_repository.dart  -- wraps existing finance/supplier-invoices endpoints
                                            (extended payload) + new finance/purchases,
                                            finance/purchases/{invoice}/receipts endpoints
  views/
    purchasing_center_screen.dart      -- list + KPIs, route /finance/purchases
    purchase_invoice_form_screen.dart  -- line-item editor (inventory item picker reusing
                                            InventoryItem/UnitConversionResolver display,
                                            expense-category picker for service lines,
                                            account picker defaulted to 1500 for asset lines)
    purchase_invoice_detail_screen.dart -- route /finance/purchases/:id; receive/pay actions
    quick_purchase_dialog.dart         -- شراء سريع single-action flow
  widgets/                              -- purchase-line row widgets, receipt dialog
```

- `finance_navigation_bar.dart`: add a new `_FinanceDestination('purchases', '/finance/purchases', Icons.shopping_cart_outlined)` entry — per the requested nav order, placed directly after `expenses` (المصروفات) and before `suppliers` (الموردون والمستحقات), since a purchase is naturally reviewed before the resulting supplier balance. Add the matching Arabic label constant alongside the existing `financeSectionSuppliers`-style constants in `app_localizations_ar.dart`.
- `app_router.dart`: add `GoRoute`s for `/finance/purchases`, `/finance/purchases/new`, `/finance/purchases/:invoiceId`, following the exact pattern of the existing `/finance/suppliers`/`/finance/suppliers/:supplierId` routes (wrapped in `BlocProvider<PurchasingCubit>`, no router-level guard — same server-driven-authorization convention as every other Finance route).
- `FinanceSetupRepository`: **not extended directly** — Purchasing gets its own `PurchasingRepository` (new file) per the established one-repository-per-feature convention, even though it calls some of the same underlying `finance/supplier-invoices` endpoints `FinanceSetupRepository` already calls (duplication of a thin HTTP wrapper method, not of business logic, matching how the app already has decoupled repositories per feature).
- `InventoryItem` model reuse: the existing `purchaseUnit`/`lastPurchaseCost` fields (already present, per the audit) can pre-fill a new purchase line's unit/last-cost fields as a convenience default — read-only suggestions, never authoritative (the line's own `unit_price`/`purchase_unit` at entry time is what posts).
- Authorization: no new client-side pattern. Catch `ApiException.statusCode == 401/403` for a permission-denied state (existing convention); gate every action button (فاتورة جديدة، استلام، ترحيل) on a server-supplied `allowedActions` list on the invoice/receipt model (existing convention, already used by `SupplierInvoice`/`WarehouseTransfer`).

---

## Seed Data

Extend the existing demo seeder (`FinanceOperationsDemoSeeder`/`Cafe618FinanceOperationsDemoSeeder`, which the audit confirmed already builds supplier invoices and inventory data through **real service calls**, not raw inserts) with, once the corresponding phase ships:

- Coffee-bean inventory purchase (credit, posted, received) — via `SupplierInvoiceService` + `PurchaseReceivingService`.
- Packaging purchase (credit, partially received) — exercises `receipt_status='partially_received'`.
- Milk purchase (cash, paid immediately) — via `QuickPurchaseService`.
- A second credit purchase left unpaid, to populate Supplier Aging realistically.
- A partial payment against one open purchase invoice — via `SupplierPaymentService`, unchanged call.
- An operating/service purchase (e.g. "internet bill via supplier") — `invoiceType=service`, no receipt.
- A purchase return against a partially-consumed receipt — via `PurchaseReturnService` (Phase 5 seed addition only).

Every new seed scenario must call the real domain services (`SupplierInvoiceService`, `PurchaseReceivingService`, `SupplierPaymentService`, `QuickPurchaseService`) exactly the way the current seeder's `postedInvoice()`/`payment()` helpers already do — never raw `DB::table(...)->insert()` for these rows, to guarantee the seeded data is itself a live regression test of the real code paths.

---

## Phased Build-Out

### PHASE 0 — Schema & Contracts

**Scope**: purely additive schema + catalog + permission groundwork. No UI, no new business logic beyond what's needed for the schema to be usable.

- **Database**: `supplier_invoice_lines` (see Line Model above); `supplier_invoices.receipt_status` (new nullable string column, default `null` for non-inventory invoices); `invoice_types.is_purchase` (new boolean, default `false`).
- **Backend**: seed new `invoice_groups`/`invoice_types` rows (`purchases` group; `purchase_inventory`/`purchase_service`/`purchase_asset` types) via the existing idempotent seeding pattern (`FinancialSetupService`-style `updateOrInsert`); add `finance.purchases.*` strings to `FinanceAccess::CATALOG`; seed the tenant-level "Cash Supplier" the same way.
- **Endpoints**: none new yet.
- **Flutter**: none.
- **Accounting/Inventory impact**: none — no posting logic changes yet.
- **Tests**: migration/seed idempotency tests (mirroring `FinancialInventoryFoundationApiTest`'s existing seeding-idempotency style); permission-catalog tests confirming the new strings are grantable via `finance_role_permissions`.
- **Acceptance criteria**: `supplier_invoice_lines` exists and is empty everywhere; every existing Finance/Inventory test still passes unmodified (zero behavioral change).
- **Dependencies**: none.

### PHASE 1 — Purchasing Center + Real Purchase Invoice Core (no receiving yet)

**Scope**: line items on a Supplier Invoice, single-line-type-per-invoice only (no mixed lines yet), no stock effect yet — matches today's "invoice posts, inventory doesn't move" behavior exactly, just with real line detail instead of one flat amount.

- **Database**: none beyond Phase 0.
- **Backend**: extend `SupplierInvoiceController`/`SupplierInvoiceService` to accept/return `lines[]` on create/update; server recomputes `subtotal`/`tax_amount`/`total_amount` from lines when present (never trusts client totals); validation rejects mixed `line_type` values on one invoice for this phase; new thin `PurchaseController@index` (read-only) joining `supplier_invoices`+`invoice_types` filtered to `is_purchase=true` for the Purchasing Center list/KPIs.
- **Endpoints**: extend existing `POST/PATCH finance/supplier-invoices[/:id]` payload (backward compatible — omitting `lines` behaves exactly as today); new `GET finance/purchases` (list/KPIs).
- **Flutter**: `features/purchasing/` scaffolding; `PurchasingCenterScreen` (route `/finance/purchases`); `PurchaseInvoiceFormScreen` with a real line-item editor (item picker for inventory lines, category picker for service lines, account picker defaulted to `1500` for asset lines); nav entry + route registration.
- **Permissions**: `finance.purchases.view/create/edit/post`.
- **Accounting impact**: none beyond what `SupplierInvoiceService::post()` already does today (single debit account per invoice, now sourced from the lines' shared type instead of a flat header field).
- **Inventory impact**: none.
- **Tests**: line totals sum-validation; mixed-type rejection; tenant/branch isolation on the new list endpoint; permission checks for each new string; regression — existing `SupplierAccountsPayableApiTest` suite stays green unmodified.
- **Acceptance criteria**: an owner can create, view, and post a real multi-line inventory or service purchase invoice from a dedicated Purchasing Center, with the exact same single journal entry `SupplierInvoiceService` already produces today; existing Supplier/Expense screens are unaffected.
- **Dependencies**: Phase 0.

### PHASE 2 — Inventory Receiving / WAC Integration

**Scope**: the Goods Receipt domain; wires physical stock to a posted purchase invoice with zero new journal entries; lifts the single-line-type restriction by teaching `SupplierInvoiceService::post()` to build one debit line per distinct resolved account.

- **Database**: `purchase_receipts` (id, tenant_id, branch_id, supplier_invoice_id FK restrictOnDelete, receipt_number, received_date, notes, idempotency_key unique per tenant, created_by, timestamps); `purchase_receipt_lines` (id, tenant_id, purchase_receipt_id FK cascadeOnDelete, supplier_invoice_line_id FK restrictOnDelete, inventory_item_id, warehouse_id [snapshotted from the invoice line], unit, quantity, base_quantity, unit_cost [snapshot], stock_movement_id FK nullable, timestamps).
- **Backend**: new `PurchaseReceivingService` — validates `Σ(this receipt's qty) + supplier_invoice_lines.received_quantity ≤ supplier_invoice_lines.base_quantity` under row lock, calls `InventoryPostingService::post(type='stock_in', ...)` per line inside one transaction, updates `supplier_invoice_lines.received_quantity` and recomputes `supplier_invoices.receipt_status`; new `PurchaseReceiptController`; extend `SupplierInvoiceService::post()` to group `supplier_invoice_lines` by resolved account and emit one debit line per account (backward compatible: header-only/no-lines invoices keep the exact existing single-debit-line behavior).
- **Endpoints**: `POST finance/purchases/{invoice}/receipts`, `GET finance/purchases/{invoice}/receipts`, `GET finance/purchases/{invoice}/receipts/{receipt}`.
- **Flutter**: "استلام" (receive) action on `PurchaseInvoiceDetailScreen`; receipt-lines dialog defaulting to remaining quantity per line, warehouse picker (defaulting per line, per the warehouse-placement decision above).
- **Permissions**: `finance.purchases.receive`.
- **Accounting impact**: **none from the receipt itself** — this is the phase where the no-double-posting invariant from the audit is directly exercised; the mixed-line posting change is additive/backward-compatible.
- **Inventory impact**: WAC/quantity update exactly matching the existing manual `stock_in` behavior, now `referenceType`/`referenceId`-linked back to the receipt (using `stock_movements.reference_type`/`reference_id`, already present columns, previously only used for demo-seed markers) instead of a free-text demo marker.
- **Tests**: WAC recalculation matches `InventoryPostingService`'s existing test pattern for the same cost/quantity inputs; partial receipt across multiple receipts; over-receipt rejected; **explicit duplicate-posting regression test**: after a receipt, assert `journal_entries` count is unchanged (mirrors `SupplierAccountsPayableApiTest`'s existing `test_inventory_type_invoice_posts_ap_liability_without_creating_any_stock_movement`, inverted); mixed-line invoice posts one debit line per distinct account, still balances.
- **Acceptance criteria**: a posted inventory purchase invoice can be received (fully or partially) with correct WAC/quantity effects and provably zero new journal entries; a mixed-type invoice (inventory + service lines) posts one correctly-grouped, balanced journal entry.
- **Dependencies**: Phase 1.

### PHASE 3 — Supplier AP + Immediate/Partial Payment Integration (Quick Purchase)

**Scope**: the low-friction "شراء سريع" flow; the Cash Supplier; payment-status surfacing in the Purchasing Center — no new payment engine.

- **Database**: none beyond seeding the Cash Supplier (Phase 0, referenced here for completeness).
- **Backend**: new `QuickPurchaseService` orchestrating `SupplierInvoiceService` → `PurchaseReceivingService` → (optionally) `SupplierPaymentService`, one transaction, one idempotency key threaded through all three; new `POST finance/purchases/quick` endpoint.
- **Endpoints**: `POST finance/purchases/quick`.
- **Flutter**: `QuickPurchaseDialog` — item, quantity, unit price, warehouse, "pay now?" toggle (reusing `CashBanksScreen`'s cash/bank + payment-method picker pattern).
- **Permissions**: `finance.purchases.create` + `finance.purchases.receive` (+ `finance.supplier_payments.create` if paying now — reuse the existing payment permission, don't invent a parallel one).
- **Accounting impact**: exactly the two existing journal entries described in the Quick Purchase section above — no new posting logic.
- **Inventory impact**: exactly Phase 2's receiving effect, orchestrated rather than manual.
- **Tests**: one Quick Purchase call produces exactly one invoice + one receipt (+ one payment if paid-now) + the correct journal count; idempotent replay produces no duplicates; Cash Supplier is auto-provisioned exactly once per tenant.
- **Acceptance criteria**: an owner can record "5kg beans, $80, paid cash" in one dialog, with the Purchasing Center immediately showing it as `paid`/`received`, and the Supplier screen for "Cash Supplier" showing zero outstanding balance.
- **Dependencies**: Phases 1, 2.

### PHASE 4 — Purchase Orders + Partial Receiving Against a PO + GRNI

**Scope**: the one phase that changes existing invoice-posting behavior (to support Flow 3, goods-before-invoice) — the largest and riskiest phase in this plan; ship only after Phases 1-3 are stable in production use.

- **Database**: `purchase_orders`/`purchase_order_lines` (approval lifecycle, no accounting effect by themselves); a new GL account `2020` "Goods Received Not Invoiced" (must not reuse `2010`, already "Sales Tax Payable" — confirmed in the audit); `purchase_receipt_lines.purchase_order_line_id` nullable FK (a receipt may now reference a PO line instead of/in addition to an invoice line).
- **Backend**: `PurchaseOrderService` (draft→pending_approval→approved/rejected, no journal); extend `PurchaseReceivingService` to allow receiving against a PO line with **no** invoice yet — this path **does** call a new `AccountingPostingService::postGoodsReceiptAccrual()` (`Dr 1100 / Cr 2020`), the first and only case in this entire plan where a Goods Receipt posts a journal, explicitly scoped to the pre-invoice scenario; when the invoice later arrives for a PO-received line, `SupplierInvoiceService::post()` must debit `2020` (clearing the accrual) instead of `1100` for that portion — a real, carefully-tested change to existing posting logic.
- **Endpoints**: full `purchase-orders` CRUD + approve/reject; receipts extended to accept a `purchaseOrderLineId`.
- **Flutter**: PO list/detail/approval screens; receiving flow extended to receive against an open PO.
- **Permissions**: `finance.purchases.approve`.
- **Accounting impact**: introduces the plan's only new "sometimes a receipt posts a journal" branch — must be exhaustively tested against Phase 2's invariant (a receipt against an *existing invoice line* still posts nothing; only a receipt against a PO line with no invoice yet posts the accrual).
- **Inventory impact**: none beyond Phase 2's mechanics, reused.
- **Tests**: full PO lifecycle; receiving against a PO before any invoice exists posts the accrual correctly; the subsequent invoice correctly clears `2020` instead of debiting `1100` again (**explicit test that `1100` is debited exactly once total across the accrual+invoice pair, not twice**); partial receiving across multiple receipts against one PO.
- **Acceptance criteria**: a PO can be raised, approved, partially received before any invoice exists, and reconciled against the eventual invoice with `2020` net to zero and `1100` debited exactly once for the true total.
- **Dependencies**: Phases 1-3 stable; explicitly the highest-risk phase in this plan per the accounting-logic change required.

### PHASE 5 — Purchase Returns

**Scope**: correcting received purchases without ever editing a posted journal or deleting a stock movement.

- **Database**: `purchase_returns`/`purchase_return_lines` (references the original `purchase_receipt_line_id`, quantity returned, reason).
- **Backend**: `PurchaseReturnService` — posts `return_out` (existing movement type) + new `AccountingPostingService::postPurchaseReturn()` adapter (`Dr 2000 or Purchase-Returns-contra / Cr 1100`); enforces the reversal ordering from the Purchase Returns and Reversals section above (payment must be reversed first if the invoice was paid).
- **Endpoints**: `POST finance/purchases/{invoice}/returns`.
- **Flutter**: "إرجاع" (return) action on the invoice/receipt detail screen.
- **Permissions**: `finance.purchases.return`.
- **Accounting impact**: new adapter, new correcting journal, never mutates the original invoice/payment journals.
- **Inventory impact**: `return_out` stock movement, already confirmed non-GL-posting on its own (mapper treats it as `NOT_APPLICABLE`), so the correcting journal must be posted by `PurchaseReturnService` itself, not expected from the mapper.
- **Tests**: full return reduces stock and posts a correcting journal that balances; return blocked against an already-fully-consumed quantity; return-then-invoice-reversal ordering enforced; partial return leaves correct remaining receivable/payable amounts.
- **Acceptance criteria**: a damaged or over-ordered purchase can be returned with correct, auditable stock and GL effect, without ever touching the original posted entries.
- **Dependencies**: Phases 1-3 (does not depend on Phase 4/PO).

### PHASE 6 — Reports / Closing / Alerts

**Scope**: confirm zero-new-report-logic claim in practice; add the one optional Daily-Closing informational signal.

- **Backend**: verify (with tests, not new queries) that Purchasing invoices already appear correctly in Supplier Aging/Statement/Trial Balance/GL/Cash Flow; add the optional `receipt_status != 'received'` aging alert to `DailyClosingReadinessService` as a non-blocking informational item; surface existing `InventoryLowStockAlert` data (already present per the Flutter audit) as reorder suggestions in the Purchasing Center.
- **Flutter**: Purchasing Center KPI row; reorder-suggestion panel reading existing low-stock alert data.
- **Tests**: report totals including Purchasing data reconcile against manually-summed `journal_entries`/`payment_allocations`, exactly like the existing Finance report tests already do for non-purchasing supplier invoices.
- **Acceptance criteria**: no report shows a different total for Purchasing-tagged invoices than it would for any other supplier invoice of the same type — proving there is no parallel ledger.
- **Dependencies**: Phases 1-5 (needs real data from each to be meaningful).

### PHASE 7 — Demo Seeding + Comprehensive Regression

**Scope**: the seed scenarios listed above, plus a full regression pass.

- **Backend**: extend the existing demo seeder with every scenario in the Seed Data section, via real service calls only.
- **Tests**: a comprehensive end-to-end Purchasing test suite covering every scenario in §Test Plan below; re-run the full existing Finance + Inventory suites (`SupplierAccountsPayableApiTest`, `ExpenseWorkflowApiTest`, `FinanceDashboardExpensesAndApTest`, `InventoryAccountingMapperTest`, `InventoryCenterApiTest`, `InventorySecurityAndSeederTest`) and confirm zero regressions.
- **Acceptance criteria**: the demo tenant shows a realistic, fully-reconciling Purchasing history across every purchase type and lifecycle state; the full backend test suite (existing + new) is green.
- **Dependencies**: all prior phases.

---

## Test Plan

**Backend**:
- Tenant isolation, branch isolation, warehouse authorization on every new endpoint (mirroring `InventorySecurityAndSeederTest`'s existing patterns).
- Draft purchase invoice create/edit/discard.
- Inventory-line purchase posts `Dr 1100/Cr 2000` for the summed line total (Phase 1); WAC updates correctly on receipt (Phase 2); unit conversion applied correctly for a non-base purchase unit.
- **No duplicate inventory receipt** — retried receipt with the same idempotency key replays, doesn't double-post stock.
- **No duplicate accounting entry** — retried invoice-post/receipt/payment doesn't create a second journal (DB unique-constraint-backed).
- Credit purchase / AP aging correctness; cash purchase; partial payment; full payment (all via existing `SupplierPaymentService` tests extended with Purchasing-sourced invoices, not new payment logic).
- Partial receipt, multiple receipts against one invoice/PO.
- Reversal/return ordering enforcement (payment→return→invoice).
- Posting into a closed accounting period is rejected (reuses `AccountingPeriodGuard`, already enforced by `JournalEntryService::post()` — verify Purchasing inherits it, don't reimplement).
- Daily Closing readiness correctly reflects Purchasing-driven cash payments and draft-journal blockers.
- Idempotency/concurrent-replay safety on Quick Purchase and Goods Receipt.
- Posted-document immutability: a posted invoice's lines cannot be edited directly; only receipt/payment/return actions may affect it further.

**Flutter**:
- Navigation: new "المشتريات" destination reachable, correct active-tab highlighting.
- Purchase list: filters (type, status, receipt-status, supplier), pagination.
- Create workflow: inventory lines (item/unit/quantity/warehouse), non-stock lines (service/asset), validation (mixed-type rejection in Phase 1, totals reconciliation).
- Permissions: action buttons correctly hidden/shown per `allowedActions`; 401/403 surfaces the existing permission-denied state, not a crash.
- Loading/error/empty states for the new list/detail screens (matching existing Finance screen conventions).
- Detail view: line items, receipt history, payment history all correctly rendered from the existing/extended models.
- Receipt status and payment status rendered as two independently correct badges, never conflated.

---

## Feature Matrix

| Feature | Existing | Reuse | Modify | New | Risk | Recommended Phase |
|---|---|---|---|---|---|---|
| Supplier master | Yes | Yes | — | — | Low | 0 |
| AP liability + journal (header-only) | Yes | Yes | — | — | Low | 1 (as-is) |
| Invoice line items | No | — | — | Yes | Low | 1 |
| Purchasing Center list/KPIs | No | — | — | Yes (read-model) | Low | 1 |
| Mixed-line invoice posting | No | — | Yes (`SupplierInvoiceService::post()`) | — | Medium | 2 |
| Goods Receipt (stock_in linkage) | No | — | — | Yes | Medium | 2 |
| Quick Purchase orchestration | No | — | — | Yes | Low-Medium | 3 |
| Cash Supplier | No | — | — | Yes (seed) | Low | 0/3 |
| Supplier payment integration | Yes | Yes | — | — | Low | 3 (as-is) |
| Purchase Orders | No | — | — | Yes | Medium | 4 |
| GRNI accrual | No | — | Yes (`SupplierInvoiceService::post()` for PO-sourced lines) | Yes | **High** | 4 |
| Purchase Returns | No | — | — | Yes | Medium | 5 |
| Daily Closing alert | Yes (engine) | Yes | Minor addition | — | Low | 6 |
| Financial reports coverage | Yes | Yes | — | — | Low | 6 (verification only) |
| Demo seeding | Yes (pattern) | Yes | Extend | — | Low | 7 |
| Purchasing Flutter module/nav/route | No | — | — | Yes | Low | 1 |
| `finance.purchases.*` permissions | No | — | Extend `FinanceAccess::CATALOG` | Yes (strings) | Low | 0 |

---

## ARCHITECTURE DECISION

Extend `supplier_invoices` with a subordinate `supplier_invoice_lines` table (never a second header) to carry real purchase line detail; add a new, independent Goods Receipt domain (`purchase_receipts`/`purchase_receipt_lines`) that is the sole trigger for `InventoryPostingService::post(type='stock_in')` and posts zero journal entries for as long as receiving is scoped to invoice-referenced lines (Phases 1-3); defer Purchase Orders and the one genuinely new accounting branch they require (GRNI, Phase 4) until the simpler, invoice-anchored flow is live and proven; defer Purchase Returns (Phase 5) until receiving exists to return against. The "Purchasing Center" is a filtered, tagged read of `supplier_invoices` (via an additive `invoice_types.is_purchase` flag), never a second ledger. No existing AP, payment, or inventory-costing service is modified in Phase 1; the only later modification to an existing service (`SupplierInvoiceService::post()`, for mixed-line grouping in Phase 2 and GRNI-clearing in Phase 4) is additive and backward-compatible with every header-only invoice already in production.

## PHASE 1 READY: YES

Conditioned on Phase 0 landing first (schema/catalog/permission seeding only — no behavioral change to any existing endpoint, verified by requiring the full existing test suite to pass unmodified). No blocker requires a redesign of anything already shipped: the default chart of accounts already has the asset account (`1500`) Phase 1 needs; the invoice-type catalog is already extensible without a migration to the catalog tables themselves; the permission system is already DB-backed and only needs new strings; and the single most important accounting fact this audit uncovered — `stock_in` posts nothing today — is exactly the property Phase 1-3 needs to remain true, and changing nothing about it is the recommended path.
