# Phase 3 — Recipes, Sales Consumption, and Costing

## Current lifecycle

Orders are draft/unpaid until `POST /api/v1/orders/{order}/pay` succeeds. The
current controller creates a completed payment and changes the order to `paid`
inside one transaction; this is the sole consumption trigger. Cart, held,
unpaid and cancelled orders never affect stock. Refunds are amount-based
financial reversals only: neither full nor partial refunds return inventory
until an explicit item-aware return-to-stock operation exists.

## Model and versioning

Canonical Menu variant/modifier recipes belong to the published Menu snapshot.
The legacy `recipes`/`recipe_lines` tables and their yield/wastage fields remain
only for compatibility and do not participate in Menu publication, payment,
consumption, WAC, or COGS. Sales snapshots retain realized WAC COGS; manual
product/variant `cost_price` remains a non-authoritative reference estimate.

## Consumption and reversal

At payment, a service locks the order and checks an idempotent consumption
record. It resolves the branch's `BR-{branchId}-MAIN` warehouse, validates the
published Menu components, then posts per-ingredient `sale_consumption`
movements through the inventory ledger in the same database transaction.
Refunds do not create stock movements or alter historical consumption/COGS.

## Costing

Each consumption uses the warehouse weighted average at the exact locked time.
Order-item COGS is the ingredient total; order COGS is their sum. Tax is a
customer liability, not revenue: net revenue is subtotal minus discounts and
tax-exclusive refunds. Gross profit is net revenue minus realized COGS;
discounts affect revenue only, never recipe quantities.

## API and Flutter map

Recipe list/show/create/version/status/history/availability live under
`/api/v1/inventory/recipes`. Product inventory configuration and readiness are
under `/api/v1/inventory/product-settings` and `/inventory/readiness`.
Order costing is exposed by `/api/v1/orders/{order}/costing`. The RTL Flutter
Inventory subsection provides recipe list/builder/cost view/readiness and
read-only manager costing.

## Compatibility, tests, deferred work

Historical orders are untouched. New nullable snapshot fields are populated
only at payment after deployment. Tests cover isolation, validation,
idempotency, insufficient stock atomicity, recipe/cost immutability, full
refund reversal, discounts and readiness. Suppliers, purchasing, transfer UI,
asset flows, barcode hardware and final financial reports are deferred.
