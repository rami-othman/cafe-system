# Purchasing Forensic Audit

Read-only investigation. No application code, migrations, or Flutter screens were changed while producing this document. Every claim below was verified directly against the current repository (backend under `cafe-system/backend`, Flutter under `cafe-system/windows_application`) on 2026-09-12; file:line references are exact at that commit. Prior planning documents in `docs/finance/` and `docs/inventory/` were consulted only as historical color and are explicitly **not** trusted — several (notably `docs/finance/FINANCE_AUDIT_AND_ARCHITECTURE.md`, dated to "Phase 0A") assert that Suppliers/Expenses/AP are "completely missing," which is now false. See §8.

## 1. Executive Summary

The café already has a real, working, tested **Accounts-Payable and Expense subsystem**: `suppliers`, `supplier_invoices`, `supplier_payments`, `payment_allocations` (+ `supplier_payment_allocation_history`, `invoice_groups`/`invoice_types`, `expenses`, `expense_categories`) all exist, are wired to a shared `AccountingPostingService` → `JournalEntryService` posting pipeline, and are covered by three solid feature-test files (`SupplierAccountsPayableApiTest`, `ExpenseWorkflowApiTest`, `FinanceDashboardExpensesAndApTest`). Inventory has an equally real, independently tested **stock/WAC engine** (`InventoryPostingService`) with weighted-average costing, unit conversion, warehouse assignment, and idempotent movement posting.

**These two subsystems are correct in isolation and completely disconnected from each other.** `supplier_invoices` is a **header-only** AP document — one amount, one debit account, no line items, no warehouse, no quantity. `stock_in` movements are a **standalone manual form** with no supplier/invoice reference. Nothing in the codebase links a stock movement to a supplier invoice; nothing in the codebase creates a stock movement from a supplier invoice. The Flutter side mirrors this exactly: `SupplierProfileScreen`'s invoice dialog is a flat total-amount form, and the Inventory `stock_in` screen has no supplier picker at all (`grep -n "supplier"` returns zero hits in either inventory view file).

There is **no purchase-order, goods-receipt, or line-item schema anywhere** — `purchase_orders`, `purchase_order_lines`, `purchase_receipts`, `purchase_receipt_lines`, `supplier_invoice_lines`, `purchase_returns` do not exist in any migration (confirmed independently by two separate greps of `database/migrations`, from both the Finance and Inventory sides).

The single most important accounting fact this audit establishes: **`stock_in` currently posts zero journal entries.** `InventoryAccountingMapper::decision()` explicitly buckets `stock_in` (along with `opening_balance`, `stock_out`, `return_in`, `return_out`) as `NOT_APPLICABLE` / `UNMAPPED_RECEIPT_OR_MOVEMENT` — no journal is ever created for it. Meanwhile, an `invoiceType='inventory'` Supplier Invoice already posts `Dr 1100 Inventory Asset / Cr 2000 Accounts Payable` for the **full invoice amount**, and a dedicated test (`SupplierAccountsPayableApiTest::test_inventory_type_invoice_posts_ap_liability_without_creating_any_stock_movement`) asserts this posting happens **without** touching `stock_movements` at all. This means the current design already has exactly one place that owns the Inventory-Asset GL debit (the Invoice) and exactly one place that owns the physical quantity/WAC change (a manual `stock_in`) — they just aren't connected to each other yet. Building Purchasing correctly means **wiring these two into one workflow without ever making both of them post to the ledger independently** — i.e., a Goods Receipt must keep triggering `stock_in`-shaped inventory effects while `InventoryAccountingMapper` continues to treat `stock_in` as non-posting. If a future change ever adds journal posting to `stock_in`, it will double-post against Inventory Asset alongside the Invoice — this is flagged as the single most important invariant to protect (§7, §16 of the implementation plan).

## 2. Current Architecture — Confirmed Live Components

```
SupplierController / SupplierInvoiceController / SupplierPaymentController / ExpenseController
        │ (inline-validated, no FormRequest classes — NOT FOUND in app/Http/Requests for this domain)
        ▼
SupplierService          — CRUD on `suppliers` only
SupplierInvoiceService   — writes `supplier_invoices`; resolves debit account by invoice_type;
                            posts ONE journal per invoice via AccountingPostingService::postSupplierInvoice()
SupplierPaymentService   — writes `supplier_payments` + `payment_allocations`;
                            posts ONE journal per payment via AccountingPostingService::postSupplierPayment()
SupplierPayableQueryService — READ ONLY; derives invoice remaining/paid/overdue from `payment_allocations`
ExpenseService           — writes `expenses`; posts on `pay()` via AccountingPostingService::postExpense()
        │
        ▼
AccountingPostingService (thin orchestration; unique (tenant_id, source_type, source_id, source_event)
        │                 DB constraint prevents any accidental double post of the same business event)
        ▼
JournalEntryService — createDraft() / post() / reverse() / hasBeenReversed() — debit=credit enforced,
        │              AccountingPeriodGuard blocks posting into a closed period, reverse() never
        │              mutates the original entry (creates a new posted, swapped entry instead)
        ▼
journal_entries / journal_entry_lines
```

```
StockMovementController → InventoryPostingService::post()  — the single funnel for ALL stock/cost writes
        │ types: opening_balance, stock_in, stock_out, adjustment_in, adjustment_out,
        │        transfer_in, transfer_out, return_in, return_out, waste, stock_count_variance,
        │        sale_consumption
        │ for stock_in specifically: increases stock_balances.quantity_on_hand, recomputes
        │ stock_balances.average_unit_cost (integer weighted-average math), updates
        │ inventory_items.latest_unit_cost/cost_per_unit, and — stock_in only —
        │ inventory_items.last_purchase_cost
        ▼
stock_movements (immutable, idempotency_key unique per tenant)
        ▼
InventoryAccountingMapper::postForFinalMovement() — called for EVERY movement type, but only
        `waste` and `stock_count_variance` actually produce a journal (Dr/Cr 1100 vs 5010,
        direction depending on surplus/shortage). stock_in/stock_out/opening_balance/return_in/
        return_out are explicitly NOT_APPLICABLE. transfer_in/out are NOT_APPLICABLE ("no P&L
        impact"). sale_consumption is explicitly deferred ("already included in the paid-order
        COGS journal" — posted elsewhere, not audited here as out of scope for Purchasing).
```

These two funnels never call each other. `SupplierInvoiceService` has no `Inventory`/`StockMovement`/warehouse reference anywhere in its 338 lines. `InventoryPostingService`/`InventoryAccountingMapper` have no `Supplier`/`supplier_invoice` reference anywhere.

## 3. Verified Findings Against the Prompt's Assumptions

| # | Assumption in the request | Verified? | Evidence |
|---|---|---|---|
| A | Supplier/AP exists: `suppliers`, `supplier_invoices`, `supplier_payments`, `payment_allocations` | **Confirmed** | `database/migrations/2026_09_02_000009_create_supplier_ap_tables.php:11-131` creates all four; `SupplierController`/`SupplierInvoiceController`/`SupplierPaymentController` (`app/Http/Controllers/Api/`) are live and routed (`routes/api.php:461-476`) |
| B | Supplier invoices support `expense`/`inventory`/`other` | **Confirmed, and evolved further** | `SupplierInvoiceController::draftData()` inline validation accepts `invoiceType in:expense,inventory,other` (L99-101), but the effective type is now resolved server-side from a configurable `invoice_types` catalog (`invoice_types.posting_behavior`, migration `2026_09_10_000019_create_invoice_type_catalog.php:27-37`) via `SupplierInvoiceService::withResolvedType()` (L289-298) — a 4th behavior, `none`, exists for non-postable/test types |
| C | Inventory-type invoice posts `Dr 1100 / Cr 2000` | **Confirmed exactly** | `SupplierInvoiceService::resolveDebitAccount()` (L246-256, inventory branch) hard-resolves account code `1100`; `post()` (L109-134) always builds exactly two lines: `[debitAccount.code debit=total], ['2000' credit=total]` — this is the **only** journal-posting code path for any invoice type, expense/inventory/other alike |
| D | `SupplierInvoiceService` intentionally does not create inventory quantity | **Confirmed, and explicitly documented in-code** | Class docblock (L12-19): *"it never creates a stock movement or inventory quantity, even for invoiceType 'inventory' — that is a Goods Receipt's job, and no such workflow exists yet."* Enforced by test `SupplierAccountsPayableApiTest::test_inventory_type_invoice_posts_ap_liability_without_creating_any_stock_movement` (asserts `stock_movements` count unchanged after posting) |
| E | `InventoryPostingService` supports `stock_in`; increases stock, updates warehouse balance, computes WAC, updates latest/last-purchase cost | **Confirmed exactly** | `app/Domain/Inventory/InventoryPostingService.php`: `stock_in` is in the `INCOMING` const (L16); balance update at L73; WAC calc at L66-70; `latest_unit_cost`/`cost_per_unit` update at L74-78; `last_purchase_cost` update is **stock_in-specific** (L79-83, with an explicit comment: *"stock_in is the purchase-receiving movement. It is the authoritative place to record the most recent buy price."*) |
| F | `InventoryAccountingMapper` does not post a journal for `stock_in` | **Confirmed exactly** | `decision()` L58: `stock_in` (with `opening_balance, stock_out, return_in, return_out`) → `nonPosting('NOT_APPLICABLE', 'UNMAPPED_RECEIPT_OR_MOVEMENT', ...)`. Only `waste`/`stock_count_variance` post; `adjustment_in`/`adjustment_out` throw a configuration-required error if attempted without setup; `transfer_in`/`transfer_out`/`sale_consumption` are explicitly non-posting for other, documented reasons |
| G | Flutter Supplier Invoice is total-level, not line-item | **Confirmed exactly** | `SupplierProfileScreen`'s `_InvoiceFormDialog` (`supplier_profile_screen.dart:589-1018`) fields are exactly: branch, invoice number, invoice date, due date, invoice type, one expense-category-or-debit-account, one subtotal, one tax amount, description, notes. No `items`/`lines` array in the submit payload (L760-778) or in the `SupplierInvoice` Dart model (`finance_setup_models.dart:680-804`) — no inventory item picker, quantity, unit, unit price, or warehouse field exists anywhere in this dialog |
| H | No `purchase_orders`, `purchase_order_lines`, `purchase_receipts`, `purchase_receipt_lines`, `supplier_invoice_lines`, `purchase_returns` | **Confirmed absent** | `grep -rniE "purchase_order|purchase_receipt|supplier_invoice_line|purchase_return" database/migrations` → zero matches (independently re-run from both the Finance-side and Inventory-side research passes) |

## 4. Domain Ownership — Current State (Before Purchasing)

| Domain | Current source of truth | Owns | Does NOT own |
|---|---|---|---|
| Accounts-Payable liability | `supplier_invoices` (+ `SupplierInvoiceService`) | The single AP-liability journal per invoice (`Dr resolved account / Cr 2000`); invoice header amount, type, status | Any stock/quantity effect (explicitly, by design and by test) |
| AP payment / cash-out | `supplier_payments` + `payment_allocations` (+ `SupplierPaymentService`) | The single `Dr 2000 / Cr cash-or-bank` journal per payment; invoice `status` transition (`posted → partially_paid → paid`) derived from `SUM(payment_allocations.amount)` | Anything about what was purchased or received |
| Operating expense | `expenses` (+ `ExpenseService`) | `Dr expense-category account / Cr cash-or-bank` at `pay()` time, independent lifecycle (draft→pending_approval→approved→paid/rejected) | AP liability tracking — `expenses.supplier_id` exists as a column but is **unconstrained (no FK) and never read or written anywhere in application code** (confirmed by grep) — it is dead/vestigial, not a real link |
| Physical stock quantity + WAC | `stock_balances` + `inventory_items.latest_unit_cost`/`last_purchase_cost` (+ `InventoryPostingService`) | The only place quantity-on-hand and weighted-average cost are computed, for every movement type including `stock_in` | Any GL/journal effect for `stock_in` specifically (by explicit design, §3.F) |
| Accounting journal | `journal_entries`/`journal_entry_lines` (+ `JournalEntryService`, wrapped by `AccountingPostingService`) | Every posted debit/credit anywhere in the system; the only reversal mechanism (`reverse()` — new balancing entry, original never mutated); the single duplicate-posting guard (`(tenant_id, source_type, source_id, source_event)` unique) | Business-rule decisions about *what* to post — callers must supply fully-resolved `lines[]` |
| Purchase / Purchase Order / Goods Receipt | **Nothing** — no schema, no service, no UI | — | Everything: this is the actual gap Purchasing must fill |

**The critical rule going forward, stated once so every phase in the implementation plan can be checked against it:** a new Purchasing module must add exactly **one new owner** — a Goods Receipt concept that owns "stock moved because of a purchase" — and must **never** duplicate the AP-liability journal that `SupplierInvoiceService` already owns, **never** duplicate the payment journal that `SupplierPaymentService` already owns, and must **preserve** `InventoryAccountingMapper`'s current non-posting treatment of `stock_in` (a Goods Receipt must keep using `type='stock_in'`, not invent a new type that could accidentally get mapped to a journal later without this same review).

## 5. Reusable Components (verified live, not aspirational)

- `AccountingPostingService` — generic `post()` + eight named adapters (`postSale`, `postRefund`, `postExpense`, `postSupplierInvoice`, `postSupplierPayment`, `postInventoryAdjustment`, `postWaste`, `postCashTransfer`). A `postPurchaseReturn()`/similar adapter (Phase 5) is additive, not a redesign.
- `JournalEntryService` — `createDraft/post/reverse/hasBeenReversed/find/totals`, debit=credit enforcement, `AccountingPeriodGuard` period-lock check already wired into `post()`.
- `SupplierInvoiceService`/`SupplierPaymentService`/`SupplierPayableQueryService` — the entire AP engine, including idempotency (`idempotency_key`/`idempotency_fingerprint`, plus a **separate** `posting_idempotency_key` pair specifically for the posting action on invoices), reversal, and the exact remaining-balance math the aging/statement reports already depend on.
- `invoice_groups`/`invoice_types` catalog (`2026_09_10_000019_create_invoice_type_catalog.php`) — already a **configurable, tenant-scoped classification system** for supplier invoices with a `posting_behavior` (`expense`/`inventory`/`other`/`none`) and `is_postable`/`is_active` flags. This is directly reusable to classify Purchase-related invoice types (inventory purchase, service/operating purchase, asset purchase) without any schema change — see §7 of the implementation plan.
- `InventoryPostingService` — the WAC/quantity engine; a Goods Receipt should call it exactly the way the existing manual `stock_in` screen already does (same `type='stock_in'`, same warehouse-assignment and branch-access checks it already performs internally via `InventoryWarehouseAssignment::assertAssigned` and `FinancialActor::assertBranchAccess`).
- `UnitConversionResolver::resolve()` — purchase-unit → base-unit conversion, reading `inventory_item_unit_conversions`; this is exactly what a purchase line's "purchase unit" vs. the item's base unit needs.
- `financial_accounts` code `1500` ("Fixed Assets", `account_group=assets`) is **already seeded** by `FinancialSetupService::defaultAccounts()` (L53) — asset purchases are already representable today via `invoiceType='other'` + `debitAccountId` pointed at 1500. No new GL account is required for Phase 1 asset purchases.
- `FinanceAccess::CATALOG` (`app/Support/FinanceAccess.php:13`) — a single hardcoded permission-string array, checked against a real per-tenant `finance_role_permissions` DB table. This is the correct, already-DB-backed pattern to extend with `finance.purchases.*` strings (§14 of the implementation plan) — it is a materially better foundation than Inventory's own permission system, which is a **hardcoded, non-DB-backed** role→permission array (`InventoryAccess::ROLE_PERMISSIONS`).
- `DailyClosingSummaryService`/`DailyClosingReadinessService` already correctly key cash-effect off `supplier_payments` (never `supplier_invoices`, which is correct since invoices carry no cash effect) and already block closing on any unposted draft `journal_entries` — this generically protects Purchasing's own postings for free, with zero new closing logic required for Phase 1-3.
- Flutter: the entire `features/finance_inventory_setup/` feature-first pattern (`repositories/*_repository.dart` wrapping `DioApiClient`, `Cubit`+`Equatable State` registered via `get_it`, `StatefulWidget` screens that mostly bypass the cubit for read-heavy work and call the repository directly), plus the server-driven authorization convention (`ApiException.statusCode == 401/403` → permission-denied UI; per-record `allowedActions: List<String>` gating action buttons) — no client-side permission system exists to reinvent.
- `CashBanksScreen`'s parallel-fetch pattern (`getFinancialLocations`, `getPaymentMethods`) plus `_PaymentFormDialog`'s cash/bank + payment-method + allocation UI (already built in `supplier_profile_screen.dart`) is the exact template for a "quick purchase — pay now" screen.

## 6. Missing Components

- Any line-item table for a supplier invoice (`supplier_invoice_lines` does not exist — invoices are `subtotal`/`tax_amount`/`total_amount` header fields only).
- Any Goods-Receipt concept (`purchase_receipts`/`purchase_receipt_lines`) linking a stock-in event back to a specific invoice/line.
- Any Purchase Order concept (`purchase_orders`/`purchase_order_lines`) — no commitment-before-liability document exists.
- Any Purchase Return concept (`purchase_returns`) — reversing a received-and-invoiced purchase today would require manually reversing the invoice (existing, tested) and manually posting an offsetting stock movement (existing primitive, `return_out`, but no orchestration ties it to a specific original receipt).
- A GRNI (Goods Received Not Invoiced) accrual account/flow — does not exist and is not needed for Phase 1-3 (see the Implementation Plan §Flows).
- A `finance.purchases.*` permission set (`FinanceAccess::CATALOG` has no purchasing entries today).
- A Flutter `features/purchasing/` module, a `/finance/purchases` route, and a "المشتريات" entry in `FinanceNavigationBar` — none exist (`grep -rni "purchas" lib/` returns only unit-of-purchase item metadata, a movement-type display label, and an unused reports-menu heading string — no route, screen, cubit, or repository).
- A dedicated "quick purchase" orchestration service that calls the three existing services (Invoice, Receipt, Payment) inside one transaction with one idempotency key.

## 7. Obsolete / Superseded Documentation

- `docs/finance/FINANCE_AUDIT_AND_ARCHITECTURE.md` ("Phase 0A") states in its Executive Summary that "Purchasing, Suppliers, Expenses ... are completely missing; not incomplete, not a stub, genuinely absent from the schema." **This is now false** — `git log` shows `suppliers`/AP tables were added in a later commit ("FINANCE phase 1" / subsequent commits), and `docs/finance/FINANCE_IMPLEMENTATION_PLAN.md`'s Phase 3 (Expenses) and Phase 5 (Suppliers + AP) describe exactly the work that has since shipped — corroborated independently by `docs/finance/FINANCE_API_MAP.md`, which marks Suppliers/Supplier-Invoices/Supplier-Payments/Expenses as `Implemented`. Treat `FINANCE_AUDIT_AND_ARCHITECTURE.md` as a historical snapshot of a much earlier state, not current truth.
- `docs/finance/FINANCE_SCREEN_MAP.md` (more recent, "Phase 0.5") is accurate as of this audit and does **not** list any purchasing screen or route — consistent with this audit's own findings.
- `docs/inventory/INVENTORY_AUDIT_REPORT.md` (dated 2026-08-29) independently states "Lots/batches, suppliers, purchases/GRN, procurement — no inventory tables/routes/services found — NOT IMPLEMENTED," which is still accurate for the *inventory* side (no GRN/procurement schema exists), though it predates and doesn't cover the AP side, which was built afterward.
- No existing documentation anywhere in `docs/` describes a Purchasing/procurement architecture — this audit and its companion implementation plan are the first.

## 8. Duplication Risks

| Risk | Evidence | Mitigation required |
|---|---|---|
| A "Purchase Invoice" header table duplicating `supplier_invoices` | Building a new `purchases`/`purchase_invoices` header (Option B in the implementation plan) would create two independently-editable records for one AP liability — exactly the failure mode the prompt calls out. | Do not create a new header table. Extend `supplier_invoices` with a **child** `supplier_invoice_lines` table only (see Implementation Plan §Architecture Decision). |
| Expense vs. "service/expense-type Purchase Invoice" double-entry | `expenses` and `supplier_invoices` (invoiceType=expense) both resolve their debit account from the **same** `expense_categories` table, but there is no FK or shared record between them; `expenses.supplier_id` is a dead, unconstrained column. Two tests (`FinanceDashboardExpensesAndApTest::test_supplier_payment_is_never_counted_as_an_operating_expense`, `...is_not_double_counted_as_an_expense_in_the_ap_view`) prove the *dashboard aggregation* keeps them separate, but nothing stops an operator from entering the same real-world spend once as an Expense and once as a Purchase. | This is a workflow/training concern, not a schema bug — document it explicitly (done here) rather than attempting to enforce it in code for Phase 1. A soft UI nudge ("this supplier has open Purchase invoices — did you mean to create a Purchase instead of an Expense?") is a reasonable later-phase nicety, not a blocker. |
| Goods Receipt independently posting Inventory Asset | If a future Goods Receipt were built to call `AccountingPostingService` directly (instead of only `InventoryPostingService`), it would double-post `1100` alongside the Invoice's own posting. | The audit in §2/§3.F already confirms `stock_in` posts nothing today — the implementation plan must keep it that way for Purchasing-triggered receipts (Phase 2) and only introduce a genuinely new GRNI account/posting in Phase 4, where the Invoice's own posting logic must also change (debit GRNI instead of 1100 when a GRNI accrual already exists) to avoid a double debit to Inventory Asset. |
| Supplier Payment vs. a hypothetical separate "Payment Voucher" for purchases | The Flutter `vouchers_screen.dart`/`finance/vouchers` endpoints already exist as a **separate** domain (see `FinanceSetupRepository` L444-454) alongside supplier payments. | Purchasing's payment step must call `SupplierPaymentService` exclusively; it must not create a `voucher` for the same cash-out event. Not investigated further in this pass — flagged for the implementation team to confirm `vouchers` and `supplier_payments` don't already overlap for supplier-related cash-out (out of this audit's scope, since the prompt's evidence list did not include `VoucherService`). |

## 9. Accounting / Inventory-Integration Risks

- **`InventoryAccountingMapper`'s non-posting treatment of `stock_in` is load-bearing for the whole no-double-posting argument in this audit.** Any future, unrelated change to that mapper (e.g., "let's also post `stock_in` for completeness") would silently break Purchasing's accounting correctness. This should be called out with an explicit code comment when Purchasing ships (Implementation Plan Phase 2).
- **Two different branch-authorization helpers are in play**: `InventoryPostingService`/`WarehouseService` use `FinancialActor::assertBranchAccess`, while `WarehouseTransferService` uses `InventoryAccess::assertBranchAccess`. Since a Purchasing Goods Receipt will call `InventoryPostingService` directly (not `WarehouseTransferService`), it inherits the `FinancialActor` check — consistent with the rest of the Finance-domain code Purchasing lives in. This is a pre-existing inconsistency unrelated to Purchasing itself; noted so the implementation team doesn't mistake it for a bug introduced by this work.
- **`supplier_invoices.status`** (`draft`/`posted`/`partially_paid`/`paid`) already conflates document lifecycle and payment lifecycle in one column, by original design. Purchasing must **not** further overload this field with receipt-status values — a **separate**, additive `receipt_status` (or equivalent) column/derivation is required (Implementation Plan §Status Model), to avoid a four-way-overloaded status field.
- **Account code collision risk for GRNI**: code `2010` is already used by the seeded COA for "Sales Tax Payable" (`FinancialSetupService::defaultAccounts()` L56). Any future GRNI liability account (Phase 4+) must use an unused code (e.g. `2020`), not `2010`.
- **Mixed-type invoices (inventory + service + delivery in one document)** cannot be posted correctly today without a change to `SupplierInvoiceService::post()`, which currently always builds exactly one debit line + one credit line from the single header `debit_account_id`. Supporting mixed lines requires grouping `supplier_invoice_lines` by resolved account and emitting one debit line per distinct account — additive and backward-compatible (header-only invoices with no lines keep behaving exactly as today), but it is real service-layer work, not just a schema addition. See Implementation Plan Phase 1/2.
- **No FormRequest validation classes exist for this entire domain** (`Supplier*`/`Expense*` — validation is all inline `$request->validate()` in controllers). This is a pre-existing pattern in the codebase, not a Purchasing-specific gap, but a new Purchasing controller should decide up front whether to match this inline convention or introduce FormRequests (a minor, non-blocking style decision, called out for the implementing team).

## 10. Summary Table — What Exists vs. What Purchasing Must Add

| Component | Exists today | Purchasing action |
|---|---|---|
| Supplier master | Yes (`suppliers`) | Reuse as-is |
| AP liability + journal | Yes (`supplier_invoices` + `SupplierInvoiceService`) | Reuse header/posting; add child lines |
| AP payment + journal | Yes (`supplier_payments`/`payment_allocations` + `SupplierPaymentService`) | Reuse unchanged |
| Invoice type classification | Yes (`invoice_groups`/`invoice_types`) | Extend with purchase-flagged types |
| Stock quantity + WAC | Yes (`InventoryPostingService`) | Reuse via a new Goods Receipt caller |
| Stock-to-GL mapping | Yes, and `stock_in` is intentionally non-posting | Preserve as-is — do not add posting to `stock_in` |
| Line items / quantity / unit / warehouse on a purchase | **No** | New (`supplier_invoice_lines`) |
| Goods Receipt | **No** | New (`purchase_receipts`/`purchase_receipt_lines`) |
| Purchase Order | **No** | New, later phase |
| Purchase Return | **No** | New, later phase |
| Purchasing permissions | **No** | New (`finance.purchases.*` in existing `FinanceAccess::CATALOG`) |
| Purchasing Flutter module/route/nav | **No** | New (`features/purchasing/`, `/finance/purchases`, nav entry) |

See `PURCHASING_IMPLEMENTATION_PLAN.md` for the phased build-out, the three-option architecture comparison, the full accounting matrix, and the phase-readiness verdict.
