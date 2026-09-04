# Finance UI Gap Matrix — Phase 0.5

## Design-reference availability

The checked-in corrected reference is available at `docs/reference/finance/Cafe618_Finance_Workspace_CORRECTED.html`. Exact shell, token, spacing, typography, and component rules are frozen in `FINANCE_DESIGN_CONTRACT.md`.

## Current UI contract gaps

| Component | Current implementation | Gap |
|---|---|---|
| Finance shell/navigation | Router-level `FinanceNavigationBar` | Apply the frozen reference sidebar/topbar/page-heading/tab-strip consistently to every dedicated canonical route in Phase 1. |
| Breadcrumb / global period / branch / compare context | Partial visual context in `FinanceWorkspaceScreen` | Phase 1 must bind the reference context bar to shared period/branch/compare query state. |
| KPI, alerts, trends | Workspace dashboard | Uses live API, but only workspace overview exposes the full dashboard context. |
| Tables / paging / badges | Shared Finance paginator and management widgets | Accounting-period and operations lists now receive server pages; Phase 1 aligns every visual table/filter/badge detail with the frozen reference. |
| Cash/bank detail | Dialog in `CashBanksScreen` | No route/deep-linkable detail; bank contract was fixed in Phase 0. |
| Transfers | Dialog | No transaction list/detail route. |
| Expense detail / invoice detail / payment detail | Dialog/tab/list actions | Backend detail endpoints exist but no standalone screen/drawer. |
| Reconciliation / daily close / period workspaces | Generic `FinanceOperationScreen` | Workflow entry/create/edit UX is incomplete. |
| Settings | Readiness, payment methods, categories | No UI for approval rules or role permissions. |
| Loading / empty / error | Each screen supplies a local form | Not yet one consistently shared Finance presentation layer. |

Do not implement these deferred design changes in Phase 0.5.
