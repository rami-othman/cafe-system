# Future Full Menu Management Architecture

The former Flutter Menu Management prototype was intentionally removed. It modeled the wrong workflow and did not represent the approved domain. The new Menu Management feature is **not implemented** in this repository yet.

## Approved future flow

```text
Central Catalog
→ Items + Variants + Modifiers
→ Menu Composition
→ Locations / Channels
→ Availability Rules
→ Draft Validation
→ Preview
→ Publish
→ Immutable Published Menu Snapshot
→ POS Sync and Local Cache
→ Operational Sold Out Overlay
```

The current Laravel `GET /api/v1/menu/categories`, `GET /api/v1/menu/products`, and `GET /api/v1/menu/products/{product}` endpoints are temporary POS Catalog APIs. The existing Product, Category, and Modifier schema remains in use and must not be removed until the replacement menu domain is implemented and safely migrated.

Authentication is intentionally deferred: `X-Tenant-Id` and the development first-tenant fallback remain temporarily. Tenant-scoped validation is implemented independently of authentication.

Tax is currently tenant-level (`tenants.tax_rate`). `orders.tax_rate` is an immutable tax snapshot for financial history; it is not a menu tax category or product-specific rule.
