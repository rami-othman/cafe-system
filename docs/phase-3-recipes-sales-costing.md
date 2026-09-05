# Phase 3 — Recipes, Sales Consumption, and Costing

## Current lifecycle

Orders are draft/unpaid until `POST /api/v1/orders/{order}/pay` succeeds. The
current controller creates a completed payment and changes the order to `paid`
inside one transaction; this is the sole consumption trigger. Cart, held,
unpaid and cancelled orders never affect stock. Existing refunds are
amount-based: a full refund can reverse all consumed ingredients, while a
partial refund remains financial-only until item-level refund quantities exist.

## Model and versioning

Recipes belong to a tenant and product and have immutable versions. A line has
one tenant-scoped inventory item, required quantity per yield and optional
wastage. Product inventory settings indicate inventory control, bar/kitchen
consumption, and optional per-branch warehouse mappings. Sales snapshots retain
recipe version, ingredient cost, COGS and profit on order and order-item rows;
later recipes or costs never rewrite them.

## Consumption and reversal

At payment, a service locks the order and checks an idempotent consumption
record. It resolves explicit branch mapping, otherwise active branch bar or
kitchen warehouse (never central), validates every ingredient availability,
then posts per-ingredient `sale_consumption` movements through the inventory
ledger in the same database transaction. On a full completed refund it emits
one idempotent `return_in` movement per original consumption at its historical
unit cost. Partial amount-only refunds create no stock return.

## Costing

Each consumption uses the warehouse weighted average at the exact locked time.
Order-item COGS is the ingredient total; order COGS is their sum. Net sales is
the paid sale total minus completed refunds. Gross profit is net sales minus
COGS; discounts affect net sales only, never recipe quantities.

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
