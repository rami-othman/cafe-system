# Backend Integration

## Dio API Client

The Flutter POS flow uses `DioApiClient` in `lib/core/network`. The client wraps Dio with:

- Base URL: `http://localhost:8000/api/v1`
- Default headers: `Accept: application/json`, `Content-Type: application/json`, `X-Tenant-Id: 1`
- Connect, send, and receive timeouts
- Laravel `{ "data": ... }` response unwrapping
- Central `ApiException` mapping for offline backend, validation, auth, not found, server, and unknown Dio errors

`ApiConfig.baseUrl` can be overridden at build time with:

```bash
--dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## Startup Flow

`PosCubit.loadInitialData()` now loads backend data through `PosRepository`:

- `GET /branches`
- `GET /shifts/current?branchId=1`
- `GET /menu/categories?branchId=1`
- `GET /menu/products?branchId=1&availability=all`
- `GET /customers`
- `GET /pos/state?branchId=1`

If the backend is unreachable, the POS state receives the clear API error message from `ApiException`.

## POS Order Flow

The current POS checkout flow is backend-backed through Dio:

- Product details and modifiers: `GET /menu/products/{productId}?branchId=1`
- Create order: `POST /orders`
- Update order context: `PATCH /orders/{orderId}` for `orderType` and `customerId`; Flutter sends `tableId: null` when changing order type.
- Add item: `POST /orders/{orderId}/items`
- Update quantity: `PATCH /orders/{orderId}/items/{itemId}`
- Remove item: `DELETE /orders/{orderId}/items/{itemId}`
- Hold order: `POST /orders/{orderId}/hold`
- Cancel order: `DELETE /orders/{orderId}`
- Available discounts: `GET /discounts/available?orderId={orderId}`
- Apply discount: `POST /orders/{orderId}/discounts/apply`
- Remove discount: `DELETE /orders/{orderId}/discounts`
- Payment summary: `GET /orders/{orderId}/payment-summary?amountReceived={amount}`
- Pay: `POST /orders/{orderId}/pay`
- Receipt preview: `GET /orders/{orderId}/receipt`

The existing POS screens and dialogs are preserved. Backend model mapping stays in repository/model code rather than widgets.

Backend product-detail loading is explicit in Flutter: a successful detail response (including zero modifier groups) opens the backend customization flow, while a failed request shows Retry/Cancel and never falls back to local fake modifiers. Cafe System 618 does not use table management in the current phase, so all new orders send `tableId: null` and order-type updates explicitly clear any table context.

## Backend Totals

After `currentOrderId` is set, `PosState` displays subtotal, discount, tax, and total from the backend order response. Local total calculation remains only for fake repository tests and pre-backend local fallback behavior.

Backend order item IDs are stored on `CartItem.backendItemId`, and quantity/remove actions use those IDs.

## Orders Backend Integration

The Orders screen and Order Details side panel are backend-backed through the existing `DioApiClient`.

Connected endpoints:

- Order list: `GET /orders`
- Branch order list: `GET /orders?branchId=1`
- Held orders: `GET /orders?branchId=1&status=held`
- Dine-in orders: `GET /orders?branchId=1&orderType=dine_in`
- Takeaway orders: `GET /orders?branchId=1&orderType=takeaway`
- Order detail: `GET /orders/{id}`

Filter mapping:

- Active Orders calls `GET /orders?branchId=1` and keeps `draft`, `preparing`, and `ready` style orders in the UI.
- Held Orders calls `GET /orders?branchId=1&status=held`.
- Dine-in calls `GET /orders?branchId=1&orderType=dine_in`.
- Takeaway calls `GET /orders?branchId=1&orderType=takeaway`.

Status mapping:

- `draft` -> `PREPARING`
- `held` -> `HELD`
- `paid` -> `COMPLETED`
- `refunded` -> `REFUNDED`
- `partially_refunded` -> `PARTIAL REFUND`
- `cancelled` -> `CANCELLED`

Order list responses are treated as summaries. If `items` is empty on `GET /orders`, the card safely shows zero items and no line item preview. The side panel fetches `GET /orders/{id}` and maps full items, modifiers, notes, payments, refunds, timeline, and totals.

## Current Limitations

- PAY from Orders is not connected yet.
- RESUME held order is not connected to POS yet.
- CANCEL and COMPLETE backend mutations from Orders are not connected yet.
- Refund backend connection is pending; the current refund modal remains local.
- Real print endpoint is not connected.
- Payment dialog still keeps its existing UI and local amount-entry behavior; backend payment summary is fetched when the dialog opens.
- Product customization renders backend modifier groups when available, but the visual design remains the existing modal.
- Widget tests register the fake POS repository so tests do not require a running Laravel server.

## Next Backend Step

Connect Orders actions: resume held order, pay from orders, cancel/complete, and refund backend flow.
