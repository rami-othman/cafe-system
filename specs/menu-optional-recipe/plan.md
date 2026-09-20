# Implementation Plan: Optional Product Recipes and Recipe Inheritance

**Branch**: `menu-optional-recipe` | **Date**: 2026-09-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/menu-optional-recipe/spec.md`

## Summary

Add an optional tenant-owned product base recipe and reinterpret existing non-empty variant recipes as complete overrides. One backend effective-base-recipe resolver will select variant override, product recipe, or empty state before existing modifier effects are applied. Publishing will continue writing the resolved result into schema-v3 `baseRecipe`; POS payment will continue consuming the pinned snapshot, while Sales Invoice will resolve current configuration through the same backend authority. Empty recipes will be valid zero-consumption outcomes with zero inventory-derived COGS and no recipe-only warehouse requirement. Later Flutter work will expose base, inherited, override, and empty states without redesigning Menu Management.

Delivery remains split into controlled implementation checkpoints: backend domain/API and safe backfill; publishing/POS/Sales Invoice runtime; Flutter Windows/Web experience; independent regression closure. Each checkpoint must be accepted before the next begins.

## Technical Context

**Language/Version**: PHP 8.3 with Laravel 13.8; Dart SDK 3.12.1 with Flutter

**Primary Dependencies**: Laravel Eloquent, validation, transactions, route middleware and PHPUnit 12.5; Brick Math for exact recipe decimals; Flutter Bloc, Dio, go_router, intl, generated Flutter localization, and GetIt

**Storage**: PostgreSQL through Laravel migrations/Eloquent/query builder; immutable published menu JSON snapshots remain schema version 3

**Testing**: Laravel feature/integration tests with `RefreshDatabase` against the shared PostgreSQL testing database, run serially; Flutter unit/widget tests; `flutter analyze`; `git diff --check`

**Target Platform**: Laravel API in the existing Docker deployment; Flutter Windows and Web clients

**Project Type**: Multi-application system with a Laravel REST backend and Flutter desktop/web client

**Performance Goals**: Preserve bounded per-product/per-variant recipe reads; avoid per-variant resolver queries during list, preview, validation, and publication; payment and Sales Invoice paths add no live configuration lookup for pinned POS orders; backfill is set-bounded, restart-safe, and deterministic

**Constraints**: Strict tenant isolation; backend authorization; forward-only database evolution; no historical mutation; decimal-string API semantics; Inventory-owned conversions/WAC/COGS; schema-v3 compatibility; no live fallback for pinned orders; no empty base-recipe parent rows; serial Laravel suites; no production migration execution without separate authorization

**Scale/Scope**: Two new tables and two models; product recipe CRUD plus variant DELETE and additive response fields; one effective resolver reused by validation, preview, publication, resolve, and Sales Invoice; targeted POS warehouse/consumption changes; focused Menu Management Flutter model/repository/state/view/localization updates

## Current Brownfield Baseline

- Active base recipe persistence is `variant_recipes` and `variant_recipe_components`; `RecipeConfigurationService` creates a parent even for an empty component list.
- Variant recipe GET/PUT and resolve routes exist in `backend/routes/api.php`; no product recipe endpoints or variant DELETE route exist.
- `RecipeResolver` combines the current variant recipe with existing modifier material profiles.
- `ProductVariantResource` exposes only `recipeConfigured` and `recipeComponentCount`, based on the direct variant relation.
- `MenuValidationService` currently emits blocking `VARIANT_RECIPE_MISSING` and `VARIANT_RECIPE_EMPTY` errors for stock-tracked variants.
- `PublishedMenuSnapshotBuilder` currently serializes direct variant components into schema-v3 `baseRecipe`.
- `SaleConsumptionService` correctly reads the pinned published snapshot but currently rejects an empty recipe before warehouse resolution and consumption.
- `SalesInvoiceInventoryConsumptionService` is the manual invoice inventory boundary and currently derives consumption from live variant-recipe data; it must consume the shared effective resolver rather than duplicate precedence.
- Flutter currently models `VariantRecipe` with one editable `components` list and uses existing variant recipe routes. Existing summary parsing expects `recipeConfigured` and `recipeComponentCount`.
- Legacy `recipes` and `recipe_lines` are a separate domain and are excluded.

## Constitution Check

*GATE: PASS before implementation planning. Re-check at each phase boundary and after final design.*

- **Tenant and authorization**: `product_recipes`, components, overrides, resolver inputs, publication, and runtime queries remain scoped by authenticated `TenantContext`. Existing Catalog middleware and permission policy remain the backend boundary; client visibility grants no authority. Foreign product, variant, material, and modifier identifiers fail without disclosure. Platform Super Admin remains separate. Branch access is unchanged; existing POS/Finance branch contracts govern runtime operations.
- **Domain authority and scope**: Menu owns canonical recipe configuration and publishing. Inventory remains the only conversion, warehouse movement, quantity, WAC, and COGS authority. Finance consumes authoritative results. POS consumes the pinned snapshot. No modifier-selection, pricing, discount, tax, purchasing, production, or legacy-recipe redesign is included.
- **History and data safety**: Published versions, pinned orders, movements, payments, and journals are never updated by configuration or backfill. Migrations are forward-only. All non-empty variant recipes survive as explicit overrides; empty parents normalize to absence. The migration requires restart-safe insertion, reconciliation, audit evidence, and roll-forward recovery. Non-testing execution is separately authorized.
- **Exact semantics**: Recipe quantities remain positive decimal strings with at most six configuration places; database quantity remains `decimal(18,6)`. Inventory conversion and three-decimal base-quantity representability remain authoritative. Existing money/WAC/COGS rounding is unchanged; empty consumption yields exact zero. Tax and timezone logic are unaffected because the feature adds no tax or time-sensitive rule. Writes and runtime posting retain existing transactions, locks, retry identities, and rollback behavior.
- **Contracts and scale**: Existing variant routes, request fields, resolve shape, and legacy summary fields remain. New fields are additive. Legacy `components` aliases only override data. Recipe payloads are bounded per entity. Preview/validation/publication must eager-load or batch-resolve recipes to avoid N+1 access. Real backend errors and state remain visible; no client fallback is allowed.
- **UX and platforms**: Flutter reuses the current Menu Management shell, recipe components, navigation patterns, Bloc/repository structure, and responsive conventions. All new presentation uses generated English/Arabic localization and correct RTL/LTR behavior on Windows and Web. No POS UI redesign is planned.
- **Verification and scope**: Focused service/API, migration, publishing, POS, Sales Invoice, historical, tenant/permission, Flutter parsing/state/widget/navigation, static-analysis, and broader integration checkpoints are listed below. Laravel suites run serially. Every phase ends with changed-file review and `git diff --check`; skipped or timed-out gates remain unverified.

No constitutional exception is required.

## Design Decisions

### 1. Persist product recipes in a parallel active-domain schema

Create `product_recipes` and `product_recipe_components` mirroring the active variant recipe schema. Add `ProductRecipe` and `ProductRecipeComponent` models and `Product::recipe()`. The parent is unique by `(tenant_id, product_id)`; a component is unique by `(product_recipe_id, inventory_item_id)`; component deletion cascades only from its recipe parent; Inventory references do not cascade-delete configuration.

Rationale: this preserves active recipe semantics and avoids absorbing legacy `recipes`/`recipe_lines` concepts such as yield, wastage, or versions.

### 2. Centralize effective base-recipe resolution

Extend `RecipeConfigurationService` or introduce one narrowly named catalog resolver used by all configuration-facing consumers. It returns a value object/array containing:

- `source`: `variant`, `product`, or `none`;
- `hasOverride`;
- sorted `overrideComponents`;
- sorted `effectiveComponents`.

`RecipeResolver` then applies modifier effects to `effectiveComponents`. Controllers, resources, validation, preview, publication, and Sales Invoice must call this authority rather than duplicate precedence.

Batch/eager-load entry points are required for menu validation, preview, publication, and variant summaries so the resolver does not cause per-variant queries.

### 3. Normalize base-recipe emptiness to absence

Product and variant `PUT components: []` share the same transactional clear operation as DELETE. The operation deletes the applicable parent, is idempotent, writes an audit event when state changes, and returns current normalized state even when already absent. Product deletion does not touch variant rows. Explicit empty modifier profiles remain unchanged because they carry suppression meaning.

### 4. Preserve lifecycle data while blocking archived mutations

Normal route binding/query helpers continue exposing active and inactive non-archived entities. Authorized lifecycle/history reads must use an explicit `withTrashed`-style path or service boundary for archived entities without widening operational list access. Every create, replace, clear, and override-removal operation checks both product and variant archive state. Restoration re-enables future writes without rewriting any history.

Stored inactive/archived materials are serialized for diagnosis by ID and available metadata, while shared component validation rejects them on replacement.

### 5. Evolve API responses additively

Product CRUD uses the exact `data` envelope from the specification. Variant GET/PUT/DELETE always returns both override and effective lists. `components` remains an alias of `overrideComponents`, not effective state. Resolve retains its existing final canonical `components` response. Variant resource summaries add the four new fields and retain the two old fields as effective-state aliases.

No route version bump or removal occurs. A separately approved versioned change is required to remove legacy fields.

### 6. Keep schema-v3 publication authoritative

Validation and preview inspect effective recipe state. Missing state yields a warning and remains valid. Configured-invalid state remains blocking. Snapshot generation serializes effective components into the existing `baseRecipe` array and changes neither schema version nor POS shape. Version comparison continues comparing serialized effective components.

### 7. Treat pinned empty POS recipes as valid runtime input

`SaleConsumptionService` first confirms that the compatible pinned snapshot and sold variant node exist. An empty `baseRecipe` is then an intentional valid result: snapshot item COGS to zero, create no movement or `sale_consumptions` row requiring a warehouse, and continue. Warehouse preflight resolves a warehouse only if at least one payable tracked line has actual final recipe consumption. A missing/incompatible snapshot remains fail-closed.

Mixed orders still require a warehouse for lines with components. Non-empty paths continue through `SalesInventoryMovementService` and retain negative-stock, conversion, WAC, idempotency, and transaction behavior.

### 8. Make Sales Invoice use current effective configuration through Menu authority

Manual Sales Invoice is not pinned to a published POS snapshot, so preview/posting resolves the invoice line's current effective base recipe through the same backend resolver. Empty state is valid zero consumption and zero inventory-derived COGS. Non-empty state retains Inventory conversion, warehouse, movement, WAC, rollback, and idempotency rules. The service must not query `variant_recipes` directly after convergence.

### 9. Make migration/backfill deterministic and roll-forward only

The forward migration creates tables and performs or invokes a bounded, restart-safe backfill:

1. Find products with exactly one unambiguous default variant.
2. If that variant has a non-empty recipe, insert the product parent/components idempotently in stable component order.
3. Preserve that and every other non-empty variant recipe as an explicit override.
4. Remove only empty `variant_recipes` parents after confirming they have no components.
5. Leave the product parent absent when the default is missing or ambiguous.
6. Record deterministic counts/reconciliation evidence and abort on tenant or referential inconsistency.

Unique constraints make replay safe. Recovery is roll-forward: correct the cause and rerun the idempotent operation. The migration does not update published snapshots or transactional history. `down()` may remove only newly introduced schema in testing/development; production recovery does not depend on destructive rollback.

### 10. Separate Flutter editable and effective state

Add `ProductRecipe` and expand `VariantRecipe` with `hasOverride`, `source`, `overrideComponents`, and `effectiveComponents`, while exposing `components` only as a compatibility mapping to override data where needed. Repository methods cover product GET/PUT/DELETE and variant DELETE. Cubit draft initialization uses only own components; inherited components are display-only. Clearing or removing an override reloads server-returned resolved state.

The existing Recipe & Materials workspace is reorganized in place—no new application shell or broad navigation redesign. Empty and inherited states, warnings, retry/error states, focus behavior, and simulation output use localized English/Arabic strings. Raw backend/exception text is not displayed.

## Project Structure

### Documentation

```text
specs/menu-optional-recipe/
├── spec.md
└── plan.md
```

No `tasks.md`, checklist, contract file, or implementation log is created by this planning step.

### Backend: expected change surface

```text
backend/
├── routes/api.php
├── app/
│   ├── Models/
│   │   ├── Product.php
│   │   ├── ProductVariant.php
│   │   ├── ProductRecipe.php                         # new
│   │   └── ProductRecipeComponent.php                # new
│   ├── Http/
│   │   ├── Controllers/Api/Admin/Catalog/RecipeConfigurationController.php
│   │   └── Resources/Catalog/ProductVariantResource.php
│   └── Services/
│       ├── Catalog/RecipeConfigurationService.php
│       ├── Catalog/RecipeResolver.php
│       ├── Menu/MenuValidationService.php
│       ├── Menu/MenuPreviewService.php
│       ├── Menu/PublishedMenuSnapshotBuilder.php
│       ├── Menu/PublishedMenuVersionComparisonService.php
│       ├── SaleConsumptionService.php
│       └── SalesInvoiceInventoryConsumptionService.php
├── database/migrations/
│   └── <timestamp>_create_product_recipe_tables_and_backfill.php  # new
└── tests/Feature/
    ├── Admin/Catalog/RecipeConfigurationApiTest.php
    ├── Admin/MenuValidation/MenuValidationApiTest.php
    ├── Admin/MenuPublishing/MenuPublishingApiTest.php
    ├── Admin/MenuVersionHistory/PublishedMenuVersionHistoryApiTest.php
    ├── ProductInventoryTrackingE2ETest.php
    ├── SaleAccountingApiTest.php
    ├── RealSaleIntegrationTest.php
    ├── SalesInvoicePosCrossPathCharacterizationTest.php
    └── SalesInvoicePhaseTwoApiTest.php
```

Exact migration filename is assigned at implementation time. Existing focused tests should be extended when ownership is clear; a new focused test file is acceptable only when it isolates migration or cross-domain behavior better than an existing suite.

### Flutter: expected change surface

```text
windows_application/
├── lib/features/menu_management/
│   ├── repositories/menu_catalog_repository.dart
│   ├── models/                                   # product/variant summary models
│   ├── controllers/                              # product detail/summary state
│   ├── recipes/
│   │   ├── models/recipe_models.dart
│   │   ├── controllers/recipe_cubits.dart
│   │   └── views/
│   │       ├── variant_recipe_screen.dart
│   │       ├── recipe_simulation_screen.dart
│   │       └── <product recipe workspace file if needed>
│   ├── review/                                   # warning categorization/presentation
│   └── views/product_detail_screen.dart
├── lib/l10n/                                     # existing ARB localization files
└── test/features/menu_management/
    ├── recipe_cubits_test.dart
    ├── recipe_views_test.dart
    ├── recipe_navigation_test.dart
    ├── recipe_material_repository_test.dart
    ├── readiness_issue_browser_test.dart
    └── ux_g0b_consistency_test.dart
```

The implementer must confirm exact product/variant model and localization filenames before editing. Do not create parallel repository, design-system, or routing layers.

## Delivery Phases

### Phase 2 — Backend Recipe Domain and API

1. Add failing characterization/contract coverage for product CRUD, inheritance, full override, empty normalization, idempotent delete, lifecycle, authorization, cross-tenant rejection, summaries, and response aliases.
2. Add forward-only product recipe schema, models, relationships, constraints, and deterministic backfill.
3. Implement one effective base-recipe resolution API with batch/eager-load support.
4. Add product GET/PUT/DELETE and variant DELETE routes/controller methods.
5. Refactor variant GET/PUT responses and clear behavior without changing resolve response shape.
6. Update summaries to effective-state aliases plus additive source/override fields.
7. Preserve audit events for create, replace, clear, and override removal.
8. Verify migration behavior only against testing data; do not execute against non-testing environments.

**Phase gate**: Focused recipe API/model/migration tests pass serially; response examples match the specification; backfill reconciliation proves no non-empty variant data or historical data changed; `git diff --check` passes. Publishing/runtime/Flutter remain unclaimed.

### Phase 3 — Publishing, POS, Sales Invoice, and Inventory Runtime

1. Change Menu Review missing effective recipe from blocking error to non-blocking `VARIANT_RECIPE_MISSING`; eliminate normalized-state `VARIANT_RECIPE_EMPTY`.
2. Keep strict blocking validation for every configured product, override, and modifier component.
3. Update preview, snapshot builder, and version comparison to effective recipe state with batched loading.
4. Preserve schema-v3 and serialize empty state as `baseRecipe: []`.
5. Change POS preflight/consumption so compatible pinned empty recipes are zero-consumption lines; preserve fail-closed missing snapshot behavior.
6. Require a warehouse only when at least one payable line has actual components.
7. Route Sales Invoice preview/posting through the same effective configuration resolver; make empty state zero consumption.
8. Preserve transaction, rollback, retry, WAC, and COGS behavior for non-empty lines.

**Phase gate**: Scenarios A–H have focused backend evidence; POS and Sales Invoice agree; schema-v3 historical orders remain payable/resumable; mixed lines, failure rollback, and retry idempotency pass; relevant suites run serially; `git diff --check` passes. Flutter remains unclaimed.

### Phase 4 — Flutter Menu Management Experience

1. Add additive response parsing and product recipe repository methods.
2. Separate editable override draft from inherited/effective display state in Cubits.
3. Add product base recipe editing and variant override removal within the existing workspace.
4. Present product, variant, inherited, overridden, empty, and modifier-no-effect states accurately.
5. Accept an empty successful simulation result.
6. Update readiness warning presentation for non-blocking `VARIANT_RECIPE_MISSING`.
7. Add generated English/Arabic strings and verify RTL/LTR, keyboard focus, accessibility, loading, error, empty, retry, and navigation behavior on Windows/Web layouts.

**Phase gate**: Focused model/repository/Cubit/widget/navigation tests pass; `flutter analyze` passes; inherited components cannot be saved accidentally; no raw backend error text appears; `git diff --check` passes.

### Phase 5 — Independent Review and Closure

1. Independently inspect final diff against every FR, scenario, exclusion, and constitution gate.
2. Re-run focused suites and cross-domain integration checkpoints serially.
3. Reconcile migration counts and confirm no historical mutation.
4. Verify POS uses only pinned snapshots and Sales Invoice uses only the shared current resolver.
5. Verify exact zero/non-zero movement and COGS outcomes, warehouse preflight, retries, rollback, and tenant/permission failures.
6. Verify Windows/Web EN/AR behavior and legacy client parsing.
7. Run broader relevant Laravel regression, Flutter analysis/tests, `git diff --check`, scope review, and secret review.

**Phase gate**: All acceptance scenarios have observed evidence; failures, timeouts, and skipped gates are disclosed; no unrelated changes are included.

## Data Migration and Deployment Strategy

1. Deploy additive schema and backend compatibility code before any Flutter dependency on new fields.
2. Keep existing variant routes and legacy fields functional throughout mixed-version deployment.
3. Run schema/backfill verification against isolated testing data first, including interrupted/replayed backfill scenarios.
4. Produce pre/post reconciliation counts per tenant: products examined, unambiguous defaults, product recipes copied, non-empty overrides retained, empty parents removed, ambiguous/missing defaults, and rejected inconsistencies.
5. Require separate approval naming the non-testing environment and exact command before production/staging execution.
6. Use roll-forward recovery only: correct the migration/backfill fault and safely rerun. Never use `migrate:fresh`, `db:wipe`, destructive reseeding, snapshot rewrite, or legacy-table consolidation.
7. Release runtime changes only after schema/API compatibility is established. Release Flutter after backend fields/routes are available.

## Transaction, Concurrency, and Retry Boundaries

- Recipe replacement/clear locks or otherwise serializes the applicable parent identity inside one database transaction; concurrent PUT/DELETE converges to one valid state and never leaves partial components.
- Unique tenant/product and parent/material constraints reject duplicate persistence races.
- Backfill uses deterministic keys/upserts and stable ordering so replay produces the same state.
- Publication remains atomic under existing publication transaction/checksum rules.
- POS payment retains its existing payment idempotency key and sale-consumption locking. Empty lines record zero cost through the existing item/order snapshot path without creating duplicate inventory events.
- Sales Invoice posting retains its existing status lock/idempotency identity. Empty lines do not create inventory movements; non-empty lines retain movement idempotency keys.
- Any failure rolls back all effects owned by the current operation; no partial recipe, payment, movement, COGS, or journal state is accepted.

## Verification Plan

### Backend focused gates

- Recipe configuration API: product CRUD, variant inheritance/override/delete, aliases, decimal strings, lifecycle, material validity, tenant and permission isolation, audit, and idempotent retries.
- Migration/backfill: unambiguous default copy, all non-empty overrides retained, empty parent removal, ambiguous/missing default, cross-tenant corruption rejection, deterministic ordering, replay, and reconciliation.
- Menu validation/preview/publishing: warning severity, configured blockers, effective counts/source, schema-v3 output, modifier remove validity, checksum/version comparison.
- POS: service and stock-tracked empty recipes, mixed lines, warehouse preflight, canonical conversion, movement, WAC COGS, failure rollback, retry idempotency, and incompatible/missing pinned snapshot.
- Sales Invoice: empty, inherited, overridden, modifier-adjusted, invalid, warehouse, movement/WAC, rollback, retry, and POS cross-path characterization.
- Historical: existing schema-v3 payloads, resume/payment after live changes, and immutable published/order records.

### Flutter focused gates

- JSON parsing of old and new response shapes and retained summary aliases.
- Repository paths/payloads for product save/clear and variant save/remove.
- Cubit separation of override drafts from effective display state, request race safety, retry, and empty simulation.
- Widget states for inherited/override/none, inactive stored materials, non-blocking warning, exact decimals, and authorized unit selection.
- EN/AR strings, RTL/LTR, focus order, accessibility semantics, route/back navigation, Windows/Web responsive layouts, and no raw server text.

### Commands and evidence policy

- Run Laravel suites serially through the repository's Docker/backend test path against testing data only.
- Run only phase-relevant focused commands during Phases 2–4; run broader relevant regression at Phase 5.
- Run focused Flutter tests and `flutter analyze` after Flutter changes.
- Run `git diff --check` and `git status --short` at every phase gate.
- Record exact commands, exit codes, failures, timeouts, and skipped checks. Startup-only or partial output is unverified.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Legacy client saves inherited data as a new override | Keep legacy `components` equal only to `overrideComponents`; expose effective data separately |
| N+1 queries across menu variants | Provide batched/eager-loaded effective resolution for summary, preview, validation, and publishing |
| Publishing succeeds but payment rejects empty recipe | Deliver and verify validation, snapshot, preflight, and consumption behavior in the same runtime phase |
| Product clear accidentally removes overrides | Separate parent relationships and test override rows/components byte-for-byte before and after clear |
| Backfill changes behavior unexpectedly | Preserve every non-empty variant recipe as an override; copy only unambiguous default data; reconcile per tenant |
| Empty pinned recipe confused with missing snapshot | Validate snapshot/version/variant presence separately, then accept an explicitly present empty array |
| Sales Invoice diverges from POS | Reuse the effective configuration resolver and cross-path characterization tests while preserving distinct runtime authority |
| Archived materials become unreadable | Serialize stored references for diagnosis, but reuse strict shared validation on any replacement |
| Concurrent clear/replace creates empty or duplicate parents | Transactional mutation plus unique constraints and concurrency-focused tests |
| Broad UI redesign or business-logic duplication | Restrict Flutter changes to existing recipe workspace/repository/Cubits; keep all precedence and validation on backend |

## Complexity Tracking

| Decision | Why required | Simpler alternative rejected because |
|---|---|---|
| Add two product recipe tables | Product-level inheritance needs explicit tenant-owned configuration | Reusing legacy recipe tables imports unrelated yield/version semantics; storing on variants preserves duplication |
| Retain variant recipe rows as overrides during backfill | Guarantees behavioral compatibility and lossless migration | Deduplication could silently change variant behavior or destroy user data |
| Separate override and effective response arrays | Prevents inherited values from becoming accidental writes | One `components` array cannot safely represent both editable ownership and resolved display |
| Keep POS and Sales Invoice authority inputs distinct | POS is historically pinned; manual invoices use current configuration | Forcing either path onto the other's source would violate snapshot immutability or current invoice semantics |

## Post-Design Constitution Re-check

**PASS**. The plan preserves authenticated tenant scope, backend authorization, Super Admin separation, shared branch access, one authority per domain, immutable history, exact decimals, forward-only migration, lifecycle preservation, additive APIs, bounded queries, real backend state, English/Arabic Windows/Web behavior, transaction/idempotency guarantees, serial regression, and strict phase scope. No exception or unresolved clarification remains.
