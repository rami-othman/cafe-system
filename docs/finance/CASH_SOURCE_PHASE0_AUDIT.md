# Cash source architecture audit (Phase 0)

Audited from source on 2026-09-19. No staging database connection was used; the reported staging rows are user observations, not independently verified here.

## Identity and schema

| Field | Current meaning and assumption |
| --- | --- |
| `financial_account_id` | GL destination. The original `financial_locations` migration made `(tenant_id, financial_account_id)` unique, wrongly making one physical location per account. Migration `2026_09_26_000001` removes that uniqueness and adds a nonunique index. |
| `financial_location_id` | Physical cash/bank location on supplier payments, customer payments/refunds, vouchers, transfers and reconciliations. POS `payments` has no physical location column. Cash expenses use `paid_from_financial_location_id`. |
| `branch_id` | Operational scope on locations, shifts and business documents. A null branch location is tenant-wide; branch access checks alone do not bind it to an operation's branch. |
| `shift_id` | Operator responsibility. Shifts have a nullable location. Supplier payments and vouchers gained nullable shift links in migration `2026_09_25_000001`; customer payments, refunds and expenses do not have one. |

## Existing paths

- `FinancialSetupService` preserves a tenant-wide `CASH-DRAWER`, creates a branch drawer idempotently, and makes `CASH` a generic method with null location. The branch drawer is identified by counting active branch drawers, with no explicit branch setting.
- `ShiftController::open` stores the one active branch drawer when exactly one exists, but otherwise opens a shift with a null drawer. It does not validate the drawer's financial account.
- `PurchaseCashSourceResolver` requires exactly one active branch drawer for every role. It can repair an open null shift during preview, and rejects a shift tied to a different drawer after branch configuration changes. It has no manager selection. `PurchasePostingOrchestrator` wraps invoice posting, receipt, supplier payment, voucher and shift movement in one transaction and uses fixed invoice-derived idempotency keys.
- `SupplierPaymentService`, `CustomerPaymentService`, `CustomerRefundService`, `ExpenseService` and `FinanceDocumentService` each validate a caller supplied location independently. Their branch/actor/shift rules differ. The API controllers generally require `financialLocationId`, including for cashier requests. This is the principal backend override gap.
- Manual sales immediate collection passes a Flutter selected method/location into `CustomerPaymentService`; the AR-only post path has no cash source. The Flutter sales dialogs filter methods by nonnull `financialLocationId`, which excludes the generic `CASH` method.
- The purchase Flutter form and detail screens display a previewed drawer, but cannot offer a manager selection. Branch editor exposes a POS inventory warehouse setting but no POS cash drawer setting.
- `ShiftCashSummaryService` counts POS payments/refunds and `shift_cash_movements`. Purchase auto payment writes an expense movement. Other direct customer payments, refunds and expenses do not consistently write shift movements, so expected cash can omit them.
- `DailyClosingSummaryService` aggregates branch cash amounts from supplier payments, customer payments/refunds and expenses by location kind, but its shift cash figure comes from shift summaries. `FinancialReconciliationQueryService::eligible` selects journal lines by GL account and optional branch, ignoring `financial_location_id`; two drawers sharing 1010 cannot be reconciled independently from those lines. `FinancialReconciliationService::complete` checks overlapping periods by account alone.
- `CashTransferService` already transfers location to location, separately from warehouse transfers. Reports based on GL account are valid at account level; physical drawer reports require location identity.
- `FinancialActor` delegates branch scope to `BranchAccessService`. Finance routes have permission middleware, but location selection needs domain-level checks because route permission alone cannot prove drawer ownership.

## Root cause and migration safety

The reported staging branch has a null shift location and only a global `CASH-DRAWER`. The purchase resolver deliberately requires a branch cash drawer, so cash posting fails before the transaction. The existing branch-drawer migration may not have run in staging, may have failed, or may have run without giving the branch an explicit configured default; staging migration status and rows must be checked before applying further migrations. Keep the global row and historical records. Never infer a physical drawer from account 1010 or generic method `CASH`.

## Required implementation order

1. Add explicit branch default drawer, backfill only unambiguous valid locations and create missing drawers idempotently. Validate it on shift open and snapshot it.
2. Centralize actor-aware cash source resolution. Cashiers require their open shift and cannot override its drawer. Managers/owners select an authorized location. Expose mode and options to the UI.
3. Route purchase, standalone supplier payment, manual sales collection, customer payment/refund, expense and vouchers through that resolver; persist source/shift and keep posting atomic and idempotent.
4. Make expected cash and daily closing consume all shift-linked movements exactly once. Fix reconciliation to distinguish physical locations sharing a GL account.
5. Update Flutter branch and transaction forms, test each role and rollback path, then validate staging without production deployment.

## 2026-09-19 continuation — reconciliation cross-drawer fix (item 4)

Added `journal_entry_lines.financial_location_id` (migration `2026_09_19_000002`,
nullable, additive, indexed with `financial_account_id`) and threaded it through
`JournalEntryService::createDraft`/`reverse`, `AccountingPostingService::post`
(new optional `financialLocationId` per line), and the cash-side journal line
in `SupplierPaymentService`, `CustomerPaymentService`, `CustomerRefundService`,
`ExpenseService`, `CashTransferService`, and `FinanceDocumentService::post`
(vouchers, matched by the document's configured location account).
`FinancialReconciliationQueryService::eligible` and
`FinancialReconciliationService::balances/journalTotals/complete` now filter
by `financial_location_id` (falling back to legacy untagged lines) so two
drawers sharing account 1010 no longer bleed into each other's reconciliation
balances, matches, or overlap checks. No historical journal rows were
rewritten — old lines keep a null location and remain included as before.

Verified: `BranchCashDrawerTest`, `FinancialReconciliationApiTest`,
`DailyClosingReconciliationTest`, `CustomerPaymentApiTest`,
`ExpenseWorkflowApiTest`, `PurchasingPhase2ApiTest` all pass except for
**4 pre-existing issue groups (5 failing test cases)** confirmed via
`git stash` to already exist before this continuation (not caused by it):
`PurchasingPhase2ApiTest::permission_is_required_to_receive...` (403 vs 201
manager permission gap); `CashierDashboardApiTest` has **two** failures
(`finance_blocks_stay_null...` and `...stock_list_exposes_quantities...`);
`DailyClosingIntegrityTest::inventory_posting_issue_is_scoped...` (a
`warehouse_id = 0` FK violation in a test fixture); and
`CustomerAgingAndStatementTest::day_1_to_5_scenario...`
(`SALES_ACCOUNT_NOT_CONFIGURED: sales.additional_charge_revenue` before this
continuation; a different, also pre-existing branch/location validation error
surfaces after — same root fixture problem, not investigated further here).
These 4 groups / 5 cases need attention before Phase 26 staging validation
but are outside this continuation's scope (item 4).

Remaining from the original plan: item 5 (Flutter forms/tests for the
remaining workflows — vouchers/expense/refund UI beyond what's already
uncommitted) and the still-open backend test failures above.
