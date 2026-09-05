# Cafe System 618 Backend

Laravel backend for the Cafe System 618 Windows client. The current Menu
Management reference is [Menu Management Architecture](../docs/MENU_MANAGEMENT_ARCHITECTURE.md)
and the current project baseline is
[PROJECT_STATUS](../windows_application/PROJECT_STATUS.md).

## Deployment Phase 1B — Supabase staging contract

Local development remains unchanged: `backend/.env` points at local PostgreSQL
and uses `PRODUCT_IMAGE_DISK=product-images-local`. For explicit Supabase
staging verification, copy `.env.staging.example` to the Git-ignored
`.env.staging`, populate it locally, and run Artisan with `--env=staging`.
Never put a staging URL, password, S3 secret, or `APP_KEY` in Git.

The only approved database target is the Supabase **Session Pooler** at
`aws-0-eu-central-1.pooler.supabase.com:5432`, database `postgres`, user
`postgres.uowuallmnboeqhsydzlk`, with `sslmode=require`. Do not use port 6543,
the Supabase Data API, Supabase Auth, a custom PostgreSQL schema, or RLS for
application tables. Verify the non-secret target identity before any command.

```powershell
# From backend/ after creating ignored .env.staging
php artisan migrate:status --env=staging
php artisan migrate --force --env=staging
php artisan migrate:status --env=staging
```

Never run `migrate:fresh`, `db:wipe`, or `DatabaseSeeder` against staging.
The explicit, small, idempotent initializer creates the Cafe System 618 staging
tenant, Owner/Manager/Cashier (with temporary credentials from the ignored env
file and `must_change_password=true`), Downtown branch, three products, and one
current POS publication. It refuses any non-staging, non-PostgreSQL, or
non-approved-Pooler target.

```powershell
php artisan staging:initialize --env=staging --confirm-staging
```

Product uploads stay multipart (`image`, with optional `productId`) and are
handled by `ProductImageStorage`. Local uploads retain the legacy public API URL
and local disk. Staging uses the public `product-images` Supabase Storage bucket
with server-only S3 credentials and paths
`tenants/{tenantId}/products/{uuid}.{extension}`. The public URL must be HTTPS.
When `productId` is supplied, the service uploads first, updates the product in a
database transaction, then best-effort removes only the old managed object; an
archived product keeps its image. No Flutter client receives write credentials.

Create the Storage bucket once in Supabase Dashboard: **Storage → New bucket →
Name `product-images` → Public bucket enabled → Create bucket**. Then go to
**Storage → Configuration → S3**, enable the S3 protocol and create a
server-only access key. Copy its key ID/secret, region, and direct
`https://<project-ref>.storage.supabase.co/storage/v1/s3` endpoint into ignored
`.env.staging` (or later Render secrets). Do not use the browser anon key for
server writes.

## Deployment Phase 1A — local cloud-image readiness

**Status: CLOSED LOCALLY.** The root Dockerfile has two targets: `development`
continues to support `docker compose up` with the existing source and named
`vendor` bind mounts, while `cloud` is a self-contained staging image. The
cloud target copies the Laravel application and lockfile-resolved production
Composer dependencies into the image; it never uses a host mount or host
`vendor` directory.

Build the cloud image from the repository root:

```powershell
docker build --target cloud -t cafe-system-618-backend:phase-1a .
```

At runtime its entrypoint requires a stable, externally supplied `APP_KEY`,
clears and rebuilds only Laravel's configuration/view caches (without touching
the configured application cache store), optionally runs only `php artisan migrate
--force`, then runs `php artisan serve --host=0.0.0.0 --port=$PORT`. `PORT`
defaults to `8000` for local smoke tests but Render supplies it dynamically.
Set `RUN_MIGRATIONS=true` only for the current single-instance staging service.
It must remain `false` for normal local containers and future multi-instance
production, where migrations belong in a dedicated release/pre-deploy step.
The entrypoint never runs `migrate:fresh` or `db:wipe`.

The Render environment contract is: `APP_ENV=staging`, `APP_DEBUG=false`, a
stable `APP_KEY`, `APP_URL`, `LOG_CHANNEL=stderr`, `PORT`, `DB_CONNECTION=pgsql`,
either `DB_URL` or the individual PostgreSQL values, `DB_SSLMODE=require`,
`TRUSTED_PROXIES=*`, `CORS_ALLOWED_ORIGINS`, and `RUN_MIGRATIONS`. Do not commit
these values. The staging entrypoint refuses absent cloud DB configuration
instead of falling back to SQLite. `APP_DEBUG=false` prevents stack traces in
normal error responses.

The cloud image defaults `CACHE_STORE=file`, `SESSION_DRIVER=file`, and
`QUEUE_CONNECTION=sync` for its ephemeral, single-service staging runtime; they
may be overridden only when the corresponding shared infrastructure exists.

Render terminates HTTPS upstream. `TRUSTED_PROXIES=*` is appropriate only for
the Render service because its container is reachable through the Render proxy;
leave it unset locally. This allows forwarded HTTPS/host information to drive
redirect and public-disk URL generation. `APP_URL` remains the source of truth
for configured URLs.

CORS is environment-driven through the comma-separated `CORS_ALLOWED_ORIGINS`.
It supports `Authorization`, `Content-Type`, and `Accept` preflight requests
without using a credentialed wildcard. If not supplied, local Super Admin
development retains `SUPER_ADMIN_WEB_URL` / `http://localhost:3000` behavior.

No queue worker or scheduler service is needed: the configured queue driver is
`sync` and `routes/console.php` defines no scheduled work. Logs can be sent to
stderr. `storage/` and `bootstrap/cache/` are writable framework scratch space,
but Render's filesystem is ephemeral. Product-image uploads remain local-disk
compatibility behavior and must not be manager-tested in cloud staging until
Phase 1B moves them to Supabase Storage. This phase does not connect Supabase
or deploy Render.

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

## Branch lifecycle and Cafe Configuration

`GET /api/v1/branches` is an operational selector: it returns only active,
non-deleted branches the authenticated actor can use. Owners retain implicit
all-branch access only for active branches; Manager and Employee assignments
also require an active branch. Deactivation preserves historical references and
existing `user_branches` rows, but those rows no longer grant operational use.

Owner-only branch administration is intentionally separate at
`/api/v1/cafe-configuration/branches`. Its list returns all non-deleted
same-tenant branches, including inactive branches, and supports only list,
create, detail, and update of branch contact/location fields. Currency is
server-controlled as `SYP`; lifecycle mutations are not exposed there.

## Cafe Profile and Tax Configuration

The Owner-only Cafe Configuration boundary also exposes the authenticated
tenant singleton resources below. All four routes require the opaque-token
session, a completed initial password change, and the `cafe.configuration`
Owner policy. A request never supplies a Tenant ID.

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/cafe-configuration/profile` | Read the Cafe Profile. |
| `PUT` | `/api/v1/cafe-configuration/profile` | Update only `name`, `email`, `phone`, and `timezone`. |
| `GET` | `/api/v1/cafe-configuration/tax` | Read the tenant-wide tax rate. |
| `PUT` | `/api/v1/cafe-configuration/tax` | Update only the tenant-wide tax rate. |

Profile reads include `name`, `email`, `phone`, `timezone`, read-only `currency`
(`SYP`), and read-only `status`. They never expose or mutate `slug`, `plan`,
`logo_url`, deletion metadata, or platform subscription data. Updating the Cafe
contact email updates only `tenants.email`; it never changes any User login
identity.

Tax is a JSON numeric fraction stored in `tenants.tax_rate` as `decimal(8,6)`:
the UI's **8%** is API input/output `0.08`. Valid values are `0` through `1`,
with at most six decimal places; `8` is rejected rather than interpreted as
8%. Tax remains exclusive. Each Order saves its tax rate at creation, so a
later configuration change affects new Orders only and cannot recalculate an
existing Order's tax or total snapshot. Cafe Profile, Tax, Branch, and Team
operational audit trails remain intentionally deferred.

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
