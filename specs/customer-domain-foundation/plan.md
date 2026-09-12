# Implementation Plan: Phase 1 — Customer Domain Foundation

**Branch**: `customer-domain-foundation` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/customer-domain-foundation/spec.md`

## Summary

Build the authoritative Laravel Customer domain around the existing `customers` table without breaking `GET /api/v1/customers`, the Flutter POS mapper, nullable walk-in orders, live historical customer display, or tier-based discounts. The implementation will add tenant-scoped Eloquent models, aggregate services, Customer and Customer Group administration APIs, a limited employee quick-create/membership API, multi-phone storage with a safely repeatable legacy-phone backfill, tenant-sequence customer numbers, bounded administrative queries, explicit role/permission enforcement, lifecycle services, audit events, and a shared operational-eligibility rule used by both lookup and order mutations.

The existing operational lookup remains a small compatibility surface. New administration is placed under an explicit `/api/v1/admin/customer-management` boundary so pagination and lifecycle representations cannot change the existing POS response. Customer create/update, phone synchronization, group membership replacement, lifecycle changes, number allocation, and audit recording run inside database transactions. Order create/update lock and validate the selected customer inside their existing transactions so concurrent deactivation or archival cannot race an order attachment.

## Technical Context

**Language/Version**: PHP `^8.3` (Docker runtime PHP 8.4)

**Primary Dependencies**: Laravel `^13.8`, Eloquent ORM/query builder, Laravel validation and HTTP resources, `mbstring`, PostgreSQL `pg_trgm` extension for indexed partial search

**Storage**: PostgreSQL 16; existing `customers`, `orders`, `users`, `tenant_roles`, and `activity_logs` tables plus new Customer-domain tables and forward-only alterations

**Testing**: PHPUnit `^12.5.12` through Laravel's `php artisan test`, `RefreshDatabase`, real PostgreSQL test database

**Target Platform**: Linux-hosted Laravel JSON API in Docker/Render; existing Flutter Windows/Web POS clients consume the compatibility endpoint but no Flutter code is added in this phase

**Project Type**: Multi-tenant web service in a monorepo with Laravel backend and Flutter operational client

**Performance Goals**: Operational lookup p95 at or below 200 ms and administrative list/search p95 at or below 300 ms against a representative 100,000-customer tenant; no response may exceed its documented page/limit bound

**Constraints**: Preserve the existing `{data: [...]}` POS customer shape and 30-row operational cap; preserve nullable `orders.customer_id`; use authenticated tenant context only; no hard delete; no new phone uniqueness identity; no Flutter UI, loyalty, metrics, import, snapshot, or tier redesign; no unbounded collection reads

**Scale/Scope**: Design and index for at least 100,000 customers per tenant, multiple phones and groups per customer, and concurrent quick-create/order traffic; administrative page size defaults to 30 and caps at 100

## Constitution Check

*GATE: Passed before design. Re-check result after the design below: Passed; no justified violations remain.*

- **Tenant and authorization**: `customers`, `customer_phones`, `customer_groups`, memberships, number counters, and Customer permission rows carry `tenant_id`. Every query begins with `TenantContext::id($request)` and every relationship mutation verifies same-tenant parents. Admin routes require `api.token`, `password.changed`, and Customer admin middleware. Owners are implicit full administrators; managers require `customer.manage`; employees receive only operational lookup/select, quick-create, and membership mutation. Platform Super Admin routes and identities are untouched. Customers are tenant-wide, so no branch ownership is added; existing order branch authorization remains unchanged.
- **Domain authority and scope**: `CustomerService` owns profile, phone, group-membership, number, and lifecycle invariants. `CustomerOperationalEligibility` is the sole authority for operational lookup and new order attachment. Orders continues to own order mutability and the nullable `customer_id` relationship. Discounts continues to own New/Regular/VIP tier behavior using the preserved legacy metrics. Customer history, metrics, group-targeted discounts, loyalty, import, snapshots, and Flutter UI remain out of scope.
- **History and data safety**: Active/inactive uses `is_active`; archive uses the existing soft-delete column plus `is_active=false`; restore clears deletion and returns a customer inactive. Historical orders retain `customer_id` and continue resolving live customer data. Forward-only migration adds nullable columns/tables, backfills every existing row and phone without changing raw legacy values, initializes counters, then applies constraints. No legacy column is removed.
- **Exact semantics**: No new money, tax, quantity, conversion, or business-time calculation exists. `total_spent` and `visits_count` retain current meanings solely for compatibility. Aggregate writes and lifecycle changes are transactional. Customer number allocation uses a locked per-tenant counter; repeat lifecycle targets and backfill operations are idempotent. Phone/name normalization is deterministic and independent of server locale/timezone.
- **Contracts and scale**: The operational endpoint retains its exact envelope, required fields, sort, eligibility, search compatibility, and 30-row limit. Administration uses a separate paginated API with stable `meta`, server-side filters, deterministic tie-breaking, and a 100-row maximum. PostgreSQL B-tree and trigram indexes cover tenant, number, normalized name, email, and phone search paths. Backend validation returns stable domain codes for permission, eligibility, lifecycle, and concurrency failures.
- **UX and platforms**: Phase 1 has no UI. Raw Arabic/English names remain unchanged for display while normalized search supports both. Existing Flutter Windows/Web POS parsing remains valid because required keys and types are preserved. Phase 2 owns localized administrative UI, RTL/LTR, loading/error/empty states, and application-shell integration.
- **Verification and scope**: Add focused schema, service, API, permission, compatibility, concurrency, and order-integration tests. Re-run existing POS, order, and discount tests, then the full backend suite at the phase checkpoint. Run Pint only on changed PHP files, inspect the final diff for scope/secrets, and require `git diff --check`. Existing unrelated Spec Kit/template changes remain untouched.

## Project Structure

### Documentation (this feature)

```text
specs/customer-domain-foundation/
├── spec.md              # Approved Phase 1 requirements and clarifications
├── plan.md              # This implementation plan
└── tasks.md             # Created later by $speckit-tasks
```

This plan does not create `research.md`, `data-model.md`, `quickstart.md`, or `contracts/`; the selected lean Spec Kit skill requires the technical context, decisions, and file structure in `plan.md` itself.

### Source Code (repository root)

```text
backend/
├── app/
│   ├── Domain/Customer/
│   │   ├── CustomerAccess.php
│   │   ├── CustomerDomainException.php
│   │   ├── CustomerNameNormalizer.php
│   │   ├── CustomerPhoneNormalizer.php
│   │   ├── CustomerNumberGenerator.php
│   │   └── CustomerOperationalEligibility.php
│   ├── Http/
│   │   ├── Controllers/Api/
│   │   │   ├── CustomerController.php                    # preserve lookup; add quick-create/membership operations
│   │   │   ├── CustomerGroupLookupController.php         # active groups for membership-capable users
│   │   │   └── Admin/CustomerManagement/
│   │   │       ├── CustomerManagementController.php
│   │   │       ├── CustomerGroupController.php
│   │   │       └── CustomerRolePermissionController.php
│   │   ├── Middleware/
│   │   │   └── EnsureCustomerPermission.php
│   │   ├── Requests/Customer/
│   │   │   ├── ListCustomersRequest.php
│   │   │   ├── StoreCustomerRequest.php
│   │   │   ├── UpdateCustomerRequest.php
│   │   │   ├── QuickCreateCustomerRequest.php
│   │   │   ├── SyncCustomerGroupsRequest.php
│   │   │   └── CustomerGroupRequest.php
│   │   └── Resources/Customer/
│   │       ├── CustomerManagementResource.php
│   │       ├── CustomerGroupResource.php
│   │       └── OperationalCustomerResource.php
│   ├── Models/
│   │   ├── Customer.php
│   │   ├── CustomerPhone.php
│   │   └── CustomerGroup.php
│   └── Services/Customer/
│       ├── CustomerService.php
│       ├── CustomerGroupService.php
│       └── CustomerQueryService.php
├── bootstrap/app.php
├── database/
│   └── migrations/
│       ├── *_add_customer_domain_foundation.php
│       └── *_backfill_and_constrain_customer_foundation.php
├── routes/api.php
└── tests/
    ├── Unit/Customer/
    │   ├── CustomerNameNormalizerTest.php
    │   └── CustomerPhoneNormalizerTest.php
    └── Feature/Customer/
        ├── CustomerDomainSchemaTest.php
        ├── CustomerManagementApiTest.php
        ├── CustomerAuthorizationApiTest.php
        ├── CustomerPhoneCompatibilityTest.php
        ├── CustomerGroupApiTest.php
        ├── CustomerSearchPaginationTest.php
        ├── CustomerOperationalCompatibilityTest.php
        ├── CustomerOrderEligibilityTest.php
        └── CustomerNumberConcurrencyTest.php
```

**Structure Decision**: Keep all production work inside the existing Laravel backend. Use a small `App\Domain\Customer` layer for pure rules/access/eligibility and `App\Services\Customer` for transactional application services. Keep controllers responsible for HTTP validation and resource selection only. Continue using the existing `CustomerController` for the public operational contract so current route wiring and regression tests remain recognizable; isolate all new administrative representations under `Api\Admin\CustomerManagement`.

## Brownfield Evidence

- `backend/database/migrations/2026_05_31_000008_create_customers_table.php` already defines tenant ownership, one nullable `phone`, optional profile fields, legacy metrics, `is_active`, and soft deletion.
- `backend/app/Http/Controllers/Api/CustomerController.php` directly queries the table and establishes the current operational envelope, field names, tier calculation, name/phone search, name ordering, and 30-row limit.
- `backend/routes/api.php` places customer lookup and Orders inside the authenticated operational boundary; administrative domains use explicit `/admin` prefixes and middleware aliases.
- `backend/app/Http/Controllers/Api/PosOrderController.php` currently validates `customerId` with tenant existence only, so inactive rows are accepted and eligibility can race lifecycle changes.
- `windows_application/lib/features/pos/repositories/pos_repository.dart` consumes `id`, `name`, `phone`, `tier`, and `loyaltyPoints`, confirming the compatibility keys that cannot be renamed or made required in a new shape.
- `backend/app/Services/TenantEmployeeService.php`, `PosNumberGenerator.php`, and Customer-adjacent catalog services establish the repository patterns for tenant-scoped row locks, aggregate transactions, counter allocation, lifecycle actions, and fresh resources.
- `backend/app/Support/FinanceAccess.php` and `finance_role_permissions` demonstrate a bounded domain-specific permission catalog; Customer Management will mirror the pattern without importing Finance permissions or widening Platform Super Admin access.
- `backend/tests/TestCase.php` supplies real opaque tenant tokens to legacy tests, while new authorization tests can select explicit Owner, Manager, and Employee actors.

## Design Decisions

### 1. Route and Contract Separation

Preserve the current route exactly:

```text
GET /api/v1/customers
```

It remains inside the authenticated operational boundary and returns only eligible customers in the current `{data: [...]}` envelope. With no administrative parameters it remains ordered by name and capped at 30. Existing keys remain:

```text
id, name, phone, email, totalSpent, visitsCount,
loyaltyPoints, tier
```

New operational actions use the same authenticated tenant boundary:

```text
POST /api/v1/customers/quick-create
PUT  /api/v1/customers/{customer}/groups
GET  /api/v1/customer-groups
```

- Quick-create accepts exactly `name` and one `phone`, creates an Active customer, and makes that phone primary.
- Membership replacement accepts unique active same-tenant `groupIds`; an empty list removes all memberships.
- Active group lookup is paginated/bounded and exists so employees can select an existing group without gaining group administration.

Full administration uses a separate boundary:

```text
GET  /api/v1/admin/customer-management/customers
POST /api/v1/admin/customer-management/customers
GET  /api/v1/admin/customer-management/customers/{customer}
PUT  /api/v1/admin/customer-management/customers/{customer}
POST /api/v1/admin/customer-management/customers/{customer}/activate
POST /api/v1/admin/customer-management/customers/{customer}/deactivate
POST /api/v1/admin/customer-management/customers/{customer}/archive
POST /api/v1/admin/customer-management/customers/{customer}/restore

GET  /api/v1/admin/customer-management/customer-groups
POST /api/v1/admin/customer-management/customer-groups
GET  /api/v1/admin/customer-management/customer-groups/{group}
PUT  /api/v1/admin/customer-management/customer-groups/{group}
POST /api/v1/admin/customer-management/customer-groups/{group}/archive
POST /api/v1/admin/customer-management/customer-groups/{group}/restore

GET  /api/v1/admin/customer-management/role-permissions/manager
PUT  /api/v1/admin/customer-management/role-permissions/manager
```

The permission endpoints are owner-only and enable/disable the single Phase 1 manager permission, `customer.manage`. Owners are implicitly authorized and cannot be disabled. Managers without that row retain ordinary operational actions but receive 403 from every admin route. Employee capabilities are fixed by the clarified policy and are not promoted through this endpoint.

Administrative list response:

```json
{
  "data": [],
  "meta": {
    "currentPage": 1,
    "lastPage": 1,
    "perPage": 30,
    "total": 0
  }
}
```

Customer filters are `search`, `status=active|inactive|archived|all`, `groupId`, `page`, and `perPage`. No status means Active and Inactive (non-archived). Ordering is normalized name ascending, then customer ID ascending. Group lists use the same pagination metadata and default to non-archived groups.

### 2. Authorization Model

Add `customer_role_permissions` rather than expanding Finance-specific permissions or creating a repository-wide RBAC redesign:

```text
tenant_id, role, permission, timestamps
UNIQUE (tenant_id, role, permission)
```

Only `role=manager` and `permission=customer.manage` are valid in Phase 1. Existing tenants start with no manager grant (secure default); owners can grant it through the owner-only endpoint. `CustomerAccess` reloads the authenticated active tenant actor and exposes explicit assertions:

```text
assertCanAdminister
assertCanQuickCreate
assertCanManageMemberships
assertCanUseOperationalLookup
assertOwnerCanConfigureManagerPermission
```

Route middleware protects the admin surface, while services repeat capability checks for sensitive aggregate mutations so internal controller refactoring cannot bypass policy. Authorization failures return 403 with `CUSTOMER_PERMISSION_DENIED`. Cross-tenant resource reads return 404; cross-tenant submitted relationship IDs return 422 without foreign record details.

### 3. Customer Persistence Model

Extend `customers` without removing legacy fields:

```text
customer_number     varchar(32), tenant-unique, non-null after backfill
normalized_name     varchar(255), non-null after backfill
is_active           existing boolean
deleted_at          existing archive marker
phone               existing compatibility mirror
email               existing optional value
birth_date          existing optional value
notes               existing optional value
total_spent         existing compatibility metric
visits_count        existing compatibility metric
```

Create `customer_number_counters` with one lockable row per tenant. `CustomerNumberGenerator` uses `insertOrIgnore`, `lockForUpdate`, increments `next_value`, and formats `C-` plus a minimum six-digit decimal sequence. Numbers grow beyond six digits without truncation. Every existing customer, including archived rows, receives a deterministic sequence ordered by customer ID; counter high-water marks are initialized after backfill. A database unique constraint on `(tenant_id, customer_number)` is the final safety boundary.

`CustomerNameNormalizer` trims and collapses whitespace, lowercases with `mb_strtolower`, removes Arabic diacritics and tatweel, and maps Alef variants (`أ`, `إ`, `آ`, `ٱ`) to `ا`. It never changes the displayed `name`.

Add a database unique key on `(tenant_id, id)` to `customers` as the referenced parent key for tenant-safe composite foreign keys. The globally unique primary key remains unchanged.

### 4. Multi-Phone Authority and Compatibility

Create `customer_phones`:

```text
id, tenant_id, customer_id,
raw_number varchar(50),
normalized_number varchar(32) nullable,
type varchar(30) default 'mobile',
is_primary boolean,
validation_status varchar(20),
timestamps
```

Use a same-tenant composite foreign key from `(tenant_id, customer_id)` to customers, a unique constraint on `(customer_id, normalized_number)` (PostgreSQL permits multiple nulls), and a partial unique index on `customer_id WHERE is_primary = true`. These enforce tenant ownership, no duplicate normalized number within one customer, and at most one primary. `CustomerService` enforces at least one primary whenever phones exist.

Phone normalization is dependency-free and deterministic:

- trim and preserve `raw_number` unchanged apart from outer whitespace;
- translate Arabic-Indic and Eastern Arabic digits to ASCII;
- retain a leading `+` and digits for normalized search; remove common spaces, parentheses, periods, and hyphens;
- classify E.164-like `+` values with 8–15 digits as `valid`;
- classify plausible national digit strings with 7–15 digits and no country context as `unverified`;
- classify other non-blank in-limit values as `invalid`, with `normalized_number` null when no searchable digits can be derived.

The forward-only backfill creates one primary phone for each customer with non-null `customers.phone` and no phone row. It preserves the raw value, calculates normalization/status through the same normalizer, and is guarded by existence checks plus database constraints so a safe retry cannot duplicate rows. During rollout, operational reads fall back to `customers.phone` only when no primary phone row exists. After backfill, the phone collection is authoritative and every aggregate write mirrors the primary raw value to `customers.phone` in the same transaction.

### 5. Customer Groups and Memberships

Create `customer_groups` with tenant ownership, `name`, `normalized_name`, `is_active`, timestamps, and soft deletes. Group names are unique by `(tenant_id, normalized_name)` across active and archived rows, preventing an archive/restore collision. Restore makes a group active.

Add `(tenant_id, id)` as a unique parent key on `customer_groups` so memberships can enforce tenant consistency at the database boundary.

Create `customer_group_memberships` with `tenant_id`, `customer_id`, `customer_group_id`, and timestamps. Composite same-tenant foreign keys prevent cross-tenant joins, and `(tenant_id, customer_id, customer_group_id)` is unique. Customer or group hard deletion may cascade only as a database integrity fallback; no normal Customer API exposes hard deletion.

Membership synchronization locks the customer, validates the complete unique group set as active/non-archived and same-tenant, then replaces memberships within the customer aggregate transaction. Archived groups retain existing membership rows but cannot receive new assignments. Group membership has no effect on legacy tier or discount calculations.

### 6. Lifecycle and Concurrent Writes

Represent Customer states without adding a competing status column:

| State | `is_active` | `deleted_at` |
|---|---:|---|
| Active | true | null |
| Inactive | false | null |
| Archived | false | non-null |

Allowed transitions are Active→Inactive, Inactive→Active, Active/Inactive→Archived, and Archived→Inactive through restore. A repeated action already at its target is a successful no-op. Activating an archived customer or restoring a non-archived customer outside its no-op target returns `CUSTOMER_INVALID_TRANSITION` (422). Customer archive never deletes phones, memberships, or order references.

Group archive sets inactive plus soft deletion; restore sets active. Repeating archive or restore is idempotent.

Customer and group writes use row locks. Phase 1 deliberately uses serialized last-committed-write-wins behavior rather than adding a new optimistic-version contract; every response contains the fresh `updatedAt`, and later UI work must refresh after mutation. Database uniqueness errors are translated into stable validation errors rather than leaked as SQL exceptions.

### 7. Operational Eligibility and Orders Integration

`CustomerOperationalEligibility` owns one query scope and one locked assertion:

```text
tenant_id = authenticated tenant
AND is_active = true
AND deleted_at IS NULL
```

`CustomerController::index` applies this scope. `PosOrderController::store` and `update` stop using the current tenant-only `exists` rule for `customerId`. They validate nullable integer shape first, then inside their existing database transaction lock the selected customer row and call the eligibility assertion before persisting `customer_id`. Customer deactivate/archive also locks the customer, so an order attachment and lifecycle change serialize deterministically.

Null remains valid. Foreign, inactive, or archived identifiers return 422 with `CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE`; the order remains unchanged. Existing orders may still serialize an inactive or archived customer because historical readability is separate from eligibility for a new attachment.

### 8. Query and Index Strategy

Administrative customer search normalizes the query once and applies a tenant-scoped OR group across:

```text
customer_number
name / normalized_name
customer_phones.raw_number / normalized_number
legacy customers.phone fallback during rollout
email
```

Use `whereExists` for phone/group filters instead of result-producing joins so a customer appears once. Escape SQL wildcard characters before adding intentional partial-match wildcards. Apply tenant, permission, status, and group constraints before `paginate()` calculates totals.

Enable PostgreSQL `pg_trgm` in the expansion migration and add tenant-leading B-tree indexes for lifecycle and exact filters plus GIN trigram indexes for normalized name, number, email, and phone search expressions. Migration preflight must fail clearly if the deployment database cannot enable the extension; do not silently ship unindexed partial scans at the documented scale.

### 9. Resources, Errors, and Audit

Use separate resources for operational and administrative shapes. `OperationalCustomerResource` preserves current numeric/string behavior, including legacy `loyaltyPoints` and `tier` derivation. `CustomerManagementResource` includes identity, profile fields, lifecycle state, phones, groups, allowed actions, and ISO-8601 timestamps. It must not describe legacy counters as authoritative analytics.

Add `CustomerDomainException` rendering in `bootstrap/app.php` with stable codes and statuses:

```text
CUSTOMER_PERMISSION_DENIED             403
CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE    422
CUSTOMER_INVALID_TRANSITION            422
CUSTOMER_NUMBER_CONFLICT               409
CUSTOMER_WRITE_CONFLICT                409 (reserved for database uniqueness translation)
```

Use normal Laravel validation responses for field errors. Record customer create/update/lifecycle, employee quick-create, membership replacement, group lifecycle, and manager-permission changes through `OperationalAuditService`. Audit state includes identifiers and relevant before/after fields but excludes raw phone numbers, email, birth date, and notes to avoid copying customer PII into the general audit log; phone audit entries record phone IDs, type, primary flag, and validation status only.

## Migration and Rollout Plan

### Expansion Migration

1. Enable `pg_trgm` and add nullable `customer_number` and `normalized_name` columns.
2. Create number-counter, phone, group, membership, and Customer permission tables with tenant-safe keys and initial non-destructive indexes.
3. Do not drop, rename, or reinterpret any existing customer column.

### Backfill and Constraint Migration

1. Process all tenants and both live/archived customers in stable ID order.
2. Assign deterministic customer numbers to null rows and normalize names.
3. Insert a primary phone only where the legacy phone is non-null and no phone row exists.
4. Initialize each tenant counter to the maximum assigned Phase 1 sequence.
5. Verify no null/duplicate customer number, no null normalized name, and no customer with multiple primary phones.
6. Add non-null and unique constraints plus final search/partial-primary indexes.
7. Abort and roll back on invariant failure; never delete or rewrite legacy customer values to make validation pass.

The current production backend has no customer mutation endpoint, so existing application versions cannot create competing customer writes during pre-release backfill. Deploy the schema/backfill before enabling the new admin/quick-create routes. If production row volume makes the transactional migration exceed the deployment window, split execution into expand → deploy dual-read code → run the same idempotent backfill in bounded batches → verify → finalize constraints; record that operational runbook before deployment rather than weakening constraints.

Rollback is roll-forward: disable new routes if necessary while retaining additive tables/columns and the legacy operational reader. Do not run destructive `down()` operations on production data after Customer-domain writes begin.

## Implementation Sequence

### Phase A — Schema and Pure Domain Rules

1. Add expansion/backfill migrations and schema integrity tests.
2. Add Customer, CustomerPhone, and CustomerGroup models with tenant scopes, soft-delete behavior, and relationships.
3. Add name/phone normalizers and focused unit tests.
4. Add counter allocation and PostgreSQL concurrency coverage.

### Phase B — Authorization and Aggregate Services

1. Add `CustomerAccess`, Customer permission middleware/alias, secure default manager grant storage, and owner-only manager permission endpoints.
2. Implement transactional `CustomerService`, `CustomerGroupService`, and `CustomerQueryService`.
3. Add audit redaction/snapshots and stable domain exceptions.
4. Cover Owner, permitted/unpermitted Manager, Employee, foreign tenant, inactive actor, and Platform Super Admin separation cases.

### Phase C — Administrative and Operational APIs

1. Add request objects and resources.
2. Add full admin customer/group routes and bounded list filters.
3. Preserve the existing operational lookup route and add quick-create, membership sync, and active group lookup.
4. Lock the route-permission map with a feature test so future sensitive routes cannot omit Customer middleware.

### Phase D — Orders Compatibility Integration

1. Inject `CustomerOperationalEligibility` into `PosOrderController`.
2. Move selected-customer eligibility checks inside order create/update transactions.
3. Prove active same-tenant and null cases succeed; foreign/inactive/archived cases fail atomically.
4. Prove historical order serialization still resolves the live customer and tier discounts remain unchanged.

### Phase E — Verification and Phase Checkpoint

1. Run Customer unit and feature tests.
2. Run relevant existing POS, snapshot-aware order, tenant-validation, and discount eligibility tests.
3. Run the full Laravel backend suite against the dedicated PostgreSQL testing database.
4. Run Pint on changed PHP files, inspect the scoped diff and secrets, and run `git diff --check`.
5. Report every command and result accurately; a timeout, interruption, unavailable database, or unrelated pre-existing failure is not a pass.

## Test Strategy

### Unit Tests

- Arabic/English name normalization, whitespace, diacritics, tatweel, and Alef variants.
- ASCII, Arabic-Indic, and Eastern Arabic digit normalization.
- `valid`, `unverified`, and `invalid` phone classification without raw-value loss.
- Customer number format growth beyond six digits.

### Schema and Service Tests

- Same-tenant composite foreign keys and unique constraints.
- At-most-one primary phone database enforcement and at-least-one service enforcement.
- Customer/group normalized-name and number uniqueness, including archived rows.
- Atomic rollback when one phone or group fails.
- Idempotent lifecycle calls and rejected transition matrix.
- Backfill preservation and safe replay.
- Concurrent number allocation with no duplicates or reuse.

### Authorization Tests

- Owner full Customer and Customer Group administration.
- Manager denied without `customer.manage` and allowed after owner grant.
- Employee lookup, quick-create, active-group lookup, and membership replacement allowed.
- Employee full profile edit, lifecycle, group administration, admin listing, and permission configuration denied.
- Membership permission never implies Customer Group administration.
- Foreign-tenant identifiers reveal no record data.

### Contract and Integration Tests

- Existing operational endpoint envelope, field names/types, sort, 30-row bound, and active-only behavior.
- Search by legacy phone before/backfill fallback and primary phone after backfill.
- Admin search by number, raw/normalized name, raw/normalized phone, and email.
- Active/Inactive/Archived/All and group filters with correct totals and no duplicates.
- Admin pagination defaults to 30, caps at 100, and remains stable across equal names.
- Employee quick-create requires name plus exactly one phone and rejects extra profile fields.
- Shared phones across customers are accepted; duplicate normalized phones within one customer are rejected.
- Order create/update eligibility for active, inactive, archived, foreign, and null customers.
- Concurrent archive versus order attachment has one serialized valid outcome and no ineligible persisted relationship.
- Existing tier labels, loyalty-point compatibility, discount eligibility, walk-in orders, and live historical customer display remain green.

### Verification Commands

```powershell
docker compose exec -T backend php artisan test --filter='Customer'
docker compose exec -T backend php artisan test --filter='PosApiSmokeTest|SnapshotAwarePosOrderApiTest|TenantTaxAndValidationTest|DiscountRuntimeEligibilityTest'
docker compose exec -T backend php artisan test
docker compose exec -T backend vendor/bin/pint --test app/Domain/Customer app/Services/Customer app/Models/Customer.php app/Models/CustomerPhone.php app/Models/CustomerGroup.php app/Http/Controllers/Api/CustomerController.php app/Http/Controllers/Api/Admin/CustomerManagement app/Http/Requests/Customer app/Http/Resources/Customer app/Http/Middleware/EnsureCustomerPermission.php bootstrap/app.php routes/api.php tests/Unit/Customer tests/Feature/Customer
git diff --check
```

Do not run `migrate:fresh`, `db:wipe`, or destructive reseeding against any non-testing database. Migration tests and concurrency tests must use `cafe_system_618_testing` or an isolated equivalent.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Existing POS response changes accidentally | Dedicated operational resource and unchanged endpoint regression assertions |
| Inactive customer attached by direct ID | Shared locked eligibility assertion inside order transactions |
| Cross-tenant membership through nested IDs | Composite tenant foreign keys plus tenant-scoped complete-set validation |
| Two concurrent customers receive one number | Per-tenant counter row lock plus database unique constraint and retry-safe conflict handling |
| Phone backfill duplicates or loses raw values | Existence-guarded forward-only backfill, raw preservation, transaction rollback, replay test |
| Primary phone and legacy mirror diverge | Single aggregate transaction and partial primary uniqueness index |
| Archived-group restore collides with a replacement name | Tenant-wide normalized group-name uniqueness including archived rows |
| Manager permission broadens unrelated RBAC | One Customer-domain permission table/key and owner-only configuration; no Finance/platform reuse |
| Audit logs copy customer PII | Explicit Customer audit projection that excludes raw phone, email, birth date, and notes |
| Partial search degrades at scale | Tenant filters, bounded pages, `whereExists`, trigram indexes, and representative query-plan/performance check |
| Long production backfill blocks rollout | Preflight row count; use staged idempotent batched backfill/runbook when the deployment window is insufficient |

## Complexity Tracking

No Constitution violations require justification. The dedicated Customer domain/access layer and permission table are bounded additions required to prevent controller-level rule duplication and to implement the clarified Manager permission without expanding Finance or Platform RBAC.
