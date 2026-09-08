# Menu ↔ Inventory Validation and Review UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Inventory conversions the sole recipe-unit authority, protect publishing from existing invalid recipes, and ensure Review & Publish displays only current, actionable server validation.

**Architecture:** `UnitConversionResolver::resolveRecipe()` remains the single backend conversion contract. Recipe writes, runtime resolution, menu validation, and snapshot publishing consume that contract without rounding. Flutter preserves the response’s backend code/severity/message/metadata and clears superseded validation state before every recheck.

**Tech Stack:** Laravel/PHP, PostgreSQL, Brick Math, Flutter/Dart, Cubit, Dio, flutter_test.

**Spec:** User request in the current Codex conversation; live stack inspected on 2026-09-08 (`backend:8000`, PostgreSQL `cafe_system_618`).

## Global Constraints

- Inventory is the only authority for units and conversions.
- A recipe component is valid only if `UnitConversionResolver::resolveRecipe()` succeeds.
- No family-compatibility authority, conversion rounding, conversion creation, validation weakening, migration, or silent recipe rewrite.
- Preserve existing API fields and `RECIPE_COMPONENT_CONVERSION_INVALID`.
- Run only focused tests and `git diff --check`.

---

### Task 1: Strengthen backend conversion and existing-data diagnostics

**Files:**
- Modify: `backend/app/Domain/Inventory/UnitConversionResolver.php`
- Modify: `backend/app/Services/Catalog/RecipeConfigurationService.php`
- Modify: `backend/app/Services/Catalog/RecipeResolver.php`
- Modify: `backend/app/Services/Catalog/MaterialCatalogService.php`
- Modify: `backend/app/Services/Menu/MenuValidationService.php`
- Test: `backend/tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php`
- Test: `backend/tests/Feature/Admin/MenuPublishing/MenuPublishingApiTest.php`

**Interfaces:**
- Consumes: `resolveRecipe(int $tenantId, object $item, string $quantity, ?string $unit): array`.
- Produces: exact integer 3-decimal base quantities; recipe validation errors indexed to the submitted component; validation issue metadata with `materialId`, `materialName`, `recipeQuantity`, `recipeUnit`, `inventoryBaseUnit`, and `conversionReason`.

- [ ] **Step 1: Write failing feature tests**

Add assertions covering an active base-unit save/publish, missing/inactive/non-positive/precision-breaking conversion write failures, modifier equivalence, material `allowedRecipeUnits`, and existing unavailable/conversion-invalid components returned by publish validation with the complete actionable metadata.

- [ ] **Step 2: Run focused Laravel tests to verify RED**

Run: `docker compose exec -T backend php artisan test tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php tests/Feature/Admin/MenuPublishing/MenuPublishingApiTest.php`

Expected: the new metadata/unit-contract assertions fail before implementation changes.

- [ ] **Step 3: Implement the narrow backend changes**

Use the Inventory unit catalog to reject unmapped base/input units in the resolver. Keep quantities as exact scaled integers through runtime recipe/modifier aggregation. Emit detailed metadata for both unavailable material and conversion failure paths; retain the stable error code and server severity. Expose only the base recipe unit plus active Inventory conversion source units that target that item’s base unit.

- [ ] **Step 4: Run focused Laravel tests to verify GREEN**

Run: `docker compose exec -T backend php artisan test tests/Feature/Admin/Catalog/RecipeConfigurationApiTest.php tests/Feature/Admin/MenuPublishing/MenuPublishingApiTest.php`

Expected: all selected tests pass.

### Task 2: Make Flutter Review & Publish current and actionable

**Files:**
- Modify: `windows_application/lib/features/menu_management/review/controllers/menu_review_cubit.dart`
- Modify: `windows_application/lib/features/menu_management/review/presentation/validation_issue_presentation.dart`
- Modify: `windows_application/lib/features/menu_management/review/widgets/readiness_issue_browser.dart`
- Modify: `windows_application/lib/core/config/api_config.dart` only if a testable explicit intended-URL contract is needed
- Test: `windows_application/test/features/menu_management/menu_publishing_test.dart`
- Test: `windows_application/test/features/menu_management/readiness_issue_browser_test.dart`
- Test: `windows_application/test/core/network/dio_api_client_test.dart`

**Interfaces:**
- Consumes: `MenuValidationResult` and `ValidationIssue` from the backend API.
- Produces: no retained validation payload while a verification is loading/fails, and a Recipes & Materials grouping for `RECIPE_COMPONENT_CONVERSION_INVALID` without rewriting backend severity/code/message/metadata.

- [ ] **Step 1: Write failing Flutter tests**

Add a Cubit test with a pending second validation response and assert the old result is absent before the latest response resolves. Add presentation tests that preserve a conversion issue’s `error` severity, code, message, and metadata while categorizing it as Recipes & Materials. Add a Dio/ApiConfig test that a default client targets the live local API base URL.

- [ ] **Step 2: Run focused Flutter tests to verify RED**

Run: `flutter test test/features/menu_management/menu_publishing_test.dart test/features/menu_management/readiness_issue_browser_test.dart test/core/network/dio_api_client_test.dart --dart-define=API_BASE_URL=http://localhost:8000/api/v1`

Expected: the stale-state and conversion-category tests fail before implementation changes.

- [ ] **Step 3: Implement the narrow Flutter changes**

Clear validation data at the start of every verification and on verification failure; retain ticket protection against late responses. Map the stable conversion code to `recipesMaterials`. Render present backend metadata as supporting detail without replacing the backend message or severity. Keep `ApiConfig` as the sole default/Dart-define base URL source.

- [ ] **Step 4: Run focused Flutter tests and analyzer to verify GREEN**

Run: `flutter test test/features/menu_management/menu_publishing_test.dart test/features/menu_management/readiness_issue_browser_test.dart test/core/network/dio_api_client_test.dart --dart-define=API_BASE_URL=http://localhost:8000/api/v1`

Run: `flutter analyze`

Expected: all selected tests and static analysis pass.

### Task 3: Verify non-regression and live-data reporting

**Files:**
- No data writes or migrations.

- [ ] **Step 1: Run P0 integration test**

Run: `docker compose exec -T backend php artisan test tests/Feature/RealSaleIntegrationTest.php`

Expected: all P0 sale/inventory integration tests pass.

- [ ] **Step 2: Re-run the read-only affected-data query**

Query current variant and modifier recipe components against their inventory materials and active conversion rows. Report exact component IDs/material IDs/material names/quantities/units/base units/reasons; do not mutate rows.

- [ ] **Step 3: Check patch hygiene**

Run: `git diff --check`

Expected: exit code 0.
