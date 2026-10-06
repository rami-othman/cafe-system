- 2026-10-05 current-source continuation: actual Web pointer/text acceptance proved targeted Code create/edit/reopen, isolated Automatic create/conversion/discovery/disjoint/cap/suppression/undo, supported cash/card, stale quote reconfirmation, committed-but-lost response recovery, configured Manual zero-balance, hold/resume/hold, and paid snapshot/replay effects. Fixed early-cart staging before a known missing-shift failure (19 regression tests) and the history Print order placeholder: stored receipt preview/reprint now uses the selected order/branch and discards stale receipt responses (25 regression tests). Acceptance fixtures now publish categorized products with a nonselected sibling variant and a Finance-mapped Card. Backend focused:70 tests/1203 assertions; Flutter focused:184 tests; Pint7files passed. Final suites/builds/analysis and per-D2 gaps are recorded in ../docs/verification/discount_plan2_acceptance_2026-10-05_ar.md. Native Release launches, but Windows text automation cannot authenticate; physical printing remains unproved. D2-11/13–16/19 remain open; no public activation, deployment, commit or push.

- Earlier 2026-10-05 ad-hoc removal phase: Removed free/ad-hoc POS entry for every role and rejected new/old free creation and outstanding reviews server-side. Saved legacy read/remove/settle and completed replay remain supported. Historical focused results (70 Flutter;38 Backend/581 assertions;3 Daily Report/Tax) are phase records, not the current full-suite outcome. Cleanup removed only the temporary HEAD export/ZIP and added exact ignores. Evidence: ../docs/verification/discount_ad_hoc_removal_2026-10-05.md.

- Production UI patch (2026-09-27, commit 2d34328): restored factory Settings/logout access and removed the owner data-scope dropdown requested by the user. Flutter Web release built for /cafe18/ with existing production API https://46.224.139.32/api/v1; factory sidebar tests: 3 passed; analyzer: 29 existing infos, no errors/warnings. Production deployment complete: live HTTP index and main.dart.js served successfully; main.dart.js SHA-256 0ed3d6a5e953cee313cd13f8958fc12f0841056fce15d9fc2ff6f105203634b6 matches the local release. Previous web root preserved at /var/www/cafe18-backup-logout-2d34328. GitHub push was rejected by automatic approval review; no push was made. Backend and database unchanged.

- Factory logout access (2026-09-27): restored the shared Settings destination for factory users and factory branches; Settings already provides confirmed session logout. Updated factory sidebar expectations. This enables switching to a cafe account for POS.

- Historical shift close (2026-09-27): date selection now reloads a versioned branch-timezone preview before counting. Historical cash and bar counts require an explicit recorded-period/current basis. Closing seals an immutable prior-period snapshot, carries later source links into one continuation, preserves journals and inventory movements, and performs any actual cash transfer at execution time. Identical retries are idempotent; stale previews, ambiguous/incomplete inventory history, incompatible legacy partial receipts, and multiple mandatory bar templates are blocked with actionable errors. PostgreSQL table locks serialize this rare recovery path (five-second timeout); production rollout should account for tenant-wide contention. No real shift was closed as an acceptance test. Local additive migration is already applied. Verification: 60 backend tests / 540 assertions; 2 concurrency tests / 12 assertions; 12 Flutter shift tests. Full analyzer: 34 informational lint notices, no errors or warnings. Windows Debug build succeeded. Also corrected a misplaced active-branch getter in the sales screen that blocked compilation. Production feature-toggle rollout and user operational acceptance remain pending. Plan: ../docs/finance/HISTORICAL_SHIFT_CLOSE_PLAN_AR.md; source contract: ../docs/finance/HISTORICAL_SHIFT_CLOSE_SOURCE_MAP.md.
- 2026-09-27: Recipe ingredient selection now has an editable searchable/filterable DropdownMenu displaying only the material name, with a clear Arabic search hint. Existing server search/pagination remains available and its field is labelled بحث عن مادة. No stock quantities, units, costs or recipe payloads changed. Existing recipe controller/model checks: 5 passed. Full analysis has no errors/warnings and 28 existing info diagnostics.

- 2026-09-27: Simplified factory sidebar for factory_manager and selected factory context to Manufacturing, Purchases, Sales and Supplier Documents only, respecting each existing capability. Removed finance overview, extra module links and settings from this factory sidebar. Supplier Documents opens the existing suppliers workspace; manufacturing retains its internal tabs. Updated active destination selection for factory trading routes while retaining cafe finance highlighting. No data or backend permissions changed. Focused factory sidebar/manufacturing-route tests: 5 passed. Affected-file analysis: no issues. Full analysis: no errors/warnings, 28 existing info diagnostics.

- Factory separation, Phase 2 verification (2026-09-26): fixed a backend gap found during verification — InventoryAccess had no factory_manager entry at all, so every inventory call (materials list, warehouses, stock counts) 403'd for the role the Manufacturing "materials"/"الجرد" tabs actually run as; added factory_manager to InventoryAccess::ROLE_PERMISSIONS (view/items.manage/counts.view+create+post/adjustments.create — no locations.manage, no transfers.*). Confirmed server-side (not just UI) rejection of a stock count against a warehouse outside the factory branch via FactoryWarehouseScope — verified by a new test creating a count against the cafe branch's warehouse (422) and the factory's own (201). Renamed the factory_manager sidebar's home entry from "التصنيع" (shared with Owner's entry) to "المعمل", and the Manufacturing overview page header from "التصنيع" to "نظرة عامة", per explicit request. Added a real end-to-end check (new `integration_test/factory_manager_live_flow_test.dart`, using the `integration_test` package added as a dev dependency — plain `flutter test` fakes all HTTP, so it cannot exercise a live backend) that runs the actual compiled Windows app against the live local backend: logs in as the seeded `factory.demo@cafe618.test` demo user, and clicks through sidebar → materials → recipes → production → stock counts → purchases → sales → finance → reports, asserting each screen's real header loads and no cafe-only surface (POS, dashboard, shift badge) is reachable. Ran via `flutter test integration_test/factory_manager_live_flow_test.dart -d windows`: passed. Backend regression after the InventoryAccess fix: FactoryManagerRoleTest (8 passed) + ManufacturingCoreFlowTest (24 passed) + InventoryCenterApiTest + InventoryItemDetailsApiTest — 72 passed / 1236 assertions total. Flutter analyze: 0 errors/warnings, same 28 pre-existing infos. Windows Release build succeeded (`build\windows\x64\runner\Release\windows_application.exe`). Not covered: the full `php artisan test` suite (still unreliable in this environment from unrelated concurrency issues seen earlier this session) and full `flutter test` regression (deferred, as instructed, to the final acceptance phase). Report context: this session's Phase 1 (factory_manager role) and Phase 2 (factory context/shell/sidebar) chat reports.

- Simple factory consolidated report (2026-09-26): documented all six phases, current demo seed data, cost and gross-margin policy, per-run validation results, usage steps, manual acceptance and remaining accounting/transfer UI limits. No application code or data changed by this documentation task. Report: E:/cafe6.18/docs/SIMPLE_FACTORY_FINAL_REPORT_2026-09-26.md.

- Simple factory branch, Phase 6 (2026-09-26): reused existing counts with factory default warehouse and server branch/warehouse validation for create/list. Verified count approval, variance and duplicate-post rejection. User confirmed local catalogue is empty and requested seeder data. ManufacturingDemoSeeder now provisions a dedicated factory branch/private warehouse, 17 assigned items, 4 recipes and 12 opening movements transactionally; compatible records are reused, production environments rejected. Ran twice locally without duplicate stock/recipes. Read-only local cake preview: 4 units, no shortage/conversion issue, material batch 255998.80 / unit 63999.70. Final focused backend cycle/catalogue/count: 3 passed / 284 assertions; seeder: 1 / 10; earlier inventory regression: 31 / 606. Flutter counts/warehouse: 10 passed; analyze has 28 infos, no errors/warnings; Windows Release build passed. Local seed data is synthetic; manual UI acceptance and real operational setup remain pending. Report: E:/cafe6.18/docs/SIMPLE_FACTORY_PHASE_6_2026-09-26.md.

- Simple factory branch, Phase 5 (2026-09-26): existing sales form uses factory warehouse-assigned inventory items directly, avoiding a second recipe consumption. Backend enforces this at create/update/preview/post. Sales center follows active branch with stale-response protection. Posted invoice details expose ex-tax gross margin using immutable movement costs and posted returns; operating costs remain managerial/memo-only, not net profit. Corrected planned/actual sales cost array merge. Backend manufacturing/sales/pricing/returns: 53 passed / 777 assertions. Focused Flutter sales: 27 passed. Full sales run has two existing payment-dialog fixture failures (missing cash-source-options response), recorded separately. Real user inventory unchanged; runtime source reconciliation and operational acceptance remain pending. Report: E:/cafe6.18/docs/SIMPLE_FACTORY_PHASE_5_2026-09-26.md.

# CURRENT AUTHORITATIVE STATUS

- Menu Pricing V1 Flutter completion/remediation (2026-09-28): completed Flutter-only context isolation (drafts/reviews/overview are scoped to menu + branch + channel), explicit discard confirmation and registered unsaved-navigation guard, request/draft/action revision protection, single-flight Apply, stored-adjustment recovery, exact input validation, rounding presets/custom step/null no-rounding wire value, category browsing, full paginated menu selection, review detail/summary/warnings/acknowledgements, localized safe copy, and Review & Publish handoff. Backend, migrations, databases, POS, tax, and publication behavior were not changed. Automated verification: normal localization generation; focused models/Cubit suite (10 tests) passed; focused pricing analysis has no errors, warnings, or informational findings. Manual acceptance still pending: Windows build, English/Arabic constrained-window review scrolling, live owner/manager/employee route behavior, real timeout recovery, and Review & Publish handoff against a running backend. No Windows build or live POS acceptance is claimed.

- Simple factory branch, Phase 4 (2026-09-26): production preview uses selected warehouse WAC and available stock net of reservations; factory warehouse selection excludes shared/foreign warehouses. Production validates recipe/output assignments, preserves atomic consumption/output and idempotency, records zero-consumption overrides, rejects unrelated consumption, fixes output base-unit cost/batch quantities and reversal value. Existing completion form accepts optional managerial labor/electricity/other costs; result/detail show material unit cost and full managerial batch/unit cost. These additional costs remain memo-only and do not create payments/journals or capitalize inventory. Production history is scoped by active branch. Backend combined purchasing/manufacturing suite: 66 passed / 927 assertions; reserved-stock/branch scenario extension passed separately (19 assertions). Flutter manufacturing/navigation: 34 passed, warehouse widgets: 5 passed. Windows Release build succeeded. No real user inventory or production documents changed. Operational acceptance and any historical non-base-unit batch audit remain pending. Report: E:/cafe6.18/docs/SIMPLE_FACTORY_PHASE_4_2026-09-26.md.

- Simple factory branch, Phase 3 (2026-09-26): existing purchase/receipt flow now enforces factory-owned active warehouses in API and form selection; manufacturing materials opens the existing purchase form. Receipt retry reuses draft IDs and idempotency keys during the controller session, handles uncertain create/post responses and allows correction after rejected creation. Existing material assignment API reused without duplicate items or moving old balances. Backend purchasing/cost regression: 45 passed, 534 assertions. Flutter relevant suites: 20 passed across initial run and added correction test. Full analyze: 0 errors/warnings, 33 pre-existing infos. Real user stock and purchases were not modified; runtime data-source matching and operational acceptance remain pending. Report: E:/cafe6.18/docs/SIMPLE_FACTORY_PHASE_3_2026-09-26.md.

- Simple factory branch, Phase 2 (2026-09-26): added cafe/factory branch type in existing branch settings/API, one factory warehouse using current provisioning, operational branch default warehouse metadata, factory administrative sidebar links to existing purchases/sales gated by server capabilities, selected-branch defaults for new purchase/sales forms and manufacturing warehouse selection. Fixed branch creation response to refresh after warehouse binding. Branch and user permissions remain existing policy; no new employee role or automatic finance grants. Backend branch lifecycle suite: 8 passed / 99 assertions. Flutter focused navigation, purchasing, configuration, and materials suites: 42 passed. Full analysis: 33 existing info notices, no errors/warnings. Applied only additive branch_type migration locally; no live factory branch/user assignments or inventory writes. User confirms device inventory exists, but inspected local backend has no material/purchase rows; source/session reconciliation remains outstanding. Details: workspace docs/SIMPLE_FACTORY_PHASE_2_2026-09-26.md.

- Simple factory branch plan, Phase 1 (2026-09-26): fixed Manufacturing materials filtering after pagination by adding optional multi-type filtering to the shared inventory index; added page navigation and visible retryable load errors. Materials now pass the selected operational branch, and InventoryRepository.items forwards its existing branchId argument. No runtime records were created or changed. Local Docker cafe_system_618 read-only audit found zero inventory items, zero manufacturing recipes, and no warehouses linked to its four branches; equivalence with the user's purchasing environment remains unconfirmed. Backend InventoryItemDetailsApiTest: 10 passed, 120 assertions. Focused Flutter materials, inventory Cubit, and recipe Cubit suites: 10 passed. Full flutter analyze ran and reported 34 info notices in other files; edited-file analysis is recorded in docs/SIMPLE_FACTORY_PHASE_1_2026-09-26.md. Six-phase scope is in docs/SIMPLE_FACTORY_BRANCH_PLAN_2026-09-26.md at workspace root. Next: confirm operational data source, then configure the factory branch and its single warehouse using existing modules.

- Flutter Manufacturing Phases 1-7 (full module): Phase 1 shipped the shell + Overview only (see prior entry text, superseded by this one). Phases 2-7 add Materials, Recipes, Production (preview/draft/complete/history/details/reversal), Conversion, and Reports, all reading real backend contracts (`ManufacturingRecipeController`/`Service`, `ManufacturingProductionController`/`Service`, `ManufacturingConversionController`, `ManufacturingReportController`/`Service`) — no client-side recalculation of cost, WAC, conversions, or reversibility. **Models**: `manufacturing_recipe_models.dart`, `manufacturing_production_models.dart`, `manufacturing_conversion_models.dart`, `manufacturing_report_models.dart` (all null-safe via `json_helpers.dart`, money/qty kept as `String`). **Repository**: `ManufacturingRepository` extended with recipes (list/get/create/update/status/duplicate), production (preview/drafts/complete/list/get/reverse), conversion (create/get), reports — Materials/stock-receipts intentionally have no methods here and go through the existing `InventoryRepository`/`InventoryCubit` instead (`ManufacturingMaterialsScreen` reuses Inventory's own `ItemTable`/`ItemFilters`/`WarehouseDropdown`; `ManufacturingStockReceiptScreen` posts a real `stock_in` movement via `InventoryRepository.postMovement`, no AP/invoice created). **Cubits** (one per screen-cluster, no giant cubit): `ManufacturingRecipeCubit`, `ManufacturingProductionCubit`, `ManufacturingConversionCubit`, `ManufacturingReportsCubit`, alongside the existing Phase-1 `ManufacturingCubit` (Overview only). **Idempotency**: `ManufacturingProductionCubit`/`ManufacturingConversionCubit` mint one key per user-initiated mutation (draft creation, completion, reversal, conversion) at the start of that action, fingerprinted on its real inputs, and reuse it across retries of the same action — mirroring `PosCubit`'s `_operationKey` pattern; a new key is minted only once the underlying request actually changes. **Reversal**: `ManufacturingProductionDetailsScreen` calls the real reverse endpoint and renders `ApiException.message` verbatim — the backend already maps `ManufacturingDomainException` (`PRODUCTION_NOT_REVERSIBLE`, etc.) to Arabic via `DomainErrorMessages::forCode()` before the response ever reaches Flutter, so no second client-side mapping table was needed; a failed reversal never mutates the loaded order. **Batch/expiry**: rendered exactly as `ManufacturingProductionOrder.batch`/`ManufacturingExpiringBatch` return it; audited `ManufacturingReportService::overview()`'s "expiring" list and `ManufacturingProductionService::serializeOrder()` and found both already read `manufacturing_batches.remaining_quantity` correctly (the previously-flagged bug reading `actual_quantity` instead was not found in the current backend — treat as resolved, not re-broken). **Routes**: `/manufacturing/{materials,materials/new,materials/:itemId,materials/:itemId/edit,stock-receipts/new,recipes,recipes/new,recipes/:recipeId,recipes/:recipeId/edit,production,production/new,production/new/:recipeId,production/complete/:draftId,production/result/:id,production/:id,conversions/new,conversions/:id,reports}` added to `app_router.dart`; `ManufacturingNavigationBar`'s five tabs are all enabled now (no disabled placeholders left). **Permissions**: centralized into one new `_manufacturingAccessRedirect` route guard (owner/manager only, one `// TODO` for a real backend capability once `AuthUser` exposes one) applied to every Manufacturing `GoRoute`, instead of scattering the check per screen; the sidebar's existing Phase-1 gate is unchanged. **Two authorized Inventory fixes** (both proven integration gaps blocking Manufacturing, not scope creep): `item_form_screen.dart`'s item-type dropdown was missing `semi_finished_good` (added, per task instruction); `inventory_item_widgets.dart`'s `inventoryItemTypeLabel()` switch was *also* missing `semi_finished_good` (fell back to "أخرى") — fixed as the one additional minimal, explicitly-flagged gap, since Manufacturing's Materials screen reuses that exact widget. Tests: 9 Phase-1 tests unchanged, plus 20 new — recipe/production/conversion/report model parsing (including a missing-cost line, a conversion-issue preview row, a reversed order, an empty reports response), `ManufacturingRecipeCubit`/`ManufacturingProductionCubit` success/error transitions, idempotency-key-reuse-on-retry and new-key-on-changed-input for `createDraft`, a `PRODUCTION_NOT_REVERSIBLE` conflict test asserting the exact backend Arabic message and no optimistic state mutation, a `semi_finished_good` label-mapping regression test, and a Manufacturing route-constant/path-builder contract test — 29/29 passing. `flutter analyze`: 0 errors (34 pre-existing/informational lints, 5 of them newly introduced `use_null_aware_elements` info hints in `manufacturing_production_cubit.dart`, no warnings/errors). Not run: an actual Windows desktop build/manual click-through (no Windows GUI/build tooling available in this environment) — verification relied on `flutter analyze` + the full focused test suite + direct reading of every touched backend controller/service/request/exception class against the Flutter code that calls it.

- A2 (shift / cash drawer lifecycle) — FINAL, branch `fix/a2-shift-drawer-lifecycle` from main `e21e46f`, uncommitted for review, not deployed. Nothing from `wip/a2-before-main-merge-2026-09-24` (cc5dc4b) was reused: that commit contains only manufacturing work, no A2 code. **Architecture**: one canonical `App\Services\ShiftDrawerReadinessService` defines drawer/destination/float validity (POS drawer = active `kind=cash`,`type=cash_drawer` location of the tenant and branch with an active account; destination = active cash location of the same tenant, global or same branch, never the drawer; float ≥ 0) and is used by shift open, `BranchController::update`, the branch payload (`shiftDrawerReadiness`), the new `GET /api/v1/shifts/readiness?branchId=`, `ShiftCloseTransferService` and the legacy adoption command; `BranchPosCashDrawer` now delegates to it. New `App\Services\ShiftCloseService` holds the one close algorithm (lock → open check → required bar checks → `ShiftCashSummaryService` → `ShiftCloseTransferService` → one shift update) used by both the manual endpoint and `AutomaticShiftCloseService`. Messages live in `backend/lang/{ar,en}/shifts.php` (Arabic default, `X-App-Locale: en` gives English). **One physical drawer = one open shift**: `ShiftController::open` no longer locks the tenant row; it locks the branch (configuration) row and only the drawer location row (`FOR UPDATE OF locations`), validates readiness, rejects an existing open shift on the drawer, requires `openingCash` == posted location-specific drawer ledger (message states the ledger figure), takes a tenant-scoped advisory lock only for shift numbering, inserts, and converts a PostgreSQL 23505 on `shifts_one_open_per_location` into the same localized `branchId` validation error (no SQL leaks). Different drawers open concurrently. **Snapshot**: the shift stores `financial_location_id`, `close_destination_financial_location_id`, `closing_float_amount` at open; branch edits never touch an open shift. A branch without a valid destination can no longer open shifts; `FinancialSetupService::ensureDefaultShiftCloseDestination` sets the tenant's global `MAIN-SAFE` as a provisioning default only for branches whose destination is NULL (tenant onboarding/`ensureForTenant` and branch creation — never on branch update, never replacing an explicit choice). **Close transfer / float**: close moves `counted − closing float` from drawer to the snapshotted destination as exactly one cash transfer (key `shift-close-transfer:{shiftId}`, `shift_id`, `actor_type` user/system), after requiring counted == expected (no variance policy exists) and counted == drawer ledger; a zero amount closes without a transfer; the float stays in the drawer as the next shift's opening custody. Identical manual retries return the stored result; automatic retries are no-ops. **Manual vs automatic**: manual stores `closing_cash` and `close_type=manual`; automatic uses expected cash as the ledger check, keeps `closing_cash=NULL` (no fabricated count), `close_type=automatic`, `actor_type=system`. `App\Support\ShiftClosePresentation` makes API/history/report distinguish `manual` (counted), `automatic` (uncounted; difference null) and `legacy_reconcile` (no expected/actual/difference/transfer); history `closedWithDifference` and the reports-overview "critical cash difference" exception only consider counted manual closes. **Historical overlap reconciliation**: `php artisan shifts:detect-overlaps [--tenant=]` (read-only) and `php artisan shifts:reconcile-overlap {tenantId} {financialLocationId} --confirmed-cash= --reason= --actor= [--dry-run|--apply]` (`ShiftOverlapReconciliationService`, dry-run default): locks the drawer location and all overlapping open shifts, requires ≥ 2, requires confirmed cash == posted drawer ledger, refuses while any linked non-deleted order is not `paid/cancelled/refunded`, then closes all of them at one timestamp as `legacy_reconcile` with `closing_cash`/`close_transfer_id` NULL, no cash transfer, no order/payment/journal/stock/voucher change, an appended note, and `activity_logs` rows (`shift.legacy_overlap_reconciled` with tenant/branch/drawer/shift ids/original rows/ledger/confirmed cash/reason/actor/timestamp, plus `shift.legacy_reconciled` per shift; `OperationalAuditService::recordContext` gained an optional `$before`). Afterwards the one-open-shift migration can be (re)applied and the next shift opens normally with `openingCash` = full drawer ledger (one clean custody period; historical cash is never split). **Legacy config adoption**: `php artisan shifts:adopt-close-config {tenantId} {shiftId} --reason= --actor= [--dry-run|--apply]` copies only the validated current branch destination/float onto a single open legacy shift whose destination is NULL (no overlap, drawer still valid), creates no financial entry and writes `shift.close_configuration_adopted` to `activity_logs`. **Flutter**: shift open/close errors now surface the server's localized field reason (drawer not configured, destination missing, drawer already open, opening count ≠ ledger) instead of the generic message; history/report show close type (`ShiftCloseMode`), render uncounted closes as "—"/"غير معدود" and exclude them from difference totals; strings in `ShiftStrings`. No new screens. **Migrations**: none added or modified. **Deployment/rollback**: deploy code; run `shifts:detect-overlaps`; before deploy verify every active branch has a valid close destination (`GET /api/v1/shifts/readiness`) or configure one, otherwise new shifts on that branch are refused; legacy open shifts with NULL destination need `shifts:adopt-close-config` before they can close. Rolling back code needs no schema rollback. Runbook: `docs/SHIFT_DRAWER_OPERATIONS.md`. **Tests** (Docker PHP 8.4, PostgreSQL 16): new `ShiftDrawerLifecycleTest` 26/26 (scenarios 1–2, 4–28 plus reporting) and `ShiftOpenConcurrencyTest` 2/2 (real multi-process races: same drawer → exactly one open shift, losers get the Arabic 422; different drawers → both open with distinct numbers). Focused set (with `BranchCashDrawerTest`, `ShiftCashSummaryApiTest`, `CashierAuthorizationApiTest`, `ArabicValidationErrorPresentationTest`, `BranchLifecycleAndCafeConfigurationTest`, `ValidationErrorPresentationUnitTest`): 98 passed, 1 failed (pre-existing). Full suite: 890 passed, 38 failed, 1 skipped (8984 assertions). All 38 failures are pre-existing: those failing files, run on a clean `e21e46f` worktree, fail in exactly the same 38 tests (SupplierAccountsPayable, WarehouseConfigurationRepair, PreAuthFinancialConcurrency, demo seeders, FinanceDashboard*, DiscountRuntimeEligibility, AuthPhase*, etc.). Three `BranchCashDrawerTest` cases were updated because they assumed a shift could open without a destination; they now simulate a pre-A2 legacy shift. `migrate:fresh --env=testing` (DB pinned to `cafe_system_618_testing_migrations`) passed, and `shifts_one_open_per_location` exists as a partial unique index in both test DBs. `flutter analyze lib/features/shift`: no issues. `test/features/shift` widget tests fail on a `PosCubit` provider-missing error; this was already documented above as a broken shift test harness and is not caused by these changes.

- F (user-facing backend/API validation and error-message quality): presentation-only pass — no validation rule, accounting rule, or business logic changed. Root cause of the reported `The lines.2.unitCost field format is invalid` leak: `SupplierInvoiceController::draftData()` (and ~20 other controllers) use inline `$request->validate([...])` with no Arabic `lang/` resources at all (the app had none — Laravel 13 ships no default `lang/` dir). Added `backend/lang/ar/validation.php` (rule translations for every rule actually used + an ~200-entry `attributes` map for real API field names, including `lines.*`/`charges.*`/etc. wildcard labels) and set `APP_LOCALE=ar` / kept `APP_FALLBACK_LOCALE=en`. New `App\Support\ValidationErrorPresenter` turns any `collection.N.field` error key into a 1-based Arabic prefix (`lines.2.unitCost` → message prefixed "البند 3: ", `allocations.*` → "التوزيع", unknown collections fall back to "العنصر N" — never the raw path) without touching the machine-readable `errors` keys clients match on. `bootstrap/app.php`'s `ValidationException` render now applies this to **all** `api/*` routes (previously only `api/v1/orders/*/pay`) and returns a generic Arabic top-level `message`; the pay-route's existing code-derivation logic is preserved. New `App\Support\DomainErrorMessages` gives every `OrderLifecycleException`/`ManufacturingDomainException`/`CustomerDomainException`/generic-`DomainException` `domainCode` (~50, all pre-existing) a safe Arabic display string, falling back to a generic Arabic message for any future unmapped code — the original English exception text is untouched (still logged). New `App\Support\SafeExceptionResponse` + a final catch-all `\Throwable` render hide unexpected-500 internals (SQL/class/file text) behind a generic Arabic message when `app.debug` is off, explicitly leaving `HttpExceptionInterface`/auth/`ValidationException`/`ModelNotFoundException` responses (and anything with `app.debug` on) alone — status codes (401/403/404/409/422) are unchanged. New `App\Http\Middleware\SetLocaleFromRequest` (global, first in the api pipeline) honors an `Accept-Language: ar|en` header so the Flutter app's existing English/Arabic toggle (`AppLocaleCubit`) isn't broken by the new Arabic default — Flutter's `DioApiClient` now sends that header from a new `CurrentLocale` static (mirrored by `AppLocaleCubit` on every locale change). Translated a bounded set of pre-existing hardcoded English strings at their source (not a lang-file concern): ~13 idempotency-conflict `abort(409, ...)` messages across `FinanceDocumentService`/`CashTransferService`/`CustomerPaymentService`/`CustomerRefundService`/`ExpenseService`/`SupplierInvoiceService`/`SupplierPaymentService`/`PurchaseReceivingService`; one leftover English `ValidationException::withMessages` string in `CashSourceResolver` (already mostly Arabic from prior work); and `AccountingPeriodGuard`, which was literally returning the raw code string `ACCOUNTING_PERIOD_CLOSED`/`ACCOUNTING_PERIOD_LOCKED` as the user-facing message — now real Arabic sentences (updated the one test, `FinancialReportsAndPeriodsTest`, that asserted the old raw code). Flutter's `purchase_error_messages.dart` (from task D) now prefers the backend's own per-field Arabic message (which already includes "البند N: ...") and only falls back to its local reconstruction if a backend message still contains a raw `lines.N.field` path — kept, not deleted, since the fallback still protects against an older/lagging backend. **Known, explicitly out-of-scope-for-this-pass remainder**: the domain-service layer has several hundred additional hardcoded English `ValidationException::withMessages`/`abort()` sentences beyond the bounded set above (e.g. most of `ExpenseService`, `InventoryPostingService`, `BarCheckTemplateService`) — found via audit, deliberately not mass-translated per the task's explicit "do not translate every possible internal exception blindly" instruction; flagged for a follow-up pass, not silently left inconsistent. Also found ~20 Flutter call sites using `error.toString()`/`snapshot.error.toString()` for user-visible text (`inventory_cubit.dart`, `finance_setup_cubit.dart`, `pos_cubit.dart`, etc.) — low risk today since `ApiException.toString()` already equals the (now Arabic) backend `message`, but a raw Dart exception (not an `ApiException`) reaching one of these would still print English/technical text; not touched, per the task's "do not refactor unrelated debugging tooling" instruction. Backend regression (Docker PHP 8.4, `cafe_system_618_testing`): new `ArabicValidationErrorPresentationTest` 9/9, new `ValidationErrorPresentationUnitTest` 11/11; full regression sweep of touched-adjacent suites — `PurchaseLineCostPrecisionApiTest`, `PurchasingPhase2ApiTest`, `CustomerPaymentApiTest`, `RefundAccountingApiTest`, `SaleAccountingApiTest`, `ShiftCashSummaryApiTest`, `FinancialReportsAndPeriodsTest`, `MoneyIdempotencyApiTest`, `CashierAuthorizationApiTest` — 118/118 passed, 1256 assertions, 0 failures. `flutter analyze`: 0 errors, still exactly the documented 40 info-level lints. A2 untouched; A3/B1/C/D/E behavior unchanged (presentation-only); manufacturing untouched; no historical data modified; no migrations added.

- C (date/business-date correctness): fixed hidden `now()`/`DateTime.now()` fallbacks in the six confirmed paths without changing A2 close-transfer accounting, A3 direct-cash semantics, or B1 debit/credit design. New `App\Support\BranchLocalDate` (`backend/app/Support/BranchLocalDate.php`) answers "what calendar date is today for this branch?" from `branches.timezone` (falls back to UTC) and is used only as an explicit default, never to convert stored UTC timestamps. **C1/C2** — `PurchasePostingOrchestrator::post()` now accepts optional `paymentDate`/`receiptDate` (defaulting to branch-local today, not `now()`) and threads them into the auto-created supplier payment's journal entry and the auto-receipt's `receipt_date`/stock-movement `occurred_at`; `PurchaseController::post` validates and forwards both fields; `PurchaseReceivingService::create` defaults a caller-omitted `receiptDate` to branch-local today instead of `now()->toDateString()`. Flutter: `purchase_posting_dialog.dart` now has editable "تاريخ الاستلام"/"تاريخ الدفع" fields (both default to today) whose values flow through `PurchasingRepository.postPurchase` to the backend. **C3** — voucher backend (`FinanceDocumentService`) already required an explicit `documentDate`; `vouchers_screen.dart` now has an editable "تاريخ السند" field (default today) feeding the payload instead of `DateTime.now()` at save time; B1 behavior (debit/credit labels, preview, balance validation, draft/post) is unchanged. **C4** — `ImmediateCollectDialog`'s registered-customer branch now shows an editable "تاريخ الدفع" field (default today) instead of a hidden `_today()`; the direct-cash branch is unchanged (`paymentDate == invoiceDate`, still enforced server-side). `CustomerPaymentDialog` already had an editable date picker. **C5** — `shift_report_screen.dart`'s "تاريخ التقرير" tile now reads `result.closedAt` instead of `DateTime.now()`, so reopening a closed shift's report the next day still shows its real closing date. **C6** — `BranchLocalDate` is the shared helper; nothing about UTC storage changed. Backend regression (Docker PHP 8.4, `cafe_system_618_testing`): `PurchasingPhase2ApiTest` 33/33, `FinanceVoucherApiTest` 9/9, `BranchLocalDateTest` (new) 2/2, plus `CustomerPaymentApiTest`/`SaleAccountingApiTest`/`RefundAccountingApiTest`/`ShiftCashSummaryApiTest` 86/86 unaffected — all green. A pre-existing, unrelated `php artisan test` full-run had 64 failures in `SupplierAccountsPayableApiTest` (stale test payloads missing `branchId`, unrelated to date handling) and `WarehouseConfigurationRepairTest` (missing seeded cash account) — confirmed via `git diff` that neither failing file nor any file they exercise was touched by this task; left unfixed as out of scope. Flutter: new `test/features/sales/immediate_collect_dialog_test.dart` (2/2) plus full `purchasing/` suite (35/35) green; `flutter analyze` still exactly the documented baseline — 0 errors, 40 info-level lints. A shift-report widget test was attempted but could not be kept: the whole `windows_application/test/features/shift/` suite (including the pre-existing, untouched `shift_overview_smoke_test.dart`) currently hangs/times out in this environment on a periodic `Timer` inside `shift_identity_header.dart` — a pre-existing test-infrastructure issue, not introduced here; the C5 fix itself is a one-line, low-risk change verified by direct code inspection. A2/A3/B1/manufacturing/inventory costing were not touched.

- A3 (cash-sale save/post/collect) continuation, Phase 1+2: reporting/read-model correctness and the direct-cash refund contract. `is_walk_in` customers are now excluded from AR-wide read models (`CustomerReceivableQueryService::customerOverview/invoicesAsOf/summary/overdueOutstanding/openInvoiceCount/openInvoices`) so a fully cash-collected invoice never shows as permanently outstanding in AR aging, the customer statement, or the Finance/Sales-Center dashboard's `outstandingAr` KPI. A posted direct-cash sales invoice can now be credited/refunded through the existing Sales Credit Note document: `SalesCreditNotePostingService` detects a direct-cash original invoice (via `customer_payments.direct_sales_invoice_id`) and, instead of reducing AR or creating unapplied customer credit for the shared walk-in customer, credits the resolved cash/bank source directly for the refund amount, capped cumulatively at what that specific invoice actually collected net of prior posted refunds (never a shared customer-credit balance). A new `customer_refunds.sales_credit_note_id` nullable/unique FK (additive migration `2026_10_01_000001_link_direct_cash_credit_note_refunds.php`) makes the refund auditable and traceable, sharing the credit note's own reversal journal (no second journal). `sales-invoices` API now exposes `refundedAmount`/`netCollectedAmount`/`remainingRefundableAmount` for walk-in invoices; `canCreateCreditNote` is enabled for posted walk-in invoices. Backend regression: `SalesCreditNoteApiTest`, `SalesCreditNoteDirectCashApiTest` (new, 7 tests), `CustomerPaymentApiTest`, `CustomerAgingAndStatementTest`, `FinanceDashboardCompletionTest`, `FinanceDashboardMissingSalesInvoiceTablesTest` — 55 passed, 647 assertions (Docker PHP 8.4, `cafe_system_618_testing`). Flutter: credit-note detail screen now collects a cash/bank refund source before posting a direct-cash credit note (`_CashRefundSourceDialog`), and the invoice detail screen shows the cash-refund figures for walk-in invoices; `flutter analyze` on the touched files is currently blocked by a **pre-existing structural corruption** in `sales_screens.dart` (a missing class declaration/state fields around the `SalesInvoiceFormScreen` state, left by concurrent manual edits already in progress on that file before this continuation started) — not introduced by this change, left untouched, needs the file's own author to reconcile. Known remaining gap: full/partial cash refund has no dedicated stand-alone Flutter screen beyond the existing credit-note flow; sales/payment dashboard query services beyond those listed were not individually audited. A2 was not touched and remains operationally blocked. No manufacturing files were touched.

- Direct purchasing flow: new inventory purchases default to immediate receipt when posted; payment amount and receipt mode are independent. One destination warehouse is selected for direct purchases. The Purchasing Center opens on the invoice list and the receipt screen remains available for delayed/partial delivery. Purchasing API regression suite: 30 passed, 351 assertions on an isolated test database. Three purchasing Flutter widget suites: 19 passed. `flutter analyze --no-pub`: no issues. See `docs/purchasing/DIRECT_PURCHASE_FLOW_AUDIT.md`. No deployment or commit was made.

- Inventory catalogue: the 184 supplied material definitions from
  Ø§Ù„Ù…ÙˆØ§Ø¯_Ù…Ø¶2Ø¨ÙˆØ·.xlsx are represented as active raw materials without opening
  stock, costs, or reorder thresholds. Exact existing names are retained
  rather than duplicated; all other names, categories, and units are preserved
  and available to product recipe configuration.

Cafe System 618 has a Laravel backend in `backend` and a Flutter Windows client
in `windows_application`. Tenant isolation is backend-authoritative. The test
suite is guarded to use `cafe_system_618_testing`.

## Authentication status

- Auth Phase 0: **CLOSED**
- Auth Phase 1: **CLOSED**
- Pre-Auth Hardening A-D: **CLOSED**
- Batch 12: **COMPLETE**
- Auth Phase 2: **CLOSED**
- Flutter Auth Phase 3: **IMPLEMENTED â€” verification in progress**
- Phase 1B staging smoke: Flutter login sends exactly one trimmed identity key
  (`email` or `username`), never `identifier`; request-contract coverage
  protects session parsing and safe 422 handling.
- Deployment Phase 1C: Flutter Web platform abstractions implemented; final
  local browser/staging smoke remains environment-dependent.
- Final Permission Catalog: **DEFERRED**

Auth Phase 1 closure was manually verified on this exact worktree with
`docker compose exec -T backend php artisan test`: **160 tests passed, 2,054
assertions, 0 failures, in 67.15 seconds**. The suite includes the Auth Phase 1,
Platform Super Admin, publication/payment/discount concurrency, POS runtime,
snapshot-aware order, tenant isolation, and testing-database isolation coverage.

Auth Phase 2 closure passed `migrate:fresh --seed` against
`cafe_system_618_testing` and the full Laravel suite: **164 tests, 2,099
assertions, 0 failures**. It delivers the backend-only Tenant Employee
Management domain: separate `tenant_roles` identities (Owner/Manager/Employee),
one authoritative Role per User, read-only role catalog, temporary-password
employee creation, Manager-to-Manager creation, protected Owner lifecycle and
credentials, Tenant-safe active Branch assignments, lifecycle/password token
revocation, and the temporary Owner/Manager employee-administration boundary.
The final Permission Catalog, custom role management, Flutter Auth, actor
attribution, and full operational route authorization remain deferred.

## Current delivery state

- Maintenance: the Cafe Configuration create-branch route resolves a
  route-scoped `BranchEditorCubit` through the service locator.

Menu Management Admin is **COMPLETE through Publish / Versions**:

- Batch 8 â€” Pricing & Availability: **COMPLETE**
- Batch 9 â€” Menus & Composition: **COMPLETE**
- Batch 10 â€” Assignments & Schedules: **COMPLETE**
- Batch 11 â€” Review & Publish: **COMPLETE**
- Menu â†” Inventory validation hardening: **COMPLETE** â€” recipe writes,
  resolution, publishing, and Review & Publish now use the Inventory conversion
  contract; existing invalid rows remain visible with actionable diagnostics.
- Recipe editor dropdown resilience: existing recipes load inactive/archived
  current materials as one disabled selection; material IDs and allowed recipe
  unit codes are normalized before dropdown items are built.

The implemented flow covers Catalog, modifiers, recipes/material configuration,
menus/sections/placements, exact Branch + Sales Channel assignments and schedules,
validation, resolved preview, publishing, immutable version history, comparison,
and rollback.

Published Menu Snapshots are versioned immutable payloads. Schema v3 defines
published Menu order by the serialized `menus[]` sequence and zero-based
`scopeOrder`; automatic publication uses exact-scope active assignment order.
Catalog Menu priority is not a published runtime-order field and must not be used
to re-sort a snapshot. Explicit `menuIds` retain the established canonical Menu
order, not request order. Historical payloads remain immutable and rollback copies
the selected historical payload unchanged.

## Current POS boundary

- Published POS variant selection: COMPLETE. The customization dialog presents
  every sellable runtime variant, defaults to the published default, and
  submits the selected immutable variant ID with its effective price.

- Phase 12A â€” Runtime Contract: **COMPLETE**
- Phase 12B â€” Backend POS Runtime Sync API: **COMPLETE**
- Phase 12C â€” Snapshot-Aware Order Contract (backend): **COMPLETE**
- Phase 12D â€” Flutter Runtime DTOs + Sync Repository + Scoped Cache: **COMPLETE**
- Phase 12E â€” Published Menu presentation cutover: **COMPLETE**
- Phase 12F â€” Offline / reconnect / pending-version behavior: **COMPLETE**
- Phase 12G â€” Legacy cutover + final regression: **COMPLETE**

**BATCH 12 â€” COMPLETE.** Production POS follows Published Runtime Contract v1
only: Menu Management -> Publish -> Immutable Published Version -> POS Runtime
Contract v1 -> `/pos/menu-sync` -> scoped Flutter cache -> Published POS UI ->
version-bound cart -> snapshot-aware Order. It never falls back to the live
Catalog when publication, network, or contract/cache validation fails.
The bounded runtime overlay keeps Sold Out and Temporarily Unavailable state
fresh without republishing; published schedules remain backend-resolved.

Offline menu and cart preparation are supported. True offline transaction or
payment processing is not implemented. The legacy Catalog Menu endpoints and the
no-version `POST /orders` branch are retained as deprecated compatibility paths
for non-POS consumers and existing historical workflows. They are not used by
the production Windows POS. Historical orders
with no published version remain readable, refundable, and receiptable. Future
authenticated barista/terminal assignment may restrict visible Branch choices;
current Branch / cart isolation remains authoritative.

## Batch 12 closure verification

On the exact closure worktree: backend focused tests passed (41 tests / 485
assertions), the full Laravel suite passed (138 tests / 1,891 assertions), and
Pint, Dart format, and `git diff --check` passed. Manual Windows verification
passed: `flutter gen-l10n`, `flutter analyze`, `flutter test` (487 passed), and
`flutter build windows`. The built executable launched successfully and rendered
the Published POS screen.

## Pre-Auth hardening

### Pre-Auth Hardening A âœ… CLOSED

- `OrderLifecyclePolicy` permits normal mutation only for unpaid Draft/Held
  orders; completed and refunded orders are immutable.
- Payment and refunds use database locks, tenant/order-scoped idempotency keys,
  unique constraints, and durable locked number counters.
- Flutter supplies one key per payment/refund attempt; offline payments remain
  blocked.
- True PostgreSQL process-concurrency coverage passed for payment/refund
  idempotency and order/refund number contention.

### Pre-Auth Hardening B âœ… CLOSED

- Mutable admin feature Cubits are lazy and route-scoped; POS startup no
  longer creates Orders, Discounts, Reports, or Menu Management state.
- `PosCubit` remains the session POS workspace so cart and branch context
  survive a temporary route change. Its branch safety rule remains unchanged.
- Orders and Reports follow that authoritative branch only while their route is
  mounted; report requests pass the supported `branchId` contract.
- Router topology tests assert that POS does not request unvisited feature
  repositories and that Orders, Reports, and Discounts initialize independently.

### Pre-Auth Hardening C âœ… CLOSED

- `DiscountEligibilityService` is the authoritative runtime policy for managed
  discounts, including Branch-local date/day/time and overnight windows.
- Product/category targeting uses persisted immutable category identity for
  versioned Orders; legacy Orders retain their live-Catalog compatibility path.
- Payment-time revalidation covers tender restrictions and current policy state.
  Discount usage is consumed only by a successful payment with locked global and
  per-customer checks, and payment retries cannot double-consume it.
- Full Laravel verification passed: 149 tests / 1,985 assertions; Pint and
  `git diff --check` passed; `cafe_system_618_testing` migration rebuild and
  seed completed successfully. No Flutter files changed for Hardening C.

### Pre-Auth Hardening D âœ… CLOSED

- Publication now acquires its exact tenant + Branch + channel advisory lock
  before it starts the repeatable-read critical section. Candidate resolution,
  blocking validation, snapshot construction, checksum/no-change selection,
  version writes, and publication audit all use that one authoritative state.
- PostgreSQL worker coverage verifies same-scope serialization, no-change
  contention, cross-scope independence, and an independent-connection edit
  between validation and snapshot construction.
- Flutter has a small typed API error foundation for unavailable network,
  unauthenticated, forbidden, validation, conflict, server, and unknown paths.
  Safe generic EN/AR copy is available; useful 422 domain messages and stable
  backend codes are retained. POS cached-menu offline behavior remains distinct.

Closure verification passed locally: Laravel 152 tests / 2,003 assertions,
Flutter 496 tests, `flutter analyze`, and the Windows build all completed.

**PRE-AUTH HARDENING COMPLETE.**

## Pre-Auth handoff

Auth Phase 0 and Auth Phase 1 are closed. Platform Super Admin
authentication/permissions remain a separate security domain. Auth Phase 2,
Flutter Auth, and the final Permission Catalog remain future work.

The next phase is Tenant Employee Authentication, Roles, Permissions, Branch
Assignment, server-side authorization, actor identity/audit attribution, and
Flutter permission-aware navigation. It is not implemented by this baseline.

The hardening sequence is:

1. **Pre-Auth Hardening A** â€” Order lifecycle + payment/refund concurrency/idempotency
2. **Pre-Auth Hardening B** â€” Flutter route-scoped Cubits / shared app context cleanup
3. **Pre-Auth Hardening C** â€” Discount runtime correctness
4. **Pre-Auth Hardening D** â€” Publish validation race + docs/error hygiene
5. **Auth + Employee Roles + Permissions + Branch Assignment**

Hardening items 1â€“4 are closed; only the final tenant employee-auth handoff is
future work and it is not part of Batch 12.

## Important architecture notes

- Products, Variants, Modifier Groups, Modifier Options, and Menu Sections use
  Active / Inactive / Archived lifecycle semantics; archive takes precedence.
- Variant base recipes and Modifier Option material adjustments are configuration,
  not Inventory runtime. Exact decimal quantities and canonical units are
  authoritative.
- Published snapshots exclude operational availability state, remaining quantities,
  and Inventory runtime data. Rollback creates a new Version rather than
  reactivating historical data.
- The Flutter Windows app uses feature-based Cubit architecture. The Product
  Workspace remains the canonical Product parent.
- Phase 4K architecture cleanup and broader localization migration remain deferred.

## Cafe Configuration Flutter Phase 2

- Owner-only Cafe Configuration now includes Team & Access and Tax alongside
  Overview, Cafe Profile, and Branches.
- Team & Access uses the existing paginated employees and roles APIs, supports
  Manager/Employee creation and editing, protected Owner rows, lifecycle
  actions, password reset, and active-branch assignment rules.
- Tax uses the tenant-wide fractional API contract while presenting percentages
  to the Owner. Overview now reports live team, tax, profile, and branch data.

## Batch 12 status

## Reports Overview UI

- The existing `/reports` Cubit/repository-backed overview now follows the
  Reports Overview reference hierarchy with RTL-aware controls, polished
  loading/error/empty states, and truthful branch/product data presentation.
- Financial Reports reuses its canonical `/finance/reports` screen; remaining
  detailed report categories are visibly pending rather than dead links.

## Sales & Profitability Report UI

- Added the route-scoped `/reports/sales-profitability` report with typed
  presentation models, Cubit filter/view/sort state, responsive Arabic-first
  report sections, and a deliberately endpoint-free repository for this UI
  phase.
- The Reports Overview Sales & Profitability category is now active; Inventory,
  Expenses, Purchasing & Suppliers, and Custom Report Builder remain pending.

## Cash & Shifts Report UI

- Added the route-scoped `/reports/cash-shifts` report with typed
  presentation models, Cubit filter state, responsive Arabic-first report
  sections, and a deliberately endpoint-free repository for this UI phase.
- The Reports Overview Cash & Shifts category is now active.  It remains a
  read-only analytics destination; shift, payment, and closing operations stay
  in their canonical operational modules.

## Inventory Report UI

- Added the route-scoped `/reports/inventory` read-only analytics report with
  typed inventory presentation models, filter state, responsive Arabic-first
  sections, and an endpoint-free repository during this UI phase.
- The Reports Overview Inventory category is now active. Expenses, Purchasing
  & Suppliers, and Custom Report Builder remain pending.

## Reports Demo Data

- `Cafe618ReportsDemoSeeder` prepares idempotent Cafe 618 development data for
  report work: POS sales, cash/card payments, refunds, shifts, cash transfers,
  reconciliations, daily closings, and overview history. It is limited to
  local, development, and testing environments and is included in local
  `DatabaseSeeder` runs.

- 12A âœ… Runtime Contract
- 12B âœ… Backend POS Runtime Sync API
- 12C âœ… Snapshot-Aware Order Contract
- 12D âœ… Flutter Sync / Scoped Cache
- 12E âœ… Published POS UI Cutover
- 12F âœ… Offline / Reconnect / Pending Version
- 12G âœ… Legacy Cutover / Final Regression

**BATCH 12 â€” COMPLETE**

## Inventory warehouse context audit

- Inventory list requests now carry both the active operational `branchId` and
  the selected `warehouseId`; Laravel applies and validates both scopes for
  balances, items, movements, counts, and the dashboard.
- Warehouse selectors use one active/legacy/branch rule, retain central
  warehouses, clear stale selections on branch changes, and reload the owning
  screen immediately.
- Inventory Cubit loaders use latest-request-wins guards so a slow response for
  a previous warehouse cannot replace newer data. Stock-count warehouse
  options remain isolated from the general warehouse list.
- Focused Flutter warehouse-context tests and the backend
  `InventoryCenterApiTest` suite pass.

## Inventory branch provider repair

- The operational branch Cubit now has one lazy, shell-wide provider above all
  Inventory routes. Route-local duplicates were removed so the module frame,
  warehouse selectors, and routed page always observe the same branch state.
- `InventoryModuleShell` initializes that context from the authoritative POS
  branch and follows later top-navigation branch changes.
- Static analysis is clean, and the provider/synchronization regression test
  plus all warehouse dropdown widget tests pass (5 tests).

## Cafe 618 branding integration

- Added a centralized, role-aware brand identity resolver. Cashiers see the
  authoritative active branch name; managers and owners retain the general
  Cafe System 618 identity. Missing or stale branch context falls back safely
  and never guesses a branch.
- Replaced scattered shell, authentication, splash, and receipt branding with
  reusable logo/header widgets backed by bundled transparent assets.
- Web metadata, favicon/PWA icons, Windows executable resources, and runtime
  browser/native window titles now use the same centralized identity.
- Added regression coverage for role rules, branch switching, logout/re-login,
  long Arabic names, image fitting, and the Inventory branch-provider scope.
- Dart static analysis and focused branding/provider tests pass. The Windows
  debug runner builds successfully with the branded icon and title channel.

## Optional product modifier assignments

- The product modifier assignment endpoint now requires the replacement key to
  be present while accepting `groups: []` as the explicit detach-all command.
- Flutter already sends the replacement field for an empty selection; a new
  Cubit regression test protects that contract and its successful UI state.
- Laravel coverage verifies initially empty products, removal of all existing
  assignments without deleting group definitions, retained assignments,
  missing-key validation, and cross-tenant rejection. POS coverage confirms
  products with no modifier groups remain directly configurable/sellable.
- This behavioral fix changes no database schema or seed data.

## Automatic POS Bar inventory routing

- Cashiers no longer select a warehouse in POS. Laravel resolves the active
  branch's explicit `pos_inventory_warehouse_id`, validates tenant/branch/type,
  and snapshots it on the order for audit and payment-time revalidation.
- New branches receive an idempotent Bar warehouse configuration. The schema
  migration only backfills existing branches that have exactly one active Bar;
  ambiguous branches are intentionally left for administrator review.
- The warehouse repair command now audits missing, invalid, and ambiguous POS
  Bar configuration in dry-run mode and applies only deterministic repairs.
- POS consumption can create a negative Bar balance while preserving WAC/COGS.
  Incoming transfers understand signed balances and naturally settle a deficit
  (covered by the `0 -> -20 -> +20 -> 0` integration scenario).
- Laravel sale/accounting and warehouse-repair suites pass, and Flutter has a
  request-contract regression test proving `warehouseId` is never submitted.

## Shift module â€” full UI (frontend-only, mock-backed)

- New self-contained `lib/features/shift` module: current-shift overview, no
  open-shift / open-shift form, a five-step closing wizard (operations
  review, cash count with a denomination counter, bar count, final review,
  success), a filterable/paginated history screen, and a full closing report
  with an A4/thermal print-preview mock.
- Bar counting lives entirely inside the closing wizard (step 3), per
  explicit direction, and is not routed through
  `features/inventory/bar_checks`.
- Backed by `ShiftMockRepository`, a local in-memory data source with a
  debug-only scenario switcher (balanced close, cash shortage/surplus, stock
  variance, negative theoretical stock, blocking open order, incomplete
  count, no open shift, loading, error) â€” no backend endpoint exists yet.
- Domain models (`shift_models.dart`), a pure `ShiftAssessment` (alerts,
  readiness checklist, stage track) computed once and shared by the
  overview, the wizard and the confirmation dialog, and centralized
  `ShiftStrings`/`ShiftFormat` copy/formatting so no screen holds a literal.
- Registered in `service_locator.dart` and wired into `app_router.dart`
  under `/shift/current`, `/shift/history`, `/shift/closing`,
  `/shift/report/:shiftNumber`, with a new `ShiftModuleShell` sub-nav and a
  sidebar entry for both the owner and cashier navigation lists.
- `flutter analyze` is clean (only two pre-existing, unrelated warnings in
  `sales_screens.dart`). Two tests cover the module: a smoke test
  (`shift_overview_smoke_test.dart`) and a full five-step wizard walk-through
  (`shift_closing_flow_test.dart`, balanced scenario, operations â†’ cash â†’
  bar count â†’ final review â†’ confirm dialog â†’ success â†’ report route).
  Running the wizard test surfaced and fixed a real responsive bug: the
  stepper's full-label mode was switching on at the module's general tablet
  breakpoint (700px), which overflows with five Arabic step labels â€” it now
  switches at the desktop breakpoint (1100px). Deeper per-scenario coverage
  is left for a follow-up pass.
- Not done: backend integration, accounting/inventory posting, and real
  print/export â€” all explicitly out of scope for this UI-approval pass.
- Update: the module is now backed by a real `ShiftRepository` API client
  (`shifts/current`, `shifts/current/snapshot`, `shifts/history`,
  `shifts/{shiftNumber}/report`, `shifts/{shift}/close`); the demo scenario
  switcher was dropped from production wiring, and the older, separate
  `features/shift_close` module (and its `/shift-close` route) was retired in
  its favor â€” this is now the one Shift implementation.

### 2026-09-17 â€” Purchase item search usability review
- Evaluated the item picker implementation and ran two temporary widget probes using mocked inventory responses. Both reproduced defects: clearing a query before debounce completion still shows old results; typing a replacement after selecting an item clears the typed text.
- Code review also found no explicit arrow/Enter selection support and network errors rendered as empty search results.
- Live desktop interaction was interrupted by concurrent user input. No invoices were saved and no production code was changed. Temporary probes were removed after diagnosis.
- Recommended next step: fix selection/query synchronization and stale request cancellation, then add keyboard selection and distinct connection-error feedback.

### 2026-09-17 â€” Purchase item search repair
- Fixed query/selection synchronization so replacing a selected item preserves typed text.
- Debounced and in-flight responses are invalidated immediately on query changes, clear, selection, outside click, focus loss, and Escape. Removed stale results during new searches and prevented delayed overlays after dismissal/disposal.
- Added arrow-key highlighting with scrolling, Enter selection, and separate search-failure feedback with retry. Result overlay now anchors to the actual field bottom in RTL.
- Added 9 widget regression scenarios; all 14 focused picker and purchase-form tests passed. Flutter analyze reports only the pre-existing unnecessary_brace_in_string_interps info in create_discount_policy_screen_test.dart:780; no findings in changed files. git diff --check passed.
- No database, catalogue, stock, or backend changes. Next step: smoke-check the updated Windows UI after hot restart/rebuild.

### 2026-09-17 â€” Atomic Purchase Invoice posting, receiving, and cash settlement
- Added a dedicated `PurchasePostingOrchestrator` behind `POST /finance/purchases/{id}/post`. It validates permissions, branch and an unambiguous actor cash source before atomically posting the Supplier Invoice, completing remaining inventory receipt lines through `PurchaseReceivingService`, settling AP through `SupplierPaymentService`, and creating a linked posted Payment Voucher.
- Inventory purchases continue to use the existing Goods Receipt -> `InventoryPostingService` path, preserving stock movements, balances, WAC, unit conversions, landed costs, and receipt history. Expense/service and asset purchases create no stock movement.
- Cashiers must have an open shift in the invoice branch. The shift is bound to one active branch cash drawer; no bank, cross-branch, or arbitrary fallback is allowed. The payment is recorded as a shift expense so expected cash and closing reflect the purchase. Owners/managers without a shift require exactly one active branch cash drawer.
- Added schema links for shift cash source, Supplier Payment -> shift/voucher, Voucher -> purchase invoice/payment source, and idempotent shift movement sources. The migration performs no historical backfill or posting.
- The automatic voucher shares the Supplier Payment journal (Dr AP / Cr Cash) instead of creating a duplicate journal. Direct voucher reversal is blocked; reversing the Supplier Payment updates its linked voucher and shift cash movement consistently.
- Flutter Purchase Invoice now supports Save as Draft and unified Post, requires branch/receipt warehouse for posting, shows a server-resolved cash/shift confirmation, reports success, and links the payment voucher from invoice detail.
- New backend integration coverage passes 8 scenarios / 90 assertions covering inventory posting, double-submit idempotency, missing shift, shift expected cash, inventory/payment-stage rollback, old fully received invoices, expense/asset behavior, and branch isolation. Focused Flutter purchase/search tests pass (14 tests). The broader related Laravel run passed 106 tests / 961 assertions and retained four pre-existing authorization/bar-check expectation failures documented in the handoff; Flutter analyze is clean for changed files with one unrelated pre-existing info in the discounts test.

### 2026-09-19 — Purchase item mouse selection repair
- Root cause: the positioned overlay entry had only the popup width, while CompositedTransformFollower painted its result list below that parent. Flutter hit testing rejected mouse events outside the parent even though the list was visible. The overlay now has a full-screen hit-test parent and the follower remains anchored to the field; TapRegion still dismisses outside clicks.
- Preserved debounced server search and latest-request cancellation. Added mouse-click and scroll-then-click widget regressions. Purchase lines now retain stable widget identity, and choosing another item resets the purchase unit to that item's default while preserving the warehouse.
- Picker widget tests: 12 passed, including mouse click, scroll then click, and independent rows. Focused purchase and picker tests: 18 passed before the final two picker cases. Flutter analyze: one existing unused optional parameter warning in the purchase form and one unrelated discount-test info. Web and Windows release builds passed.

### 2026-09-19 — Follow-up: real mouse pointer regression
- Reproduced the reported failure with a widget test using PointerDeviceKind.mouse and separate pointer-down/up events. The previous tester.tap test used a touch pointer and missed it. On mouse down, the TextField lost focus and its focus listener removed the result overlay before ListTile.onTap could run.
- The result popup now tracks pointer-down inside its own region, so focus loss during a result click does not dismiss it. Selection closes the popup after updating the selected item. Tab, Escape, outside click, and ordinary blur still dismiss it.
- Focused picker and purchase-form suite: 20 tests passed, including the real mouse sequence. Flutter analyze retains the same two pre-existing findings. Web and Windows release builds passed after this follow-up fix.

### 2026-09-19 — Purchase receipt warehouse selector
- Fixed the invoice's optional all-branches state filtering out every branch warehouse. It now shows all accessible active warehouses when no invoice branch is selected, and the selected branch plus global warehouses once a branch is chosen. An incompatible line warehouse is cleared on branch change.
- Long warehouse names now fit the 190px selector via expanded layout and ellipsis. Added a widget regression with two branch warehouses; focused purchase and picker tests pass (21).
### 2026-09-19 — Direct purchase release readiness pass
- The default inventory purchase remains a single invoice form and posting action. Receive later is an unchecked operational option; it retains the separate partial receipt workflow.
- The purchase list and detail now label invoices spanning warehouses as “متعدد المخازن”. The detail shows a compact received quantity summary and explains why cancellation is unavailable after stock receipt.
- The purchase receipt mode migration was renamed to `2026_09_19_000001_add_purchase_receipt_mode.php` before staging; no historical stock is backfilled.

### 2026-09-19 � Supplier-specific purchase invoice numbering
- New purchase invoices receive a supplier-scoped, backend-generated reference using the stable supplier number and the existing locked number counter. The system PI number and optional external supplier document reference remain separate.
- Saved drafts keep their supplier and assigned number; changing supplier requires a new draft. The purchase form displays both automatic numbers read-only and labels the manual external reference separately.
- Added API regression assertions for independent supplier sequences, idempotent retry, optional external reference, and blocked supplier changes.

### 2026-09-20 - Manual Sales Invoice

- The form now offers direct posting from the editor. Posting uses the existing Sales Invoice service, which consumes inventory and records WAC/COGS in the same transaction.
- The form has a grouped header, detailed line controls, additional charges, and a totals preview. Backend totals remain authoritative.
- A line can sell an eligible inventory material directly. Its unit selector contains the base unit and active item-specific conversions. The invoice snapshots the selected unit and converted base quantity.
- The detail view shows the selling unit and line totals. Credit Note restock uses the original stock movement and cost snapshot.
- Focused backend pricing and posting tests, new raw-material tests, and targeted Flutter tests pass. The broader sales suites still contain failures in payment widget and sales-reporting fixtures.
- Deployment was not performed.
### 2026-09-23 - Printer Setup active branch resolution

- Printer Setup now follows the shell branch selector and loads printer defaults from the selected branch's configuration API. Branch changes reload automatically; loading, no selection, and configuration failures have distinct states, and Retry reloads the selected branch.
- Focused printer tests cover initial branch loading without visiting POS, branch switching, no branch, and configuration failure with retry. The printer suite passes (15 tests); modified paths pass Flutter analysis, Dart formatting, and `git diff --check`.

### 2026-09-23 - Printer Setup Settings overflow follow-up

- The Settings content now scrolls within its existing page layout so the printer card and actions remain reachable at the reported Windows window height. The local printer fields remain intentionally disabled while branch defaults are selected; turning that switch off enables the device override fields.
- Added focused widget coverage for the switch and for the full Settings layout at the reported desktop height. All 17 focused printer tests pass, the six modified Flutter paths pass analysis, and formatting and `git diff --check` pass.

### 2026-09-23 - P2 receipt raster printing

- Printer Setup resolves the active branch through the shell's operational branch context independently of visiting POS. Loading, no selection, branch lookup failure, and configuration failure have separate states; Retry re-fetches branches or configuration as appropriate.
- The receipt renderer reads the backend receipt contract without recalculating totals, shapes Arabic and mixed text with bundled fonts, and emits inspectable PNG plus RGBA raster bytes at 384 dots for 58mm and 576 dots for 80mm. Zero-balance receipts show no payment required and suppress Cash.
- PrinterService converts the raster to ESC/POS GS v 0 image blocks and reuses the existing TCP connection for initialize, image, feed, and cut. Rendering errors remain separate from network results. POS print actions remain for P3.

### 2026-09-23 - P3 POS printing integration

- The existing cart PRINT action now prints a saved order as a pre-bill using the authoritative receipt endpoint and configured effective printer. It displays ORDER CHECK / NOT PAID, refuses orders without items or orders the backend reports as paid, and does not submit or mutate payment.
- The post-payment Print Receipt action and branch autoPrintAfterPayment setting use the authoritative receipt, ReceiptRenderer, and local PrinterService. Printing is single-flight, auto print is deduplicated per paid order, failures leave payment state intact, and explicit Retry creates a new print attempt.
- Zero-total receipts show Total 0 and No payment required; payment labels are read from the backend and zero-balance receipts do not show Cash. Printer configuration, API, rendering, timeout, connection, and write failures map to localized safe messages with Retry, Close, and Printer Setup where applicable.
- Local print_jobs now record pre_bill/receipt type, effective printer and device, queued/started/completed timestamps, and safe failure codes/messages through queued -> printing -> completed/failed transitions. Laravel records the attempt only and does not print.
- Verification: focused Flutter POS/printer/payment suites passed (77 tests); the 26 modified Dart paths pass Flutter analyze; Dart formatting and git diff --check pass. PosApiSmokeTest passed (2 tests / 78 assertions), DiscountRuntimeEligibilityTest passed (8 / 91). Windows Release and Android APK builds passed.
- Additional legacy checks: test/widget_test.dart has five POS shell expectation failures before reaching its print assertions; its static auth fixture has no absolute expiry, so it does not enter the authenticated POS route. SaleAccountingApiTest passed 27 tests but its cash drawer balance assertion failed (actual 0.0, expected 4.86). The zero-balance cases passed in both the dedicated discount suite and SaleAccountingApiTest.
- Fixed the live ListTile ink/background assertion in the decorated availability panel by placing panel contents on a transparent Material surface.

### 2026-09-23 - P3 POS printing software closure

- The clean Docker/PostgreSQL rerun of `SaleAccountingApiTest` repeated the same result twice: 27 passed, 1 failed, 290 assertions. The failing 4.86 cash sale posts successfully, but its cash journal debit has no `financial_location_id`: `PaymentController::postSale` supplies only `accountCode` and amount, and `SalePaymentMethodResolver` returns no location. `FinancialAccountBalanceQuery` filters cash drawer balances by `financial_location_id`, so the drawer endpoint remains at 0.0. The payment posting and failing test predate P3; zero-balance and card accounting cases passed. Finance posting was left unchanged for separate repair.
- `widget_test.dart` now uses a current authenticated session with absolute expiry, so it enters POS. Assertions follow the current localized POS labels and still check customization, responsive layout, payment, receipt, print feedback, and customer selection. The offline customer fixture now honors the same search query as the backend. All 6 widget tests pass.
- Final focused Flutter printer, receipt, POS, payment, and shell group: 87 passed. `DiscountRuntimeEligibilityTest` and `PosApiSmokeTest`: 10 passed, 169 assertions. Affected Flutter paths analyze cleanly; 24 Dart paths are formatted; Pint and `git diff --check` pass. P3 print behavior received no changes in this closure pass. Software P3 can be marked CLOSED with the independent Finance cash drawer defect tracked separately; physical printer output remains a manual acceptance test.

### 2026-09-23 - Cafe Settings Printing tab

- Moved branch receipt printer defaults from Branch Edit into Cafe Settings > Printing. The tab selects a tenant branch, prefers the current operational branch when selected, and reads and saves the existing branch printer fields through CafeConfigurationRepository. Device Printer Setup remains separate.
- Added English and Arabic strings and focused navigation, controller, and widget coverage. The focused Cafe Settings and printer tests pass (30 tests).
- Printing UI layout follow-up: capped the content width, narrowed the branch selector, grouped receipt controls, and arranged printer fields in two columns on desktop and one column at narrow widths. Focused Printing widget tests pass, including Arabic RTL geometry; modified UI and test paths pass analysis and Dart formatting.

### 2026-09-24 - Task E: Inventory item details visibility

- E1: the item-details "سجل الحركات" tab now reads from `GET inventory/items/{item}/movements`, paginated (25/page) and ordered `occurred_at DESC, id DESC`, with `from`/`to` filters. The item-show endpoint's `recentMovements` stays an intentional 5-row summary elsewhere on the same screen.
- E2: two new read-only endpoints back the previously-placeholder tabs - `recipe-usage` (from `variant_recipe_components` + `modifier_option_recipe_profile_components`, the tables the live POS costing path actually reads; the legacy `recipe_lines`/`recipes` tables have zero remaining references) and `purchase-history` (from `purchase_receipt_lines` on posted receipts only, one row per physical receipt line so nothing double-counts).
- E3: movement types are now mapped to Arabic via `inventoryMovementTypeLabel()` (unknown future types degrade to the raw string instead of crashing); `inventoryMoney()` now calls the existing app-wide `CurrencyFormatter` instead of a hardcoded `$`.
- E4: proved and fixed a real defect - the item-details aggregate total/status was summed across every `stock_balances` row with no warehouse scope, so stock sitting in a read-only LEGACY-coded warehouse (invisible in the per-warehouse breakdown) could keep an item showing "نافد المخزون" after a real purchase. Now scoped to active, non-deleted, non-LEGACY warehouses, matching the per-warehouse breakdown it sits next to. Negative-stock policy is unchanged (still correctly reported as out of stock). Also fixed an unrelated crash found while proving this: `StockMovementController` parsed `quantity_before`/`quantity_after` with the unsigned decimal parser, which threw whenever a manual stock-in landed on top of an already-negative balance.
- 9 new backend feature tests (`InventoryItemDetailsApiTest`) and 13 new/updated Flutter tests pass; full inventory/purchasing regression suites pass except two pre-existing failures unrelated to this task (shift-close and supplier-payment branch validation, both touched by other in-progress work already in this worktree). `flutter analyze`: 0 errors, same 40 pre-existing infos.

Factory separation resume 2026-09-26: phase 3 ownership and materials UI in progress; 17 demo materials backfilled to factory branch 5. No commit. Final acceptance and later phases remain pending.

Factory separation phases 3 → 3b → 4 → 5 → 6 → 7 → 8 → 10 → 9 COMPLETE (2026-09-27). Private materials/master data/recipes, scoped shared screens, factory finance without shifts, independent warehouse/POS/transfer guards, and internal parties/consolidation/reconciliation implemented. Migrations 2026_10_06_000001–000007 applied; local item/recipe backfill repeat 0 candidates/0 conflicts. Final Laravel 970 passed / 36 pre-existing failures / 1 skipped; clean phase-2 baseline 959 / 37 / 1: zero new failed cases, one route-map case fixed. NO_OPEN_SHIFT is pre-existing in all three DiscountRuntimeEligibility cases; configured cafe cashier cycle passes. Flutter 1516 / 23 versus baseline 1512 / identical 23 failures; affected Flutter 19 / 0; analyzer 0 errors/warnings, 28 existing infos. Live factory UI and production/sale/independent cafe purchase/payment/collection passed. Windows Release rebuilt with fresh AOT at build/windows/x64/runner/Release. Final report, all failure causes, manual acceptance and explicit single-commit list: docs/FACTORY_FINAL_VERIFICATION.md, FACTORY_KNOWN_TEST_FAILURES.md, FACTORY_ACCEPTANCE_CHECKLIST.md, FACTORY_COMMIT_FILES.md. Nothing staged/committed/pushed; master requires approval of the concrete file list first.
- 2026-09-27: Shift opening failures now display the API rejection inline on the opening form instead of silently rebuilding it. Opening retries and successful opens clear stale errors. Added a regression test for a rejected opening; both overview widget tests pass. Full flutter analyze completed with info diagnostics only (55 reported), no errors or warnings. The actual runtime rejection still needs the displayed server message to diagnose.

### 2026-09-27 - Recipe output product typed name
- Replaced the new recipe output dropdown with a name text field; existing recipe edits retain the linked product name as read-only.
- Recipe creation accepts productName, reuses a matching active factory-owned product or creates a finished good assigned to the factory default warehouse. Product and recipe save atomically; branch locking prevents duplicate concurrent name creation. Existing productItemId clients remain supported.
- Verified: ManufacturingCoreFlowTest 25 passed / 502 assertions including typed name, duplicate prevention and rollback; focused Flutter recipe tests 5 passed. Full Flutter analyze has 0 errors/warnings and 28 pre-existing infos. Windows Release build passed. No commit or push.

- 2026-09-27: Added detailed Arabic implementation plan for historical shift closing and continuation shifts at docs/finance/HISTORICAL_SHIFT_CLOSE_PLAN_AR.md. Covers shared period preview, event-time attribution, historical cash and inventory reconstruction, actual transfer timing, atomic split/audit/idempotency, Flutter flow, concurrency and acceptance tests. Planning only; historical closing behavior has not changed.

### 2026-09-27 - Hide factory reports tab
- Removed Reports from ManufacturingNavigationBar destinations as requested. Report screens/routes/data remain available internally; this is a temporary navigation visibility change.
- Flutter analyze: 28 existing info diagnostics, no errors or warnings.
- Windows Release build passed (81.8s). No commit or push.

### 2026-09-27 - Factory SYP / USD documents
- Added per-factory default input currency (SYP or USD) and a manually configured USD-to-SYP rate, with owner/factory-manager editing and audit logging. Factory navigation exposes a currency settings button; invoice/payment fields can reuse and save the defaults.
- Added decimal server-side conversion for supplier invoices, sales invoices, supplier payments and vouchers. Document snapshots retain original inputs/currency/rate; ledger balances, allocations and inventory valuation remain SYP. Factory-only scope is enforced; cafe currency selection is rejected.
- Draft edit hydration uses original USD inputs and rate; SYP edits use the configured dollar rate. Automatic purchase-payment vouchers inherit their invoice currency without converting posted money again.
- Migration 2026_10_07_000001 applied. The migration run also applied pre-existing pending migration 2026_09_30_000001_add_historical_shift_closing from other work.
- Validation: manufacturing suite 27 passed / 539 assertions; subsequent currency/automatic-voucher checks 3 passed / 49 assertions. Flutter currency/sales/purchase/supplier profile group 30 passed. Analyze has no errors/warnings; Windows Release built successfully. No commit/push.
- Implementation and usage: docs/FACTORY_CURRENCY_IMPLEMENTATION_2026-09-27.md.

### 2026-09-27 - Purchase form inventory reference permissions
- Fixed the inventory permission denial while loading purchase forms: explicitly marked warehouse/item/unit-conversion read routes accept purchase create/edit permissions, retaining controller tenant/branch scopes. Inventory mutation and stock-report routes keep their existing permission checks.
- Added a cashier regression test for reference reads, warehouse branch scope, and denied inventory operations.
- PHP syntax checks and git diff --check passed. Feature test execution blocked: local PHP 8.2.12 does not meet Composer requirement >=8.4.1. No production deployment performed.

### 2026-09-28 - Menu Pricing UX refinement

- Reframed the pricing workspace with surfaced context controls, a clear eligibility notice, an action toolbar placed before the affected data, and a bordered, scan-friendly pricing table.
- Retained the bulk-price dialog because it is a reversible proposal before the existing server-authoritative review/apply gate. Its form is now responsive, grouped by adjustment and rounding, shows percent/currency context, exposes an explicit scope notice, has labelled controls, and prevents duplicate preview submission with progress feedback.
- Added a narrow-width dialog regression. The focused pricing-screen widget suite passes (3 tests). Full Flutter analysis remains blocked by an unrelated existing `CafeConfigurationRepository.getFinancialAccounts` test-double error; no pricing diagnostic was reported before that failure. No commit or deployment.

### 2026-09-28 - Menu Pricing review dialog provider repair

- Fixed the live `ProviderNotFoundException` in the review dialog. `showDialog` uses the root navigator while `MenuPricingCubit` is scoped to the menu-pricing route, so the dialog now receives the existing cubit through `BlocProvider.value` before building its `BlocBuilder`.
- Updated the pricing screen harness so the cubit is route-local like production; this reproduces and guards the formerly missing provider boundary. Focused pricing-screen tests pass (3). No commit or deployment.

### 2026-09-28 - Menu Pricing review workspace UX

- Rebuilt the price-adjustment review from a dense text stream into a structured desktop workspace: scoped information notices, wrapped summary count cards, and a readable item card with labelled original, raw, rounding, final, difference, and configuration-effect values.
- Kept the acknowledgement gate and server-authoritative Apply behavior intact. The primary Apply action now includes a clear progress state; all controls retain explicit text labels for RTL usability and accessibility.
- Verification: focused English/Arabic/narrow dialog tests pass (3); direct analysis of `menu_pricing_screen.dart` has no issues. Full workspace analysis still has the unrelated `CafeConfigurationRepository.getFinancialAccounts` test-double error. No commit or deployment.

### 2026-09-28 - Menu Pricing acknowledgement panel Material repair

- Fixed the Windows runtime `ListTile background color or ink splashes may be invisible` assertion in the review acknowledgement panel. Its colored rounded container now gives the interactive `CheckboxListTile` children a transparent `Material` paint surface, preserving the visual design and interaction behavior.
- Extended the review-dialog regression to scroll through and build the acknowledgement panel. Focused pricing tests pass (3); direct screen analysis has no issues. No commit or deployment.

### 2026-09-28 - Arabic supplier localization coverage

- Added Arabic source translations for the 120 previously untranslated Supplier Finance messages, preserving every interpolation token (`reference`, `remaining`, `days`, and `error`). Source validation confirms zero missing Arabic message keys and placeholder parity.
- Regeneration remains pending: `flutter gen-l10n` is waiting on an already-active Flutter SDK lock, so generated localization Dart files have not been claimed as verified or manually edited. No commit or deployment.

### 2026-09-28 - Actual monthly Discount value metric

- Replaced the Discount dashboard's seeded `estimated_saved_value` aggregation with a protected `GET /discounts/metrics` contract. It sums immutable `order_discounts.discount_amount` only for tenant-scoped configured policies on completed, paid/partially-refunded/refunded, non-cancelled orders closed in the current month; free-form manual discounts and non-paid or prior-month orders are excluded.
- The Flutter Discount Cubit loads that server-authoritative metric alongside the policy list. The summary card shows no amount while the metric is unavailable, rather than fabricating a zero or summing seeded display metadata. English and Arabic source labels now identify it as the actual current-month value.
- Validation: `docker compose exec -T backend php artisan test --filter=DiscountManagementApiTest` passed 8 tests / 53 assertions, including the current-month/exclusion regression. Flutter regeneration and focused Flutter verification are pending because an active `flutter run` SDK lock prevented `flutter gen-l10n`; generated localization Dart was not edited manually. No migration, commit, or deployment.

### 2026-09-29 - Cafe Configuration test fake interface repair

- Added the missing `getFinancialAccounts` implementation to the Cafe Configuration Cubit test repository fake, returning an empty account list with the repository's default status argument.
- Focused Cafe Configuration test passed (12 tests). Full `flutter analyze` found 29 info-level findings outside this file and no missing-method error. No commit or deployment.

### 2026-09-30 - Repeatable POS Hold and Resume lifecycle

- Added an authorized `POST /orders/{order}/resume` transition from unpaid held to draft. An eligible draft can be reopened without changing its status, so interrupted POS sessions can recover it from Active Orders. Paid, closed, unauthorized, and unsupported-snapshot orders remain blocked.
- POS loads the server-confirmed draft before enabling Hold again. A lost Resume response is checked with one GET; the client does not repeat the mutation automatically.
- Verification: `OrderLifecycleApiTest` passed (11 tests / 102 assertions); focused Flutter Hold, order-context, and Orders lifecycle tests passed (43). Full `flutter analyze` reported only 29 existing info-level findings outside the changed files. No migration, commit, or deployment.

### 2026-09-30 - Fixed product discount per eligible unit

- Added `fixedAmountBasis` (`per_order` by default, `per_unit` for fixed product discounts) to the Discount management contract, persistence, Create/Edit form, and list/detail value labels. English and Arabic choices are available when a fixed discount targets products.
- The backend applies the fixed amount to every eligible unit across all selected products, caps each order-item line at its price, then applies the policy's optional order-wide maximum. Existing discounts remain once per order. Draft cart changes and payment revalidate the server amount.
- Applied only `2026_09_30_000002_add_fixed_amount_basis_to_discounts` to the local application database after reviewing its single additive SQL statement. Focused Laravel runtime and management suites passed (9 tests / 101 assertions and 9 tests / 65 assertions); focused Flutter Discount tests passed (49), and Discount analysis reported no issues. The final focused Create-form submission test also passed. No commit or deployment.

### 2026-09-30 - Shift status badge RTL overflow

- Reproduced the Arabic shift badge `RenderFlex` overflow inside a 102.5 px table cell. The badge now wraps its label within the available width, so the full status stays visible in a taller badge.
- A focused badge widget test and shift overview smoke tests passed. Full `flutter analyze` reported 29 info-level findings in other files and no errors or warnings. The live Windows screen has not yet been reopened for visual acceptance. No commit or deployment.

### 2026-10-01 - Plan 1 Discount product/variant Flutter targeting

- Implemented D1-09–D1-13 Flutter code: full-detail edit hydration, lossless policy fields including legacy timestamps, exact product-only selection writes, independent paginated/searchable Discount product/variant references, retained selected identities and lifecycle metadata, per-product All/Selected controls, safe scoped failures/retry, stale-response protection and duplicate-submit guards. EN/AR summary and illustrative preview preserve backend financial authority.
- Required serial checks: localization generation exit 0; Discounts 76 tests, POS Discount dialog 2 tests and Discounts routing 2 tests, all exit 0. Additional route-request isolation passed 4 tests. Scoped analysis had no issues (exit 0). Full analysis retained 29 existing Info findings in Sales and Printer test with no errors/warnings (exit 1). Scoped Dart formatting and `git diff --check` passed (exit 0).
- Web and Windows release builds passed (exit 0). A real browser loaded the new Web build and rendered login with zero Console errors. Authenticated Discount runtime interactions were unavailable; the local Windows UI helper could not initialize. Platform builds/widget tests are not runtime acceptance.
- D1-09–D1-12 and D1-15 handoff are complete; D1-13/D1-14 closure remains pending authenticated platform and POS/payment/receipt acceptance. Plan 1 is not yet ready for Plan 2. Full evidence, remaining gates and changed-file inventory: [Flutter handoff](../docs/discount_variant_flutter_handoff.md).
- Preserved the existing dirty Backend implementation and Plan 2. No backend code, shared financial behavior, packages, commits, deployment, migrations or operational data changes in this Flutter task.

### 2026-10-02 - Plan 1 pagination correction and authenticated acceptance

- Fixed the shared Discount product/variant picker: a failed new search no longer keeps the previous query's page metadata (Next stayed enabled and requested page 3 of the new query). Pagination metadata is now tied to the query that produced it (`pageQuery`), cleared on search change, navigation/counter disabled while loading or failed, and Retry repeats the failed query/page. Saved selections, unavailable metadata, stale-response protection and all/selected semantics unchanged. Files: `discount_targets_cubit.dart`, `discount_product_targets.dart`; permanent tests `discount_picker_pagination_test.dart` (7, product + variant, EN/AR; all fail without the fix).
- Serial checks: Discounts 83, POS Discount dialog 2, routing 2, route-request isolation 4 (all exit 0); scoped analysis clean (exit 0); full analysis 29 existing Info findings, no errors/warnings (exit 1, not modified); scoped format and `git diff --check` exit 0; release Web and Windows builds exit 0.
- Authenticated acceptance against an isolated testing backend (own Postgres/volume, `APP_ENV=testing`, seeded owner via real login): Web in a real browser and Windows via `integration_test/discount_variant_acceptance_live_test.dart` (exit 0) covered EN/AR + RTL, product/variant search and pagination, failure, retry and navigation, mixed all/selected, save/reopen/edit without field loss and unavailable-target correction; backend API and the Web POS UI confirmed Manual/Code sibling exclusion, percentage/per_order/per_unit amounts and POS = payment = receipt totals (52.92 in the UI scenario). Correction 2026-10-03: D1-13/D1-14 remain OPEN; callbacks and same-origin proxy do not satisfy required acceptance. Plan 1 is not ready for Plan 2. Evidence and findings F1 (backend CORS lacks `X-App-Locale` for cross-origin Web), F2 (pre-existing `DiscountsCubit.loadDiscounts` emit-after-close) and F3 (Windows form controls driven via callbacks): [acceptance report](../docs/verification/discount_variant_acceptance_2026-10-02.md).
- No backend application code, Plan 2, commits, deployment or operational data were touched; migrations/seed ran only on the isolated testing database.

### 2026-10-03 - Plan 1 remaining gap closure

- F2 lifecycle guards and regression tests implemented; late list/branch/reference/save/delete success/error completions ignore disposed state; single-write and mutation outcome semantics retained. Discounts tests 103 passed.
- F1 explicit CORS locale header added with six CORS/auth/bootstrap tests passing; real cross-origin browser login and authenticated Discounts EN/AR observed, denied-origin preflight blocked. No proxy.
- F3 callback bypasses removed from acceptance harness; actual pointer/text input, centered scrolling and hit-testing enforced. Windows POS/payment/receipt scenario added using guarded isolated fixtures. Final Windows integration test exit 0 (1 test, 04:03): actual EN/AR + RTL Create/Edit, search/page/failure/retry, selections, unavailable correction, sibling rejection, apply/pay/receipt. EN order 3 / AR order 4: 40 - 8 + 2.56 = 34.56 equal backend. Screenshots visually inspected.
- D1-13/D1-14 closed on observed interactions; final verification and Plan 1 closure: [Current evidence](../docs/verification/discount_variant_acceptance_2026-10-03.md).

Plan 1 final closure 2026-10-03: F1/F2/F3 and D1-13/D1-14 CLOSED on observed acceptance. Ready for Plan 2; Plan 2 has NOT started. Final Windows/Web Release builds exit 0; scoped analyze/format/Pint exit 0; full analyzer exit 1 with 29 prior Info only. See current acceptance evidence for every command exit and screenshots.


### 2026-10-03 - Plan 2 backend foundations D2-01 through D2-04

- Explicitly authorized bounded backend phase delivered: tenant-wide settings/defaults/version/audit, narrow Owner/Manager permission with revocation preservation, GET/PUT optimistic save and unavailable-engine guard, additive usage/snapshot/allocation/suppression schema. No Flutter implementation or builds.
- Plan 1 targeting, Manual/Code calculations, single application/usage, paid monetary snapshots and payment locking preserved. Defaults remain automatic off + single; engineReady=false. Stored future settings do not activate runtime behavior.
- Final Discount/Plan 1/financial concurrency regression: 52 passed / 580 assertions, exit 0. Final settings API after foreign-role guard: 7 passed / 98 assertions, exit 0. Foundation schema/race/rehearsal tests passed within the 67-test POS/configuration/receipt/refund group (66 pass / 1 pre-existing Finance assertion failure, exit 1). Eleven scoped PHP files pass Pint; syntax of all twelve touched PHP files and diff whitespace checks pass. Shared routes retains two reproduced baseline Pint findings. Full Laravel/Flutter suites are not claimed verified.
- Testing reused existing isolated acceptance PostgreSQL 16.13, accept-postgres, with separate empty normal/migration testing databases to preserve acceptance fixtures. No Docker config/image changes, operational migrations/data writes, commits or deployment.
- D2-01 through D2-04 checked; Plan 2 is not complete. D2-05 through D2-09 may begin as a separately authorized backend phase; engine activation remains gated on runtime/client/quote/concurrency integration. [Backend contract](../docs/discount_settings_backend_contract.md), [evidence, limitations and changed-file inventory](../docs/verification/discount_settings_foundation_2026-10-03.md).

### 2026-10-04 — Plan 2 Flutter/integration D2-10 through D2-18

- Implemented narrow Discount Settings management, all eight fields with a separate draft and explicit version-conflict review, Manager grants and session/route revocation, EN/AR help/defaults. Create/Edit supports integer priority and independently capability-gated Automatic, with Plan 1 full-detail/variant preservation and explicit clears.
- Implemented operational capabilities, header 2, serial cart/create recovery, typed exact money DTOs, full discount lists, explicit review and durable operation recovery, suppression/undo, selected payment-method ID, quote confirmation/stale refresh and payment identity recovery. Receipts/pre-bill/order history read saved discount rows and Backend aggregate totals.
- Windows payment acceptance failure was traced through actual HTTP/DTO/Cubit states to a Flutter test `expect` used in an asynchronous Dio callback. The precise fix uses callback-safe `expectSync` with the same matcher. It changes acceptance infrastructure only; no Backend or payment-calculation correction was needed. Focused probe fails before the fix and passes after; missing-header rejection remains tested.
- Final native Windows EN/AR acceptance passed 1 test, exit 0 (04:15): actual pointer/text Settings conflicts and save/reopen, variant form/retry/edit preservation, lost-create and operation recovery, cash tender quote, stale rejection requiring a second confirmation, lost-payment recovery without another payment and Backend receipt. EN order 14 / AR order 15: **40 − 8 + 2.56 = 34.56** across POS, quote/payment/receipt.
- Completed focused Flutter groups: 430, 91, 27 and final protocol probe 2 passed; final scoped analysis has no issues (exit 0). Earlier full Flutter: 1674 pass / 23 fail; HEAD comparison reproduced the same 22 historical failures, with the newly added final-source test subsequently passing focused verification. Full Backend: 1097 pass / 44 existing failures / 1 skip, exit 2; all 44 match the recorded HEAD baseline. Corrected focused Backend: 143 pass / 2095 assertions, exit 0. Full suites and HEAD comparison were not repeated after the user's instruction.
- Public rollout remains unavailable: **engineReady=false**, public Automatic creation false, automaticEnabled false, foundation CHECK intact. No D2-19, commit, deployment, operational migration, printer transport change or physical-printing claim. Remaining acceptance and exact final build/service-restoration evidence are recorded in [Flutter verification](../docs/verification/discount_settings_flutter_2026-10-04.md). Plan 2 is not marked complete.

- Final payment follow-up found a separate demonstrated Backend JSONB intent-key ordering defect. Canonicalizing only normalized intent keys removes false immediate `DISCOUNT_REVIEW_STALE`; calculations/compatibility/locks are unchanged. New PostgreSQL regression passes 1 test / 38 assertions, exit 0; prior Engine/Corrections/Concurrency group had 39 existing passes, while the new test initially expected the wrong HTTP status (combined exit 1, documented and corrected to contract 422).
- Real Arabic Web release order 16 proves **10.00 − 2.50 + 0.60 = 8.10**, selected cash ID 1, received `100.00`, stale quote requiring a second pointer confirmation and the same payment identity. Null-tender zero settlement passes orders 17/18 with one pay request each and Backend `zero_balance`. A demonstrated legacy receipt cash-label fallback was corrected by preserving canonical settlementMethod and using existing zero-balance localization; no tender/settlement/printer transport change.
- Final focused receipt/protocol tests: 16 pass, exit 0; scoped 6-path analysis clean, exit 0. A separately included historical tax-label test failed as already recorded by HEAD and remains untouched. Final Web/Windows Release rebuilds exit 0 (95.0 s / 80.8 s). After Web finished, native payment-only acceptance passed 1 test, exit 0 (00:35), order 19 total **34.56**, including durable recovery/stale confirmation/receipt. Full suites and HEAD comparison were not repeated.
- Final authority read confirms public creation/Automatic/engineReady false, version 28 defaults/cap null, the unchanged `NOT automatic_enabled` foundation CHECK and restored original Manager grants. Existing acceptance services are restored stopped (same container IDs and all volumes preserved); task Web/native processes are closed. D2-10/D2-12 and verification/documentation execution D2-17/D2-18 are checked; implemented D2-11/D2-13–D2-16 retain explicit live acceptance gaps. Standalone Windows Release interactions, native Manager/Employee sessions, final Web English/two tender IDs and live Automatic/suppression/pre-bill/history gaps remain open. D2-19 is not authorized or enabled.
- Final narrowed Discount Plan 2 continuation, 2026-10-05: Backend full completed once:1103 passed/44 failed/1 skipped,11686 assertions,exit2; all44 failure identities match the saved historical record, with no new identity (no new HEAD baseline). Flutter full before fixes:1682/22,exit1; all22 identities historical; no repeated full suite. Post-fix regressions:25 passed plus2 EN/AR receipt-label tests,exit0. Fixed the observed generic DISCOUNT label in Arabic receipts while retaining custom historical labels; scoped final analysis has no issues,exit0 (earlier full analysis30 infos/exit1 is retained). Final Windows Release100.2s and Web115.9s both exit0; final8-file format exit0. Acceptance services restored to base testing database with all Automatic capability gates false, then stopped with volumes retained; operational Cafe services remained running. Full gate ledger and actual evidence: ../docs/verification/discount_plan2_acceptance_2026-10-05_ar.md. Native Windows interaction, physical print and the remaining context/selection matrix are unverified; D2-11/13–16/19 stay open. No shift-management/printer-configuration/transport development, public activation, operational migration, commit, push or deployment.
