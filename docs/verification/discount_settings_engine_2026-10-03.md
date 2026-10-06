# Plan 2 backend engine verification — 2026-10-03

Scope: D2-05–D2-09 and backend prerequisites of D2-11. This record is finalized after serial verification. No Flutter implementation/build, deployment, commit, operational migration or acceptance fixture regeneration. Existing dirty Plan 1/foundation/Flutter files were preserved.

## Environment and authority

Existing Compose file `windows_application/integration_test/fixtures/discount_acceptance.compose.yml`, existing project `cafe-discount-acceptance-20261003`; no Docker changes/new project. Services accept-backend / accept-postgres, PostgreSQL 16.13, user postgres. Read-only `current_database/current_user/version` confirmed `cafe_system_618_testing` and `cafe_system_618_testing_migrations` before test writes. No operational or acceptance fixture database was targeted. Engine tests assert exact database names; independent worker tests use the migration-testing DB. Shared database suites ran serially.

Automatic verification uses APP_ENV=testing plus `discount_engine.isolated_automatic=true` and the actual database allowlist. Real policy/review/quote/snapshot/usage/payment/accounting persistence is exercised, while settings automatic_enabled stays false and the applied CHECK is unchanged. Public engineReady and Automatic policy creation remain false. Final activation requires a separate additive migration and capability change after frontend acceptance.

## Commands and observed results

Commands run from repository root unless specified. Test prefix:

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e SUPER_ADMIN_WEB_URL= accept-backend php artisan test
```

| Verification | Final observed result |
|---|---|
| Foundation/Plan 1 `--filter='DiscountSettingsApiTest|DiscountVariantBackendTest' --do-not-cache-result` | exit 0; 19 passed, 268 assertions, 22.68s (early baseline verification) |
| Initial wider Discount/POS/payment/receipt/refund/shift regression filter | exit 1; 136 passed / 4 failed, 1402 assertions, 670.52s. Two new failures subsequently fixed: required customer fixture identity fields and Automatic validation envelope. Phase12Authorization baseline and independent-worker locale mismatch listed below. |
| Corrected `--filter='DiscountEngineTest|DiscountSecurityHardeningTest|DiscountEngineConcurrencyTest|ShiftOpenConcurrencyTest' --do-not-cache-result` | exit 1; 28 passed / 1 locale failure, 541 assertions, 82.15s. All 17 engine behavior cases, 7 real PostgreSQL races and 3 security cases passed. |
| Final-source focused regression (exact command below) | exit 0; 269 passed, 2929 assertions, 923.89s. |
| HEAD comparison of all failing classes (exact command below) | exit 1; 185 tests, 141 passed, 12 errors + 32 failures, 1317 assertions, 534.937s. |
| Complete serial backend suite (`APP_LOCALE=ar`, no filter) | exit 1; 1082 passed, 44 failed, 1 skipped; 11289 assertions; 3299.76s. Executed before final small hardening changes; final-source focused rerun below is separate evidence. |
| Scoped Pint and PHP syntax | Engine/core 28-file Pint formatter and --test exit 0; 32 PHP syntax checks exit 0. Additional three lock callers formatted with exit 0. Final 31-file scoped Pint --test exit 0; final 32-file PHP syntax exit 0 (31 scoped files plus routes). git diff --check exit 0. |

The wider regression filter was:

```text
DiscountEngineTest|DiscountSettingsApiTest|DiscountSettingsFoundationTest|DiscountVariantBackendTest|DiscountVariantConcurrencyTest|DiscountManagementApiTest|DiscountV1ContractTest|DiscountV2BackendTest|DiscountSecurityHardeningTest|DiscountRuntimeEligibilityTest|PosApiSmokeTest|SnapshotAwarePosOrderApiTest|MoneyIdempotencyApiTest|OrderRefundableBalanceApiTest|RefundAccountingApiTest|ReceiptTemplateConfigurationTest|RefundConcurrencyApiTest|PreAuthFinancialConcurrencyTest|DailyClosingConcurrencyTest|ShiftOpenConcurrencyTest|HistoricalShiftCloseConcurrencyTest|Phase12AuthorizationApiTest
```

## Behavioral coverage

Exact actual monetary ranking after caps/budget; priority/ID ties; configured zero versus Automatic zero; greedy recalculation and positive allocation reservation; fixed/per_order once, fractional per_unit; BigInteger largest remainder; residual order stage/original minimum; item group versus exclusive order; category overlap and bundle exclusivity; persisted variant/branch/channel/customer/overnight schedule/usage eligibility; explicit Code/manual/ad-hoc intent; coupon secrecy; suppression reason/permission/setting/lifecycle/cart survival/order isolation/undo; stale reviews/durable replay/recovery/conflicts; full policy set/settings/expiry quote invalidation including lower totals; authoritative tender/provisional/no-tender/invalid mapping/zero-balance; policy-specific settlement usages, immutable snapshots, receipt/metrics/refund/accounting and old-client guards.

Race coverage uses independent PHP/PDO workers and a PostgreSQL physical wait-graph barrier. Parent holds the tenant advisory gate, observes every worker's blocking graph reach that transaction, releases it, and validates committed payment/usage/allocation/amount/journal balance effects. No sequential calls or sleep-based race timing are presented as proof. Cases: final policy use across orders, overlapping multi-policy payments, different policies on one shift/drawer, absent/existing settings versus payment, policy create/edit versus payment, duplicate operation/payment and later completed replay, apply/remove/suppress/undo versus cart mutation. Final coverage also includes policy creation versus quote and tenant-wide payment identity reuse across different orders; all nine race cases passed in the final rerun. All 20 engine behavior cases passed, including final intent/permission/tender-map/rollback hardening.

## Lock audit and migration

Full affected-call graph and implicit FK lock considerations are in the authoritative backend contract. Drawer now precedes shared/exclusive shift consistently across ShiftLockService, POS cash location, refund, CashSourceResolver, manual/automatic close, legacy adoption and Finance voucher post/reverse. Payment acquires exclusive shift once before policy/stock/Finance work. Journal/customer payment/refund/credit-note refund/voucher numbering uses tenant FOR NO KEY UPDATE to avoid tenant FK key-share upgrades. Settings and all policy API writers share advisory `(20402,tenant)` before settings/policy children; policy parent locks are ascending ID. Existing inventory warehouse/balance/lot and accounting algorithms remain unchanged. Tenant-wide policy gate deliberately serializes resolution/configuration within a tenant; throughput is a limitation to measure before activation.

Additive engine migration `2026_10_03_000003_create_discount_engine_protocol.php` adds priority/no-coupon Automatic constraint, explicit suppression permission and durable intent/review/operation/quote storage. Production rollback refuses engine snapshots or protocol/intent data, including cart snapshots without a quote; isolated race teardown deletes only its owned test records after assertions to rehearse structural rollback without weakening the guard. Foundation migrations were not edited. Paid history is not backfilled/reconstructed.

## Changed-file inventory for this phase

New: `backend/app/Services/DiscountResolutionService.php`, `DiscountEngineProtocol.php`, `backend/app/Http/Controllers/Api/DiscountEngineController.php`, `backend/config/discount_engine.php`, engine protocol migration, `backend/tests/Concerns/DiscountEngineFixture.php`, `backend/tests/Feature/DiscountEngineTest.php`, `DiscountEngineConcurrencyTest.php`, `backend/tests/Fixtures/DiscountEngineWorker.php`.

Integrated existing: DiscountAccess, DiscountRolePermissionController, DiscountController, DiscountEligibilityService, PosPricingService, PosOrderController, PaymentController, ReceiptController, RefundController, ShiftLockService, ShiftCloseService, LegacyShiftCloseConfigurationAdoptionService, PosCashLocationResolver, CashSourceResolver, JournalEntryService, CustomerPaymentService, CustomerRefundService, SalesCreditNotePostingService, FinanceDocumentService, routes/api.php, config/cors.php. Foundation test migration rehearsal now includes engine prerequisite down/up; CORS test includes the contract header. Formatting is scoped; financial business calculations were not redesigned.

Documentation: `docs/discount_settings_backend_contract.md`, Plan 1 contract engine addendum, this report, Plan 2 verified task status. Other dirty/untracked files (including Flutter, Plan 1 and foundation files) predated this phase and are not claimed as new engine work.

## Baselines, limitations and handoff gate

- Phase12AuthorizationApiTest line 25 retains the obsolete exact cashier capability array; FinanceAccess and that test remain unchanged from HEAD. No assertion was weakened.
- ShiftOpenConcurrencyTest's independent workers inherit APP_LOCALE=en from the acceptance service although its line 34 expects Arabic. The repeat uses explicit APP_LOCALE=ar, without editing its assertions or application translations.
- Shared routes Pint findings `fully_qualified_strict_types` and `ordered_imports` are pre-existing; routes were not globally reformatted.
- All 44 full-suite failing cases reproduced on a temporary HEAD source export: 185 cases, 141 passed, 12 errors and 32 assertion failures, 1317 assertions, exit 1, 534.937s. No exit-1 run is called green. Tests and FinanceAccess were verified unchanged from HEAD; fixture/permission/date/environment baselines are listed below.
- Public activation, Flutter settings/Create/Edit/POS/receipt/history rendering, EN/AR/layout and live acceptance remain open. D2-11 is backend-partial. Physical printer output is outside this phase.

The complete client endpoint/DTO/error/replay/quote sequence is in [the backend contract](../discount_settings_backend_contract.md). D2-05–D2-09 are implemented and verified; D2-11 remains backend-partial. The third Flutter/acceptance prompt may start implementation against these contracts, with public Automatic controls disabled. Runtime activation remains blocked by frontend/acceptance gates and the separate baseline failures; Plan 2 is not complete. No new relevant backend regression remains in the final 269-case focused run.

## HEAD baseline reproduction

The comparison used `git archive HEAD backend` extracted into `/tmp/discount-engine-head` in the **existing** backend container, with its existing vendor dependencies and a temporary Composer bootstrap selecting HEAD App/Tests/Database classes. It did not checkout, reset or overwrite the dirty worktree. DB_DATABASE and DB_DATABASE_MIGRATIONS_TESTING remained the two verified isolated databases. The exact test invocation was:

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e APP_ENV=testing -e APP_LOCALE=ar -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e DB_URL= -e SUPER_ADMIN_WEB_URL= accept-backend php vendor/bin/phpunit --configuration=/tmp/discount-engine-head/backend/phpunit.xml --bootstrap=/tmp/discount-engine-head/autoload.php --do-not-cache-result --log-junit=/tmp/discount-engine-head-result.xml --filter='AuthPhaseFourOperationalCutoverTest|AuthPhaseOneTest|BranchCashDrawerTest|Cafe618FinanceOperationsDemoSeederTest|Cafe618PosSalesDemoSeederTest|Cafe618ReportsDemoSeederTest|CashierAuthorizationApiTest|CustomerAgingAndStatementTest|ExampleTest|FinanceDashboardBreakdownAndBranchTest|FinanceDashboardExpensesAndApTest|FinanceDashboardSalesAndCogsTest|FinanceOperationsDemoSeederTest|ManufacturingCoreFlowTest|Phase12AuthorizationApiTest|PurchasingPhase1ApiTest|ReportsOverviewApiTest|SalesInvoiceLinePricingTest|SalesReportingUnionTest|ShiftCashSummaryApiTest|SmartSearchApiTest|StagingInitializerTest|SupplierAccountsPayableApiTest|WarehouseConfigurationRepairTest'
```

Final exit **1**. The same 44 failing cases/classes from the full suite reproduced; the comparison does not claim the entire HEAD suite was run. These remain separate pre-existing/environment findings, requiring separate authorization for repair:

| Cases/classes | Failed count | Observed cause |
|---|---:|---|
| AuthPhaseFourOperationalCutoverTest | 2 | stale drawer/shift fixture; NO_OPEN_SHIFT |
| AuthPhaseOneTest / CashierAuthorizationApiTest / Phase12AuthorizationApiTest | 3 | obsolete exact Finance permission/access expectations; Phase12 line 25 unchanged |
| BranchCashDrawerTest / ShiftCashSummaryApiTest | 3 | old close validation expectations versus current cashDifferenceReason/close behavior |
| Cafe618FinanceOperationsDemoSeederTest / Cafe618PosSalesDemoSeederTest / Cafe618ReportsDemoSeederTest / FinanceOperationsDemoSeederTest | 4 | drawer availability, already-open shift or opening cash/ledger fixture |
| FinanceDashboardBreakdownAndBranchTest / FinanceDashboardExpensesAndApTest / FinanceDashboardSalesAndCogsTest | 5 | selected drawer unavailable |
| CustomerAgingAndStatementTest / ManufacturingCoreFlowTest / SalesReportingUnionTest / SupplierAccountsPayableApiTest | 18 | missing required backdateReason in dated fixtures |
| PurchasingPhase1ApiTest | 1 | cash purchase payment missing branch |
| ReportsOverviewApiTest | 2 | aggregate assertion; English assertion versus explicit Arabic test environment |
| SalesInvoiceLinePricingTest | 1 | existing unit conversion quantity expectation (600 versus 1000) |
| SmartSearchApiTest | 2 | customer fixtures omit required customer_number |
| StagingInitializerTest | 1 | old role count (3 versus 4) |
| WarehouseConfigurationRepairTest | 1 | fixture lacks active cash account 1010 |
| ExampleTest | 1 | acceptance environment invalid view cache path; HEAD export also lacks that path |
| **Total** | **44** | **No new engine regression in this list** |

## Final-source regression command

This repeat follows the complete suite because final small hardening changes added saved explicit intent, invalid-intent preservation, source-snapshot rollback guard, cross-tenant tender-map validation, and tenant-wide payment identity locking. It verifies the final code separately; it does not relabel the earlier complete suite as a final-source green run.

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e APP_LOCALE=ar -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e SUPER_ADMIN_WEB_URL= accept-backend php artisan test --do-not-cache-result --log-junit=/tmp/discount-engine-final-focused.xml --filter='DiscountEngineTest|DiscountEngineConcurrencyTest|DiscountSettingsApiTest|DiscountSettingsFoundationTest|DiscountVariantBackendTest|DiscountVariantConcurrencyTest|DiscountManagementApiTest|DiscountV1ContractTest|DiscountV2BackendTest|DiscountSecurityHardeningTest|DiscountRuntimeEligibilityTest|DiscountCorsTest|PosApiSmokeTest|SnapshotAwarePosOrderApiTest|MoneyIdempotencyApiTest|OrderRefundableBalanceApiTest|RefundAccountingApiTest|ReceiptTemplateConfigurationTest|RefundConcurrencyApiTest|PreAuthFinancialConcurrencyTest|DailyClosingConcurrencyTest|ShiftOpenConcurrencyTest|HistoricalShiftCloseConcurrencyTest|HistoricalShiftCloseTest|ShiftCloseVarianceTest|ShiftReconciliationRaceTest|ShiftDrawerLifecycleTest|FinanceVoucherApiTest|CustomerPaymentApiTest|SalesCreditNoteApiTest|SalesCreditNoteDirectCashApiTest'
```

Final exit **0**: **269 passed, 2929 assertions, 923.89s**. All 20 engine behavior cases, all 9 engine independent PostgreSQL worker cases and all 11 existing PreAuthFinancialConcurrency cases passed. Plan 1/foundation/Discount/POS/payment/receipt/refund/Finance voucher/customer payment/credit note/shift regressions in the exact filter above passed.

Local ignored evidence artifacts: `backend/storage/app/discount-engine-final-focused.xml` and `backend/storage/app/discount-engine-head-result.xml`. Parsed JUnit confirms 269 cases / 2929 assertions / zero errors, failures or skips in the final repeat, and 44 failing cases in the HEAD comparison. Console duration includes runner overhead, so JUnit summed durations differ slightly.

## Final static verification commands

From `backend`, this exact scope covers the phase's integrated and new PHP files, excluding the pre-existing shared-route style baseline:

```powershell
$engineFiles = @(
  'app/Domain/Discount/DiscountAccess.php',
  'app/Http/Controllers/Api/DiscountController.php',
  'app/Http/Controllers/Api/DiscountRolePermissionController.php',
  'app/Http/Controllers/Api/DiscountEngineController.php',
  'app/Http/Controllers/Api/PaymentController.php',
  'app/Http/Controllers/Api/PosOrderController.php',
  'app/Http/Controllers/Api/ReceiptController.php',
  'app/Http/Controllers/Api/RefundController.php',
  'app/Services/CashSourceResolver.php',
  'app/Services/CustomerPaymentService.php',
  'app/Services/CustomerRefundService.php',
  'app/Services/DiscountEligibilityService.php',
  'app/Services/DiscountEngineProtocol.php',
  'app/Services/DiscountResolutionService.php',
  'app/Services/FinanceDocumentService.php',
  'app/Services/JournalEntryService.php',
  'app/Services/LegacyShiftCloseConfigurationAdoptionService.php',
  'app/Services/PosCashLocationResolver.php',
  'app/Services/PosPricingService.php',
  'app/Services/SalesCreditNotePostingService.php',
  'app/Services/ShiftCloseService.php',
  'app/Services/ShiftLockService.php',
  'config/cors.php', 'config/discount_engine.php',
  'database/migrations/2026_10_03_000003_create_discount_engine_protocol.php',
  'tests/Concerns/DiscountEngineFixture.php',
  'tests/Feature/DiscountEngineTest.php',
  'tests/Feature/DiscountEngineConcurrencyTest.php',
  'tests/Feature/DiscountSettingsFoundationTest.php',
  'tests/Feature/DiscountCorsTest.php',
  'tests/Fixtures/DiscountEngineWorker.php'
)
php vendor/bin/pint --test @engineFiles
foreach ($engineFile in @($engineFiles + 'routes/api.php')) {
  php -l $engineFile
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
php vendor/bin/pint --test routes/api.php
git diff --check
```

Final exits respectively **0 / 0 / 1 / 0**. Shared routes retain only the documented `fully_qualified_strict_types` and `ordered_imports` findings. No global formatting, assertion weakening or Finance redesign was used to conceal baseline failures.
