# Cafe System 618 — Optional Product Recipe and Recipe Inheritance Plan

## Pre-Implementation Roadmap

**Status:** Ready for specification and phased implementation  
**Scope:** Menu Management, recipe configuration, publishing, POS inventory consumption, Sales Invoice consumption, and Flutter Menu Management  
**Implementation Model:** Five controlled phases  
**Current Task:** Planning only; no implementation is included in this document

---

# 1. Purpose

Change Menu Management so a product can be published and sold without any recipe.

The feature will also introduce a product-level base recipe so variants do not need duplicate recipes. Variant recipes become optional overrides, and modifier recipe adjustments remain optional.

The intended hierarchy is:

```text
Optional Product Base Recipe
        ↓ inherited by
Optional Variant Recipe Override
        ↓ adjusted by
Optional Modifier Material Effects
        ↓ resolved into
Published Effective Recipe
```

If no effective recipe exists, the product remains publishable and sellable. It produces no recipe-based inventory movement and zero inventory-derived COGS.

This document is an implementation roadmap. It is not a replacement for a formal feature specification or the implementation plan generated from that specification.

---

# 2. Clarified Business Requirement

Recipes are optional at every level.

A product such as an internet service, delivery charge, subscription, or other non-material service must be able to:

- exist without a product recipe;
- have variants without variant recipes;
- have modifiers without recipe adjustments;
- pass Menu Review without a recipe-related blocking error;
- be published normally;
- appear in POS;
- be added to an order;
- be paid normally; and
- complete without inventory consumption.

The absence of a recipe is a valid business state, not malformed configuration.

Configured recipes remain strict. If a product, variant, or modifier recipe is present, its material references, units, conversions, quantities, tenant ownership, and operations must be valid.

---

# 3. Current-System Findings

## 3.1 Current Base Recipe Authority

The active recipe domain currently stores base recipes only against product variants:

```text
variant_recipes
variant_recipe_components
```

There is no active product-level base-recipe relationship in Menu Management.

## 3.2 Current Publishing Rule

For a stock-tracked product, every active variant currently requires a non-empty variant recipe. Menu validation produces blocking errors for missing or empty recipes.

This rule must be removed. Missing recipes must no longer block validation or publication.

## 3.3 Current Modifier Behavior

Modifier recipe adjustments are already optional.

Configured profiles use this inheritance order:

```text
Variant-scoped profile
    > Product-scoped profile
        > Global profile
            > No material effect
```

This inheritance behavior must remain unchanged. Modifier selection requirements are a separate concern and must not be weakened.

## 3.4 Current Published Runtime

Publishing stores each variant's recipe in the immutable published-menu snapshot as:

```json
{
  "baseRecipe": [],
  "modifierRecipeAdjustments": []
}
```

POS payment consumes inventory from that immutable snapshot. Historical orders must continue using the recipe that was published when the order was created.

## 3.5 Current Payment Risk

Current payment logic rejects a stock-tracked item when its published `baseRecipe` is empty.

Removing only the publish validation would therefore create an unsafe flow:

```text
Publish succeeds
→ order succeeds
→ payment fails because the recipe is empty
```

The payment and warehouse-preflight paths must be changed in the same feature.

## 3.6 Secondary Sales Invoice Path

Manual Sales Invoice posting reads variant recipe tables directly instead of using the published-menu snapshot.

It must use the same effective-recipe authority and must treat an absent recipe as a valid zero-consumption line.

## 3.7 Existing Legacy Recipe Tables

The repository also contains older `recipes` and `recipe_lines` tables with version, yield, wastage, and active-state concepts. They are not the active Menu Management recipe contract.

Do not reuse or delete those tables implicitly. Any consolidation of that older schema requires a separate decision and a production-data audit.

---

# 4. Non-Negotiable Domain Decisions

## 4.1 Recipe Optionality

The following are all valid:

```text
Product without a recipe
Variant without an override
Modifier option without material effects
Published variant with an empty effective recipe
Paid item with no recipe-based inventory consumption
```

Missing recipe configuration must never be a publication error.

## 4.2 Effective Base Recipe

For each variant:

```text
effective base recipe = non-empty variant override
                        otherwise product base recipe
                        otherwise empty recipe
```

An empty effective recipe is valid.

## 4.3 Variant Override Semantics

A variant recipe is a complete replacement of the product base recipe, not an additive difference.

```text
No override record       → inherit product recipe
Non-empty override       → replace product recipe
Delete override          → return to product inheritance
No product recipe        → effective recipe is empty
```

Variant add/remove adjustments are outside this feature. Full replacement is retained because it is compatible with existing variant recipe data and requires a smaller migration.

## 4.4 Empty Variant Writes

An empty variant override must not become an ambiguous persistent state.

The specification must choose and document one of these equivalent API behaviors:

- `PUT components: []` removes the override and returns the inherited result; or
- `PUT components: []` is rejected and clients must call `DELETE`.

Recommended behavior: provide `DELETE` explicitly and treat `PUT []` as removing the override for backward compatibility.

## 4.5 Modifier Semantics

Modifier material effects remain optional and retain their current rules:

- global, product, and variant scope precedence remains intact;
- an explicit empty modifier profile may suppress an inherited profile;
- configured `add` and `remove` components must be valid;
- quantity-enabled groups cannot use unsupported remove behavior;
- aggregate removes cannot exceed the effective base recipe;
- absence of a modifier recipe means no inventory effect.

Do not confuse an optional modifier recipe with an optional modifier selection. Required modifier groups and selection limits remain authoritative.

## 4.6 Publishing Without a Recipe

Menu Review and publishing must allow an empty effective recipe.

The following errors must no longer block publication:

```text
VARIANT_RECIPE_MISSING
VARIANT_RECIPE_EMPTY
```

The UI may show a localized informational status or warning, but it must be non-blocking.

## 4.7 Configured Recipe Validity

Optional means that a recipe may be absent. It does not mean an invalid configured recipe may be published.

When components exist, continue validating:

- material belongs to the tenant;
- material is eligible for recipe consumption;
- material is active and available;
- inventory base unit is mapped;
- selected recipe unit is authorized;
- required unit conversion is active and valid;
- converted quantity is representable at inventory precision;
- quantity is a positive decimal with at most six decimal places;
- duplicate material rules are enforced;
- modifier operations are `add` or `remove`; and
- modifier removal never produces an invalid effective result.

## 4.8 Runtime Consumption Without a Recipe

At payment or Sales Invoice posting:

```text
effective recipe has components
→ perform authoritative inventory movement and WAC COGS calculation

effective recipe is empty
→ no inventory movement
→ inventory-derived COGS is zero
→ payment/posting continues normally
```

No synthetic material, fake recipe, fallback component, or live-recipe substitution may be invented.

## 4.9 Stock-Tracking Flag

Service products should normally use `isStockTracked = false`.

However, recipe absence must still not block publishing or payment if a product is marked as stock-tracked. In that state, the line has no recipe-based material consumption.

The UI should make this state understandable, but it must not silently change the product's stock-tracking flag.

## 4.10 Warehouse Preflight

Warehouse readiness must be required only when at least one payable line has actual recipe components to consume.

A product flag alone must not require a warehouse when the item's immutable published effective recipe is empty.

## 4.11 Published Snapshot Authority

Publishing must continue resolving the catalog configuration into each published variant's existing `baseRecipe` field.

```text
Product recipe or variant override
→ resolve effective recipe
→ serialize into variant.baseRecipe
```

When no effective recipe exists:

```json
"baseRecipe": []
```

Do not make POS resolve product/variant recipe inheritance itself.

## 4.12 Historical Compatibility

Existing published schema-v3 payloads must remain readable and payable.

Old orders must continue consuming their frozen historical recipe. A later product recipe or override change must not affect existing orders.

The preferred design keeps snapshot schema version 3 because the runtime fields do not need to change.

## 4.13 Tenant Isolation

Every product recipe, component, override, modifier profile, material lookup, preview, publication, and consumption query must remain tenant-scoped.

Cross-tenant material IDs, products, variants, and modifiers must be rejected.

---

# 5. Target Data Model

Introduce explicit product recipe tables consistent with the active variant recipe domain:

```text
product_recipes
├── id
├── tenant_id
├── product_id
├── created_at
└── updated_at

product_recipe_components
├── id
├── tenant_id
├── product_recipe_id
├── inventory_item_id
├── quantity decimal(18,6)
├── unit_code
├── sort_order
├── created_at
└── updated_at
```

Required constraints:

- unique `(tenant_id, product_id)` product recipe;
- unique `(product_recipe_id, inventory_item_id)` component;
- cascade component deletion when its product recipe is deleted;
- preserve referenced Inventory materials rather than cascading their deletion;
- add tenant/material indexes matching the variant component tables.

Add a `Product::recipe()` relationship and dedicated product recipe/component models.

---

# 6. Target API Contract

## 6.1 Product Base Recipe

```http
GET /api/v1/admin/catalog/products/{product}/recipe
PUT /api/v1/admin/catalog/products/{product}/recipe
DELETE /api/v1/admin/catalog/products/{product}/recipe
```

Suggested response:

```json
{
  "productId": 42,
  "configured": true,
  "components": []
}
```

## 6.2 Variant Recipe Override

Keep the existing variant endpoints and add explicit deletion:

```http
GET /api/v1/admin/catalog/product-variants/{variant}/recipe
PUT /api/v1/admin/catalog/product-variants/{variant}/recipe
DELETE /api/v1/admin/catalog/product-variants/{variant}/recipe
POST /api/v1/admin/catalog/product-variants/{variant}/recipe/resolve
```

Suggested response:

```json
{
  "variantId": 7,
  "hasOverride": false,
  "source": "product",
  "overrideComponents": [],
  "effectiveComponents": []
}
```

Valid `source` values:

```text
variant
product
none
```

Separate override components from effective components so the editor cannot accidentally save inherited components as a new override.

## 6.3 Variant Summary Fields

Replace or extend the ambiguous direct-recipe summary with:

```json
{
  "effectiveRecipeConfigured": true,
  "effectiveRecipeComponentCount": 2,
  "recipeSource": "product",
  "hasRecipeOverride": false
}
```

Maintain old fields temporarily only if compatibility requires them. Document their deprecation semantics if retained.

---

# 7. Five-Phase Implementation Plan

## Phase 1 — Specification and Contract Lock

### Objective

Convert this roadmap into an unambiguous implementation specification before changing code.

### Required work

- Confirm the product recipe and variant override API shapes.
- Lock the `PUT []` and `DELETE` semantics.
- Define effective-recipe precedence.
- Define missing-recipe Review & Publish presentation as non-blocking.
- Define empty-recipe payment and Sales Invoice behavior.
- Define warehouse-preflight behavior.
- Confirm schema-v3 snapshot retention.
- Define migration/backfill behavior for existing variant recipes.
- Define compatibility expectations for older Flutter clients if applicable.
- Record explicit exclusions.

### Required decisions

- Whether missing recipes produce a warning or no issue at all.
- Whether product recipes may be deleted while overrides exist.
- Whether an archived/inactive product recipe remains readable but not writable.
- Whether `PUT []` deletes a recipe or stores an empty parent row.

### Deliverable

A reviewed specification containing scenarios, API examples, migration rules, acceptance criteria, and the test matrix.

### Exit criteria

- No unresolved inheritance semantics.
- No unresolved empty-recipe runtime behavior.
- No ambiguity between recipe optionality and modifier selection requirements.
- No implementation work started.

---

## Phase 2 — Backend Recipe Domain and API

### Objective

Add product base recipes and optional variant overrides with one authoritative effective-recipe resolver.

### Required work

- Add product recipe migrations and constraints.
- Add product recipe models and relationships.
- Extend the recipe configuration service for product recipes.
- Add product recipe GET/PUT/DELETE endpoints.
- Add variant recipe DELETE behavior.
- Change variant recipe reads to expose override and effective state separately.
- Implement one effective base-recipe resolver.
- Reuse current material, unit, conversion, quantity, and eligibility validation.
- Add audit entries for create, replace, clear, inherit, and override removal.
- Update product and variant resource summaries.
- Preserve archived-data readability and tenant isolation.

### Migration policy

Safest initial migration:

1. Create product recipe tables.
2. Copy the non-empty default variant recipe into the product base recipe when available.
3. Keep all existing non-empty variant recipes as explicit overrides.
4. Do not delete or deduplicate existing variant components automatically.
5. Treat existing empty variant recipe rows as no override.
6. Do not touch immutable published snapshots.
7. Audit the older `recipes`/`recipe_lines` data before any attempted consolidation.

### Tests

- Product recipe CRUD and empty clearing.
- Variant inheritance without an override.
- Variant full replacement override.
- Override removal returns to inheritance.
- Product without recipe resolves to an empty effective recipe.
- Existing variant-only recipes remain effective after migration.
- Material eligibility and unit conversion validation.
- Inactive/archived material diagnostics.
- Cross-tenant product, variant, and material rejection.
- Archived/inactive lifecycle behavior.

### Exit criteria

- Backend API contract matches Phase 1.
- Effective recipe resolution has one authoritative implementation.
- Existing recipe behavior is preserved through variant overrides.
- Focused backend tests pass serially.
- No publishing, runtime-consumption, or Flutter work is claimed complete yet.

---

## Phase 3 — Publishing, POS Consumption, and Sales Invoice Runtime

### Objective

Make optional recipes safe across validation, publication, payment, inventory, COGS, and historical flows.

### Required work

- Remove missing/empty recipe publication blockers.
- Continue blocking malformed configured recipes.
- Validate product recipe components and variant override components.
- Make modifier remove checks use the effective base recipe.
- Make combined modifier remove checks use the effective base recipe.
- Update preview recipe status and counts to use effective recipes.
- Serialize effective components into the existing published `baseRecipe`.
- Serialize an empty array when no effective recipe exists.
- Keep modifier adjustment serialization unchanged.
- Change POS payment consumption so an empty `baseRecipe` is valid zero consumption.
- Change warehouse preflight to inspect actual payable recipe consumption.
- Preserve WAC and inventory authority when components exist.
- Change Sales Invoice preview/posting to use the same effective recipe contract.
- Preserve idempotency and rollback guarantees.
- Preserve historical schema-v3 snapshots and orders.
- Ensure published-version comparison still reports effective recipe changes.

### Important runtime rule

Do not fall back from a pinned published order to the current live product recipe.

```text
Pinned snapshot exists
→ use snapshot baseRecipe, including an intentional empty array

No compatible pinned snapshot for a tracked historical line
→ preserve the existing historical safety policy
```

### Tests

- Publish service product with no recipe.
- Publish stock-tracked product with no recipe.
- Publish inherited product recipe.
- Publish variant override.
- Publish configured invalid product recipe is blocked.
- Publish configured invalid modifier adjustment is blocked.
- Empty effective recipe produces `baseRecipe: []`.
- POS payment succeeds without recipe consumption.
- Empty recipe does not require a warehouse.
- Non-empty recipe still requires an authoritative warehouse.
- Non-empty recipe consumes correct canonical quantities and WAC COGS.
- Modifier additions and removals consume the correct final quantities.
- Sales Invoice without recipe posts with zero inventory COGS.
- Sales Invoice with inherited or overridden recipe consumes correctly.
- Existing schema-v3 published orders remain payable and resumable.
- Payment retries remain idempotent.
- Recipe changes do not mutate historical snapshots.

### Exit criteria

- No recipe-related path can publish successfully and then fail merely because the recipe is empty.
- POS and Sales Invoice agree on optional-recipe behavior.
- Inventory movement remains server-authoritative whenever components exist.
- Focused publication, payment, inventory, Finance, and historical tests pass serially.
- Flutter implementation has not begun unless Phase 3 is accepted.

---

## Phase 4 — Flutter Menu Management Experience

### Objective

Expose the new product base recipe and optional inheritance model without redesigning the broader Product workspace.

### Product Recipe workspace

Restructure the existing `Recipe & Materials` tab into:

```text
Product Base Recipe
Variant Overrides
Modifier Material Effects
Test Recipe
```

### Product Base Recipe behavior

- Display first in the workspace.
- Allow add, edit, clear, and retry.
- Show “No base recipe” as a valid state.
- Explain that products without recipes consume no inventory materials.
- Never present missing recipe as a blocking error.

### Variant Override behavior

Each variant must show one of:

```text
Uses product recipe
Variant override configured
No effective recipe
Not inventory tracked
```

Required actions:

- create override;
- edit override;
- remove override and return to inheritance;
- clearly distinguish inherited components from editable override components.

### Modifier behavior

- Preserve global/product/variant inheritance.
- Present “No material effect” as valid.
- Retain explicit suppression of inherited modifier effects.
- Do not alter modifier selection requirements.

### Recipe simulation

- Select a variant.
- Resolve its product recipe or variant override.
- Apply selected modifier effects.
- Display final canonical Inventory quantities.
- Allow an empty successful result and explain that no materials will be consumed.

### Client contract changes

- Add product recipe repository methods.
- Expand variant recipe models with `hasOverride`, `source`, `overrideComponents`, and `effectiveComponents`.
- Update Cubit state so inherited data is never saved accidentally.
- Update variant summary parsing.
- Update route locations for product recipe editing and variant override editing.
- Keep errors localized and do not expose raw backend text.

### Tests

- Product base recipe loads and saves.
- No product recipe renders as a valid empty state.
- Variant inherits product recipe.
- Variant override creation and editing.
- Removing override returns to inherited presentation.
- Empty effective recipe is not shown as a blocking failure.
- Modifier with no material effect remains valid.
- Simulation accepts an empty resolved recipe.
- Exact decimal quantities and authorized unit dropdown behavior remain intact.
- Inactive stored materials remain visible and replaceable.
- EN/AR localization, RTL, focus, and accessibility coverage.
- Route and back-navigation behavior.

### Exit criteria

- The UI accurately distinguishes own, inherited, overridden, and empty recipes.
- No inherited recipe can be overwritten accidentally.
- No missing recipe is shown as a publication blocker.
- Focused Flutter widget/controller/repository tests and static analysis pass.

---

## Phase 5 — Independent Review and Closure

### Objective

Review the entire implementation independently and close cross-layer gaps before declaring completion.

### Review areas

- Database constraints and safe migration behavior.
- Tenant isolation.
- Product/variant effective-recipe precedence.
- Empty and delete semantics.
- Modifier inheritance and remove validation.
- Menu Review warnings versus blockers.
- Published snapshot shape and checksum behavior.
- POS order and payment lifecycle.
- Warehouse preflight.
- Inventory movement and WAC COGS.
- Sales Invoice posting.
- Historical order compatibility.
- Flutter parsing, state, editing, and localization.
- Existing dirty-worktree preservation.

### Verification sequence

Run tests serially against the shared PostgreSQL testing database.

Recommended order:

1. Recipe configuration API tests.
2. Menu validation tests.
3. Menu publishing and version-history tests.
4. Full Menu Management lifecycle test.
5. POS inventory/payment integration tests.
6. Sales Invoice inventory tests.
7. Focused Flutter recipe, variant, review, repository, and navigation tests.
8. Flutter static analysis.
9. Laravel broader relevant suites if the focused gates pass.
10. `git diff --check` and changed-file scope review.

Do not run Laravel suites concurrently against the shared PostgreSQL test database.

### Closure evidence

The final implementation report must include:

- exact changed files;
- migration behavior;
- final API contract;
- observed test commands and exit results;
- any skipped or timed-out verification;
- confirmation that no unrelated features were changed;
- confirmation that old published snapshots remain supported.

### Exit criteria

- All acceptance scenarios have evidence.
- No publication/payment contradiction remains.
- No current or historical inventory path reads the wrong recipe source.
- Any failure or unverified check is reported explicitly.

---

# 8. Explicit Exclusions

This feature must not introduce:

- automatic recipe generation;
- guessed material quantities;
- automatic Inventory unit conversions;
- variant add/remove recipe deltas;
- recipe costing redesign;
- recipe yield or wastage management;
- production/batch recipes;
- inventory material auto-creation;
- changes to modifier selection rules;
- POS UI redesign;
- Menu Management navigation redesign;
- deletion of historical published versions;
- live-recipe fallback for pinned orders;
- unrelated Discount, Customer, Finance, or Inventory features; or
- consolidation of legacy `recipes`/`recipe_lines` without a separate approved scope.

---

# 9. Acceptance Scenarios

## Scenario A — Internet Service Without Recipe

```text
Given an active product with an active default variant
And no product recipe
And no variant override
When the manager validates and publishes the menu
Then publication succeeds
And POS can sell the item
And payment succeeds
And no inventory movement is written
And inventory-derived COGS is zero
```

## Scenario B — Product Base Recipe Inheritance

```text
Given a product recipe
And multiple active variants without overrides
When the menu is published
Then every variant receives the effective product recipe in baseRecipe
And selling any variant consumes the product recipe quantities
```

## Scenario C — Variant Override

```text
Given a product recipe
And one variant with its own non-empty override
When the menu is published
Then the overridden variant uses its own recipe
And all other variants inherit the product recipe
```

## Scenario D — Modifier Without Recipe

```text
Given a valid modifier option with no material profile
When it is selected for an order item
Then selection and payment succeed
And it makes no change to material consumption
```

## Scenario E — Invalid Configured Recipe

```text
Given a configured recipe referencing an inactive material or invalid conversion
When the menu is validated
Then publication is blocked with an actionable localized recipe error
```

## Scenario F — Remove Override

```text
Given a variant override
When the manager removes it
Then the variant immediately inherits the product recipe
And subsequent publications use that inherited recipe
And previous published versions remain unchanged
```

## Scenario G — No Warehouse for Empty Recipe

```text
Given an order whose payable lines have empty published baseRecipe arrays
When payment preflight runs
Then no inventory warehouse is required
And payment may complete normally
```

## Scenario H — Historical Safety

```text
Given an existing order pinned to a schema-v3 published version
When live product and variant recipes later change
Then payment or resume continues using the pinned historical baseRecipe
```

---

# 10. Recommended Prompt Boundaries

Use one implementation prompt per phase.

Every implementation prompt should include:

> Implement ONLY this phase. Preserve unrelated worktree changes. Do not begin the next phase. Keep backend authority and historical compatibility. Do not claim success without observed terminal evidence.

Recommended sequence:

```text
Prompt 1: Specification and contract lock
Prompt 2: Backend product recipe and inheritance domain
Prompt 3: Publishing, POS, Sales Invoice, and inventory runtime
Prompt 4: Flutter Menu Management implementation
Prompt 5: Independent review, regression repair, and closure
```

Do not combine Phases 2 and 3 unless the implementation model can independently verify payment, Sales Invoice, and historical snapshot behavior. Those paths carry the highest inventory and financial risk.

---

# 11. Definition of Done

The feature is complete only when all of the following are true:

- any valid product can be published without a recipe;
- missing recipes never block Review & Publish;
- product base recipes can be configured independently of variants;
- variants inherit product recipes by default;
- variants may define and remove full overrides;
- modifier material effects remain optional and hierarchical;
- configured recipes remain strictly validated;
- published snapshots contain the resolved effective recipe or an empty array;
- empty recipes do not block POS payment;
- empty recipes do not require an inventory warehouse;
- empty recipes create no inventory movements and zero inventory-derived COGS;
- POS and Sales Invoice follow the same optional-recipe rule;
- historical published orders retain their original recipe behavior;
- tenant isolation is preserved;
- Flutter clearly communicates inherited, overridden, and empty states;
- focused and relevant regression suites pass with observed evidence; and
- no unrelated features or architecture boundaries are changed.
