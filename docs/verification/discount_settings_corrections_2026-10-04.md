# Plan 2 Discount backend corrections — 2026-10-04

Scope: three confirmed financial-calculation defects and the warehouse/engine concurrency gap only. Backend, directly related permanent tests and documentation. Existing uncommitted Plan 1/foundation/engine/Finance/Flutter work was retained. No Flutter implementation, commit, deployment, dependency upgrade, operational migration or operational data repair. `engineReady=false`, public Automatic creation/activation unavailable, D2-11 backend-partial; Plan 2 remains incomplete.

## Environment and isolation

Read the applicable ancestor/backend instructions search (no applicable backend AGENTS.md found), Plan 2 plan, backend contract, 2026-10-03 verification and actual implementation/tests. Memory identified the existing environment and was verified live.

Reused `windows_application/integration_test/fixtures/discount_acceptance.compose.yml`, project `cafe-discount-acceptance-20261003`, existing containers and volumes. Initial `ps -a`: both accept-backend and accept-postgres exited (137). Started these existing services only; PostgreSQL recovered its previous unclean shutdown and became healthy. Before any test writes, `DiscountEngineEnvironment.php` bootstrapped the actual Laravel environment and confirmed **APP_ENV=testing**, DB host **accept-postgres**, current database/user/version for both configured connections: **cafe_system_618_testing / cafe_system_618_testing_migrations**, **postgres**, **PostgreSQL 16.13**. The acceptance fixture DB `cafe_discount_acceptance_testing` and operational DBs were not test targets. Every database-mutating suite ran serially. The existing concurrency/migration lifecycle uses only the established isolated migration DB. No new Docker project/database/volume was created.

Commands from repository root unless specified:

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml ps -a
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml start accept-postgres accept-backend
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T accept-postgres psql -U postgres -d cafe_system_618_testing -c "select current_database(),current_user,version();" -c "select datname from pg_database where datname in ('cafe_system_618_testing','cafe_system_618_testing_migrations');"
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e APP_ENV=testing -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e DB_URL= accept-backend php tests/Fixtures/DiscountEngineEnvironment.php
```

The completed identity checks exited **0**. The initial combined service start exited **1** while PostgreSQL recovered its prior unclean shutdown; after its health check became healthy, `docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml start accept-backend` exited **0**. This startup result is separate from test results. Service restoration evidence is recorded below.

## Root causes and corrections

1. **Global cap bypass.** The old compatibility/capabilities/active decisions considered Automatic, combination mode and persisted engine state, but omitted `maximumTotalDiscountPercent`. Default-single old clients could still calculate/apply/pay through legacy pricing, ignoring the cap. A shared `DiscountResolutionService::requiresContract()` rule now includes **any nonnull cap**, non-single combination and Automatic. Capabilities, compatibility, legacy mutation, cart pricing and payment use this authority. Old clients reject with `DISCOUNT_CLIENT_UPDATE_REQUIRED`; contract-2 legacy apply/remove rejects with `DISCOUNT_REVIEW_REQUIRED`, directing clients to capped preview/apply/quote. Cap introduction affects existing unpaid legacy discounts; quotes invalidate through settings fingerprints. Default-null cap retains legacy behavior. Completed operation/payment replay returns durable results before new calculation or quote validation.
2. **Fixed per_unit allocation/overlap.** Scoring correctly summed quantity benefits but allocated that amount using selling-value weights. This transferred excessive benefit between lines and could leave a tiny already-eligible line undiscounted/unreserved for a second policy. Allocation now weights exact `min(value × quantity, remaining balance)` per-line contributions. Caps/budget scale those contributions with exact largest remainder and item-ID tie breaks. Aggregate HALF_UP can assign one rounding cent to a fractional contribution, bounded by that contribution's upward cent ceiling and actual line balance. Allocations sum exactly; positive allocations reserve disjoint identities. Fixed per_order and percentage selling-value semantics remain preserved. The reproductions produce `11.00` with `1.00/10.00` contributions and `1.01` with `1.00/0.01`, excluding the overlapping extra policy.
3. **Bundle early rounding.** `bundleWeights()` rounded each component into cents and scoring clamped the correct aggregate amount to the prematurely rounded component sum. Exact required-quantity × pinned-price component bases now survive until aggregate scoring/allocation. The established eligibility amount, aggregate rounding boundary, exclusive one-bundle selection and quantity semantics remain. The `0.333 + 0.333` reproduction pays `0.67`, allocating `0.34/0.33`; no legacy bundle pricing refactor was made.
4. **Warehouse/engine cycle dynamically confirmed.** Quote bound the warehouse before acquiring the engine gate. Binding holds an implicit FK warehouse KEY SHARE; an already-bound payment could own the engine gate and request warehouse FOR UPDATE through real inventory posting. Quote and payment now both acquire the engine gate before warehouse binding. Payment retains order → payment identity/replay → drawer → shift ordering; stock/balance/lot/accounting algorithms are unchanged. Order creation already inserts its warehouse FK after acquiring the gate.

## Deterministic PostgreSQL race evidence

Permanent `test_bound_stock_payment_and_first_unbound_quote_have_no_warehouse_engine_wait_cycle` uses independently bootstrapped PHP/HTTP-kernel workers on PostgreSQL. The fixture has an actual **stock-tracked product**, real recipe service writes, successful **menu publish API** with schema-v3 snapshot, variant/placement, configured warehouse, assigned material and positive WAC stock. It exercises a payment of an already-bound order against the first quote of another initially-unbound order in the same tenant/warehouse.

Parent owns advisory observation barrier `(20406,tenant)`. A test-only query listener pauses the payment worker immediately after its **real** engine-lock acquisition; business services, SQL, settlement and inventory paths remain intact. The parent observes the payment waiting on its barrier, then the quote waiting on the payment with `pg_blocking_pids`, and releases the barrier. It examines physical blockers in both directions, before PostgreSQL's deadlock timeout; framework transaction retries cannot conceal a cycle. No mocked settlement, replacement business callback, sequential-call race proof or timing-sleep synchronization is used. The listener exists only in the guarded isolated worker.

Before the lock correction, observed graph from the clean red run:

```text
payment PID 2289: wait_event_type=Lock, wait_event=transactionid
query: select * from "warehouses" ... limit 1 for update
pg_blocking_pids = {2290}

quote PID 2290: wait_event_type=Lock, wait_event=advisory
query: select pg_advisory_xact_lock($1, $2)
pg_blocking_pids = {2289}
```

This is an actual wait cycle, captured and failed before waiting for PostgreSQL to choose a deadlock victim. It is stronger than a source-only suspicion, without claiming an observed SQLSTATE 40P01 (the test deliberately terminates workers after capturing the cycle).

After correction: both workers finish with exit **0**, both HTTP requests return **200**, no cycle; second order binds after the engine gate. Both real payments settle `18.00`, consume one policy usage each and two recipe units each: stock `100.000 → 96.000`, two sale consumptions and sale movements, `COGS=4.00`/order, `gross_profit=14.00`/order, two posted balanced POS journals. A third stock-capable order rejects a stale quote with no side effects; a fresh quote then exercises insufficient-stock rollback with negative stock disabled, retaining zero payment/usage/snapshot/allocation/consumption/journal effects for that order and unchanged stock/movement counts.

## Commands and results

Common test prefix (exact environment on every mutating run):

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e APP_ENV=testing -e APP_LOCALE=ar -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e DB_URL= -e SUPER_ADMIN_WEB_URL= accept-backend php artisan test --do-not-cache-result
```

Append the exact arguments below to that prefix:

| Run | Arguments | Observed result |
|---|---|---|
| Confirmed-defect red, before calculation fixes | `--log-junit=/tmp/discount-corrections-red.xml --filter=DiscountEngineCorrectionsTest` | exit **1**; 8 failed / 1 passed; 61 assertions; 13.77s. Seven failures exercise cap/quantity/overlap/bundle defects; one new fixture submitted forbidden cap=0, subsequently corrected to a valid cap=1 while retaining replay assertions. |
| Clean warehouse red, before lock correction | `--log-junit=/tmp/discount-warehouse-red.xml --filter=test_bound_stock_payment_and_first_unbound_quote` | exit **1**; 1 failed; 11 assertions; 9.99s. Actual reciprocal physical wait graph above. Earlier fixture/category and resource-cleanup failures were corrected before this recorded clean reproduction. |
| Initial calculation rerun | `--log-junit=/tmp/discount-corrections-green-initial.xml --filter='DiscountEngineCorrectionsTest\|DiscountEngineTest'` | exit **1**; 28 passed / 1 fixture failure; 397 assertions; 23.30s. All original 20 engine behavior cases passed; cap=0 fixture then corrected. |
| Combined intermediate run | `--log-junit=/tmp/discount-corrections-green.xml --filter='DiscountEngineCorrectionsTest\|DiscountEngineTest\|DiscountEngineConcurrencyTest'` | exit **1**; 38 passed / 1 fixture failure; 713 assertions; 94.17s. No warehouse cycle; successful race settlement assertions passed. Third rollback-test order copied paid lifecycle from its fixture source; reset to a fresh unpaid lifecycle without weakening assertions. |
| Corrected warehouse/rollback run | `--log-junit=/tmp/discount-warehouse-green.xml --filter=test_bound_stock_payment_and_first_unbound_quote` | exit **0**; 1 passed; 56 assertions; 15.64s. |

Pipe characters in the Markdown table are escaped for rendering; actual shell filters use literal `|` without backslashes.

Final broad regression command:

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e APP_ENV=testing -e APP_LOCALE=ar -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e DB_URL= -e SUPER_ADMIN_WEB_URL= accept-backend php artisan test --do-not-cache-result --log-junit=/tmp/discount-corrections-final-focused.xml --filter='DiscountEngineCorrectionsTest|DiscountEngineTest|DiscountEngineConcurrencyTest|DiscountSettingsApiTest|DiscountSettingsFoundationTest|DiscountVariantBackendTest|DiscountVariantConcurrencyTest|DiscountManagementApiTest|DiscountV1ContractTest|DiscountV2BackendTest|DiscountSecurityHardeningTest|DiscountRuntimeEligibilityTest|DiscountCorsTest|PosApiSmokeTest|SnapshotAwarePosOrderApiTest|MoneyIdempotencyApiTest|OrderRefundableBalanceApiTest|RefundAccountingApiTest|ReceiptTemplateConfigurationTest|RefundConcurrencyApiTest|PreAuthFinancialConcurrencyTest|DailyClosingConcurrencyTest|ShiftOpenConcurrencyTest|HistoricalShiftCloseConcurrencyTest|HistoricalShiftCloseTest|ShiftCloseVarianceTest|ShiftReconciliationRaceTest|ShiftDrawerLifecycleTest|FinanceVoucherApiTest|CustomerPaymentApiTest|SalesCreditNoteApiTest|SalesCreditNoteDirectCashApiTest|SaleAccountingApiTest|InventoryAccountingMapperTest|FinancialInventoryFoundationApiTest|ProductInventoryTrackingE2ETest|MenuPublishingApiTest|RecipeConfigurationApiTest'
```

Final broad result: exit **0**, **378 passed / 4051 assertions**, **1011.69s**. This includes all nine new correction cases, all twenty existing engine cases, all ten engine concurrency cases (including the stock/warehouse race), settings/foundation/variant suites, payment/replay/receipt/inventory/accounting and affected financial concurrency regressions.

Additional directly affected real-sale regression, run serially after the broad suite:

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e APP_ENV=testing -e APP_LOCALE=ar -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e DB_URL= -e SUPER_ADMIN_WEB_URL= accept-backend php artisan test --do-not-cache-result --log-junit=/tmp/discount-corrections-real-sale.xml --filter=RealSaleIntegrationTest
```

Result: exit **0**, **13 passed / 360 assertions**, **17.86s**. Real published recipe consumption, legacy unpaid warehouse binding, completed-payment replay, invalid warehouse/material assignment and insufficient-stock rollback all pass. Final combined scope: **391 tests / 4411 assertions**, **zero failures, errors or skipped cases**, independently checked in both JUnit files.

Scoped static commands:

```powershell
# From backend: format only the changed concurrency test.
php vendor/bin/pint tests/Feature/DiscountEngineConcurrencyTest.php
# From repository root: final eight-file style check (source mount is read-only).
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T accept-backend php vendor/bin/pint --test app/Services/DiscountEngineProtocol.php app/Services/DiscountResolutionService.php app/Http/Controllers/Api/DiscountEngineController.php app/Http/Controllers/Api/PaymentController.php tests/Feature/DiscountEngineCorrectionsTest.php tests/Feature/DiscountEngineConcurrencyTest.php tests/Fixtures/DiscountEngineWorker.php tests/Fixtures/DiscountEngineEnvironment.php
$correctionFiles = @('backend/app/Services/DiscountEngineProtocol.php','backend/app/Services/DiscountResolutionService.php','backend/app/Http/Controllers/Api/DiscountEngineController.php','backend/app/Http/Controllers/Api/PaymentController.php','backend/tests/Feature/DiscountEngineCorrectionsTest.php','backend/tests/Feature/DiscountEngineConcurrencyTest.php','backend/tests/Fixtures/DiscountEngineWorker.php','backend/tests/Fixtures/DiscountEngineEnvironment.php')
foreach ($correctionFile in $correctionFiles) {
  php -l $correctionFile
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
git diff --check
```

Final scoped formatter/Pint/syntax/diff exits **0 / 0 / 0 / 0**; **8 files** pass Pint and all **8 PHP syntax checks** pass. An initial scoped Pint check found the new concurrency fixture's fully-qualified imports/style and exited 1; only that test file was formatted. Shared routes and unrelated files were not globally reformatted. Git's existing Windows CRLF informational warning is not a diff-check failure.

Ignored local JUnit evidence copied from the existing container into `backend/storage/app/`: `discount-corrections-red-2026-10-04.xml`, `discount-warehouse-red-2026-10-04.xml`, `discount-warehouse-green-2026-10-04.xml`, `discount-corrections-final-focused-2026-10-04.xml`, `discount-corrections-real-sale-2026-10-04.xml`. These artifacts preserve the calculation failures, actual warehouse cycle and final successful regressions without staging generated files. Each copy exited **0** using `docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml cp accept-backend:/tmp/<source>.xml backend/storage/app/<dated-name>.xml`.

Service restoration after all suites and evidence copies:

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml stop --timeout 60 accept-backend accept-postgres
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml ps -a
git diff --check
```

All three commands exited **0**. Final `ps -a` confirms both original containers stopped: backend **Exited (137)** after the stop grace period, PostgreSQL **Exited (0)**. The initial stopped state is restored; containers and existing database volumes were preserved, with no `down` or volume removal. Final post-documentation diff check passes.

## Modified-file inventory for this correction scope

- `backend/app/Services/DiscountResolutionService.php`: shared compatibility activation, exact contribution weights/scoring/allocator, bundle bases, allocation bounds.
- `backend/app/Services/DiscountEngineProtocol.php`: unified capabilities/compatibility/legacy-review decisions.
- `backend/app/Http/Controllers/Api/DiscountEngineController.php`: engine gate before quote warehouse binding.
- `backend/app/Http/Controllers/Api/PaymentController.php`: engine gate before payment warehouse binding; existing prior engine integration retained.
- `backend/tests/Feature/DiscountEngineCorrectionsTest.php` (new): permanent nine-case calculation/cap/replay/receipt regressions.
- `backend/tests/Feature/DiscountEngineConcurrencyTest.php`: stock/published-recipe wait-cycle test and settlement/rollback evidence.
- `backend/tests/Fixtures/DiscountEngineWorker.php`: isolated real-query observation barrier.
- `backend/tests/Fixtures/DiscountEngineEnvironment.php` (new): read-only live environment/database identity verifier.
- `docs/discount_settings_backend_contract.md`, `plans/discount_settings_automatic_combination_implementation_plan.md`, this report: changed compatibility/allocation/lock contract and acceptance evidence only.

PosPricingService and legacy endpoints obtain the correction through the shared engine authority; they did not need separate pricing rewrites. Existing foundation/engine migrations, Automatic rollout config, legacy eligibility bundle calculation, unrelated Finance files and Flutter files were not changed by this scope.

## Limits and Flutter handoff

The previous 2026-10-03 report records 44 full-suite failures reproduced against HEAD, plus shared-route Pint baseline findings. Those historical results are not a current full-suite rerun and are not called green here. This correction phase runs the directly relevant broad regression scope; it does not repair unrelated authorization/seeder/backdate/view-cache/Finance baselines or claim universal lock safety across every unrelated transaction schedule.

There are **no remaining blockers in this requested correction scope**. The backend is ready to hand off to the Flutter implementation phase under the existing contract and rollout gates. Public Automatic controls must remain unavailable during Flutter implementation; `engineReady=false` and D2-11 backend-partial remain unchanged. No Flutter implementation, Flutter acceptance or activation gate is closed by these backend tests.

Subsequent separately authorized Flutter/payment integration on the same date is recorded in [Flutter verification](discount_settings_flutter_2026-10-04.md). Its only later Backend exception canonicalizes normalized intent key order after PostgreSQL JSONB round trips, with before/after regression evidence. It does not rewrite the reviewed calculations, compatibility rules or lock ordering above. The original correction results remain historical evidence; public activation and D2-19 stay untouched.
