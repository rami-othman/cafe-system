# Feature Specification: Optional Product Recipes and Recipe Inheritance

**Feature Branch**: `menu-optional-recipe`

**Created**: 2026-09-19

**Status**: Draft

**Input**: User description: "Phase 1 — Specification and Contract Lock from `plans/menu_optional_recipe_plan.md`: make product base recipes, variant overrides, and modifier material effects optional while preserving strict configured-recipe validation, immutable published runtime authority, historical compatibility, and server-authoritative Inventory and Finance behavior."

## Overview

This specification locks the contract for allowing any valid product, including a stock-tracked product, to be configured, published, ordered, paid, and posted to a Sales Invoice without a recipe. It introduces an optional product base recipe, treats an optional non-empty variant recipe as a full replacement override, retains optional modifier material-effect profiles, and resolves those layers into the existing immutable published variant `baseRecipe`.

Recipe absence is a valid configuration state. It is distinct from a configured recipe whose components are invalid. An absent effective recipe produces a non-blocking Menu Review warning and zero recipe-based inventory consumption; an invalid configured recipe remains a blocking error. Runtime authority is the order's pinned schema-v3 published snapshot, never current live recipe configuration.

## Scope

The complete feature contract covers future product-recipe persistence and APIs, effective-recipe resolution, migration/backfill, Menu Review and publishing, POS payment, Sales Invoice posting, Inventory/WAC COGS behavior, historical compatibility, and Flutter presentation. Phase 1 produces this specification only. Backend, database, publishing, POS, Inventory, Finance, Sales Invoice, Flutter, migrations, and tests are deferred to separately authorized later phases.

## Authoritative Domain Decisions

### Recipe optionality and strict validity

- Product base recipes, variant overrides, and modifier material-effect profiles are independently optional.
- Missing recipes are valid for stock-tracked and non-stock-tracked products and MUST NOT block Menu Review, publication, ordering, payment, or Sales Invoice posting.
- A recipe or material-effect profile is configured only when its persisted parent has components, except that an explicit empty modifier profile remains valid as an inheritance-suppression record.
- Every configured component remains subject to existing tenant, material eligibility, unit, conversion, positive decimal quantity, precision, duplication, operation, and removal validation.
- Optional modifier material effects do not alter required modifier-group selections, minimum or maximum selections, quantity rules, or option eligibility.

### Effective base-recipe precedence

For a variant, the backend MUST resolve the effective base recipe in this exact order:

1. A non-empty variant override is the complete effective base recipe.
2. Otherwise, a product base recipe with components is the complete effective base recipe.
3. Otherwise, the effective base recipe is empty.

Variant overrides are full replacements, never additive deltas. Effective modifier material effects are applied only after base-recipe selection. Existing modifier-profile precedence remains variant scope over product scope over global scope over no effect. An explicit empty modifier profile continues suppressing an inherited profile.

### Configuration authority and runtime authority

Menu owns current canonical recipe configuration and resolves it at publication. The immutable published schema-v3 snapshot owns POS runtime recipe input. Inventory owns material eligibility, canonical base-unit conversion, warehouse movement, WAC, and COGS. Finance and Sales Invoice consume authoritative Inventory results and MUST NOT recreate those calculations. Current configuration MUST NOT replace or repair a pinned historical snapshot.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Publish and Sell Without a Recipe (Priority: P1)

An authorized menu administrator can publish a valid product that has no effective recipe, and operational users can sell and pay for it without inventory consumption.

**Why this priority**: Optional recipes are the core business outcome, and publication without safe payment behavior would leave a broken sales path.

**Independent Test**: Publish and pay for a product whose active default variant has neither a product base recipe nor a variant override; verify the warning, empty snapshot recipe, successful payment, no movement, and zero inventory-derived COGS.

**Acceptance Scenarios**:

1. **Scenario A — Internet Service Without Recipe**: **Given** an active product with an active default variant, no product recipe, and no variant override, **When** an authorized manager validates and publishes the menu and the item is ordered and paid, **Then** publication, ordering, and payment succeed, the variant snapshot contains `"baseRecipe": []`, no recipe-based inventory movement is written, and inventory-derived COGS is exactly zero.
2. **Given** a stock-tracked variant with no effective recipe, **When** Menu Review runs, **Then** it emits `VARIANT_RECIPE_MISSING` as a localized non-blocking warning, does not emit `VARIANT_RECIPE_EMPTY`, keeps validation valid, and does not disable publication.
3. **Scenario G — No Warehouse for Empty Recipe**: **Given** an order whose payable lines all have empty pinned `baseRecipe` arrays, **When** payment preflight runs, **Then** no inventory warehouse is required solely because a product is stock-tracked and payment can complete normally.

---

### User Story 2 - Configure Product Inheritance and Variant Replacement (Priority: P1)

An authorized administrator can define one product base recipe for variants to inherit, while any variant can use a complete explicit replacement.

**Why this priority**: One unambiguous resolver prevents duplicated recipe authority and accidental additive behavior.

**Independent Test**: Configure a product recipe across multiple variants, add an override to one, resolve and publish all variants, and compare each effective recipe and source.

**Acceptance Scenarios**:

1. **Scenario B — Product Base Recipe Inheritance**: **Given** a product base recipe and multiple active variants without overrides, **When** the menu is published, **Then** every variant receives the product components in its snapshot `baseRecipe`, reports source `product`, and sales consume those quantities under existing Inventory rules.
2. **Scenario C — Variant Override**: **Given** a product base recipe and one variant with a non-empty override, **When** the menu is published, **Then** that variant uses only its override with source `variant`, while variants without overrides inherit the product recipe.
3. **Given** an effective base recipe and selected modifier options, **When** recipe resolution runs, **Then** the backend first chooses the complete variant override or product recipe and then applies the existing effective modifier profiles to produce one canonical final recipe.
4. **Scenario D — Modifier Without Recipe**: **Given** a valid modifier option with no material-effect profile, **When** it is validly selected for an order item, **Then** selection and payment succeed and the option makes no change to material consumption.

---

### User Story 3 - Clear Recipes Without Ambiguous Empty Rows (Priority: P1)

An authorized administrator can clear either recipe layer and immediately receive its normalized state without leaving an empty recipe parent.

**Why this priority**: Clear semantics prevent an empty override from ambiguously suppressing inheritance and keep old PUT clients safe.

**Independent Test**: Clear product and variant recipes through both `PUT components: []` and `DELETE`, repeat each delete, and inspect persistence and returned resolution.

**Acceptance Scenarios**:

1. **Given** a product recipe, **When** `PUT` receives `components: []` or product recipe `DELETE` is called, **Then** the product recipe parent and components are removed and the response reports `configured: false` with an empty component array.
2. **Scenario F — Remove Override**: **Given** a variant override, **When** `PUT` receives `components: []` or variant recipe `DELETE` is called, **Then** the override parent and components are removed, the response reports no override and the current inherited or empty effective state, later publications use that state, and earlier published versions remain unchanged.
3. **Given** no recipe or override exists, **When** the corresponding delete is repeated, **Then** it succeeds without duplicate effects and returns the current absent, inherited, or empty state.

---

### User Story 4 - Preserve Strict Configured-Recipe Safety (Priority: P1)

An administrator can diagnose stored references but cannot newly save a malformed configured recipe.

**Why this priority**: Optionality must not weaken Inventory correctness when components exist.

**Independent Test**: Attempt to save foreign, inactive, archived, ineligible, duplicate, non-positive, over-scale, unmapped, or invalidly converted components and verify atomic rejection.

**Acceptance Scenarios**:

1. **Scenario E — Invalid Configured Recipe**: **Given** a configured recipe referencing an inactive material or invalid conversion, **When** the menu is validated, **Then** publication is blocked with a stable actionable recipe error whose English and Arabic presentation is localized.
2. **Given** stored components referencing an inactive or archived Inventory material, **When** an authorized administrator reads the recipe, **Then** those components remain visible for diagnosis and replacement; **when** any recipe containing such a reference is newly saved, **then** the complete write is rejected.
3. **Given** any component validation failure, **When** replacement is attempted, **Then** neither the parent nor any component change is persisted.

---

### User Story 5 - Preserve Lifecycle and Tenant Boundaries (Priority: P2)

Authorized administrators can prepare inactive catalog entities for reactivation while archived entities and foreign-tenant resources remain protected.

**Why this priority**: Lifecycle and tenant rules protect configuration integrity without converting deactivation or archival into data loss.

**Independent Test**: Read and write recipes for inactive entities, attempt the same for archived entities, restore and retry, and exercise every endpoint with foreign identifiers.

**Acceptance Scenarios**:

1. **Given** an inactive but non-archived product or variant, **When** an authorized administrator reads, replaces, or clears its recipe, **Then** the operation succeeds without reactivating it.
2. **Given** an archived product or variant, **When** an authorized lifecycle/history context reads its recipe, **Then** the stored state is readable; **when** creation, replacement, clearing, or override removal is attempted before restoration, **then** the backend rejects the mutation without deleting data.
3. **Given** a product base recipe and existing variant overrides, **When** the product recipe is deleted, **Then** overrides remain byte-for-byte unchanged and continue to apply, variants without overrides resolve to no recipe, and the tenant-scoped clear is audited.
4. **Given** any foreign-tenant product, variant, material, modifier, or recipe identifier, **When** it is used by another tenant, **Then** the backend rejects it without exposing foreign data or mutating either tenant.

---

### User Story 6 - Preserve Published and Historical Authority (Priority: P1)

Orders always use the recipe frozen in their compatible pinned published version, even after live recipes change.

**Why this priority**: Historical inventory and financial correctness is non-negotiable.

**Independent Test**: Pin an order to a schema-v3 version, change or clear live recipes, then resume and pay the order and compare its movements and COGS with the pinned recipe.

**Acceptance Scenarios**:

1. **Scenario H — Historical Safety**: **Given** an existing order pinned to a schema-v3 published version, **When** live product and variant recipes later change, **Then** resume and payment continue using the pinned historical `baseRecipe` without mutating the published version or order.
2. **Given** a compatible pinned snapshot with an intentionally empty `baseRecipe`, **When** payment runs, **Then** it treats the empty array as authoritative and does not consult live configuration.
3. **Given** a tracked historical line with no compatible pinned snapshot, **When** resume or payment is attempted, **Then** the existing historical fail-closed policy remains in force and no live-recipe fallback is used.

---

### User Story 7 - Keep Older Flutter Clients Safe (Priority: P2)

Older clients can continue using the existing variant endpoints and fields without accidentally converting inherited components into an override.

**Why this priority**: Additive evolution is required while Windows and Web clients roll forward separately.

**Independent Test**: Parse new responses with a legacy client model, edit a variant through legacy `components`, and verify that inherited data is never exposed as editable override data.

**Acceptance Scenarios**:

1. **Given** a variant that inherits a product recipe, **When** its recipe is retrieved, **Then** legacy `components` and new `overrideComponents` are empty while `effectiveComponents` contains the inherited recipe.
2. **Given** an older client submitting the existing component request shape, **When** it PUTs a non-empty recipe, **Then** a complete variant override is created using unchanged component names and decimal-string semantics.
3. **Given** a variant resource returned to an older client, **When** it parses only `recipeConfigured` and `recipeComponentCount`, **Then** those fields remain present and describe effective recipe state, while additive fields expose source and override state to new clients.

### Edge Cases and Failure Behavior

- A product recipe delete MUST succeed even when one or more variant overrides exist and MUST NOT cascade to them.
- Concurrent clear/delete retries MUST converge on absence and MUST NOT recreate an empty parent.
- A variant `PUT components: []` MUST mean remove override, never "store an empty override."
- Duplicate material rules and deterministic ordering MUST apply within each configured base recipe; modifier `add` and `remove` uniqueness and aggregation retain their existing rules.
- Modifier removals MUST be validated against the selected effective base recipe and the combined selected effects; a final negative or otherwise invalid quantity MUST fail.
- An explicit empty modifier profile remains a persisted suppression record and MUST NOT be normalized away with base recipes.
- Product or variant inactivity MUST NOT imply archival, deletion, or automatic recipe removal.
- Product or variant restoration MUST NOT rewrite recipes, snapshots, orders, movements, or journals.
- A configured recipe containing a material that later becomes inactive or archived MUST remain readable but MUST block publication until replaced or cleared; its historical snapshots remain usable.
- An order containing both empty and non-empty published base recipes requires a warehouse because actual consumption exists for at least one line; empty-recipe lines create no movement.
- A retry after a payment or posting failure MUST follow existing idempotency identity, payload-conflict, transaction, and rollback rules and MUST NOT double-post movements, COGS, payments, or journals.
- Failure to resolve a required Inventory conversion for a configured component MUST fail validation; the system MUST NOT guess, silently round, or synthesize a conversion.
- Quantities MUST remain decimal strings at the API boundary and use existing deterministic Inventory precision and rounding points; binary floating-point MUST NOT determine persisted quantities or COGS.
- Recipe behavior is not time-based; tenant/branch timezone rules remain unchanged and no developer-machine or server-default time is introduced.

## Requirements *(mandatory)*

### Functional Requirements

#### Optionality and resolution

- **FR-001**: The system MUST treat a product base recipe, a variant override, and each modifier material-effect profile as independently optional configuration.
- **FR-002**: A missing effective recipe MUST be valid regardless of `isStockTracked` and MUST NOT block Menu Review, publication, ordering, payment, or Sales Invoice posting.
- **FR-003**: A configured base recipe or modifier material-effect component MUST satisfy all existing same-tenant material eligibility, active lifecycle, authorized unit, active conversion, positive quantity, decimal scale, duplicate, operation, and precision rules.
- **FR-004**: The effective base recipe MUST be the non-empty variant override when present; otherwise the non-empty product base recipe; otherwise an empty list.
- **FR-005**: A variant override MUST replace the complete product base recipe and MUST NOT be interpreted as an additive delta.
- **FR-006**: The resolver MUST apply the existing effective modifier material profiles only after selecting the effective base recipe.
- **FR-007**: Modifier-profile precedence MUST remain variant over product over global over no effect, and an explicit empty modifier profile MUST continue suppressing inheritance.
- **FR-008**: Modifier material-effect optionality MUST NOT weaken modifier selection requirements, selection limits, quantity rules, option availability, or supported `add`/`remove` behavior.

#### Empty writes, deletes, and lifecycle

- **FR-009**: A product recipe `PUT` with `components: []` and product recipe `DELETE` MUST both remove the product-recipe parent and its components and return the normalized absent state.
- **FR-010**: A variant recipe `PUT` with `components: []` and variant recipe `DELETE` MUST both remove the variant-override parent and its components and return the current inherited or empty effective state.
- **FR-011**: Empty product-recipe and variant-override parent rows MUST NOT be persisted; this normalization MUST NOT apply to explicit empty modifier profiles.
- **FR-012**: Product and variant recipe deletes MUST be idempotent; a repeated delete MUST succeed and return current normalized state.
- **FR-013**: Product base-recipe deletion MUST be allowed while variant overrides exist and MUST NOT delete or modify those overrides.
- **FR-014**: Product-recipe creation, replacement, clearing, and deletion and variant-override creation, replacement, clearing, and removal MUST be tenant-scoped, backend-authorized, transactional, and auditable when implemented.
- **FR-015**: An inactive but non-archived product or variant MUST remain readable and writable by an authorized administrator without implicit reactivation.
- **FR-016**: An archived product or variant MUST remain readable only through authorized lifecycle/history contexts; all recipe mutations MUST be rejected until restoration.
- **FR-017**: Archive, deactivate, restore, recipe clear, and recipe delete MUST remain distinct operations and MUST NOT destructively remove unrelated configuration or history.
- **FR-018**: Stored components referencing inactive or archived Inventory materials MUST remain readable for diagnosis, but the backend MUST reject any newly saved configuration containing those references.

#### Menu Review and publishing

- **FR-019**: Menu Review MUST emit canonical code `VARIANT_RECIPE_MISSING` with non-blocking warning severity for a variant with no effective recipe.
- **FR-020**: Menu Review MUST NOT emit `VARIANT_RECIPE_EMPTY` for normalized new state because empty base-recipe parents are not retained.
- **FR-021**: A missing-recipe warning MUST NOT mark validation invalid or disable publication; a configured invalid component MUST remain a blocking error.
- **FR-022**: English and Arabic clients MUST localize warning and validation presentation while preserving canonical error codes untranslated.
- **FR-023**: Publishing MUST retain snapshot schema version 3 and serialize the resolved effective base recipe into each existing variant `baseRecipe` field.
- **FR-024**: Publishing MUST serialize no effective recipe exactly as `"baseRecipe": []` and MUST NOT invent components or omit the field to imply a live fallback.
- **FR-025**: Publishing MUST validate and serialize modifier adjustments under existing rules, using the effective base recipe for removal validity.

#### Runtime, Inventory, Finance, and history

- **FR-026**: POS MUST consume the order's compatible pinned published snapshot and MUST NOT resolve live product or variant recipe configuration.
- **FR-027**: When pinned `baseRecipe` is empty, payment MUST continue normally, create no recipe-based inventory movement, assign inventory-derived COGS exactly zero, and require no warehouse solely due to `isStockTracked`.
- **FR-028**: Sales Invoice preview and posting MUST use the same authoritative effective-recipe contract; an absent effective recipe MUST post with no recipe-based inventory movement and exactly zero inventory-derived COGS.
- **FR-029**: When components exist, existing authoritative Inventory conversion, warehouse assignment, movement, WAC, COGS, transaction, concurrency, rollback, and idempotency rules MUST remain mandatory for POS and Sales Invoice paths.
- **FR-030**: No runtime path MUST create a fake material, recipe, quantity, conversion, warehouse, or live-configuration fallback.
- **FR-031**: Existing schema-v3 snapshots and pinned orders MUST remain readable, resumable, and payable under their frozen `baseRecipe` and modifier adjustments.
- **FR-032**: Later recipe edits, clears, deletes, lifecycle changes, or migration backfill MUST NOT mutate published versions, pinned orders, movements, payments, journals, or other historical records.
- **FR-033**: The existing fail-closed historical policy MUST remain in force when a tracked historical line has no compatible pinned snapshot.

#### API and compatibility contract

- **FR-034**: All product and variant recipe endpoints MUST be tenant-scoped and backend-authorized using existing tenant-user authorization; client visibility and client-supplied tenant identifiers MUST NOT grant or widen access, and Platform Super Admin separation MUST remain unchanged.
- **FR-035**: Product recipe GET, PUT, and DELETE MUST use `/api/v1/admin/catalog/products/{product}/recipe` and return the `data` envelope defined below.
- **FR-036**: Variant recipe GET and PUT MUST remain available, DELETE MUST be added at `/api/v1/admin/catalog/product-variants/{variant}/recipe`, and resolve MUST remain available at `/api/v1/admin/catalog/product-variants/{variant}/recipe/resolve`.
- **FR-037**: Variant GET, PUT, and DELETE MUST return `variantId`, `hasOverride`, `source`, `components`, `overrideComponents`, and `effectiveComponents`; `source` MUST be exactly `variant`, `product`, or `none`.
- **FR-038**: Variant response `components` MUST temporarily alias `overrideComponents`, never `effectiveComponents`, so inherited data cannot be unknowingly saved as a new override.
- **FR-039**: Resolve MUST retain `{ "data": { "variantId": <id>, "components": [...] } }`, where `components` is the final canonical recipe after base selection and modifier effects.
- **FR-040**: Component request fields and decimal-string semantics MUST remain compatible with existing variant recipe clients; a non-empty legacy PUT MUST create or replace a full variant override.
- **FR-041**: Variant summaries MUST add `effectiveRecipeConfigured`, `effectiveRecipeComponentCount`, `recipeSource`, and `hasRecipeOverride` while retaining `recipeConfigured` and `recipeComponentCount` as aliases of effective state.
- **FR-042**: Legacy response and summary fields MUST remain until a separately approved versioned contract change defines their removal; Phase 1 makes no Flutter change.
- **FR-043**: New clients MUST edit `overrideComponents` and use `effectiveComponents` for display or simulation; older clients cannot configure product recipes or distinguish inheritance until the later Flutter phase.

#### Data model and migration/backfill

- **FR-044**: A future forward-only migration MUST create `product_recipes` and `product_recipe_components` without altering legacy `recipes` or `recipe_lines`.
- **FR-045**: `product_recipes` MUST contain tenant ownership, product ownership, timestamps, and a unique `(tenant_id, product_id)` constraint.
- **FR-046**: `product_recipe_components` MUST contain tenant ownership, product-recipe ownership, Inventory material reference, `quantity decimal(18,6)`, `unit_code`, `sort_order`, timestamps, uniqueness on `(product_recipe_id, inventory_item_id)`, and tenant/material indexes consistent with variant components.
- **FR-047**: Product-recipe component deletion MUST cascade when its parent is cleared, while deleting or archiving an Inventory material MUST NOT cascade-delete recipe history or configuration.
- **FR-048**: Backfill MUST copy a non-empty default variant recipe into the product base recipe only when one unambiguous default variant exists.
- **FR-049**: Backfill MUST retain every existing non-empty variant recipe, including the default variant recipe, as an explicit override and MUST NOT deduplicate or delete its data.
- **FR-050**: Backfill MUST normalize existing empty variant-recipe parent rows to absence/no override.
- **FR-051**: If default-variant data is absent or ambiguous, backfill MUST NOT guess; it MUST leave the product recipe absent and preserve all non-empty variant overrides.
- **FR-052**: Backfill MUST NOT modify published versions, pinned orders, inventory movements, payments, journals, or other historical data.
- **FR-053**: Migration and backfill MUST use tenant-scoped constraints, deterministic component ordering, auditable outcomes, restart-safe behavior, and an explicit roll-forward recovery procedure that can safely resume after partial deployment failure without duplicate parents or components.
- **FR-054**: Any non-testing migration or backfill execution MUST require separate environment-specific authorization and is outside Phase 1.

#### Platform and presentation

- **FR-055**: The later Flutter implementation MUST preserve the existing Menu Management shell and responsive behavior on Windows and Web and MUST NOT redesign Menu Management or POS.
- **FR-056**: All later user-facing warning, empty, validation, loading, authorization, network, and server states MUST use established English/Arabic localization, RTL/LTR layout, and canonical backend state without hard-coded production copy or fabricated success.
- **FR-057**: Recipe endpoint payloads are bounded component collections for one product or variant; no new unbounded tenant collection is introduced. Existing material-search pagination and filtering authority MUST remain unchanged.

### API Contract Examples

All successful responses use the existing top-level `data` envelope. PUT requests use the existing component shape:

```json
{
  "components": [
    {
      "materialId": 9,
      "quantity": "18.000000",
      "unitCode": "gram",
      "sortOrder": 0
    }
  ]
}
```

Product base recipe endpoints:

```http
GET /api/v1/admin/catalog/products/{product}/recipe
PUT /api/v1/admin/catalog/products/{product}/recipe
DELETE /api/v1/admin/catalog/products/{product}/recipe
```

Configured response:

```json
{
  "data": {
    "productId": 42,
    "configured": true,
    "components": [
      {
        "materialId": 9,
        "quantity": "18.000000",
        "unitCode": "gram",
        "sortOrder": 0
      }
    ]
  }
}
```

Absent or cleared response:

```json
{
  "data": {
    "productId": 42,
    "configured": false,
    "components": []
  }
}
```

Variant override endpoints:

```http
GET /api/v1/admin/catalog/product-variants/{variant}/recipe
PUT /api/v1/admin/catalog/product-variants/{variant}/recipe
DELETE /api/v1/admin/catalog/product-variants/{variant}/recipe
POST /api/v1/admin/catalog/product-variants/{variant}/recipe/resolve
```

Variant GET/PUT/DELETE response when inheriting:

```json
{
  "data": {
    "variantId": 7,
    "hasOverride": false,
    "source": "product",
    "components": [],
    "overrideComponents": [],
    "effectiveComponents": [
      {
        "materialId": 9,
        "quantity": "18.000000",
        "unitCode": "gram",
        "sortOrder": 0
      }
    ]
  }
}
```

When no product recipe exists, the same response uses `source: "none"` and empty `effectiveComponents`. When a non-empty override exists, it uses `hasOverride: true`, `source: "variant"`, and identical component values in `components`, `overrideComponents`, and `effectiveComponents` before modifier effects.

Resolve response remains additive-compatible:

```json
{
  "data": {
    "variantId": 7,
    "components": [
      {
        "materialId": 9,
        "quantity": "36.000000",
        "unitCode": "gram",
        "sortOrder": 0
      }
    ]
  }
}
```

Variant summary additions and retained aliases:

```json
{
  "effectiveRecipeConfigured": true,
  "effectiveRecipeComponentCount": 1,
  "recipeSource": "product",
  "hasRecipeOverride": false,
  "recipeConfigured": true,
  "recipeComponentCount": 1
}
```

### Key Entities

- **Product Recipe**: Optional tenant-owned parent for one product base recipe. Absence means no product base recipe; an empty parent is prohibited.
- **Product Recipe Component**: Ordered reference to an eligible same-tenant Inventory material with a positive decimal quantity and authorized recipe unit.
- **Variant Recipe Override**: Optional tenant-owned non-empty full replacement for a variant. Absence means inherit the product recipe or resolve empty.
- **Modifier Material-Effect Profile**: Optional global, product, or variant scoped `add`/`remove` profile. Unlike base recipes, an explicit empty profile can suppress inheritance.
- **Effective Recipe**: Transient resolution of variant override or product base recipe followed by selected modifier effects. It is display/simulation output, not editable override state.
- **Published Variant Snapshot**: Immutable schema-v3 runtime record whose `baseRecipe` is the resolved effective base recipe at publication time.

## Explicit Exclusions

This feature and Phase 1 MUST NOT introduce automatic recipes, guessed materials or quantities, automatic conversions, material auto-creation, variant add/remove base-recipe deltas, recipe yield or wastage management, production/batch recipes, recipe costing redesign, modifier-selection changes, Menu Management navigation redesign, POS redesign, schema-v4 publishing, live recipe fallback, historical rewrites, or consolidation/deletion of legacy `recipes` and `recipe_lines`.

Phase 1 specifically excludes all production code, Dart code, migrations, seeders, tests, generated plans, tasks, checklists, implementation notes, formatting, test execution, data changes, and deployment execution.

## Future Verification Matrix

| Area | Future verification | Locked expected result |
|---|---|---|
| Backend product API | GET/PUT/non-empty/PUT-empty/DELETE/repeated DELETE | Exact envelopes; empty writes normalize to absence; deletes are idempotent |
| Backend variant API | Inherit, full override, PUT-empty, DELETE, repeated DELETE, resolve | Override and effective arrays remain distinct; precedence and final resolution are exact |
| Validation | Foreign/inactive/archived/ineligible material, duplicate, quantity, unit, conversion, precision | Atomic rejection of configured invalid data; absent recipe remains valid |
| Lifecycle | Inactive read/write; archived history read; archived mutation; restore | Inactive configurable; archived read-only until restore; no destructive deletion |
| Tenant/authorization | Cross-tenant IDs and unauthorized tenant actors across every endpoint | No disclosure or mutation; backend authorization is authoritative |
| Migration | Unambiguous default, missing/ambiguous default, empty/non-empty variants, restart | Product copy only when unambiguous; all non-empty overrides retained; empty rows removed; restart-safe |
| Publishing | No recipe, inherited product recipe, variant override, invalid configured recipe | Schema v3; `baseRecipe: []` or exact effective components; invalid configured data blocks |
| Menu Review | Missing effective recipe and normalized persistence | Localized `VARIANT_RECIPE_MISSING` warning is non-blocking; no new-state `VARIANT_RECIPE_EMPTY` |
| POS payment | Empty, non-empty, mixed lines, retry, failure rollback | Empty consumes nothing/zero COGS/no sole warehouse requirement; non-empty retains Inventory authority; no double post |
| Sales Invoice | Empty, inherited, overridden recipes and retries | Same optional behavior and authoritative Inventory/WAC contract as POS |
| Historical | Existing schema-v3 order, later live edits, empty pinned recipe, incompatible/missing pin | Frozen recipe used; live fallback forbidden; existing fail-closed policy preserved |
| Inventory/Finance | Conversions, warehouse, movement, WAC, COGS, journal integration | Existing exact decimal, transaction, event, and idempotency rules remain authoritative |
| Flutter Windows/Web | Old parsing, legacy edit, new inheritance display, EN/AR, RTL/LTR | Additive parsing works; inherited components never appear in editable legacy `components`; localized responsive states |
| Static and regression | Focused backend, publishing, payment, Inventory, Finance, historical and Flutter checks; diff check | Each later phase reports observed results; skipped, timed-out, or failing checks are not called passed |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All future acceptance tests for scenarios A–H pass with exact prescribed outcomes.
- **SC-002**: 100% of missing-effective-recipe Menu Review results use non-blocking `VARIANT_RECIPE_MISSING`, produce no normalized-state `VARIANT_RECIPE_EMPTY`, and leave publication enabled.
- **SC-003**: 100% of successful empty product/variant PUTs and deletes leave zero corresponding empty base-recipe parent rows.
- **SC-004**: Across product inheritance, variant override, and no-recipe cases, published schema-v3 `baseRecipe` matches the effective configuration exactly and never uses a live fallback.
- **SC-005**: Empty published recipes produce zero recipe-based movements, exactly zero inventory-derived COGS, and no warehouse requirement caused solely by stock tracking in both POS and Sales Invoice flows.
- **SC-006**: Non-empty recipes retain exact existing Inventory conversion, warehouse, movement, WAC, transaction, rollback, concurrency, and idempotency outcomes.
- **SC-007**: Cross-tenant and unauthorized recipe operations have zero data disclosure and zero persisted effects.
- **SC-008**: Migration verification accounts deterministically for every pre-existing non-empty variant recipe as a retained override and every empty variant parent as normalized absence, with zero historical-record mutations.
- **SC-009**: Existing schema-v3 pinned orders remain readable, resumable, and payable using frozen data after live recipe edits.
- **SC-010**: Legacy clients continue parsing retained fields and can write full variant overrides, while inherited components are returned only through `effectiveComponents`.

## Assumptions and Dependencies

- Existing tenant authentication, catalog authorization, audit service, lifecycle restoration, material eligibility, unit conversion, Inventory movement/WAC, Finance posting, payment idempotency, published version pinning, and historical fail-closed mechanisms remain the reusable authorities.
- Existing request component field names and decimal-string behavior are compatibility surfaces; examples use six decimal places, while canonical response formatting continues to follow the existing decimal-string contract without binary floating-point.
- One product has at most one unambiguous default variant according to existing catalog rules; migration treats violations or absence as ambiguous and does not infer intent.
- Branch access changes are not introduced. Existing shared branch authorization governs publication, payment, warehouse, and Sales Invoice operations where branch context already applies.
- Tax, prices, discounts, revenue recognition, and business-date calculation are not changed. Inventory-derived COGS is the only financial value directly affected by recipe absence.
- No new paginated collection is introduced; component arrays remain bounded by one recipe and material discovery retains its existing server-side collection contract.
- Later phases require their own authorization and observed verification. This Draft specification does not claim implementation readiness beyond the locked requirements.

## Constitution Check *(mandatory)*

- **Tenant, authorization, and branch access**: Every configuration, resolution, publication, and consumption lookup is tenant-scoped and backend-authorized. Foreign identifiers fail without disclosure. Platform Super Admin separation and existing shared branch access remain unchanged; stock movement still uses the authoritative branch warehouse only when actual components require consumption.
- **Domain authority and boundaries**: Menu owns canonical configuration and immutable publication; Inventory owns material validity, conversions, warehouse movements, WAC, and COGS; Finance consumes authoritative events; POS consumes pinned snapshots. Modifier selection, tax, pricing, discounts, legacy recipe consolidation, and UI redesign remain outside scope.
- **History, lifecycle, and data evolution**: Schema-v3 snapshots and pinned orders remain immutable. Inactive entities stay configurable; archived entities are read-only until restore. Forward-only tables and restart-safe backfill preserve all non-empty overrides and all historical records. No import behavior is added; backfill is deterministic and auditable rather than a source-data merge.
- **Exact semantics and time**: Quantities retain decimal strings, six-place configuration limits, authoritative conversion, and existing Inventory precision; WAC/COGS retain domain rounding. Empty consumption yields exactly zero inventory-derived COGS. Tax is unchanged. No new time-sensitive rule exists, and existing tenant/branch IANA timezone authority remains untouched.
- **API, state, and scale**: Backend validation and authorization remain authoritative. Additive fields preserve old routes, request fields, decimal semantics, resolve shape, and legacy summaries; removal requires a separate versioned change. UI must show real warning/error state. Per-recipe arrays are bounded, and no unbounded tenant collection is added.
- **Localization and platforms**: Canonical codes and identifiers are untranslated; later presentation must localize English and Arabic, preserve RTL/LTR semantics, and support Windows/Web in the existing shell without redesign.
- **Transactions, retries, and verification**: Future writes, payment, Sales Invoice, movement, COGS, and Finance effects must retain atomic rollback, concurrency protection, and idempotent replay. The matrix plans focused and cross-domain regression, static analysis where applicable, and mandatory `git diff --check`; incomplete checks must be reported accurately.
- **Real production state and security**: No fake materials, identifiers, recipes, conversions, warehouse, success state, authorization bypass, or live fallback is permitted. No secrets or production data changes belong to Phase 1.
- **Documentation and scope discipline**: This document distinguishes current brownfield behavior from future required behavior and labels implementation as deferred. Phase 1 changes only `.specify/feature.json` and this specification; no application, migration, test, plan, task, checklist, or runtime work is authorized.

No constitutional exception is required.
