# Cafe System 618 Laravel Backend

This Laravel application supplies API controllers and business logic for the Flutter Windows application, including the POS catalog, orders, discounts, reports, payments, and refunds.

Run it through Docker from the repository root:

```bash
docker compose exec backend php artisan migrate
```

## Database environments and safe testing

The development database is `cafe_system_618`. The PostgreSQL testing database is **always** `cafe_system_618_testing`; tests and testing migrations must never use the development database.

Create a local `backend/.env.testing` from `backend/.env.testing.example`, then supply the local PostgreSQL password. The committed example contains no real credential. Docker uses the same host (`postgres`), port (`5432`), and username pattern as development, but with `APP_ENV=testing`, `DB_CONNECTION=pgsql`, and `DB_DATABASE=cafe_system_618_testing`.

Create the isolated database once, without touching the development database, from the repository root in PowerShell:

```powershell
$exists = docker compose exec -T postgres psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'cafe_system_618_testing'"
if ($null -eq $exists -or $exists.Trim() -ne '1') { docker compose exec -T postgres createdb -U postgres cafe_system_618_testing }
```

Run backend tests only with the testing environment:

```bash
docker compose exec backend php artisan optimize:clear --env=testing
docker compose exec backend php artisan about --env=testing
docker compose exec backend php artisan migrate:fresh --seed --env=testing
docker compose exec backend php artisan test
```

The testing safety provider resolves Laravel's active database configuration before testing commands run. It rejects `cafe_system_618` and any database name without a `_testing` or `_test` suffix, preventing destructive test migrations from reaching development.

Never run `migrate:fresh` against `cafe_system_618`, and never omit `--env=testing` for a destructive testing migration. Earlier Phase 1 runtime verification accidentally used the development database because the testing environment was not isolated. No restoration is claimed here.

Tenant API authentication is deliberately not enabled yet. The current `TenantContext` keeps `X-Tenant-Id` support and its first-tenant development fallback. Tenant-owned submitted references are still validated against that resolved tenant.

Tax is configured once per tenant in `tenants.tax_rate`. New orders snapshot that value in `orders.tax_rate`, and all subsequent order recalculation uses the snapshot. The existing `/api/v1/menu/categories`, `/api/v1/menu/products`, and `/api/v1/menu/products/{product}` APIs remain the temporary POS Catalog API.

## Menu domain Phase 1

The additive Menu-domain schema keeps `products` as the canonical Catalog Item table. `product_variants` represents sellable versions, and the migration creates a default `Regular` Variant for every existing Product without changing legacy product prices or order snapshots. Legacy `products.price`, `cost_price`, `sku`, and `barcode` remain for POS compatibility; new domain code will use variants in later phases.

`categories` remain Catalog organization, while `reporting_categories` are analytics classification. Menus are composed through `menus`, `menu_sections`, and `menu_item_placements`; assignments, availability, price overrides, publication/version records, and audit records are schema-only preparation for later phases. Size-like legacy Modifier Groups are deliberately not converted into variants automatically.

There are no Admin Menu APIs, Publish Service, Flutter Menu Management, POS sync, or authentication changes in Phase 1. See [the architecture document](../docs/MENU_MANAGEMENT_ARCHITECTURE.md) for the schema and deferred invariants. Phase 1 may be marked implemented only after migrations and the full test suite pass.

## Phase 2A Admin Catalog APIs

Tenant-scoped catalog management lives under `/api/v1/admin/catalog` and continues to resolve its tenant from `X-Tenant-Id` with the existing first-tenant development fallback. Authentication is still deliberately deferred.

The API manages Categories, Reporting Categories, Kitchen Stations, Products, Product Variants, Modifier Groups, Modifier Options, and reusable Product–Modifier Group assignments. Resources use camelCase JSON fields, paginated collection metadata, archive/restore actions, tenant-safe reference validation, and `menu_audit_logs` for catalog changes.

Products are created transactionally with one or more Variants and exactly one active Default Variant. The Default Variant mirrors `basePrice`, `costPrice`, `sku`, and `barcode` into the legacy Product fields used by the temporary POS catalog endpoints. Updating or changing the Default Variant repeats that synchronization; non-default Variant changes do not. Products, references, groups, options, and variants are archived with soft deletes rather than hard-deleted.

The existing `/api/v1/menu/categories`, `/api/v1/menu/products`, and `/api/v1/menu/products/{product}` routes remain unchanged temporary POS contracts. Menu Composition, publishing, POS sync, Flutter changes, authentication, Combos, and inventory APIs are not part of Phase 2A.

## Phase 2B Admin Menu Composition APIs

Phase 2B adds tenant-scoped, editable Menu composition records under `/api/v1/admin/menus`. Menus are not Catalog Categories and Menu Sections are not Catalog Categories: Categories organize the central Product catalog, while Sections arrange existing Products for display within one Menu. Menus are editable composition records; they are not Published snapshots.

The API supports Menu list/create/show/update, archive/restore/reorder, Section management and reordering, and Product placements with display-only name, description, and image overrides. A placement always references the existing Product; it never copies prices, Variants, Modifier Groups, kitchen routing, or reporting data. Placements can be archived/restored, reordered, moved between Sections, or fully synchronized.

`GET`/`PUT /api/v1/admin/menus/{menu}/assignments` synchronizes active Branch and Sales Channel configuration. `GET`/`PUT /api/v1/admin/menus/{menu}/availability-rules` synchronizes optional schedule restrictions; no rules means no Menu-level schedule restriction, and overnight time ranges are valid. `GET /api/v1/admin/catalog/products/{product}/menu-usage` shows active placements, with `includeArchived=true` available for Admin diagnostics.

All composition writes are transactional, tenant-scoped through the existing `TenantContext` (`X-Tenant-Id` plus its first-tenant development fallback), and recorded in `menu_audit_logs` with no publication ID. Authentication remains deliberately deferred. Archive/restore never changes referenced Catalog Products; restoring a Menu returns it to `draft` and does not implicitly restore its archived children.

Current status: Phase 1 Complete; Phase 1.5 Complete; Phase 2A Complete; Phase 2B Complete. Phase 2C.1 â€” Variant Price Override APIs: Complete only after the full backend suite passes. Phase 2C.2 â€” Product Availability APIs: Not started. Phase 3 Preview, Validation, and Publishing is not started.

## Phase 2C.1 Variant Price Override APIs

`GET` and transactional `PUT /api/v1/admin/catalog/product-variants/{variant}/price-overrides` manage the complete price-override set for one tenant-owned, non-archived Variant. Overrides use `branch`, `channel`, or `branch_channel` scope. The backend alone creates the internal canonical keys: `branch:{branchId|*}|channel:{channel|*}`. Branches must be active and tenant-owned, channel values come from `SalesChannel`, prices are non-negative, and duplicate scopes are rejected.

`GET /api/v1/admin/catalog/product-variants/{variant}/effective-price?branchId=&channel=` is an Admin-only price preview. It resolves an active eligible override in priority order: Branch + Channel, Branch, Channel, then Variant base price. Inactive and archived overrides, including overrides that point to an archived or invalid Branch, are ignored. The preview does not change any data.

The `PUT` endpoint creates or updates scopes, restores a submitted same-scope archived record, and soft-archives omitted records in a single transaction. Bounded create/update/archive/restore and synchronization audit events are written to `menu_audit_logs` with no publication ID. Overrides are contextual only: they do not mutate `products.price`, `product_variants.base_price`, existing Orders, or the unchanged temporary POS Catalog responses. POS consumption of overrides and authentication remain deferred.

## Phase 2C.2A Scheduled Product Availability APIs

`GET` and transactional `PUT /api/v1/admin/catalog/products/{product}/availability-rules` manage the complete scheduled availability set for a Product. A null `productVariantId` is a Product-level rule; a supplied tenant-owned non-archived Variant ID is Variant-specific. Rules can be global, Branch-only, Channel-only, or Branch + Channel. Duplicate rules are rejected canonically across Variant, scope, weekday, times, and dates; Branches must be active and tenant-owned, and channels use `SalesChannel`.

The optional narrow Admin diagnostic endpoint is `GET /api/v1/admin/catalog/products/{product}/availability-preview`. It evaluates persisted Product/Variant schedules only, using the selected Branch timezone when a Branch is supplied. No applicable scheduled rules means unrestricted availability. Otherwise, Variant rules take precedence over Product rules, then Branch + Channel, Branch, Channel, and Global scope select the governing schedule; matching windows use highest `priority`. Weekly and date-range conditions are conjunctive. Overnight intervals such as `22:00`â€“`02:00` remain associated with their starting day/date after midnight.

Scheduled rules are separate from the untouched Operational Sold Out and remaining-quantity tables. They do not alter the POS, Orders, publishing, sync, Flutter, authentication, combos, or inventory. Current status: Phase 2C.1 — Price Overrides: Complete. Phase 2C.2A — Scheduled Availability: Complete. Phase 2C.2B — Operational Availability: Complete only after the full suite passes. Phase 3 — Preview, Validation, and Publishing: Not started.

## Phase 2C.2B Operational Availability and Sold Out APIs

Admin operational overlays use `GET /api/v1/admin/catalog/operational-availability`, exact-scope Product/Variant `PUT` and `DELETE` routes, and `GET /api/v1/admin/catalog/products/{product}/operational-availability-preview`. They are tenant-scoped immediate runtime overrides, not scheduled availability, structural status, visibility, inventory, publishing, or POS behavior. The internal `all` channel means every Sales Channel in the selected active Branch and is never added to the public `SalesChannel` enum.

For a Variant preview, the resolver selects Variant exact channel, Variant all channels, Product exact channel, Product all channels, then default available. A narrower explicit `available` record wins over broader sold-out state. Expired non-available records are ignored without deletion; Branch timezone is used to interpret preview time. `temporarily_unavailable` requires a future expiration, while `available` clears expiration and reason. `remainingQuantity` is informational only: no inventory integration, automatic deduction, or automatic sold-out behavior exists.

PUT is a transactional canonical-scope upsert and DELETE is an idempotent hard clear of only that overlay row. Writes produce bounded audit snapshots in `menu_audit_logs` with a null publication ID. The list is paginated and can include archived diagnostic records. Authentication remains deferred; Preview/Publishing, POS sync, Flutter, Combos, and Inventory remain untouched.

## Phase 3A Menu Publish Validation

`POST /api/v1/admin/menus/{menu}/validate` validates one editable Menu, while `POST /api/v1/admin/menu-management/validate` validates submitted Menu IDs or all active assignments for a requested active Branch and Sales Channel. Responses contain stable issue codes and `error`, `warning`, or `information` severity arrays, plus per-menu summaries. Only errors block future publishing.

The validator is entirely read-only: it does not write audit logs, Menu records, Products, availability rows, publications, or versions. It reuses the existing price, scheduled-availability, and operational-availability resolvers in the Branch timezone. Catalog and modifier integrity failures are errors; intentionally contextual concerns such as base-price fallback, outside schedule, operational sold-out state, missing presentation metadata, empty Sections, and legacy size-like modifier groups are warnings. Preview is implemented and publishing remains unimplemented; authentication remains deferred.

## Phase 3C.1 Publishing and Immutable Snapshots

`POST /api/v1/admin/menu-management/publish` validates and publishes active assigned Menus for one tenant Branch and Sales Channel. `GET /api/v1/admin/menu-management/current-version?branchId=&channel=` returns only current Version metadata. A failed validation is recorded as a failed Publication; warnings can publish. A PostgreSQL advisory transaction lock and database constraint protect sequential Version numbers and a single current Version. Canonical static snapshots are SHA-256 checked: identical content records a no-change Publication, while changed content creates the next Version and supersedes the prior one.

Snapshots contain static localized composition, active visible records, schedules, effective scoped prices, modifiers, and ordering. Runtime Operational Availability, sold-out/temporary state, remaining quantity, availability/sellability results, preview data, and validation diagnostics are excluded. Authentication remains deferred. Version History, Rollback, POS snapshot consumption/sync, Flutter, Combos, and Inventory remain untouched.

## Phase 3C.2 Version History, Comparison, and Rollback

Admin Version APIs list and inspect tenant-scoped history, compare two Versions in the same Branch/Channel scope, and roll back to a historical Version by creating a new immutable Version. Historical checksums are indexed but no longer unique: rollback intentionally reuses the target payload/checksum. The prior current Version becomes `rolled_back`; historical records are never reactivated. Rollback uses the publishing advisory lock, records a new Publication, and returns a no-change result when the target already matches the current checksum. POS sync and authentication remain deferred.

## Phase 3B Resolved Menu Preview

`POST /api/v1/admin/menus/{menu}/preview` and `POST /api/v1/admin/menu-management/preview` are Admin-only, read-only diagnostics for a tenant-owned active Branch and `SalesChannel`. The collection route resolves explicit `menuIds`, or all actively assigned Menus when IDs are omitted. `at` defaults in the Branch timezone; `language` supports `default`, `ar`, and `en`; unavailable records are included by default and hidden placements are excluded by default. Tenant route isolation returns 404 and foreign submitted IDs return 422. Authentication remains deferred.

The non-persisted response contains context, validation, and resolved Menu/Section/Placement/Product/Variant/Modifier data. It reuses effective-price, scheduled product availability, and operational availability resolution. Menu schedules apply Branch + Channel, Branch, Channel, then Global scope, with priority, weekly/date constraints, and overnight periods. A Variant is sellable when active, scheduled available, operationally available, and validly priced; a Product also needs a visible placement. Placement overrides take precedence over localized Product text; other entities use requested/default/fallback localization. Modifier pivot overrides are applied, archived groups/options are excluded, and active unavailable Options preserve `isAvailable`.

Preview creates no publications, versions, snapshots, audit logs, or operational rows and updates no timestamps. Validation remains present after filtering. Publishing and snapshots are not started (Phase 3C); POS does not consume Preview, and POS sync, Flutter, Authentication, Combos, and Inventory remain untouched.
