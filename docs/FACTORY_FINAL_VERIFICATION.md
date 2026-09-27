# Factory separation verification

Status: phases 3 → 3b → 4 → 5 → 6 → 7 → 8 → 10 → 9 are complete (2026-09-27). User subsequently authorized a push after verifying cash drawer closing. The complete suites retain pre-existing failures; comparison with clean phase-2 commit 583de91 found zero new failing cases. See SHIFT_CLOSE_VERIFICATION.md for the subsequently verified closing fixes. Full-suite counts below describe the factory checkpoint before that follow-up.

## Implemented behavior

| Phase | Result |
|---|---|
| 3 | Private factory materials, immutable ownership, guarded inventory references and posting, quantity/WAC/value in shared material screens. |
| 3b | Private suppliers/customers/categories/catalogs/groups, scoped imports, owner scope selector, factory document prefixes. |
| 4 | Shared material/purchase screens under manufacturing routes, locked factory selection, material production batches with pagination. |
| 5 | Factory financial reads/writes exclude global NULL rows; independent factory drawer works without shifts. |
| 6 | Manufacturing requires factory branches; warehouse boundaries enforced in both directions; factory POS/shift rejected. |
| 7 | Private immutable recipes, scoped production/reports, searchable paginated ingredient picker retaining selected rows. |
| 8 | Independent default_warehouse_id and factory warehouse type; factory POS pointer NULL; cafe defaults preserved. |
| 10 | Owner-managed internal counterparties, separate sale/purchase/settlement documents, consolidated internal exclusion and reconciliation. |
| 9 | Full suites and independent baseline comparison, cashier/cafe regression, live Windows factory flows, idempotent local backfills, manual acceptance checklist and Windows Release. |

## Local migrations and backfills

Applied `2026_10_06_000001` through `000007`: material ownership; master ownership; recipe branch; required recipe branch; default factory warehouse; internal parties; scoped customer imports/group uniqueness. Existing-data migrations do not delete business records. The warehouse migration stores old types for rollback; scoped group rollback refuses name conflicts rather than deleting data.

| Applied migration under backend/database/migrations | Change |
|---|---|
| 2026_10_06_000001_add_inventory_item_owner_branch.php | Material owner branch |
| 2026_10_06_000002_add_master_data_owner_branches.php | Supplier/customer/category/catalog/group owners |
| 2026_10_06_000003_add_manufacturing_recipe_branch.php | Recipe branch before backfill |
| 2026_10_06_000004_require_manufacturing_recipe_branch.php | Required recipe branch after backfill |
| 2026_10_06_000005_decouple_factory_default_warehouse.php | Independent default warehouse, reversible warehouse-type snapshot, factory POS pointer cleared |
| 2026_10_06_000006_add_internal_counterparties.php | Internal party flags and counterpart branches |
| 2026_10_06_000007_scope_customer_imports_and_group_names.php | Import ownership and scoped group-name uniqueness |

- Item ownership: dry-run 17 candidates / zero conflicts, apply 17, repeat zero.
- Recipe branches: dry-run 4 / zero conflicts, apply 4, repeat zero.
- Master inspection: zero relocation candidates. Private catalogs: six copies for factory 5, repeat zero.
- Warehouse preview: factory 5 / warehouse 1, then apply.
- Internal counterparties: five new records, repeat zero (four factory customers and one shared cafe supplier representing factory 5).
- Backups: `backups/cafe_system_618_pre_factory_phase1_20260926_142157.dump` and `backups/cafe_system_618_pre_phase3_20260926_171438.dump`.

Final phase-9 repeat on local `cafe_system_618` (not the testing databases):

```text
factory:backfill-items             Candidates: 0; conflicts: 0. Dry run; no data changed.
factory:backfill-items --apply     Candidates: 0; conflicts: 0. Ownership assignments applied.
factory:backfill-recipes           Candidates: 0; conflicts: 0.
factory:backfill-recipes --apply   Candidates: 0; conflicts: 0.
factory:setup-catalogs             New records: 0. Dry run.
factory:setup-internal-parties     Candidates: 0.
migrate:status                    All seven factory migrations Ran.
```

Both dump headers were verified as PostgreSQL PGDMP. No manual reset of the local business database was performed; test fixtures use only `cafe_system_618_testing` and `cafe_system_618_testing_migrations`.

## Implementation decisions

Cafe master data keeps NULL ownership, so the supplier representing a factory is shared by cafes; reconciliation filters each cafe's documents. Private catalog codes use f{branch}_ and document numbers F{branch}-. New factory setup creates independent catalogs once and repairs a missing default warehouse pointer. Factory managers' branch omission resolves to an assigned factory; owner omission retains the cafe master scope, with explicit factory/all inventory read options. No price lists, automatic purchase drafts, paired settlement or factory/cafe inventory transfers were added (phase 11 remains cancelled).

Item and recipe ownership cannot be moved by editing; factories use separate records. Branch-specific financial reports retain internal documents; owner consolidation excludes them by default. The includeInternal query uses numeric 1/0 to satisfy Laravel boolean validation. Shared Flutter forms use explicit manufacturing route scopes and reload when the owner's data scope changes. These choices preserve decisions 1–8.

## Final verification results

- Flutter full final suite: 1516 passed, 23 failed. Clean phase-2 archive: 1512 passed, identical 23 failures by name. Existing failures include fixture/provider setup, auth storage assumptions, localization/goldens and pre-existing POS/payment tests.
- Final affected Flutter tests: 19 passed, zero failed. Analyzer: zero errors/warnings, 28 existing info diagnostics.
- Live compiled Windows factory-manager UI: passed through all factory module tabs without POS/shift surfaces.
- Live production → factory sale → independent cafe purchase/receipt → supplier payment/customer collection: passed. Each new invoice has 0.00 remaining; cafe stock increased once, factory stock did not change at cafe receipt. Existing demo debts were preserved; reconciliation difference returned to its starting value.
- Final Windows Release rebuild passed (107.1s). Release/data/app.so rebuilt at 2026-09-27 00:58 local; deploy the entire Release folder with the executable.
- Targeted backend run before the final full rerun: 20 passed, zero failed, 536 assertions, including cashier shift/order/discount/payment/close, manager permissions, scoped import/group names, internal-report exclusion and foreign customer-statement rejection.
- Final full backend: **970 passed, 36 failed, one skipped, 9952 assertions, 1553.86s**. Clean phase-2 baseline: **959 passed, 37 failed, one skipped, 10020 assertions, 1469.62s**. All 36 final failure names occur in the baseline: **zero new failures**, one corrected canonical finance route permission-map failure.
- `DiscountRuntimeEligibilityTest`: three failures in both baseline and final, with the same HTTP 422 / NO_OPEN_SHIFT / "The order shift has no valid cash drawer." These are pre-existing fixture failures. The new cafe cashier regression with a configured branch drawer passes the complete shift/order/discount/payment/close cycle.
- Skipped in both runs: optional 100k customer-search query-plan benchmark. Every residual backend/Flutter case and its observed cause is listed in [FACTORY_KNOWN_TEST_FAILURES.md](FACTORY_KNOWN_TEST_FAILURES.md).
- Reloaded the final HTTP backend: factory sales-material lookup HTTP 200 with 17 records and no POS shift; foreign cafe customer statement HTTP 404 for factory manager.
- Initial backend runs (909/87 and 925/81) were diagnostic. The latter exposed a new PostgreSQL GROUP BY error in migration 000007 rollback, plus downstream fixture contamination. The grouped query now selects only grouping columns; the full rerun verifies the fix. Scoped-import coverage also verifies duplicate group names cause a safe rollback refusal without deleting records or dropping ownership.
- Old factory POS/shared-material purchase fixtures were updated to the approved separation: direct factory sales, defaultWarehouseId, private material/supplier records and rejected cafe warehouse assignments. Stock, WAC, receipt idempotency and cafe cashier checks remain enforced.
- A vendor-symlink baseline was discarded because Composer resolved current application classes. Valid baseline and final runs use independent application/vendor copies, identical dependencies and sequential execution, with no concurrent docker exec.

Raw evidence under `E:/cafe6.18/docs`: `FACTORY_BACKEND_TEST_RESULTS_VERIFIED.txt`, `FACTORY_BACKEND_BASELINE_RESULTS_VALID.txt`, `FACTORY_FLUTTER_TEST_RESULTS_FINAL.txt`, `FACTORY_FLUTTER_BASELINE_RESULTS.txt`, `FACTORY_FLUTTER_ANALYZE_RESULTS.txt`, `FACTORY_BACKEND_LAST_FOCUSED_RESULTS.txt`, `FACTORY_FLUTTER_FINAL_AFFECTED_RESULTS.txt`, `FACTORY_LIVE_UI_RESULTS.txt`, `FACTORY_LIVE_CYCLE_RESULTS.txt`, `FACTORY_WINDOWS_RELEASE_RESULTS_FINAL.txt`.

Windows Release: `E:/cafe6.18/cafe-system/windows_application/build/windows/x64/runner/Release`. Ship this entire folder; its fresh `data/app.so` was built at 2026-09-27 00:58:20 local (16,597,904 bytes), even though the cached runner stub retains an older timestamp.

## Acceptance and limits

Manual acceptance instructions: `docs/FACTORY_ACCEPTANCE_CHECKLIST.md`. Automated API/UI checks do not claim every manual checklist step was manually exercised. Live acceptance creates uniquely named local demo documents/materials/production records. Interrupted test attempts also left demo drafts and unmatched documents; they were preserved rather than deleted or silently settled.

`windows_application/pubspec.yaml` and `pubspec.lock` already contain integration_test from committed phase 2 (583de91); they have no new changes in phases 3–10. Golden failure artifacts, raw diagnostic files and backups are excluded from the proposed commit.

No full manual walkthrough of all 13 checklist steps is claimed. Pre-existing test failures were documented rather than expanding this factory task into unrelated auth, fixture, golden and finance repairs. Phase 11 automation remains cancelled by the approved decision. No deployment or push was requested.

The proposed single commit is listed explicitly in [FACTORY_COMMIT_FILES.md](FACTORY_COMMIT_FILES.md). Per FACTORY_MASTER_PROMPT_RUN_ALL.md, it will not be committed before approval of that list. External progress/review documents at E:/cafe6.18/docs were updated separately because they are outside this Git repository.
