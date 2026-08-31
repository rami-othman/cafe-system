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

## Pre-Auth Hardening D

Publishing serializes only its exact tenant + Branch + channel scope. It acquires
that scoped advisory lock before beginning a repeatable-read publication
transaction, then resolves candidates, runs blocking validation, builds the
snapshot, checks its checksum, updates version history, and records audit state.
Validation and the published payload therefore share one authoritative database
snapshot. A validation failure creates no Version; a matching checksum remains a
no-change publication. Historical rollback still copies the stored historical
payload into a new Version rather than rebuilding it from live tables.

The API client maps network, 401, 403, 409, 422, 5xx, and unknown failures to
typed error categories. Domain validation and stable domain codes remain
available; connection and unexpected-server details are not primary UI text.
This is preparation for tenant employee authentication only. Platform Super
Admin authentication/permissions remain a separate existing security domain.

## Discount runtime policy (Pre-Auth Hardening C)

`DiscountEligibilityService` is the single server authority for managed
discounts. It evaluates persisted Order, Branch, Customer, published-menu, and
Discount data; the client supplies neither a discount amount nor eligibility
facts. The configuration-to-runtime matrix is:

| Configuration | Runtime policy |
| --- | --- |
| `is_active`, `starts_at`, `ends_at` | Enforced. Timestamp boundaries are inclusive. |
| `active_days`, `start_time`, `end_time` | Enforced in the Order Branch timezone; an end before its start is an inclusive overnight window. |
| branch targets | Enforced against `orders.branch_id`; no targets means global to the tenant. |
| `scope` + product/category targets | Enforced against Order lines. `order` uses the whole pre-discount subtotal; targeted scopes use only matching lines. |
| application mode | `code` requires a code; `auto`/`manual` require selection by tenant-scoped ID. It does not auto-select a best discount. |
| percentage/fixed/BOGO, maximum and minimum | Calculated on the authoritative eligible subtotal; fixed amounts cannot exceed it; percentage is limited to 0–100 at management write time; maximum caps the result. Minimum remains the existing pre-discount whole-order subtotal rule. |
| customer eligibility | The supported Admin values are All Customers, Regular, VIP, and New Customers; identified Order customer is required where applicable. |
| payment method | Deferred at Apply because tender is unknown, then strictly revalidated at Payment. A mismatch blocks payment; it does not silently remove the discount. |
| usage limits | Consumed only on successful payment in the same transaction. `discount_usages` is the completed-sale audit history; the locked Discount row serializes global and per-customer limit checks and idempotent payment retries cannot double consume. |
| conditions/display period/estimated saved value | UI/description metadata only. There is no stacking/combinability field in the persisted domain, and one `order_discounts` row is retained per Order. |

For versioned Orders, `order_items.category_id` is an immutable selling
identity copied from the published payload (and backfilled from existing
payloads by the migration). Category targeting never reads the live Catalog for
those Orders. Legacy no-version Orders retain the documented live-category
fallback. Order discount rows retain their configured type/value and the actual
applied amount; paid totals are never recalculated after settlement. Tax remains
calculated after the order discount, matching the existing pricing policy.

All active Flutter discount/POS currency displays use the shared formatter; the
backend available-discount fixed badge emits `SYP`, not `$`.

Backend verification gate:

```sh
docker compose exec -T backend php artisan optimize:clear --env=testing
docker compose exec -T backend ./vendor/bin/pint
docker compose exec -T backend php artisan test
```

Do not treat old phase labels or historical test counts as current status.
