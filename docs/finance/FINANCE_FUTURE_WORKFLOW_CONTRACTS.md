# Finance Deferred Workflow Contracts â€” Phase 0.5

These workflows are confirmed in scope for repair, but are deliberately not started in Phase 0.5.

| Workflow | Existing backend contract | Permission contract | Deferred UI work |
|---|---|---|---|
| Reconciliation creation | `POST /finance/reconciliations` | `finance.reconciliation.manage`; tenant/branch-scoped | Canonical create entry point and validated form. |
| Accounting-period create/edit | `POST/PATCH /finance/accounting-periods` | `finance.periods.manage`; close/lock separately permissioned | Create/edit form; preserve server readiness/allowed actions. |
| Approval rules | `GET/POST/PATCH /finance/settings/approval-rules` | view/manage settings permissions | Settings section with explicit rule lifecycle. |
| Finance role permissions | `GET /finance/settings/role-permissions`, `GET/PUT /{role}` | view/manage settings permissions | Role matrix editor; no client-side authorization substitute. |

No deferred workflow may calculate balances, readiness, or permissions in Flutter. Laravel remains authoritative.
