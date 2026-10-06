# Plan 2 foundation verification — 2026-10-03

Scope: authorized D2-01–D2-04 only. No Flutter implementation/build, engine, operational suppression/application APIs, quote, multi-policy runtime, deployment or commits. Historical planning-only text is superseded only for this bounded phase by the current user authorization. D2-05 is the next unimplemented task.

## Inspection and preservation

No root/backend AGENTS.md was found; the only descendant AGENTS.md is under windows_application, whose implementation is outside scope. Direct checks of every ancestor AGENTS.md through C:\ and a hidden-file repository search found no applicable instructions; an initial home directory listing was denied and replaced by direct path checks. Reviewed the two authoritative plans, Plan 1 closure evidence, Discount controller/eligibility/pricing/schema/variant tests, tenant token middleware, DiscountAccess/catalog consumers, DefaultTenantRoleService, permission administration, general CafeConfigurationPolicy, operational audit and payment/refund/shift/inventory/accounting lock paths. Plan 1 documented closure is current in repository; backend preservation is verified by new regression execution, not old counts. Dirty baseline recorded before edits, inventory appended below. Existing Flutter, CORS, variant, pricing, concurrency fixture and acceptance work was preserved.

## Isolated test environment identity

Reused existing Compose project `cafe-discount-acceptance-20261003`, file `windows_application/integration_test/fixtures/discount_acceptance.compose.yml`, running accept-backend / accept-postgres. Read-only inspection confirmed Laravel APP_ENV=testing, DB_HOST=accept-postgres, PostgreSQL 16.13 (Debian 16.13-1.pgdg13+1), DB user postgres. Initial current_database was `cafe_discount_acceptance_testing`; the server initially contained only that database plus postgres/template0/template1.

To preserve compiled-acceptance fixtures and allow existing permanent tests' exact isolated migration-database assertions, created two empty testing databases **on that same isolated accept-postgres server**, without another Docker project, image build, Docker edits or operational connection:

- `cafe_system_618_testing`: normal transaction-wrapped suites.
- `cafe_system_618_testing_migrations`: existing DatabaseMigrations/independent-worker convention.

Both database identities were queried and confirmed with current_database/current_user/version before migrations/tests. `CREATE DATABASE` and both identity queries exited 0. The separate migration DB is necessary because independent workers require committed rows and migration rehearsal requires a real schema lifecycle. Acceptance fixtures are not reset by these suites. Operational `cafe_backend` containers were inventoried only; no operational migration/seed/reset/test writes were issued. No deployment occurred.

## Permanent checks

DiscountSettingsApiTest covers absent defaults, round trips, Owner/Manager access and revocation/grant administration, unrelated Profile/Tax denial, Employee/factory denial, foreign header isolation and mismatched token and foreign tenant-role reference denial, authenticated platform session rejection, strict fields/combinations/activation, stale writes, exact audit before/after/version/actor and rollback of first insert/existing update on injected audit failure.

DiscountSettingsFoundationTest uses independent HTTP workers and PostgreSQL advisory-lock blocking observation (`pg_blocking_pids` + exact wait event) before release for both first saves and existing updates. Each race proves one 200 and one 409, one row, one additional version/audit, and persisted data equal to the winner. No sleeping determines race progress. The same suite rehearses legacy paid/usage upgrades, nullable metadata/no invented allocations, unchanged receipt/order amounts after settings/policy changes, composite uniqueness, foreign-tenant and wrong-order allocation rejection, suppression reason/actor constraints, upgrade grants and revocation preservation, and refusal to restore old uniqueness once multiple usages exist.

## Command evidence

Commands run serially through the existing accept-backend container with explicit environment overrides:

```powershell
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e SUPER_ADMIN_WEB_URL= accept-backend php artisan test --filter='<suite filter>' --do-not-cache-result
```

Initial settings suite: exit 1, six passed/one failed. Failure was test route-controller caching retaining the injected failed audit dependency during a subsequent intended successful request; production rollback assertions were retained and the test lifecycle fixed by flushing the cached controller before the two failure requests. Final results are recorded after all source changes below; earlier counts are not closure proof.

Read-only network psql identity attempt: exit 1 because no password supplied. Local PostgreSQL socket identity queries and Laravel environment inspection succeeded and established the isolated server; this failed network attempt made no mutation. Initial sandbox Docker inventory was denied; authorized elevated read-only inventory succeeded (exit 0). One PowerShell inline Python route-edit attempt failed to parse (exit 1), wrote nothing, and was replaced with apply_patch.

## Changed-file inventory (this phase)

- backend/app/Domain/Discount/DiscountAccess.php
- backend/app/Services/DefaultTenantRoleService.php
- backend/app/Services/DiscountSettingsService.php (new)
- backend/app/Http/Controllers/Api/DiscountRolePermissionController.php
- backend/app/Http/Controllers/Api/CafeConfiguration/DiscountSettingsController.php (new)
- backend/routes/api.php (additive settings routes, existing dirty variant routes preserved)
- backend/database/migrations/2026_10_03_000001_create_discount_settings_foundation.php (new)
- backend/database/migrations/2026_10_03_000002_extend_discount_runtime_foundation.php (new)
- backend/tests/Feature/DiscountSettingsApiTest.php (new)
- backend/tests/Feature/DiscountSettingsFoundationTest.php (new)
- backend/tests/Feature/DiscountSecurityHardeningTest.php (Manager grant count only; four legacy grant checks unchanged)
- backend/tests/Feature/PreAuthFinancialConcurrencyTest.php (valid drawer/shared-shift fixture helper; prior dirty final-use fixture retained)
- docs/discount_settings_backend_contract.md (new)
- docs/verification/discount_settings_foundation_2026-10-03.md (new)
- plans/discount_settings_automatic_combination_implementation_plan.md (foundation status only)
- windows_application/PROJECT_STATUS.md (status documentation only)

## Backend handoff

After verified foundation closure, D2-05–D2-09 can start as a separately authorized backend phase, in dependency order. Reuse Plan 1 matcher and exact arithmetic. Complete runtime calculation/allocations first, then discovery/intent/suppression, preview/apply replay contract, tender-aware payment quote/fingerprint/usage consumption, then deterministic PostgreSQL race/cycle coverage. Current settings are stored only; consumeUsage still uses its single-order guard and Manual/Code replacement is unchanged. Future activation requires deliberate removal/replacement of the schema automatic guard and compatible client rollout after engine gates. `engineReady` remains false. Paid legacy aggregate snapshots remain readable with null metadata/no allocations; no backfill/recalculation is permitted.

## Initial dirty-worktree inventory

```text
 M backend/app/Http/Controllers/Api/DiscountController.php
 M backend/app/Services/DiscountEligibilityService.php
 M backend/app/Services/PosPricingService.php
 M backend/config/cors.php
 M backend/routes/api.php
 M backend/tests/Feature/PreAuthFinancialConcurrencyTest.php
 M backend/tests/Feature/SnapshotAwarePosOrderApiTest.php
 M windows_application/PROJECT_STATUS.md
 M windows_application/lib/features/discounts/controllers/discounts_cubit.dart
 M windows_application/lib/features/discounts/models/discount_detail.dart
 M windows_application/lib/features/discounts/models/discount_form_references.dart
 M windows_application/lib/features/discounts/models/discount_upsert_request.dart
 M windows_application/lib/features/discounts/repositories/discounts_repository.dart
 M windows_application/lib/features/discounts/views/create_discount_policy_screen.dart
 M windows_application/lib/features/discounts/widgets/discount_pos_preview_card.dart
 M windows_application/lib/l10n/app_ar.arb
 M windows_application/lib/l10n/app_en.arb
 M windows_application/lib/l10n/app_localizations.dart
 M windows_application/lib/l10n/app_localizations_ar.dart
 M windows_application/lib/l10n/app_localizations_en.dart
 M windows_application/test/app/route_scoped_request_topology_test.dart
 M windows_application/test/features/discounts/controllers/discounts_cubit_test.dart
 M windows_application/test/features/discounts/models/discount_detail_test.dart
 M windows_application/test/features/discounts/models/discount_upsert_request_test.dart
 M windows_application/test/features/discounts/views/create_discount_policy_screen_test.dart
 M windows_application/test/features/discounts/views/discounts_list_screen_test.dart
?? .playwright-mcp/
?? backend/app/Http/Controllers/Api/DiscountReferenceController.php
?? backend/app/Services/DiscountProductVariantService.php
?? backend/database/migrations/2026_10_01_000001_create_discount_product_target_variants.php
?? backend/tests/Feature/DiscountCorsTest.php
?? backend/tests/Feature/DiscountVariantBackendTest.php
?? backend/tests/Feature/DiscountVariantConcurrencyTest.php
?? backend/tests/Fixtures/DiscountVariantWorker.php
?? docs/discount_variant_backend_contract.md
?? docs/discount_variant_flutter_handoff.md
?? docs/verification/
?? output/playwright/
?? plans/discount_create_edit_variant_implementation_plan.md
?? plans/discount_settings_automatic_combination_implementation_plan.md
?? windows_application/integration_test/discount_variant_acceptance_live_test.dart
?? windows_application/integration_test/fixtures/
?? windows_application/lib/features/discounts/controllers/discount_targets_cubit.dart
?? windows_application/lib/features/discounts/models/discount_product_selection.dart
?? windows_application/lib/features/discounts/widgets/discount_product_targets.dart
?? windows_application/test/features/discounts/discount_picker_pagination_test.dart
?? windows_application/test/features/discounts/discount_variant_repository_test.dart
?? windows_application/test/features/discounts/discount_variant_targets_test.dart
```

Regression first run: exit 1, 46 passed / 6 failed, 539 assertions, 564.69s. All Discount and Plan 1 suites passed; six PreAuthFinancialConcurrencyTest payment cases hit invalid test cash-drawer configuration before their intended scenario. Fixed only makeOrder fixture setup to use Finance-mapped cash drawer and one shared open shift. Existing race/idempotency/usage assertions and prior dirty final-use fixture remain intact. No production payment lock or guard was changed.

Foundations/POS/authorization/receipt/refund group final run: exit 1, 66 passed / 1 failed, 673 assertions, 335.38s. All 11 foundation tests (including strengthened real legacy payment/usage rehearsal and native constraint tests), BranchLifecycleAndCafeConfigurationTest, PosApiSmokeTest, PosMenuSyncApiTest, ReceiptTemplateConfigurationTest, RefundAccountingApiTest, RefundConcurrencyApiTest, OrderRefundableBalanceApiTest and SnapshotAwarePosOrderApiTest passed. Three of four Phase12AuthorizationApiTest cases passed. The remaining pre-existing assertion at line 25 expects only finance.transactions.view, but unchanged FinanceAccess::permissionsFor supplies the fixed cashier workflow baseline plus that explicit grant (19 entries). The initial denial and later explicit-grant API assertions passed; only obsolete whole-array equality failed. Finance production code and this test are unchanged (git diff --exit-code for those three files returned 0). No assertion was weakened and no unrelated Finance contract was redesigned.

Scoped Pint: first 11-file check exit 1 with four issues. Scoped formatter exit 0; final standard container Pint --test over 11 foundation-owned PHP files (including the repaired PreAuth fixture) PASS, exit 0. Shared routes/api.php also checked: standard Pint exit 1 for fully_qualified_strict_types and ordered_imports, reproduced on a temporary HEAD copy with the same two findings (exit 1). Unrelated route import/qualified-name rewrites introduced by formatter were removed; only the settings import/routes and preserved original variant routes remain. A temporary line-ending finding after the edit was normalized to LF. No lint rule/profile was weakened. Native PHP syntax checks on all 12 touched PHP files: final exit 0, no syntax errors. Initial sandbox native PHP attempt was denied before execution and is not counted as a successful syntax check.

Final network identity query also succeeded (exit 0): accept-postgres / 172.28.0.2:5432, postgres user, cafe_system_618_testing, PostgreSQL 16.13. Container identity is authoritative; its private IP may change on restart.

A final narrow authorization review identified that User::tenantRole uses a single-column relationship. Settings authorization now additionally verifies role tenant ownership (without changing legacy Discount authorization or User itself), and the existing isolation test includes a malformed foreign-role reference. This final guard requires the concluding settings API rerun below. Syntax/Pint for those two changed files passed, exit 0.

Final Discount/Plan 1/financial concurrency group: **exit 0, 52 passed / 580 assertions, 555.95s**. Filter: DiscountManagementApiTest|DiscountV1ContractTest|DiscountV2BackendTest|DiscountSecurityHardeningTest|DiscountRuntimeEligibilityTest|DiscountVariantBackendTest|DiscountVariantConcurrencyTest|PreAuthFinancialConcurrencyTest. All eleven financial contention/idempotency/refund/usage/migration cases passed after test fixture repair, with production payment locks unchanged.

## Final closure and remaining limitations

D2-01 through D2-04 VERIFIED and checked only for this bounded scope. D2-05 through D2-19 remain unchecked; Plan 2 is not complete, engineReady=false, automaticEnabled cannot be enabled. No operational migration, deployment, commit or Flutter build.

| Final check | Observed result | Exit |
|---|---|---|
| Settings API after final foreign-role guard | 7 passed / 98 assertions, 26.29s | 0 |
| Foundation + POS/configuration/authorization/receipt/refund group | 66 passed / 1 pre-existing Finance array assertion failure, 673 assertions, 335.38s; all 4 foundation schema/race/rehearsal tests passed | 1 |
| Discount/Plan 1/financial PostgreSQL concurrency group after fixture repair | 52 passed / 580 assertions, 555.95s | 0 |
| Standard scoped Pint, 11 foundation files including repaired concurrency fixture | PASS; final two authorization files also rechecked/formatted successfully | 0 |
| Standard Pint shared routes/api.php | Same two pre-existing findings as HEAD temporary copy | 1 |
| PHP syntax, all 12 touched PHP files | No syntax errors; final two changed files rechecked | 0 |
| git diff --check | No whitespace errors across preserved worktree | 0 |
| Full Laravel suite / Flutter tests-builds | Not run, unverified | not run |

Combined foundation/POS/authorization/receipt/refund filter: DiscountSettingsApiTest|DiscountSettingsFoundationTest|PosApiSmokeTest|SnapshotAwarePosOrderApiTest|PosMenuSyncApiTest|Phase12AuthorizationApiTest|BranchLifecycleAndCafeConfigurationTest|ReceiptTemplateConfigurationTest|RefundAccountingApiTest|RefundConcurrencyApiTest|OrderRefundableBalanceApiTest.

Known independent verification debt: Phase12AuthorizationApiTest line 25 expects an obsolete cashier permission array (the server's fixed cashier baseline predates this phase). Kept untouched. Shared route Pint fully_qualified_strict_types / ordered_imports also predate this phase and were preserved rather than broad-formatting unrelated routes. These are reported as failures, not green checks. They do not invalidate the observed foundation API/schema/authorization/race proof; they remain part of the later full-regression gate before runtime activation.

The next phase can implement D2-05 through D2-09 with the frozen contract, nullable schema and Plan 1 matcher; it must complete exact allocation/discovery/explicit intent, mutation replay, tender-aware fresh quotes and policy-specific usage plus lock-cycle/race tests before engine/client activation. The current single-consumption guard must be changed only in that later engine/payment phase. Roll forward if future multi-policy usages exist; never restore old uniqueness by deleting history.

A first documentation status update attempt exited 1 at a Unicode marker assertion before writing any file; exact apply_patch and ASCII-only status append succeeded.
