# Finance UI Map — Phase 0A

Investigation and design only. No screens were built in this phase.

## 1. Finance Navigation

The app currently has **no dedicated "Finance" sidebar tab.** What exists today is `finance_inventory_setup`, a combined Finance-setup + Warehouse-setup feature reachable via a single sidebar entry ("تهيئة المالية والمخازن", between Inventory Management and Reports). Its `financial_accounts_screen.dart` and `journal_entries_screen.dart` are real, working Finance screens — just filed under a "setup" label rather than a "Finance" section. The Reports screen (`reports_overview_screen.dart`) already has a static "Coming next" category grid that anticipates **"Financial Reports"** and **"Purchasing & Suppliers"** as future tiles — i.e. the intended taxonomy already partially exists in the codebase, this task is filling in what those tiles should lead to.

**Recommendation:** add one new top-level sidebar entry, **"المالية" (Finance)**, positioned after Inventory Management and before/beside the existing "تهيئة المالية والمخازن" entry. Do not delete or rename the existing setup entry in this phase (no redesign mandate) — instead:
- The new Finance section **absorbs** Chart of Accounts and Journal Entries as in-place route aliases (same screens, reachable from both the old setup entry and the new Finance nav, until a later phase formally retires the old entry).
- Warehouses setup stays where it is (`تهيئة المالية والمخازن` → Warehouses) since it is an Inventory concern, not Finance — this UI map does not propose moving it.
- Financial Reports becomes reachable both from the new Finance nav and from Reports' existing "Coming next" tile (same screen, two entry points — consistent with how Journal Entries would be reachable from two places too).

```
المالية (Finance)                          existing نav (unchanged)
├── نظرة عامة           Overview            [FIN-01, NEW]
├── الحركات المالية      Transactions        [FIN-02, NEW]
├── النقدية والبنوك       Cash & Banks        [FIN-03/04/05, NEW]
├── المصروفات            Expenses            [FIN-06/07/08, NEW]
├── الموردون والمستحقات   Suppliers/Payables  [FIN-09/10/11/12, NEW]
├── التسويات             Reconciliation      [FIN-13, NEW, later phase]
├── القيود المحاسبية      Journal Entries     [FIN-14/15, EXTEND — alias of existing screen]
├── الإغلاق اليومي        Daily Closing       [FIN-16, NEW]
├── التقارير المالية      Financial Reports   [FIN-17, NEW — also reachable from Reports tile]
├── دليل الحسابات         Chart of Accounts   [FIN-18, EXTEND — alias of existing screen]
├── الفترات المحاسبية      Accounting Periods  [FIN-19, NEW, later phase]
└── إعدادات المالية        Finance Settings    [FIN-20, EXTEND — absorbs existing setup dashboard]
```

RTL is mandatory for the whole section, matching the existing pattern: every `finance_inventory_setup` screen already wraps itself individually in `Directionality(textDirection: TextDirection.rtl, ...)` (rather than relying on the shell's route-prefix RTL logic, which currently only triggers for `/inventory/*`). New Finance screens should either extend the shell's RTL route-matching to include `/finance/*`, or follow the same per-screen `Directionality` wrap already established — **prefer extending the shell's route match** (one-line change, removes the need to repeat the wrapper on every new screen) but this is a minor implementation detail for the next phase, not a blocker.

## 2. Screen Inventory

| ID | Screen | Status | Route |
|---|---|---|---|
| FIN-01 | Finance Overview | NEW | `/finance` |
| FIN-02 | Financial Transactions | NEW | `/finance/transactions` |
| FIN-03 | Cash & Banks | NEW | `/finance/cash-banks` |
| FIN-04 | Cash Account Details | NEW | `/finance/cash-banks/:id` |
| FIN-05 | Cash Transfer | NEW (dialog) | modal from FIN-03/04 |
| FIN-06 | Expenses | NEW | `/finance/expenses` |
| FIN-07 | Expense Details | NEW | `/finance/expenses/:id` |
| FIN-08 | Create/Edit Expense | NEW (dialog) | modal from FIN-06/07 |
| FIN-09 | Suppliers & Payables | NEW | `/finance/suppliers` |
| FIN-10 | Supplier Financial Profile | NEW | `/finance/suppliers/:id` |
| FIN-11 | Supplier Invoice | NEW (dialog) | modal from FIN-10 |
| FIN-12 | Supplier Payment | NEW (dialog) | modal from FIN-10 |
| FIN-13 | Reconciliation | NEW, later phase | `/finance/reconciliation` |
| FIN-14 | Journal Entries | **EXTEND_EXISTING** | `/finance/journal-entries` (alias of `/finance-inventory-setup/journal-entries`) |
| FIN-15 | Journal Entry Details | **EXTEND_EXISTING** (fix data-source bug) | dialog within FIN-14, same as today |
| FIN-16 | Daily Closing | NEW | `/finance/daily-closing` |
| FIN-17 | Financial Reports | NEW | `/finance/reports` |
| FIN-18 | Chart of Accounts | **EXTEND_EXISTING** | `/finance/accounts` (alias of `/finance-inventory-setup/accounts`) |
| FIN-19 | Accounting Periods | NEW, later phase | `/finance/periods` |
| FIN-20 | Finance Settings | **EXTEND_EXISTING** | `/finance/settings` (absorbs setup dashboard content) |

No screen in the original 20-item template was removed; three (`FIN-14`, `FIN-18`, and the setup-dashboard portion of `FIN-20`) already exist and only need routing aliases + the fixes noted in §4, not new implementation.

## 3–4. Detailed Specification Per Screen (incl. reuse notes)

Legend for **Data source**: which existing table(s) the screen reads; **Required APIs**: existing (✅) vs net-new (🆕); **Existing components**: from `lib/shared/` + `management_ui.dart` (the established `finance_inventory_setup` toolkit).

### FIN-01 — Finance Overview
- **Purpose**: single-page financial health snapshot, entry point to the whole Finance section.
- **Roles/permissions**: `finance.reports.view_all` (Accountant/Owner); Branch Manager sees `finance.reports.branch_summary` (branch-scoped only); Cashier has no access to this screen.
- **Data source**: `orders`, `payment_refunds`, `journal_entries`/`journal_entry_lines` (expenses), `stock_movements` (waste/loss), `shifts` (variance alerts). Reuse `ReportsOverviewController::period()`'s existing sales/refund and expense-ledger query logic rather than writing new SQL (§10/§12 of the audit doc).
- **Required APIs**: 🆕 `GET /finance/overview` (new controller method, but should internally reuse the exact query helpers `ReportsOverviewController` already has — extract them into a shared query class first).
- **KPIs**: Net Sales, Gross Profit, Expenses, Net Operating Profit, Cash Balance, Supplier Payables (last two are 🆕 — Cash Balance needs `cash_accounts` to exist, Supplier Payables needs `suppliers`/`supplier_invoices`; both should show "Not available yet" gracefully, exactly like `ReportsOverviewController`'s existing `available`/`reason` pattern on its KPI objects — reuse that convention).
- **Charts**: Revenue vs Expenses, Sales vs COGS vs Gross Profit, Expense Distribution, Payment Methods, Cash Flow, Branch Performance — reuse `_SalesTrendCard`/`_BranchComparisonCard`'s existing custom-paint chart widgets from `reports_overview_screen.dart` as the base, don't build a new charting primitive.
- **Operational alerts**: pending expenses, supplier invoices due, shift cash variance, unreconciled payments, high waste/loss — reuse `_ExceptionsCard`'s existing pattern (already surfaces cash-diff shifts + low-stock items).
- **Filters**: date range, branch, comparison period — reuse `ReportsOverview`'s existing period/branch filter UI verbatim.
- **Loading/Empty/Error**: `ManagementMessage` (loading spinner / "no data for this period" / retry-on-error) — same pattern as every other management screen.
- **Row actions / primary actions**: drill into any KPI navigates to FIN-02 (Transactions) pre-filtered; drill into Expenses KPI navigates to FIN-06.

### FIN-02 — Financial Transactions
- **Purpose**: unified ledger-level list of every posted transaction (sales, refunds, expenses, supplier payments, journal entries) — the "show me everything that moved money" screen.
- **Roles**: Accountant, Owner. Manager sees branch-scoped.
- **Data source**: `journal_entries` (once posting exists) unioned conceptually with `payments`/`payment_refunds` for the pre-Finance-Core period (so history isn't empty on day one).
- **APIs**: 🆕 `GET /finance/transactions` (filters: date, branch, source_type, account, amount range).
- **Table columns**: date, source type (Sale/Refund/Expense/Supplier Payment/Manual JE), description, account, debit, credit, branch, status, actor.
- **Row actions**: view source (deep-link to the originating order/expense/supplier invoice), view journal entry detail (FIN-15).
- **Filters**: reuse `ManagementFilterBar` — date range, branch, source type, account, status.
- **Existing components**: `ManagementTableShell`, `ManagementFilterBar`, `ManagementBadge` for status/source-type pills.

### FIN-03 — Cash & Banks
- **Purpose**: at-a-glance list of every cash drawer and bank account.
- **Roles**: Branch Manager (own branch cash), Accountant/Owner (all).
- **Data source**: 🆕 `cash_accounts`/`bank_accounts` (proposed in the audit doc §16), each linked to a `financial_accounts` row whose balance is derived from posted `journal_entry_lines`.
- **APIs**: 🆕 `GET /finance/cash-accounts`.
- **Cards**: Main Cash, Bar Cash, Petty Cash, Bank accounts — each shows current balance, today's incoming, today's outgoing, pending-reconciliation count. Use `ManagementKpiCard` per account.
- **Actions**: view transactions (→ FIN-04), cash in, cash out, transfer (→ FIN-05), reconcile (→ FIN-13).
- **Empty state**: if no `cash_accounts` exist yet (pre-setup), show a call-to-action to Finance Settings (FIN-20) to create the default Main Safe/Cash Drawer/Bank rows — this mirrors the existing setup-readiness pattern in `finance_setup_dashboard_screen.dart`.

### FIN-04 — Cash Account Details
- **Purpose**: transaction ledger for one cash/bank account.
- **Data source**: `journal_entry_lines` filtered to the account's `financial_account_id`.
- **APIs**: 🆕 `GET /finance/cash-accounts/:id/transactions`.
- **Table columns**: date, description, source, debit, credit, running balance.
- **Primary actions**: cash in, cash out, transfer, export (disabled until an export mechanism exists elsewhere in the app — none does today).

### FIN-05 — Cash Transfer
- **Purpose**: move money between two cash/bank accounts (e.g. drawer → safe).
- **Form**: from account, to account, amount, date, notes.
- **Validation**: from ≠ to, amount > 0, sufficient balance (soft warning, not a hard block, matching the app's general validation tone elsewhere).
- **Resulting flow**: `AccountingPostingService.postCashTransfer()` → one balanced journal entry (debit destination, credit source).
- **Component**: `AppDialog` + `AppTextField`, matching the existing dialog pattern in `journal_entries_screen.dart`'s draft form (not a full page).

### FIN-06 — Expenses
- **Purpose**: list/manage all expense records.
- **Roles**: Cashier — none. Branch Manager — own branch, create + approve up to a limit. Accountant/Owner — all branches, full control.
- **Data source**: 🆕 `expenses` table (proposed §16 of audit doc).
- **APIs**: 🆕 `GET/POST /finance/expenses`, `PATCH /finance/expenses/:id`, `PATCH /finance/expenses/:id/status`.
- **KPIs**: Today, This Month, Pending Approval, Unpaid — `ManagementKpiCard` row, same visual pattern as the existing screens' header area.
- **Filters**: period, branch, category, status, payment method, supplier, employee — `ManagementFilterBar`.
- **Table columns**: date, branch, category, amount, status, payment method, supplier (if any), created by.
- **Row actions**: view (→FIN-07), edit (draft/pending only), approve/reject (Manager/Accountant), mark paid.
- **Primary action**: "إضافة مصروف" → FIN-08.

### FIN-07 — Expense Details
- **Purpose**: single expense record, full detail + audit history.
- **Data source**: `expenses` + `activity_logs` (reuse `OperationalAuditService`, same as every other module).
- **Sections**: header (amount/status/category), payment info, attachment preview, audit timeline (mirror `transfers_screen.dart`'s existing audit-timeline pattern from the Inventory Transfers detail screen — same visual language).

### FIN-08 — Create/Edit Expense
- **Form fields** (exactly as specified in the prompt): date, branch, category, amount, tax (optional), payment status, payment method, paid-from account, supplier (optional), cost center (optional, only if that table is built), description, attachment, notes.
- **Validation**: amount > 0, category required, if payment status = paid then paid-from-account required, branch must belong to tenant + actor's allowed branches (reuse `assertBranchAccess` pattern).
- **Resulting flow**: on submit with status=paid → `AccountingPostingService.postExpense()` (debit the mapped expense account, credit the paid-from cash/bank account) inside the same transaction as the `expenses` row insert.
- **Component**: `AppDialog`, reuse `AppTextField`/dropdown patterns already in `financial_accounts_screen.dart`'s create form.

### FIN-09 — Suppliers & Payables
- **Purpose**: supplier master list with AP summary.
- **Data source**: 🆕 `suppliers`, `supplier_invoices`.
- **KPIs**: Total Payables, Overdue, Suppliers count.
- **Table columns**: name, outstanding balance, overdue amount, last purchase date, status.
- **Primary action**: "إضافة مورد".

### FIN-10 — Supplier Financial Profile
- **Purpose**: everything about one supplier's money relationship.
- **KPIs** (as specified): outstanding balance, total purchases, total paid, overdue balance.
- **Tabs**: Invoices, Payments, Statement, Purchases (Purchases tab stays empty/"not available" until a Purchasing module exists — do not fake data here).
- **Primary actions**: "فاتورة جديدة" (→ FIN-11), "دفعة جديدة" (→ FIN-12).

### FIN-11 — Supplier Invoice
- **Form**: supplier (pre-filled from FIN-10), invoice number, date, due date, amount, line items (optional detail, or a single total if Purchasing isn't built yet), notes, attachment.
- **Resulting flow**: `AccountingPostingService.postSupplierInvoice()` (debit an expense/inventory account depending on invoice type, credit Accounts Payable 2000).

### FIN-12 — Supplier Payment
- **Form**: supplier, amount, paid-from account, date, allocation (which open invoices this pays, partial allowed) — reuse the exact "remaining balance" math pattern `RefundController` already uses for payment-vs-refund totals, **but fix its missing row-lock** (§12 of the audit doc) before this screen's backend goes live, since the same race condition would otherwise apply here.
- **Resulting flow**: `AccountingPostingService.postSupplierPayment()` + `payment_allocations` rows (debit AP, credit cash/bank).

### FIN-13 — Reconciliation (later phase)
- **Purpose**: match bank/cash statement lines against posted transactions.
- **Deferred**: no `reconciliations` table exists yet; build after Cash & Banks (FIN-03/04) and enough posting volume exists to reconcile against.

### FIN-14 — Journal Entries — **EXTEND_EXISTING**
Already implemented at `lib/features/finance_inventory_setup/views/journal_entries_screen.dart`, reachable, functional (list/create-draft/post against real `finance/journal-entries` endpoints). Alias its route under `/finance/journal-entries`. Required extensions (not a rebuild):
- Multi-line entry support (currently hardcoded to exactly 2 lines) and a description field on the draft form.
- Add a "reverse" action once `JournalEntryService.reverse()` exists (net-new backend method, §11/§19 of the audit doc).
- **Roles**: Accountant/Owner only (matches the prompt's "restricted to appropriate roles" requirement) — today it's gated only by `FinancialActor`'s owner/manager check; tighten to a dedicated `finance.journal_entries.*` permission string once §18's permission work lands.

### FIN-15 — Journal Entry Details — **EXTEND_EXISTING, has a live bug to fix**
The "تفاصيل" dialog in `journal_entries_screen.dart` currently reads `entry.lines` off the list-summary object, which the backend's list endpoint never populates — `FinanceSetupRepository.getJournalEntry(id)` exists but is never called (confirmed by direct code read, §5 of the audit doc). **Fix**: call `getJournalEntry(id)` when opening the details dialog. Show: account, debit, credit, cost center (once it exists), source, created by, posted by, audit history (reuse `OperationalAuditService` records for this entry, same pattern as FIN-07's audit timeline).

### FIN-16 — Daily Closing
- **Purpose**: the strong operational end-of-day screen the prompt asks for. **Note**: `daily_operational_report_screen.dart` already exists with an `expectedCash` KPI but is currently **not routed/reachable** (dead code, confirmed §5 of audit doc) and lacks opening/actual cash and shift metadata — it is the closest starting point but needs real extension, not a green-field build.
- **Shows**: POS sales, Cash, Card, Other payments, Discounts, Refunds, Expenses, Supplier payments, Cash in/out, Opening cash, Expected cash, Actual cash, Cash difference, Waste, Inventory adjustments, Open shifts, Pending approvals, Unposted/invalid transactions.
- **Data source**: `orders`/`payments`/`payment_refunds` (reuse `DailyReportController`'s existing per-day aggregation rather than writing a third implementation, per §12 of the audit doc — this screen should call the *same* underlying query helpers, extracted into a shared service), `shifts`, `expenses` (once built), `stock_movements` (`type='waste'`, `type='stock_count_variance'`).
- **Blocking conditions for closing the day** (must resolve `ShiftController::close`'s refund-omission bug first, §12/§19 of audit doc, or this screen will show a wrong number): any shift still open, any expense in `pending_approval` status, any cash-difference beyond a configurable tolerance, any `stock_count_variance` line still `needs_manager_review`, any unposted draft journal entry dated that day. Non-blocking but flagged: waste value above a configurable threshold.
- **Roles**: Branch Manager (own branch, can close), Accountant/Owner (all branches).

### FIN-17 — Financial Reports
- **Purpose**: P&L, Trial Balance, General Ledger, Balance Sheet, Cash Flow, Supplier Statement/Aging — the formal report set.
- **Reachable from**: new Finance nav AND the existing Reports screen's "Financial Reports" placeholder tile (`reports_overview_screen.dart`'s `_BrowseCategories` grid already names this tile — wire it here instead of leaving it "Coming next").
- **Data source**: `journal_entries`/`journal_entry_lines` grouped by `financial_accounts.account_group`/`normal_balance` — this is the first screen that genuinely needs `accounting_periods` to exist (to bound "as of" dates meaningfully) and needs real posting volume to be non-empty, so it is realistically a later-phase screen even though it's listed here for completeness.
- **Roles**: Accountant/Owner only.

### FIN-18 — Chart of Accounts — **EXTEND_EXISTING**
Already implemented at `financial_accounts_screen.dart`. Alias under `/finance/accounts`. Required extensions: expose `account_group`/`normal_balance`/`parent_account_id` as real editable fields (today they're copied, not editable, per §5 of the audit doc); wire the existing-but-unused `setAccountStatus` activate/deactivate control into the UI; send the `search` query param to the backend instead of client-side-only filtering.

### FIN-19 — Accounting Periods (later phase)
- **Purpose**: open/close/lock monthly periods, block postings into locked periods.
- **Deferred**: no `accounting_periods` table exists; build once posting volume makes period-locking meaningful (roughly aligned with Reconciliation, FIN-13).

### FIN-20 — Finance Settings — **EXTEND_EXISTING**
Absorbs `finance_setup_dashboard_screen.dart`'s existing readiness checklist (accounts ready / central warehouse ready / branch coverage ready — keep as-is, it's correct and working) and adds: default cash/bank account configuration, payment-method-to-ledger-account mapping (🆕, needed before FIN-03 can show real cards), expense category management (thin wrapper over `financial_accounts` where `account_group='expenses'`), fiscal year start date (feeds `financial_settings`, §16 of audit doc).

## 5. Data/API Mapping Summary

See the ✅/🆕 markers per screen above. Every 🆕 endpoint should be added under the existing `Route::prefix('finance')->middleware('api.token')->group(...)` block in `routes/api.php` — **do not** repeat the auth gap documented in §13/§19 of the audit doc; every new Finance route must carry `api.token` from day one.

## 6. Roles and Permissions Per Screen

| Screen | Cashier | Branch Manager | Accountant | Owner |
|---|---|---|---|---|
| FIN-01 Overview | — | branch-scoped | full | full |
| FIN-02 Transactions | — | branch-scoped | full | full |
| FIN-03/04/05 Cash & Banks | view own shift drawer only | branch cash | full | full |
| FIN-06/07/08 Expenses | — | create + approve (branch, limit) | full | full |
| FIN-09/10/11/12 Suppliers | — | view only | full | full |
| FIN-13 Reconciliation | — | — | full | full |
| FIN-14/15 Journal Entries | — | — | full | full |
| FIN-16 Daily Closing | — | branch (close) | all branches | all branches |
| FIN-17 Reports | — | branch summary | full | full |
| FIN-18 Chart of Accounts | — | — | full | full |
| FIN-19 Periods | — | — | manage | manage |
| FIN-20 Settings | — | — | view | manage |

## 7. User Actions → Business/Accounting Flow

```
Create Expense (paid)      → expenses row → AccountingPostingService.postExpense()
                             → journal_entries (draft→posted, debit expense account /
                               credit cash account) → Financial Transactions (FIN-02),
                               Finance Overview KPIs, Financial Reports

POS Sale                    → order completed → payment recorded → (once built) inventory
                             consumption → cost value received FROM Inventory (never
                             recomputed in Finance) → AccountingPostingService.postSale()
                             → journal_entries → reports

Refund                      → payment_refunds row → AccountingPostingService.postRefund()
                             → journal_entries (debit Sales Returns 4020, credit cash/card
                               clearing) → reports

Supplier Payment             → supplier_payments + payment_allocations rows
                             → AccountingPostingService.postSupplierPayment()
                             → journal_entries (debit Accounts Payable, credit cash/bank)
                             → Supplier Financial Profile balance updates

Inventory Waste              → stock_movements (type=waste, cost from InventoryPostingService)
                             → AccountingPostingService.postWaste()
                             → journal_entries (debit Waste/Inventory Variance 5010,
                               credit Inventory Asset 1100) → reports

Stock Count Variance         → stock_movements (type=stock_count_variance)
                             → AccountingPostingService.postInventoryAdjustment()
                             → journal_entries → reports
```

Every arrow above that says "journal_entries" reuses the **existing** `JournalEntryService.createDraft()` + `.post()` pair inside the proposed `AccountingPostingService` — no new ledger-writing code path is introduced anywhere in this mapping.

## 8. Loading / Empty / Error States

All new screens reuse the established `ManagementMessage` component (loading spinner / empty-with-illustration-and-CTA / error-with-retry) already used throughout `finance_inventory_setup` and other management screens — no new state-widget pattern should be invented. Specific empty states worth calling out: FIN-03 (no cash accounts yet → CTA to FIN-20), FIN-09 (no suppliers yet → CTA to add one), FIN-17 (no posted journal entries in range → "no financial activity in this period" rather than a broken chart).

## 9. RTL and Responsive Behavior

RTL: mandatory throughout, per §1 above. Responsive: reuse `ResponsiveLayout`/`DesktopPageLayout` and the existing `Responsive.isLargeWidth` sidebar-collapse behavior from `AppShell` — this is a desktop-first Windows app (per the existing codebase's own framing), so mobile-specific layouts are **not** a priority; KPI grids and tables should follow the same breakpoint behavior already used in `inventory_counts_screen_test.dart`'s 1440×900 reference layout and the `ManagementKpiCard`/`ManagementTableShell` wrap/scroll behavior already built into `management_ui.dart`.
