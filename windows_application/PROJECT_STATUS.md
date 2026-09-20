# CURRENT AUTHORITATIVE STATUS

- Direct purchasing flow: new inventory purchases default to immediate receipt when posted; payment amount and receipt mode are independent. One destination warehouse is selected for direct purchases. The Purchasing Center opens on the invoice list and the receipt screen remains available for delayed/partial delivery. Purchasing API regression suite: 30 passed, 351 assertions on an isolated test database. Three purchasing Flutter widget suites: 19 passed. `flutter analyze --no-pub`: no issues. See `docs/purchasing/DIRECT_PURCHASE_FLOW_AUDIT.md`. No deployment or commit was made.

- Inventory catalogue: the 184 supplied material definitions from
  Ø§Ù„Ù…ÙˆØ§Ø¯_Ù…Ø¶2Ø¨ÙˆØ·.xlsx are represented as active raw materials without opening
  stock, costs, or reorder thresholds. Exact existing names are retained
  rather than duplicated; all other names, categories, and units are preserved
  and available to product recipe configuration.

Cafe System 618 has a Laravel backend in `backend` and a Flutter Windows client
in `windows_application`. Tenant isolation is backend-authoritative. The test
suite is guarded to use `cafe_system_618_testing`.

## Authentication status

- Auth Phase 0: **CLOSED**
- Auth Phase 1: **CLOSED**
- Pre-Auth Hardening A-D: **CLOSED**
- Batch 12: **COMPLETE**
- Auth Phase 2: **CLOSED**
- Flutter Auth Phase 3: **IMPLEMENTED â€” verification in progress**
- Phase 1B staging smoke: Flutter login sends exactly one trimmed identity key
  (`email` or `username`), never `identifier`; request-contract coverage
  protects session parsing and safe 422 handling.
- Deployment Phase 1C: Flutter Web platform abstractions implemented; final
  local browser/staging smoke remains environment-dependent.
- Final Permission Catalog: **DEFERRED**

Auth Phase 1 closure was manually verified on this exact worktree with
`docker compose exec -T backend php artisan test`: **160 tests passed, 2,054
assertions, 0 failures, in 67.15 seconds**. The suite includes the Auth Phase 1,
Platform Super Admin, publication/payment/discount concurrency, POS runtime,
snapshot-aware order, tenant isolation, and testing-database isolation coverage.

Auth Phase 2 closure passed `migrate:fresh --seed` against
`cafe_system_618_testing` and the full Laravel suite: **164 tests, 2,099
assertions, 0 failures**. It delivers the backend-only Tenant Employee
Management domain: separate `tenant_roles` identities (Owner/Manager/Employee),
one authoritative Role per User, read-only role catalog, temporary-password
employee creation, Manager-to-Manager creation, protected Owner lifecycle and
credentials, Tenant-safe active Branch assignments, lifecycle/password token
revocation, and the temporary Owner/Manager employee-administration boundary.
The final Permission Catalog, custom role management, Flutter Auth, actor
attribution, and full operational route authorization remain deferred.

## Current delivery state

- Maintenance: the Cafe Configuration create-branch route resolves a
  route-scoped `BranchEditorCubit` through the service locator.

Menu Management Admin is **COMPLETE through Publish / Versions**:

- Batch 8 â€” Pricing & Availability: **COMPLETE**
- Batch 9 â€” Menus & Composition: **COMPLETE**
- Batch 10 â€” Assignments & Schedules: **COMPLETE**
- Batch 11 â€” Review & Publish: **COMPLETE**
- Menu â†” Inventory validation hardening: **COMPLETE** â€” recipe writes,
  resolution, publishing, and Review & Publish now use the Inventory conversion
  contract; existing invalid rows remain visible with actionable diagnostics.
- Recipe editor dropdown resilience: existing recipes load inactive/archived
  current materials as one disabled selection; material IDs and allowed recipe
  unit codes are normalized before dropdown items are built.

The implemented flow covers Catalog, modifiers, recipes/material configuration,
menus/sections/placements, exact Branch + Sales Channel assignments and schedules,
validation, resolved preview, publishing, immutable version history, comparison,
and rollback.

Published Menu Snapshots are versioned immutable payloads. Schema v3 defines
published Menu order by the serialized `menus[]` sequence and zero-based
`scopeOrder`; automatic publication uses exact-scope active assignment order.
Catalog Menu priority is not a published runtime-order field and must not be used
to re-sort a snapshot. Explicit `menuIds` retain the established canonical Menu
order, not request order. Historical payloads remain immutable and rollback copies
the selected historical payload unchanged.

## Current POS boundary

- Published POS variant selection: COMPLETE. The customization dialog presents
  every sellable runtime variant, defaults to the published default, and
  submits the selected immutable variant ID with its effective price.

- Phase 12A â€” Runtime Contract: **COMPLETE**
- Phase 12B â€” Backend POS Runtime Sync API: **COMPLETE**
- Phase 12C â€” Snapshot-Aware Order Contract (backend): **COMPLETE**
- Phase 12D â€” Flutter Runtime DTOs + Sync Repository + Scoped Cache: **COMPLETE**
- Phase 12E â€” Published Menu presentation cutover: **COMPLETE**
- Phase 12F â€” Offline / reconnect / pending-version behavior: **COMPLETE**
- Phase 12G â€” Legacy cutover + final regression: **COMPLETE**

**BATCH 12 â€” COMPLETE.** Production POS follows Published Runtime Contract v1
only: Menu Management -> Publish -> Immutable Published Version -> POS Runtime
Contract v1 -> `/pos/menu-sync` -> scoped Flutter cache -> Published POS UI ->
version-bound cart -> snapshot-aware Order. It never falls back to the live
Catalog when publication, network, or contract/cache validation fails.
The bounded runtime overlay keeps Sold Out and Temporarily Unavailable state
fresh without republishing; published schedules remain backend-resolved.

Offline menu and cart preparation are supported. True offline transaction or
payment processing is not implemented. The legacy Catalog Menu endpoints and the
no-version `POST /orders` branch are retained as deprecated compatibility paths
for non-POS consumers and existing historical workflows. They are not used by
the production Windows POS. Historical orders
with no published version remain readable, refundable, and receiptable. Future
authenticated barista/terminal assignment may restrict visible Branch choices;
current Branch / cart isolation remains authoritative.

## Batch 12 closure verification

On the exact closure worktree: backend focused tests passed (41 tests / 485
assertions), the full Laravel suite passed (138 tests / 1,891 assertions), and
Pint, Dart format, and `git diff --check` passed. Manual Windows verification
passed: `flutter gen-l10n`, `flutter analyze`, `flutter test` (487 passed), and
`flutter build windows`. The built executable launched successfully and rendered
the Published POS screen.

## Pre-Auth hardening

### Pre-Auth Hardening A âœ… CLOSED

- `OrderLifecyclePolicy` permits normal mutation only for unpaid Draft/Held
  orders; completed and refunded orders are immutable.
- Payment and refunds use database locks, tenant/order-scoped idempotency keys,
  unique constraints, and durable locked number counters.
- Flutter supplies one key per payment/refund attempt; offline payments remain
  blocked.
- True PostgreSQL process-concurrency coverage passed for payment/refund
  idempotency and order/refund number contention.

### Pre-Auth Hardening B âœ… CLOSED

- Mutable admin feature Cubits are lazy and route-scoped; POS startup no
  longer creates Orders, Discounts, Reports, or Menu Management state.
- `PosCubit` remains the session POS workspace so cart and branch context
  survive a temporary route change. Its branch safety rule remains unchanged.
- Orders and Reports follow that authoritative branch only while their route is
  mounted; report requests pass the supported `branchId` contract.
- Router topology tests assert that POS does not request unvisited feature
  repositories and that Orders, Reports, and Discounts initialize independently.

### Pre-Auth Hardening C âœ… CLOSED

- `DiscountEligibilityService` is the authoritative runtime policy for managed
  discounts, including Branch-local date/day/time and overnight windows.
- Product/category targeting uses persisted immutable category identity for
  versioned Orders; legacy Orders retain their live-Catalog compatibility path.
- Payment-time revalidation covers tender restrictions and current policy state.
  Discount usage is consumed only by a successful payment with locked global and
  per-customer checks, and payment retries cannot double-consume it.
- Full Laravel verification passed: 149 tests / 1,985 assertions; Pint and
  `git diff --check` passed; `cafe_system_618_testing` migration rebuild and
  seed completed successfully. No Flutter files changed for Hardening C.

### Pre-Auth Hardening D âœ… CLOSED

- Publication now acquires its exact tenant + Branch + channel advisory lock
  before it starts the repeatable-read critical section. Candidate resolution,
  blocking validation, snapshot construction, checksum/no-change selection,
  version writes, and publication audit all use that one authoritative state.
- PostgreSQL worker coverage verifies same-scope serialization, no-change
  contention, cross-scope independence, and an independent-connection edit
  between validation and snapshot construction.
- Flutter has a small typed API error foundation for unavailable network,
  unauthenticated, forbidden, validation, conflict, server, and unknown paths.
  Safe generic EN/AR copy is available; useful 422 domain messages and stable
  backend codes are retained. POS cached-menu offline behavior remains distinct.

Closure verification passed locally: Laravel 152 tests / 2,003 assertions,
Flutter 496 tests, `flutter analyze`, and the Windows build all completed.

**PRE-AUTH HARDENING COMPLETE.**

## Pre-Auth handoff

Auth Phase 0 and Auth Phase 1 are closed. Platform Super Admin
authentication/permissions remain a separate security domain. Auth Phase 2,
Flutter Auth, and the final Permission Catalog remain future work.

The next phase is Tenant Employee Authentication, Roles, Permissions, Branch
Assignment, server-side authorization, actor identity/audit attribution, and
Flutter permission-aware navigation. It is not implemented by this baseline.

The hardening sequence is:

1. **Pre-Auth Hardening A** â€” Order lifecycle + payment/refund concurrency/idempotency
2. **Pre-Auth Hardening B** â€” Flutter route-scoped Cubits / shared app context cleanup
3. **Pre-Auth Hardening C** â€” Discount runtime correctness
4. **Pre-Auth Hardening D** â€” Publish validation race + docs/error hygiene
5. **Auth + Employee Roles + Permissions + Branch Assignment**

Hardening items 1â€“4 are closed; only the final tenant employee-auth handoff is
future work and it is not part of Batch 12.

## Important architecture notes

- Products, Variants, Modifier Groups, Modifier Options, and Menu Sections use
  Active / Inactive / Archived lifecycle semantics; archive takes precedence.
- Variant base recipes and Modifier Option material adjustments are configuration,
  not Inventory runtime. Exact decimal quantities and canonical units are
  authoritative.
- Published snapshots exclude operational availability state, remaining quantities,
  and Inventory runtime data. Rollback creates a new Version rather than
  reactivating historical data.
- The Flutter Windows app uses feature-based Cubit architecture. The Product
  Workspace remains the canonical Product parent.
- Phase 4K architecture cleanup and broader localization migration remain deferred.

## Cafe Configuration Flutter Phase 2

- Owner-only Cafe Configuration now includes Team & Access and Tax alongside
  Overview, Cafe Profile, and Branches.
- Team & Access uses the existing paginated employees and roles APIs, supports
  Manager/Employee creation and editing, protected Owner rows, lifecycle
  actions, password reset, and active-branch assignment rules.
- Tax uses the tenant-wide fractional API contract while presenting percentages
  to the Owner. Overview now reports live team, tax, profile, and branch data.

## Batch 12 status

## Reports Overview UI

- The existing `/reports` Cubit/repository-backed overview now follows the
  Reports Overview reference hierarchy with RTL-aware controls, polished
  loading/error/empty states, and truthful branch/product data presentation.
- Financial Reports reuses its canonical `/finance/reports` screen; remaining
  detailed report categories are visibly pending rather than dead links.

## Sales & Profitability Report UI

- Added the route-scoped `/reports/sales-profitability` report with typed
  presentation models, Cubit filter/view/sort state, responsive Arabic-first
  report sections, and a deliberately endpoint-free repository for this UI
  phase.
- The Reports Overview Sales & Profitability category is now active; Inventory,
  Expenses, Purchasing & Suppliers, and Custom Report Builder remain pending.

## Cash & Shifts Report UI

- Added the route-scoped `/reports/cash-shifts` report with typed
  presentation models, Cubit filter state, responsive Arabic-first report
  sections, and a deliberately endpoint-free repository for this UI phase.
- The Reports Overview Cash & Shifts category is now active.  It remains a
  read-only analytics destination; shift, payment, and closing operations stay
  in their canonical operational modules.

## Inventory Report UI

- Added the route-scoped `/reports/inventory` read-only analytics report with
  typed inventory presentation models, filter state, responsive Arabic-first
  sections, and an endpoint-free repository during this UI phase.
- The Reports Overview Inventory category is now active. Expenses, Purchasing
  & Suppliers, and Custom Report Builder remain pending.

## Reports Demo Data

- `Cafe618ReportsDemoSeeder` prepares idempotent Cafe 618 development data for
  report work: POS sales, cash/card payments, refunds, shifts, cash transfers,
  reconciliations, daily closings, and overview history. It is limited to
  local, development, and testing environments and is included in local
  `DatabaseSeeder` runs.

- 12A âœ… Runtime Contract
- 12B âœ… Backend POS Runtime Sync API
- 12C âœ… Snapshot-Aware Order Contract
- 12D âœ… Flutter Sync / Scoped Cache
- 12E âœ… Published POS UI Cutover
- 12F âœ… Offline / Reconnect / Pending Version
- 12G âœ… Legacy Cutover / Final Regression

**BATCH 12 â€” COMPLETE**

## Inventory warehouse context audit

- Inventory list requests now carry both the active operational `branchId` and
  the selected `warehouseId`; Laravel applies and validates both scopes for
  balances, items, movements, counts, and the dashboard.
- Warehouse selectors use one active/legacy/branch rule, retain central
  warehouses, clear stale selections on branch changes, and reload the owning
  screen immediately.
- Inventory Cubit loaders use latest-request-wins guards so a slow response for
  a previous warehouse cannot replace newer data. Stock-count warehouse
  options remain isolated from the general warehouse list.
- Focused Flutter warehouse-context tests and the backend
  `InventoryCenterApiTest` suite pass.

## Inventory branch provider repair

- The operational branch Cubit now has one lazy, shell-wide provider above all
  Inventory routes. Route-local duplicates were removed so the module frame,
  warehouse selectors, and routed page always observe the same branch state.
- `InventoryModuleShell` initializes that context from the authoritative POS
  branch and follows later top-navigation branch changes.
- Static analysis is clean, and the provider/synchronization regression test
  plus all warehouse dropdown widget tests pass (5 tests).

## Cafe 618 branding integration

- Added a centralized, role-aware brand identity resolver. Cashiers see the
  authoritative active branch name; managers and owners retain the general
  Cafe System 618 identity. Missing or stale branch context falls back safely
  and never guesses a branch.
- Replaced scattered shell, authentication, splash, and receipt branding with
  reusable logo/header widgets backed by bundled transparent assets.
- Web metadata, favicon/PWA icons, Windows executable resources, and runtime
  browser/native window titles now use the same centralized identity.
- Added regression coverage for role rules, branch switching, logout/re-login,
  long Arabic names, image fitting, and the Inventory branch-provider scope.
- Dart static analysis and focused branding/provider tests pass. The Windows
  debug runner builds successfully with the branded icon and title channel.

## Optional product modifier assignments

- The product modifier assignment endpoint now requires the replacement key to
  be present while accepting `groups: []` as the explicit detach-all command.
- Flutter already sends the replacement field for an empty selection; a new
  Cubit regression test protects that contract and its successful UI state.
- Laravel coverage verifies initially empty products, removal of all existing
  assignments without deleting group definitions, retained assignments,
  missing-key validation, and cross-tenant rejection. POS coverage confirms
  products with no modifier groups remain directly configurable/sellable.
- This behavioral fix changes no database schema or seed data.

## Automatic POS Bar inventory routing

- Cashiers no longer select a warehouse in POS. Laravel resolves the active
  branch's explicit `pos_inventory_warehouse_id`, validates tenant/branch/type,
  and snapshots it on the order for audit and payment-time revalidation.
- New branches receive an idempotent Bar warehouse configuration. The schema
  migration only backfills existing branches that have exactly one active Bar;
  ambiguous branches are intentionally left for administrator review.
- The warehouse repair command now audits missing, invalid, and ambiguous POS
  Bar configuration in dry-run mode and applies only deterministic repairs.
- POS consumption can create a negative Bar balance while preserving WAC/COGS.
  Incoming transfers understand signed balances and naturally settle a deficit
  (covered by the `0 -> -20 -> +20 -> 0` integration scenario).
- Laravel sale/accounting and warehouse-repair suites pass, and Flutter has a
  request-contract regression test proving `warehouseId` is never submitted.

## Shift module â€” full UI (frontend-only, mock-backed)

- New self-contained `lib/features/shift` module: current-shift overview, no
  open-shift / open-shift form, a five-step closing wizard (operations
  review, cash count with a denomination counter, bar count, final review,
  success), a filterable/paginated history screen, and a full closing report
  with an A4/thermal print-preview mock.
- Bar counting lives entirely inside the closing wizard (step 3), per
  explicit direction, and is not routed through
  `features/inventory/bar_checks`.
- Backed by `ShiftMockRepository`, a local in-memory data source with a
  debug-only scenario switcher (balanced close, cash shortage/surplus, stock
  variance, negative theoretical stock, blocking open order, incomplete
  count, no open shift, loading, error) â€” no backend endpoint exists yet.
- Domain models (`shift_models.dart`), a pure `ShiftAssessment` (alerts,
  readiness checklist, stage track) computed once and shared by the
  overview, the wizard and the confirmation dialog, and centralized
  `ShiftStrings`/`ShiftFormat` copy/formatting so no screen holds a literal.
- Registered in `service_locator.dart` and wired into `app_router.dart`
  under `/shift/current`, `/shift/history`, `/shift/closing`,
  `/shift/report/:shiftNumber`, with a new `ShiftModuleShell` sub-nav and a
  sidebar entry for both the owner and cashier navigation lists.
- `flutter analyze` is clean (only two pre-existing, unrelated warnings in
  `sales_screens.dart`). Two tests cover the module: a smoke test
  (`shift_overview_smoke_test.dart`) and a full five-step wizard walk-through
  (`shift_closing_flow_test.dart`, balanced scenario, operations â†’ cash â†’
  bar count â†’ final review â†’ confirm dialog â†’ success â†’ report route).
  Running the wizard test surfaced and fixed a real responsive bug: the
  stepper's full-label mode was switching on at the module's general tablet
  breakpoint (700px), which overflows with five Arabic step labels â€” it now
  switches at the desktop breakpoint (1100px). Deeper per-scenario coverage
  is left for a follow-up pass.
- Not done: backend integration, accounting/inventory posting, and real
  print/export â€” all explicitly out of scope for this UI-approval pass.
- Update: the module is now backed by a real `ShiftRepository` API client
  (`shifts/current`, `shifts/current/snapshot`, `shifts/history`,
  `shifts/{shiftNumber}/report`, `shifts/{shift}/close`); the demo scenario
  switcher was dropped from production wiring, and the older, separate
  `features/shift_close` module (and its `/shift-close` route) was retired in
  its favor â€” this is now the one Shift implementation.

### 2026-09-17 â€” Purchase item search usability review
- Evaluated the item picker implementation and ran two temporary widget probes using mocked inventory responses. Both reproduced defects: clearing a query before debounce completion still shows old results; typing a replacement after selecting an item clears the typed text.
- Code review also found no explicit arrow/Enter selection support and network errors rendered as empty search results.
- Live desktop interaction was interrupted by concurrent user input. No invoices were saved and no production code was changed. Temporary probes were removed after diagnosis.
- Recommended next step: fix selection/query synchronization and stale request cancellation, then add keyboard selection and distinct connection-error feedback.

### 2026-09-17 â€” Purchase item search repair
- Fixed query/selection synchronization so replacing a selected item preserves typed text.
- Debounced and in-flight responses are invalidated immediately on query changes, clear, selection, outside click, focus loss, and Escape. Removed stale results during new searches and prevented delayed overlays after dismissal/disposal.
- Added arrow-key highlighting with scrolling, Enter selection, and separate search-failure feedback with retry. Result overlay now anchors to the actual field bottom in RTL.
- Added 9 widget regression scenarios; all 14 focused picker and purchase-form tests passed. Flutter analyze reports only the pre-existing unnecessary_brace_in_string_interps info in create_discount_policy_screen_test.dart:780; no findings in changed files. git diff --check passed.
- No database, catalogue, stock, or backend changes. Next step: smoke-check the updated Windows UI after hot restart/rebuild.

### 2026-09-17 â€” Atomic Purchase Invoice posting, receiving, and cash settlement
- Added a dedicated `PurchasePostingOrchestrator` behind `POST /finance/purchases/{id}/post`. It validates permissions, branch and an unambiguous actor cash source before atomically posting the Supplier Invoice, completing remaining inventory receipt lines through `PurchaseReceivingService`, settling AP through `SupplierPaymentService`, and creating a linked posted Payment Voucher.
- Inventory purchases continue to use the existing Goods Receipt -> `InventoryPostingService` path, preserving stock movements, balances, WAC, unit conversions, landed costs, and receipt history. Expense/service and asset purchases create no stock movement.
- Cashiers must have an open shift in the invoice branch. The shift is bound to one active branch cash drawer; no bank, cross-branch, or arbitrary fallback is allowed. The payment is recorded as a shift expense so expected cash and closing reflect the purchase. Owners/managers without a shift require exactly one active branch cash drawer.
- Added schema links for shift cash source, Supplier Payment -> shift/voucher, Voucher -> purchase invoice/payment source, and idempotent shift movement sources. The migration performs no historical backfill or posting.
- The automatic voucher shares the Supplier Payment journal (Dr AP / Cr Cash) instead of creating a duplicate journal. Direct voucher reversal is blocked; reversing the Supplier Payment updates its linked voucher and shift cash movement consistently.
- Flutter Purchase Invoice now supports Save as Draft and unified Post, requires branch/receipt warehouse for posting, shows a server-resolved cash/shift confirmation, reports success, and links the payment voucher from invoice detail.
- New backend integration coverage passes 8 scenarios / 90 assertions covering inventory posting, double-submit idempotency, missing shift, shift expected cash, inventory/payment-stage rollback, old fully received invoices, expense/asset behavior, and branch isolation. Focused Flutter purchase/search tests pass (14 tests). The broader related Laravel run passed 106 tests / 961 assertions and retained four pre-existing authorization/bar-check expectation failures documented in the handoff; Flutter analyze is clean for changed files with one unrelated pre-existing info in the discounts test.

### 2026-09-19 — Purchase item mouse selection repair
- Root cause: the positioned overlay entry had only the popup width, while CompositedTransformFollower painted its result list below that parent. Flutter hit testing rejected mouse events outside the parent even though the list was visible. The overlay now has a full-screen hit-test parent and the follower remains anchored to the field; TapRegion still dismisses outside clicks.
- Preserved debounced server search and latest-request cancellation. Added mouse-click and scroll-then-click widget regressions. Purchase lines now retain stable widget identity, and choosing another item resets the purchase unit to that item's default while preserving the warehouse.
- Picker widget tests: 12 passed, including mouse click, scroll then click, and independent rows. Focused purchase and picker tests: 18 passed before the final two picker cases. Flutter analyze: one existing unused optional parameter warning in the purchase form and one unrelated discount-test info. Web and Windows release builds passed.

### 2026-09-19 — Follow-up: real mouse pointer regression
- Reproduced the reported failure with a widget test using PointerDeviceKind.mouse and separate pointer-down/up events. The previous tester.tap test used a touch pointer and missed it. On mouse down, the TextField lost focus and its focus listener removed the result overlay before ListTile.onTap could run.
- The result popup now tracks pointer-down inside its own region, so focus loss during a result click does not dismiss it. Selection closes the popup after updating the selected item. Tab, Escape, outside click, and ordinary blur still dismiss it.
- Focused picker and purchase-form suite: 20 tests passed, including the real mouse sequence. Flutter analyze retains the same two pre-existing findings. Web and Windows release builds passed after this follow-up fix.

### 2026-09-19 — Purchase receipt warehouse selector
- Fixed the invoice's optional all-branches state filtering out every branch warehouse. It now shows all accessible active warehouses when no invoice branch is selected, and the selected branch plus global warehouses once a branch is chosen. An incompatible line warehouse is cleared on branch change.
- Long warehouse names now fit the 190px selector via expanded layout and ellipsis. Added a widget regression with two branch warehouses; focused purchase and picker tests pass (21).
### 2026-09-19 — Direct purchase release readiness pass
- The default inventory purchase remains a single invoice form and posting action. Receive later is an unchecked operational option; it retains the separate partial receipt workflow.
- The purchase list and detail now label invoices spanning warehouses as “متعدد المخازن”. The detail shows a compact received quantity summary and explains why cancellation is unavailable after stock receipt.
- The purchase receipt mode migration was renamed to `2026_09_19_000001_add_purchase_receipt_mode.php` before staging; no historical stock is backfilled.

### 2026-09-19 � Supplier-specific purchase invoice numbering
- New purchase invoices receive a supplier-scoped, backend-generated reference using the stable supplier number and the existing locked number counter. The system PI number and optional external supplier document reference remain separate.
- Saved drafts keep their supplier and assigned number; changing supplier requires a new draft. The purchase form displays both automatic numbers read-only and labels the manual external reference separately.
- Added API regression assertions for independent supplier sequences, idempotent retry, optional external reference, and blocked supplier changes.

### 2026-09-20 - Manual Sales Invoice

- The form now offers direct posting from the editor. Posting uses the existing Sales Invoice service, which consumes inventory and records WAC/COGS in the same transaction.
- The form has a grouped header, detailed line controls, additional charges, and a totals preview. Backend totals remain authoritative.
- A line can sell an eligible inventory material directly. Its unit selector contains the base unit and active item-specific conversions. The invoice snapshots the selected unit and converted base quantity.
- The detail view shows the selling unit and line totals. Credit Note restock uses the original stock movement and cost snapshot.
- Focused backend pricing and posting tests, new raw-material tests, and targeted Flutter tests pass. The broader sales suites still contain failures in payment widget and sales-reporting fixtures.
- Deployment was not performed.
