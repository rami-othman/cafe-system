# Project Status

## Project Name

Cafe System 618

## Current Goal

Establish the general project foundation for a Flutter Windows desktop cafe and
restaurant management system.

## Current Phase

Phase 1 — Project Foundation

## Completed Work

- Final Finance audit canonicalized reachable legacy Finance URLs: operational
  `?tab=` paths and prior aliases now redirect to one canonical workspace,
  while Overview and Transactions remain the only `FinanceWorkspaceScreen`
  content paths. The complete Finance Laravel matrix (193 tests, 1,683
  assertions) and Finance Flutter suite (133 tests) pass.
- Completed the Phase 10 validation cleanup with dedicated Account Detail,
  Accounting Period Detail, and Payment Method financial-location widget tests
  at 1280, 1366, 1440, 1600, and 1920 pixels; each verifies RTL and no
  rendering overflow, with real mocked API contracts and drill-through flows.
- Extended Finance administration with tenant-scoped account detail and an
  expandable Chart of Accounts tree, account-to-General-Ledger drill-through,
  backend readiness-led accounting-period detail, payment-method financial
  location linking, and Finance Settings links/readiness cards. Verification:
  focused Laravel Finance tests, Finance Flutter tests, and the full Flutter
  suite pass; existing unrelated analyzer informational lints remain.
- Completed Finance Phase 1 shared visual foundation: exact Finance design tokens, canonical 12-tab navigation, reusable Finance shell/components, ten-row server pagination treatment, RTL/LTR amount handling, and widget regression coverage; individual screen redesign remains intentionally deferred to Phase 2.
- Completed Finance Phase 0.75 row-level branch-security regression coverage for canonical Finance records, actions, reports, dashboard scope, tenant-wide masters, and rejected-mutation side effects; no Finance UI work was started.
- Closed Finance Phase 0.5 contracts: checked in the corrected visual reference and frozen its design tokens; made cash/bank URLs kind-safe and branch-safe; added typed Flutter location contracts; and moved accounting-period operations to backend pagination at ten rows per page.
- Unified the Finance desktop navigation bar across all Finance routes, fixed
  its operational destinations, repaired Finance-only Arabic text encoding,
  and added a reusable ten-row paginator to the Finance tables.
- Added the connected Finance Operations demo to local/development/test
  database seeding. The idempotent demo now includes a paginated expense
  scenario while preserving its verified cash reconciliation and period close.
- Hardened Inventory Count and Bar Check posting: explicit uncounted state,
  base-unit snapshots, tolerance/reason/manager-review gates, and a required
  Bar Check shift-close gate. Count and Bar Check state helpers now live in
  their own feature slices while the legacy screen is migrated incrementally.
- Updated the RTL Start Stock Count modal with an explicit real-warehouse
  selection, partial-count category validation, backend branch-access checks,
  active-duplicate protection, generated-line coverage, and workspace routing.
- Rebuilt the Arabic RTL Stock Counts list around the live paginated inventory
  API: real status KPIs, period/warehouse/type/status/creator/source filters,
  creator options, row navigation, retry states, and desktop overflow coverage.
- Backfilled warehouse-material availability from existing stock balances so
  newly created stock counts for the Bar and other warehouses receive their
  real count lines; the inventory demo seeder now maintains those links.
- Aligned the Stock Count Workspace controls and line-table density with the
  approved reference, including a real-data reason-required filter.
- Added the Bar Check backend foundation: tenant-scoped templates and template
  lines, shift-linked `SHIFT_CHECK` stock-count snapshots, and a shift-close
  blocker for required incomplete checks. The Inventory Flutter center and
  workspace are the next implementation slice.
- Arranged inventory balance summary cards in a compact horizontal desktop row,
  with a responsive stacked layout for narrower windows.
- Added a visible, draggable vertical scrollbar to the Inventory Items table,
  while retaining horizontal scrolling for wide data sets.
- Enabled the same vertical table scrolling for inventory balances, movements,
  and stock-count list screens.
- Paginated the Inventory Movements table at five server-loaded records per
  page, with range and previous/next controls.
- Preserved the movement API pagination metadata instead of unwrapping its
  data array before the page parser receives it.
- Made the paginated Inventory Movements table end after the records on the
  current page instead of stretching to fill the remaining viewport.
- Made the Inventory Movements page scroll as needed so the page controls do
  not overflow below the table on shorter Windows windows.
- Applied the five-row paginated table treatment to Inventory Balances and
  widened filter dropdowns so their full labels remain visible.
- Created the initial Flutter project scaffold.
- Added foundation dependencies for routing, state management, dependency
  injection, value equality, and currency formatting.
- Created the feature-based folder structure.
- Added the app entry point, router, desktop shell placeholder, core utilities,
  shared widgets, and POS placeholder screen.
- Added general documentation/control files for future Codex work.
- Implemented shared theme/design system foundation.
- Implemented desktop app shell with sidebar, topbar, main content slot, and
  right panel slot.
- Implemented static POS screen UI with product area and cart panel.
- Fixed responsive/adaptive layout behavior for POS shell and static POS UI.
- Implemented POS Cubit with fake data interactions, cart updates, order type
  selection, and local totals calculation.
- Fixed POS search field focus/typing bug and improved search field
  spacing/alignment.
- Fixed POS search field visual design by removing nested input border and
  aligning icon/text spacing.
- Fixed compact window overflow bugs in topbar and collapsed sidebar.
- Implemented product customization/modifiers dialog with local selection state
  and cart integration.
- Implemented POS discount dialog with coupon code input, available discount
  cards, and local totals integration.
- Fixed POS discount dialog coupon Apply button text wrapping and added compact
  layout coverage.
- Implemented POS payment flow modal with local cash/card/wallet payment
  handling and cart clearing on completion.
- Implemented receipt preview modal with completed order snapshot after local
  payment.
- Updated receipt preview Print Receipt placeholder to close the dialog and
  show payment completion feedback.
- Implemented Select Customer modal and connected optional customer selection
  to the POS cart flow.
- Fixed Select Customer dialog footer button wrapping and blocked hidden
  filtered selections from being confirmed.
- Implemented Orders screen with fake active/held order data, filters,
  responsive order cards, and sidebar routing.
- Adjusted Orders card grid widths to keep cards closer to the design while
  still wrapping responsively.
- Implemented Order Details side panel with fake detail data, customer info,
  item breakdown, payment summary, and timeline.
- Implemented local Refund Flow modal from Order Details with full/partial
  refund selection and validation.
- Connected POS order flow to Laravel backend API using Dio for catalog loading,
  backend order creation, cart item updates, discounts, payment, and receipt
  preview.
- Fixed backend POS product category mapping so products returned with
  `categoryId` display under the selected category tabs.
- Connected Orders screen and Order Details side panel to Laravel backend using
  Dio.
- Added the Menu Management foundation with immutable menu domain models, mock
  repository data, Menu Cubit/state, dependency injection, placeholder routes,
  sidebar navigation, and automated repository/routing coverage.
- Implemented the Figma-based Menu Overview UI with a Menu-specific top bar,
  action buttons, KPI cards, internal tabs, filters, and recent activity table.
- Implemented the Figma-based Products List UI with responsive filters, mock
  product rows, reusable type/status chips, row actions, and pagination.
- Implemented the Figma-based Create Product General Information UI with local
  form state, responsive form sections, product summary/progress, channel
  visibility controls, a fixed action footer, and navigable Menu/Products
  breadcrumbs.
- Implemented the Figma-based Modifier Groups UI with Cubit-loaded mock data,
  local search and selection, responsive master/detail layout, options table,
  assigned product chips, and placeholder actions.
- Implemented the Create Discount Policy UI with local form state, responsive
  policy sections, POS preview, configuration summary, sticky actions, sidebar
  routing, and automated route/layout coverage.
- Implemented the Figma-based Discounts & Coupons list with typed local mock
  data, Cubit-backed search/status/pagination state, summary cards, table
  actions, and preserved Create Discount routing.
- Completed a full POS and Orders flow audit across Flutter, Dio, Laravel, and database behavior. See docs/POS_FLOW_AUDIT.md.
- Implemented Flutter-side canonical cart configuration matching, defensive quantity merging, and serialized cart mutations.
- Implemented Flutter payment submission guards, payment/receipt separation, uncertain-payment verification, and receipt retry recovery.
- Implemented safe backend product-detail loading and Flutter order-context persistence for customer and order type.
- Removed Flutter table selection for the current phase; all new orders use `tableId: null`.
- Fixed the available POS discounts response so it is always returned as a JSON
  list after inactive or expired discounts are filtered out.
- Made POS coupon matching case-insensitive so backend coupon codes work
  regardless of how they were capitalized when created.
- Connected the Orders branch selector to backend branch IDs, so order queries
  no longer use a stale hard-coded branch ID.
- Connected the Daily Operational Report to the Laravel API, including daily
  sales KPIs, hourly sales, payment and order breakdowns, products, refunds,
  discounts, and recent transactions populated by the POS demo seeder.
- Fixed the Discounts table action overflow, standardized the desktop branch
  label casing, and hardened Orders list/detail loading against stale requests
  while preserving actionable API messages.
- Implemented the Finance & Inventory Setup foundation with live Laravel API
  repositories, Cubit state, RTL Windows screens for setup readiness,
  warehouses, chart of accounts, and journal entries, plus sidebar routing.
- Implemented the Phase 2 Inventory Center feature with live tenant-scoped
  APIs, inventory dashboard, items, warehouse balances, immutable movement
  ledger entry, and stock-count workflow screens in the RTL Windows app.
- Completed Finance Phase 2 Overview parity with the Claude reference: the
  canonical `/finance` Overview now renders six live KPI cards, a
  backend-driven needs-attention panel, a revenue-vs-expenses trend chart,
  branch performance bars, and a recent activity table, all sourced from the
  existing `dashboard`/`dashboard/trends`/`dashboard/branches` endpoints with
  real period/branch/comparison context, loading/empty/error states, and
  canonical KPI/attention/activity navigation. No Flutter-side accounting
  calculations or fake data were introduced. Transactions, Cash & Banks,
  Expenses, Suppliers, Reconciliation, Journal, Daily Closing, Reports,
  Accounts, Periods, and Settings remain deferred to later phases.
- Completed Finance Phase 3 Financial Transactions and Journal Drawer parity
  with the Claude reference: the canonical `/finance?tab=transactions` screen
  now has its own dedicated widget (no longer the shared generic workspace
  table) with backend-driven summary KPIs, real global period/branch context,
  backend-driven type/status/account/payment-method filters and debounced
  search, a server-paginated table with debit/credit shown directly from the
  backend, and a centralized transaction-type-to-Arabic-label/badge mapper
  shared with the Overview. Row clicks open a production Journal Drawer that
  lazily loads journal impact lines and reuses the existing
  `FinanceSourceNavigation` contract for "view source" and "view journal"
  actions. Added one small backend endpoint
  (`GET finance/transactions/branches`) so the branch selector only ever
  offers the actor's authorized branches, gated by the same
  `finance.transactions.view` permission and covered by branch-isolation
  tests. No transaction export exists yet — the "تصدير" action was
  intentionally omitted rather than wired to a fake or newly invented
  mechanism.
- Completed Finance Phase 4 Cash & Banks, Account Details, and Transfers
  parity with the Claude reference: `/finance/cash-banks` is rebuilt on the
  shared `FinanceShell`/Phase 1 components with four backend-authoritative
  KPIs (cash/bank totals composed client-side only as a sum of already-
  authorized per-account balances; today's incoming/outgoing likewise),
  a real configuration warning driven by payment methods missing a linked
  financial location (no hard-coded method name), separate النقدية/البنوك
  account groups matching Claude's row layout, and a "recent cash & bank
  movements" feed reusing the Phase 3 transactions endpoint. Account
  create/edit/activate-deactivate, account detail (KPIs + real ledger
  movements with running balance), and transfers (validation, the fixed
  debit-destination/credit-source accounting-impact preview, and posting)
  are all wired to the existing `FinancialLocationService`/
  `CashTransferService` contracts — no balance, posting, or reversal logic
  was duplicated in Flutter. Extracted the Phase 3 journal drawer into a
  shared `FinanceJournalDrawerBody` (now detail-driven rather than row-
  driven) so Cash & Banks movement rows reuse the same production journal
  inspection panel, extended with an "عكس التحويل" action that calls the
  specialized cash-transfer reversal endpoint (never a generic journal
  reverse) when a movement is a reversible, posted, not-yet-reversed
  transfer. Added one small backend filter (`has_cash_effect` on
  `GET finance/transactions`) reusing the existing cash/bank location set,
  with tests.
- Completed Finance Phase 5 Expenses parity with the Claude reference:
  `/finance/expenses` is rebuilt on the shared `FinanceShell`/Phase 1
  components with a real global period/branch context (no comparison
  toggle — the backend has no comparison-period concept for expenses),
  four backend-computed KPIs from a new `GET finance/expenses/summary`
  endpoint (reusing the exact same filtered/visible query as the list, so
  the totals are never a partial-page approximation), status/category
  filters, and a 7-column table matching the design contract. Lifecycle
  actions (submit/approve/reject/pay/reverse) are driven entirely by the
  backend's existing per-record `allowedActions` field — computed from
  actual permissions and the approval policy (e.g. a creator can never
  approve their own expense) — rather than re-derived from `status` alone,
  closing a real gap where the previous UI could offer an action the
  backend would then reject. Payment reuses `FinanceAccountImpactPreview`
  (debit the expense category account, credit the paid-from cash/bank
  account) and the shared journal drawer for "عرض القيد"/"عرض قيد العكس".
  A rejected expense has no resubmit action, matching the backend's actual
  transition table, not Claude's demo. Added a small `GET
  finance/expenses/branches` endpoint (mirroring Phase 3's
  `transactions/branches`) so the branch selector never leaks unauthorized
  branches, and extended `FinanceSourceNavigation`'s expense destination
  with the expense id so a journal's "عرض المصدر" opens that exact expense.
  Extended the shared `FinanceStatusBadge` resolver with the
  `pending_approval`/`reversed` states and split `approved` from `paid`
  instead of collapsing them onto one raw/misleading label.
- Completed Finance Phase 6 Suppliers & Accounts Payable: `/finance/suppliers`
  (list) and `/finance/suppliers/:id` (profile) are rebuilt on the shared
  `FinanceShell`/Phase 1 components. The list shows four backend-derived KPIs
  (outstanding, overdue, active suppliers, average payment terms — the last
  only computed once the full unpaginated set is loaded, never approximated
  from one page), a paginated `FinanceTable` via the existing `data`+`meta`
  `finance/suppliers` endpoint, and status/search filters (no global period
  context — the backend supports no date/branch filter on supplier master
  data, matching the Cash & Banks precedent). The Profile screen has an
  Entity Header, four KPIs, and three tabs (Invoices/Payments/Statement,
  dropping the old unimplemented "Purchases" placeholder tab). Invoice and
  payment lifecycle actions (edit/post/reverse) are entirely
  `allowedActions`-driven from the backend, not re-derived from `status`.
  The Supplier Payment dialog was redesigned around spec: a distinct
  "Payment Amount" input plus live-computed "Allocated Amount" and
  "Remaining Unallocated Amount" (must reach exactly 0.00, matching the
  backend's exact-sum validation in `SupplierPaymentService::pay()`), with
  the existing user-controlled per-invoice allocation inputs preserved as-is
  — deliberately never auto-filling/paying all open invoices. Both invoice
  and payment detail dialogs reuse the shared `FinanceJournalDrawer`/
  `FinanceJournalDrawerBody` for "عرض القيد", and payment allocation rows
  drill into the linked invoice detail. Added an `id` field to each
  `GET finance/suppliers/{id}/statement` line (backend + test) so the
  Statement tab's rows can drill down to the exact invoice/payment record;
  the statement's summary (opening/closing/total invoices/total payments) is
  computed client-side from the endpoint's already-complete, unwindowed line
  list. Extended `FinanceSourceNavigation`'s supplier_invoice/supplier_payment
  destinations with the record id (`?invoiceId=`/`?paymentId=`); since the
  journal source payload carries no supplier id, the Suppliers list screen
  resolves the invoice/payment's supplier once and redirects to its profile
  with `?openInvoice=`/`?openPayment=`, which auto-opens that detail dialog.
  Fixed a real, previously-uncaught overflow bug where none of the invoice
  and payment form dropdowns set `isExpanded: true`, so the longest item in
  each list (not just the selected one) could overflow the dialog. Also
  fixed two pre-existing status-label bugs: supplier active/inactive reused
  `FinanceStatusBadge`'s `active` case (renders "مكتمل"/completed, not
  "نشط") — mirrored the Cash & Banks Phase 4 `_ActiveBadge` fix — and an
  overdue invoice incorrectly reused `FinanceStatusBadge`'s `overdue` case
  (grouped with rejected/cancelled, renders "مرفوض"/rejected) instead of a
  dedicated "متأخر" badge.
- Completed Finance Phase 7 Reconciliation: `/finance/reconciliation` (list)
  and `/finance/reconciliation/:id` (workspace) replace the old generic
  `FinanceOperationScreen(kind: reconciliation)` entirely — that kind and its
  reconciliation-only rendering/mutation code were deleted, not left dead
  behind a changed route; the legacy `/finance/reconciliations` (plural)
  paths now resolve to the same dedicated screens rather than a second
  implementation. The list shows the four backend-derived KPIs (open,
  completed, unresolved difference, need-matching) and the exact
  period/account/type/branch/balances/difference/progress/status columns
  from `FinancialReconciliationQueryService`, plus a create-session dialog
  using the real `POST finance/reconciliations` contract (cash/bank location
  or card payment method, date range). The workspace renders a Cash layout
  (KPIs, readiness, a real system-movements table) or a Bank/Card two-panel
  compare (system transactions vs. statement lines) depending on backend
  `type`, entirely from `GET .../{id}`, `.../system-transactions`, and
  `.../suggestions`. Matching reuses the backend's actual one-statement-line-
  to-one-journal-entry `POST .../matches` contract: a single Match click is
  decomposed into one call for 1:1, or one call per pairing for many-to-one/
  one-to-many (mirroring the backend's own many-to-one/one-to-many test
  coverage), gated on the selected totals differing by zero; true many-to-
  many (multiple selected on both sides at once) has no atomic backend
  operation to submit, so it's deliberately disabled with an explained error
  rather than inventing a bulk-match endpoint. Suggestions, unmatch (per
  match record, not a fabricated "match group"), add/delete statement line,
  and complete all call the corresponding real endpoints and reload
  authoritative state afterward — never mutate rows locally as truth.
  Readiness is exactly the backend's `canComplete` boolean plus
  `blockingReasons` (Ready/Blocked/Completed); Claude's mock "Warning —
  complete anyway" tier has no backend support (`complete()` rejects on any
  blocker with no leniency), so it was not fabricated. Completed sessions are
  read-only (no checkboxes, match/unmatch/add/delete/complete actions) with a
  completion banner; "completed by" is omitted since the backend returns
  only a bare numeric user id with no name to show. Journal/source drill-down
  reuses the existing shared `FinanceJournalDrawer`/`FinanceSourceNavigation`
  unchanged — no separate resolver was added for Reconciliation. Fixed a
  real, previously-uncaught overflow bug in the Match button (`_matching`
  was never reset to `false` after a successful match, leaving a spinner
  stuck forever and `pumpAndSettle` hanging in tests). Also fixed an
  unrelated pre-existing backend bug found while getting a clean test
  baseline: `FinanceOperationsDemoSeeder`'s cash-reconciliation close date
  was a hardcoded past string while the POS sale/refund it seeds always post
  "today" — once the wall clock passed that hardcoded date, the seeded sale/
  refund fell outside the reconciliation window and broke the hardcoded
  actual-cash assumption with a false `NON_ZERO_DIFFERENCE`, failing every
  test that seeds (this was silently masked in Phase 6's report as an
  "unrelated" `DailyReportApiTest` failure); the close date now tracks
  `now()` like the sale/refund it depends on.

## In Progress

- Phase 2.5 UI/UX unification for the inventory and finance/setup workspace.
- Inventory Management UI has been rebuilt as an English LTR desktop module,
  including live dashboard, item list/details, balances, movement ledger,
  movement posting, and stock-count entry points.
- Consolidated inventory demo seeding around one tenant-level catalog,
  deactivated obsolete generic demo items safely, and added tenant-scoped
  catalog-identity protection for SKU and no-SKU items. Inventory selectors
  now show searchable `Item Name — SKU — Unit` labels from active items only.
- Added the Inventory Management horizontal navigation for Overview, Inventory
  Items, Warehouse Balances, Inventory Movements, and Stock Counts. Added
  connected stock-count detail routes and kept action/detail pages outside the
  tab strip.
- Inventory Items now uses tenant-scoped server filtering and pagination, real
  available stock, and a complete add/edit form with category, stock-control,
  notes, and safe deactivation handling.
- Hardened the source-derived Inventory shell: physical RTL sidebar placement
  is covered at 1440×900, while Inventory-specific geometry no longer changes
  the existing LTR modules.
- Removed runtime branch fallback data. Backend-free widget runs use an
  explicit operational-branch fake instead.
- Reconciled the Inventory source map and Arabic RTL secondary navigation with
  the Claude Module/Extensions/Operations exports.
- Aligned the live Stock Counts list, start-count dialog, and count workspace
  with the approved RTL desktop layout: compact filters/KPIs/tables, real
  cycle-category selection, count notes, workspace filter pills, and
  lifecycle-safe footer actions.
- Unified the Stock Count list and workspace tables with the shared Inventory
  Items table geometry and visual defaults.
- Hardened the Inventory Items filter dropdown so its selected value is always
  represented by one unique menu item, including the `packaging` type.
- Fixed the Inventory Item form type selector to support every backend-valid
  item type, including `packaging`, and to safely handle stale values.
- Fixed the desktop Warehouse Balances table width at 1300px and preserved
  horizontal scrolling below that available content width.
- Added an internal vertical scrollbar to the Inventory Items table so its
  result rows no longer clip the page footer.
- Stock Count workspace now stages entered quantities for review submission,
  saves them through the existing line endpoint first, and then uses the real
  submit transition; users no longer need to press Enter in each quantity field.

## Next Step

Connect Orders actions (payment, resume, cancel, and complete) to their backend
workflows when those APIs are ready.

## Architecture Decisions

- Flutter is used for the Windows desktop app.
- The app is desktop-first, with possible future tablet support.
- The project uses feature-based architecture.
- Each feature uses an MVC-style internal structure.
- Cubit is used as the controller/state-management layer.
- Theme values should be centralized.
- Feature-specific logic should stay inside its feature.
- Shared reusable UI should go inside `shared`.

## Important Constraints

- Do not create feature-specific documentation until requested.
- Do not create `POS_FLOW.md` yet.
- Do not add database or local storage yet.
- Keep changes focused and avoid unrelated refactors.
- Avoid over-engineering.

## Open Questions

- Detailed component states are not fully defined yet.
- The expected Manrope variable font file still needs to be added if absent.
- Tablet support requirements are not defined yet.

## Recent Changes Log

- 2026-09-02: Completed Finance Phase 7 Reconciliation: `/finance/reconciliation`
  and `/finance/reconciliation/:id` replace the old generic
  `FinanceOperationScreen(kind: reconciliation)` (deleted, not left dead) and
  the legacy plural route now points at the same screens. Cash workspace
  shows real balances/readiness/system movements; Bank/Card workspace is a
  real two-panel system-vs-statement compare whose Match action decomposes
  into the backend's actual one-line-to-one-entry match() calls (1:1, N:1,
  1:N — true N:M is disabled, no bulk-match endpoint exists to submit it
  atomically). Suggestions, unmatch (per match record), add/delete statement
  line, and complete all call real endpoints and reload authoritative state.
  Readiness is exactly backend `canComplete`/`blockingReasons` — no fabricated
  "warning, complete anyway" tier, since `complete()` has no such leniency.
  Fixed a stuck-spinner bug (`_matching` never reset after a successful
  match) and an unrelated pre-existing backend bug: `FinanceOperationsDemoSeeder`'s
  hardcoded cash-reconciliation close date drifted behind the POS sale/
  refund it seeds (which always post "today"), breaking every seeded test
  with a false `NON_ZERO_DIFFERENCE` once the wall clock passed it — now
  tracks `now()`.
- 2026-09-02: Completed Finance Phase 6 Suppliers & Accounts Payable: rebuilt
  `/finance/suppliers` and `/finance/suppliers/:id` on the shared Finance
  design system, with `allowedActions`-driven invoice/payment lifecycle
  buttons, a redesigned Payment dialog (explicit Payment Amount / Allocated /
  Remaining Unallocated, still user-controlled per-invoice allocation, never
  auto-paying all open invoices), and shared journal-drawer/statement
  drill-down navigation. Added an `id` field to supplier statement lines
  (backend + test) for drill-down, extended `FinanceSourceNavigation` with
  invoice/payment ids and a supplier-resolving redirect for the "عرض المصدر"
  deep link. Fixed a real dropdown overflow bug (`isExpanded` missing on the
  invoice/payment form dropdowns) and two status-label bugs where supplier
  active/inactive and invoice overdue state were rendered through
  `FinanceStatusBadge`'s unrelated `active`/`overdue` cases instead of their
  own dedicated badges.
- 2026-09-02: Completed Finance Phase 5 Expenses: rebuilt `/finance/expenses`
  on the shared Finance design system with real KPIs from a new
  `GET finance/expenses/summary` endpoint, status/category filters, global
  period/branch context, and a detail view whose lifecycle buttons are
  driven by the backend's own `allowedActions` (permission- and approval-
  policy-aware, not just `status`). Payment shows the accounting impact
  preview; paid/reversed expenses link to the shared journal drawer. Added
  `GET finance/expenses/branches` for a leak-safe branch selector and
  extended `FinanceStatusBadge`/`FinanceSourceNavigation` centrally rather
  than duplicating status or navigation logic locally.
- 2026-09-01: Completed Finance Phase 4 Cash & Banks: rebuilt
  `/finance/cash-banks` on the shared Finance design system with real
  KPIs, a payment-method configuration warning, cash/bank account groups,
  account create/edit/activate-deactivate, account detail with real ledger
  movements, and a transfer dialog with accounting-impact preview and
  active-account-only selection; generalized the Phase 3 journal drawer
  into a shared, detail-driven `FinanceJournalDrawerBody` with a
  transfer-reversal action; added a small `has_cash_effect` transaction
  filter for the account-agnostic recent-movements feed.
- 2026-09-01: Completed Finance Phase 3 Financial Transactions and Journal
  Drawer: dedicated `FinanceTransactionsView` (summary KPIs, real
  period/branch context, backend-driven filters/search, server pagination,
  centralized type badges) replaces the generic workspace table for the
  Transactions tab; added a production Journal Drawer with lazy-loaded
  impact lines and centralized source/journal navigation; added the
  branch-scoped `GET finance/transactions/branches` endpoint with tests.
- 2026-09-01: Completed Finance Phase 2 Overview parity: connected the six KPI
  cards, needs-attention panel, revenue/expense trend chart, branch
  performance, and recent activity table to the live dashboard/trends/branches
  endpoints, and fixed the recent activity table to show localized
  transaction-type labels and navigate to the correct canonical Finance
  destination per source type (expense, cash transfer, supplier invoice/
  payment, order/refund, inventory movement, journal) instead of always
  opening Journal Entries.
- 2026-09-01: Corrected the Finance UI encoding and navigation, introduced a
  shared 10-row Finance table paginator, applied the Finance analyzer fixes,
  and made the verified connected Finance demo part of non-production seeds.
- 2026-06-09: Implemented shared theme/design system foundation with warm
  artisan cafe colors, Manrope typography registration, spacing/radius/size
  tokens, shared button/text-field/card updates, and design-system
  documentation.
- 2026-06-09: Implemented the desktop app shell with fixed sidebar, topbar,
  main content slot, and right panel placeholder based on the approved Figma
  POS screen.
- 2026-06-09: Implemented the static POS screen UI inside the app shell with
  mock product cards, category/search controls, static cart items, order type
  selector, totals, secondary actions, and pay button.
- 2026-06-09: Fixed POS responsive behavior with centralized breakpoints,
  collapsed sidebar rail at medium/compact widths, hidden inline cart in compact
  mode, adaptive topbar cart action, bounded search width, adaptive product
  grid columns, and safer cart rows.
- 2026-06-09: Implemented POS Cubit fake-data interactions for loading
  products/categories, category and search filtering, cart add/update/remove,
  order type selection, Cancel cart clearing, and local subtotal/tax/total
  calculations.
- 2026-06-09: Created general project documentation/control files:
  `AGENTS.md`, `PROJECT_STATUS.md`, `README.md`, `docs/ARCHITECTURE.md`,
  `docs/CODEX_WORKFLOW.md`, `docs/ROADMAP.md`, `docs/DESIGN_SYSTEM.md`, and
  `docs/DECISIONS.md`.
- 2026-06-09: Established the initial Flutter app foundation with app routing,
  desktop shell placeholder, core/shared folders, POS placeholder files, and
  foundation dependencies.
- 2026-06-16: Implemented POS discount dialog with coupon entry, fake available
  discount cards, local validation, applied discount state, and pre-tax totals
  integration.
- 2026-06-16: Fixed the POS discount dialog coupon Apply button wrapping issue
  and covered compact discount dialog layout behavior with widget tests.
- 2026-06-16: Implemented POS payment flow modal with cash amount entry, quick
  cash buttons, payment method selection, local fake card/wallet completion,
  split-payment placeholder, and cart clearing after completion.
- 2026-06-17: Implemented receipt preview modal with local completed-order
  snapshot, thermal receipt paper preview, placeholder WhatsApp/print actions,
  and receipt snapshot Cubit coverage.
- 2026-06-17: Updated the receipt preview Print Receipt placeholder so it
  dismisses the preview and shows `Payment completed`.
- 2026-06-17: Implemented Select Customer modal with fake local customers,
  cart header selection, receipt customer snapshot display, and payment reset
  to Walk-in Customer.
- 2026-06-17: Fixed Select Customer dialog footer button wrapping and disabled
  confirmation when the selected customer is filtered out of the visible list.
- 2026-06-20: Implemented Orders screen with fake active/held order data,
  filters, responsive order cards, local placeholder actions, and sidebar
  routing.
- 2026-06-20: Adjusted Orders card grid widths to keep order cards compact and
  responsive across desktop window sizes.
- 2026-06-20: Implemented Order Details side panel with fake detail data,
  customer info, item breakdown, payment summary, placeholder actions, and
  timeline.
- 2026-06-20: Implemented local Refund Flow modal from Order Details with
  safety warning, full/partial refund selection, amount validation, reasons,
  manager notes, and local refund state updates.
- 2026-06-20: Connected POS order flow to Laravel backend API using Dio for
  catalog loading, backend order creation, cart item updates, discounts,
  payment, and receipt preview.
- 2026-06-20: Fixed POS product grid filtering by mapping backend product
  `categoryId` values to category names and returning `categoryName` from the
  menu products API.
- 2026-06-20: Connected Orders screen and Order Details side panel to Laravel
  backend using Dio, including list/detail endpoints, filter mapping, status
  mapping, and safe placeholders for order actions.
- 2026-07-01: Added the Menu Management foundation with menu catalog models,
  mock repository data, Cubit/state filtering, eight title-only routes, Menu
  sidebar activation, service-locator registrations, and automated tests.
- 2026-07-06: Implemented the desktop-first Menu Overview UI from Figma,
  including the scoped shell header, action controls, Cubit-backed KPI cards,
  responsive tabs and filters, exact mock activity rows, status chips, and
  widget/routing coverage.
- 2026-07-06: Implemented the desktop-first Products List UI from Figma with a
  Menu Management top bar, page actions, responsive search/filter controls,
  five exact mock catalog rows, reusable product chips, icon thumbnails, row
  actions, pagination, and widget/routing coverage.
- 2026-07-06: Implemented the desktop-first Create Product General Information
  UI from Figma with local-only form state, reusable Menu form widgets,
  responsive two-column layout, locked setup progress, fixed action footer,
  placeholder save feedback, and widget/routing coverage.
- 2026-07-06: Made the Create Product Menu and Products breadcrumbs navigate
  directly to `/menu` and `/menu/products`, with routing test coverage.
- 2026-07-06: Implemented the desktop-first Modifier Groups UI from Figma with
  exact mock group counts, local search/selection, reusable group/detail/table
  widgets, assigned product chips, placeholder actions, responsive stacking,
  and widget/routing coverage.
- 2026-07-06: Implemented the desktop-first Create Discount Policy UI from the
  supplied Figma reference and screenshot, including the `/discounts/create`
  route, active Discounts sidebar state, local-only policy controls, responsive
  form cards, POS preview, summary panel, sticky actions, and widget coverage.
- 2026-07-12: Implemented guarded Flutter payment submission, confirmed-payment
  cart clearing before independent receipt retrieval, receipt retry recovery,
  uncertain-payment order-status verification, and focused payment tests.
- 2026-07-12: Implemented explicit backend product-detail loading, safe
  no-fallback failure handling, and serialized order-context persistence for
  customer and type updates. Table selection is intentionally deferred; all
  POS order creation sends `tableId: null`.
- 2026-07-15: Implemented the desktop-first Discounts & Coupons list from
  Figma node 66:2 with local-only filtering and pagination, reusable discount
  widgets, active sidebar routing, and a local branch selector in the shared
  top bar. No discount backend or calculation logic was added.
- 2026-07-15: Fixed the Discounts table action-cell overflow at the desktop
  sidebar breakpoint by matching the two Figma row actions, with a shell-level
  regression test at 1200 px.
- 2026-07-15: Added reusable clickable breadcrumbs to Discounts Create and
  Menu child routes so direct navigation no longer requires using the sidebar
  to return to an ancestor screen.
- 2026-07-18: Fixed the available POS discounts API response to reindex the
  filtered collection. This lets the Flutter POS dialog display active
  discounts when earlier records are inactive or expired.
- 2026-07-18: Made POS coupon matching case-insensitive so lowercase backend
  codes such as `zaher` apply correctly from the Flutter discount dialog.
- 2026-07-18: Connected Orders branch selection to backend branch data and
  passed the selected branch ID to order-list API requests.
- 2026-07-30: Prevented stale Orders list and detail responses from replacing
  newer UI state, cleared the detail panel on context changes or close, and
  surfaced backend API messages. Fixed Discounts table action wrapping and the
  initial POS branch-label regression; added focused regression coverage.
- 2026-08-16: Added the RTL Finance & Inventory Setup module backed by Laravel:
  readiness checklist, warehouse setup, chart of accounts, and journal draft/
  posting screens. The module uses the existing Dio, GetIt, Cubit, go_router,
  shell, and desktop UI primitives.
- 2026-08-17: Added the Inventory Center frontend and Laravel domain layer:
  weighted-average warehouse balances, immutable stock movements, controlled
  stock counts, demo inventory data, and tenant-isolation feature tests.
- 2026-08-17: Unified the Inventory Center and Finance & Inventory Setup
  presentation with reusable RTL desktop page headers, KPI cards, filter bars,
  status badges, data-table shells, and loading/empty/error states while
  preserving the existing Cubit, repository, route, and API integrations.
- 2026-08-20: Replaced the Reports sidebar destination with the English LTR
  Reports Overview vertical slice. It uses a tenant-scoped Laravel overview
  endpoint, typed Flutter repository/Cubit models, real filters, availability
  states, chart, branch comparison, products, and operational exceptions.
- 2026-08-20: Refined only the Inventory Dashboard with live scoped KPIs,
  branch/warehouse/date/search filters, warehouse value bars, low-stock alerts,
  and immutable movement history from the inventory dashboard API.
- 2026-08-20: Completed the Inventory Items vertical slice with paginated,
  server-filtered catalog results; real available quantity and stock state; and
  an add/edit form that supports barcode, category, cost, thresholds, notes,
  and deactivation confirmation without creating opening stock automatically.
- 2026-08-20: Fixed the Inventory Dashboard query contract so
  `compare_previous` is serialized as Laravel-compatible `1` or `0`.
- 2026-08-20: Refined the Inventory Item Details vertical slice with a
  tenant-scoped summary response, active warehouse balances, the newest five
  immutable movements, and item-specific KPI, balance, and history layouts.
- 2026-08-20: Applied the pending inventory catalog-identity migration to the
  running PostgreSQL backend, restoring item save/edit operations; connected
  Inventory Items dropdown filters to live refreshes and tightened their
  desktop control/table layout.
- 2026-08-20: Enforced a controlled inventory-unit catalog end to end. Item
  create/edit now uses a searchable English-label selector, the API rejects
  arbitrary units, existing units were normalized to canonical codes, and all
  inventory displays use friendly labels while movements and stock counts
  inherit the selected item's unit.
- 2026-08-20: Completed Phase 1 inventory master data with a tenant-scoped
  Units & Conversions screen and Laravel API. Conversions are stored per item,
  use controlled source and target units only, preserve inactive records, and
  protect an item's base unit after a conversion or stock history exists.
- 2026-08-23: Began the source-audited Inventory expansion: added a shared
  operational branch context for the top bar, POS, Orders and Inventory;
  introduced a backwards-compatible RTL shell configuration for Inventory;
  bundled IBM Plex Sans Arabic; and applied Claude-reference sidebar/top-bar
  dimensions without changing the default LTR shell.
- 2026-08-23: Applied the first visual-correction pass to the existing
  Inventory screens: Arabic RTL headers, controls, filter labels, tables,
  dialogs, statuses and feedback now retain their current live Inventory APIs
  while using the source-matched Inventory typeface in shared management
  primitives.
- 2026-08-23: Started the Stock Counts refactor by exposing the existing
  tenant-safe count-line and lifecycle APIs in the Flutter workspace. Users can
  add counted item lines and move a count through start, submit, approve and
  an explicitly confirmed variance-posting step without duplicating the count
  workflow.
- 2026-08-23: Resolved all Dart analyzer findings across the Finance,
  Inventory, and Reports modules, including unsafe asynchronous context usage,
  unused Inventory widgets, deprecated form-field values, and query-map lints.
- 2026-08-26: Completed the Stock Count Workspace vertical slice: it now uses
  the existing count-detail API, immutable creation-time stock snapshots,
  debounced line autosave with visible saving/saved/failed states, real
  variance/reason validation, lifecycle submission, read-only final states,
  and branch-access checks for line edits and transitions. Final variance
  posting remains intentionally outside this slice.
- 2026-08-27: Added the Bar Check Template and Warehouse Transfer vertical
  slices. Templates now support persisted branch/warehouse configuration,
  editable live inventory lines, tolerance type/value and review rules. Draft
  transfers support real line editing, submission, dispatch through immutable
  stock movements, and idempotent receipt posting with received/discrepancy
  quantities in the RTL inventory workspace.
- 2026-08-27: Hardened Inventory posting before the next workflow phase:
  movement writes now pass through the Inventory domain posting service with
  idempotency, base-unit conversion, integer-safe decimal arithmetic, and a
  dry-run reconciliation command. Existing tenant-header development behavior
  and Flutter movement routes remain compatible.
