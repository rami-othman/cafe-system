# Menu Management Architecture

## Phase status

## Phase 4A: Flutter foundation and read-only Product Catalog

Status: Complete after the Flutter analyzer and full test suite pass.

The Windows Flutter application exposes `/menu-management`, which redirects to
`/menu-management/products`, and `/menu-management/products/:productId` for a
read-only product detail page. It uses the real tenant-scoped Admin Catalog
APIs: products, categories, reporting categories, and kitchen stations. List
filters, search, sorting, and pagination remain server-side; reference-data
failures do not prevent product-list use.

There is no mock Menu data or Menu repository. Phase 4A contains no create,
edit, archive, restore, variant, modifier, menu-builder, availability,
publishing, version-history, rollback, POS-sync, authentication, combo, or
inventory UI. Product editing, variants, and modifiers begin in Phase 4B.
POS continues to use the temporary `/api/v1/menu` Catalog API. Publishing UI
and authentication remain deferred.

## Phase 4B.1: Flutter Product General Editor

Status: Complete after the Flutter analyzer and full test suite pass.

Flutter now supports `/menu-management/products/create` and
`/menu-management/products/:productId/edit`. Create sends the Product general
fields plus exactly one required active Default Variant (`isDefault: true`,
`isActive: true`, `sortOrder: 0`) to `POST /api/v1/admin/catalog/products`.
The initial Variant name defaults to `Regular` but remains user-editable; a
standard Product requires its base price while an open-price Product can start
at zero.

General editing calls `PATCH /api/v1/admin/catalog/products/{product}` with
product fields only. It neither resends nor mutates Variants, and displays the
current Default Variant read-only. Full Variant/Pricing management starts in
Phase 4B.2. Modifier management, Menu Builder, Publishing UI, POS sync,
authentication, combos, and inventory remain unimplemented.

## Phase 4B.2: Flutter Product Variants and Base Pricing

Status: Complete. Flutter analyzer and full test suite pass.

`/menu-management/products/:productId/variants` manages a Product's active,
archived, and combined Variant lists. It supports create, edit, dedicated
Default selection, archive/restore, and complete active-list reordering. Base
Price and Cost Price are Variant fields; Branch and Channel Price Overrides
remain a later phase and are intentionally not shown in this UI.

Default selection always uses the dedicated endpoint. The Default Variant must
be active. Archiving the Default Variant requires choosing another active
Variant from the same Product; the only active Variant cannot be archived.
When a Product has no active Default Variant, restoring a Variant requires
`makeDefault: true` under the backend contract.

Every successful Variant mutation reloads Product Detail data and invalidates
the Product Catalog because the backend synchronizes the Default Variant's
base price, cost, SKU, and barcode into legacy Product fields for temporary POS
compatibility. Modifier Library management remains Phase 4B.3.

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

Status: Phase 2C.1 — Price Overrides: Complete. Phase 2C.2A — Scheduled Availability: Complete. Phase 2C.2B — Operational Availability: Complete only after the full backend test suite passes. Phase 3 — Preview, Validation, and Publishing: Not started.

`GET` and transactional `PUT /api/v1/admin/catalog/products/{product}/availability-rules` manage a Product's complete scheduled rule set. A rule with no `productVariantId` applies at Product level; a rule with a tenant-owned, non-archived Variant ID applies to that Variant only. Product and Variant rules may each target the global scope, a Branch, a Sales Channel, or an exact Branch + Channel pair. Branches must be active and tenant-owned; channels use `SalesChannel`.

`GET /api/v1/admin/catalog/products/{product}/availability-preview` is a narrow Admin diagnostic endpoint. It evaluates only saved scheduled rules at a supplied date/time. When `branchId` is supplied, evaluation uses that Branch's timezone; otherwise it uses the submitted timezone or application timezone.

Rules are positive availability windows. No applicable configured schedule means unrestricted availability. If a matching Variant-level scope exists it governs before Product-level rules; then Branch + Channel, Branch, Channel, and Global select the governing scope. Within that scope, a matching window with the highest priority wins. If its configured scope has no matching window at the requested time, availability is false with `outside_schedule`. Weekly day rules and date ranges are both conjunctive when present. A `22:00`â€“`02:00` rule is anchored on the starting date/day and correctly remains available after midnight. Rules are soft-deleted on synchronization omissions and audit to `menu_audit_logs` with no publication ID.

Scheduled availability is intentionally separate from Operational Sold Out/remaining quantity tables. The current POS does not consume these rules, and authentication remains deferred.

## Phase 2C.2B: Operational Availability and Sold Out APIs

Operational Availability is an immediate mutable runtime overlay, entirely separate from scheduled availability, structural product status, menu visibility, inventory, and publishing. Admin routes under `/api/v1/admin/catalog` manage Product- and Variant-level overrides for one active tenant Branch and either a `SalesChannel` or the internal `all` channel scope. `all` is not a public `SalesChannel` value; it means every channel in the selected Branch.

For a Variant request, resolution is deterministic: Variant + exact Channel, Variant + all Channels, Product + exact Channel, Product + all Channels, then no override (available). An explicit narrower `available` row therefore overrides a broader `sold_out` row. Expired non-available records (`unavailableUntil <= evaluated time`) are ignored but retained for diagnostics; evaluation uses the Branch timezone. The resolver intentionally does not inspect scheduled rules. A combined resolver belongs to a later preview/publishing phase.

Overrides support `available`, `sold_out`, and `temporarily_unavailable`. Temporary unavailability requires a future expiration. `available` normalizes reason and expiration to null. `remainingQuantity` is returned and audited but informational only: it is not deducted by Orders, does not infer sold-out state, and has no Inventory integration. PUT upserts a unique Product/Variant + Branch + Channel scope transactionally; DELETE clears only that exact runtime row and is idempotent. Changes use bounded audit snapshots in `menu_audit_logs` with no publication ID.

The list and single-product diagnostic preview endpoints are Admin-only. Archived Product/Variant records are hidden from the list by default (with `includeArchived=true` for diagnostics). POS does not consume operational overlays yet, and authentication remains deferred.

## Phase 3A: Menu Publish Validation

`POST /api/v1/admin/menus/{menu}/validate` validates one editable Menu for an active Branch and Sales Channel. `POST /api/v1/admin/menu-management/validate` validates supplied `menuIds`, or every active Menu Assignment for that Branch and Channel when IDs are omitted. Both return stable machine-readable issues grouped as `errors`, `warnings`, and `information`, plus a per-Menu summary. Errors are the only severity that blocks future publishing; warnings and information are diagnostic.

Validation is strictly read-only: it creates no audit logs, publications, versions, snapshots, or repairs. It reuses the price, scheduled availability, and operational availability resolvers using the Branch timezone. Base-price fallback, scheduled outside-window state, active sold-out state, absent Menu schedules, hidden placements, and legacy size-like modifier groups are warnings. Empty active Sections are also warnings when another Section can still provide visible placements. Missing/archived Categories and invalid catalog or modifier configurations are errors; missing reporting categories and kitchen stations are warnings.

The phase validates only editable data readiness. Publishing, snapshots, POS sync, Flutter, authentication, combos, and Inventory remain unimplemented. Status: Phase 3A — Menu Validation: Complete. Phase 3B — Menu Preview: Complete. Phase 3C — Publishing and Snapshots: Not started.

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

## Phase 3C.1: Publishing and Immutable Snapshots

Status: Phase 3A — Validation: Complete. Phase 3B — Preview: Complete. Phase 3C.1 — Publishing and Snapshots: Complete. Phase 3C.2 — Version History and Rollback: Not started.

`POST /api/v1/admin/menu-management/publish` publishes active assigned Menus for one tenant Branch and Sales Channel. `GET /api/v1/admin/menu-management/current-version?branchId=&channel=` returns current Version metadata only. Validation errors create a failed Publication and return 422; warnings permit publishing. Each flow records a pending Publication, validates, takes a PostgreSQL advisory transaction lock for its tenant/branch/channel scope, creates a deterministic static snapshot, and hashes canonical JSON with SHA-256. Changed payloads supersede the previous current Version; identical checksums record a no-change Publication without a duplicate Version. Database uniqueness additionally guarantees one current Version per scope.

Snapshots contain static localized Menu composition, active visible catalog records, schedule rules, effective Branch/Channel Variant prices, modifiers, and ordering. They deliberately exclude operational sold-out/temporary availability, remaining quantity, evaluated availability/sellability values, Preview time/context, and validation diagnostics. Authentication remains deferred. Version History, comparison, rollback, POS snapshot consumption/sync, Flutter, Combos, and Inventory remain unimplemented.

## Phase 3B: Resolved Menu Preview

Status: Phase 3A — Menu Validation: Complete. Phase 3B — Menu Preview: Complete. Phase 3C — Publishing and Snapshots: Not started.

`POST /api/v1/admin/menus/{menu}/preview` resolves one tenant-owned Menu and `POST /api/v1/admin/menu-management/preview` resolves supplied `menuIds`, or every actively assigned Menu for the requested Branch and Sales Channel when IDs are omitted. These are Admin diagnostics only; POS does not consume Preview. Requests accept `branchId`, a `SalesChannel` `channel`, optional `at`, `language` (`default`, `ar`, or `en`), `includeUnavailable` (default true), and `includeHidden` (default false). Branches must be active and tenant-owned; a cross-tenant route Menu returns 404 and foreign submitted IDs return 422. Authentication remains deferred.

The response is resolved, not persisted: it contains timezone context, `canPublish`, the existing validation result, and Menus with assignment/schedule state, Sections, Placements, Products, Variants, and active Modifier Groups/Options. It never creates a publication, version, snapshot, audit event, or availability row, and does not update timestamps or order data.

Menu schedules are positive windows. Active non-archived rules select Branch + Channel, Branch, Channel, then Global scope; the highest-priority matching rule within the governing scope applies. A governing scope with no matching window is unavailable, while no applicable active rule is unrestricted. Weekdays and date ranges are conjunctive, including overnight periods anchored to their starting date/day.

Preview reuses the existing effective price, product schedule, and operational availability resolvers. A Variant is sellable only when structurally active, scheduled available, operationally available, and validly priced. A Product also requires a visible Placement and at least one sellable Variant; Inventory is not considered. Hidden placements are omitted by default and retained diagnostically with `hidden` when requested. Unavailable Products remain by default and can be filtered with `includeUnavailable=false`, without hiding validation issues. Placement text overrides localized Product text; otherwise requested language, default, then other localized values are used without writes. Archived Modifier Groups/Options are excluded, active unavailable options retain `isAvailable`, and pivot overrides are applied. Publishing, snapshots, POS sync, Flutter, Combos, and Inventory remain untouched.

## Phase 3D Version History, Comparison, and Rollback

Admin Version history and detail are tenant-scoped; detail returns immutable snapshot payload only with `includePayload=true`. Comparisons are bounded structural summaries. Historical checksums are deliberately non-unique so rollback can create a new immutable Version with an older payload. A rollback never reactivates history: it marks the prior current Version `rolled_back` and creates a new current Version under the advisory lock. The one-current-per-scope constraint remains enforced. Authentication is deferred and POS Sync remains unimplemented.
