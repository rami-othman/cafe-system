# Finance Implementation Plan — Phase 0A Output

Planning only. Nothing in this document has been built. Every phase after 0B assumes the previous phase's acceptance criteria are met.

## Ordering Rationale

Phase 0B exists because §19 of `FINANCE_AUDIT_AND_ARCHITECTURE.md` found four small-but-load-bearing bugs (POS auth gap, missing idempotency, refund race condition, cancel-after-paid hole) that any automatic posting logic would otherwise inherit and amplify. Fixing them first is cheaper than fixing them after ten modules depend on the broken behavior. Everything from Phase 1 onward reuses the existing `financial_accounts`/`journal_entries` schema and `JournalEntryService` — no phase before Phase 6 needs a large migration.

---

## PHASE 0B — Finance Core

**Scope**: close the blockers, build `AccountingPostingService` as an orchestration-only wrapper (no new tables), add `JournalEntryService::reverse()`.

- **Backend**: add `api.token` middleware to the `orders`/`payments`/`shifts`/`discounts`/`reports`/`branches`/`menu`/`customers`/`tables` route groups in `routes/api.php` (mirroring how `/inventory/*` and `/finance/*` are already wrapped); add an `idempotency_key` column + unique-per-tenant constraint to `orders`, `payments`, `payment_refunds` (mirroring `stock_movements.idempotency_key`); add `lockForUpdate()` to `RefundController::store`'s balance check; add a `payment_status !== 'paid'` guard to `PosOrderController::cancel`; add `JournalEntryService::reverse(int $entryId)` (creates a new posted entry with debit/credit swapped, linked via a new nullable `journal_entries.reversal_of_id` self-FK); create `App\Services\AccountingPostingService` with method stubs only (`postSale`, `postRefund`, `postExpense`, `postSupplierInvoice`, `postSupplierPayment`, `postInventoryAdjustment`, `postWaste`, `postCashTransfer`) — each stub validates its input shape and calls `JournalEntryService::createDraft()` + `::post()`, but is **not yet wired into any caller** in this phase.
- **Database**: one small migration — `orders.idempotency_key`, `payments.idempotency_key`, `payment_refunds.idempotency_key` (nullable, unique per tenant where not null, matching the existing `stock_movements` pattern exactly); `journal_entries.reversal_of_id` nullable self-FK; extend `journal_entries.status` to allow `'reversed'`.
- **Frontend**: none required for this phase (no new screens); existing `finance_inventory_setup` screens continue to work unchanged.
- **APIs**: no new public endpoints; `pay`/`refund` request contracts gain an optional `idempotencyKey` field (backward compatible — omit and it behaves as today, minus the fixed bugs).
- **Integrations**: none yet — `AccountingPostingService` is built but not called from any business controller in this phase, so nothing changes behaviorally for POS/Inventory yet, keeping this phase low-risk.
- **Migration risks**: low. All new columns are nullable additions; the `api.token` middleware change is the only behaviorally-visible change and must ship with the corresponding Flutter POS/Orders/Reports repositories updated to send a Bearer token (check whether they already do — `DioApiClient` already supports `setBearerToken()`; confirm which repositories currently omit it before flipping the middleware on, to avoid breaking the live POS UI).
- **Tests**: fix the 4 currently-failing tests as a byproduct where they overlap this phase's scope (`PosApiSmokeTest`'s 401 will need real auth headers once the middleware is added — this is expected and correct, not a regression); add feature tests for: idempotent-replay of `pay`/`refund`/(new expense endpoint later), concurrent-refund race (now blocked), cancel-after-paid (now rejected), `JournalEntryService::reverse()` (balances flip, original stays posted, new entry links back).
- **Acceptance criteria**: full backend suite green including the 4 currently-failing tests (or their replacements); a retried `pay`/`refund` request with the same idempotency key returns the original result, not a duplicate; two concurrent refund requests against the same payment cannot both succeed beyond the true remaining balance; a paid order cannot be cancelled without an explicit reversal step; `AccountingPostingService` stub methods each have a passing unit test proving they produce a balanced draft and post it.
- **Dependencies**: none (this is the first phase).

---

## PHASE 1 — Finance Settings + Chart of Accounts

**Scope**: extend the existing, working `financial_accounts_screen.dart` rather than rebuild it.

- **Backend**: extend `FinancialAccountController`/`Service` to accept `account_group`/`normal_balance`/`parent_account_id` on update (currently store-only); add a `search` query-param handler it already half-supports per the audit.
- **Database**: none.
- **Frontend**: `financial_accounts_screen.dart` — make the edit form's group/normal-balance/parent fields real controls; wire the existing `setAccountStatus` call into an activate/deactivate button; send `search` to the backend. Route-alias `/finance/accounts` → same screen (FIN-18).
- **APIs**: extend existing `PATCH finance/accounts/{account}` payload; no new endpoints.
- **Tests**: extend `FinancialInventoryFoundationApiTest` for group/parent editing and status toggling.
- **Acceptance criteria**: an accountant can fully edit a non-system-protected account's group/balance-side/parent and activate/deactivate it from the UI; system-protected accounts remain locked.
- **Dependencies**: Phase 0B not strictly required for this phase (purely additive to existing working code) but should ship after it for sequencing clarity.

---

## PHASE 2 — Cash Accounts + Payment Methods

**Scope**: first genuinely new tables.

- **Backend**: new `CashAccountController`/`Service`, new `PaymentMethodController`/`Service`. `payments.method` gets a new nullable `payment_method_id` FK (keep the string column for one deprecation cycle, per the audit's recommendation).
- **Database**: `cash_accounts`, `bank_accounts` (or one polymorphic `financial_locations` table with a `type` column — recommend two separate tables for clarity, matching the schema's existing preference for explicit tables over polymorphism, e.g. `warehouse_transfer_receipts` vs a generic "events" table), `payment_methods`, each linked to a `financial_accounts` row.
- **Frontend**: FIN-03/04/05 (Cash & Banks, Details, Transfer) built for the first time; FIN-20 gains payment-method-to-account mapping UI.
- **APIs**: 🆕 `GET finance/cash-accounts`, `GET finance/cash-accounts/:id/transactions`, `POST finance/cash-transfers`, `GET/POST finance/payment-methods`.
- **Integrations**: `AccountingPostingService.postCashTransfer()` wired to the new transfer endpoint (first real caller of the Phase 0B service).
- **Migration risks**: low-medium — seeding default cash accounts (Main Safe, Cash Drawer, Bank) per tenant should reuse `FinancialSetupService`'s existing idempotent `updateOrInsert` pattern, not a new seeding mechanism.
- **Tests**: cash-transfer posts a balanced entry; cross-tenant cash-account isolation; payment-method CRUD tenant scoping.
- **Acceptance criteria**: Cash & Banks screen shows real balances derived from posted journal entries (not a cached/duplicated number); a transfer between two accounts is reflected correctly on both.
- **Dependencies**: Phase 0B (`AccountingPostingService` must exist).

---

## PHASE 3 — Expenses

**Scope**: the first real business object that posts automatically.

- **Backend**: new `ExpenseController`/`Service` with draft→pending_approval→approved→paid/rejected lifecycle; wires `AccountingPostingService.postExpense()` on transition to paid.
- **Database**: `expenses`, `expense_categories` (thin wrapper over existing 6100-6190 accounts).
- **Frontend**: FIN-06/07/08.
- **APIs**: 🆕 `GET/POST finance/expenses`, `PATCH finance/expenses/:id`, `PATCH finance/expenses/:id/status`.
- **Integrations**: first live `AccountingPostingService.postExpense()` caller.
- **Migration risks**: low.
- **Tests**: expense approval-then-payment posts correct debit/credit; branch-scoped manager cannot approve another branch's expense; attempting to post an expense against an inactive/system-protected-in-the-wrong-way account is rejected.
- **Acceptance criteria**: an approved, paid expense appears correctly in Finance Overview's Expenses KPI and in Financial Transactions (FIN-02).
- **Dependencies**: Phase 0B, Phase 2 (paid-from-account selection needs `cash_accounts` to exist).

---

## PHASE 4 — POS + Shift Finance Integration

**Scope**: the highest-risk phase — wires real money-in-motion to the ledger for the first time.

- **Backend**: `PaymentController::pay()` calls `AccountingPostingService.postSale()` inside its existing transaction; `RefundController::store()` calls `postRefund()`; fix `ShiftController::close()`'s expected-cash formula to subtract `payment_refunds` (the bug found in the audit, §12/§19).
- **Database**: none new (reuses Phase 0B's idempotency columns).
- **Frontend**: no new screens; Daily Closing (FIN-16, Phase 9) will consume this data later.
- **APIs**: no new endpoints; existing `pay`/`refund`/`shift close` responses unchanged in shape.
- **Integrations**: `postSale()` debits a payment-method-mapped cash/card-clearing account and credits Sales Revenue (4000) net of discounts (debit Discounts Given 4010) — **decide explicitly at this phase** whether COGS posting (credit Inventory Asset / debit COGS) waits for the dormant recipe pipeline to be finished or uses an interim estimate; do not silently skip it.
- **Migration risks**: **highest in the plan** — every POS sale now has a side effect it didn't have before; feature-flag this behind a tenant-level setting if possible, and roll out to one demo tenant before general availability.
- **Tests**: a full POS sale produces a balanced journal entry; a refund produces a correcting entry; a failed posting step rolls back the payment too (not just logs an error); shift close's cash-difference is now refund-aware.
- **Acceptance criteria**: `PosApiSmokeTest` (extended) shows a `journal_entries` row after payment and after refund with correct totals; Finance Overview's Net Sales/Gross Profit KPIs now source from real posted data instead of the `ReportsOverviewController`'s independent aggregation (or the two are proven to agree, as a transitional check).
- **Dependencies**: Phase 0B (idempotency + reverse), Phase 2 (payment-method→account mapping), Phase 3 (Discounts Given/COGS account behavior established).

---

## PHASE 5 — Suppliers + Accounts Payable

- **Backend**: new `SupplierController`, `SupplierInvoiceController`, `SupplierPaymentController`/services; `AccountingPostingService.postSupplierInvoice()`/`postSupplierPayment()` wired.
- **Database**: `suppliers`, `supplier_invoices`, `supplier_payments`, `payment_allocations`.
- **Frontend**: FIN-09/10/11/12.
- **APIs**: 🆕 full CRUD under `finance/suppliers*`.
- **Migration risks**: low-medium — decide whether to migrate `inventory_items.preferred_supplier_name` free text into real `suppliers` rows (recommended, one-time backfill script) or leave it as a legacy display field.
- **Tests**: invoice→partial payment→remaining balance math (reuse the fixed, now-locked refund-balance pattern from Phase 0B); supplier statement totals match posted journal entries exactly.
- **Acceptance criteria**: Supplier Financial Profile's outstanding-balance figure matches a manually-computed sum of unpaid invoice remainders.
- **Dependencies**: Phase 0B, Phase 2.

---

## PHASE 6 — Inventory Accounting Integration

- **Backend**: `StockCountService::post()` (variance) and `InventoryPostingService::post()` (where `type='waste'`) each call `AccountingPostingService.postInventoryAdjustment()`/`postWaste()` respectively, using the movement's own `unit_cost`/`total_cost` — **never recomputed, always read from Inventory** (the audit's core non-negotiable rule, §4/§16 of the audit doc).
- **Database**: none new.
- **Frontend**: none new (feeds FIN-01/FIN-17 KPIs).
- **Migration risks**: medium — this changes behavior for two flows the Inventory module already relies on (`docs/inventory/` reports document this module in depth); coordinate with whoever owns Inventory before wiring, and confirm posting failure does not block the inventory movement itself from succeeding (or does, by design — this must be an explicit decision, not an accident).
- **Tests**: a posted waste movement produces a debit to Waste/Inventory Variance (5010) and credit to Inventory Asset (1100) for the exact `total_cost` on the movement row; a stock-count variance posts correctly in both directions (surplus vs shortage).
- **Acceptance criteria**: Inventory's own existing tests remain green; new tests confirm ledger totals match `stock_movements.total_cost` sums exactly for the period.
- **Dependencies**: Phase 0B.

---

## PHASE 7 — Financial Transactions + Journal UI

- **Frontend-heavy phase**: FIN-02 (Transactions list), FIN-14/15 extensions (multi-line entries, description field, reversal action, fix the details-dialog data-source bug found in the audit §5/§12).
- **Backend**: 🆕 `GET finance/transactions` (unifies reads across `journal_entries`, tagged by `source_type`).
- **Tests**: transactions list correctly reflects entries from every poster built in Phases 2-6.
- **Acceptance criteria**: an accountant can find any Phase 2-6 transaction from one screen and drill into its journal entry.
- **Dependencies**: Phases 2-6 (needs real posted data to be meaningful).

---

## PHASE 8 — Reconciliation

- **Backend/Database**: `reconciliations`, `reconciliation_lines`.
- **Frontend**: FIN-13.
- **Acceptance criteria**: a cash-account reconciliation session correctly flags matched vs unmatched lines.
- **Dependencies**: Phase 2 (needs `cash_accounts`/`bank_accounts`), enough transaction volume from Phases 4-6.

---

## PHASE 9 — Daily Closing

- **Backend**: extend `DailyReportController`'s existing per-day aggregation (don't fork a third implementation, per audit §12) with expenses/supplier-payments/waste/adjustments data; route it and provide the real `DailyReportCubit` at the shell level (it exists in DI already but is currently unrouted — confirmed dead code, audit §5).
- **Frontend**: FIN-16, extending `daily_operational_report_screen.dart` rather than a green-field build.
- **Acceptance criteria**: every blocking condition listed in the audit's FIN-16 spec (open shifts, pending expense approvals, out-of-tolerance cash variance, unreviewed count variances, unposted draft entries) correctly prevents day closure and is individually visible to the manager closing the day.
- **Dependencies**: Phases 3, 4, 5, 6 (needs expenses, sales postings, supplier payments, waste/adjustments all live).

---

## PHASE 10 — Finance Dashboard

- **Frontend**: FIN-01 in full (charts, alerts) — the KPI/query plumbing was already built incrementally in earlier phases; this phase is primarily the visual assembly.
- **Acceptance criteria**: every KPI/chart on the Overview screen sources from a real, already-tested query from an earlier phase — no new financial calculation logic is written in this phase.
- **Dependencies**: Phases 1-9.

---

## PHASE 11 — Financial Reports

- **Backend/Database**: `accounting_periods` (finally needed here for "as of" period bounding); P&L/Trial Balance/GL/Balance Sheet/Cash Flow/Supplier Aging report endpoints.
- **Frontend**: FIN-17, FIN-19.
- **Acceptance criteria**: Trial Balance's total debits equal total credits across all posted entries tenant-wide (the fundamental correctness check for the whole ledger); P&L figures reconcile against Finance Overview's KPIs for the same period.
- **Dependencies**: all prior phases (this is the integration proof-point for everything posted so far).

---

## PHASE 12 — Permissions + Approvals

- **Backend**: extend `InventoryAccess`'s pattern (or the shared `Access` class if generalized) with the `finance.*` permission strings proposed in the audit §18; retire `FinancialActor`'s hardcoded gate in favor of it; add approval-limit configuration for Branch Manager expense approval (Phase 3's approval step gets a real ceiling instead of unlimited).
- **Frontend**: role-aware screen/action visibility (currently the sidebar has none at all, per audit §5 — this phase is where that changes for Finance specifically, without necessarily fixing the rest of the app's sidebar).
- **Acceptance criteria**: a Cashier gets a 403 (not a confusing empty screen) attempting any Finance write beyond their own shift; a Branch Manager cannot approve an expense above their configured limit.
- **Dependencies**: could technically run earlier (Phase 3 onward each individually need *some* permission check), but is scoped as its own phase here to formalize the pattern once real usage from Phases 3-9 reveals what granularity is actually needed — avoids guessing permission strings before they're exercised.

---

## PHASE 13 — Seeders + E2E + Financial Integrity Audit

- **Backend**: a `FinanceDemoSeeder` (expenses, supplier invoices/payments, a few weeks of realistic posted transactions) — reuse `ReportsOverviewSeeder`'s existing 14-day synthetic-order pattern as the template rather than inventing a new seeding style.
- **Tests**: a comprehensive E2E suite exercising every posting path end to end; a "financial integrity audit" test that asserts, tenant-wide: every posted journal entry balances, every `expenses`/`supplier_payments` row with `status=paid` has a corresponding posted journal entry, and total debits equal total credits across the whole ledger.
- **Acceptance criteria**: this final integrity test passes against the full demo dataset and becomes a permanent regression test run on every future Finance change.
- **Dependencies**: all prior phases.

---

## Exact Scope for the NEXT Phase Only (Phase 0B)

This is the only phase authorized to begin after this Phase 0A review. Restated precisely:

1. Add `api.token` middleware to the currently-unauthenticated route groups (`branches`, `reports/*`, `shifts/*`, `menu/*`, `customers`, `tables`, `pos/state`, `discounts*`, `orders*`) — **first confirm which Flutter repositories already send a Bearer token** before flipping this on, to avoid breaking the live POS UI on day one.
2. Add nullable, tenant-unique `idempotency_key` to `orders`, `payments`, `payment_refunds`.
3. Add `lockForUpdate()` to `RefundController::store`'s remaining-balance read.
4. Guard `PosOrderController::cancel` against an already-paid order.
5. Add `JournalEntryService::reverse()` + `journal_entries.reversal_of_id` + `'reversed'` status.
6. Create `AccountingPostingService` with the eight named stub methods, each producing a balanced draft+post through the *existing, unchanged* `JournalEntryService` — not called from any other controller yet.
7. Tests: fix/replace the 4 currently-failing tests as they intersect this scope; add new tests for every item above.

**Explicitly out of scope for Phase 0B**: any new UI, any new table beyond the three idempotency columns and one self-FK, wiring `AccountingPostingService` into POS/Refund/Expense (that starts at Phase 4/3 respectively), Suppliers, Expenses, Cash Accounts.
