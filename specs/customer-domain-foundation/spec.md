# Feature Specification: Phase 1 — Customer Domain Foundation

**Feature Branch**: `customer-domain-foundation`

**Created**: 2026-09-09

**Status**: Draft

**Input**: User description: "Read `plans/customer_management_plan.md` and create a specification for Phase 1 — Customer Domain Foundation."

## Overview

Phase 1 establishes the authoritative tenant-owned Customer Management backend while preserving the customer contract already used by the POS and Orders domains. It adds safe customer administration, lifecycle management, multiple phones, customer groups, scalable administrative search, and a single operational-eligibility rule for attaching customers to new orders.

This phase is backend-only. It does not build the Flutter Customer Management screens, POS quick-create UI, customer history or metrics, customer-group discounts, legacy import, loyalty changes, tier redesign, or historical customer snapshots.

## Clarifications

### Session 2026-09-09

- Q: Who should be allowed to perform Phase 1 customer and customer-group administration? → A: Owners have full Customer and Customer Group administration; managers require Customer Management permission for full administration; employees are limited to customer search/select, quick-create, and membership assignment or removal for existing groups, with no group administration, customer lifecycle, or full administration access.
- Q: How should Phase 1 generate customer-facing customer numbers? → A: Use a backend-generated, tenant-scoped sequence formatted like `C-000001`; customer numbers are immutable and never reused.
- Q: How should the legacy `customers.phone` column coexist with the new multi-phone records? → A: Backfill each existing legacy phone as the primary phone, make the multi-phone collection authoritative, and transactionally mirror its primary raw value into `customers.phone` for compatibility.
- Q: What fields may an employee submit when quick-creating a customer? → A: Employee quick-create requires a name and exactly one phone number.
- Q: How should Phase 1 handle a non-blank phone number that cannot be confirmed as valid? → A: Accept non-blank values within length limits, preserve the raw input, and classify each as `valid`, `invalid`, or `unverified`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Manage Tenant Customers Safely (Priority: P1)

An authorized tenant administrator (an owner or a manager with Customer Management permission) creates, views, and updates customer records without exposing or changing another tenant's data. A customer can be created without a phone and receives a stable tenant-scoped customer number.

**Why this priority**: Customer identity, tenant isolation, and safe administration are the foundation for every later Customer Management and POS workflow.

**Independent Test**: Authenticate as an authorized administrator, create a customer with only a name, retrieve and update it, and verify that another tenant cannot discover or mutate it by identifier.

**Acceptance Scenarios**:

1. **Given** an authorized tenant administrator and a valid customer name, **When** the administrator creates a customer without a phone, **Then** an active customer is created for that tenant with a non-empty customer number and no phone.
2. **Given** an existing customer in the authenticated tenant, **When** an authorized administrator updates editable profile fields, **Then** the updated customer is returned and its identity, tenant, and customer number remain unchanged.
3. **Given** a customer or group belonging to another tenant, **When** an actor attempts to read, update, assign, or change its lifecycle, **Then** the request fails without revealing the foreign record's data.
4. **Given** an authenticated actor without full Customer Management administration authority, **When** the actor attempts a customer or group administration operation outside their explicitly permitted operational actions, **Then** the operation is denied even if the client displays an administrative control.

---

### User Story 2 - Preserve POS Lookup and Enforce Order Eligibility (Priority: P1)

An authenticated POS user can continue using the existing customer lookup contract, while every new order attachment is checked by the backend against the same authoritative eligibility rule.

**Why this priority**: Phase 1 must not disrupt current sales, and client-side filtering cannot protect order integrity.

**Independent Test**: Call the existing customer lookup without administrative parameters, compare its response with the legacy contract, then attempt to attach active, inactive, archived, foreign-tenant, and null customers to new or mutable orders.

**Acceptance Scenarios**:

1. **Given** active, inactive, and archived customers in one tenant, **When** the existing `GET /api/v1/customers` request is made without administrative parameters, **Then** only active, non-archived customers are returned in the existing `{data: [...]}` envelope, ordered by name and limited to 30.
2. **Given** a customer returned by operational lookup, **When** that customer is attached to a new or mutable order in the same tenant, **Then** the backend accepts the customer relationship.
3. **Given** an inactive, archived, deleted, or foreign-tenant customer, **When** its identifier is submitted for a new operational order attachment, **Then** the backend rejects the attachment with a stable validation error and does not change the order.
4. **Given** an order workflow where a customer is optional, **When** the customer identifier is omitted or explicitly cleared, **Then** the backend accepts the anonymous walk-in order behavior.
5. **Given** an employee with operational customer access, **When** the employee quick-creates a customer with a non-blank name and exactly one non-blank phone within length limits, **Then** an Active customer is created with that phone as primary, its validation status recorded, and a generated customer number.
6. **Given** an employee quick-create request with no phone, multiple phones, or full-profile, lifecycle, or group-administration fields, **When** it is submitted, **Then** the request is rejected without creating a partial customer.

---

### User Story 3 - Maintain Multiple Customer Phones (Priority: P2)

An authorized tenant administrator records zero, one, or multiple phone numbers for a customer, identifies one primary phone when phones exist, and can find the customer using either raw or normalized phone input.

**Why this priority**: Multiple and shared phone numbers are required domain behavior, but depend on the core customer identity and compatibility contract.

**Independent Test**: Create customers with no phone, one phone, multiple phones, and a phone shared by two customers; change the primary phone and verify search and the legacy `phone` field.

**Acceptance Scenarios**:

1. **Given** valid customer data with multiple phones, **When** exactly one phone is designated primary, **Then** all raw values are preserved and the primary raw number is exposed through the legacy customer `phone` field.
2. **Given** two customers in the same or different tenants, **When** they are assigned the same raw or normalized phone number, **Then** both records are accepted without being merged.
3. **Given** a customer with phones, **When** the primary phone is removed or another phone is made primary, **Then** exactly one remaining phone is primary and the legacy `phone` field changes atomically with it.
4. **Given** a customer whose last phone is removed, **When** the update succeeds, **Then** the customer has no phone records and the legacy `phone` field is null.
5. **Given** a formatted phone search value, **When** it normalizes to a stored phone's normalized value, **Then** the matching same-tenant customer is returned.

---

### User Story 4 - Organize Customers in Groups (Priority: P2)

An authorized tenant administrator creates and updates tenant customer groups. An owner, permitted manager, or employee may assign a customer to zero or more existing active groups without allowing cross-tenant relationships; this membership authority does not grant Customer Group administration.

**Why this priority**: Groups support administration and later discount targeting while remaining distinct from existing customer tiers.

**Independent Test**: Create two groups, assign both to one customer, remove one, archive and restore a group, and attempt a cross-tenant assignment.

**Acceptance Scenarios**:

1. **Given** active groups in the same tenant as a customer, **When** an owner, permitted manager, or employee submits group membership changes, **Then** the complete requested membership set is stored atomically.
2. **Given** a group from another tenant, **When** it is included in a customer's membership request, **Then** the entire request is rejected and existing memberships remain unchanged.
3. **Given** an archived group, **When** an administrator attempts a new assignment to that group, **Then** the assignment is rejected while pre-existing membership history remains intact.
4. **Given** existing customer tier values and tier-based discount rules, **When** customer groups are created or assigned, **Then** tiers and tier-based discount behavior are unchanged.

---

### User Story 5 - Search and Filter the Administrative Collection (Priority: P2)

An authorized tenant administrator searches a potentially large customer collection by customer number, name, Arabic-normalized name, phone, or email and narrows results by lifecycle state or group.

**Why this priority**: Administration must remain usable at production scale and must not require loading an entire tenant's customer set.

**Independent Test**: Seed more than one page of same-tenant customers with different states and groups, then verify search, filters, ordering, pagination metadata, and isolation from another tenant.

**Acceptance Scenarios**:

1. **Given** more customers than the administrative page size, **When** a page is requested, **Then** the response is bounded, deterministically ordered, and includes sufficient metadata to request other pages.
2. **Given** customers in active, inactive, and archived states, **When** each status filter and the all-status filter is requested, **Then** only the requested same-tenant states are returned and archived customers remain excluded by default.
3. **Given** a customer in multiple groups, **When** one of those groups is used as a filter, **Then** the customer appears once in the result set.
4. **Given** Arabic names that differ only by supported normalization variants, **When** the normalized search form is submitted, **Then** matching same-tenant customers are returned.

---

### User Story 6 - Change Lifecycle Without Losing History (Priority: P2)

An authorized tenant administrator deactivates, activates, archives, or restores a customer without hard-deleting identity or breaking historical order references.

**Why this priority**: Customer records must leave operational use safely while remaining available to historical workflows.

**Independent Test**: Attach an active customer to an order, move the customer through each permitted lifecycle transition, and verify operational eligibility, list visibility, restoration behavior, and the unchanged historical relationship.

**Acceptance Scenarios**:

1. **Given** an active customer, **When** the customer is deactivated, **Then** the customer becomes inactive, remains administratively retrievable, and is no longer operationally eligible.
2. **Given** an active or inactive customer with historical orders, **When** the customer is archived, **Then** it is hidden from default operational and administrative lists while its historical order references remain readable.
3. **Given** an archived customer, **When** the customer is restored, **Then** it returns as inactive and requires an explicit activation before operational use.
4. **Given** a lifecycle request already applied to the target state, **When** the same request is retried, **Then** it succeeds without creating duplicate effects.
5. **Given** an invalid lifecycle transition such as activating an archived customer before restore, **When** it is requested, **Then** the request is rejected and the current state remains unchanged.

### Edge Cases

- Concurrent customer creation MUST not issue the same customer number twice within a tenant.
- Customer numbers MAY repeat across different tenants, but MUST be unique and immutable within one tenant and MUST NOT be reused after archival.
- Empty, whitespace-only, or over-limit names MUST fail validation without partial phone or group writes.
- A phone collection with no primary, or with more than one primary, MUST fail when at least one phone exists.
- An employee quick-create request MUST fail if the name or single required phone is absent, or if more than one phone is submitted.
- Raw phone values that cannot be confirmed as valid MUST be retained when non-blank and within length limits, classified as `invalid` or `unverified` as applicable, and MUST NOT be treated as a unique identity or trigger an automatic merge.
- Reordering phones without changing which phone is primary MUST not change the legacy `phone` value.
- Duplicate phone rows within one customer's submitted collection MUST be rejected as an ambiguous duplicate even though the same number may belong to different customers.
- Search input containing phone punctuation or spacing MUST use the same normalization rules as stored phones.
- Name normalization MUST ignore Arabic diacritics and tatweel and normalize supported Alef variants consistently in both stored search data and queries, without changing the displayed raw name.
- An archived customer or group requested directly by identifier MUST remain available only to an authorized administrative or historical context, never through operational lookup.
- Archiving a group MUST retain existing memberships, exclude it from default group lists, and prevent new membership assignment until restored.
- If any customer profile, phone, or membership validation fails, no part of that create or update operation may persist.
- The forward-only phone backfill MUST create exactly one primary phone for each existing customer with a non-null legacy `phone` and no phone records, while preserving the raw legacy value and deriving its normalized value and validation status.
- Existing customers with only the legacy `phone` value MUST remain searchable and serializable during migration to the multi-phone structure, including while the backfill is incomplete.
- Changing a customer's current name or primary phone continues to affect live historical display because immutable order snapshots are outside this phase.

## Requirements *(mandatory)*

### Functional Requirements

#### Ownership, Identity, and Authorization

- **FR-001**: Every customer, customer phone, customer group, and group membership MUST be owned by exactly one tenant, and the authenticated tenant context MUST scope every read, count, search, validation, mutation, and relationship lookup.
- **FR-002**: Client-supplied tenant identifiers MUST NOT select or widen tenant scope.
- **FR-003**: Foreign-tenant identifiers MUST be rejected without revealing whether the foreign resource exists.
- **FR-004**: The backend MUST authorize Customer administration, Customer Group administration, Customer Group membership changes, and operational customer actions as distinct capabilities through the existing tenant-user authorization domain; client-side visibility MUST NOT grant authority.
- **FR-005**: Tenant owners MUST have full Customer and Customer Group administration authority. Managers MUST have the same full authority only when granted Customer Management permission through the project's existing permission architecture.
- **FR-006**: Employees MUST be allowed to search and select operationally eligible customers, quick-create customers, and assign or remove customers to or from existing active same-tenant groups. Employee quick-create MUST accept only a required non-blank name and exactly one required phone, create the customer as Active with that phone as primary, and generate the customer number. Employees MUST NOT create, edit, archive, or restore Customer Groups; archive or restore customers; edit full customer profiles; or access the full Customer Management administration collection.
- **FR-007**: Each newly created customer MUST receive the next backend-generated tenant-scoped sequence formatted as `C-` followed by a minimum of six zero-padded decimal digits (for example, `C-000001`). The number MUST be unique within the tenant, immutable for the customer's lifetime, safe under concurrent creation, monotonically increasing, and never reused after archival.
- **FR-008**: A normal manual customer create request MUST NOT use a caller-provided customer number as authoritative. Future imported legacy customer numbers MUST be represented separately and MUST NOT replace or alter the Phase 1 customer number.

#### Customer Administration and Lifecycle

- **FR-009**: Authorized administrators MUST be able to create, retrieve, and update customers using repository-conventional routes equivalent to `POST /api/v1/customers`, `GET /api/v1/customers/{customer}`, and `PUT /api/v1/customers/{customer}`.
- **FR-010**: A manually created customer MUST require a non-blank name and MAY include email, birth date, notes, phones, and group memberships.
- **FR-011**: New customers MUST start active unless an authorized administrative create contract explicitly requests inactive state.
- **FR-012**: Customer create and update MUST validate and persist the profile, phones, primary-phone compatibility value, and group memberships atomically.
- **FR-013**: The customer lifecycle MUST support Active, Inactive, and Archived states with actions equivalent to activate, deactivate, archive, and restore; normal Customer Management MUST expose no hard-delete action.
- **FR-014**: Permitted lifecycle transitions MUST be Active to Inactive, Inactive to Active, Active to Archived, Inactive to Archived, and Archived to Inactive through restore.
- **FR-015**: A repeated request that already matches its lifecycle target MUST be idempotent; any other unsupported transition MUST fail without changing state.
- **FR-016**: Archived customers MUST be excluded from operational lookup and default administrative lists but remain retrievable in authorized administrative and historical contexts.
- **FR-017**: Deactivation, archival, restoration, or profile editing MUST NOT remove or rewrite an existing order-to-customer relationship.
- **FR-018**: Historical order/customer display MUST continue resolving the current live customer name and primary/legacy phone; immutable order customer snapshots MUST NOT be introduced in this phase.

#### Phones and Backward Compatibility

- **FR-019**: A customer MUST support zero, one, or multiple phone records, each retaining its raw entered number, searchable normalized number when derivable, type, primary designation, and one validation status from `valid`, `invalid`, or `unverified`.
- **FR-020**: Phone numbers MUST NOT be globally or tenant-uniquely constrained, and shared or duplicate numbers across customers MUST NOT cause automatic customer merging.
- **FR-021**: When a customer has phones, exactly one MUST be primary. When a customer has no phones, none may be primary.
- **FR-022**: Within one customer's submitted phone collection, the same normalized non-empty number MUST NOT appear more than once.
- **FR-023**: The multi-phone collection MUST be the authoritative phone source after backfill. The existing customer `phone` compatibility value MUST mirror the primary phone's raw value, MUST become null when no phones remain, and MUST change in the same atomic operation as the authoritative phone collection.
- **FR-024**: A forward-only backfill MUST create exactly one primary phone record for every existing customer that has a non-null legacy `phone` and no phone records. It MUST preserve the legacy value as `raw_number`, derive the normalized value and validation status using the production rules, avoid duplicate phone records if safely retried, and leave `customers.phone` intact.
- **FR-025**: During rollout and any incomplete backfill, customers that have a legacy `phone` value but no phone record MUST continue to expose that value and match phone searches. Phone normalization MUST be deterministic and applied identically to backfilled records, new records, updates, and search queries while preserving every raw value. A non-blank phone within configured length limits MUST be accepted even when validity cannot be confirmed and MUST be classified as `invalid` or `unverified` rather than rejected solely for its format.

#### Customer Groups

- **FR-026**: Tenant owners and managers with Customer Management permission MUST be able to list, create, retrieve, update, archive, and restore tenant-owned customer groups using repository-conventional Customer Group routes; membership authority alone MUST NOT authorize these operations.
- **FR-027**: A customer MAY belong to zero or more customer groups. Owners, managers with Customer Management permission, and employees MAY assign or remove memberships for existing active same-tenant groups, and membership replacement MUST be atomic and free of duplicate memberships.
- **FR-028**: Only active, non-archived groups from the customer's tenant MAY receive new memberships.
- **FR-029**: Group archival MUST preserve existing memberships, exclude the group from default group and customer-group filters, and prevent new assignments until restoration.
- **FR-030**: Restoring an archived group MUST make it active without changing its retained memberships.
- **FR-031**: Customer groups MUST remain distinct from the existing New, Regular, and VIP customer tiers and MUST NOT alter tier calculation, tier labels, or tier-based discount eligibility.

#### Phase 2 Administrative Group Contract

The following additive JSON contract is frozen for the Phase 2 Flutter client. All
routes derive tenant and actor solely from the bearer token, use the existing
Customer-management authorization boundary, return camelCase JSON, and return 404
without foreign-record detail when a same-tenant resource cannot be found. They do
not accept `X-Tenant-Id` or an unbounded complete membership set.

- `GET /api/v1/customer-management/capabilities` returns
  `{data:{customer:{manage:boolean}}}` for the authenticated tenant user. It is
  true only for an owner or a manager granted `customer.manage`; employee,
  ungranted manager, invalid tenant actor, and Platform Super Admin return false or
  remain outside this tenant-user endpoint. The owner-only role-permission
  configuration endpoint is not a substitute.
- `GET /api/v1/admin/customer-management/customer-groups` accepts optional
  `search`, `status=active|archived|all`, `page`, and `perPage`. It applies tenant,
  authorization, status, and normalized-name search before counts/pagination; orders
  by `normalized_name`, then `id`; defaults/caps `perPage` at 30/100; and returns
  `{data:[{id,name,status,isActive,memberCount,createdAt,updatedAt}],meta:{currentPage,lastPage,perPage,total}}`.
- `GET /api/v1/admin/customer-management/customer-groups/{group}/members` accepts
  `search`, `page`, and `perPage` and returns the same bounded metadata envelope.
  It is an administration-only query, includes retained members of an archived
  group, orders by normalized customer name then ID, and projects each member using
  the existing administrative customer resource.
- `GET /api/v1/admin/customer-management/customer-groups/{group}/eligible-members`
  accepts `search`, `page`, and `perPage` and returns the same bounded envelope.
  It requires an active group, excludes existing members and non-active/archived
  customers before pagination, uses tenant-safe normalized customer search/order,
  and projects the existing administrative customer resource.
- `POST /api/v1/admin/customer-management/customer-groups/{group}/members` accepts
  `{customerIds:[positive-integer,...]}` with distinct IDs. It is one atomic,
  locked command: all IDs must be same-tenant, active, non-archived, and not already
  a member; otherwise it changes nothing. A replay/duplicate membership is a stable
  validation or conflict response, not a silent partial success. On success it
  returns the authoritative group resource including refreshed `memberCount`.
- `DELETE /api/v1/admin/customer-management/customer-groups/{group}/members/{customer}`
  removes exactly that same-tenant membership under a lock. A missing/foreign group,
  customer, or membership is a safe 404; success returns the authoritative group
  resource including refreshed `memberCount`. Neither command archives, restores,
  or deletes a customer or group, and unrelated memberships remain unchanged.

#### Search, Filtering, and Pagination

- **FR-032**: The administrative customer collection MUST support server-side search by exact or partial customer number, displayed name, normalized Arabic name, raw phone, normalized phone, and email.
- **FR-033**: The administrative collection MUST support Active, Inactive, Archived, and All lifecycle filters plus an active same-tenant customer-group filter.
- **FR-034**: Archived customers MUST be excluded when no administrative status filter is supplied.
- **FR-035**: Administrative collection responses MUST be bounded and paginated, default to 30 records per page, reject or cap sizes above 100, include page/total metadata, and use deterministic ordering with a unique tie-breaker.
- **FR-036**: Search, filters, authorization, and tenant scope MUST be applied before totals and page results are calculated, and joins MUST NOT duplicate a customer in results.
- **FR-037**: Name normalization MUST preserve the displayed name and use consistent query-time and stored-value rules that at minimum ignore Arabic diacritics and tatweel and normalize supported Alef variants.

#### Operational Contract and Eligibility

- **FR-038**: `GET /api/v1/customers` without administrative parameters MUST preserve the current operational contract: authenticated tenant scope; active, non-archived customers only; optional name/phone search; name ordering; maximum 30 results; and a `{data: [...]}` response.
- **FR-039**: Every operational customer item MUST continue providing `id`, `name`, `phone`, `email`, `totalSpent`, `visitsCount`, `loyaltyPoints`, and `tier` with meanings and types compatible with the current POS consumer. Additive fields MUST NOT be required by existing clients.
- **FR-040**: The operational search MAY additionally match customer number and normalized name/phone, provided its existing name/phone behavior and response compatibility remain intact.
- **FR-041**: One authoritative backend eligibility rule MUST determine whether a customer can be newly attached to an order: the customer belongs to the authenticated tenant, is active, and is not archived or deleted.
- **FR-042**: Order create and mutable-order customer update MUST enforce FR-041 and MUST allow a null customer wherever the existing order contract permits walk-in customers.
- **FR-043**: Operational lookup and order attachment MUST use the same eligibility rule so that a customer excluded as ineligible cannot be attached by submitting an identifier directly.
- **FR-044**: Rejecting an ineligible customer MUST leave the order and all related state unchanged and return a stable machine-readable validation error.

#### Data Preservation and Verification

- **FR-045**: Schema and data evolution MUST preserve all existing customer rows and the legacy `phone`, `email`, `birth_date`, `notes`, `total_spent`, `visits_count`, active-state, timestamps, and archive/soft-delete information.
- **FR-046**: Stored `total_spent` and `visits_count` MUST remain available for current POS and tier compatibility but MUST NOT be redefined as authoritative analytics by this phase.
- **FR-047**: Phase 1 MUST include automated coverage for customer creation with zero/one/multiple phones, duplicate/shared phones, all phone validation statuses, primary-phone compatibility, search, pagination, filters, group assignment, cross-tenant rejection, lifecycle transitions, tenant isolation, operational lookup compatibility, employee quick-create and membership permissions, operational eligibility, and anonymous orders.
- **FR-048**: Phase 1 verification MUST include focused backend tests, relevant POS/customer compatibility tests, a full backend regression checkpoint, and a clean whitespace/error check of the final diff. Any skipped, timed-out, or failing check MUST be reported as such.

### Key Entities *(include if feature involves data)*

- **Customer**: Tenant-owned customer identity with an internal identifier, immutable `C-000001`-style tenant sequence number, displayed and normalized names, optional contact/profile data, Active/Inactive/Archived lifecycle, legacy primary-phone compatibility value, and preserved legacy tier metric fields.
- **Customer Phone**: Authoritative tenant-owned phone entry belonging to one customer; stores raw and normalized values, type, validation status, and whether it is the customer's sole primary phone. It is searchable contact data, not customer identity; `customers.phone` remains a synchronized compatibility mirror of its primary raw value.
- **Customer Group**: Tenant-owned optional classification with a name and active/archive lifecycle. It is administratively managed and is explicitly separate from legacy customer tiers.
- **Customer Group Membership**: Same-tenant many-to-many relationship between a customer and a group. It carries no tier or discount meaning in this phase.
- **Operational Customer Eligibility**: Backend-owned domain rule consumed by customer lookup and order attachment to determine whether an existing customer may be used for a new operational action.
- **Order Customer Relationship**: Existing nullable relationship from an order to a customer. Phase 1 validates new attachments but preserves existing historical relationships and live-profile display behavior.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All automated cross-tenant read, mutation, membership, search, count, lifecycle, and order-attachment scenarios return no foreign customer or group data and persist no cross-tenant relationship.
- **SC-002**: 100% of the defined Active/Inactive/Archived transition matrix produces the specified target state or deterministic rejection, and repeated target-state requests create no duplicate effects.
- **SC-003**: Customers created, updated, or backfilled with zero, one, or multiple phones always finish with either zero primary phones when none exist or exactly one primary phone when any exist; the legacy `phone` value matches in every tested mutation, and a safely repeated backfill creates no duplicate phone records.
- **SC-004**: Existing POS customer contract tests pass unchanged for response envelope and required fields, and default lookup returns no inactive or archived customer.
- **SC-005**: Every tested direct order attachment of an inactive, archived, deleted, or foreign-tenant customer is rejected, while active same-tenant and null-customer cases retain their expected behavior.
- **SC-006**: Administrative searches return correct same-tenant matches for customer number, displayed/normalized Arabic name, raw/normalized phone, and email across more than one page of test data.
- **SC-007**: Administrative list responses never exceed 100 customer records, report totals after tenant and filter constraints, and return each matching customer at most once.
- **SC-008**: Archiving and restoring customers or groups preserves all tested historical order references and group memberships; no normal hard-delete endpoint is available.
- **SC-009**: The focused Phase 1 suite, relevant POS/customer compatibility tests, and the full backend regression checkpoint complete successfully, and `git diff --check` reports no errors before the phase is declared complete.

## Assumptions

- The existing authenticated tenant-user system and permission architecture will be extended narrowly for Customer Management; this phase will not introduce a replacement RBAC subsystem.
- Customer and Customer Group administration, Customer Group membership changes, and operational customer actions are separate authorization capabilities. Owners have full administration; managers require Customer Management permission; employees receive only the limited operational and membership actions stated in FR-006.
- Employee quick-create requires a non-blank name and exactly one phone, produces an Active customer with that phone as primary, and does not accept full-profile, lifecycle, or Customer Group administration fields.
- Restoring an archived customer returns it to Inactive as the safest non-operational state; activation is a separate explicit action.
- Restoring an archived customer group returns it to Active because group restoration does not itself make a customer operationally eligible.
- Customer numbers use a backend-generated `C-` prefix with a minimum six-digit tenant sequence, are immutable, and are not accepted as caller-selected identity during normal manual creation. Future legacy identifiers remain a separate import concern.
- Administrative pagination may use additional query parameters or a dedicated administrative endpoint. The implementation plan will select the repository-conventional shape without changing the no-parameter operational contract.
- Email, birth date, and notes remain optional and retain the repository's established validation limits unless the implementation plan identifies a current unsafe or inconsistent limit requiring explicit revision.
- Lifecycle timestamps or audit fields may be added during planning if needed for deterministic archive/restore behavior, but existing data and historical references must be preserved.
- Existing non-null `customers.phone` values will be backfilled into authoritative primary phone records through a forward-only, safely repeatable data migration; the legacy column remains a synchronized compatibility mirror throughout V1.
- Phone format uncertainty does not block capture: any non-blank value within the established maximum length is retained and classified as `valid`, `invalid`, or `unverified`; blank or over-limit values remain validation errors.
- Legacy customer import, automatic deduplication, customer merge, immutable order customer snapshots, new analytics, group-targeted discounts, and all Flutter work are deferred to separate phases or specifications.

## Constitutional Alignment *(mandatory)*

- **Tenant, authorization, and branch access**: Customers, phones, groups, and memberships are tenant-owned and tenant-wide, never branch-owned. Backend authorization separates administrative access from operational POS lookup. Customer eligibility has no branch ownership rule; order branch authorization remains owned by the existing Orders/shared branch-access contract.
- **Domain authority and boundaries**: Customer Management owns customer identity, contact data, group membership, lifecycle, search, and customer operational eligibility. Orders owns order mutability and the nullable order relationship; Discounts retains existing tier rules. Loyalty, analytics, import, Flutter UI, snapshots, and group discount targeting are excluded.
- **History, lifecycle, and data evolution**: Active, Inactive, and Archived are non-destructive states. Restore is deterministic, historical order references remain intact, live-profile historical display is preserved, and forward-only evolution retains all legacy customer columns and rows.
- **Exact semantics and time**: This phase introduces no money calculations, tax treatment, quantities, schedules, or local-time business rules. Existing decimal legacy metric fields remain untouched and are not made analytically authoritative. Any lifecycle audit timestamps use the repository's timezone-aware persistence conventions and do not control eligibility beyond the explicit state.
- **API, state, and scale**: Backend validation owns lifecycle, tenant membership, phone-primary invariants, and eligibility. The current POS response remains compatible. Administrative collections use server-side search, filters, stable bounded pagination, and real authorization/error outcomes.
- **Localization and platforms**: No Flutter UI is delivered in Phase 1. Backend search treats Arabic and English names as first-class input and preserves raw display values. Phase 2 remains responsible for localized strings, RTL/LTR presentation, and Windows/Web UI behavior.
- **Transactions, retries, and verification**: Aggregate writes are atomic, lifecycle target-state retries are idempotent, customer-number generation is concurrency-safe, and rejected eligibility or relationship changes leave no partial state. Focused domain/security/compatibility coverage plus a full backend checkpoint and `git diff --check` are required.
