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
