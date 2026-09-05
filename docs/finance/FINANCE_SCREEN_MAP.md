# Finance Screen Map — Phase 0.5

## Canonical routes

| Area | Flutter implementation | Route | Classification | Notes |
|---|---|---|---|---|
| Overview shell | `FinanceWorkspaceScreen` | `/finance` | CANONICAL | Live dashboard, trends and branch data; owns the shared Finance shell. |
| Transactions | `FinanceWorkspaceScreen` tab | `/finance?tab=transactions` | CANONICAL | Paginated API list. |
| Cash & Banks / transfers | `CashBanksScreen` | `/finance/cash-banks` | CANONICAL | Account dialog and transfer dialog; no separate transfer route. |
| Expenses | `ExpensesScreen` | `/finance/expenses` | CANONICAL | Create/edit/detail dialogs and lifecycle actions. |
| Suppliers & payables | `SuppliersScreen` | `/finance/suppliers` | CANONICAL | Supplier list. |
| Supplier profile / invoices / payments / statement | `SupplierProfileScreen` | `/finance/suppliers/:id` | CANONICAL | Tabs; invoice/payment detail endpoints have no standalone UI. |
| Reconciliation | `ReconciliationScreen` | `/finance/reconciliation` | CANONICAL | List/detail workspace with backend-driven matching and reconciliation state. |
| Journal entries | `JournalEntriesScreen` | `/finance/journal-entries` | CANONICAL | Detail dialog, create, post and reverse. |
| Daily closing | `DailyClosingScreen` | `/finance/daily-closing` | CANONICAL | Daily list and detail workspace with backend close checks. |
| Financial reports | `FinancialReportsScreen` | `/finance/reports` | CANONICAL | Reports use backend data. |
| Chart of accounts | `FinancialAccountsScreen` | `/finance/accounts` | CANONICAL | Includes the backend-backed account-detail route. |
| Accounting periods | `FinanceOperationScreen(period)` | `/finance/accounting-periods` | CANONICAL | Server-paginated at 10 rows with detail/readiness/close/lock presentation. |
| Finance settings | `FinanceSetupDashboardScreen` | `/finance/settings` | CANONICAL | Readiness and operational setup links. |
| Payment methods | `PaymentMethodsScreen` | `/finance/settings/payment-methods` | CANONICAL | CRUD/status. |
| Expense categories | `ExpenseCategoriesScreen` | `/finance/settings/expense-categories` | CANONICAL | CRUD/status. |

## Legacy, duplicate, and dead code

| Implementation | Classification | Reason |
|---|---|---|
| Legacy `?tab=` workspace URLs | REDIRECT | Operational tabs redirect to their dedicated canonical Finance route. Only Overview and Transactions render in `FinanceWorkspaceScreen`. |
| Plural reconciliation/daily-closing URLs and old report paths | REDIRECT | They preserve deep-link parameters while routing to the canonical singular/report workspace. |
| `/finance-inventory-setup` accounts, journals, and setup URLs | REDIRECT | They preserve existing links without registering a second screen implementation. Warehouse setup remains its dedicated route. |

## Missing standalone screens

Cash, bank, transfer, expense, supplier-invoice, and supplier-payment details are presented through their operational workspaces, dialogs, or profile tabs. Account and accounting-period details have dedicated canonical routes.
