# Cafe 618 Inventory — source-derived implementation plan

## Delivery rules

- Preserve the confirmed dirty baseline; extend it in place.
- Use the three Claude exports as the UI authority, never `_ds/classical-*`.
- Ship every Inventory screen in Arabic RTL, retaining source LTR islands for
  numeric values, SKU, dates and formulas.
- Preserve correct existing ledger, tenant, audit, weighted-average and
  negative-stock foundation rather than reimplementing it.
- Reports Center is not in scope.

## Phase 1 — shared operational and RTL foundation (first execution phase)

1. Introduce a shared operational branch-context Cubit/repository backed by
   the current branches API. Migrate `AppTopBar`, POS, Orders and Inventory so
   Inventory never depends on `OrdersCubit`.
2. Bundle/configure IBM Plex Sans Arabic 400/500/600/700; establish Inventory
   Arabic copy and deterministic fallback.
3. Make `AppShell`, sidebar, top bar, breadcrumbs, tables and action alignment
   direction-configurable. Preserve existing LTR screens by default.
4. Add source tokens and configurable dimensions: 236px sidebar, 64px topbar,
   module content padding 28×32, 38px filters, 40px primary controls, 12px
   cards, `#F4E7D3` 44px table headers and 16px dialogs.
5. Add focused Cubits/state boundaries and route scaffolding without duplicating
   the current Inventory feature.

## Phase 2 — correct reusable Module screens (B)

1. Rebuild Overview, Items, Details, Balances, Movements and Add Movement on
   the RTL foundation using the exact UI-map tables, filters, row heights,
   labels, pagination and confirmation dialog.
2. Extend the existing API only for source-required date, user and reference
   filters, preserving response conventions and tenant isolation.
3. Add an idempotency key to stock-changing manual movement requests and
   present the server result after confirmation.
4. Verify loading, empty, validation, forbidden and API-error states at
   1440×900.

## Phase 3 — refactor Counts and Units (C)

1. Refactor Stock Counts into a list with source filters/KPIs and an editable
   workspace: line lookup, variance/reason, draft save, submit, approve/post
   and irreversible confirmation.
2. Extend count services/queries safely, preserving posted immutability and
   one-time variance posting.
3. Model controlled base, purchase and consumption units; normalize every
   operation to base units. Rebuild the source table/dialog including defaults
   and calculated LTR formula.

## Phase 4 — transfers (D)

1. Add migrations, requests, services, controllers, APIs, seed data and tests
   for transfer/line lifecycle: draft → submitted/sent → in_transit → received.
2. Lock source/destination balances in a deterministic order; prevent negative
   source stock; support partial receipt and shortage reasons; emit immutable
   linked movements with operation idempotency.
3. Implement the source-matched Arabic RTL transfer list/workspace, sticky
   action bar and receipt-confirmation dialog.

## Phase 5 — recipes and sales consumption (D)

1. Extend recipes/lines for controlled consumption units, yields and fractional
   output; provide recipe/product-settings/readiness APIs.
2. Build Arabic RTL Recipes & Product Costing and Recipe Builder exactly to the
   source tables, cost panel, version warning and actions.
3. Integrate one idempotent inventory-consumption service into successful
   payment only. Resolve a branch operational warehouse; do not consume for
   draft, unpaid, cancelled or non-stock products.

## Phase 6 — suppliers, purchasing, reorder and barcode (D)

1. Add suppliers and supplier-item mappings, then source-shaped supplier list
   and selected-supplier panel.
2. Add PO/line/receipt models, partial receipt service and weighted-average
   updates. Implement PO list and receiving workspace with financial summary.
3. Add reorder rules/suggestions, preferred supplier and suggestion actions.
4. Add barcode mappings/lookup/scan activity and the source scan-mode UI.

## Phase 7 — verification and hand-off

1. Create comprehensive tenant-safe demo data through services: central,
   branch and bar warehouses; normal/low/out stock; conversions; counts;
   transfers; recipes; suppliers; POs/partial receipts; reorders; barcodes.
2. Add backend and Flutter tests mandated by the task, then source-sized
   goldens for key screens.
3. Run fresh migrations/seeding, backend tests/formatters/static analysis,
   `flutter analyze` and `flutter test`; fix introduced failures.
4. Reconcile every UI-map row and final-audit requirement; mark all gaps
   resolved or explicitly documented in the gap analysis.
