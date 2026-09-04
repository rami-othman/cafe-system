# Finance API Map — Phase 0

All listed endpoints are under `/api/v1/finance`, require `api.token`, derive the tenant through `TenantContext`, and enforce the named `finance.permission` middleware. `data[] + meta` means a paginated list; `data object` means one entity or composite response.

| Screen / action | Repository method | HTTP endpoint | Controller / service / tables | Permission; branch scope | Response shape | Status |
|---|---|---|---|---|---|---|
| Overview | `getFinanceMap` | GET `dashboard`, `dashboard/trends`, `dashboard/branches` | `FinanceDashboardController` → query services → journals/orders/payments/expenses | `finance.view`; branch context | `data object` | Implemented |
| Transactions | `getFinancePage` | GET `transactions`, `transactions/summary` | `FinancialTransactionController` → `FinancialTransactionQueryService` → journal tables | `finance.transactions.view`; actor branch filtered | list + meta / object | Implemented |
| Cash/bank list | `getFinancialLocations` | GET `cash-accounts`, `bank-accounts` | `FinancialLocationController` → balance query → locations/accounts | `finance.cash_accounts.view`; non-owner rows filtered to assigned branches + company-wide | list + meta | Implemented |
| Cash/bank detail and movements | typed `getFinancialLocation`, `getFinancialLocationTransactions` | GET `{cash,bank}-accounts/{id}`, `/transactions` | `FinancialLocationController` → balance query → locations/journals | `finance.cash_accounts.view`; tenant, URL-kind, and actor-branch checked | detail object; `{location, transactions}` object | Fixed in Phase 0.5 |
| Transfer / reverse | `createCashTransfer`, `reverseCashTransfer` | POST `cash-transfers`, `cash-transfers/{id}/reverse` | controller → `CashTransferService` → transfers/journals | create/reverse permissions; branch checked in service | `data object` | Implemented |
| Expenses | `getExpenses`, `getExpense`, `saveExpense`, `expenseAction`, `payExpense` | GET/POST/PATCH `expenses`; POST lifecycle actions | `ExpenseController` → `ExpenseService` → expenses/journals | per-action permission and branch checks | list + meta / object | Implemented |
| Suppliers | `getSuppliers`, `getSupplier`, `saveSupplier`, `setSupplierStatus`, `getSupplierStatement` | CRUD `suppliers`, GET `statement` | `SupplierController` → supplier/payable query → suppliers/invoices/payments | supplier permissions; profile data tenant scoped | list + meta / object | Implemented |
| Supplier invoices/payments | repository methods | CRUD/post/reverse `supplier-invoices`; GET/POST/reverse `supplier-payments` | controllers → invoice/payment services → AP, allocations, journals | branch filtering and per-action permission | list + meta / object | Implemented; detail UI missing |
| Reconciliation | reconciliation repository methods | CRUD + statement/match/complete routes | controller → reconciliation services → reconciliation tables/journals | reconciliation permissions, actor/branch query scope | list + meta / object/list | Implemented; create UI missing |
| Journal | `getJournalEntries`, `getJournalEntry`, create/post/reverse | journal endpoints | `JournalEntryController` → `JournalEntryService` → journal tables | journals permissions and branch access | list + meta / detail | Implemented |
| Daily closing | operations repository methods | daily-closing(s) routes | `DailyClosingController` → services → closings/shifts/journals | daily-close permissions and branch access | list + meta / detail | Implemented; create flow missing |
| Reports | `getFinanceMap` | report routes | `FinancialReportController` → report query service → journals/AP | `finance.reports.view`; report branch context | `data object` | Implemented |
| Accounts | `getAccounts`, save/status | accounts routes | `FinancialAccountController` → account service → accounts | accounts permissions; tenant scoped | list + meta / object | Implemented |
| Periods | `getFinancePage` + operations repository methods | accounting-period routes | `AccountingPeriodController` → period service → periods/journals | periods permissions; tenant scoped | `data[] + meta` / object | Fixed in Phase 0.5 |
| Settings | payment/category repository methods | payment-methods, expense-categories | controllers → services → setting tables | settings permissions; tenant scoped | list + meta / object | Implemented |

## Contract fixes made

1. Cash and bank detail/movement routes now pass `kind` to the controller. A cash route rejects a bank location and vice versa with `404`; all list/detail/movement paths retain tenant and branch checks.
2. Flutter parses the detail response as `FinancialLocation` and the composite movement response as `FinancialLocationTransactions`, including an empty transaction list and API errors.
3. Accounting periods use the standard `data[] + meta` response and are requested at `page`/`perPage=10` by the operation screen.

## Remaining contract gaps

- Several detail repository methods (`getExpense`, `getSupplierInvoice`, `getSupplierPayment`) are implemented but unused by a dedicated detail view.
