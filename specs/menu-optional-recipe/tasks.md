# Tasks: Optional Product Recipes and Recipe Inheritance

**Input**: Design documents from `/specs/menu-optional-recipe/`

**Prerequisites**: `spec.md` and `plan.md`

**Tests**: Every changed behavior requires focused automated coverage. Write the named failing test first, confirm it fails for the intended missing behavior, then implement the paired production task. Laravel tests MUST run serially against the shared PostgreSQL testing database.

**Scope rule**: Execute only the phase explicitly authorized by the user. Completing this task list is not blanket authorization to implement Phases 2â€“5 together. Never run a non-testing migration or backfill without separate authorization naming the environment and exact command.

**Organization**: Tasks are dependency-ordered and mapped to specification user stories. They are deliberately explicit so a lower-cost model can execute one task at a time without inventing behavior.

## Format: `Tnnn [P] [USn] Description`

- **[P]** means the task edits different files and can run in parallel after its dependencies are satisfied.
- **[US1â€“US7]** maps the task to a specification user story.
- Every implementation task names its allowed primary files and its required behavior.
- Do not mark a task complete from code inspection alone when it requires a command result.

---

## Phase 1: Setup and Brownfield Contract Locks

**Purpose**: Capture the current behavior before changing schema or services, and prevent a cheaper model from silently changing adjacent contracts.

- [x] T001 Read `specs/menu-optional-recipe/spec.md`, `specs/menu-optional-recipe/plan.md`, `.specify/memory/constitution.md`, and `plans/menu_optional_recipe_plan.md`; record no edits, and stop if any implementation request conflicts with the locked precedence, snapshot authority, or historical policy.
- [x] T002 Run `git status --short --untracked-files=all` from the repository root and record the pre-existing changed/untracked paths; preserve `plans/menu_optional_recipe_plan.md`, `.specify/feature.json`, `spec.md`, `plan.md`, and unrelated dirty work exactly unless a later task explicitly names a documentation update.
- [x] T003 Inspect the current route/controller/service/resource chain in `backend/routes/api.php`, `backend/app/Http/Controllers/Api/Admin/Catalog/RecipeConfigurationController.php`, `backend/app/Services/Catalog/RecipeConfigurationService.php`, `backend/app/Services/Catalog/RecipeResolver.php`, and `backend/app/Http/Resources/Catalog/ProductVariantResource.php`; do not edit yet, and note the existing request fields and resolve response shape that must remain compatible.
- [x] T004 [P] Inspect the current publishing/runtime chain in `backend/app/Services/Menu/MenuValidationService.php`, `backend/app/Services/Menu/MenuPreviewService.php`, `backend/app/Services/Menu/PublishedMenuSnapshotBuilder.php`, `backend/app/Services/Menu/PublishedMenuVersionComparisonService.php`, and `backend/app/Services/SaleConsumptionService.php`; do not edit and identify where missing recipes block and where pinned `baseRecipe` is consumed.
- [x] T005 [P] Inspect `backend/app/Services/SalesInvoiceInventoryConsumptionService.php`, `backend/app/Services/SalesInvoicePostingService.php`, and focused Sales Invoice tests; confirm the direct `variant_recipes` query is current configuration behavior and must be replaced only in Phase 3, not during Phase 2.
- [x] T006 [P] Inspect `windows_application/lib/features/menu_management/recipes/`, `windows_application/lib/features/menu_management/repositories/menu_catalog_repository.dart`, `windows_application/lib/features/menu_management/models/catalog_models.dart`, review models/views, `windows_application/lib/app/app_router.dart`, and both ARB files; do not edit until Phase 4.

**Checkpoint**: The implementer can state the current authority chain and compatibility surfaces without having changed production code.

---

## Phase 2: Foundational Backend Schema and Resolver (Blocks All Backend Stories)

**Purpose**: Add lossless product-recipe storage and one effective base-recipe authority before exposing new behavior.

### Tests first

- [x] T007 [US2] Add failing schema/model assertions in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php` for unique `(tenant_id, product_id)`, unique `(product_recipe_id, inventory_item_id)`, `decimal(18,6)`, deterministic `sort_order`, component cascade on recipe deletion, and no cascade deletion from an Inventory material; do not test legacy `recipes`/`recipe_lines` as part of this feature.
- [x] T008 [US2] Add failing resolver cases in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php` proving exact precedence: non-empty variant override replaces product components; otherwise non-empty product components inherit; otherwise source is `none`; modifier effects are applied only after base selection.
- [x] T009 [US2] Add failing batch-resolution/query-count coverage in the most focused existing Menu preview or catalog test to prove resolving multiple variants does not issue one product/variant recipe query per variant; keep the assertion tolerant of fixed framework queries but sensitive to linear N+1 growth.
- [x] T010 [US4] Add failing validation parity cases in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php` proving product components reuse the existing material eligibility, active state, unit, conversion, positive decimal, six-place scale, precision, and duplicate rules used by variant recipes.

### Schema and models

- [x] T011 [US2] Create one forward-only migration in `backend/database/migrations/` for `product_recipes` and `product_recipe_components` with the exact fields and constraints in FR-044â€“FR-047; do not touch `recipes`, `recipe_lines`, published versions, orders, movements, payments, or journals in this task.
- [x] T012 [P] [US2] Create `backend/app/Models/ProductRecipe.php` with tenant/product relationships, ordered components, guarded/fillable behavior matching `VariantRecipe`, and no soft-delete concept unless an existing active recipe model requires it.
- [x] T013 [P] [US2] Create `backend/app/Models/ProductRecipeComponent.php` matching `VariantRecipeComponent` field casting and relationships; quantity must remain decimal-safe and must not be converted to binary floating-point.
- [x] T014 [US2] Add `recipe()` to `backend/app/Models/Product.php` and any strictly required inverse relationships; preserve all existing Product lifecycle/scopes and do not modify `ProductVariant` behavior beyond any explicit eager-load relationship needed by the resolver.

### Shared resolver and validation

- [x] T015 [US2] Refactor component validation/serialization in `backend/app/Services/Catalog/RecipeConfigurationService.php` only enough for product and variant base recipes to share one rule path; preserve modifier `add`/`remove` validation and explicit empty modifier-profile suppression unchanged.
- [x] T016 [US2] Implement one effective base-recipe method in `backend/app/Services/Catalog/RecipeConfigurationService.php` returning exactly `source`, `hasOverride`, sorted `overrideComponents`, and sorted `effectiveComponents`; treat only a non-empty variant parent as an override, fall back to non-empty product components, otherwise return `none` and empty components.
- [x] T017 [US2] Add a batch/eager-loaded effective-state method in `backend/app/Services/Catalog/RecipeConfigurationService.php` for a collection of variants and update the focused query-count test from T009; do not add a second precedence implementation in resources or Menu services.
- [x] T018 [US2] Update `backend/app/Services/Catalog/RecipeResolver.php` to start from the shared effective base components, then apply existing modifier-profile precedence and arithmetic; preserve the existing resolve output shape, canonical base-unit conversion, aggregate remove validation, selection rules, and deterministic ordering.
- [x] T019 Run the focused foundation command `docker compose exec -T backend php artisan test --filter='RecipeConfigurationApiTest'`; resolve only T007â€“T018 failures, record the exact exit code/result, and stop if PostgreSQL or Docker is unavailable rather than substituting SQLite.

**Checkpoint**: Product storage exists, effective precedence has one backend authority, and the existing resolver shape remains compatible. No routes, publishing, POS, Sales Invoice, or Flutter behavior is claimed complete.

---

## Phase 3: User Story 2 â€” Configure Product Inheritance and Variant Replacement (Priority: P1)

**Goal**: Expose product base recipes and additive variant effective-state contracts without breaking older variant clients.

**Independent Test**: Configure a product recipe, observe inheritance on two variants, add a full override to one, resolve both, and verify sources, editable arrays, effective arrays, decimals, ordering, and modifier results.

### Tests first

- [x] T020 [US2] Add failing product GET/PUT contract tests in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php` for exact `data.productId`, `configured`, and component envelopes, including absent state, decimal strings, stable sort order, inactive non-archived product write, and strict component validation.
- [x] T021 [US2] Add failing variant GET/PUT response tests in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php` for `variantId`, `hasOverride`, exact `source`, `components`, `overrideComponents`, and `effectiveComponents`; assert `components == overrideComponents` and never equals inherited data unless an override exists.
- [x] T022 [US2] Add failing older-client compatibility cases in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php`: existing non-empty `{components:[...]}` PUT creates a complete override; existing resolve request/response is unchanged; inherited data never appears in legacy editable `components`.
- [x] T023 [US2] Add failing summary cases in `backend/tests/Feature/Admin/Catalog/CatalogApiTest.php` and the most focused preview test for `effectiveRecipeConfigured`, `effectiveRecipeComponentCount`, `recipeSource`, `hasRecipeOverride`, plus retained legacy aliases equal to effective state.

### Implementation

- [x] T024 [US2] Add tenant-scoped product recipe GET and PUT controller methods in `backend/app/Http/Controllers/Api/Admin/Catalog/RecipeConfigurationController.php`; use `TenantContext`, existing catalog authorization middleware, the shared service, exact validation field names, and the exact `data` envelopeâ€”never accept a client tenant ID.
- [x] T025 [US2] Register product recipe GET/PUT routes in `backend/routes/api.php` beside existing catalog recipe routes with the same authenticated tenant/admin permission boundary; do not add unauthenticated or header-only compatibility routes.
- [x] T026 [US2] Implement transactional product read/replace methods in `backend/app/Services/Catalog/RecipeConfigurationService.php`; validate all components before mutation, replace atomically, audit identifiers/counts without secrets, and return canonical decimal strings and sort order.
- [x] T027 [US2] Change variant recipe read/replace response assembly in `backend/app/Services/Catalog/RecipeConfigurationService.php` to the locked override/effective contract; do not return inherited components via `components` and do not change modifier profile response semantics.
- [x] T028 [US2] Update `backend/app/Http/Resources/Catalog/ProductVariantResource.php` and the query/eager-load path that feeds it so the four new summary fields and two legacy effective aliases are emitted without per-row queries.
- [x] T029 [US2] Update `backend/app/Services/Menu/MenuPreviewService.php` only for effective recipe summary/source fields required by T023; do not yet change publication blockers or snapshot runtime behavior.
- [x] T030 [US2] Run `docker compose exec -T backend php artisan test --filter='RecipeConfigurationApiTest|CatalogApiTest'` serially and record results; fix only Phase 2/US2 regressions in the named recipe/model/controller/resource/route paths.

**Checkpoint**: Product recipes and variant inheritance/overrides are independently usable through the locked API, and old clients can still create full overrides safely.

---

## Phase 4: User Story 3 â€” Clear Recipes Without Ambiguous Empty Rows (Priority: P1)

**Goal**: Normalize empty product/variant base recipes to absence and provide idempotent DELETE semantics.

**Independent Test**: Exercise PUT `components: []`, DELETE, and repeated DELETE for product and variant states with/without inheritance, then inspect tables and returned envelopes.

### Tests first

- [x] T031 [US3] Add failing product clear tests in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php`: PUT-empty and DELETE remove parent/components, return `configured:false`, preserve all variant overrides byte-for-byte, audit a real clear, and make repeated DELETE succeed without duplicate state changes.
- [x] T032 [US3] Add failing variant clear tests in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php`: PUT-empty and DELETE remove the override parent, return inherited product state or `none`, keep `components`/`overrideComponents` empty, and make repeated DELETE idempotent.
- [x] T033 [US3] Add a focused concurrent replace/clear test in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php` or a new narrowly named PostgreSQL concurrency test proving the unique constraints and transaction path cannot leave duplicate or empty parents or partial components.

### Implementation

- [x] T034 [US3] Implement shared transactional product clear/delete behavior in `backend/app/Services/Catalog/RecipeConfigurationService.php`; PUT-empty must call the same operation as DELETE, delete only the product parent, leave variant rows untouched, and return normalized state.
- [x] T035 [US3] Implement shared transactional variant clear/delete behavior in `backend/app/Services/Catalog/RecipeConfigurationService.php`; PUT-empty must not `firstOrCreate`, DELETE must be safe when absent, and both must return current inherited/effective state.
- [x] T036 [US3] Add product and variant DELETE controller methods in `backend/app/Http/Controllers/Api/Admin/Catalog/RecipeConfigurationController.php` returning the same `data` contracts as GET/PUT; do not return message-only responses.
- [x] T037 [US3] Register exact product and variant DELETE routes in `backend/routes/api.php` under the existing authenticated Catalog boundary.
- [x] T038 [US3] Add or adjust audit calls in `backend/app/Services/Catalog/RecipeConfigurationService.php` so create/replace/clear/override removal are tenant-scoped and distinguish actual changes from idempotent absence without logging component secrets or unrelated data.
- [x] T039 [US3] Run `docker compose exec -T backend php artisan test --filter='RecipeConfigurationApiTest'` and record exact results; inspect `product_recipes` and `variant_recipes` assertions to confirm zero empty parent rows.

**Checkpoint**: Empty base recipes cannot persist, both DELETE endpoints are idempotent, and product clear never damages overrides.

---

## Phase 5: User Stories 4 and 5 â€” Strict Safety, Lifecycle, Tenant, and Authorization (Priorities P1/P2)

**Goal**: Preserve strict configured-recipe correctness while making inactive entities configurable, archived entities read-only, and every relationship tenant-safe.

**Independent Test**: Read/replace/clear inactive entities, read archived state through an authorized history path, reject archived mutations, diagnose inactive materials, and reject all foreign/unauthorized identifiers without disclosure.

### Tests first

- [x] T040 [P] [US4] Extend `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php` with product and variant cases for foreign, inactive, archived, ineligible, duplicate, invalid quantity, invalid unit, inactive/missing conversion, and non-representable converted quantity; every failed replacement must preserve the complete previous recipe.
- [x] T041 [P] [US5] Add lifecycle tests in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php`: inactive non-archived product/variant GET/PUT/clear succeeds without reactivation; archived product/variant recipe read succeeds only in the authorized lifecycle/history context; every archived mutation fails until restoration.
- [x] T042 [P] [US5] Add tenant/authorization matrix coverage in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php` for every product/variant GET/PUT/DELETE/resolve route and nested material ID; foreign resources must not be disclosed or changed, and an authenticated actor lacking Catalog recipe authority must be denied.
- [x] T043 [US4] Add diagnostic-read coverage in `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php`: a stored inactive/archived material remains serialized for diagnosis, but resubmitting the same component as new configuration is rejected until replaced with an eligible material.

### Implementation

- [x] T044 [US5] Refactor tenant-scoped product/variant lookup helpers in `backend/app/Http/Controllers/Api/Admin/Catalog/RecipeConfigurationController.php` only as needed to support inactive records and explicitly authorized archived reads; do not widen operational lists or permit archived writes.
- [x] T045 [US5] Add one shared writable-entity guard in `backend/app/Services/Catalog/RecipeConfigurationService.php` covering product and variant archive state; keep inactivity writable and never translate archive/deactivation into recipe deletion.
- [x] T046 [US4] Adjust recipe component serialization/read loading in `backend/app/Services/Catalog/RecipeConfigurationService.php` and existing material resource helpers so stored unavailable material references remain diagnosable without weakening save validation or inventing fallback names/units.
- [x] T047 [US4] Verify all product/variant write methods validate the full replacement before entering destructive mutation, execute inside one DB transaction, and preserve previous state on any validation or audit failure; add a regression assertion before changing code if a gap is found.
- [x] T048 [US5] Review recipe route middleware and service entry points in `backend/routes/api.php`, `RecipeConfigurationController.php`, and `RecipeConfigurationService.php`; add a focused route-permission assertion if none exists, and do not rely on Flutter role checks.
- [x] T049 [US4] Run `docker compose exec -T backend php artisan test --filter='RecipeConfigurationApiTest'`; record exact results and do not proceed while any lifecycle, tenant, permission, or atomicity case fails.

**Checkpoint**: Configured data stays strict, archived history remains readable but immutable, inactive entities remain configurable, and tenant/permission isolation is proven.

---

## Phase 6: Migration and Backfill Safety

**Goal**: Copy only an unambiguous default recipe to the new product layer, preserve all non-empty variant recipes as overrides, normalize empty variant parents, and make replay/recovery safe.

### Tests first

- [x] T050 [US2] Create a focused migration/backfill test in `backend/tests/Feature/Admin/Catalog/ProductRecipeBackfillTest.php` covering one unambiguous default variant with a non-empty recipe: product components are copied in deterministic order and the original variant recipe/components remain unchanged as an override.
- [x] T051 [P] [US2] Extend `ProductRecipeBackfillTest.php` for multiple non-empty variants, including the default: every variant remains an explicit override and no automatic deduplication occurs.
- [x] T052 [P] [US3] Extend `ProductRecipeBackfillTest.php` for empty variant parent rows: they become absence/no override while non-empty rows remain untouched.
- [x] T053 [P] [US2] Extend `ProductRecipeBackfillTest.php` for missing default, multiple defaults, foreign-tenant inconsistency, and repeated execution: no guessing, no cross-tenant copy, deterministic reconciliation counts, and replay without duplicate parents/components.
- [x] T054 [P] [US6] Extend `ProductRecipeBackfillTest.php` to checksum or compare published versions, pinned orders, movements, payments, journals, legacy `recipes`, and `recipe_lines` before/after; all must remain unchanged.

### Implementation

- [x] T055 Implement the backfill inside the new migration or a migration-local helper under `backend/database/migrations/`: scope every query by tenant, define unambiguous default as exactly one default variant, copy only non-empty components, retain all non-empty overrides, delete only confirmed empty variant parents, and never access historical or legacy recipe tables for mutation.
- [x] T056 Make T055 restart-safe using unique keys plus idempotent inserts/upserts and stable ordering; return or record deterministic reconciliation counts suitable for test assertions, and fail closed on tenant/referential inconsistency rather than guessing.
- [x] T057 Document the migration's roll-forward recovery comments in the migration itself: fix the cause and rerun safely; do not depend on destructive production rollback. Ensure `down()` only removes new tables for testing/development and is never presented as the production recovery path.
- [x] T058 Run only the migration-focused testing command `docker compose exec -T backend php artisan test --filter='ProductRecipeBackfillTest|RecipeConfigurationApiTest'`; do not run migrations against a non-testing environment and record exact results.

**Checkpoint**: Backfill is lossless, deterministic, tenant-safe, replay-safe, and demonstrably leaves all historical and legacy records unchanged.

---

## Phase 7: User Story 1 â€” Menu Review and Schema-v3 Publication (Priority: P1)

**Goal**: Allow absent effective recipes through Review & Publish while continuing to block configured-invalid recipes and freezing effective state into schema-v3.

**Independent Test**: Validate and publish variants with none/product/override recipes, inspect issue severity and snapshot JSON, and prove invalid configured data still blocks.

### Tests first

- [x] T059 [US1] Update/add failing cases in `backend/tests/Feature/Admin/MenuValidation/MenuValidationApiTest.php`: no effective recipe emits exactly `VARIANT_RECIPE_MISSING` at warning severity, validation remains valid, `VARIANT_RECIPE_EMPTY` is absent for normalized state, and configured-invalid product/override/modifier components remain blocking errors.
- [x] T060 [US1] Add failing publishing cases in `backend/tests/Feature/Admin/MenuPublishing/MenuPublishingApiTest.php` for Scenario A (`baseRecipe: []`), Scenario B (product inheritance), Scenario C (full variant replacement), Scenario D (modifier with no effect), and Scenario E (invalid configured recipe blocks).
- [x] T061 [P] [US6] Add failing immutability/version cases in `backend/tests/Feature/Admin/MenuVersionHistory/PublishedMenuVersionHistoryApiTest.php`: schema remains 3, effective recipe changes affect only new versions/comparison, and older payload/checksum/history remain unchanged.
- [x] T062 [US2] Add failing preview summary/count/source cases in the focused Menu preview API test so product inheritance and overrides are visible without exposing inherited data as editable override state.

### Implementation

- [x] T063 [US1] Update `backend/app/Services/Menu/MenuValidationService.php` to use the shared effective resolver: emit `VARIANT_RECIPE_MISSING` warning for empty state, never emit normalized-state `VARIANT_RECIPE_EMPTY`, and retain all configured component/modifier blockers and selection rules.
- [x] T064 [US2] Update `backend/app/Services/Menu/MenuPreviewService.php` to use batched effective state for configured/count/source summaries; avoid N+1 queries and keep unrelated price/availability output unchanged.
- [x] T065 [US1] Update `backend/app/Services/Menu/PublishedMenuSnapshotBuilder.php` to serialize sorted effective components into the existing variant `baseRecipe`, including exact empty array; retain schema version 3, modifier adjustment shape, canonical conversion, and no live-runtime hint/fallback field.
- [x] T066 [US6] Update `backend/app/Services/Menu/PublishedMenuVersionComparisonService.php` only as needed so effective base-recipe changes are compared through existing schema-v3 fields; do not rewrite previous payloads.
- [x] T067 [US1] Run serially `docker compose exec -T backend php artisan test --filter='MenuValidationApiTest|MenuPublishingApiTest|PublishedMenuVersionHistoryApiTest'`; record exact results and stop if missing recipes still block or schema changes.

**Checkpoint**: Menu Review is non-blocking for absence, strict for invalid configuration, and publication freezes exact effective state into schema-v3.

---

## Phase 8: User Stories 1 and 6 â€” POS Payment, Warehouse, COGS, and Historical Safety (Priority: P1)

**Goal**: Treat an explicitly empty pinned recipe as valid zero consumption while preserving fail-closed historical behavior and full Inventory authority for non-empty recipes.

**Independent Test**: Pay empty, non-empty, and mixed pinned orders with/without warehouses, retry payment, change live recipes, and verify exact movements, COGS, and immutable history.

### Tests first

- [x] T068 [US1] Add Scenario A/G failing cases to `backend/tests/Feature/ProductInventoryTrackingE2ETest.php` or `SaleAccountingApiTest.php`: stock-tracked pinned `baseRecipe: []` pays successfully, creates no recipe movement, snapshots item/order inventory-derived COGS as exactly zero, and requires no warehouse solely for tracking.
- [x] T069 [US1] Add mixed-order and non-empty regression cases: an order with any actual recipe consumption still requires an eligible authoritative warehouse; empty lines produce no movement; non-empty lines preserve canonical quantities, WAC COGS, and existing negative-stock policy.
- [x] T070 [US6] Add Scenario H to `backend/tests/Feature/RealSaleIntegrationTest.php` or the closest snapshot-aware order test: after pinning, change/delete live product/variant recipes and prove resume/payment uses frozen schema-v3 `baseRecipe` only.
- [x] T071 [US6] Add fail-closed cases for missing/incompatible pinned snapshot or missing sold variant node and contrast them with an explicitly present empty `baseRecipe`; no current live recipe may rescue the former.
- [x] T072 [US1] Add payment retry/concurrency and rollback assertions in `backend/tests/Feature/SaleAccountingApiTest.php`: empty lines never double-write effects; non-empty movement idempotency remains; an error on a later consuming line rolls back earlier owned effects and payment completion.

### Implementation

- [x] T073 [US1] Refactor `backend/app/Services/SaleConsumptionService.php` to distinguish "compatible pinned variant with empty baseRecipe" from "missing/incompatible snapshot data" before warehouse resolution; empty is valid and missing stays fail-closed.
- [x] T074 [US1] In `SaleConsumptionService.php`, implement the empty-line path through existing COGS snapshot helpers: write exact zero item/order COGS as required, create no recipe-based Inventory movement, do not synthesize a `sale_consumptions` recipe event, and continue payment.
- [x] T075 [US1] Update `SaleConsumptionService.php` payment preflight to scan actual pinned payable recipe components and call `PosInventoryWarehouseResolver` only when at least one line consumes; preserve branch/warehouse validation for non-empty and mixed orders.
- [x] T076 [US6] Preserve `publishedSnapshot()` and variant-node lookup as the sole POS recipe authority in `SaleConsumptionService.php`; remove no historical safety checks and add no call to `RecipeConfigurationService` or live recipe tables.
- [x] T077 [US1] Run serially `docker compose exec -T backend php artisan test --filter='ProductInventoryTrackingE2ETest|SaleAccountingApiTest|RealSaleIntegrationTest'`; record exact results, including any unrelated failures, and do not call timeout/startup output a pass.

**Checkpoint**: No recipe-related path can publish successfully and then fail payment merely because pinned `baseRecipe` is empty; non-empty and historical safety behavior remains authoritative.

---

## Phase 9: User Story 1 â€” Sales Invoice Effective Recipe and Zero Consumption (Priority: P1)

**Goal**: Make manual Sales Invoice preview/posting use current effective recipe authority and match POS optional-recipe outcomes without pretending invoices use pinned snapshots.

**Independent Test**: Preview/post invoices with no/product/override recipes, compare non-empty Inventory results with POS, and verify empty lines create no movement and zero COGS.

### Tests first

- [x] T078 [US1] Add failing empty-recipe preview/post cases in `backend/tests/Feature/SalesInvoicePhaseTwoApiTest.php`: active valid product/variant with no effective recipe posts normally, creates no recipe movement, and records exactly zero inventory-derived COGS without a recipe-only warehouse requirement.
- [x] T079 [US2] Add failing product inheritance and full override cases in `SalesInvoicePhaseTwoApiTest.php`, including modifier behavior only if the existing invoice contract accepts selections; assert exact canonical quantities and source-independent final Inventory results.
- [x] T080 [P] [US1] Extend `backend/tests/Feature/SalesInvoicePosCrossPathCharacterizationTest.php` for equal empty/non-empty effective outcomes while explicitly retaining the authority distinction: POS reads pinned snapshot; Sales Invoice reads current effective configuration.
- [x] T081 [US4] Add configured-invalid, foreign tenant/material, inactive/archived material, warehouse, rollback, and retry/idempotency cases to the focused Sales Invoice suite; no partial movement, COGS, invoice status, or journal may persist on failure.

### Implementation

- [x] T082 [US2] Inject and call the shared effective recipe authority from `backend/app/Services/SalesInvoiceInventoryConsumptionService.php`; remove the direct `variant_recipes`/`variant_recipe_components` join after tests cover it, and do not copy precedence logic into the invoice service.
- [x] T083 [US1] Implement empty effective recipe as zero consumption in `SalesInvoiceInventoryConsumptionService.php`: no recipe movement, exact zero inventory-derived COGS, and no warehouse requirement solely for an empty line.
- [x] T084 [US1] Preserve existing non-empty `SalesInventoryMovementService`, conversion, warehouse, WAC, transaction, insufficient-stock, rollback, and idempotency behavior in `SalesInvoiceInventoryConsumptionService.php` and `SalesInvoicePostingService.php`; make no pricing, tax, discount, or journal redesign.
- [x] T085 [US1] Run serially `docker compose exec -T backend php artisan test --filter='SalesInvoicePhaseTwoApiTest|SalesInvoicePosCrossPathCharacterizationTest|SaleAccountingApiTest'`; record exact results and resolve only optional-recipe regressions in the named services/tests.

**Checkpoint**: POS and Sales Invoice agree on empty/non-empty consumption outcomes while retaining their correct pinned-versus-current authorities.

---

## Phase 10: User Story 7 â€” Flutter Contract Parsing and Repository Compatibility (Priority: P2)

**Goal**: Parse additive backend fields safely and expose product recipe and variant removal APIs without breaking older response parsing.

**Independent Test**: Parse old/new JSON, load inherited state, save a full override, clear product recipe, and delete an override while capturing exact routes/payloads.

### Tests first

- [x] T086 [P] [US7] Add model parsing tests in `windows_application/test/features/menu_management/recipe_cubits_test.dart` or a new narrowly named `recipe_models_test.dart` for `ProductRecipe`, new `VariantRecipe` fields, exact `source` values, old response fallback, decimal strings, and the rule that editable components come only from override data.
- [x] T087 [P] [US7] Add repository contract tests in the existing Menu repository test seam for product GET/PUT/DELETE, variant DELETE, unchanged variant PUT request fields, and resolve compatibility; assert exact `/api/v1/admin/catalog/...` paths and `data` envelope parsing.
- [x] T088 [P] [US7] Extend catalog/review model tests for additive summary fields and retained legacy aliases so older JSON without new fields remains parseable and new JSON exposes effective/source/override state.

### Implementation

- [x] T089 [US7] Add `ProductRecipe`, `RecipeSource`, and expanded `VariantRecipe` parsing in `windows_application/lib/features/menu_management/recipes/models/recipe_models.dart`; preserve `RecipeComponent` decimal strings and do not infer inheritance from list contents when explicit fields exist.
- [x] T090 [US7] Add abstract and Dio implementations for product recipe GET/PUT/DELETE and variant DELETE in `windows_application/lib/features/menu_management/repositories/menu_catalog_repository.dart`; keep existing non-empty variant save and resolve methods compatible, validate envelopes, and map unknown server failures to the established localized-safe error path.
- [x] T091 [US7] Add new summary parsing to `windows_application/lib/features/menu_management/models/catalog_models.dart` and `windows_application/lib/features/menu_management/review/models/review_models.dart`; keep `recipeConfigured` and `recipeComponentCount` available as effective-state compatibility fields.
- [x] T092 [US7] Run focused Flutter model/repository tests with the exact relevant `flutter test` file paths and record results; do not begin UI tasks until parsing and route contracts pass.

**Checkpoint**: The Flutter data layer understands own versus effective state and remains compatible with old/additive backend responses.

---

## Phase 11: User Story 7 â€” Flutter State and Existing Workspace UX (Priority: P2)

**Goal**: Let managers edit product base recipes and variant overrides without ever saving inherited values as an override, while preserving Windows/Web and EN/AR behavior.

**Independent Test**: Load none/product/override states, create/remove overrides, simulate empty/non-empty recipes, inspect localized readiness warnings, and verify focus/navigation on Windows/Web-sized surfaces.

### Tests first

- [x] T093 [US7] Add Cubit tests in `windows_application/test/features/menu_management/recipe_cubits_test.dart`: inherited effective components render but never enter the editable override draft; save uses only user-authored override components; remove reloads server state; empty successful resolve is success, not error; stale async responses cannot overwrite newer state.
- [x] T094 [P] [US7] Add widget cases in `windows_application/test/features/menu_management/recipe_views_test.dart` for Product Base Recipe, Uses product recipe, Variant override configured, No effective recipe, No material effect, inactive stored material diagnosis, clear/remove confirmation, loading/error/retry/empty states, and no blocking presentation for missing recipe.
- [x] T095 [P] [US7] Extend `windows_application/test/features/menu_management/readiness_issue_browser_test.dart` so `VARIANT_RECIPE_MISSING` is categorized/presented as a localized non-blocking warning while canonical code remains untranslated and configured-invalid issues remain errors.
- [x] T096 [P] [US7] Extend `windows_application/test/features/menu_management/recipe_navigation_test.dart` for product recipe and variant override paths, route context, back navigation, and malformed IDs; do not add a replacement application shell.
- [x] T097 [P] [US7] Add EN/AR widget assertions for RTL/LTR, focus traversal, semantics labels, keyboard operation, and Windows/Web width behavior in the existing recipe widget tests; no raw backend/exception text may be rendered.

### Implementation

- [x] T098 [US7] Refactor `windows_application/lib/features/menu_management/recipes/controllers/recipe_cubits.dart` to maintain separate editable override/product drafts and effective display state; use request identity/race protection already established in the feature and preserve failed drafts for retry.
- [x] T099 [US7] Update `windows_application/lib/features/menu_management/recipes/views/variant_recipe_screen.dart` to distinguish inherited, overridden, and empty states, provide explicit remove-override action, and bind editors only to own components; do not redesign unrelated Product screens.
- [x] T100 [US7] Add the product base-recipe section within the existing Recipe & Materials workspace using `windows_application/lib/features/menu_management/views/product_detail_screen.dart` and the smallest required recipe view file; reuse current component editor/design system and provide add/edit/clear/retry actions.
- [x] T101 [US7] Update `windows_application/lib/features/menu_management/recipes/views/recipe_simulation_screen.dart` so an empty resolved list is a localized successful "no materials consumed" result; keep backend resolution authoritative and do not compute recipe arithmetic in Flutter.
- [x] T102 [US7] Update variant list/detail state in `windows_application/lib/features/menu_management/variants/controllers/variants_cubit.dart`, `variants_state.dart`, `variants/views/variants_screen.dart`, and directly used detail state only as necessary to show effective/source/override summaries without per-variant API calls.
- [x] T103 [US7] Update readiness presentation under `windows_application/lib/features/menu_management/review/` so missing recipe warning does not disable publication; do not translate or rename canonical codes and do not downgrade configured-invalid errors.
- [x] T104 [US7] Add only the required product recipe route(s) and route builders in `windows_application/lib/app/app_router.dart`; retain existing variant and simulation URLs, shell, guards, and malformed-context failure behavior.
- [x] T105 [US7] Add English and Arabic strings to `windows_application/lib/l10n/app_en.arb` and `app_ar.arb`, regenerate localizations using the repository's normal Flutter mechanism, and inspect generated changes only under `windows_application/lib/l10n/`; never hand-edit generated localization Dart files unless the repository workflow explicitly requires it. Verified by the user-observed `flutter gen-l10n` completion from `windows_application`; generated localization changes remain scoped to `windows_application/lib/l10n/` and were not hand-edited.
- [x] T106 [US7] Run the focused recipe/review/navigation Flutter tests named in T093â€“T097, then run `flutter analyze`; record exact commands/results and do not treat a timeout or startup-only output as passed.

**Checkpoint**: Windows/Web managers can safely distinguish and edit product, inherited, override, modifier, and empty states in EN/AR without client-side business-rule duplication.

---

## Phase 12: Cross-Cutting Hardening and Independent Closure

**Purpose**: Prove the implementation matches every locked contract across database, backend, runtime, history, and Flutter before completion is claimed.

- [x] T107 Review every changed PHP/Dart file against FR-001â€“FR-057 and Scenarios Aâ€“H; add a focused regression test before fixing any discovered gap, and do not rewrite `spec.md` to hide an implementation deviation.
- [x] T108 Search changed production code for duplicate precedence, direct live recipe access from POS, direct `variant_recipes` access from Sales Invoice, invented fallback materials/conversions/warehouses, client tenant IDs, raw exception UI text, and changes to modifier-selection rules; remove only confirmed feature-introduced violations.
- [x] T109 Run the full focused backend sequence serially: `RecipeConfigurationApiTest`, `ProductRecipeBackfillTest`, `CatalogApiTest`, `MenuValidationApiTest`, `MenuPublishingApiTest`, `PublishedMenuVersionHistoryApiTest`, `ProductInventoryTrackingE2ETest`, `SaleAccountingApiTest`, `RealSaleIntegrationTest`, `SalesInvoicePhaseTwoApiTest`, and `SalesInvoicePosCrossPathCharacterizationTest`; record each exact result.
- [x] T110 Run the broader relevant Laravel checkpoint serially for Menu, POS/order lifecycle, Inventory, Finance/accounting, and Sales Invoice tests; use the repository's Docker PostgreSQL environment, report all unrelated pre-existing failures separately, and never run suites concurrently against the shared database.
- [x] T111 Run all focused Flutter Menu Management recipe/review/navigation/model/repository tests and `flutter analyze`; report every failure, timeout, or unavailable tool accurately.
- [x] T112 Inspect the migration/backfill on isolated testing data and record reconciliation counts for products examined, unambiguous defaults, copied product recipes, retained non-empty overrides, removed empty parents, ambiguous/missing defaults, and rejected inconsistencies; do not execute on staging/production. Verified in isolated PostgreSQL with 500 products across 5 tenants, 1,000 variant parents, first-run and idempotent replay; 7 tests and 55 assertions passed in 39.58s.
- [x] T113 Verify historical immutability by comparing published version payload/checksum, pinned orders, movements, payments, journals, and legacy recipe tables before/after configuration edits and test backfill; any mutation is a release blocker.
- [x] T114 Run `git diff --check`, `git status --short --untracked-files=all`, and inspect the complete diff for secrets, fake production state, destructive commands, generated churn, unrelated formatting/refactoring, accidental roadmap edits, and changes outside the approved feature paths.
- [x] T115 Prepare the final handoff with exact changed files, migration/backfill behavior, final API contract, observed commands and exit results, skipped/timed-out/unverified items, and explicit confirmation that schema-v3 history, older clients, tenant isolation, and unrelated features were preserved.

**Final checkpoint**: Do not claim completion unless all selected implementation phases and T107â€“T114 have observed passing evidence. A missing database, timeout, interrupted command, unrun test, or partial output remains unverified.

---

## Dependencies and Execution Order

### Phase dependencies

- **Phase 1 (T001â€“T006)**: No dependencies; read-only baseline.
- **Phase 2 (T007â€“T019)**: Depends on Phase 1 and blocks every backend behavior. Tests T007â€“T010 precede T011â€“T018; models T012/T013 may proceed in parallel after T011 exists; T019 is the gate.
- **Phase 3 / US2 (T020â€“T030)**: Depends on Phase 2. Tests T020â€“T023 precede route/service/resource work. Implement service T026/T027 before controller/route integration is considered complete.
- **Phase 4 / US3 (T031â€“T039)**: Depends on Phase 3 response contracts. Tests precede clear/delete implementation.
- **Phase 5 / US4+US5 (T040â€“T049)**: Depends on Phases 3â€“4. Test tasks T040â€“T043 may be prepared in parallel; production changes share core files and should be sequential.
- **Phase 6 migration (T050â€“T058)**: Depends on foundational schema/resolver semantics and may be developed before publishing/runtime, but must pass before Phase 2 backend delivery is accepted.
- **Phase 7 publishing (T059â€“T067)**: Depends on backend API/resolver and migration completion.
- **Phase 8 POS (T068â€“T077)**: Depends on published effective schema-v3 behavior from Phase 7.
- **Phase 9 Sales Invoice (T078â€“T085)**: Depends on the shared resolver; it can be prepared alongside Phase 8 only if no shared test/database commands run concurrently. Complete both before runtime acceptance.
- **Phase 10 Flutter data (T086â€“T092)**: Depends on the final backend API contract from Phases 3â€“5.
- **Phase 11 Flutter UX (T093â€“T106)**: Depends on Phase 10 and backend warning/runtime contracts.
- **Phase 12 closure (T107â€“T115)**: Depends on every authorized implementation phase.

### Story dependency graph

```text
Baseline
  -> Schema + shared effective resolver
      -> US2 product inheritance/full override
          -> US3 normalized clear/delete
              -> US4 strict configured safety + US5 lifecycle/tenant isolation
                  -> safe backfill
                      -> US1 Menu Review/publishing
                          -> US1 POS runtime + US6 history
                          -> US1 Sales Invoice runtime
                              -> US7 Flutter parsing/repository
                                  -> US7 Flutter state/UX
                                      -> independent closure
```

### Safe parallel opportunities

- T004â€“T006 are read-only and may run together.
- T012 and T013 target separate new model files after migration structure is fixed.
- T040â€“T043 are test additions but must not be assigned concurrently if they edit the same test file.
- T051â€“T054 are conceptually parallel but should be serialized when editing one migration test file.
- T086â€“T088 may run in parallel only if they use separate test files.
- T094â€“T097 may run in parallel only when each edits a different test file.
- Never parallelize Laravel test commands against the shared PostgreSQL testing database.
- Never parallelize edits to `RecipeConfigurationService.php`, `RecipeConfigurationController.php`, `backend/routes/api.php`, `SaleConsumptionService.php`, `menu_catalog_repository.dart`, `recipe_cubits.dart`, or the same test file.

---

## Implementation Rules for a Lower-Cost Model

1. Execute exactly one task ID at a time. Before editing, reread the referenced spec FRs/scenario and the matching plan design decision.
2. For test tasks, add only the named failing behavior, run only its focused test class, and confirm the failure is caused by missing intended behaviorâ€”not syntax, fixture, database, or environment failure.
3. For production tasks, edit only the named paths plus directly required imports. If another file seems necessary, stop and justify it against a specific requirement before changing it.
4. Never invent recipe components, quantities, conversions, materials, warehouses, tenant IDs, or live fallbacks. Empty is a valid result.
5. Never implement precedence twice. All backend consumers use the shared effective resolver; Flutter displays backend state and does not reproduce business rules.
6. Keep `components` on variant GET/PUT/DELETE equal to explicit override components only. Use `effectiveComponents` for inherited/display state. This rule prevents accidental override creation.
7. Keep explicit empty modifier profiles. Normalize only product base recipes and variant base overrides to absence.
8. Scope the product/variant and every nested material/modifier relationship to authenticated `TenantContext` before reading, counting, validating, or mutating.
9. Validate the full replacement before deleting old components. Use one transaction for parent/components/audit. A failed write must preserve the previous complete state.
10. POS must read only its compatible pinned published snapshot. Sales Invoice uses current effective configuration through the shared Menu resolver. Do not swap or blend these authorities.
11. Preserve schema version 3 and historical records. Never update old published payloads, orders, movements, payments, or journals during recipe edits/backfill.
12. Preserve Inventory authority for base units, conversions, warehouse movement, WAC, and COGS. Do not calculate or round those values independently in Menu, Finance, or Flutter.
13. Use decimal strings and existing exact helpers. Never cast persisted recipe quantities or COGS inputs to binary floating-point.
14. Do not change modifier selection requirements, Menu/POS layouts outside the existing recipe workspace, legacy `recipes`/`recipe_lines`, pricing, tax, discounts, or unrelated Inventory/Finance features.
15. If Docker, PostgreSQL, Flutter, or a required dependency is unavailable, report the exact blocker. Do not substitute a weaker environment and do not claim a test passed without exit evidence.

---

## Requirement Coverage Map

| Requirement area | Primary tasks |
|---|---|
| Optionality and precedence (FR-001â€“FR-008) | T008, T015â€“T018, T020â€“T030, T059â€“T067 |
| Empty writes and deletes (FR-009â€“FR-013) | T031â€“T039 |
| Transactions and audit (FR-014) | T026, T034â€“T038, T047 |
| Lifecycle and stored unavailable materials (FR-015â€“FR-018) | T040â€“T049 |
| Review/publishing/localization codes (FR-019â€“FR-025) | T059â€“T067, T095, T103, T105 |
| POS/Inventory/Finance/history (FR-026â€“FR-033) | T068â€“T085, T109â€“T113 |
| Tenant authorization and API compatibility (FR-034â€“FR-043) | T020â€“T030, T040â€“T049, T086â€“T092 |
| Data model and backfill (FR-044â€“FR-054) | T007, T011â€“T014, T050â€“T058, T112â€“T113 |
| Flutter platforms and presentation (FR-055â€“FR-057) | T086â€“T106 |
| Scenario A | T059â€“T060, T068, T073â€“T077 |
| Scenario B | T008, T020â€“T030, T060, T065, T079â€“T085 |
| Scenario C | T008, T020â€“T030, T060, T065, T079â€“T085 |
| Scenario D | T018, T060, T065, T093â€“T101 |
| Scenario E | T010, T040, T059â€“T067 |
| Scenario F | T032, T035â€“T039, T093â€“T100 |
| Scenario G | T068â€“T077 |
| Scenario H | T061, T070â€“T077, T113 |
