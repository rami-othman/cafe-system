# POS Frontend API Handoff

## Base

```text
Base URL: http://localhost:8000/api/v1
Swagger:  http://localhost:8000/swagger.html
```

All JSON success responses use:

```json
{
  "data": {}
}
```

Validation errors use Laravel's default shape:

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "field": ["Error message"]
  }
}
```

## Current Auth Mode

Login is temporarily disabled for the POS flow. Call the POS endpoints directly.

```http
Accept: application/json
Content-Type: application/json
```

## POS Startup Flow

1. Load branches
   `GET /branches`

2. Load current shift
   `GET /shifts/current?branchId=1`

3. Open shift when needed
   `POST /shifts/current`

```json
{
  "branchId": 1,
  "openingCash": 0
}
```

4. Load POS catalog
   `GET /menu/categories?branchId=1`
   `GET /menu/products?branchId=1&categoryId=1&availability=all`

5. Load tables and customers
   `GET /tables?branchId=1`
   `GET /customers?search=walk`

6. Load POS operational state
   `GET /pos/state?branchId=1`

## Product Customization

Call product details before opening the customize modal:

```http
GET /menu/products/3?branchId=1
```

The response includes `modifierGroups`. Required groups must be submitted when adding an item.

Example selected modifiers:

```json
[
  { "groupId": 1, "optionId": 1 },
  { "groupId": 2, "optionId": 5 },
  { "groupId": 3, "optionId": 8 },
  { "groupId": 4, "optionId": 10 }
]
```

## Create Order

```http
POST /orders
```

```json
{
  "branchId": 1,
  "shiftId": 1,
  "orderType": "dine_in",
  "tableId": 1,
  "customerId": null,
  "items": [
    {
      "productId": 3,
      "quantity": 1,
      "modifiers": [
        { "groupId": 1, "optionId": 1 },
        { "groupId": 2, "optionId": 5 },
        { "groupId": 3, "optionId": 8 }
      ],
      "note": "Extra hot"
    }
  ]
}
```

## Cart Actions

Add item:

```http
POST /orders/{orderId}/items
```

Update item quantity or modifiers:

```http
PATCH /orders/{orderId}/items/{itemId}
```

Remove item:

```http
DELETE /orders/{orderId}/items/{itemId}
```

Hold order:

```http
POST /orders/{orderId}/hold
```

Cancel order:

```http
DELETE /orders/{orderId}
```

## Discount

List available discounts for the modal:

```http
GET /discounts/available?orderId=1
```

Apply by coupon code or selected discount:

```http
POST /orders/{orderId}/discounts/apply
```

```json
{
  "code": "OPEN10"
}
```

or:

```json
{
  "discountId": 2
}
```

The legacy manual discount endpoint is still available:

```http
PUT /orders/{orderId}/discount
```

```json
{
  "type": "percentage",
  "value": 10,
  "reason": "Manager discount"
}
```

Remove:

```http
DELETE /orders/{orderId}/discount
```

## Print

Receipt preview:

```http
GET /orders/{orderId}/receipt
```

```http
POST /orders/{orderId}/print
```

```json
{
  "type": "receipt"
}
```

Allowed types:

```text
receipt, kitchen_ticket
```

## Pay

Payment modal summary and change due:

```http
GET /orders/{orderId}/payment-summary?amountReceived=30
```

```http
POST /orders/{orderId}/pay
```

```json
{
  "method": "cash",
  "amount": 15.66,
  "reference": null
}
```

Allowed methods:

```text
cash, card, wallet, split
```

## Refund

```http
POST /orders/{orderId}/refunds
```

```json
{
  "type": "partial",
  "amount": 5,
  "reason": "Customer Request",
  "managerNotes": "Approved from POS refund flow."
}
```

Use `"type": "full"` to refund the remaining refundable balance.

## Order Details

```http
GET /orders/{orderId}
```

The response includes order items, customer, table, discount, totals, payments, refunds, and timeline for the details drawer.

## Important Frontend Notes

- Use `id` values from API responses. Do not hard-code product, group, option, table, or branch IDs.
- The backend calculates all prices, modifiers, discounts, tax, and totals. The frontend should display API totals, not calculate final totals independently.
- Products with required modifier groups cannot be added without valid modifier selections.
- `orderType` values are `dine_in`, `takeaway`, and `delivery`.
- Money is returned as numbers. Format currency in the frontend.
