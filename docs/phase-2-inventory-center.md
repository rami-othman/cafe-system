# Phase 2 — Inventory Center

## Current state and limits

Phase 1 supplies tenant-scoped warehouses and audit logging. The legacy
`inventory_items.current_stock` and single signed `stock_movements.quantity`
columns are retained for compatibility with old seed data, but are not an
authoritative balance and must not be used for new stock decisions.

## Data model

`inventory_items` gains Arabic/English names, barcode, classification,
reorder level, latest cost, notes, actor fields and tenant-scoped optional
SKU/barcode uniqueness. `stock_balances` is the authoritative one-row balance
for tenant + warehouse + item. `stock_movements` becomes an immutable ledger
with explicit quantity-in/out, before/after quantities and occurred time.
`stock_counts` and `stock_count_lines` implement the controlled count flow.

## Balance and cost strategy

All writes run in a database transaction and lock the balance row. Available
quantity is `quantity_on_hand - reserved_quantity`; reservations are zero in
this phase. Incoming opening/stock-in/adjustment-in/return-in recompute
weighted average `(old quantity * old cost + incoming quantity * incoming
cost) / new quantity`. Outgoing, waste, adjustment-out and transfer-out use
the locked current average. Negative available stock is rejected. Transfers
can be expressed as paired source/destination movements while preserving the
source cost. Inventory journal posting is intentionally deferred.

## Lifecycle and validation

Posted movements are insert-only: no update or delete route exists; corrections
are new compensating movements. Adjustment, waste and count variance require a
reason. A count is draft/in-progress/submitted/approved/posted/cancelled,
targets one warehouse, and its lines are editable only before submission.
Posting locks the count, emits variance movements atomically and cannot run
twice. Tenant, item, warehouse and optional branch context are checked on every
write.

## API map

- `GET|POST /api/v1/inventory/items`; `GET|PATCH /inventory/items/{item}`;
  `PATCH /inventory/items/{item}/status`; item stock and movements subpaths.
- `GET /api/v1/inventory/balances`; `GET /api/v1/inventory/dashboard`.
- `GET|POST /api/v1/inventory/movements`; `GET /inventory/movements/{id}`.
- `GET|POST /api/v1/inventory/counts`; show, line upsert, start, submit,
  approve, post and cancel actions below `/inventory/counts/{count}`.

All list endpoints return `{ data, meta }` and accept bounded `perPage`.

## Flutter flows

The RTL Inventory section has dashboard, items, warehouse balances, movement
ledger and guided movement entry, and stock-count list/detail flows. They use
the existing Dio, GetIt, Cubit and GoRouter architecture; reporting export is
shown disabled until the reporting phase.

## Compatibility and migration

No legacy rows are removed. Migration maps old movement quantity to explicit
in/out and backfills a balance per old warehouse/item where possible. The new
demo seeder is idempotent and uses the ledger service, so it never relies on
`current_stock` for operational calculations.

## Tests

Feature coverage verifies tenant isolation, tenant mismatch rejection,
weighted-average intake/outflow, no negative stock, waste reason, immutable
ledger surface, count variance/post-once/approval, and dashboard low/out stock
totals, together with existing POS and Phase 1 suites.

## Deferred

Recipes and automatic POS consumption, purchase orders, suppliers, barcode
hardware, reservations, transfers UI, inventory financial journals, exports,
and reporting are deferred to Phase 3 and later.
