# Cafe System 618 Backend

Laravel backend for the Cafe System 618 Windows client. The current Menu
Management reference is [Menu Management Architecture](../docs/MENU_MANAGEMENT_ARCHITECTURE.md)
and the current project baseline is
[PROJECT_STATUS](../windows_application/PROJECT_STATUS.md).

Menu Management includes catalog/variants, reusable Modifiers, recipes and
material adjustments, menus and schedules, validation/preview/publishing, immutable
versions, Price Overrides, and operational availability. Catalog and configured
Variant/Override prices are strictly positive; Modifier price adjustments are
signed; final POS unit prices below zero are rejected.

Recipe components configure consumption only. They do not perform inventory stock
deduction, reservations, or automatic availability. Batch 12 Published POS runtime
sync is complete: production POS uses `/pos/menu-sync`, a scoped Flutter cache,
and snapshot-aware orders. Offline menu and cart preparation are supported, but
true offline transaction or payment processing is not implemented. Authentication
is intentionally deferred; the approved next work is documented in
`windows_application/PROJECT_STATUS.md`.

Backend verification gate:

```sh
docker compose exec -T backend php artisan optimize:clear --env=testing
docker compose exec -T backend ./vendor/bin/pint
docker compose exec -T backend php artisan test
```

Do not treat old phase labels or historical test counts as current status.
