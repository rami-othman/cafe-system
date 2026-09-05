# Finance Backend Gaps — Phase 0

## Verified strengths

- Finance routes use `api.token`, `TenantContext`, route permissions, and tenant-scoped queries.
- Expense, AP invoice/payment, transfer, journal, reconciliation, close, and period services are covered by dedicated feature tests for posting, reversal, and idempotency.
- Posted financial effects are journal based; reversal routes exist instead of destructive delete routes.

## Gaps and risks

| Priority | Finding | Evidence / impact |
|---|---|---|
| Fixed | Bank detail and movement routes were absent while Flutter called them. | Added GET bank detail and transactions routes. |
| Fixed | Flutter parsed account movement composite data as a list. | The detail dialog always received an empty/invalid list; corrected to parse `transactions`. |
| Fixed | Cash/bank URL kind and branch access were not enforced consistently. | Details and movements now reject the opposite kind, require actor branch access, and list only assigned/company-wide locations for non-owners. |
| Fixed | Accounting-period list was unpaginated. | It now returns canonical `data + meta`, with validated `page`/`perPage` and server paging. |
| Medium | Finance settings APIs for approval rules and role permissions have no Finance settings UI. | Backend functionality is not operable through Flutter. |
| Medium | Reconciliation and accounting-period create/edit endpoints have no frontend entry point. | APIs exist but the core workflow cannot start from the app. |
| Low | Most Finance controllers are compact one-line files. | Auditing and maintenance are unnecessarily difficult; no behavior change proposed in Phase 0. |

## Financial-calculation ownership

No duplicate accounting engine was found in Flutter. Flutter formats and validates draft journal cents locally before submission; Laravel is still authoritative for balancing, state transitions, posting, reversals, balances, payables, reconciliation and reports. The supplier statement running balance is calculated in Laravel, not Flutter.

## Security audit conclusion

No route accepts client `tenant_id`. Endpoint controllers shown in the Finance route group call `TenantContext::id`. Branch-scoped invoices, payments, journals and closings enforce actor branch access in their services/controllers. Required follow-up tests: bank/cash URL-kind mismatch, every non-owner list/detail cross-branch denial, and all setting endpoints for a non-owner role.
