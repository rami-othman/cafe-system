# Cafe System 618 Laravel Backend

This Laravel application supplies API controllers and business logic for the Flutter Windows application, including the POS catalog, orders, discounts, reports, payments, and refunds.

Run it through Docker from the repository root:

```bash
docker compose exec backend php artisan migrate
docker compose exec backend php artisan test
```

Tenant API authentication is deliberately not enabled yet. The current `TenantContext` keeps `X-Tenant-Id` support and its first-tenant development fallback. Tenant-owned submitted references are still validated against that resolved tenant.

Tax is configured once per tenant in `tenants.tax_rate`. New orders snapshot that value in `orders.tax_rate`, and all subsequent order recalculation uses the snapshot. The existing `/api/v1/menu/categories`, `/api/v1/menu/products`, and `/api/v1/menu/products/{product}` APIs remain the temporary POS Catalog API.
