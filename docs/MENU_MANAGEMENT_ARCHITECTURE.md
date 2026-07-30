# Menu Management Architecture

## Phase status

**Phase 1: Backend Menu Domain and Database Schema**

Status: Implemented — migrations and the full backend test suite pass in the backend container.

## Database environment safety

Phase 1 runtime verification previously used `cafe_system_618`, the development PostgreSQL database, because testing isolation was missing. That command may have deleted development data that was not recreated by seeders; no restoration is claimed by this repository.

Development uses `cafe_system_618`; Laravel tests and `--env=testing` migrations use only `cafe_system_618_testing`. Configure the ignored local `backend/.env.testing` from `backend/.env.testing.example` with the Docker PostgreSQL host, port, and local credentials, keeping `APP_ENV=testing` and `DB_DATABASE=cafe_system_618_testing`.

Create the test database once (from the repository root) without altering the development database:

```powershell
$exists = docker compose exec -T postgres psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'cafe_system_618_testing'"
if ($null -eq $exists -or $exists.Trim() -ne '1') { docker compose exec -T postgres createdb -U postgres cafe_system_618_testing }
```

Safe verification commands are `docker compose exec backend php artisan optimize:clear --env=testing`, `docker compose exec backend php artisan about --env=testing`, `docker compose exec backend php artisan migrate:fresh --seed --env=testing`, and `docker compose exec backend php artisan test`. Never run `migrate:fresh` against development or without `--env=testing`. An early Laravel configuration guard rejects the development database and non-test-suffixed names before destructive testing migrations can begin.

## Phase 2A: Backend Catalog APIs

Status: Complete only when the full backend suite passes. Phase 1 — Backend Menu Domain and Database Schema: Complete. Phase 1.5 — Isolated Testing Database: Complete. Phase 2A — Backend Catalog APIs: Complete. Phase 2B — Backend Menu Composition APIs: Complete. Phase 2C — Pricing and Availability APIs: Not started. Phase 3 — Preview, Validation, and Publishing: Not started.

Tenant Admin Catalog APIs are under `/api/v1/admin/catalog`, separate from the temporary POS `/api/v1/menu` namespace. They use the existing `TenantContext` (`X-Tenant-Id` and development first-tenant fallback); authentication remains deferred. The API manages Categories, Reporting Categories, Kitchen Stations, Products, Product Variants, Modifier Groups, Modifier Options, and reusable Product–Modifier Group assignments.

Product creation is transactional and requires one or more Variants with exactly one active Default Variant. The Default Variant mirrors its price, cost, SKU, and barcode into the legacy Product fields so the unchanged POS catalog still reads the correct values. Product and Variant archive/restore flows preserve records and order snapshots through soft deletes. Product references must be active and tenant-owned; archived reporting categories and kitchen stations cannot be newly assigned.

Modifier Groups are reusable. Their option counts, selection type, required minimum/maximum values, default options, and product-level overrides are validated before synchronization. Catalog changes are written to `menu_audit_logs` without using global observers.

## Phase 2B: Admin Menu Composition APIs

Tenant Admin Menu composition routes live under `/api/v1/admin/menus`; Product usage is available at `/api/v1/admin/catalog/products/{product}/menu-usage`. The controllers use the existing `TenantContext`, so `X-Tenant-Id` and the first-tenant development fallback remain in place and authentication is still deferred.

Menus are editable composition records, not Published snapshots. They support list filters (`search`, `status`, `branchId`, `channel`, `hasAssignments`), pagination, archive/restore, and transactional priority reordering. A restored Menu becomes `draft`; archival preserves all Sections, Placements, Assignments, and Availability Rules without affecting Catalog records.

Catalog Categories organize Products centrally. A Menu Section organizes the display of existing Products inside one Menu. A placement is display composition only: it references a Product and may override display name, description, or image, but never duplicates Product prices, Variants, Modifiers, kitchen routing, or reporting classification. Sections and placements are soft-deleted and can be restored; placements support reorder, move, and complete transactional synchronization.

Assignments are complete Branch/Channel configuration sets, allowing multiple Menus to target the same Branch/Channel and retaining a priority for later precedence work. Menu Availability Rules are complete schedule sets: Branch and Channel are optional, `dayOfWeek` is 0–6, time pairs may cross midnight, and no rules means no Menu-level schedule restriction. Rules are stored only; this phase does not evaluate availability.

Product Menu Usage returns active placement locations by default and accepts `includeArchived=true` for Admin diagnostics. All Menu composition changes write bounded before/after entries to `menu_audit_logs`, with `menu_publication_id = null`. Cross-tenant route resources return 404 and foreign submitted IDs return generic validation errors.

Pricing, Operational Availability, Preview, Publishing, snapshots, POS sync, Flutter, Authentication, Combos, Recipes, and Inventory remain untouched in Phase 2B. The temporary POS routes remain unchanged.

## Phase 2C.1: Variant Price Override APIs

Status: Complete only after the full backend test suite passes. Phase 2C.2 â€” Product Availability APIs: Not started.

Tenant Admin pricing routes are under `/api/v1/admin/catalog/product-variants/{variant}`:

- `GET /price-overrides` lists the non-archived overrides for a Variant.
- `PUT /price-overrides` transactionally synchronizes the complete set.
- `GET /effective-price?branchId=&channel=` previews the resolved price without changing the Variant, Product, or Order.

The supported scopes are `branch`, `channel`, and `branch_channel`. The client never submits a scope key; the backend constructs the canonical database key as `branch:{branchId|*}|channel:{channel|*}`. Branches must be active and owned by the current tenant, and channels use the `SalesChannel` enum. Duplicate canonical scopes are rejected.

Synchronization creates, updates, restores a same-scope soft-deleted override, and soft-archives any omitted active override in one transaction. Changes are logged in `menu_audit_logs` with `menu_publication_id = null`, using bounded scope and price data plus a summary.

Effective-price resolution is `branch_channel`, then `branch`, then `channel`, then the Variant `base_price`. Inactive, soft-deleted, foreign, and invalid/archived-branch overrides are ignored. Price Overrides never copy into `products.price` or `product_variants.base_price`; existing Order snapshots remain unchanged, and the temporary POS catalog does not consume overrides yet. Authentication remains deferred.

## Phase 2C.2A: Scheduled Product Availability APIs

Status: Complete only after the full backend test suite passes. Phase 2C.2B â€” Operational Availability: Not started.

`GET` and transactional `PUT /api/v1/admin/catalog/products/{product}/availability-rules` manage a Product's complete scheduled rule set. A rule with no `productVariantId` applies at Product level; a rule with a tenant-owned, non-archived Variant ID applies to that Variant only. Product and Variant rules may each target the global scope, a Branch, a Sales Channel, or an exact Branch + Channel pair. Branches must be active and tenant-owned; channels use `SalesChannel`.

`GET /api/v1/admin/catalog/products/{product}/availability-preview` is a narrow Admin diagnostic endpoint. It evaluates only saved scheduled rules at a supplied date/time. When `branchId` is supplied, evaluation uses that Branch's timezone; otherwise it uses the submitted timezone or application timezone.

Rules are positive availability windows. No applicable configured schedule means unrestricted availability. If a matching Variant-level scope exists it governs before Product-level rules; then Branch + Channel, Branch, Channel, and Global select the governing scope. Within that scope, a matching window with the highest priority wins. If its configured scope has no matching window at the requested time, availability is false with `outside_schedule`. Weekly day rules and date ranges are both conjunctive when present. A `22:00`â€“`02:00` rule is anchored on the starting date/day and correctly remains available after midnight. Rules are soft-deleted on synchronization omissions and audit to `menu_audit_logs` with no publication ID.

Scheduled availability is intentionally separate from Operational Sold Out/remaining quantity tables. The current POS does not consume these rules, and authentication remains deferred.

## Domain boundaries

`products` is the canonical Catalog Item entity. No `items`, `menu_items`, or `catalog_items` table exists. `product_variants` are sellable versions of a Product, beginning with one `Regular` Default Variant for each legacy Product.

`categories` organize the Catalog. `reporting_categories` are a separate sales and analytics classification. `menu_sections` organize display within a Menu, while `menu_item_placements` define a Product's appearance inside a Section. Placements never copy product pricing, variant, or modifier definitions.

```text
Central Catalog (products)
  -> Product variants and modifiers
  -> Menu composition (menus, sections, placements)
  -> Branch/channel assignments and availability rules
  -> Future draft validation, preview, and publishing
  -> Immutable published menu version
  -> Future POS sync + operational sold-out overlay
```

## Phase 1 schema

Reference tables: `reporting_categories` and tenant/optional-branch `kitchen_stations`.

Existing `products` has nullable localized names/descriptions, `product_type`, reporting category, kitchen station, and preparation time. Legacy `products.price`, `cost_price`, `sku`, and `barcode` remain temporarily so the POS Catalog API continues to work. New domain code will use `product_variants` in later phases.

The product-variants migration backfills a Default `Regular` Variant for each existing Product, including inactive Products, without changing IDs, prices, orders, or legacy Product fields. Existing Modifier Groups named Size, Sizes, or Cup Size are intentionally untouched; they require an explicit migration or manual review in a later phase.

Modifier groups now distinguish business purpose (`group_type`: choice, add_on, preparation_instruction) from selection behavior (`selection_type`: single/multiple). Options add `cost_delta` and structural `is_active`; the legacy operational `is_available` remains. Product/group pivot overrides and order-item-modifier quantity are additive.

Menu composition adds `menus`, `menu_sections`, `menu_item_placements`, and `menu_assignments`. Pricing adds `product_variant_price_overrides`, using a non-null canonical scope key. Scheduled availability uses explicit menu and product rule tables. Immediate operational availability is separate in product and variant operational availability tables; absent rows mean no operational override.

Publishing preparation adds `menu_publications`, immutable-intent `published_menu_versions`, and `menu_audit_logs`. Orders can later reference a Variant and a Published Menu Version while retaining their existing immutable product and price snapshots.

## Deferred application invariants

Portable database constraints cannot fully express tenant ownership and temporal domain rules. Phase 2 use cases must enforce: sellable active Products have active Variants; each Product has exactly one active Default Variant; related Products, Variants, Modifiers, Menus, Sections, Placements, Assignments, Branches, and Users share a Tenant; a Variant availability rule belongs to its Product; only one version is current per Tenant/Branch/Channel; and published payloads are immutable.

## Explicitly not included

No Admin Menu APIs, publish service, preview, snapshot generation, POS sync, Flutter Menu Management, authentication change, Combo logic, recipes, inventory/sold-out automation, or delivery integrations are implemented in this phase. The current POS endpoints remain temporary and use legacy Product fields:

- `GET /api/v1/menu/categories`
- `GET /api/v1/menu/products`
- `GET /api/v1/menu/products/{product}`
