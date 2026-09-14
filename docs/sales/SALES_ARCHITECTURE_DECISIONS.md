# Sales Architecture Decisions

**Status:** Accepted for Phase 0 and Phase 1 planning.
**Scope:** Manual Finance Sales Invoice and customer AR. These decisions do not change production behavior.

## ADR-01 — Sales Returns

### Context

Journal reversal already creates a separate posted entry and retains the original (`backend/app/Services/JournalEntryService.php:96-173`). POS refund is amount-based and deliberately creates no restock movement because it has no item detail (`backend/app/Http/Controllers/Api/RefundController.php:92-95`).

### Decision

Posted Sales Invoices are immutable. Phase 4 adds a separate `sales_credit_notes` / Sales Return aggregate linked by `original_sales_invoice_id`, with original line, quantity, price, tax, COGS and movement references. A correcting reversal is distinct from a physical return: reversal corrects an invalid original event; a credit note reduces revenue/tax/AR or refunds settlement, and restocks/reverses COGS only for accepted item lines.

### Why

An amount-only credit cannot determine whether goods were returned, saleable or damaged. Linked immutable evidence prevents repeated revenue and stock reversal.

### Rejected alternatives

Editing posted invoice; reusing POS `payment_refunds`; treating every credit as an inventory return.

### Consequences

Phase 0 includes additive original-reference hooks only. Phase 4 owns credit-note/return behavior and tests.

### Phase affected

0, 4.

## ADR-02 — COGS and Inventory Recognition Timing

### Context

POS currently consumes stock and snapshots cost during paid-order processing (`backend/app/Http/Controllers/Api/PaymentController.php:96-115`). Its consumption service uses immutable recipe snapshot, conversion, warehouse selection and WAC-backed movements (`backend/app/Services/SaleConsumptionService.php:48-165`, `181-300`).

### Decision

Manual Invoice draft has no effects. `posted` recognizes revenue, tax, AR, COGS and tracked-product inventory consumption atomically. Customer payment never controls COGS or inventory; a zero-paid credit invoice posts both at invoice post.

### Why

Invoice post is the manual sale/fulfillment event. Delaying COGS/stock until collection makes AR, stock availability and profitability incorrect.

### Rejected alternatives

Faking POS payment; consumption at draft; consumption at customer receipt.

### Consequences

Extract reusable lower-level consumption; preserve POS timing. Invoice posting is Phase 2.

### Phase affected

0, 2.

## ADR-03 — Accounts Receivable

### Context

Current default accounts omit AR (`backend/app/Services/FinancialSetupService.php:46-69`), while automatic posting resolves an active account by tenant code (`backend/app/Services/AccountingPostingService.php:174-207`). Supplier AP derives outstanding from posted invoices minus allocations (`backend/app/Services/SupplierPayableQueryService.php:8-36`).

### Decision

Create customer AR subledger: `sales_invoices`, `customer_payments`, `customer_payment_allocations`. Add protected default AR account `1200`, group `assets`, normal `debit`, plus a new tenant Finance-setup table `sales_account_mappings` with unique `(tenant_id, mapping_key)`, FK `financial_account_id`, and `mapping_key = sales.accounts_receivable`. Tenant setup seeds it to the tenant's `1200` account; runtime resolver validates account tenant/activity/group/normal balance and supplies its code to the existing poster. Open amount/payment status derives from allocations and credit notes; it is never an independent editable balance.

### Why

It provides statement, aging and partial-collection history with GL as the AR control total.

### Rejected alternatives

Hardcoded database account ID; invoice-only paid/remaining fields; reuse of supplier AP tables.

### Consequences

Finance setup/readiness seeds and validates mapping. Missing/invalid/inactive mapping fails post as `SALES_AR_ACCOUNT_NOT_CONFIGURED`, never silently falling back to cash/revenue.

### Phase affected

0, 2, 3.

## ADR-04 — Customer Payment Ownership

### Context

Generic Finance receipt vouchers post arbitrary supplied account lines and have no invoice-allocation invariant (`backend/app/Services/FinanceDocumentService.php:74-97`, `127-172`).

### Decision

`CustomerPayment` is the AR settlement business record and creates exactly one journal: Dr cash/bank; Cr AR. Finance can display/print it as a receipt-voucher representation but must not create a second `finance_documents` record/journal.

### Why

Customer, allocation, open-credit and reversal invariants belong to one sales record. One owner gives one audit trail and reconciliation transaction.

### Rejected alternatives

Generic voucher as payment owner plus allocation record; posting both CustomerPayment and Finance voucher; mixed cash/AR invoice journal.

### Consequences

Phase 3 implements CustomerPayment receipt number, journal/reversal IDs, allocation history and print adapter.

### Phase affected

3.

## ADR-05 — POS Compatibility

### Context

Orders are POS records with shift/table/cashier/order-type lifecycle (`backend/database/migrations/2026_05_31_000010_create_orders_table.php:11-38`; `backend/app/Services/OrderLifecyclePolicy.php:13-85`). Payments and legacy consumption are mandatory order-linked (`backend/database/migrations/2026_05_31_000012_create_payments_table.php:11-30`; `2026_08_18_000001_create_recipe_sales_costing_tables.php:27-32`).

### Decision

POS remains authoritative: `orders`, `order_items`, `payments`, `payment_refunds`, immediate settlement and shift/drawer policy. Manual Finance Sales owns invoice/line/payment/allocation tables and accrual AR. No shadow invoice is made for POS.

### Why

It avoids imposing AR/partial-collection/professional-invoice lifecycle on POS and avoids historical reporting/journal disruption.

### Rejected alternatives

`orders.source=manual`; a shadow invoice per POS sale; generic sales-document rewrite now.

### Consequences

POS golden equivalence is mandatory: order/payment/shift, journal, inventory/COGS, refund and Daily Closing remain identical unless separately approved bug fix.

### Phase affected

0–6.

## ADR-06 — SalesPostingCoordinator Boundary

### Context

Accounting posting is a generic idempotent journal orchestrator (`backend/app/Services/AccountingPostingService.php:10-29`, `49-123`); inventory posting owns WAC/movements (`backend/app/Domain/Inventory/InventoryPostingService.php:25-93`). Current POS controller composes sale journal lines and consumption is order-specific.

### Decision

Introduce a small `SalesPostingCoordinator` that orchestrates typed source event, pricing/tax result, inventory-cost result and journal-line composition. Delegate to `SalesPricingTaxResolver`, `SalesInventoryConsumptionService`, `InventoryPostingService` and `AccountingPostingService`. It owns neither UI, allocation, shift, WAC nor aggregate lifecycle.

### Why

Shared lower-level rules prevent divergent recipe/unit/WAC/COGS algorithms while aggregates retain different lifecycle and journal shape.

### Rejected alternatives

Duplicating consumption in invoice service; calling `PaymentController`; giant universal sales service.

### Consequences

Phase 0 defines typed interfaces and POS characterization. Phase 2 adds invoice adapter only after POS output equivalence.

### Phase affected

0, 2.

## ADR-07 — Immediate Payment

### Context

Manual Invoice is accrual; POS direct settlement debits the payment-method account (`backend/app/Http/Controllers/Api/PaymentController.php:176-202`).

### Decision

Every posted manual invoice debits AR, including immediate payment. Immediate collection creates separate CustomerPayment and allocation. Phase 3 may orchestrate both in one outer transaction.

### Why

It preserves statement, allocation, payment-method, partial payment, reversal and audit evidence without mixing AR and cash in revenue recognition.

### Rejected alternatives

Split invoice cash/AR journal; turn immediate manual sale into POS; defer sale until collection.

### Consequences

Immediate manual sale has two journals, but revenue is credited once—on invoice; payment credits AR only.

### Phase affected

2, 3.

## ADR-08 — Daily Closing

### Context

Daily Closing aggregates POS orders/payments/refunds and cash drawer only includes cash payment/refund types (`backend/app/Services/DailyClosingSummaryService.php:23-30`, `43-89`; `backend/app/Services/ShiftCashSummaryService.php:8-64`).

### Decision

Project sales separately from settlement: credit invoice adds revenue/COGS/AR but no cash; cash receipt adds drawer cash only on receipt date; bank receipt affects bank/reconciliation only; POS remains unchanged.

### Why

Cash collection and accrual sale dates differ.

### Rejected alternatives

Count invoice and receipt as sales; infer sales from cash; change POS close to AR behavior.

### Consequences

Phase 5 adds invoice/receipt projections and integrity checks; no Phase 0–3 close behavior change.

### Phase affected

5.

## ADR-09 — Reporting

### Context

Formal finance reports use posted journals (`backend/app/Services/FinancialReportQueryService.php:12-13`, `132-136`); cash flow classifies only known POS/refund source types (`:95-104`).

### Decision

GL/P&L/Balance Sheet/AR control use journals. Operational product sales use one normalized union of paid POS and posted invoice/credit-note lines, not journals plus source tables. Payment-method reporting uses settlement events; AR reports use open-item/allocation events.

### Why

This avoids double counting while retaining product quantities absent from journal lines.

### Rejected alternatives

Add POS totals to GL revenue; count receipt as sale; mutable invoice fields for AR aging.

### Consequences

Phase 5 adds source classifications, projections and reports.

### Phase affected

5.

## ADR-10 — Idempotency

### Context

POS has payment, movement and journal idempotency safeguards (`backend/app/Http/Controllers/Api/PaymentController.php:63-73`; `backend/app/Services/SaleConsumptionService.php:75-83`, `119-129`; `backend/app/Services/AccountingPostingService.php:61-75`).

### Decision

Invoice create, invoice post, customer payment, allocation and future credit note use separate tenant-scoped key/fingerprint pairs. Replays with same immutable payload return original effect; key reuse with different payload conflicts. Invoice posting locks its invoice; allocation locks payment and target invoices deterministically. Shared journals retain source/event uniqueness.

### Why

Create, post and collect are distinct business effects; UI duplicate-click prevention is insufficient.

### Rejected alternatives

One key for entire invoice lifetime; UI-only protection; weakening POS scopes.

### Consequences

Phase 0 defines indexes/contract; Phases 2–4 add concurrency/replay tests.

### Phase affected

0–4.

## Final Phase 1 entry criteria

| Question | Answer |
|---|---|
| Sales Invoice source of truth | Independent `sales_invoices`/lines aggregate. |
| Revenue post timing | Invoice `posted`. |
| COGS/inventory timing | Invoice `posted` for tracked products; never receipt. |
| AR account | `sales_account_mappings.sales.accounts_receivable`, default protected `1200` asset/debit. |
| Customer Payment owner | `CustomerPayment`, one settlement journal, voucher representation only. |
| Allocation | Many-to-many allocations; balances/status derived. |
| POS isolation | POS tables/lifecycle/journals/shift rules remain authoritative; no shadow invoice. |
| Shared POS code | Typed pricing/tax, inventory-consumption and posting coordinator adapters. |
| Future returns | Linked Credit Note/Sales Return with original line/cost/movement references. |
| Double-count prevention | Financial reports use journals; operations use one source-line union; closing separates sale and settlement. |
