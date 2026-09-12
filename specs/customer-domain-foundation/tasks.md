# Tasks: Phase 1 — Customer Domain Foundation

**Input**: Design documents in `specs/customer-domain-foundation/`

**Required sources**: `spec.md`, `plan.md`, and `.specify/memory/constitution.md`

**Scope**: Laravel backend only. Do not add Flutter UI, loyalty changes, customer analytics/history, imports, customer merging, group discounts, tier redesign, or immutable order-customer snapshots.

**Implementation rule**: Work in task-ID order unless the dependency tables below explicitly permit parallel work. For every test-first task, run the narrow test and confirm that it fails for the missing behavior before implementing the paired production task. Do not weaken or delete an assertion merely to make a test pass.

**Database safety**: Run migration and concurrency tests only against `cafe_system_618_testing` or an isolated equivalent. Never run `migrate:fresh`, `db:wipe`, destructive reseeding, or destructive migration rollback against non-testing data.

## Format: `[ID] [P?] [Story] Description`

- **[P]** means the task may run in parallel with other `[P]` tasks in the same phase because it changes different files and has no unfinished dependency.
- **[US1]–[US6]** maps work to the numbered user story in `spec.md`.
- Every task names the files it is allowed or expected to change. Preserve unrelated working-tree changes.

---

## Phase 1: Setup and Baseline Contract

**Purpose**: Establish a trustworthy baseline and test structure before changing production behavior.

- [x] T001 Record the pre-implementation working-tree state with `git status --short`, inspect `backend/app/Http/Controllers/Api/CustomerController.php`, `backend/app/Http/Controllers/Api/PosOrderController.php`, `backend/routes/api.php`, `backend/tests/TestCase.php`, and `backend/database/migrations/2026_05_31_000008_create_customers_table.php`, and note unrelated changes that must remain untouched in the implementation handoff.
- [x] T002 Run the existing focused compatibility baseline `docker compose exec -T backend php artisan test --filter='PosApiSmokeTest|SnapshotAwarePosOrderApiTest|TenantTaxAndValidationTest|DiscountRuntimeEligibilityTest'` without editing tests; record failures, timeouts, or unavailable services accurately before creating files under `backend/tests/Feature/Customer/`.
- [x] T003 Create the empty test namespaces/directories `backend/tests/Unit/Customer/` and `backend/tests/Feature/Customer/` only if absent, following the namespace and real opaque-token conventions in `backend/tests/TestCase.php`.

**Checkpoint**: Existing operational behavior and pre-existing repository state are documented.

---

## Phase 2: Foundational Domain and Persistence (Blocking)

**Purpose**: Add the schema, pure rules, models, stable errors, and authorization primitives required by every user story.

**CRITICAL**: Do not start user-story implementation until T004–T022 are complete.

### Pure normalization rules

- [x] T004 [P] Add failing unit cases for displayed-name preservation, trim/collapsed whitespace, case folding, Arabic diacritic and tatweel removal, and Alef variant normalization in `backend/tests/Unit/Customer/CustomerNameNormalizerTest.php`.
- [x] T005 [P] Add failing unit cases for raw-value preservation, outer trimming, ASCII/Arabic-Indic/Eastern-Arabic digits, punctuation removal, retained leading `+`, `valid` 8–15 digit E.164-like values, `unverified` 7–15 digit national values, and `invalid` values with nullable normalized output in `backend/tests/Unit/Customer/CustomerPhoneNormalizerTest.php`.
- [x] T006 Implement the deterministic, locale-independent rules from T004 in `backend/app/Domain/Customer/CustomerNameNormalizer.php`; never mutate the displayed raw name.
- [x] T007 Implement the dependency-free normalization/classification result used by T005 in `backend/app/Domain/Customer/CustomerPhoneNormalizer.php`; reject only blank/over-limit inputs at request validation, not uncertain formats inside the normalizer.

### Expansion and forward-only backfill

- [x] T008 Add failing PostgreSQL schema assertions in `backend/tests/Feature/Customer/CustomerDomainSchemaTest.php` for `pg_trgm`, nullable customer foundation columns during expansion, all four new tenant-owned tables, tenant-safe composite keys, non-global phone uniqueness, membership uniqueness, and lifecycle/search indexes.
- [x] T009 Implement the additive expansion migration `backend/database/migrations/2026_09_09_000002_add_customer_domain_foundation.php`: enable `pg_trgm` with a clear failure if unavailable; add nullable `customers.customer_number` and `customers.normalized_name`; add unique `(tenant_id,id)` parent key; create `customer_number_counters`, `customer_phones`, `customer_groups`, `customer_group_memberships`, and `customer_role_permissions`; constrain Phase 1 permission rows to `role=manager` and `permission=customer.manage`; add same-tenant composite foreign keys and initial B-tree/GIN indexes; do not drop, rename, reinterpret, or rewrite legacy columns.
- [x] T010 Extend `backend/tests/Feature/Customer/CustomerDomainSchemaTest.php` with failing backfill/replay cases covering active and soft-deleted customers, deterministic per-tenant ID ordering, cross-tenant number reuse, raw legacy-phone preservation, existence-guarded primary-phone creation, normalized name/status derivation, counter high-water marks, invariant failure rollback, and a safe second invocation with no duplicate phones or numbers.
- [x] T011 Implement `backend/database/migrations/2026_09_09_000003_backfill_and_constrain_customer_foundation.php` in stable tenant/customer ID order using the production normalizers: fill null numbers and normalized names, insert a primary phone only when legacy `customers.phone` is non-null and no phone row exists, initialize each counter to the maximum assigned sequence, verify all invariants, then add non-null/tenant-unique customer-number and normalized-name constraints plus the partial one-primary-phone index. Keep `customers.phone` intact and make `down()` non-destructive once Customer-domain writes may exist.

### Models and number allocation

- [x] T012 [P] Add failing model/relationship assertions to `backend/tests/Feature/Customer/CustomerDomainSchemaTest.php` for tenant scoping, soft-deleted retrieval in authorized contexts, casts, customer phones/groups, group customers, and preservation of phone/membership rows across archive operations.
- [x] T013 [P] Add failing format and allocation cases in `backend/tests/Feature/Customer/CustomerNumberConcurrencyTest.php` for `C-000001`, growth beyond six digits, independent tenant sequences, archived-number non-reuse, locked concurrent allocation, and database-conflict translation without duplicate numbers.
- [x] T014 Implement `backend/app/Models/Customer.php`, `backend/app/Models/CustomerPhone.php`, and `backend/app/Models/CustomerGroup.php` with explicit fillable/cast/relationship definitions, tenant-scoped query helpers, `SoftDeletes` for customers/groups, and no global phone uniqueness or automatic merge behavior.
- [x] T015 Implement `backend/app/Domain/Customer/CustomerNumberGenerator.php` with `insertOrIgnore` plus a tenant counter `lockForUpdate`, monotonic increment, `C-` plus minimum six-digit padding, high-water safety for migrated/imported rows, and stable conflict handling required by T013; callers must invoke it inside their aggregate transaction.

### Stable errors and authorization primitives

- [x] T016 [P] Add failing rendering assertions in `backend/tests/Feature/Customer/CustomerAuthorizationApiTest.php` for `CUSTOMER_PERMISSION_DENIED` (403), `CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE` (422), `CUSTOMER_INVALID_TRANSITION` (422), `CUSTOMER_NUMBER_CONFLICT` (409), and `CUSTOMER_WRITE_CONFLICT` (409), while normal field errors retain Laravel's validation envelope.
- [x] T017 Implement the code/status mapping in `backend/app/Domain/Customer/CustomerDomainException.php` and register JSON rendering for `/api/*` in `backend/bootstrap/app.php` without changing existing `OrderLifecycleException` or generic `DomainException` behavior.
- [x] T018 Extend `backend/tests/Feature/Customer/CustomerAuthorizationApiTest.php` with failing capability-matrix cases for active Owner, Manager with/without `customer.manage`, Employee operational lookup/quick-create/membership rights, inactive/deleted tenant actors, foreign tenant IDs, and Platform Super Admin separation; assert that new tenants grant managers nothing by default.
- [x] T019 Implement actor reload and the explicit `assertCanAdminister`, `assertCanQuickCreate`, `assertCanManageMemberships`, `assertCanUseOperationalLookup`, and `assertOwnerCanConfigureManagerPermission` checks in `backend/app/Domain/Customer/CustomerAccess.php`; derive tenant/actor only from authenticated request attributes and the existing canonical tenant-role service.
- [x] T020 Implement `backend/app/Http/Middleware/EnsureCustomerPermission.php`, register the `customer.permission` alias in `backend/bootstrap/app.php`, and require services to repeat sensitive aggregate authorization instead of relying only on route middleware.
- [x] T021 Add failing owner-only manager-permission API cases to `backend/tests/Feature/Customer/CustomerAuthorizationApiTest.php`: GET reports enabled state; PUT enables/disables exactly `customer.manage`; Owner cannot be disabled; Manager/Employee/Platform Super Admin are denied; each tenant is isolated; repeated replacement is idempotent.
- [x] T022 Implement `backend/app/Http/Controllers/Api/Admin/CustomerManagement/CustomerRolePermissionController.php` and register `GET|PUT /api/v1/admin/customer-management/role-permissions/manager` in `backend/routes/api.php`; store only the allowlisted Manager permission in `customer_role_permissions`, use a transaction, return a stable JSON shape, and record a PII-free permission-change event through `backend/app/Services/OperationalAuditService.php`.

**Checkpoint**: The additive schema, repeatable backfill, models, normalizers, number generator, domain errors, and capability model pass focused tests; all later writes can use them without inventing local rules.

---

## Phase 3: User Story 1 — Manage Tenant Customers Safely (Priority: P1) MVP

**Goal**: Authorized Owners and permitted Managers can create, retrieve, and update same-tenant customers; immutable identity and tenant isolation are backend-enforced.

**Independent Test**: Create a name-only customer as an authorized administrator, retrieve and update it, then prove unauthorized and foreign-tenant reads/writes disclose nothing and persist nothing.

### Tests for User Story 1

- [x] T023 [US1] Add failing API cases in `backend/tests/Feature/Customer/CustomerManagementApiTest.php` for admin create/show/update, name-only creation, default Active state, optional email/birth date/notes, generated immutable number, rejection of caller-selected `customerNumber`/`tenantId`, validation limits, fresh response timestamps, and no partial record on failure.
- [x] T024 [US1] Extend `backend/tests/Feature/Customer/CustomerAuthorizationApiTest.php` with failing US1 cases: Owner allowed; permitted Manager allowed; unpermitted Manager and Employee denied; cross-tenant route IDs return non-disclosing 404; nested foreign IDs return non-disclosing 422; inactive actor and Platform Super Admin cannot enter the tenant API.

### Implementation for User Story 1

- [x] T025 [US1] Implement transactional profile create/update and tenant-scoped locked retrieval in `backend/app/Services/Customer/CustomerService.php`: repeat `CustomerAccess` checks, generate rather than accept customer numbers, calculate normalized names, preserve tenant/ID/number/legacy metrics, default new customers Active, and translate uniqueness races to stable domain/validation errors.
- [x] T026 [P] [US1] Implement strict admin profile validation and unknown/prohibited-field rejection in `backend/app/Http/Requests/Customer/StoreCustomerRequest.php` and `backend/app/Http/Requests/Customer/UpdateCustomerRequest.php`; allow only the Phase 1 profile, phone, group, and optional administrative active-state fields specified by the plan.
- [x] T027 [P] [US1] Implement `backend/app/Http/Resources/Customer/CustomerManagementResource.php` with customer number, raw profile fields, derived lifecycle state, loaded phones/groups, allowed actions, and ISO-8601 timestamps; do not label `total_spent`/`visits_count` as authoritative analytics.
- [x] T028 [US1] Implement `store`, `show`, and `update` actions in `backend/app/Http/Controllers/Api/Admin/CustomerManagement/CustomerManagementController.php` as thin request/service/resource adapters, including authorized retrieval of archived rows by direct ID.
- [x] T029 [US1] Register admin customer `POST`, `GET {customer}`, and `PUT {customer}` routes under `/api/v1/admin/customer-management/customers` in `backend/routes/api.php` with `api.token`, `password.changed`, and `customer.permission:customer.manage`; do not add a hard-delete route or alter `GET /api/v1/customers`.
- [x] T030 [US1] Add Customer create/update audit projections in `backend/app/Services/Customer/CustomerService.php` using `backend/app/Services/OperationalAuditService.php`: include IDs and relevant before/after state, but exclude raw phone numbers, email, birth date, notes, and all other copied PII; cover the projection in `backend/tests/Feature/Customer/CustomerManagementApiTest.php`.
- [x] T031 [US1] Run `docker compose exec -T backend php artisan test --filter='CustomerManagementApiTest|CustomerAuthorizationApiTest|CustomerNumberConcurrencyTest'` and fix only US1/foundational failures in `backend/tests/Feature/Customer/`, `backend/app/Domain/Customer/`, `backend/app/Services/Customer/`, and the US1 HTTP files named by T026–T029.

**Checkpoint**: User Story 1 works independently for a name-only customer and is the Phase 1 administrative MVP.

---

## Phase 4: User Story 2 — Preserve POS Lookup and Enforce Order Eligibility (Priority: P1)

**Goal**: Keep the existing POS customer response stable, add constrained Employee quick-create, and use one locked eligibility rule for lookup and new/mutable order attachment.

**Independent Test**: Assert the legacy no-parameter lookup byte-shape semantics and 30-row bound, quick-create a customer as an Employee, and test active/null versus inactive/archived/deleted/foreign customer attachment on order create/update.

### Tests for User Story 2

- [x] T032 [P] [US2] Add failing compatibility cases in `backend/tests/Feature/Customer/CustomerOperationalCompatibilityTest.php` for authenticated tenant scope, Active/non-archived filtering, name order, 30-row maximum, optional legacy name/phone search, exact `{data:[...]}` envelope, and required `id`, `name`, `phone`, `email`, `totalSpent`, `visitsCount`, `loyaltyPoints`, and `tier` types/meanings.
- [x] T033 [P] [US2] Add failing quick-create cases in `backend/tests/Feature/Customer/CustomerOperationalCompatibilityTest.php`: Owner/Manager/Employee allowed; name and exactly one non-blank phone required; extra phones and full-profile/lifecycle/group-admin fields rejected; created customer Active with one primary classified phone and generated number; validation failure leaves no customer/phone/audit rows.
- [x] T034 [P] [US2] Add failing create/update integration cases in `backend/tests/Feature/Customer/CustomerOrderEligibilityTest.php` for active same-tenant and nullable walk-in success; inactive, archived, soft-deleted, nonexistent, and foreign IDs returning `CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE` without changing the order/items/pricing; customer update still obeys existing order mutability policy.

### Implementation for User Story 2

- [x] T035 [US2] Implement the sole `tenant_id + is_active=true + deleted_at IS NULL` query scope and locked nullable assertion in `backend/app/Domain/Customer/CustomerOperationalEligibility.php`; foreign/nonexistent/inactive/archived/deleted IDs must share the same non-disclosing domain error.
- [x] T036 [P] [US2] Implement the legacy-compatible field mapping and tier/loyalty derivation in `backend/app/Http/Resources/Customer/OperationalCustomerResource.php`, including primary-phone output with legacy `customers.phone` fallback when no primary row exists.
- [x] T037 [US2] Refactor only `index` in `backend/app/Http/Controllers/Api/CustomerController.php` to use `CustomerAccess`, `CustomerOperationalEligibility`, and `OperationalCustomerResource`; preserve the no-admin-parameter query contract, name ordering, 30-row cap, legacy search behavior, and `{data: [...]}` envelope.
- [x] T038 [P] [US2] Implement an exact allowlist validator in `backend/app/Http/Requests/Customer/QuickCreateCustomerRequest.php` for required trimmed name plus exactly one phone object/value within the established 50-character raw limit; explicitly reject profile, lifecycle, number, group-administration, and extra-phone fields.
- [x] T039 [US2] Add a limited quick-create method to `backend/app/Services/Customer/CustomerService.php` that repeats `assertCanQuickCreate`, creates the Active customer/number/normalized name/one primary phone/legacy mirror in one transaction, and records a PII-free audit event; expose it through `storeQuick` in `backend/app/Http/Controllers/Api/CustomerController.php` and `POST /api/v1/customers/quick-create` in `backend/routes/api.php`.
- [x] T040 [US2] Replace only the `customerId` existence rules in `store` and `update` in `backend/app/Http/Controllers/Api/PosOrderController.php` with nullable integer shape validation, inject `CustomerOperationalEligibility`, and perform its locked assertion inside the existing order transaction immediately before writing `customer_id`; preserve idempotency, snapshot binding, branch checks, pricing, null clearing, and all other order behavior.
- [x] T041 [US2] Add a deterministic PostgreSQL race case to `backend/tests/Feature/Customer/CustomerOrderEligibilityTest.php` for concurrent customer archive/deactivate versus order attachment, accepting either serialization order but asserting the final database never contains a newly attached ineligible customer and never has partial order effects.
- [x] T042 [US2] Run `docker compose exec -T backend php artisan test --filter='CustomerOperationalCompatibilityTest|CustomerOrderEligibilityTest|PosApiSmokeTest|SnapshotAwarePosOrderApiTest|TenantTaxAndValidationTest|DiscountRuntimeEligibilityTest'` and fix only US2/regression failures in `backend/app/Domain/Customer/CustomerOperationalEligibility.php`, `backend/app/Http/Controllers/Api/CustomerController.php`, `backend/app/Http/Controllers/Api/PosOrderController.php`, Customer resources/services, or the corresponding `backend/tests/` files without changing published menu, tier, discount, or order-history contracts.

**Checkpoint**: User Stories 1 and 2 both pass; existing POS consumers remain compatible and direct IDs cannot bypass customer eligibility.

---

## Phase 5: User Story 3 — Maintain Multiple Customer Phones (Priority: P2)

**Goal**: Administrators can atomically maintain zero, one, or many authoritative phone rows with exactly one primary when any exist and a synchronized legacy mirror.

**Independent Test**: Create/update customers with zero, one, and multiple phones; change/remove the primary; accept shared phones across customers; reject duplicates inside one customer; verify raw/normalized search and legacy fallback.

### Tests for User Story 3

- [x] T043 [US3] Add failing aggregate cases in `backend/tests/Feature/Customer/CustomerPhoneCompatibilityTest.php` for zero/one/multiple phones, exactly-one-primary validation, primary changes/removal, last-phone removal, reordering without mirror churn, raw preservation, all three validation statuses, and full transaction rollback on any invalid phone.
- [x] T044 [US3] Extend `backend/tests/Feature/Customer/CustomerPhoneCompatibilityTest.php` with failing identity cases: identical phones are allowed across customers and tenants; duplicate non-null normalized phones inside one submitted customer collection are rejected; multiple unnormalizable/null-normalized raw values follow an explicit non-merging policy; no automatic customer merge occurs.
- [x] T045 [US3] Extend `backend/tests/Feature/Customer/CustomerOperationalCompatibilityTest.php` with failing rollout cases for a legacy-phone-only row: serialize/search the legacy raw value before backfill completion, then prefer the authoritative primary phone afterward without changing the response shape.

### Implementation for User Story 3

- [x] T046 [US3] Implement a private locked phone-collection replacement path in `backend/app/Services/Customer/CustomerService.php`: normalize once, reject duplicate normalized entries, enforce exactly one primary when non-empty, replace rows and mirror the primary raw value (or null) to `customers.phone` in the same transaction, and never compare phones across different customers as identity.
- [x] T047 [US3] Complete nested phone rules in `backend/app/Http/Requests/Customer/StoreCustomerRequest.php` and `backend/app/Http/Requests/Customer/UpdateCustomerRequest.php` for raw number/type/primary fields, collection cardinality, length, distinct normalized values, and prohibited caller-supplied normalization/status/tenant/customer IDs.
- [x] T048 [US3] Complete phone loading/serialization in `backend/app/Http/Resources/Customer/CustomerManagementResource.php` and transitional primary/legacy fallback in `backend/app/Http/Resources/Customer/OperationalCustomerResource.php`; preserve insertion/display order deterministically without making order affect the primary mirror.
- [x] T049 [US3] Extend Customer audit coverage in `backend/tests/Feature/Customer/CustomerPhoneCompatibilityTest.php` and the projection in `backend/app/Services/Customer/CustomerService.php` so phone changes log only phone IDs, type, primary flag, and validation status—never raw or normalized numbers.
- [x] T050 [US3] Run `docker compose exec -T backend php artisan test --filter='CustomerPhoneCompatibilityTest|CustomerOperationalCompatibilityTest|CustomerManagementApiTest'` and resolve only US3 regressions in `backend/app/Services/Customer/CustomerService.php`, Customer requests/resources, or `backend/tests/Feature/Customer/`.

**Checkpoint**: Multi-phone rows are authoritative, the legacy phone mirror cannot diverge, and shared numbers never imply customer identity.

---

## Phase 6: User Story 4 — Organize Customers in Groups (Priority: P2)

**Goal**: Administrators manage group lifecycle while all tenant users may atomically replace memberships using existing active same-tenant groups; groups never change legacy tiers or discounts.

**Independent Test**: Create two groups, assign both to one customer, remove one, archive/restore a group, reject a cross-tenant/archived assignment atomically, and prove legacy tier behavior is unchanged.

### Tests for User Story 4

- [x] T051 [P] [US4] Add failing group administration cases in `backend/tests/Feature/Customer/CustomerGroupApiTest.php` for Owner/permitted Manager list/create/show/update/archive/restore, normalized tenant-wide name uniqueness including archived rows, default archived exclusion, idempotent lifecycle calls, retained memberships, and Employee/unpermitted Manager denial.
- [x] T052 [P] [US4] Add failing membership cases in `backend/tests/Feature/Customer/CustomerGroupApiTest.php` for Owner/Manager/Employee complete-set replacement, empty-list removal, duplicate-ID rejection, active same-tenant validation, cross-tenant and archived-group rejection with unchanged existing set, and one membership row per requested group.
- [x] T053 [P] [US4] Add failing active group lookup cases in `backend/tests/Feature/Customer/CustomerGroupApiTest.php` for all operational roles, tenant isolation, bounded pagination, deterministic ordering, archived/inactive exclusion, and no authority escalation into group administration.

### Implementation for User Story 4

- [x] T054 [US4] Implement transactional create/update/archive/restore and tenant-scoped retrieval in `backend/app/Services/Customer/CustomerGroupService.php`: normalize names, lock rows, retain memberships, restore to Active, make repeated target actions no-ops, reject uniqueness conflicts stably, and repeat administration authorization.
- [x] T055 [P] [US4] Implement strict create/update validation in `backend/app/Http/Requests/Customer/CustomerGroupRequest.php` and stable group identity/lifecycle/timestamp output in `backend/app/Http/Resources/Customer/CustomerGroupResource.php`.
- [x] T056 [US4] Implement admin list/create/show/update/archive/restore adapters in `backend/app/Http/Controllers/Api/Admin/CustomerManagement/CustomerGroupController.php` and register the planned `/api/v1/admin/customer-management/customer-groups` routes in `backend/routes/api.php` with `customer.permission:customer.manage`; expose no hard delete.
- [x] T057 [P] [US4] Implement unique integer `groupIds` complete-set validation in `backend/app/Http/Requests/Customer/SyncCustomerGroupsRequest.php`, explicitly allowing an empty array and rejecting tenant/group fields outside the allowlist.
- [x] T058 [US4] Add locked atomic membership replacement to `backend/app/Services/Customer/CustomerService.php`: repeat `assertCanManageMemberships`, resolve every requested ID under the authenticated tenant and active/non-archived constraint before deleting/inserting anything, retain unrelated archived-group history unless explicitly represented by the service contract, and emit a PII-free before/after group-ID audit.
- [x] T059 [US4] Expose membership replacement through `syncGroups` in `backend/app/Http/Controllers/Api/CustomerController.php` and `PUT /api/v1/customers/{customer}/groups` in `backend/routes/api.php`; implement paginated active-group selection in `backend/app/Http/Controllers/Api/CustomerGroupLookupController.php` at `GET /api/v1/customer-groups` without granting administration.
- [x] T060 [US4] Record group create/update/archive/restore audit events in `backend/app/Services/Customer/CustomerGroupService.php` with identifiers and lifecycle/name metadata but no copied customer PII, and assert audit behavior in `backend/tests/Feature/Customer/CustomerGroupApiTest.php`.
- [x] T061 [US4] Add tier-regression assertions to `backend/tests/Feature/Customer/CustomerGroupApiTest.php` and run `docker compose exec -T backend php artisan test --filter='CustomerGroupApiTest|DiscountRuntimeEligibilityTest|CustomerOperationalCompatibilityTest'`; group membership must not alter `new`, `regular`, or `vip` calculation or discount eligibility.

**Checkpoint**: Group administration and membership authority are distinct, all relationships are tenant-safe, and tiers remain untouched.

---

## Phase 7: User Story 5 — Search and Filter the Administrative Collection (Priority: P2)

**Goal**: Authorized administrators can search and filter a large tenant collection through bounded, stable server-side pagination.

**Independent Test**: Seed more than one page across tenants/states/groups, then search every supported field and verify filters, totals, uniqueness, stable ordering, and the 100-row cap.

### Tests for User Story 5

- [x] T062 [US5] Add failing collection cases in `backend/tests/Feature/Customer/CustomerSearchPaginationTest.php` for default 30 and maximum 100 per page, rejection/capping policy above 100, `currentPage/lastPage/perPage/total` camelCase metadata, normalized-name-plus-ID stable order, archived exclusion by default, and explicit `active|inactive|archived|all` filters.
- [x] T063 [US5] Extend `backend/tests/Feature/Customer/CustomerSearchPaginationTest.php` with failing same-tenant partial/exact matches across customer number, displayed name, Arabic-normalized name, raw/normalized authoritative phone, legacy-phone fallback, and email; include `%`, `_`, and backslash input to prove wildcard escaping rather than unintended broad matching.
- [x] T064 [US5] Extend `backend/tests/Feature/Customer/CustomerSearchPaginationTest.php` with failing active same-tenant `groupId` filter, foreign/archived group rejection, multi-group customer uniqueness via `whereExists`, and totals calculated after tenant/permission/status/group/search constraints.

### Implementation for User Story 5

- [x] T065 [P] [US5] Implement query validation/defaults in `backend/app/Http/Requests/Customer/ListCustomersRequest.php` for `search`, `status`, `groupId`, `page`, and `perPage`; normalize integer bounds and apply one documented reject-or-cap policy consistently with the tests.
- [x] T066 [US5] Implement `backend/app/Services/Customer/CustomerQueryService.php`: begin with authenticated tenant scope, escape SQL wildcard characters, normalize the query once, group OR search predicates, use `whereExists` for phone/group matching, retain legacy-phone fallback only when no primary phone row exists, apply state/group filters before `paginate()`, and order by normalized name then ID.
- [x] T067 [US5] Add admin `index` to `backend/app/Http/Controllers/Api/Admin/CustomerManagement/CustomerManagementController.php`, register `GET /api/v1/admin/customer-management/customers` in `backend/routes/api.php`, eager-load only page records, and emit exactly the planned `data` plus camelCase `meta` envelope through `CustomerManagementResource`.
- [x] T068 [US5] Add a representative 100,000-row PostgreSQL query-plan/performance test or an explicitly opt-in benchmark in `backend/tests/Feature/Customer/CustomerSearchPaginationTest.php`; verify tenant-leading lifecycle indexes, `whereExists`, and trigram indexes avoid an unbounded cross-tenant scan and document measured operational/admin p95 evidence in `specs/customer-domain-foundation/tasks.md` notes without weakening correctness tests when timing is noisy. Measured on 2026-09-09 against local Docker PostgreSQL: 20 samples on a 100,000-customer tenant, operational lookup p95 32.24 ms (target <=200 ms), administrative search p95 209.63 ms (target <=300 ms); `EXPLAIN ANALYZE` asserted an Index plan and no Seq Scan.
- [x] T069 [US5] Run `docker compose exec -T backend php artisan test --filter='CustomerSearchPaginationTest|CustomerOperationalCompatibilityTest|CustomerAuthorizationApiTest'` and resolve only US5/contract failures in `backend/app/Services/Customer/CustomerQueryService.php`, the admin list request/controller/resource, `backend/routes/api.php`, or `backend/tests/Feature/Customer/`.

**Checkpoint**: Administrative search is tenant-safe, bounded, stable, Arabic-aware, wildcard-safe, and duplicate-free.

---

## Phase 8: User Story 6 — Change Lifecycle Without Losing History (Priority: P2)

**Goal**: Authorized administrators deactivate, activate, archive, and restore customers without deletion, history loss, or invalid operational reuse.

**Independent Test**: Attach a customer to an order, execute every valid/invalid/repeated transition, and verify list/eligibility behavior plus the unchanged historical relationship and live-profile display.

### Tests for User Story 6

- [x] T070 [US6] Add the complete state/action matrix to `backend/tests/Feature/Customer/CustomerManagementApiTest.php`: Active→Inactive, Inactive→Active, Active/Inactive→Archived, Archived→Inactive only through restore, repeated target-state idempotency, and deterministic `CUSTOMER_INVALID_TRANSITION` with no state change for unsupported actions.
- [x] T071 [US6] Add history/visibility cases in `backend/tests/Feature/Customer/CustomerManagementApiTest.php` and `backend/tests/Feature/Customer/CustomerOrderEligibilityTest.php`: archived hidden from default lists but directly retrievable by authorized admin, inactive/archived ineligible for new attachment, phone/group/order rows retained, restore returns Inactive, activation is separate, and existing order serialization resolves the current live customer name/primary phone.

### Implementation for User Story 6

- [x] T072 [US6] Add locked `activate`, `deactivate`, `archive`, and `restore` methods to `backend/app/Services/Customer/CustomerService.php` using the exact state table from `plan.md`; set archived customers inactive, preserve phones/memberships/orders, treat already-achieved targets as successful no-ops, reject all other transitions, and emit PII-free lifecycle audits in the same transaction.
- [x] T073 [US6] Add lifecycle actions to `backend/app/Http/Controllers/Api/Admin/CustomerManagement/CustomerManagementController.php` and register the four planned POST routes in `backend/routes/api.php` with Customer admin middleware; always return a fresh `CustomerManagementResource` and never expose DELETE.
- [x] T074 [US6] Run `docker compose exec -T backend php artisan test --filter='CustomerManagementApiTest|CustomerOrderEligibilityTest|CustomerGroupApiTest|SnapshotAwarePosOrderApiTest'` and resolve only US6/history regressions in `backend/app/Services/Customer/CustomerService.php`, the admin customer controller/routes, or the corresponding `backend/tests/` files.

**Checkpoint**: All six user stories are independently testable and lifecycle changes never erase historical relationships.

---

## Phase 9: Cross-Cutting Security, Contract, and Audit Hardening

**Purpose**: Lock down interactions that span multiple user stories and prevent later route or audit regressions.

- [x] T075 Add a canonical map of every Customer-sensitive route and its required authentication/Customer capability middleware in `backend/tests/Feature/Customer/CustomerRoutePermissionMapTest.php`; fail when a new `/api/v1/admin/customer-management/*`, quick-create, membership, or active-group route is missing or mapped to broader Finance/Platform permissions.
- [x] T076 Add complete PII-redaction regression cases in `backend/tests/Feature/Customer/CustomerAuthorizationApiTest.php` covering create/update/quick-create/membership/customer lifecycle/group lifecycle/manager-permission audit rows; inspect serialized `before_state` and `after_state` to ensure raw/normalized phones, email, birth date, notes, tokens, and credentials never appear.
- [x] T077 Review `backend/routes/api.php`, `backend/bootstrap/app.php`, and all files under `backend/app/Domain/Customer/`, `backend/app/Services/Customer/`, `backend/app/Http/Controllers/Api/Admin/CustomerManagement/`, `backend/app/Http/Requests/Customer/`, and `backend/app/Http/Resources/Customer/` for authenticated tenant scope on every read/count/validation/write, service-level authorization, no client-selected tenant, no unbounded collection, no hard delete, and no duplicated tier/order business logic; add a focused regression test before fixing any discovered gap.
- [x] T078 Review `backend/database/migrations/2026_09_09_000002_add_customer_domain_foundation.php` and `backend/database/migrations/2026_09_09_000003_backfill_and_constrain_customer_foundation.php` against production rollout requirements: additive expansion first, idempotent data work, preflight/invariant failure, archived-row coverage, old-reader compatibility, no legacy-field deletion, final constraints only after validation, and roll-forward recovery. If representative row count exceeds the deployment window, add the required bounded-backfill operator runbook at `specs/customer-domain-foundation/backfill-runbook.md`; otherwise record why it is unnecessary in the final handoff without inventing production measurements.
- [x] T079 Run `docker compose exec -T backend php artisan test --filter='Customer'` for `backend/tests/Unit/Customer/` and `backend/tests/Feature/Customer/`, then resolve all Customer-domain failures; do not describe a timeout, interruption, missing PostgreSQL extension, or unavailable database as a pass.

---

## Phase 10: Final Verification and Handoff

**Purpose**: Produce fresh evidence that the implementation is correct, compatible, scoped, and ready for review.

- [x] T080 Run the affected integration regression command `docker compose exec -T backend php artisan test --filter='PosApiSmokeTest|SnapshotAwarePosOrderApiTest|TenantTaxAndValidationTest|DiscountRuntimeEligibilityTest'` for the named classes in `backend/tests/Feature/`, record the exact test count/result, and fix only regressions caused by Customer-domain changes.
- [ ] T081 Run the full `backend/tests/` checkpoint with `docker compose exec -T backend php artisan test` against the dedicated PostgreSQL testing database and report the exact result, including every unrelated pre-existing failure or timeout.
- [x] T082 Run Pint in check mode on only changed Customer-domain PHP files and direct integration files with `docker compose exec -T backend vendor/bin/pint --test app/Domain/Customer app/Services/Customer app/Models/Customer.php app/Models/CustomerPhone.php app/Models/CustomerGroup.php app/Http/Controllers/Api/CustomerController.php app/Http/Controllers/Api/CustomerGroupLookupController.php app/Http/Controllers/Api/Admin/CustomerManagement app/Http/Requests/Customer app/Http/Resources/Customer app/Http/Middleware/EnsureCustomerPermission.php bootstrap/app.php routes/api.php tests/Unit/Customer tests/Feature/Customer`; format only those changed files if needed and rerun the check.
- [x] T083 Run `git diff --check`, then inspect `git status --short` and the complete scoped diff under `backend/` and `specs/customer-domain-foundation/` for secrets, PII in audit fixtures/output, fake production state, destructive schema operations, generated-file churn, unrelated formatting/refactors, and accidental Flutter/loyalty/analytics/import/tier/snapshot work.
- [x] T084 Update only authoritative Customer Phase 1 documentation if the implemented contract necessarily differs from `specs/customer-domain-foundation/spec.md` or `specs/customer-domain-foundation/plan.md`; do not rewrite requirements to conceal an implementation gap, and list every deliberate deviation or incomplete check in the final handoff.

**Final checkpoint**: Do not claim Phase 1 complete unless T079–T083 finished successfully. Any skipped, unavailable, interrupted, timed-out, or failing command must be reported by its real status.

---

## Dependencies and Execution Order

### Phase dependencies

- **Phase 1 (T001–T003)**: No dependencies.
- **Phase 2 (T004–T022)**: Depends on Phase 1 and blocks all user stories. Within it, T004→T006, T005→T007, T008→T009, T010→T011, T012→T014, T013→T015, T016→T017, T018→T019→T020, and T021→T022.
- **US1 / Phase 3 (T023–T031)**: Depends on all foundational tasks. T023/T024 precede T025–T030; T025 precedes controller wiring; T026/T027 may run in parallel after their tests exist.
- **US2 / Phase 4 (T032–T042)**: Depends on US1 because quick-create reuses Customer creation, but its compatibility and order tests can be written after Phase 2. T034→T035/T040 and T032→T036→T037.
- **US3 / Phase 5 (T043–T050)**: Depends on US1 aggregate creation and US2 operational resource; test tasks T043–T045 precede implementation.
- **US4 / Phase 6 (T051–T061)**: Depends on foundational group schema/authorization and US1 Customer service; group admin and active lookup may be developed in parallel before route integration.
- **US5 / Phase 7 (T062–T069)**: Depends on US3 phones and US4 groups so every search/filter path can be implemented once.
- **US6 / Phase 8 (T070–T074)**: Depends on US1, US2 eligibility, and US4 relationship preservation.
- **Hardening / Phase 9 (T075–T079)**: Depends on every selected user story.
- **Verification / Phase 10 (T080–T084)**: Depends on all implementation and hardening tasks.

### User-story dependency graph

```text
Setup → Foundation → US1 Customer administration
                       ├→ US2 POS compatibility + eligibility
                       │    └→ US3 multi-phone authority
                       └→ US4 groups + memberships
                            └──────────────┐
US3 ──────────────────────────────────────┼→ US5 admin search
US2 + US4 ────────────────────────────────┴→ US6 lifecycle/history
US1–US6 → Hardening → Final verification
```

### Safe parallel opportunities

- T004 and T005 may run together; implement T006 and T007 only after their corresponding failing tests.
- T012, T013, and T016 may run together after migrations exist because they target different test/production files.
- T026 and T027 may run together after the US1 contract tests are written.
- T032, T033, and T034 may run together; T035–T040 must then follow their indicated dependencies.
- T051, T052, and T053 may run together; T055 and T057 may run together after those tests fail as expected.
- Do not parallelize edits to `backend/app/Services/Customer/CustomerService.php`, `backend/routes/api.php`, `backend/bootstrap/app.php`, or the same test file.

---

## Implementation Strategy for a Lower-Cost Model

1. Execute one task ID at a time and reread that task's matching `spec.md` acceptance scenarios and `plan.md` design decision before editing.
2. Use the named existing repository files as patterns; do not create a second tenant context, RBAC system, tier calculator, order serializer, audit table, or phone identity rule.
3. For a test task, add only the named failing behavior and run only that test class. Record the expected failure reason before moving to production code.
4. For an implementation task, change only the named paths, rerun its paired focused test, then rerun the last completed story checkpoint.
5. Treat a foreign identifier as untrusted input: scope the parent and every nested relationship to the authenticated tenant before revealing data or mutating rows.
6. Keep aggregate operations transactional and lock the authoritative parent/counter rows before checking state that a concurrent request can change.
7. Preserve the operational customer envelope, nullable walk-in orders, live historical display, legacy tier metrics, and tier-based discounts exactly; additive admin resources belong only under the admin boundary.
8. Stop and report the exact blocker if PostgreSQL, `pg_trgm`, Docker, or the testing database is unavailable. Never substitute SQLite for PostgreSQL-specific constraint/concurrency proof and never claim an incomplete check passed.

## Requirement Coverage Map

| Requirement area | Primary tasks |
|---|---|
| Tenant isolation and authorization (FR-001–FR-006) | T018–T024, T051–T059, T075–T077 |
| Customer numbers (FR-007–FR-008) | T010–T015, T023–T025 |
| Administration and atomic profile writes (FR-009–FR-012) | T023–T031 |
| Customer lifecycle and history (FR-013–FR-018) | T070–T074 |
| Multi-phone authority and migration compatibility (FR-019–FR-025) | T005–T011, T043–T050 |
| Groups and memberships (FR-026–FR-031) | T051–T061 |
| Search, filters, pagination, Arabic normalization (FR-032–FR-037) | T004, T006, T062–T069 |
| POS contract and order eligibility (FR-038–FR-044) | T032–T042 |
| Data preservation, coverage, verification (FR-045–FR-048) | T008–T011, T071, T078–T084 |
