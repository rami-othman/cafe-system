# Sales Invoice Implementation Plan — Final Decision Pass

**Status:** implementation plan only. No production implementation is authorized by this document.
**Decision authority:** [SALES_ARCHITECTURE_DECISIONS.md](SALES_ARCHITECTURE_DECISIONS.md) is the final decision record; the forensic audit remains evidence of the pre-decision repository state.

## Final architecture

Manual Finance Sales and POS are separate commercial domains sharing lower-level rules—not one table and not two accounting engines.

```text
POS order/payment                       Manual Sales Invoice
orders/order_items/payments             sales_invoices/sales_invoice_lines
immediate settlement                    accrual sale into AR
shift and drawer rules                  customer/credit/allocations rules
            │                                      │
            └──────── shared, small services ─────┘
             SalesPricingTaxResolver
             SalesInventoryConsumptionService
             SalesPostingCoordinator
                         │
              InventoryPostingService + AccountingPostingService
```

* **POS remains authoritative:** it retains `orders`, `order_items`, `payments` and `payment_refunds`; no shadow `sales_invoices` row is created. Its immediate-settlement event remains `pos_order` / `POS_ORDER_PAID`.
* **Manual Sales Invoice is accrual:** a posted invoice debits AR, credits revenue/tax, and recognizes COGS/inventory for tracked lines.
* **Customer Payment is settlement:** one new AR business record posts one journal only: Dr cash/bank; Cr AR. It may be displayed/printed as a receipt voucher but never creates a second `finance_documents` posting.
* **Returns are future credit notes:** a return is a linked document, not an invoice edit and not an amount-only POS refund.

The design preserves the current POS bundle: payment writes its settlement, closes the order, consumes stock, snapshots COGS and posts the journal in one transaction (`backend/app/Http/Controllers/Api/PaymentController.php:63-118`, `176-202`). Manual Invoice calls extracted lower-level services; it never fakes POS payment.

## Final accounting and lifecycle contracts

| State | GL | AR | Inventory / COGS | Mutability |
|---|---|---|---|---|
| `draft` | None | None | None | Editable by authorized actor |
| `posted` | Dr AR; Cr sales revenue/tax; Dr COGS; Cr inventory as applicable | Receivable created | Consume tracked materials once and snapshot cost | Immutable |
| `reversed` | Linked reversing journal | Original receivable reversed | Reverse only original documented effect | Original immutable |
| `credited` (future) | Credit-note / return journals | AR reduced or separately refunded | Restock/reverse COGS only for accepted item lines | Original immutable |

Document status is persisted as `draft`, `posted`, `reversed` (later `credited` can be derived/presented). Payment status is **derived** from posted invoice total less posted payment allocations and future credit-note allocations, with due date: `unpaid`, `partial`, `paid`, `overdue`. Cached paid/open amounts, if added, are projections only.

### Invoice posting transaction

`SalesInvoicePostingService` owns the invoice aggregate transaction:

1. lock/re-read header and lines under tenant/branch scope;
2. require draft, active registered customer, valid branch/date and open accounting period;
3. validate product/service lines, immutable sale snapshot and server-recalculate totals/tax;
4. resolve validated tenant AR/revenue/tax/COGS/inventory mappings;
5. call `SalesPostingCoordinator` and `SalesInventoryConsumptionService` for tracked lines;
6. use persisted movement costs for COGS/inventory journal lines;
7. persist COGS/movement references, immutable snapshot, journal id and `posted` status;
8. audit and commit.

Any failure rolls back invoice, journal, movement and cost effects. Current inventory posting locks balance, calculates WAC and writes a movement (`backend/app/Domain/Inventory/InventoryPostingService.php:25-93`), while accounting posting has tenant/source/event idempotency (`backend/app/Services/AccountingPostingService.php:49-123`). Journal posting enforces period state and balanced lines (`backend/app/Services/JournalEntryService.php:60-94`; `backend/app/Services/AccountingPeriodGuard.php:8-27`).

### Immediate payment UX

“حفظ وترحيل واستلام دفعة” is permitted in Phase 3 as one outer operation but two accounting events:

1. invoice post: Dr AR / Cr revenue + tax; Dr COGS / Cr inventory;
2. `CustomerPayment` plus allocation: Dr cash/bank / Cr AR.

They have separate source events, journals and audits. A later receipt performs step 2 only. The invoice journal never mixes cash/bank and AR.

## Phase 0 — exact groundwork

1. Add `sales_invoices`, `sales_invoice_lines`, `customer_payments`, `customer_payment_allocations`, `sales_invoice_costs` (or equivalent sale-cost references), and professional customer profile fields. Add original invoice/line/quantity/price/tax/COGS/movement references needed by Phase 4 credit notes. Do not mutate legacy mandatory `sale_consumptions` FKs in place.
2. Add protected AR account code `1200` (asset/debit) to `FinancialSetupService::defaultAccounts()` and a new tenant Finance-setup table `sales_account_mappings` with unique `(tenant_id, mapping_key)`, FK `financial_account_id`, and mapping key `sales.accounts_receivable`. Tenant setup seeds that key to the tenant's `1200` account; the resolver validates the mapped account is active, tenant-owned, asset/debit, then passes its code to the existing journal poster. Inactive/missing/invalid mapping fails `SALES_AR_ACCOUNT_NOT_CONFIGURED`. Current finance setup lacks AR but `AccountingPostingService` resolves active tenant accounts by code (`backend/app/Services/FinancialSetupService.php:46-94`; `backend/app/Services/AccountingPostingService.php:174-207`).
3. Define typed `SalesPostingCommand`, `SalesLineForConsumption`, `SalesCostResult` and `SaleSource` contracts; introduce no new behavior yet.
4. Add finance sales/AR/receipt/future-credit-note permissions without broadening POS permissions.
5. Create POS characterization tests for cash/card, tracked/non-stock, discount/tax, refund, replay, stock failure and daily close. Existing exact-once/rollback proof is in `backend/tests/Feature/RealSaleIntegrationTest.php:32-65` and `backend/tests/Feature/ProductInventoryTrackingE2ETest.php:91-133`.
6. Use additive migrations, tenant-scoped sequences, unique idempotency indexes and restricted deletion for posted evidence.

## Phase 1 — exact scope

Build Customer and Sales Invoice **draft/core** only:

* customer legal/credit profile; credit invoice requires a registered active customer;
* draft invoice/line create/list/show/edit/delete-draft APIs and Finance Sales register/entry UI;
* product/service lines, server-side pricing/tax total calculation, invoice numbering, immutable-on-post shape and draft idempotency;
* no invoice posting, AR balance, customer payment, stock/COGS movement, reports or daily-close change.

Immediate manual sales use one configured tenant-level active **Cash/Walk-in Customer**. It is a normal `customers` record but credit disabled, so every manual invoice has identity while anonymous AR is impossible. Credit invoices cannot use it.

## Later phases

| Phase | Scope | Completion condition |
|---|---|---|
| 0 | Schema, AR mapping, permissions, contracts, POS characterization | Mappings, rollback and idempotency contract testable. |
| 1 | Customer + Sales Invoice draft/core UI/API | Drafts have no financial effects. |
| 2 | Invoice posting + AR + product COGS/inventory | Accrual invoice post is atomic and exactly once. |
| 3 | Customer Payment/receipt allocations + immediate-payment UX | One settlement journal; partial/many-to-many allocation correct. |
| 4 | Sales Returns/Credit Notes | Separate immutable financial-only/physical-return policy. |
| 5 | Reports + Daily Closing + dashboards | Sales/settlement projections do not double count. |
| 6 | Demo seeding + regression hardening | Migration/concurrency/POS-equivalence demonstrations pass. |

## Shared-services extraction boundary

| Component | Reuse/extract | Responsibility | Must not own |
|---|---|---|---|
| `SalesPricingTaxResolver` | `PosPricingService`, `TenantTaxService`, published menu pricing | Server-authoritative price/discount/tax snapshot | Invoice status, payment, journal writes |
| `SalesInventoryConsumptionService` | narrow extraction from `SaleConsumptionService::consumeForOrder()` | Tracking, immutable recipe, modifiers, canonical units, warehouse, inventory posting and cost result | POS payment/invoice header mutation |
| `SalesPostingCoordinator` | `PaymentController::postSale()` composition | Typed event, revenue/tax/COGS lines, inventory result orchestration | WAC, AR allocation, UI, POS shift checks |
| `SalesInvoicePostingService` | New | Invoice lock/lifecycle, AR mapping, outer atomic post | POS lifecycle |
| `CustomerPaymentService` | New/AP-patterned | Receipt lock, allocation caps/history, AR journal | Second generic voucher posting |

The smallest safe extraction is the algorithm now embedded in `SaleConsumptionService`: order-line lookup, published snapshot requirement, components, unit conversion, warehouse selection, stock post and cost snapshot (`backend/app/Services/SaleConsumptionService.php:48-165`, `181-300`). Extract it behind normalized sold-line/snapshot context; retain `consumeForOrder()` as POS adapter until golden outputs match. Never duplicate recipe, conversion, availability or WAC logic in invoice service.

## AR architecture

`customer_payments` stores customer, branch, date, payment method/location, amount/currency/reference, status, journal/reversal ids and idempotency. `customer_payment_allocations` links a payment to invoices. Invoice open balance derives from posted invoice total less posted payment allocations and future credit notes.

One payment may allocate to many invoices and many payments may allocate to one invoice. Lock payment and target invoices in deterministic ID order; require same tenant/customer and reject allocations over remaining payment or invoice. Phase 3 permits unapplied customer credit as an open customer credit, never revenue. This mirrors the proven supplier allocation *concept* without reusing AP ownership (`backend/database/migrations/2026_09_02_000009_create_supplier_ap_tables.php:82-118`; `backend/app/Services/SupplierPayableQueryService.php:8-36`).

`CustomerPayment` is the sole collection owner. Generic Finance receipt vouchers post arbitrary account lines and have no invoice-allocation invariant (`backend/app/Services/FinanceDocumentService.php:74-97`, `127-172`). A CustomerPayment therefore creates exactly one `CUSTOMER_PAYMENT_POSTED` journal and may only be represented—not duplicated—as a receipt voucher/print.

## Daily Closing and reporting contracts

| Business-date event | Revenue | AR | Expected drawer cash | Rule |
|---|---:|---:|---:|---|
| Credit invoice posted | Yes | Increase | No | Sale without settlement |
| Invoice + immediate cash receipt | Once on invoice | Increase then reduce | Increase on receipt | Never two sales |
| Later cash receipt | No | Reduce | Increase on receipt date | Collection only |
| Bank receipt | No | Reduce | No | Bank/reconciliation only |
| POS sale/refund | Existing | None | Existing | No POS semantic change |

Current closing directly queries POS orders/payments/refunds, so Phase 5 adds explicit invoice/receipt projections (`backend/app/Services/DailyClosingSummaryService.php:23-30`, `43-89`). Finance GL/P&L/Balance Sheet derive amounts from posted journals (`backend/app/Services/FinancialReportQueryService.php:12-13`, `132-136`). Operational product reports use one normalized source-line union of paid POS plus posted manual invoice/credit-note lines, never journals plus source rows. Payment-method reports own settlement events; AR reports own posted open items/allocations.

## Idempotency contract

| Action | Scope | Replay identity |
|---|---|---|
| Invoice create | tenant + create key | draft payload fingerprint |
| Invoice post | tenant + invoice + post key | immutable invoice snapshot/version |
| Customer payment | tenant + payment key | receipt + allocations fingerprint |
| Allocation | tenant + payment + allocation key | targets/amounts fingerprint |
| Future credit note | tenant + credit-note post key | original lines/quantities/reason/disposition |
| Journal | tenant + source type/id/event | existing journal unique guard |

POS scopes remain unchanged—payment idempotency, per-line/material movement idempotency and `pos_order/POS_ORDER_PAID` journal uniqueness (`backend/app/Http/Controllers/Api/PaymentController.php:63-73`; `backend/app/Services/SaleConsumptionService.php:75-83`, `119-129`).

## Regression and acceptance strategy

1. Establish POS golden cases before Phase 0 extraction, and compare before/after order/payment status, shift totals, journal source/lines, stock movement, COGS, refund and daily close. Differences require separate approved bug-fix scope.
2. Phase 2 tests prove invoice post rollback for mapping/stock/journal/period failure, exactly-once replay, COGS/inventory at post, and no product effect from later receipt.
3. Phase 3 tests prove partial/many-to-many allocation, concurrency over-allocation rejection, unapplied credit, reversal and as-of aging/statement accuracy.
4. Phase 4 tests prove financial-only credit has no stock effect and physical return reverses accepted original quantities/movements once.

## Decision matrix

| Decision | Final Choice | Existing Code Reused | New Work | Risk | Phase |
|---|---|---|---|---|---|
| Sales Invoice source | Independent `sales_invoices` | Finance journals/products | Header/line lifecycle | High | 0–2 |
| Revenue timing | Invoice `posted` accrual | Accounting/journal services | Invoice events | Critical | 2 |
| COGS/inventory timing | Invoice `posted`, never receipt | Inventory/WAC/recipe engine | Normalized adapter | Critical | 2 |
| AR control account | `sales_account_mappings.sales.accounts_receivable` → protected `1200` asset/debit | Finance setup/account resolver | Mapping/readiness | High | 0 |
| Customer | Registered credit customer; configured Cash/Walk-in customer for immediate manual sale | `customers` | Legal/credit profile | Medium | 0–1 |
| Customer payment | One CustomerPayment AR settlement journal | Locations/methods/journal | Receipts/allocations/print | High | 3 |
| Allocation | Many-to-many; status/open balance derived | AP allocation concept | Allocation/history/locks | High | 3 |
| POS isolation | Current POS tables/journals/shift rules stay authoritative | Current POS/tests | Adapters/golden tests | Critical | 0–2 |
| Returns | Separate linked credit note/physical return | Journal/inventory primitives | Credit note aggregate | High | 0, 4 |
| Closing/reporting | Ledger finance; source-union operations; cash on receipt | Finance/closing shells | Projections/classifiers | High | 5 |
| Idempotency | Independent business-action scopes | Existing journal/payment patterns | Invoice/AR keys | Critical | 0–3 |

ARCHITECTURE DECISION:
Manual Sales Invoices are independent accrual documents that post AR, revenue/tax and tracked-product COGS/inventory at invoice posting. CustomerPayment owns a single, separate AR-settlement journal and allocations. POS remains immediate-settlement with current tables, shift rules and journals. Both use shared typed pricing/tax, inventory-consumption and posting coordination services, without forcing POS through AR or creating shadow invoices.

PHASE 1 READY: YES

## Phase 2 completion / hardening (implemented)

* `SalesInvoicePostingService::preview()` is the read-only posting contract. It uses the same persisted totals validator, `SalesAccountResolver`, and `SalesInvoiceInventoryConsumptionService` plan as `post()`. It creates no journal, receivable, stock movement, cost snapshot, or status change.
* The selected `product_variant_id` is now persisted on every sales-invoice line (`2026_09_15_000002_add_product_variant_to_sales_invoice_lines.php`). A tracked line selects the default only when the draft is created; it is never re-resolved during posting. A user can choose another active variant through `variantId`; an old tracked draft lacking a variant is blocked rather than consuming an arbitrary recipe.
* POS selects `order_items.product_variant_id` from its immutable schema-v3 published-menu snapshot (`SaleConsumptionService::componentsForItem()`), while invoice posting selects its persisted line variant. Both canonicalize each component through `UnitConversionResolver::resolveRecipe()`, multiply by invoice/order quantity using `InventoryDecimal::applyFactor()`, route to `BR-{branch}-MAIN`, and write through `SalesInventoryMovementService` / `InventoryPostingService` WAC.
* The posting preview endpoint is `GET /finance/sales-invoices/{invoice}/posting-preview`. It returns invoice totals, resolved accounts and AR/revenue/tax entries, estimated WAC COGS/inventory entries, canonical material quantities, units and source warehouse. Validation failures (stock, mapping, recipe, WAC, variant, warehouse) remain server errors; Flutter does not calculate them.

### Characterized unit example

The dedicated `SalesInvoicePosCrossPathCharacterizationTest` configures a real selected `Regular` Cappuccino variant with `Coffee Beans = 18.000000 gram`, base inventory unit `gram`, WAC `0.0200`, and quantity `10`. Both paths produce one `sale_consumption` movement from the same `BR-{branch}-MAIN` warehouse: `180.000 gram`, unit cost `0.0200`, total COGS `3.60`. This is a test fixture, not a hard-coded production recipe.
