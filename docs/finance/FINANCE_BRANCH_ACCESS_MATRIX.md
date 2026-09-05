# Finance Branch Access Matrix â€” Phase 0.5

| Domain | Policy | Automated regression status |
|---|---|---|---|
| Transactions | Branch-scoped journals; company-wide rows are visible by design. | AUTOMATED — PASS: list, guessed detail ID, explicit Branch B filter denial. |
| Cash and bank locations | Branch-scoped location list/detail/movements; company-wide allowed. | AUTOMATED — PASS: cash/bank lists, detail, movements, URL-kind, tenant guessing. |
| Cash transfers | Both source and destination locations must be authorized. | AUTOMATED — PASS: rejected cross-branch transfer has no transfer/journal; authorized Branch A transfer succeeds. |
| Expenses | Branch-scoped; company-wide rows are visible by design. | AUTOMATED — PASS: list/detail and rejected lifecycle mutation preserve state/journals. |
| Supplier master | Tenant-wide master data. | TENANT-WIDE BY DESIGN — TESTED through tenant-scoped supplier/AP endpoints. |
| Supplier invoices | Branch-scoped financial record. | AUTOMATED — PASS: list/detail and rejected post preserve invoice/journal state. |
| Supplier payments | Branch-scoped financial record. | AUTOMATED — PASS: list/detail and rejected reverse preserves payment/reversal state. |
| Journal entries | Branch-scoped; company-wide rows are visible by design. | AUTOMATED — PASS: list/detail/post, transaction source detail, report ledger scope. |
| Reconciliations | Branch follows the selected financial location. | AUTOMATED — PASS: list/detail, update and statement-line mutation have no cross-branch effect. |
| Daily closing | Strictly branch-scoped. | AUTOMATED — PASS: list/detail/update; denied update leaves actual cash unchanged. |
| Accounting periods | Tenant-wide accounting control. | TENANT-WIDE BY DESIGN — TESTED: same-tenant manager access, cross-tenant guessed ID rejected. |
| Chart of accounts | Tenant-wide accounting master data. | TENANT-WIDE BY DESIGN — TESTED: same-tenant access and foreign tenant list isolation. |
| Reports | Branch context applies to posted journals/payables. | AUTOMATED — PASS: general-ledger rows exclude Branch B for Manager A. |
| Dashboard | Context limits scope to assigned branches. | AUTOMATED — PASS: Branch B filter denied and branch metrics omit Branch B. |
| Finance settings | Tenant-wide settings; approval rules can carry an optional branch policy. | TENANT-WIDE BY DESIGN — TESTED: same-tenant settings visibility under permissions; tenant isolation preserved by TenantContext. |

`FinanceBranchIsolationTest` uses deterministic Branch A, Branch B, owner, two restricted managers, and a separate tenant. It verifies rejected branch mutations against persisted state, transfer/journal side effects, and guessed-ID resource hiding.
