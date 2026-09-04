# Finance Test Gaps — Phase 0.5

## Existing coverage

Backend feature coverage exists for dashboards, transactions, integrity, reconciliation, reports/periods, expenses, suppliers/AP, money/idempotency, authorization, sales/refunds, daily closing, and the connected demo seeder. Flutter coverage exists for models, suppliers, expenses, categories, home, navigation, and pagination.

## Missing or insufficient tests

1. Add UI tests for reconciliation creation, period creation/editing, approval rules, and role permissions after those screens exist.
2. Add a route inventory test which fails if a Finance screen is not reachable or if a canonical route regresses to an alias.

## Test-run classification

- Laravel `FinancialLocationContractApiTest`, `FinancialInventoryFoundationApiTest`, `FinanceRoutePermissionMapTest`, and `FinanceOperationsDemoSeederTest`: 17 passed, 426 assertions.
- Flutter repository contract tests cover cash/bank details, composite movements, empty list, errors, and period metadata; final analyzer/test status is recorded in the Phase 0.5 report.
- Phase 0.75 row-level branch regression: `FinanceBranchIsolationTest` passes with deterministic Branch A/Branch B/other-tenant records.
