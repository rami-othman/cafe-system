# Finance Audit & Architecture — Phase 0A

Investigation only. No Finance Core code was written in this phase.

## 1. Executive Summary

Cafe 618 already contains a **real, working manual double-entry ledger** — chart of accounts (`financial_accounts`), journal entries with a draft→posted lifecycle and a server-enforced debit=credit check (`journal_entries`/`journal_entry_lines`), a per-tenant default chart of accounts seeded automatically (`FinancialSetupService`), and a reachable Flutter UI for both (chart-of-accounts screen, journal-entries screen, setup dashboard, all under a live "تهيئة المالية والمخازن" sidebar entry). This is a solid, reusable Phase 1 foundation — **do not rebuild it.**

What does **not** exist is the connective tissue: **nothing in the codebase posts a journal entry automatically.** `JournalEntryService` has exactly one caller — its own controller. POS sales, refunds, shift closes, inventory waste, and stock-count variances all happen today with zero ledger effect. The inventory-costing engine (Weighted Average Cost) is genuinely excellent — integer fixed-precision math, row-locked, negative-stock-safe — and is the correct source of truth for COGS. But the schema built specifically to carry that cost into orders (`recipes`, `recipe_lines`, `sale_consumptions`, `orders.cogs_total`) is **100% dormant**: the migration exists, nothing writes to it. A project doc (`docs/phase-3-recipes-sales-costing.md`) describes this as a fully implemented, tested feature ("posts per-ingredient `sale_consumption` movements... on a full completed refund it emits one idempotent `return_in` movement"); direct code inspection found zero writers anywhere. **The documentation is aspirational, not accurate to the current repository — treat it as a design intent, not a status report.**

Three entire domains the prompt asked about — **Purchasing, Suppliers, Expenses** — are completely missing; not incomplete, not a stub, genuinely absent from the schema. Payments have no idempotency protection and no row locking on the refund-balance check (a real double-refund race). Most seriously: **the entire POS/Orders/Payments/Shifts/Discounts/Reports route surface has no bearer-token authentication middleware at all** — confirmed by reading `routes/api.php` directly and by a currently-failing test (`PosApiSmokeTest`) that gets a live 401 calling `GET /api/v1/branches`. This is a pre-existing gap, not something this phase introduced, but it is a hard blocker for Finance: you cannot safely post money against an order whose retrieval path has no enforced tenant/actor identity.

**Bottom line:** the ledger primitives are trustworthy and reusable. The business objects that would feed them (expenses, supplier bills, automatic sale/refund postings) don't exist yet, and the surrounding POS auth model needs to be closed before Finance Core can safely go live. See §19 for the exact blocker list and the final GO/NO-GO at the end of this document.

## 2. Current Finance-Related Architecture

```
FinancialSetupService  ──seeds──▶  financial_accounts (chart of accounts, per tenant)
                                          ▲
JournalEntryController ──validates──▶ JournalEntryService ──writes──▶ journal_entries
      ▲                                                                journal_entry_lines
      │ (only caller)
Flutter: financial_accounts_screen.dart, journal_entries_screen.dart, finance_setup_dashboard_screen.dart
      (feature: lib/features/finance_inventory_setup/, routed, reachable, RTL)

Everything else — POS, Orders, Payments, Shifts, Discounts, Refunds, Inventory (WAC, waste,
transfers, counts) — writes to its own tables and NEVER calls JournalEntryService.
ReportsOverviewController is the only other reader of journal_entry_lines (for a "Total
Expenses" KPI, joined to financial_accounts where account_group='expenses').
```

`App\Support\FinancialActor` gates Finance mutations with a hardcoded `in_array($user->role, ['owner','manager'])` check — no permission strings, unlike Inventory's `InventoryAccess` (§18).

## 3. Current Database

62 tables across 48 migrations. Full grouped inventory (tenant_id / branch_id columns noted; money columns are `decimal`, precision noted where it varies):

### Tenancy / Auth
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `tenants` | root | — | `slug` unique, `plan`, `currency` (default SYP) |
| `branches` | yes | is self | `currency`, `is_active`, soft-deletes |
| `users` | yes (nullable) | via `user_branches` | `role` plain **string**, default `cashier`, no roles/permissions table |
| `user_branches` | yes | yes | pivot, unique `(user_id, branch_id)` |
| `api_tokens` | yes (nullable) | — | `token_hash` sha256 unique, `expires_at` |
| `activity_logs` | yes (nullable) | yes (nullable) | `action`, `entity_type/id`, `before_state`/`after_state` JSON |

### Branches / Warehouses
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `warehouses` | yes | yes (nullable) | `type` central/branch_main/bar/kitchen/main, tenant-unique `code` |

### Menu / Products / Recipes
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `categories`, `products` | yes | no | `products.price`/`cost_price` decimal(12,2); later `inventory_controlled`, `consumption_type` |
| `modifier_groups`/`options`, `product_modifier_group`, `order_item_modifiers` | yes | no | `price_delta` decimal(12,2) |
| `product_inventory_settings` | yes | yes | product→branch→warehouse consumption mapping |
| `recipes` / `recipe_lines` | yes | no | BOM, **schema exists, zero writers anywhere (§9A, §12)** |

### POS / Orders / Payments
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `cafe_tables` | yes | yes | dine-in tables |
| `orders` | yes | yes | `status`, `payment_status`, totals decimal(12,2); `cogs_total`/`gross_profit` decimal(15,2) **always null in practice** |
| `order_items` | yes | via order | `recipe_id`, `cogs_unit/cogs_total/gross_profit` — same, unpopulated |
| `payments` | yes | yes | `method` free string (no FK/table), `amount` decimal(12,2), **no idempotency key** |
| `payment_refunds` | yes | yes | `amount` decimal(12,2), `type` full/partial, `status` |
| `print_jobs` | yes | yes | receipt/KOT queue |
| `sale_consumptions` | yes | yes | per-order-item recipe consumption; **table is empty in practice, no writer** |

### Shifts
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `shifts` | yes | yes | `opening_cash/closing_cash/expected_cash/cash_difference` decimal(12,2), `status` open/closed |

### Discounts
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `discounts`, `discount_targets`, `order_discounts` | yes | via targets/order | rules engine + per-order applied snapshot; `discount_amount` decimal(12,2), no ledger link |

### Inventory
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `inventory_items` | yes | no (via warehouse) | `current_stock` legacy/unused for balances; `preferred_supplier_name` free text, **no suppliers table** |
| `stock_movements` | yes | yes (nullable) | immutable ledger, `type`, `unit_cost`/`total_cost` decimal(12,2)→(15,3)/(15,4) after hardening, `idempotency_key` unique per tenant |
| `stock_balances` | yes | via warehouse | `quantity_on_hand`/`reserved_quantity` decimal(15,3), `average_unit_cost` decimal(15,4) — **the WAC** |
| `inventory_item_unit_conversions`, `inventory_item_warehouses` | yes | via warehouse | unit factors, item↔warehouse assignment |

### Stock Counts
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `stock_counts`, `stock_count_lines` | yes | yes (nullable) | draft→...→posted lifecycle, `manager_review_status/threshold`, `average_unit_cost` snapshot |
| `bar_check_templates`, `bar_check_template_lines` | yes | yes | recurring shift-close count config |

### Transfers
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `warehouse_transfers`, `warehouse_transfer_lines`, `warehouse_transfer_receipts(+lines)`, `warehouse_transfer_operations`, `warehouse_transfer_transit_balances`, `warehouse_transfer_transit_movements` | yes | via warehouses | `idempotency_key`, full actor-per-status-transition audit trail |

### Finance / Ledger
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `financial_accounts` | yes | no | chart of accounts, `account_group`, `normal_balance`, `is_system_protected`, self-referencing `parent_account_id` |
| `journal_entries` | yes | yes (nullable) | `status` draft/posted, `source_type`/`source_id` polymorphic (unused so far) |
| `journal_entry_lines` | yes | via entry | `debit`/`credit` **decimal(14,2)** — note: the only (14,2) money columns in the schema, everything else is (12,2) or (15,x) |

### Customers / Loyalty
| Table | tenant_id | branch_id | Notes |
|---|---|---|---|
| `customers`, `loyalty_accounts`, `loyalty_transactions` | yes | no | `total_spent`, `points_balance` — not money-ledger relevant |

### Super-Admin (platform-level, no tenant_id by design)
`platform_roles`, `platform_permissions`, `platform_role_user`, `platform_permission_role`, `plans`, `plan_features`, `subscriptions`, `subscription_events`, `tenant_settings`, `platform_audit_logs`, `platform_settings`, `announcements`, `password_reset_tokens` — a separate, working RBAC + billing-plan system for platform staff, structurally interesting as a *precedent* for how a real `roles`/`permissions` schema could look if Finance needs one (see §18).

**No `suppliers`, `purchase_orders`, `goods_receipts`, `supplier_invoices`, `expenses`, `payment_methods`, `cash_accounts`, `bank_accounts`, `cost_centers`, `accounting_periods`, or `reconciliations` table exists anywhere.**

## 4. Current Backend

Key controllers/services (file paths under `backend/app/`):

| Area | Controller | Service | Notes |
|---|---|---|---|
| POS orders | `Http/Controllers/Api/PosOrderController.php` | `Services/PosPricingService.php` | create/items/discount/hold/cancel, transactional per-action |
| Payments | `Http/Controllers/Api/PaymentController.php` | — | `pay()`, `summary()` |
| Refunds | `Http/Controllers/Api/RefundController.php` | — | separate `payment_refunds` row, not a negative payment |
| Shifts | `Http/Controllers/Api/ShiftController.php` | — | open/current/close, computes expected/actual cash |
| Discounts | `Http/Controllers/Api/DiscountController.php` | — | rules CRUD + apply/remove |
| Receipts | `Http/Controllers/Api/ReceiptController.php` | — | print jobs |
| Reports | `Http/Controllers/Api/{DailyReport,ReportsOverview}Controller.php` | — | two independent aggregation implementations (§9F, §12) |
| Inventory items/catalog | `InventoryItemController.php`, `InventoryItemUnitConversionController.php` | `Services/InventoryItemService.php`, `Services/InventoryItemUnitConversionService.php` | |
| Inventory postings | `StockMovementController.php` | `Services/StockMovementService.php` (thin façade) → `Domain/Inventory/InventoryPostingService.php` (real engine) | **single funnel for all cost/quantity writes** |
| Stock counts | `StockCountController.php` | `Services/StockCountService.php` | delegates posting to `InventoryPostingService` |
| Bar checks | `BarCheckController.php` | (template service, not directly researched) | |
| Warehouses | `WarehouseController.php` | `Services/WarehouseService.php` | |
| Transfers | `WarehouseTransferController.php` | `Domain/Inventory/WarehouseTransferService.php` | idempotency-key pattern to copy for Finance |
| Chart of accounts | `FinancialAccountController.php` | `Services/FinancialAccountService.php` | CRUD + status toggle |
| Journal entries | `JournalEntryController.php` | `Services/JournalEntryService.php` | createDraft/post/find/totals — **no reverse()** |
| Finance setup | `FinancialSetupStatusController.php` | `Services/FinancialSetupService.php` | readiness + default COA/warehouse seeding |
| Audit | — | `Services/OperationalAuditService.php` | used by Inventory + core Finance; a **second, differently-shaped** implementation (`Services/SuperAdmin/PlatformAuditService.php`) exists for platform actions — duplication risk if a shared Finance audit pattern is designed against only one of them |
| Authorization | — | `Support/InventoryAccess.php` (granular, permission-string based) vs `Support/FinancialActor.php` (hardcoded 2-role gate, duplicates `assertBranchAccess` logic) | inconsistent pattern across modules (§18) |
| Tenant resolution | — | `Support/TenantContext.php` | token-attribute in production; `X-Tenant-Id` header trusted **only** in `testing` env |
| Auth middleware | — | `Http/Middleware/AuthenticateApiToken.php` | validates `api_tokens.token_hash`, sets `tenant_id`/`auth_user` request attributes — **only applied to `/inventory/*`, `/finance/*`, `/warehouses`, `auth/me`, `auth/logout`** |

## 5. Current Frontend

Flutter Windows app, `windows_application/lib/`. Feature-first: `discounts`, `finance_inventory_setup`, `inventory`, `menu`, `operational_context`, `orders`, `pos`, `reports`.

`finance_inventory_setup/` is a real, reachable feature (routed at `/finance-inventory-setup`, `/finance-inventory-setup/{warehouses,accounts,journal-entries}`, sidebar entry "تهيئة المالية والمخازن" between Inventory and Reports):
- `finance_setup_dashboard_screen.dart` — readiness checklist against `GET finance/setup-status` (accounts ready / central warehouse ready / branch coverage ready). Not a KPI dashboard.
- `financial_accounts_screen.dart` — list/search/create/edit chart of accounts against `finance/accounts`. Create/edit form only exposes code + Arabic name (group/normal-balance/parent are copied, not editable); backend search param unused (client-side filter only); no activate/deactivate control despite backend + repository support.
- `journal_entries_screen.dart` — list/create-draft/post against `finance/journal-entries`. Draft form is a single hardcoded 2-line debit/credit pair (no description, no >2 lines). The "تفاصيل" (details) dialog reads `entry.lines` off the list-summary object, which the backend list endpoint never populates — `repository.getJournalEntry(id)` exists but is never called. **Likely renders an empty line table today.**
- `warehouses_setup_screen.dart` — list/create/edit warehouses.

Shared design system (`lib/shared/`, `lib/core/theme/`): `DesktopPageLayout`, `AppCard`, `AppButton` (variants primary/secondary/accent/outlined/inverted/danger), `AppDialog`, `AppEmptyState`, `AppLoading`, `AppTextField`, `AppSidebar`/`AppSidebarItem`, `AppTopBar`, `AppBreadcrumbs`, `ShiftStatusBadge`; **`management_ui.dart`** (`ManagementPageHeader`, `ManagementKpiCard`, `ManagementFilterBar`, `ManagementTableShell`, `ManagementBadge`, `ManagementMessage`) is the closest thing to an admin-CRUD toolkit and is what `finance_inventory_setup` already uses — it is the right base for new Finance screens, not `app_empty_state`/`app_loading` (the Reports feature's convention). Tokens: `AppSpacing` (4/8/12/16/24/32/48 + directional helpers), `AppRadius` (8/12/16/20/28/999 + semantic card/control/dialog/panel).

No client-side role/permission filtering exists anywhere (`AppSidebar._destinations` is a static, always-fully-rendered list); authorization is backend-only today.

Reports feature: `reports_overview_screen.dart` (routed at `/reports`) shows 5 KPIs (Net Sales, Gross Profit, Gross Margin, Total Expenses, Net Profit), a 14-day sales trend, branch comparison, and a static "Coming next" category grid that **already lists "Financial Reports" and "Purchasing & Suppliers" as placeholder tiles** — i.e., the intended nav taxonomy already anticipates Finance. `daily_operational_report_screen.dart` has an `expectedCash` KPI but no opening/actual cash or shift metadata (not a real daily-closing screen), and **is not routed/reachable at all** (`DailyReportCubit` is registered in DI but never provided in the router) — dead code today.

## 6. Current APIs

Full route surface (`backend/routes/api.php`, 103 routes). Grouped by auth:

**No `api.token` middleware (production-unauthenticated as wired today):** `POST auth/login`, `GET branches`, `GET reports/daily`, `GET reports/overview`, `GET|POST shifts/current`, `POST shifts/{shift}/close`, `GET menu/*`, `GET customers`, `GET tables`, `GET pos/state`, `GET|POST|PATCH|DELETE discounts*`, `GET|POST|PATCH|DELETE orders*` (incl. `/pay`, `/refunds`).

**`api.token` required:** `GET auth/me`, `POST auth/logout`, `GET|POST|PATCH warehouses*`, everything under `/inventory/*` (also individually gated by `inventory.permission:<string>` middleware — 15 distinct permission strings, §18), everything under `/finance/*` (`setup-status`, `accounts*`, `journal-entries*` — gated only by `FinancialActor`'s coarse role check inside the service layer, not a route middleware).

## 7. Current Seeders

`DatabaseSeeder` order: `SuperAdminSeeder → TenantAccessSeeder → FinancialInventoryFoundationSeeder → MenuCatalogSeeder → ProductModifierSeeder → CustomerAndTableSeeder → InventorySeeder(→InventoryCenterSeeder) → DiscountSeeder → LoyaltySeeder → PosDemoSeeder`. `ReportsOverviewSeeder` is opt-in (tests only).

- `TenantAccessSeeder` — demo tenant, **4 branches** (Main Branch, Downtown, Mall, Airport), owner/manager/cashier users.
- `FinancialInventoryFoundationSeeder` — default 18-account chart of accounts (§9G below), central + branch warehouses, **one** opening-balance journal entry.
- `PosDemoSeeder` — the only seeder producing payment/refund/shift demo data: one closed shift, one paid+partially-refunded order.
- `ReportsOverviewSeeder` — 14 days × per-branch synthetic paid orders **with `cogs_total`/`gross_profit` pre-populated directly** (bypassing the dormant recipe-costing pipeline) plus one posted rent-expense journal entry — the only expense ledger data anywhere in the system.
- **No supplier/purchase/expense seeder exists** — nothing to seed, since no such tables exist.

## 8. Current Tests

51 backend feature tests, 506 assertions (see §15 for pass/fail). Zero dedicated test files exist for: Payments, Refunds (beyond one incidental path in the POS smoke test), Shifts, Loyalty, Customers, Menu/Products, and (necessarily) Suppliers/Purchasing/Expenses. Three different tenant-auth patterns coexist across test files (token+header pattern used by Inventory/Finance tests; header-only pattern relying on the testing-env `X-Tenant-Id` trust used by Reports/Discounts/POS tests; a separate session-based pattern for platform/super-admin tests) — the header-only pattern exists only because those routes have no `api.token` middleware in production either (§6, §13).

## 9. Existing Business Flows

### A. POS Sale
`PosOrderController::store` (transactional) → `order_items` via `PosPricingService::recalculateOrder` → `PaymentController::pay` (transactional: inserts `payments`, flips `orders.status`→paid/`payment_status`→paid, sets `closed_at`). **Stop.** No call to `StockMovementService`/`InventoryPostingService` exists anywhere in the POS/payment code path — a paid order never decrements stock. The `recipes`/`sale_consumptions`/`cogs_total` schema built for this is entirely unpopulated (confirmed: zero writers via full-repo grep); `ReportsOverviewController` already defensively treats COGS as possibly-missing (`cogsAvailable` flag), which is itself evidence the report layer knows this pipeline isn't live. No idempotency key on `orders`/`payments` — a retried `pay` request creates a second `payments` row with no guard. `payments.shift_id` is copied from the order without re-validating the shift is still open.

### B. Refund / Void
`RefundController::store` — separate `payment_refunds` row (not a negative payment), guarded by remaining-balance math (`payment.amount − SUM(completed refunds)`). **No `lockForUpdate()`** on that read — two concurrent refund requests can both pass validation before either commits (double-refund race). No stock reversal, no COGS reversal (both are silently *and correctly* skipped only because nothing consumes stock at sale time either — this will need to change together). `PosOrderController::cancel` has no guard against cancelling an already-`paid` order — it soft-deletes the order while its `payments` row survives, orphaned. **Financially unsafe as-is** for anything beyond the current no-inventory-effect state.

### C. Purchase
**Entirely missing.** No PO, goods receipt, or supplier-invoice concept exists. The only purchasing-adjacent artifacts are two free-text/decimal fields on `inventory_items` (`purchase_unit`, `last_purchase_cost`) used for unit-conversion display, not a procurement process.

### D. Inventory Count / Adjustment
`StockCountController` → `StockCountService` (create → count lines → tolerance/manager-review gate → submit → approve → post) → `InventoryPostingService::post()` with `type='stock_count_variance'`, direction in/out. Fully implemented, row-locked, reason-required, re-checks the review gate at every transition (defense in depth). This is genuinely production-grade and directly reusable as a Finance posting trigger.

### E. Inventory Transfer
Already deeply audited in this project's own `docs/inventory/` reports (this session built/fixed parts of it). Draft→submitted→approved→dispatched→partially_received→received/closed_shortage lifecycle, idempotency-key protected, transit ledger, cost preserved from source WAC. No ledger posting (by design so far — "Inventory journal posting is intentionally deferred" per `docs/phase-2-inventory-center.md`).

### F. Expense
**Entirely missing as a business object.** The chart of accounts has 6 pre-seeded expense accounts (Rent/Salaries/Utilities/Maintenance/Marketing/Misc); nothing debits them except one hand-seeded demo journal entry. No `ExpenseController`, no `expenses` table, no approval workflow.

### G. Shift
`ShiftController::open` (inserts `shifts`, `expected_cash`/`cash_difference` default 0) → sales accrue via `payments.shift_id` → `close()` computes `expectedCash = opening_cash + SUM(cash payments)`, `cashDifference = closingCash − expectedCash`. **Correctness bug:** this formula ignores `payment_refunds` entirely — a cash refund during the shift should reduce expected cash and currently doesn't. No paid-in/paid-out cash-movement concept exists. Bar-check completion gates shift close (unrelated to cash, but part of the same transition).

## 10. Reusable Components

- `financial_accounts` + `FinancialAccountService`/Controller + Flutter screen — chart of accounts, use as-is, extend the edit form.
- `journal_entries`/`journal_entry_lines` + `JournalEntryService` (createDraft/post/totals, debit=credit validation, entry numbering) — the exact mechanics a central `AccountingPostingService` needs; wrap, don't replace.
- `FinancialSetupService::defaultAccounts()` — the seeded COA already anticipates Sales Revenue, Discounts Given, Sales Returns, COGS, Waste/Inventory Variance, Cash Drawer, Main Safe, Bank, Inventory Asset, Accounts Payable — i.e., someone already designed the account taxonomy for exactly this Finance module.
- `InventoryPostingService` (WAC engine) — reuse its `unit_cost`/`total_cost` on every `stock_movements` row as the authoritative COGS/waste-value input; never recompute cost in Finance.
- `stock_movements.type = 'waste'` — already a clean, queryable, cost-carrying identifier for waste postings.
- `WarehouseTransferService`'s idempotency-key + `lockForUpdate` pattern (`warehouse_transfers.idempotency_key`, `warehouse_transfer_operations` dedupe log) — the concurrency-safety template Payments/Refunds/Expenses currently lack and need.
- `InventoryAccess` permission-string + middleware pattern (`inventory.permission:<string>`) — the template for real Finance permission strings, superior to `FinancialActor`'s hardcoded gate.
- `OperationalAuditService` — reuse for every new Finance write (expenses, supplier invoices/payments, postings).
- `ReportsOverviewController::period()`'s `account_group='expenses'` + posted-status ledger query — the only place in the codebase that already reads the ledger for a report; reuse this query logic for Finance's own "Total Expenses" rather than writing a third implementation (Daily/Overview reports already have two independent, slightly different sales-minus-refunds implementations — don't add a fourth).
- `management_ui.dart` widget set + `DesktopPageLayout`/`AppCard`/`AppButton`/`AppDialog` — build every new Finance screen on this, matching `finance_inventory_setup`'s existing look exactly.
- Platform RBAC schema (`platform_roles`/`platform_permissions`/pivot tables) — not directly reusable (separate platform-vs-tenant boundary) but a proven, working precedent for a real DB-backed permissions model if Finance eventually needs one.

## 11. Missing Components

Purchasing (POs, goods receipt), Suppliers (entity, ledger, AP aging), Expenses (entity, approval, payment), supplier invoices/payments/allocations, `payment_methods` as a configurable entity linked to a ledger account, `cash_accounts`/`bank_accounts`, `cost_centers`, `accounting_periods` + locking, reconciliation tables, a central `AccountingPostingService`, journal-entry reversal (`JournalEntryService` has no `reverse()`), idempotency keys on `orders`/`payments`/`payment_refunds`, a Finance permission-string system, automatic recipe/COGS-at-sale posting (schema exists, logic doesn't), automatic stock-consumption-on-sale (nothing calls `InventoryPostingService` from the POS path at all).

## 12. Broken / Risky Components

- **Documentation-vs-reality gap:** `docs/phase-3-recipes-sales-costing.md` describes live, tested recipe consumption + COGS + refund reversal. Verified: **not implemented.** Treat that doc as an unbuilt design spec.
- **`ReportsOverviewController::topProducts()`** — currently throws `SQLSTATE[HY000]: ambiguous column name: tenant_id` on SQLite (unqualified `tenant_id` in a subquery join), failing 2 live tests today (§15). Pre-existing, unrelated to Finance, but Finance must not copy this query pattern.
- **`PosOrderController::cancel`** — allows cancelling an already-paid order, soft-deleting it while its `payments` row survives unreversed.
- **`RefundController::store`** — no row lock on the refund-balance check; concurrent double-refund is possible.
- **No idempotency anywhere in POS/Payments/Refunds** — contrast with the idempotency-key pattern already proven in Warehouse Transfers.
- **`ShiftController::close`** cash formula ignores refunds — understates the true cash-difference the moment cash refunds exist.
- **Two independent audit-log writers** (`OperationalAuditService` vs `SuperAdmin\PlatformAuditService`, different signatures) — pick one pattern for Finance.
- **Two independent "net sales" implementations** (`DailyReportController` vs `ReportsOverviewController`), each with its own SQL — a Finance Overview screen must not become a third.

## 13. Data Integrity Risks

- **No `api.token` middleware on `orders`/`payments`/`shifts`/`discounts`/`reports`/`branches`/`menu`/`customers`/`tables` routes** (verified directly in `routes/api.php` and `bootstrap/app.php` — `api.token` is only aliased, never applied to a global group). `TenantContext::id()` requires either the token-set request attribute or, **only in the `testing` environment**, an `X-Tenant-Id` header. As wired today, these routes would 401 in a real deployment unless something else sets that attribute — nothing does. **Live proof:** `PosApiSmokeTest` currently fails with exactly this 401 on `GET /api/v1/branches` (§15). This is the single most important blocker for Finance — you cannot safely attach money to an order/actor whose identity isn't enforced.
- Decimal vs float: all money columns are proper `decimal` types (mostly `(12,2)`, journal lines `(14,2)`, some inventory cost columns `(15,4)`); PHP-side arithmetic in POS/payment/refund/shift controllers casts to `(float)` for every response and recalculation — standard float-rounding-error accumulation risk on repeated `round()` calls. The Inventory ledger, by contrast, does its core math in scaled integers (`InventoryDecimal`) and only casts to float at the read/report edge — the correct pattern to mandate for Finance too.
- DB transaction safety: solid within each POS/payment/refund action individually, but no transaction spans order-completion→payment→(future) stock-consumption→(future) costing→(future) ledger-posting as one unit — a partial failure mid-chain would leave inconsistent state once those steps exist.
- Idempotency/duplicate requests: `orders`, `payments`, `payment_refunds` have no idempotency key; `stock_movements` and `warehouse_transfers` do. A retried POS pay/refund tap can double-post today.
- Duplicate inventory movements: prevented by `stock_movements.idempotency_key` (unique per tenant) — solid for the paths that use it (transfers, counts, manual movements); moot for POS since POS never posts a movement at all yet.
- Completed orders without payments / payments without orders: schema allows both (no DB constraint linking `orders.payment_status='paid'` to an existing completed `payments` row); enforcement is entirely application-level and, per `cancel()`, has at least one confirmed hole.
- Unsafe hard deletes: not observed — all money-adjacent tables use soft deletes; `journal_entries` explicitly exposes no edit/delete route for posted entries (reversal-only by design, though `reverse()` isn't implemented yet).
- Editing finalized transactions: `stock_movements` is correctly insert-only; `journal_entries` correctly blocks editing a posted entry; `payments`/`orders` have no equivalent immutability guard once paid (see `cancel()` bug above).
- Reports recalculating financial values independently: confirmed — `DailyReportController` and `ReportsOverviewController` each independently aggregate `orders`/`payment_refunds`; neither reads from a shared query object. Not yet a *conflict* (both currently agree in practice) but a real drift risk, and a third Finance implementation would make it worse.
- Inventory valuation consistency / WAC: verified correct and consistent — integer math, row-locked, single funnel (`InventoryPostingService`). Confirmed no other module recomputes inventory value independently.
- Negative stock rules: enforced and verified (outbound quantity capped at on-hand minus reserved, under `lockForUpdate()`).
- Concurrency/race conditions: solid in Inventory (`lockForUpdate` throughout); **absent in Payments/Refunds** (see above).

## 14. Finance Readiness Matrix

| Capability | Exists? | Reuse? | Extend? | Build new? | Key dependency |
|---|---|---|---|---|---|
| Chart of Accounts | Yes (full) | Yes | Minor (edit form fields) | — | — |
| Journal Entries (draft/post/debit=credit) | Yes (full) | Yes | Add reversal, multi-line UI | — | — |
| Draft/Posted/Reversed lifecycle | Draft/Posted only | Yes (base) | Add `reversed` status + `reverse()` | — | `journal_entries.status` enum extension |
| Financial periods / locking | No | — | — | Yes | new `accounting_periods` table |
| Cash accounts / Bank accounts | No (only ledger *account* rows exist) | Partial (financial_accounts as the ledger side) | — | Yes | link to `payments.method` |
| Payment methods → ledger accounts | No | — | — | Yes | new `payment_methods` table + FK on `payments` |
| Expenses | No | — | — | Yes | approval workflow, `financial_accounts` (6100-6190) |
| Supplier AP / invoices / payments / allocations | No | — | — | Yes | `suppliers`, `supplier_invoices`, `supplier_payments`, `payment_allocations` |
| POS sale → ledger posting | No | Reuse WAC cost output | — | Yes | fix auth gap first (§13), decide sale-time stock consumption |
| Discounts → ledger posting | No | Reuse `order_discounts.discount_amount` | — | Yes | central posting service |
| Refunds → ledger posting | No | Reuse `payment_refunds` | Fix locking first | Yes | central posting service |
| COGS | Cost engine yes, sale-time hook no | Reuse `InventoryPostingService` cost output | — | Yes (the hook itself) | decide: build the dormant recipe pipeline, or a simpler order-level COGS estimate |
| Waste / damage / expired → ledger | Identifiable (`type='waste'`) | Yes | — | Yes (the posting call) | — |
| Stock shortages/surpluses → ledger | Identifiable (`stock_count_variance`) | Yes | — | Yes (the posting call) | — |
| Cost centers | No | — | — | Optional Phase-1 scope | — |
| Branch profitability | Partial (branch_id everywhere) | Yes | — | Reporting layer only | — |
| Shift cash reconciliation | Partial (expected/actual/diff exist) | Yes | Fix refund-omission bug | — | — |
| Daily financial closing | No dedicated screen (routed daily report is dead code) | Reuse `expectedCash` KPI concept | — | Yes | — |
| Card / bank reconciliation | No | — | — | Yes (later phase) | — |
| Audit trail | Yes (`OperationalAuditService`) | Yes | — | — | — |
| P&L / Balance Sheet / Cash Flow / Trial Balance / GL | No | Ledger data model supports them | — | Yes (reporting layer) | needs periods + postings to exist first |
| Supplier statement / aging | No | — | — | Yes | needs Suppliers first |

## 15. Proposed Finance Architecture

```
Business Module (POS payment, refund, expense, supplier payment, inventory waste/adjustment...)
        │  raises a Financial Posting Request (a plain array/DTO: sourceType, sourceId, tenantId,
        │  branchId, entryDate, description, lines[{accountCode, debit|credit, costCenter?}])
        ▼
AccountingPostingService (new, thin orchestration layer)
        │  - resolves account codes → financial_accounts ids (tenant-scoped, never trusts a raw id)
        │  - calls the EXISTING JournalEntryService.createDraft() then .post() inside one transaction
        │  - is the ONLY caller of JournalEntryService from outside JournalEntryController
        ▼
journal_entries / journal_entry_lines   (unchanged schema, already correct)
        ▼
Ledger / balances (read-side aggregation, e.g. the account_group='expenses' query pattern
        already in ReportsOverviewController — generalize it into a shared query object)
        ▼
Reports (P&L, Trial Balance, GL, Daily Closing, Finance Overview)
```

Rationale for a central service rather than letting each module call `JournalEntryService` directly: every poster needs the same three things — tenant-safe account resolution, a single atomic draft+post transaction, and a place to enforce "debit accounts must exist and be active" once instead of N times. `JournalEntryService` itself should **not** be duplicated or bypassed; `AccountingPostingService` wraps it and adds named methods (`postSale()`, `postRefund()`, `postExpense()`, `postSupplierInvoice()`, `postSupplierPayment()`, `postInventoryAdjustment()`, `postWaste()`, `postCashTransfer()`) that each build the correct `lines[]` array for their business event and hand it to the same two calls. This keeps `JournalEntryService`'s existing manual-entry API (`JournalEntryController`) untouched and still usable by an accountant for ad-hoc entries, while giving every automated poster one shared, testable choke point. Not implemented in this phase — documented only.

Each business module should emit its posting request from inside the *same database transaction* as its own state change (e.g., `PaymentController::pay()` would call `AccountingPostingService::postSale()` before committing) so a failure either commits both or neither — mirroring the pattern `WarehouseTransferService` already uses for its own multi-table writes.

## 16. Proposed Database Architecture

No migrations are proposed for creation in this phase — the tables below are **evaluated only**, per the task's explicit instruction.

| Table | Purpose | tenant/branch | Key columns | New or extend? |
|---|---|---|---|---|
| `financial_accounts` | Chart of accounts | tenant, no branch | *(existing)* | **Reuse as-is** |
| `journal_entries` / `journal_entry_lines` | Ledger | tenant, branch (nullable) | *(existing)*; would need a `reversed_entry_id`/`reversal_of_id` nullable self-FK and a `reversed` status value | **Extend** (lightweight) |
| `accounting_periods` | Lock a month/quarter against new postings | tenant | `start_date`, `end_date`, `status` (open/closed/locked), unique `(tenant_id, start_date, end_date)` | **New** |
| `financial_settings` | Per-tenant Finance config (default cash account, fiscal year start, etc.) | tenant | key/value or fixed columns, one row per tenant | **New** — could follow `tenant_settings`' existing JSON-blob pattern from the super-admin schema instead of a bespoke table |
| `cost_centers` | Optional branch/department cost attribution on journal lines | tenant | `code`, `name`, `branch_id` nullable | **New**, keep optional/deferred — avoid over-engineering (§13 of the prompt) |
| `cash_accounts` / `bank_accounts` | Physical cash drawers & bank accounts, each linked to a `financial_accounts` row | tenant, branch (nullable for bank) | `financial_account_id` FK, `type` (cash/bank), `current_balance` (derived/cached, not authoritative — the ledger is authoritative) | **New** |
| `payment_methods` | Replace `payments.method` free string; link each method to a `financial_accounts`/`cash_accounts` row | tenant | `code`, `name`, `financial_account_id` FK, `is_active` | **New**, then add `payment_method_id` FK to `payments` (keep the string column for one deprecation cycle) |
| `expense_categories` | Maps to the existing 6100-6190 expense accounts, or replaces them with a proper category table linked 1:1 to a `financial_accounts` row | tenant | `financial_account_id` FK, `name` | **New**, thin — mostly a friendlier wrapper over accounts already seeded |
| `expenses` | The actual business object missing today | tenant, branch | `amount`, `category_id`/`financial_account_id`, `status` (draft/pending_approval/approved/paid/rejected), `paid_from_account_id`, `supplier_id` nullable, `cost_center_id` nullable, `attachment_path`, idempotency key | **New** |
| `suppliers` | Vendor master | tenant | `name`, `contact`, `payment_terms`, `is_active`; replaces the free-text `preferred_supplier_name` on `inventory_items` over time | **New** |
| `supplier_invoices` | AP bill | tenant, branch | `supplier_id` FK, `amount`, `due_date`, `status` (open/partially_paid/paid/overdue), source reference to a goods-receipt if/when Purchasing is built | **New** |
| `supplier_payments` | Payment against one or more invoices | tenant, branch | `supplier_id` FK, `amount`, `paid_from_account_id`, idempotency key | **New** |
| `payment_allocations` | Splits a `supplier_payments` row across multiple `supplier_invoices` | tenant | `supplier_payment_id`, `supplier_invoice_id`, `amount`, unique pair | **New** |
| `reconciliations` / `reconciliation_lines` | Bank/cash reconciliation sessions | tenant, branch | `account_id`, `statement_balance`, `status`; lines match ledger entries to statement lines | **New**, later phase |
| `opening_balances` | Initial balances when a tenant onboards mid-year | tenant | `financial_account_id`, `amount`, `as_of_date` | **New**, small — could alternatively just be a tagged `journal_entries` (`source_type='opening_balance'`), which is in fact exactly what `FinancialInventoryFoundationSeeder` already does today. **Recommend not creating a separate table** — reuse the journal-entry mechanism that's already proven. |

Every new table above must follow the two schema conventions already established everywhere else in this codebase: `tenant_id` on every row, `decimal` (never float) for money with `(12,2)` minimum precision, soft-deletes on business records, and an `idempotency_key` column on any table representing a client-triggerable financial mutation (payments/expenses/supplier payments) — mirroring `stock_movements`/`warehouse_transfers`.

## 17. Integration Architecture

| Trigger | Emits posting request when | Depends on |
|---|---|---|
| `PaymentController::pay()` | payment completes | auth gap closed (§13), `AccountingPostingService.postSale()` |
| `RefundController::store()` | refund completes | row-locking fix (§12), `postRefund()` |
| New `ExpenseController` (paid status) | expense marked paid | `postExpense()` |
| New supplier-invoice/payment controllers | invoice posted / payment made | `postSupplierInvoice()`, `postSupplierPayment()` |
| `StockCountService::post()` (variance) | count posted with a cost-bearing variance | `postInventoryAdjustment()` |
| `InventoryPostingService::post()` where `type='waste'` | waste movement recorded | `postWaste()` |
| Manual cash transfer (new UI action under Cash & Banks) | user confirms transfer | `postCashTransfer()` |

Every integration point above is additive to an existing transactional method, not a new standalone flow — each business module keeps owning its own state machine and simply also calls `AccountingPostingService` inside its existing `DB::transaction()`.

## 18. Permission Architecture

Current state is **inconsistent between modules**: Inventory has a real permission-string system (`InventoryAccess::ROLE_PERMISSIONS`, 15 strings like `inventory.transfers.approve`, enforced by an `inventory.permission:<string>` route middleware) with `owner` as a wildcard. Finance has only `FinancialActor`'s hardcoded `in_array($role, ['owner','manager'])` — no strings, no middleware, and it duplicates `InventoryAccess`'s branch-access logic verbatim. There is **no** `roles`/`permissions` database table anywhere in the tenant schema (`role` on `users` is a plain string); the only real DB-backed RBAC in the codebase is the **platform** (super-admin) schema, which is out of tenant scope but a valid structural precedent.

**Recommendation:** extend the existing `InventoryAccess` pattern rather than invent a third one. Either (a) generalize it into a shared `App\Support\Access` (or similar) class covering both `inventory.*` and new `finance.*` permission strings, retiring `FinancialActor`'s coarse gate, or (b) — a bigger but more future-proof move — introduce a real `permissions`/`role_permissions` table modeled on the existing platform RBAC schema. Given the scale of this cafe SaaS product, (a) is the pragmatic Phase-1 choice; (b) is a legitimate future extension point, not a blocker.

Proposed Finance permission strings (following the established `<module>.<resource>.<verb>` convention):

- **POS Cashier**: `finance.shift.view_own`, `finance.cash_drawer.view_own` — scoped to their own open shift only, nothing else.
- **Branch Manager**: `finance.expenses.create`, `finance.expenses.approve` (own branch), `finance.cash.view_branch`, `finance.shift.reconcile`, `finance.reports.branch_summary`.
- **Accountant**: `finance.journal_entries.create`, `finance.journal_entries.post`, `finance.reconciliations.manage`, `finance.suppliers.manage`, `finance.reports.view_all`, `finance.settings.view` (not necessarily edit).
- **Owner/Admin**: wildcard, matching `InventoryAccess`'s existing `owner => ['*']` convention.

Branch scoping continues to layer on top via the existing `user_branches` pivot + `assertBranchAccess()` pattern — no new mechanism needed there, just consistent reuse.

## 19. Critical Blockers

Ordered by severity — these should be resolved (or explicitly accepted as known risk) before Finance Core work begins:

1. **No authentication on POS/Orders/Payments/Shifts/Discounts/Reports routes.** Verified in source and by a currently-failing test. Finance cannot safely post money against these flows until every route it depends on enforces `api.token` (or an equivalent) in production, not just in the `testing` environment's header-trust shortcut.
2. **No idempotency protection on `orders`/`payments`/`payment_refunds`.** A retried request can double-post real money today; this must exist before any automatic ledger posting is layered on top, or duplicate postings become a certainty, not a risk.
3. **No row locking on the refund-balance check** (`RefundController::store`) — a concurrency bug that becomes a real financial-loss vector once Finance depends on refund totals being correct.
4. **`PosOrderController::cancel` allows voiding an already-paid order** without reversing its payment — a silent data-integrity hole that would corrupt any Finance reconciliation built on top of `orders`/`payments`.
5. **The recipe/COGS-at-sale pipeline is schema-only.** Finance needs a real, current COGS value per sale to post correct journal entries; someone must decide whether to (a) finish the dormant recipe-consumption pipeline described in `docs/phase-3-recipes-sales-costing.md`, or (b) design a simpler interim COGS estimate, before `postSale()` can produce a correct entry.
6. **`ShiftController::close`'s cash formula ignores refunds** — must be fixed before Daily Closing/shift-cash-reconciliation screens can show a trustworthy number.
7. **No Finance-specific permission system** — `FinancialActor`'s two-role gate is too coarse for the roles this task asks for (Cashier/Manager/Accountant/Owner); must be extended before granular Finance screens ship.

None of these are large rewrites — they're each a bounded, well-understood fix in code this audit has already located precisely. They are listed as blockers because Finance Core's correctness *depends* on them, not because they are individually hard.

## 20. Validation

Commands executed against the current repository state (no code changed in this phase):

```
docker compose exec -T backend php artisan test
flutter analyze   (windows_application/)
```

**Backend: 51 tests, 506 assertions — 47 passed, 4 failed.** All 4 failures are pre-existing and unrelated to this investigation (no backend file was modified in this phase):

| Test | Cause |
|---|---|
| `ReportsOverviewApiTest::test_overview_filters_dates_and_branches_and_uses_paid_sales_minus_refunds` | `SQLSTATE[HY000]: ambiguous column name: tenant_id` — unqualified column in a subquery join inside `ReportsOverviewController::topProducts()` (`app/Http/Controllers/Api/ReportsOverviewController.php:179`) |
| `ReportsOverviewApiTest::test_overview_is_tenant_isolated_and_returns_real_aggregates` | Same root cause |
| `PosApiSmokeTest::test_pos_order_flow_can_be_completed` | `GET /api/v1/branches` returns 401 — **live, reproducible evidence of the auth gap in §13/§19**: the test sends no `X-Tenant-Id`/token header, the route has no `api.token` middleware, and `TenantContext::id()` correctly rejects the request |
| `DiscountManagementApiTest::test_tenant_and_branch_seed_data_is_idempotent` | Asserts exactly 3 branches; `TenantAccessSeeder` now seeds 4 — stale test/seeder drift, unrelated to Finance |

Per the task's instruction, none of these were fixed in this phase.

**Flutter analyze:** 0 compile errors; pre-existing `info`-level lints only, none in Finance-relevant files (`finance_inventory_setup/`, `reports/`).

## 21. Final Decision

See the chat response for the formal **GO / NO-GO** statement, exact reuse list, and next-phase scope — reproduced here for the written record.

**Decision: GO for Finance Core (Phase 0B), conditioned on resolving blockers §19.1–§19.4 as part of Phase 0B itself** (they are small, well-located fixes, not a separate multi-week phase). Blockers §19.5–§19.7 can be addressed within the phases that actually need them (COGS-at-sale in the Inventory-Accounting-Integration phase, shift-cash fix before Daily Closing, permissions before Expenses/Suppliers ship broad access). Reuse: `financial_accounts`, `journal_entries`/`journal_entry_lines`, `JournalEntryService`, `FinancialSetupService`'s seeded COA, `InventoryPostingService`'s WAC cost output, `OperationalAuditService`, `InventoryAccess`'s permission pattern, and the entire `finance_inventory_setup` Flutter feature (extend, don't rebuild). Net-new for the next phase: `AccountingPostingService` (orchestration only, no new business tables yet), the auth/idempotency/locking fixes above, and a `reverse()` method on `JournalEntryService`.
