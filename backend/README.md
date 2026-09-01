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

## Auth Phase 1 — tenant identity and opaque sessions

**Status: CLOSED.** On the exact closure worktree, the manually run full backend
suite (`docker compose exec -T backend php artisan test`) passed: 160 tests,
2,054 assertions, 0 failures, in 67.15 seconds. Focused Auth tests, Platform
Super Admin regression, testing-database migration/seed verification, Pint, and
`git diff --check` also passed.

Tenant-user authentication is a separate security domain from Platform Super
Admin session authentication and RBAC. One tenant User belongs to one Tenant:
Owners and Managers sign in with email/password, while Employees (including the
current `cashier` role) sign in with tenant-scoped, case-insensitive usernames.
The present deployment has one operational cafe, so username sign-in is only
unambiguous there; future multi-cafe login must add a Cafe Code/Tenant bootstrap
step rather than make usernames globally unique.

`POST /api/v1/auth/login` issues a cryptographically random opaque Bearer token.
Only its SHA-256 hash is persisted in `api_tokens`; raw tokens are returned once.
Sessions expire after `TENANT_TOKEN_TTL_DAYS` (30 days by default), may coexist
across devices, and `POST /api/v1/auth/logout` revokes only the current one.
`GET /api/v1/auth/me`, `POST /api/v1/auth/change-password`, and logout are the
currently protected tenant routes. Existing operational routes retain their
temporary `X-Tenant-Id`/first-tenant compatibility fallback until the Flutter
authentication cutover; that fallback is never usable on the protected boundary.

New Tenant accounts start active with `must_change_password=true`. Their issued
session may read identity, change the password, or log out; the reusable
`password.changed` middleware blocks any future normal protected action until
the change succeeds. The current token intentionally remains valid after this
initial change. Owner/Manager new passwords require 10 characters; Employee
passwords require 8. No composition rule is imposed.

Active, deactivated, and archived user lifecycle semantics are represented by
`is_active` and soft deletion. Lifecycle services revoke every active opaque
token on deactivation or archive, and deliberately protect the Tenant Owner from
generic lifecycle changes. Authenticated requests always re-check current user
and Tenant state; suspended, cancelled, and archived Tenants are not
operational. `past_due` is temporarily allowed pending a billing policy. A
re-activated Tenant may use an unexpired, unrevoked session again; user
deactivation revokes sessions permanently.

The session DTO includes the Phase 0 future offline contract
`offlineSessionMaxAgeSeconds: 43200`. It is not a Bearer-token TTL: a fully
offline client can only trust cached authorization for 12 hours after its last
online validation, so deactivation cannot be observed before reconnect or that
limit. Authentication never opens or closes a Work Shift. Permission catalog
and full route authorization remain deferred. `BranchAccessService` centralizes
the already-approved owner `allBranches` capability; other tenant users need a
tenant-safe `user_branches` assignment.

## Auth Phase 2 â€” Tenant Employee Management

**Status: CLOSED.** Tenant employment roles are separate from Platform Super
Admin RBAC. `tenant_roles` contains the idempotent system `owner`, `manager`,
and `employee` identities for each Tenant; it has no permission relation.
`users.tenant_role_id` is authoritative. The older `users.role` column remains
a deterministic compatibility projection (`cashier` maps to Employee) and is no
longer writable through the legacy Platform management endpoint.

`GET /api/v1/roles` exposes only the safe role catalog. `/api/v1/employees`
supports tenant-safe list/search/status/role/branch filters, detail, create and
update, activation, deactivation, archival, and password reset. It requires the
opaque-token boundary, Tenant context, the password-change gate, and the
temporary `employees.manage` policy: Owners and Managers may manage non-owner
users; Employees may not. Managers can create and manage Managers and Employees.

Every active non-owner has one active assignable Tenant Role and at least one
active Branch assignment. Create and Branch replacement are transactional and
reject foreign or inactive Branches. Role/identifier changes, password reset,
deactivation, and archive revoke all target sessions; reactivation never restores
old tokens. New Manager/Employee credentials are hashed temporary passwords with
`must_change_password=true` (minimum 10 and 8 characters respectively).

The Phase 2 closure run passed `migrate:fresh --seed` on
`cafe_system_618_testing` and the full Laravel suite: **164 tests, 2,099
assertions, 0 failures**. Final Permissions, custom role management, Flutter
Auth, actor attribution, and the operational authorization cutover remain
deferred.
