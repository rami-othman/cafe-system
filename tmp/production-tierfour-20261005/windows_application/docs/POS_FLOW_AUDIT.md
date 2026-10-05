# POS and Orders Flow Audit

Audit date: 2026-07-12  
Scope: Flutter Windows POS/Orders UI, Cubits, repositories, Dio contract, Laravel API/domain code, migrations, and automated checks. This was an analysis-only audit; no production, migration, seeder, or API-contract code was changed.

> Historical document: this 2026-07-12 audit predates Batch 12. Its Catalog
> startup/product-detail topology is superseded. Current production POS uses
> `/pos/menu-sync` Published Runtime Contract v1 only; the Catalog endpoints
> cited below are deprecated compatibility APIs and not production POS calls.

## A. Executive Summary

The catalog, a basic backend order lifecycle, backend totals, backend receipt retrieval, and the Orders list/detail read paths are connected and have a passing smoke test. The implementation is **development-only, not production-ready**. The highest risks are duplicate financial operations, incorrect refund limits, an authoritative cart that deliberately stores duplicate configured items, and order context/refund actions that appear in the UI but do not persist as the user would expect.

What is working:

- Catalog startup loads branches, the current shift, categories, products, customers, tables, and POS state through Dio.
- Product detail loads dynamic modifier groups; Laravel prices selected product options and recalculates order totals.
- Creating an order, adding/updating/removing an item, applying/removing a discount, holding/cancelling, paying, and fetching a receipt have routes and backend implementations.
- Orders list and order-detail DTO mapping work for the existing response shapes.
- The Laravel smoke test completes a basic create/discount/pay/receipt/refund path on its disposable SQLite test database.

What is incomplete or unsafe:

- The production/backend POS path does not merge equal configurations; it inserts a new `order_items` row for every add request.
- `POST /orders/{order}/pay` has neither an idempotency key nor a paid/status guard. A retry or double submit can insert multiple completed payments.
- Refund eligibility is based on the last payment amount (including cash change) and is not concurrency-safe. It can exceed the order total or be over-refunded concurrently.
- Cafe System 618 does not use table management in the current phase. Flutter sends `tableId: null` for all new orders and clears table context on order-type updates.
- The refund dialog only changes Flutter memory; it never calls the implemented refund endpoint.
- The Orders list API intentionally serializes no items, so every backend-backed card reports zero items.

### Verification classification

- **Runtime verified:** `dart format`, `flutter analyze`, all Flutter tests, Laravel feature tests, and Laravel route listing (details in Testing Audit).
- **Code-proven:** all findings in the table, including duplicate-line root cause. They were traced through the live request/response and persistence code.
- **Not runtime verified:** a Windows UI session against the Docker API and the requested manual 20-step POS walkthrough. No application was launched and no persistent development database was mutated for this analysis.

## B. End-to-End Flow Map

```text
App router ShellRoute
  -> PosCubit.loadInitialData / OrdersCubit.loadOrders
  -> PosRepository or OrdersRepository
  -> DioApiClient (base /api/v1, unwraps { data })
  -> Laravel route/controller
  -> query-builder persistence + PosPricingService
  -> PostgreSQL tables (orders, order_items, order_item_modifiers, payments,
     order_discounts, payment_refunds)
  -> camelCase JSON data payload
  -> repository DTO mapping
  -> immutable Cubit state
  -> POS cart / Orders cards / details panel
```

### POS startup

`AppRouter` creates the POS Cubit at the shell level. `loadInitialData()` sequentially calls `GET /branches`, `GET /shifts/current`, `GET /menu/categories`, `GET /menu/products`, `GET /customers`, `GET /tables`, and `GET /pos/state`. It selects the first branch/category and records the current shift ID. The POS-state response is discarded. If no shift is open, the app loads but adding the first backend item stops with an error; there is no open-shift recovery UI.

### Catalog and customization

The product grid filters locally by mapped category name and text search. A product tap calls `GET /menu/products/{id}`. The dialog turns selected dynamic options into `SelectedModifier(groupId, optionId)` and passes a `ProductCustomization` to the Cubit. Laravel validates product availability, validates selected options against assigned modifier groups, calculates the modifier price delta, then persists a snapshot of option names and prices.

### Cart and payment

For a first item, `PosCubit` posts `POST /orders` with one item; later adds post `POST /orders/{id}/items`. Each response replaces the entire cart from `order.items`. Quantity/remove use backend item IDs. Discounts are applied server-side, then the repository fetches the full order. Pay posts `/pay`, then retrieves `/receipt` before the Cubit clears local current-order state.

### Orders and refund

Orders calls `GET /orders` with a branch/filter query, then `GET /orders/{id}` for the panel. The UI offers local placeholder pay/resume/cancel/complete actions. Refund opens a local dialog and calls `OrdersCubit.confirmRefund`; it does not invoke `POST /orders/{id}/refunds`, despite that route existing.

## C. Findings Table

| ID | Severity | Area | Problem | Reproduction | Expected | Actual | Root Cause | Files/Endpoints | Recommended Fix |
| -- | -------- | ---- | ------- | ------------ | -------- | ------ | ---------- | --------------- | --------------- |
| P0-01 | P0 | Payment | Duplicate payment is possible. | Submit pay twice, retry after a timeout, or have the client retry after a response loss. | One completed payment per payable balance. | Each call inserts a completed `payments` row and marks the order paid. | No idempotency key, row lock, payment-status check, or remaining-balance calculation. | `PaymentController::pay`; `POST /orders/{id}/pay` | Make Laravel authoritative: lock order/payment rows, reject/return prior result for paid orders, and accept a client idempotency key. Disable Flutter confirmation while submitting. |
| P0-02 | P0 | Checkout recovery | A payment can succeed but receipt retrieval can fail, leaving the paid order active and retryable. | Cause `GET /receipt` to fail after successful `/pay`, then pay again. | Payment success should be committed locally even if receipt is delayed. | Cubit catches both calls together and preserves `currentOrderId`/cart on receipt failure. | Pay and receipt are one `try` block; backend also permits a second payment. | `pos_cubit.dart`; `/pay`, `/receipt` | Persist/emit paid completion immediately after pay; treat receipt as independently retryable. Depends on P0-01. |
| P0-03 | P0 | Refund | Refund limit can include cash change and concurrent refunds can exceed the refundable order amount. | Pay 20 for a 15 total, then request a 20 refund; issue two partial refunds concurrently. | Refundable amount is paid order value less completed refunds, atomically. | Backend uses latest payment `amount` (20), not order total/net settled amount, with no lock. | Incorrect source amount and read-then-insert race. | `RefundController::store`; `POST /orders/{id}/refunds` | Lock the order/payment/refund rows in one transaction; calculate a canonical refundable balance and store cash tender/change separately. |
| P1-01 | P1 | Cart correctness | Exact backend customizations create separate lines. | Add identical Americano options/note twice. | One line with summed quantity. | Two rows with distinct backend item IDs. | Flutter skips local merge in backend mode; Laravel `persistItem` always inserts; response remapping uses order-item ID as `CartItem.id`. | `pos_cubit.dart`, `cart_item.dart`, `PosOrderController::addItem/persistItem` | Implement canonical merge in Laravel transaction, then return merged item; Flutter should use the same key for optimistic/coalescing defense. |
| P1-02 | P1 | Order context | Customer/type changes after first item are not saved; table selection is not part of the current product phase. | Create an order, change type/customer, inspect `GET /orders/{id}`. | `PATCH /orders/{id}` persists customer/type and no table is assigned. | Cubit only emits local type/customer. UI displays hard-coded `12`; create sends first table for every order. | Existing update endpoint is never called and state has no selected table. | `pos_cubit.dart`, `pos_cart_panel.dart`; `PATCH /orders/{id}` | Flutter fix implemented: selected customer and order type are persisted through `PATCH /orders/{id}`. Table selection is intentionally removed; first-order creation uses `tableId: null` for every order type. Backend tenant validation and state-transition guards remain unresolved. |
| P1-03 | P1 | Refund UI | Refund confirmation is local-only. | Refund a backend order then refresh page/API. | Refund is persisted, details and list refresh from server. | Snackbar says `Refund recorded locally`; backend remains unchanged. | UI calls `confirmRefund`, not repository/API. | `orders_screen.dart`, `orders_cubit.dart`; `/orders/{id}/refunds` | Add repository/cubit API method, submission state, response/detail refresh, and error rollback. Depends on P0-03. |
| P1-04 | P1 | Order state | Paid/cancelled/held orders have no transition guards for cart mutations, hold, or cancel. | Pay an order then call item update, hold, or cancel endpoint. | Invalid state transitions are rejected. | Controllers find any non-deleted order and mutate it. | No status policy/domain service checks. | `PosOrderController`; item/hold/cancel routes | Centralize allowed order transitions and enforce them in Laravel before mutation. |
| P1-05 | P1 | Orders list | Backend cards always show zero items and no preview. | Open backend Orders list for a non-empty order. | Accurate item count and preview. | Index calls `serializeOrder(..., false)`, emits `items: []`; mapper uses `items.length`. | Summary response lacks item count/preview but Flutter infers them from empty items. | `PosOrderController::index/serializeOrder`; `OrdersRepository::_summaryFromJson` | Include `itemCount` and a bounded item preview in list response, map those explicit fields. |
| P1-06 | P1 | Discounts | Reapplying/replacing a discount burns usage count repeatedly; removal does not reverse it. | Apply the same code twice or replace it, inspect `discounts.used_count`. | Usage counted once per finalized order/application policy. | Each apply increments after deleting old row. | No idempotency or lifecycle accounting. | `DiscountController::apply/remove` | Define usage event semantics; make apply idempotent and reverse/reserve usage safely according to policy. |
| P1-07 | P1 | Lifecycle | Shell-level factories can recreate Cubits and rerun startup/list calls during router rebuilds, losing in-memory cart/order state. | Navigate between shell routes while a draft order is open. | One scoped POS session survives shell navigation. | `ShellRoute.builder` constructs `MultiBlocProvider` with factory Cubits and cascaded loads. | Lifetime is coupled to shell builder rebuild rather than a stable app/session scope. | `app_router.dart`, service locator | Verify with an integration test; scope providers outside rebuilds or preserve draft via an explicit session strategy. |
| P1-08 | P1 | Shift startup | No open shift blocks the first order with no recovery path. | Start POS when `/shifts/current` returns null, then add an item. | User can open/select a shift or sees an actionable blocking state. | Product add emits an error only. | Startup stores nullable shift and UI provides no shift workflow. | `pos_cubit.dart`; `/shifts/current` | Add an explicit shift-required state and route/action. |
| P2-01 | P2 | Customization | Product-detail loading failure opens the fallback, local fake modifier dialog in backend mode. | Disconnect API while opening a product with required modifiers, then add. | Do not submit an unknown configuration; show/retry error. | Dialog opens with fallback selections and posts no backend options. | `loadProductDetail` returns null for both no-modifier products and errors. | `pos_screen.dart`, `pos_cubit.dart`, customization dialog | Flutter fix implemented: backend detail success, no-modifier success, and API failure are now modeled separately. Backend mode no longer falls back to fake modifier data. |
| P2-02 | P2 | Race handling | Add-item/create/quantity operations are not serialized or guarded at method entry. | Fast double-click Add to Order before first create returns; rapidly tap quantity controls. | One ordered backend mutation sequence and predictable cart. | Calls can concurrently observe null/current stale IDs; responses replace whole cart in arrival order. | `isSyncingOrder` is emitted but add dialog/product grid are not disabled and Cubit has no mutex/versioning. | `pos_cubit.dart`, `pos_screen.dart`, dialog footer | Add a command queue or per-order mutation lock plus UI disabling and response generation checks. |
| P2-03 | P2 | Modifiers | Backend selected modifier request ordering is unstable and the local key cannot represent backend options. | Select multi-options in different tap orders. | Same option IDs produce one deterministic identity. | Map/Set iteration order is sent; backend mode never uses canonical key. | `_selectedModifiers()` does not sort and `configurationKey` uses legacy display/local values. | customization dialog, `product_customization.dart` | Build a sorted `(groupId, optionId)` key shared by local UI and server merge logic. |
| P2-04 | P2 | Receipt/payment UX | Payment summary result is discarded and dialog has hard-coded order number; receipt omits customer, discount label, and cash change fields. | Pay cash/customer/discount order, inspect dialog and receipt. | Backend-derived payment/order/receipt fields. | Dialog uses `Order #618-42`; receipt endpoint/map lacks several requested fields. | DTO/UI contract is incomplete; no persisted tender/change field. | `pos_cart_panel.dart`, `payment_dialog.dart`, `ReceiptController` | Pass backend payment summary/order number into dialog and expand receipt contract after P0 payment model is corrected. |
| P2-05 | P2 | Orders state | Filter/detail requests can race and stale details remain after a filter changes. | Open detail then switch filter quickly; issue overlapping filter taps. | Current filter controls selected panel and only latest response applies. | Detail stays selected; last response wins without request token. | No cancellation/request version and `selectFilter` does not clear selected detail. | `orders_cubit.dart`, `orders_screen.dart` | Clear panel on filter change and use request IDs/cancellation for list/detail loads. |
| P2-06 | P2 | API errors | Orders replaces real server errors with a generic connectivity message; discount/payment dialog bypasses Cubit API error state. | Trigger 422/404/server error. | Actionable server validation/error message. | Generic or raw `error.toString()` snackbars. | Inconsistent `ApiException` handling. | orders/pos widgets and Cubits | Normalize repository/Cubit error mapping and provide retry actions. |
| P2-07 | P2 | Data isolation | Validation `exists` rules do not constrain branch/table/customer/shift to tenant. | Supply another tenant's valid IDs to create/update. | Tenant-bound IDs only. | Global existence can pass; query builder writes them under current tenant order. | Validation rules only check table/id, not tenant. | `PosOrderController::store/update`; related controllers | Use tenant-aware validation/queries and enforce branch ownership. |
| P3-01 | P3 | Performance/maintainability | Order serialization performs per-order/customer/table/item/modifier/payment/refund queries; list is capped at 100 with no pagination. | Load a busy Orders screen. | Bounded query count and explicit pagination. | N+1 queries and silent truncation. | Query-builder serializer makes nested calls per row. | `PosOrderController::index/serializeOrder` | Add summary-specific joins/aggregates and cursor/page metadata. |
| P3-02 | P3 | Documentation | Architecture/integration documents contradict the backend-connected implementation and current limitations. | Read `ARCHITECTURE.md` and `BACKEND_INTEGRATION.md` against code. | Documentation tracks real implementation. | Some sections still call POS/Orders repositories fake. | Documentation was not updated consistently. | `docs/ARCHITECTURE.md`, `docs/BACKEND_INTEGRATION.md` | Reconcile after the correctness fixes; retain this audit as the factual baseline. |

Finding count: **3 P0, 8 P1, 7 P2, 2 P3**.

## D. Duplicate Cart-Line Bug Deep Dive

### Exact reproduction

1. Add Americano configured with Hot, Medium, Whole Milk and no differing note.
2. Add the same product and same backend modifier option IDs again.
3. First add calls `POST /orders`; second calls `POST /orders/{orderId}/items`.
4. Laravel executes `persistItem()` for each request and inserts a new `order_items` record.
5. Flutter maps the response items with `CartItem.id = backend order item id`, so the two database rows render as two cart rows.

### Actual root cause and responsibility

This is **B + D + E** from the requested classifications:

- **B:** Flutter's whole-cart replacement faithfully restores the two backend rows.
- **D:** Laravel intentionally/unconditionally creates one row for each add request (`persistItem` has no matching query).
- **E:** Flutter uses `BackendOrderItem.id` as the rendered cart identity after synchronization.

Flutter's fake/offline branch does merge using `ProductCustomization.configurationKey`, but that code is bypassed for backend products. The existing key is not suitable for backend authority because it uses local labels/legacy controls rather than the selected backend IDs.

**Implementation note (Flutter defensive mitigation, 2026-07-12):** the app now derives an ID-based canonical key, detects an existing exact backend cart configuration, and PATCHes its quantity instead of POSTing another order item. Cart mutations are serialized so later queued actions read the last confirmed backend response. Laravel must still implement authoritative transaction-safe canonical merging for retries, concurrency, and other clients.

### Canonical cart-line identity

Use an explicit, versioned canonical key derived only from meaningful configuration:

```text
productId
| sorted unique "groupId:optionId" pairs
| normalizedNote
```

Rules:

- Sort numerically by `groupId`, then `optionId`; reject duplicate option IDs/pairs.
- Use backend IDs, never display labels, current prices, order-item IDs, or quantity.
- Normalize note as `trim`; recommended comparison is **case-sensitive after trimming** so user-entered wording is not silently changed. If business policy chooses case-insensitive notes, apply Unicode case-folding in both layers and document it.
- Temperature, size, milk, sweetness, and add-ons participate when represented by modifier option IDs. A product-specific non-modifier field must be added explicitly to the server key.
- Quantity is deliberately excluded.

### Recommended authoritative location

Implement merging **authoritatively in Laravel**, within the same transaction as item pricing/persistence. Laravel owns orders/totals, serves future tablets/other clients, and is the only layer that can prevent duplicate rows caused by retries or concurrent clients. Flutter should also calculate the same key only for optimistic display/command coalescing; it must accept the backend response as authoritative and retain `backendItemId` for update/remove operations.

Recommended server algorithm:

1. Validate/normalize modifiers and note, and price the item.
2. Lock active `order_items` for the order (or otherwise serialize mutation for the order).
3. Compare product ID, normalized note, and canonicalized persisted modifier pairs.
4. If matched, increase quantity, recompute line total, and retain its item ID; otherwise insert row/modifier snapshots.
5. Recalculate order totals and return the full order.

### Tests required

- Laravel feature test: exact same product/options/note twice produces one row and total quantity.
- Laravel feature test: each different option, group, note, and note whitespace/case policy produces/separates rows as specified.
- Laravel concurrent/retry test: two same add requests cannot create duplicate matching rows.
- Flutter unit test: backend response maps canonical configuration and retains one backend item ID.
- Flutter integration test: rapid same-dialog Add cannot produce multiple create orders/lines.

## E. API Contract Audit

All responses are wrapped as `{ "data": ... }`; `DioApiClient` unwraps this before DTO mapping. Flutter and Laravel currently use camelCase JSON. Numeric helpers accept string/int/double in the mapped fields inspected.

| Endpoint used | Request | Response / Flutter mapping | Audit result |
| --- | --- | --- | --- |
| `GET /branches` | none | `Branch.fromJson` | Mapped; first active branch is selected without user choice. |
| `GET /shifts/current?branchId` | branch ID | `Shift?` | Mapped, but null shift has no UI recovery. |
| `GET /menu/categories?branchId` | branch ID | names plus repository ID/name cache | Mapping is correct; backend does not use `branchId`. |
| `GET /menu/products?branchId&availability=all` | availability/category optional | `basePrice` -> `PosProduct.price`, `categoryId/categoryName` | Correct `basePrice` mapping; product images are returned but ignored in Flutter. |
| `GET /menu/products/{id}?branchId` | product ID | modifier groups/options -> `BackendProductDetail` | IDs and camelCase align. Failure is ambiguous with no-detail product. |
| `GET /customers`, `GET /tables?branchId`, `GET /pos/state?branchId` | startup queries | Customer/Table DTO; POS state discarded | Customer/table map; POS state is unused; table selection missing. |
| `POST /orders` | `branchId`, `shiftId`, `orderType`, `tableId`, `customerId`, `items[]` | `BackendOrder` / cart replacement | Shape aligns; hard-coded/first table and no merge. |
| `POST /orders/{id}/items` | `productId`, quantity, `{groupId,optionId}[]`, note | full `BackendOrder` | Shape aligns; always inserts new row. |
| `PATCH/DELETE /orders/{id}/items/{item}` | quantity/modifiers/note | full `BackendOrder` | Backend item IDs map correctly; status guards absent. |
| `PATCH /orders/{id}` | type/table/customer/note | full order | Contract exists but Flutter never uses it. |
| `POST /hold`, `DELETE /orders/{id}` | none | full order / 204 | Cubit clears only after success; backend allows invalid state transitions. |
| `GET /discounts/available`, `POST /discounts/apply`, `DELETE /discounts` | order ID/code/discountId | discounts then full-order refresh | Mapping aligns. Flutter intentionally blocks BOGO although backend implements a simplistic BOGO calculation. |
| `GET /payment-summary`, `POST /pay` | amount received; method/amount/reference | `PaymentSummary`, `PaymentResult` | Summary is fetched then discarded. Pay contract lacks idempotency and stores tender as payment amount. |
| `GET /receipt` | order ID | receipt DTO | Basic fields map; customer/discount label/change are absent from endpoint contract. |
| `GET /orders`, `GET /orders/{id}` | branch/status/orderType filters | `OrderSummary`, `OrderDetail` | ID vs orderNumber mapping is correct; list items are always empty by backend design. |
| `POST /orders/{id}/refunds` | type/amount/reason/managerNotes | refund record | Backend route is not used by Flutter and has P0 refund-limit defects. |

Additional contract observations:

- There are two discount endpoint families (`/discount` and `/discounts`); Flutter uses only the newer plural endpoints. The legacy singular routes should be explicitly deprecated after compatibility review.
- `order.id` is the stable backend primary key; `orderNumber` is display only. `order_item.id` is correct for PATCH/DELETE but must not be treated as configuration identity.
- Laravel returns nullable `customer`, `table`, `payment`, and refund fields; Flutter's defensive mapping generally copes, but receipt's omitted customer/change fields cannot be rendered accurately.

## F. State and Race-Condition Risks

- No Cubit method checks `isClosed` after awaits. A provider disposal/routing rebuild can lead to emits after close.
- POS mutation responses replace the whole cart. Concurrent requests have last-response-wins behavior and can temporarily or permanently display stale data.
- Product Add stays reachable while `isSyncingOrder`; the customization footer has no submission state. Payment/refund dialogs similarly lack in-flight protection.
- Backend payment and refund mutations lack idempotency and locks; this is a financial correctness defect, not merely a UI issue.
- Orders list/detail loading has no cancellation or request generation token. Details remain open across filter changes.
- The receipt listener is guarded by `lastReceipt` state equality, but an explicit dialog-in-flight flag would make duplicate-dialog prevention robust across route/state changes.

## G. Responsive and UX Audit

Code review found useful desktop adaptations: shell sidebar collapse at medium widths, inline cart hidden at compact widths, scrollable product/cart/dialog bodies, wrapping Orders cards, and constrained details/refund panels. Existing widget tests cover several compact dialogs and shell breakpoints.

Risks remaining:

- Compact POS hides the inline cart; correctness of the top-bar cart affordance and overlay workflow was not runtime verified.
- The hard-coded table control is misleading and not keyboard/actionable selection.
- Dialogs use local controllers with proper disposal, but customization Add has no busy state and backend-detail failure can expose incorrect fallback controls.
- Orders filter header reserves 530px above its stack breakpoint, which needs a real minimum-height/medium-width test; the detail panel needs a runtime narrow-window check.
- Product images are not mapped into card UI; placeholders/icons are used. Unavailable products are ignored on tap, but no explicit unavailable explanation was verified.

## H. Test Coverage Gaps

Existing Flutter tests largely exercise fake repositories/local dialogs. The Laravel suite contains one broad smoke test and no focused financial/idempotency tests. Add coverage for:

- exact backend configuration merge, changed options/note separation, option ordering, and backend item-ID quantity mutation;
- duplicate add/create and payment/retry concurrency;
- payment status transition/idempotency and receipt-fetch failure after payment;
- refund amount capped to net order settlement, existing partial refunds, and concurrent refunds;
- persisted customer/order type/table changes;
- discount usage lifecycle and BOGO policy;
- backend list item count/preview and Orders refresh/detail stale state;
- API validation error display and no-shift recovery;
- real Windows integration at large/medium/compact widths.

## I. Prioritized Fix Plan

### Fix Batch 1 — P0/P1 order correctness

Goal: make financial/order mutations single, valid, and recoverable.

- Laravel: `PaymentController`, `RefundController`, `PosOrderController`, a dedicated order-state/payment service, and migrations only if idempotency/tender data require schema support.
- Endpoints: `/pay`, `/refunds`, item mutations, hold/cancel.
- Tests: payment retry/idempotency, receipt-after-pay recovery, refund balance/concurrency, allowed-transition matrix.
- Dependencies: none. This batch must precede UI wiring for refund and polish.

### Fix Batch 2 — Cart and customization correctness

Goal: implement canonical configuration identity and server-authoritative merging.

- Flutter: `ProductCustomization`, dialog selection ordering, `CartItem`, `PosCubit` mutation queue/UI busy state.
- Laravel: `PosOrderController`, pricing/normalization helper, order-item modifier persistence.
- Endpoints: create/add/update item.
- Tests: exact/different configuration, note normalization, modifier ordering, rapid adds.
- Dependencies: Batch 1's mutation locking/state policy.

### Fix Batch 3 — Discounts/payment/receipt

Goal: display and persist server-authoritative checkout information.

- Flutter: payment dialog/panel, receipt mapper/UI, POS error states.
- Laravel: discount usage policy, payment/receipt payload fields.
- Endpoints: available/apply/remove discount, payment summary/pay, receipt.
- Tests: discount replacement/removal and total refresh; cash tender/change; receipt completeness/one-dialog behavior.
- Dependencies: Batch 1 payment model and Batch 2 correct cart totals.

### Fix Batch 4 — Orders/details/refund

Goal: make Orders management a real backend workflow rather than a local simulation.

- Flutter: Orders repository/Cubit/screen/refund dialog; refresh and selected-detail handling.
- Laravel: order list summary serializer and tenant-scoped validation; resume/pay/cancel/complete contracts only if product requirements authorize them.
- Endpoints: `/orders`, `/orders/{id}`, `/refunds`, existing PATCH/hold/cancel routes.
- Tests: list item counts, filters, stale loads, persisted refund and over-refund prevention.
- Dependencies: Batch 1 refund/state safety.

### Fix Batch 5 — UX/responsiveness/polish

Goal: remove misleading UI, improve compact workflows, and reconcile documentation.

- Flutter: actual table selector, unavailable/product image states, responsive details/cart tests, feedback/retry states.
- Docs: architecture and backend-integration documentation.
- Tests: Windows integration/visual regression at supported width/height bands.
- Dependencies: Batches 1–4 so UI reflects settled behavior.

## J. Recommended First Fix

Start with **Fix Batch 1**, beginning with payment idempotency and refund balance enforcement in Laravel. These faults can create duplicate or excessive financial records and cannot be safely mitigated by Flutter alone. Once server mutations are safe, implement canonical server-side cart-line merging in Batch 2.

## Flutter Payment Mitigation (2026-07-12)

Flutter mitigation implemented:

- duplicate payment clicks are blocked;
- payment success clears the active POS order before receipt retrieval;
- failed receipt retrieval is independently retryable;
- uncertain payment responses are verified through order status and are never automatically resubmitted.

Remaining backend requirement:

Laravel must implement authoritative payment idempotency, payable-state guards, and transaction-safe payment handling.

## Testing Audit

Successful commands:

```text
windows_application: dart format --output=none --set-exit-if-changed .
  Result: 205 files formatted, 0 changed.

windows_application: flutter analyze
  Result: No issues found.

windows_application: flutter test
  Result: 79 tests passed.

Docker backend: php artisan test
  Result: 3 tests passed, 30 assertions. PHPUnit uses SQLite :memory:.

Docker backend: php artisan route:list --path=api/v1
  Result: 29 API routes listed.
```

The initial sandboxed Docker inspection could not read the local Docker config; the same requested Laravel checks subsequently ran inside the existing backend container with approved access. No destructive database command was run.
