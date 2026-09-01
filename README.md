# Cafe System 618

Cafe System 618 contains a Laravel API in `backend/` and a Flutter Windows desktop application in `windows_application/`. The active product surface includes POS, orders, discounts, reports, payments, and refunds.

## Current architecture

- Laravel provides tenant-aware APIs and POS pricing/business logic.
- Flutter uses Dio, Cubit, go_router, and get_it for the Windows desktop client.
- Production POS reads only `GET /api/v1/pos/menu-sync` Published Runtime Contract v1 and submits snapshot-aware orders with `publishedMenuVersionId`.
- `GET /api/v1/menu/categories`, `GET /api/v1/menu/products`, and `GET /api/v1/menu/products/{product}` are deprecated compatibility Catalog APIs. Production POS does not call them.
- Tax configuration is tenant-level (`tenants.tax_rate`); each order persists an immutable `orders.tax_rate` snapshot.

Auth Phase 1 supplies a separate tenant-user opaque Bearer-token foundation.
Existing operational routes retain their temporary `X-Tenant-Id`/first-tenant
fallback until the Flutter login cutover, while new `/api/v1/auth/*` protected
routes always derive Tenant context from the authenticated token. See the
backend README for the identity, lifecycle, offline-session, and branch-access
contract. Platform Super Admin authentication and RBAC remain separate.

Auth Phase 2 is closed: Tenant Employee Management adds per-tenant default
Owner/Manager/Employee role identities, protected employee lifecycle and
credential APIs, temporary passwords, must-change-password gating, transactional
Branch assignments, and token revocation. Tenant roles are separate from
Platform Super Admin RBAC; the final Permission Catalog, custom role management,
Flutter Auth, and the full operational authorization cutover remain deferred.

See [backend/README.md](backend/README.md), [windows_application/README.md](windows_application/README.md), and [Menu Management Architecture](docs/MENU_MANAGEMENT_ARCHITECTURE.md).

## Local development

```powershell
docker compose up -d --build
docker compose exec backend composer install
docker compose exec backend php artisan migrate --seed
cd windows_application
flutter pub get
flutter run -d windows
```
