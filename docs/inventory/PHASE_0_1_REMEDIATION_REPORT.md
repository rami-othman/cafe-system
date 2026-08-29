# Phase 0–1 Inventory Remediation Report

**Date:** 2026-08-29  
**Scope completed:** Phase 0 (inventory API security/authorization) and Phase 1 (restore inventory testability).  
**Explicitly out of scope:** Flutter transfer UI, transfer-line editing, shortage accounting, transfer state/accounting redesign, demo transfers, transfer lifecycle idempotency/race handling, pagination, and typed Flutter statuses.

## Summary

The audit findings were verified before implementation:

1. `/api/v1/inventory/*` routes had no mandatory authentication middleware.
2. `TenantContext` accepted `X-Tenant-Id` and then fell back to the first tenant.
3. `FinancialActor` accepted `X-User-Id` when no authenticated actor was present.
4. Branch access returned successfully for a null actor.
5. Inventory Form Requests returned `true` from `authorize()`.
6. Transfer actions had status gates but no server-side ability check.
7. `InventoryCenterSeeder` called `StockCountService::upsertLine()` with three parameters where the service requires four.

The existing token architecture (`AuthenticateApiToken` and `api_tokens`) is now used as the mandatory boundary for inventory locations, all inventory endpoints, and finance endpoints which use `FinancialActor`. The tenant and actor are token-derived. Client-supplied tenant/user headers are ignored in runtime. A centralized inventory permission map now protects routes, and branch-restricted actors are filtered/denied server-side.

## Root causes fixed

| Root cause | Remediation |
|---|---|
| Public inventory route group | Added `api.token` to every `/v1/inventory/*` route and `/v1/warehouses` route. |
| Unsafe tenant fallback | `TenantContext` now requires the token-injected tenant context; `X-Tenant-Id` is accepted only in `testing` for unrelated legacy tests. There is no `Tenant::first()`/first-row fallback. |
| Actor impersonation/null actor | `FinancialActor` now accepts only the token-injected actor and rejects a missing actor with 401. |
| Token accepted inactive users | `AuthenticateApiToken` now requires `users.is_active = true`. |
| Ad-hoc role logic | Added the single `InventoryAccess` permission boundary and `inventory.permission` middleware. |
| Unrestricted branch reads | Warehouse, balances/dashboard, movement list/detail, transfer list/detail/action, count list/detail/action, item stock/movement, and bar-check/template paths now use centralized branch scope/assertions. |
| Broken seed invocation | Updated count seed call to pass `$manager`; also records each generated required count line before submitting the seeded count. |

## Authentication changes

- Added public `POST /api/v1/auth/login` using the existing `AuthController` token issuance flow.
- Added authenticated `GET /api/v1/auth/me` and `POST /api/v1/auth/logout`.
- Added `api.token` to inventory, warehouse/location, and finance groups. Finance was included because its mutation services use the same `FinancialActor`; otherwise actor attribution would remain impossible.
- Every inventory route now rejects a missing/invalid/expired token with HTTP 401 before a controller executes.
- Token middleware verifies that the token’s user is active and not soft deleted.

## Tenant isolation changes

`TenantContext::id()` now returns only the request attribute set by `AuthenticateApiToken` in runtime. It aborts with 401 when no authenticated tenant is available. It no longer reads `X-Tenant-Id` or selects a database tenant in non-test environments.

The legacy header is retained only under `APP_ENV=testing` so unrelated pre-existing feature tests can still express test tenant context. Inventory tests were converted to real Bearer token fixtures and do not rely on that exception. A real token always wins over a fake header.

## Actor resolution changes

`FinancialActor::id()` now obtains the actor exclusively from `auth_user`, which `AuthenticateApiToken` derives from the bearer token. `X-User-Id` has no production effect. Missing actor is a 401, not a successful/null mutation.

The existing role restriction on financial/inventory mutation actors (`owner`, `manager`) remains in place. Inventory route permission middleware runs before controller mutation code and makes action-specific checks explicit.

## Branch authorization changes

- Owner is tenant-wide.
- Manager and cashier reads are restricted to assigned branches plus branch-less central warehouses. A user with no branch assignment sees no branch warehouse.
- Mutations continue through service-level `FinancialActor::assertBranchAccess`; with null actors removed, the prior bypass is closed.
- Transfer listings require both source and destination warehouse branches to be accessible. Show, update, action, and receive additionally assert both branches before calling the transfer service.
- Counts, bar checks/templates, stock movement reads, warehouse lists, item stock/movement reads, balances, and dashboard warehouse/movement queries apply centralized branch filtering or explicit access checks. Branch users receive branch-scoped catalog totals; tenant-wide item detail aggregates are withheld from the generic item-detail endpoint and remain available through the filtered stock/movement endpoints.

## Inventory permission matrix

The project currently seeds only tenant roles `owner`, `manager`, and `cashier`. There is no pre-existing tenant permission-table architecture (the existing permission tables are for platform/super-admin users), so the following map is intentionally centralized in `App\Support\InventoryAccess` rather than scattered in controllers.

| Role | View | Create | Submit | Approve | Dispatch | Receive | Cancel | Count | Adjust |
|---|---|---|---|---|---|---|---|---|---|
| Owner | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes: create/post | Yes |
| Manager | Yes, assigned branches/central | Yes | Yes | Yes | Yes | Yes | Yes | Yes: create/post, assigned branches/central | Yes |
| Cashier | Yes, assigned branches/central | No | No | No | No | No | No | View only | No |

### Abilities enforced

- `inventory.view`
- `inventory.items.manage`
- `inventory.locations.manage`
- `inventory.transfers.view`
- `inventory.transfers.create`
- `inventory.transfers.edit`
- `inventory.transfers.submit`
- `inventory.transfers.approve` (also reject)
- `inventory.transfers.dispatch`
- `inventory.transfers.receive` (also close-shortage)
- `inventory.transfers.cancel`
- `inventory.counts.view`
- `inventory.counts.create`
- `inventory.counts.post` (review/approve/post)
- `inventory.adjustments.create`

This mapping is route-enforced. It does not depend on Flutter button visibility.

## Seeder fix

**Old failing call**

```php
$counts->upsertLine($tenant, $id, $lineData);
```

**Current service contract**

```php
StockCountService::upsertLine(int $tenantId, int $countId, array $data, ?int $actorId): void
```

**Corrected seed behaviour**

`InventoryCenterSeeder` now passes the seeded manager as the fourth argument. It iterates all automatically generated required count lines, marking each one counted before submitting/approving/posting the count. This preserves the service contract rather than weakening it to accommodate stale seeder code.

## Tests added

Added `backend/tests/Feature/InventorySecurityAndSeederTest.php` with HTTP-level security coverage:

1. Required inventory seeders complete and create tenant, branches, warehouses, items, balances, and count objects.
2. Unauthenticated inventory transfer/balance/movement list and transfer creation are rejected.
3. A token-authenticated tenant can read its own inventory; fake `X-Tenant-Id` cannot alter that tenant scope.
4. Fake `X-User-Id` cannot turn a cashier token into an owner.
5. Tenant A cannot view or mutate a Tenant B transfer ID.
6. Tenant A cannot post Tenant B’s item or warehouse.
7. An unassigned branch-limited manager cannot list branch locations or create a branch transfer.
8. A cashier lacks approve/dispatch/receive abilities while an owner can create a permitted transfer.

The existing InventoryCenter and Foundation tests were converted from unauthenticated `X-Tenant-Id` fixtures to real bearer-token fixtures. The exceptional test header remains only for non-inventory legacy paths under `APP_ENV=testing`.

## Existing tests results

All commands use the Docker PHPUnit configuration, which specifies `APP_ENV=testing`, SQLite, and `:memory:`. No real/development database migration or destructive command was run.

| Command | Passed | Failed | Assertions | Result |
|---|---:|---:|---:|---|
| `docker compose exec -T backend php artisan test --filter=InventorySecurityAndSeederTest` | 6 | 0 | 24 | PASS |
| `docker compose exec -T backend php artisan test --filter=FinancialInventoryFoundationApiTest` | 5 | 0 | 43 | PASS |
| `docker compose exec -T backend php artisan test --filter=InventoryCenterApiTest` | 15 | 8 | 230 | PARTIAL — executes assertions; no Seeder crash/zero-assertion failure remains. |
| `docker compose exec -T backend php artisan route:list --path=api/v1/inventory` | n/a | 0 | n/a | PASS — 44 inventory routes registered. |
| Docker `php -l` for changed routes, middleware, support, and controller files | n/a | 0 | n/a | PASS |

### Remaining existing test failures (not hidden)

The eight `InventoryCenterApiTest` failures are exposed now that the default seed succeeds. They are not fixes made in this phase:

1. Several count tests assume only one/two count lines, while the now-working default seed creates a complete inventory catalog/count scope.
2. One test creates a `cycle` count without required `categoryFilters`; current service correctly rejects it with 422.
3. Item cost serialization expectation (`'2.2500'`) differs from current conversion/cost result (`0.0002`).
4. Conversion factor assertion expects formatted string `'12.000000'` but current API returns numeric `12`.
5. Reconciliation test expects exactly two scopes despite the working seed producing 29 scopes.
6. Bar-check/count tests depend on isolated count fixtures but inherit the working seeded inventory scope.

These need an intentional later test-fixture/contract decision; they are not authentication bypasses and were not changed to force a green result.

## Security verification matrix

| Scenario | Expected | Actual | Result |
|---|---|---|---|
| Unauthenticated GET transfers | 401 | 401 in HTTP feature test | PASS |
| Unauthenticated GET balances/movements | 401 | 401 in HTTP feature test | PASS |
| Unauthenticated POST transfer | 401 | 401 in HTTP feature test | PASS |
| Authenticated Tenant A inventory list | Own tenant data only | API returns Tenant A scope | PASS |
| Tenant A reads Tenant B transfer by numeric ID | 404/403 without leak | 404 | PASS |
| Tenant A mutates Tenant B transfer | 404/403 without leak | 404 | PASS |
| Tenant A uses Tenant B item | reject | 422 | PASS |
| Tenant A uses Tenant B warehouse | reject | 422 | PASS |
| Fake `X-Tenant-Id` with Tenant A token | no tenant switch | remains Tenant A | PASS |
| Fake `X-User-Id` with cashier token | no impersonation | cashier remains forbidden | PASS |
| Missing actor inventory mutation | 401 | blocked by `api.token` before mutation | PASS |
| Branch-limited manager accesses other branch | reject/filter | restricted central-only list; transfer create 403 | PASS |
| Cashier approves | 403 | 403 | PASS |
| Cashier dispatches | 403 | 403 | PASS |
| Cashier receives | 403 | 403 | PASS |
| Owner creates permitted transfer | 201 | 201 | PASS |
| Seed inventory foundation | completes | 6-test smoke suite completes | PASS |

## Files changed

| File | Why |
|---|---|
| `backend/routes/api.php` | Applied token and granular inventory-permission middleware; registered existing auth endpoints; replaced generic action paths with explicit action defaults. |
| `backend/bootstrap/app.php` | Registered `inventory.permission` middleware alias. |
| `backend/app/Http/Middleware/EnsureInventoryPermission.php` | New route middleware that delegates to centralized authorization. |
| `backend/app/Support/InventoryAccess.php` | New single role/ability map plus reusable branch scope/access helpers. |
| `backend/app/Http/Middleware/AuthenticateApiToken.php` | Rejects inactive token users. |
| `backend/app/Support/TenantContext.php` | Removes runtime header/first-tenant selection. |
| `backend/app/Support/FinancialActor.php` | Removes user-header impersonation/null actor bypass. |
| `backend/app/Http/Controllers/Api/{Warehouse,InventoryBalance,InventoryItem,StockMovement,StockCount,BarCheck,WarehouseTransfer}Controller.php` | Adds centralized branch scoping/assertions for inventory reads and ID-based operations. |
| `backend/database/seeders/InventoryCenterSeeder.php` | Aligns with the current count-line actor contract and completes required seeded count lines. |
| `backend/tests/Feature/InventorySecurityAndSeederTest.php` | New security matrix and seed smoke regression test. |
| `backend/tests/Feature/{InventoryCenterApiTest,FinancialInventoryFoundationApiTest}.php` | Replaces unsafe tenant-header-only fixtures with bearer-token fixtures. |

## Remaining audit issues

The following remain deliberately unresolved for later phases:

- Flutter transfer line workflow
- shortage ledger accounting
- cancellation audit metadata
- lifecycle idempotency
- receipt race handling
- typed transfer statuses
- server filtering/pagination
- realistic transfer demo seeders

Also unresolved: the eight pre-existing/now-exposed InventoryCenter test fixture/API-contract failures listed above. They must be triaged without relaxing inventory controls.

## Final verdict

1. **Is inventory API authentication now enforced?** Yes, all inventory and warehouse/location routes require a valid bearer token.
2. **Is tenant identity server-derived?** Yes, in runtime it comes from the authenticated token only.
3. **Can `X-Tenant-Id` still impersonate another tenant?** No in runtime. It is ignored when a token is present and unavailable outside `testing` fallback paths.
4. **Can `X-User-Id` impersonate another actor?** No. It is ignored; actor comes from the token.
5. **Is branch access enforced?** Yes for the remediated inventory location/balance/movement/transfer/count/bar-check paths, with service-level mutation checks retained.
6. **Are transfer permissions enforced?** Yes, create/view/edit/submit/approve/reject/dispatch/receive/close-shortage/cancel are independently route-authorized.
7. **Does the Seeder now succeed?** Yes in isolated automated seed smoke testing.
8. **Do inventory tests actually execute assertions?** Yes. The prior 0-assertion Seeder crash is removed; the main suite executed 230 assertions.
9. **Are there any P0 security issues remaining?** No known P0 from the Phase 0 audit remains in the remediated inventory API boundary. The still-failing inventory tests and later accounting/UI work are not P0 authentication/tenant isolation bypasses.
