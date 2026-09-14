# Sales / Sales-Invoice Forensic Audit

**Repository state audited:** `integration/inventory-finance`, commit `47594bc07ad8c7bb1abae3fc26d0c24725cdcb23`
**Audit mode:** source-only. This document records what the repository implements today; it does not claim that a proposed Sales Invoice module already exists. Final forward decisions are recorded in [SALES_ARCHITECTURE_DECISIONS.md](SALES_ARCHITECTURE_DECISIONS.md).

## Executive finding

The current system has a real, transaction-safe **POS cash-sale** pipeline, but it does not have a professional Sales Invoice, customer receivable (AR), customer receipt/allocation, credit-note, or invoice-reversal domain. `orders` is not a neutral sales document: it is structurally and behaviorally a POS order tied to a table, shift, cashier, menu snapshot, payment-at-once rule, receipt and POS refund lifecycle. The correct next architecture is therefore **a new Sales Invoice domain which uses one extracted, shared sales-posting coordinator with POS**. Reusing `orders` as manual invoices would import POS operational constraints and produce accounting/stock coupling risks.

## Scope and method

The audit inspected API routes, controllers, services, migrations, finance reports and the Flutter desktop application. File-and-line citations below are repository evidence, not external accounting guidance. “Missing” means no matching implementation was found in the audited application paths; it does not mean a business process is impossible outside the application.

## Current sales architecture

### Canonical POS flow: Order → payment → revenue/COGS → inventory → shift/daily closing

| Stage | Current behavior | Evidence |
|---|---|---|
| 1. Create order | `POST /orders` creates a draft POS order, validates only POS types (`dine_in`, `takeaway`, `delivery`), optionally links shift/table/customer, stores a POS order number, and prices its lines. | `backend/routes/api.php:308-325`; `backend/app/Http/Controllers/Api/PosOrderController.php:64-140` |
| 2. Mutate/hold/cancel | Only draft/held unpaid orders can change, be held or be cancelled; paid orders must go through refund rather than cancellation. | `backend/app/Services/OrderLifecyclePolicy.php:13-41`; `backend/app/Http/Controllers/Api/PosOrderController.php:197-207` |
| 3. Pay | `POST /orders/{order}/pay` accepts cash/card/wallet/split labels, but requires one amount at least equal to the total and explicitly rejects an existing completed payment. It requires the actor’s open shift. | `backend/app/Http/Controllers/Api/PaymentController.php:50-58`, `75-88`, `149-164` |
| 4. Persist settlement | The controller inserts one completed `payments` row for the full order total, marks order/payment status paid, and closes the order in the same DB transaction. | `backend/app/Http/Controllers/Api/PaymentController.php:63-118` |
| 5. Consume stock/cost | Immediately after settlement, `SaleConsumptionService` consumes recipe material, posts `sale_consumption` stock movements, captures WAC-derived cost, and snapshots COGS on line/order. Any stock/configuration failure rolls the whole payment back. | `backend/app/Http/Controllers/Api/PaymentController.php:106-112`; `backend/app/Services/SaleConsumptionService.php:15-36`, `48-165` |
| 6. Journal sale | With an active finance payment mapping, payment builds debit to the mapped cash/bank account; credits revenue and tax; debits discount/COGS and credits inventory as applicable. It posts source event `pos_order` / `POS_ORDER_PAID`. | `backend/app/Http/Controllers/Api/PaymentController.php:176-202`; `backend/app/Services/AccountingPostingService.php:49-123`, `133-140` |
| 7. Idempotency | Payment has a tenant idempotency key/hash; inventory movement keys are per order line/material; journal entries have a tenant/source/event unique guard. | `backend/app/Http/Controllers/Api/PaymentController.php:63-73`; `backend/app/Services/SaleConsumptionService.php:75-83`, `119-129`; `backend/app/Services/AccountingPostingService.php:61-75`; `backend/database/migrations/2026_08_29_000004_add_finance_core_safety_fields.php:39-42` |
| 8. Shift cash | Shift closing summarizes opening cash + resolved cash payments − resolved cash refunds. Non-cash settlements are excluded. | `backend/app/Services/ShiftCashSummaryService.php:8-22`, `29-64`; `backend/app/Http/Controllers/Api/ShiftController.php:78-122` |
| 9. Daily closing | Daily summary treats paid POS payments/refunds and orders as sales. Closing blocks for open shifts, cash differences, draft journals and certain inventory finance issues; a closed day retains a snapshot and flags late journals. | `backend/app/Services/DailyClosingSummaryService.php:23-30`, `43-89`; `backend/app/Services/DailyClosingReadinessService.php:15-33`; `backend/app/Services/DailyClosingService.php:15-31` |

### Accounting and inventory ownership

* `InventoryPostingService` is the stock/WAC authority: it locks the balance, calculates outgoing cost at the existing weighted average, persists the movement and calls the inventory-finance mapper inside its transaction. `backend/app/Domain/Inventory/InventoryPostingService.php:25-93`
* A `sale_consumption` movement deliberately creates **no separate journal**: the mapper labels it `ALREADY_HANDLED_BY_SOURCE` because the paid-order journal already debits COGS and credits inventory. This is the present anti-double-posting rule. `backend/app/Domain/Inventory/InventoryAccountingMapper.php:13-16`, `53-58`
* POS COGS is driven by the immutable published menu snapshot, not current recipes; stock-tracked products without a v3 sold snapshot, recipe, or warehouse fail payment rather than receive invented zero COGS. Non-stock/service lines explicitly receive valid zero COGS. `backend/app/Services/SaleConsumptionService.php:65-100`, `181-193`
* The accounting posting service is a generic, idempotent journal orchestrator. It creates a draft then posts it, enforcing source identity and tenant-specific account lookup. `backend/app/Services/AccountingPostingService.php:10-29`, `49-123`
* Standard setup contains Inventory Asset `1100`, Sales Tax Payable `2010`, Sales Revenue `4000`, Discounts `4010`, Sales Returns `4020`, and COGS `5000`. No default AR account is configured in that setup list. `backend/app/Services/FinancialSetupService.php:52-61`

### Refunds versus product returns

`POST /orders/{order}/refunds` can make full or partial payment refunds, locks the original completed payment, caps cumulative refunds, reverses revenue/tax against the original settlement account, and is idempotent. `backend/app/Http/Controllers/Api/RefundController.php:29-123`

It deliberately **does not restock inventory or reverse COGS**, because a payment refund does not identify returned items. That behavior is explicit in source and covered by the test that verifies stock stays unchanged. `backend/app/Http/Controllers/Api/RefundController.php:92-95`; `backend/tests/Feature/RefundAccountingApiTest.php:137-189`

This is correct for a pure payment refund but is not a credit-note/product-return model. A future itemized credit note needs a separate, controlled return/restock decision and must not call both the old refund path and a new COGS reversal path for the same business event.

## Current tables and their limits

| Table/domain | What exists | Sales-Invoice consequence |
|---|---|---|
| `orders`, `order_items` | Tenant/branch/shift/table/customer/cashier POS order with totals, POS types and statuses; order lines hold product, quantity, price and later COGS snapshots. | Usable as historical POS source only; unsuitable as the manual invoice primary record. `backend/database/migrations/2026_05_31_000010_create_orders_table.php:11-38`; `2026_05_31_000011_create_order_items_table.php:11-25`; `2026_08_18_000001_create_recipe_sales_costing_tables.php:31-32` |
| `payments`, `payment_refunds` | Payment belongs to one order; refund belongs to one order/payment/shift. | Cannot represent invoice payments, unapplied customer receipts, allocations, or invoice credit balances without invasive polymorphism. `backend/database/migrations/2026_05_31_000012_create_payments_table.php:11-30`; `2026_06_20_000003_create_pos_operation_tables.php:11-29` |
| `sale_consumptions` | Requires `order_id` and `order_item_id`; unique on order item; optionally links a payment. | Directly prevents manual invoice lines from reusing current consumption persistence. `backend/database/migrations/2026_08_18_000001_create_recipe_sales_costing_tables.php:27-32` |
| `stock_movements` | Generic movement supports reference type/id and idempotency. | Reusable inventory ledger surface once a sales-document-line reference contract is introduced. `backend/app/Domain/Inventory/InventoryPostingService.php:85-89` |
| `journal_entries` | Generic `source_type`, `source_id`, `source_event`; unique source event. | Reusable for invoice, receipt, credit note and reversal journals, with distinct source events. `backend/app/Services/AccountingPostingService.php:49-123`; `backend/database/migrations/2026_08_29_000004_add_finance_core_safety_fields.php:39-42` |
| `customers` | POS/loyalty contact: name, phone, email, birth date, notes, spend/visits/activity. API only lists/searches active customers. | Customer identity can be reused, but legal entity, billing/tax identity, credit terms/limit, AR balance, statement and payment history are missing. `backend/database/migrations/2026_05_31_000008_create_customers_table.php:11-27`; `backend/app/Http/Controllers/Api/CustomerController.php:11-48` |
| Supplier AP | Supplier invoices, payments and allocations plus query service derive AP balances and statements from posted invoices minus allocations. | Strong pattern to mirror for AR, but tables/controllers must not be repurposed. `backend/database/migrations/2026_09_02_000009_create_supplier_ap_tables.php:40-118`; `backend/app/Services/SupplierPayableQueryService.php:8-36` |

## Reports, closing, tenant and access findings

* Formal financial reports read posted journals rather than dashboard cache; P&L, balance sheet, GL and cash flow are already reusable reporting foundations. Cash flow currently classifies `pos_order` and `payment_refund`, so a new source type needs a classification update. `backend/app/Services/FinancialReportQueryService.php:12-13`, `95-104`, `132-136`
* Daily closing queries `orders`, `payments`, `payment_refunds` directly, so invoice issue/payment/credit events will be invisible until the summary contract is extended. `backend/app/Services/DailyClosingSummaryService.php:43-89`
* All operational sales endpoints are inside the authenticated tenant boundary but the POS routes shown have no named finance-sales permission middleware; finance routes use granular `finance.permission:*` capability middleware. `backend/routes/api.php:281-326`, `378-497`
* Branch authorization exists at order/payment/refund/shift operations, and the accounting/inventory writers carry tenant/branch context. `backend/app/Http/Controllers/Api/PaymentController.php:123-164`; `backend/app/Http/Controllers/Api/RefundController.php:40-62`; `backend/app/Domain/Inventory/InventoryPostingService.php:39-45`

## Flutter forensic finding

The client is organized around POS orders, an order history/refund screen, and a finance workspace. There is no Sales Invoice route, model, repository, cubit or finance tab.

* POS repository calls `orders`, `orders/{id}/pay`, customer lookup, shift lookup and POS state/menu APIs. `windows_application/lib/features/pos/repositories/pos_repository.dart:47-60`, `113-128`, `155-303`
* The Orders feature maps the backend `orders` history/payment/refund payload, not general invoices. `windows_application/lib/features/orders/repositories/orders_repository.dart:118-260`
* Main navigation exposes separate POS, Orders and Finance entries. `windows_application/lib/shared/widgets/app_sidebar.dart:24-43`
* The Finance module has tabs for vouchers, cash/banks, expenses, purchases, suppliers, reconciliation, journals, closing, reports and accounts—but no Sales/AR tab. `windows_application/lib/features/finance_inventory_setup/widgets/finance_navigation_bar.dart:8-78`
* Router/service locator already establish the conventional integration points for a new feature. `windows_application/lib/app/app_router.dart:13-60`, `1059-1259`; `windows_application/lib/core/services/service_locator.dart:257-265`

## Reusable versus missing capabilities

### Reuse without changing business ownership

1. Tenant context, branch access, `FinancialActor`, operational audit, transaction/idempotency patterns.
2. Product, variant, menu snapshot and recipe-costing logic for inventory-tracked sales.
3. `InventoryPostingService` as only stock/WAC writer.
4. `AccountingPostingService` + `JournalEntryService` as only automatic journal writer.
5. Finance accounts, payment methods/financial locations, reports, reconciliation and daily-closing shell.
6. Supplier AP’s posted document + receipt/allocation + balance/statement reporting pattern, copied conceptually into a customer-owned AR implementation.

### Missing or must be changed

1. Sales invoice header/line persistence, immutable issue snapshot, number sequence and lifecycle.
2. Customer business profile and credit policy.
3. AR account setup, customer receipt, allocation, credit balance, aging and statement.
4. Invoice-level and line-level idempotency, approval/post/reversal and period-lock behavior.
5. A shared sale posting coordinator. Today `PaymentController` owns the POS accounting line construction while `SaleConsumptionService` accepts only an order. `backend/app/Http/Controllers/Api/PaymentController.php:176-202`; `backend/app/Services/SaleConsumptionService.php:48-54`
6. Generalized sale-consumption linkage and traceable product-return/credit-note restock policy.
7. Sales/AR permissions, API routes, Flutter screens and report/closing integrations.

## Risks if implemented naively

| Risk | Why it exists now | Required control |
|---|---|---|
| Duplicate revenue/COGS/inventory | POS posts COGS in the paid-order journal while inventory mapper intentionally skips `sale_consumption`; a second invoice poster could journal either side again. | One coordinator owns the sale posting bundle and records distinct, idempotent events. No direct controller-level journal construction. |
| Premature stock consumption | Current POS consumes on full payment. Credit invoices need a stated recognition policy, not accidental consumption at draft, issue and receipt. | Define one “fulfillment/issue posts inventory” event; receipt must never consume again. |
| POS leakage into invoices | Order is table/shift/cashier/order-type/menu-snapshot oriented and requires active shift before pay. | Separate sales-invoice lifecycle and routes. Keep POS source context only in POS adapter. |
| Incorrect AR | `payments.order_id` is mandatory and there is no allocation history. | New customer receipts + allocations, derived outstanding balance, immutable reversal history. |
| Refund/return double reversal | Existing refund reverses payment/revenue/tax only and never stock. | Credit note must select “financial-only” or itemized restock/COGS reversal, once per line/event. |
| Reports/closing omission | Daily closing queries POS tables; cash-flow source classifier knows POS/refund only. | Extend each reporting/closing projection in same phase as new posting events. |
| Stale audit intent | Several service comments describe earlier phases; executable controller/service behavior is the source of truth. | Validate against end-to-end posting tests and ledger assertions, not comments alone. |

## Recommended boundary

Introduce a `SalesInvoice` aggregate for manual/professional sale documents, but do **not** make it a generic table replacing `orders` in the first release. Extract a narrow `SalesPostingCoordinator` used by both:

* **POS adapter:** retains current order lifecycle and, on paid order, invokes the coordinator with POS line/snapshot/settlement context.
* **Invoice adapter:** issues/reverses invoices, creates AR or immediate settlement according to its lifecycle, and invokes the same coordinator for revenue, tax, inventory and COGS.

The coordinator must return no side effect on replay and must use a stable sale-document-line reference in inventory and consumption records. It must choose exactly one authoritative journal per event:

* immediate POS/manual paid sale: Debit cash/bank, Credit revenue/tax; plus Debit COGS/Credit inventory if stock tracked;
* credit invoice issue: Debit AR, Credit revenue/tax; plus COGS/inventory once at agreed fulfillment point;
* customer receipt: Debit cash/bank, Credit AR only;
* credit note/return: Debit sales returns/tax and Credit AR or cash/bank; inventory/COGS reversal only for explicitly accepted return lines;
* reversal: a separate reversing journal referencing the original, never edits a posted document.

That boundary preserves the repository’s current separation: stock movement remains inventory-authoritative, journal entries remain finance-authoritative, and document lifecycle decides whether a business event exists.

## Evidence-backed readiness conclusion (superseded by final decision pass)

At this forensic-audit point, four policy decisions had not yet been made, so the repository was ready only for a foundation phase. The final decision pass now resolves them without production changes: immutable future credit notes, invoice-post-time COGS/inventory, tenant-configured AR, and strict POS isolation. See the ADR and final plan for the implementation-safe Phase 0/1 contract.
