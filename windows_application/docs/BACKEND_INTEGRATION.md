# Backend Integration

## Dio API Client

The Flutter POS flow uses `DioApiClient` in `lib/core/network`. The client wraps Dio with:

- Base URL: `http://127.0.0.1:8000/api/v1`
- Default headers: `Accept: application/json`, `Content-Type: application/json`, `X-Tenant-Id: 1`
- Connect, send, and receive timeouts
- Laravel `{ "data": ... }` response unwrapping
- Central `ApiException` mapping for offline backend, validation, auth, not found, server, and unknown Dio errors

`ApiConfig.baseUrl` can be overridden at build time with:

```bash
--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

## Startup Flow

`PosCubit.loadInitialData()` now loads backend data through `PosRepository`:

- `GET /branches`
- `GET /shifts/current?branchId=1`
- `GET /menu/categories?branchId=1`
- `GET /menu/products?branchId=1&availability=all`
- `GET /customers`
- `GET /tables?branchId=1`
- `GET /pos/state?branchId=1`

If the backend is unreachable, the POS state receives the clear API error message from `ApiException`.

## POS Order Flow

The current POS checkout flow is backend-backed through Dio:

- Product details and modifiers: `GET /menu/products/{productId}?branchId=1`
- Create order: `POST /orders`
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

## Backend Totals

After `currentOrderId` is set, `PosState` displays subtotal, discount, tax, and total from the backend order response. Local total calculation remains only for fake repository tests and pre-backend local fallback behavior.

Backend order item IDs are stored on `CartItem.backendItemId`, and quantity/remove actions use those IDs.

## Current Limitations

- Orders screen list, Order Details, and Refund flow still use fake/local data.
- Real print endpoint is not connected.
- Payment dialog still keeps its existing UI and local amount-entry behavior; backend payment summary is fetched when the dialog opens.
- Product customization renders backend modifier groups when available, but the visual design remains the existing modal.
- Widget tests register the fake POS repository so tests do not require a running Laravel server.

## Next Backend Step

Connect Orders screen, Order Details, and Refund flow to backend API.
