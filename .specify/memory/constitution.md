<!--
Sync Impact Report
- Version change: template (unratified) -> 1.0.0
- Added principles:
  - I. Multi-Tenant Isolation
  - II. Backend-Enforced Authorization
  - III. Consistent Operational Branch Access
  - IV. One Authoritative Source per Domain
  - V. Historical Immutability
  - VI. Exact Financial and Quantity Semantics
  - VII. Internationalization
  - VIII. Timezone Correctness
  - IX. Stable API Contracts
  - X. Safe Database Evolution
  - XI. Lifecycle and History Preservation
  - XII. Legacy and Import Integrity
  - XIII. Clear Domain Boundaries
  - XIV. Platform and UX Consistency
  - XV. Real Production State
  - XVI. Scalable Collections
  - XVII. Testing and Regression
  - XVIII. Verification Before Completion
  - XIX. Scope Discipline
  - XX. Transactionality and Idempotency
  - XXI. Documentation Accuracy
- Added sections:
  - Brownfield Compatibility and Domain Contracts
  - Delivery Workflow and Quality Gates
- Updated dependent templates:
  - .specify/templates/plan-template.md: constitution gates made explicit
  - .specify/templates/spec-template.md: constitutional alignment made mandatory
  - .specify/templates/tasks-template.md: required test and verification work encoded
- Deferred follow-up: none
-->

# Cafe System 618 Constitution

## Core Principles

### I. Multi-Tenant Isolation (NON-NEGOTIABLE)

Every tenant-owned resource MUST be scoped to the authenticated tenant context at
every read, write, relationship lookup, validation, and background operation.
Authenticated tenant context is authoritative; a client-supplied tenant identifier
MUST NOT select another tenant or widen access. Cross-tenant identifiers and
relationships MUST fail safely without disclosing foreign data. Existing explicitly
documented compatibility routes that temporarily accept `X-Tenant-Id` are migration
constraints, not precedent: they MUST NOT be expanded, and authenticated routes MUST
derive tenant context from the token.

### II. Backend-Enforced Authorization (NON-NEGOTIABLE)

UI visibility, disabled controls, routes, and client-side role checks are usability
features, never authorization boundaries. The backend MUST authorize every sensitive
operation against the authenticated actor, tenant, permission, and applicable branch
scope. Platform Super Admin authentication, authorization, tokens, and RBAC MUST
remain a separate security domain from tenant users; neither domain may inherit or
impersonate the other's authority except through an explicitly specified, audited
mechanism.

### III. Consistent Operational Branch Access (NON-NEGOTIABLE)

Operational workflows MUST use the project's shared branch-access contract rather
than implement local branch eligibility rules. New operational actions MUST reject
inactive, deleted, foreign-tenant, or unauthorized branches. Owners and assigned
users receive only the access defined by that shared contract. Historical records
MUST retain and expose their original branch references where required even after a
branch is deactivated or archived; historical readability does not grant authority
for new activity.

### IV. One Authoritative Source per Domain (NON-NEGOTIABLE)

Each business rule MUST have one production authority. Inventory owns stock,
weighted-average cost (WAC), base units, quantities, and unit conversions. Menu owns
canonical recipe configuration and immutable published menu snapshots. Finance MUST
consume authoritative accounting and Inventory business events and MUST NOT infer or
recreate them independently. Other domains and clients MUST consume these services,
events, snapshots, and contracts rather than create parallel tables, calculations,
flags, payload builders, or business-rule implementations.

### V. Historical Immutability (NON-NEGOTIABLE)

Paid orders, their item and tax snapshots, published menu versions, inventory
movements, posted journals, completed payments and refunds, and comparable historical
business records MUST NOT be rebuilt or rewritten from current configuration.
Configuration changes govern future behavior only. A historical correction MUST use
an explicit, auditable correction, reversal, or replacement workflow that preserves
the original record and its causal chain.

### VI. Exact Financial and Quantity Semantics (NON-NEGOTIABLE)

Money, tax, inventory quantities, conversions, COGS, WAC, and allocations MUST use
deterministic decimal precision, explicit scale, and domain-defined rounding points;
binary floating-point MUST NOT determine persisted business values. Unsupported or
ambiguous conversions MUST fail validation rather than be guessed or silently
rounded. Tax collected for authorities is a liability, not revenue, and all reports,
journals, and totals MUST preserve that distinction.

### VII. Internationalization (NON-NEGOTIABLE)

Arabic and English are first-class supported languages. All user-facing strings MUST
be localizable through the established localization system; production UI MUST NOT
hard-code display text. Arabic MUST support RTL and English LTR, and layouts,
navigation, focus order, controls, icons with directional meaning, validation,
loading, error, and empty states MUST work in both directions. Localization may
translate presentation but MUST NOT alter identifiers, enum values, domain identity,
decimal meaning, currency meaning, or accounting semantics.

### VIII. Timezone Correctness (NON-NEGOTIABLE)

Time-sensitive rules MUST use the authoritative tenant or branch IANA timezone
specified by the owning domain. Persistence and transport MUST use timezone-aware
instants and explicit local-date/time interpretation where the business rule requires
it. Developer-machine local time, server-default timezones, and naive timestamps
MUST NOT determine schedules, discount eligibility, business dates, closings,
reporting periods, or similar domain behavior.

### IX. Stable API Contracts (NON-NEGOTIABLE)

The backend owns business validation, authorization, totals, eligibility, and state
transitions. Existing public response shapes, domain error codes, decimal-string
semantics, pagination behavior, and compatibility endpoints SHOULD be preserved when
practical. A breaking contract change MUST be explicitly specified and include
versioning, migration, or a time-bounded compatibility treatment. Flutter MUST use
the authoritative backend contract and MUST NOT compensate for an invalid or missing
backend rule with parallel business logic.

### X. Safe Database Evolution (NON-NEGOTIABLE)

Production and staging schema changes MUST be forward-only and preserve existing and
historical data. `migrate:fresh`, `db:wipe`, destructive reseeding, and equivalents
MUST NEVER run against non-testing data. Every schema change MUST analyze rollout
order, old/new application compatibility, backfill safety, constraints, locks,
rollback or roll-forward strategy, and the treatment of legacy rows. Destructive
replacement requires an explicit migration and archival plan, never an implicit
drop-and-recreate operation.

### XI. Lifecycle and History Preservation (NON-NEGOTIABLE)

Archive, deactivate, void, reverse, and delete are distinct lifecycle actions.
Archive/deactivate MUST NOT be implemented as destructive deletion. Entities
referenced by historical records MUST remain readable to authorized users wherever
the historical workflow requires them. Restore may reactivate future use but MUST
NOT rewrite snapshots, movements, journals, orders, or other historical records.

### XII. Legacy and Import Integrity (NON-NEGOTIABLE)

Legacy imports MUST be repeatable or idempotent, traceable to their source, and
auditable through reconciliation results. Large imports MUST support dry-run and
reconciliation before commit wherever practical. Raw source values MUST be retained
when normalization is uncertain, with transformations recorded explicitly. Entities
MUST NOT be automatically merged solely because names or phone numbers are similar;
ambiguous matches require deterministic evidence or reviewed resolution.

### XIII. Clear Domain Boundaries (NON-NEGOTIABLE)

A feature MUST remain within its specified domain and MUST NOT silently absorb
adjacent workflows. Refund is not Inventory Return; Customer Management is not
Loyalty; Authentication is not Shift; Menu unit display is not Inventory conversion
authority. Cross-domain behavior requires explicit specification of ownership,
contracts, events, failure handling, and regression impact before implementation.

### XIV. Platform and UX Consistency (NON-NEGOTIABLE)

Operational Flutter features MUST preserve Windows and Web support unless an
approved feature specification narrows the platforms. Work MUST reuse the existing
application shell, navigation, design system, dependency patterns, localization,
responsive behavior, and loading/error/empty-state conventions. Production features
MUST NOT introduce isolated replacement shells, divergent design systems, or
prototype-only interaction paths.

### XV. Real Production State (NON-NEGOTIABLE)

Production paths MUST use real authenticated backend state. Fake records, hard-coded
production identifiers, demo-state switches, seeded assumptions, and test or
authorization bypasses MUST NOT determine production behavior. UI state MUST reflect
authoritative loading, success, empty, validation, conflict, authorization, network,
and server outcomes rather than mask them with fabricated success.

### XVI. Scalable Collections (NON-NEGOTIABLE)

Potentially large collections MUST use bounded server responses with appropriate
server-side pagination, search, sorting, and filtering. Clients MUST NOT fetch an
unbounded tenant dataset merely to filter or paginate locally. Specifications MUST
define stable pagination and filter semantics, and implementations MUST preserve
tenant and authorization scoping before counting or returning results.

### XVII. Testing and Regression (NON-NEGOTIABLE)

New or changed business behavior MUST have focused automated coverage at the lowest
useful level plus integration coverage where contracts or domain boundaries change.
Security-sensitive work MUST cover tenant, permission, branch, lifecycle, and
cross-tenant failure cases as applicable. Financial, snapshot, inventory, import,
and retry behavior MUST cover exact values, rollback, immutability, and idempotent
replay as applicable. Tests MUST exercise production services and contracts; they
MUST NOT substitute hand-built equivalent payloads when doing so bypasses the
behavior under test.

### XVIII. Verification Before Completion (NON-NEGOTIABLE)

Relevant focused tests and static checks MUST complete successfully before work is
declared done. `git diff --check` is mandatory. Broader or full regression MUST run
at meaningful integration checkpoints and whenever risk crosses multiple domains.
A skipped, interrupted, timed-out, unavailable, or failing check MUST be reported
accurately and MUST NOT be described as passed. Verification evidence MUST identify
the commands run and any remaining unrelated failures.

### XIX. Scope Discipline (NON-NEGOTIABLE)

Feature work MUST contain only changes required by the approved specification and
its necessary tests, migrations, contracts, and documentation. Repository-wide
formatting, opportunistic refactoring, generated-file churn, and unrelated cleanup
MUST NOT be bundled into the work. Pre-existing unrelated changes or diagnostics
MUST be preserved and reported separately rather than silently modified or claimed
as part of the result.

### XX. Transactionality and Idempotency (NON-NEGOTIABLE)

Financial posting, payment and refund effects, inventory business-event posting,
provisioning, and imports MUST be transactionally safe across all state they own.
When clients, workers, deployments, or network failures can retry an operation, the
contract MUST define an idempotency identity, replay behavior, payload-conflict
behavior, and concurrency control. A failure MUST roll back partial owned effects;
a retry MUST NOT double-post money, stock, usage, or provisioning state.

### XXI. Documentation Accuracy (NON-NEGOTIABLE)

Documentation MUST describe current authoritative production behavior and clearly
label proposals, compatibility paths, deferred work, and historical reports as such.
Old phase labels, obsolete implementation notes, historical audit observations, and
past test counts MUST NOT be presented as current project status. Contract-changing
work MUST update its authoritative documentation in the same delivery scope.

## Brownfield Compatibility and Domain Contracts

- Existing production behavior, migrations, tests, and documented compatibility
  contracts are evidence. New specifications MUST identify the affected authority
  and reconcile conflicts rather than invent a competing rule.
- The current production Menu-to-sale path is canonical recipe configuration ->
  validated immutable published snapshot -> pinned Order -> Inventory consumption ->
  Finance posting. Live configuration MUST NOT replace pinned historical inputs.
- Inventory remains the authority for base-unit conversion, stock movements, WAC,
  and consumption cost. Finance records the resulting authoritative events; Menu and
  Flutter may display units but do not become conversion authorities.
- The published POS runtime contract and snapshot-aware order contract are public
  compatibility surfaces. Deprecated Catalog endpoints may be maintained for
  compatibility but MUST NOT become a second production POS authority.
- Tenant-user auth and Platform Super Admin auth remain separate. Transitional
  unauthenticated or header-based operational compatibility described by current
  documentation MUST be treated as migration debt: do not widen it, and specify the
  compatibility and rollout impact when replacing it.
- Shared services and established contracts for branch access, money, publishing,
  inventory posting, accounting posting, localization, navigation, and API errors
  MUST be reused unless an explicit specification approves their replacement.

## Delivery Workflow and Quality Gates

Every feature specification and plan MUST document the affected tenant, permission,
branch, domain-owner, history, precision, timezone, API, database, localization,
platform, collection-size, transaction, retry, and compatibility concerns. `N/A` is
acceptable only with a concrete reason.

Before implementation, the Constitution Check MUST confirm:

1. tenant isolation, backend authorization, Super Admin separation, and shared branch
   access are preserved;
2. one domain authority owns each changed rule and adjacent domains remain out of
   scope or have explicit contracts;
3. historical data, lifecycle behavior, imports, and database evolution are safe;
4. decimal, tax, conversion, timezone, transaction, concurrency, and idempotency
   semantics are explicit where applicable;
5. API compatibility, pagination, real-state UI, Arabic/English directionality, and
   Windows/Web behavior are addressed; and
6. focused tests, integration regression, static checks, `git diff --check`, and the
   appropriate broader regression checkpoint are planned.

During implementation, tests SHOULD be added alongside each behavior change so that
the failing and passing behavior is attributable. Database changes MUST be verified
on testing data only unless a separately authorized deployment procedure names the
exact non-testing environment and safe command. Reviewers MUST reject duplicated
business logic, unbounded collections, destructive migration paths, hidden test
bypasses, or claims unsupported by completed verification.

Before completion, the implementer MUST inspect the final diff for scope and secrets,
run the planned gates, record incomplete checks and pre-existing diagnostics, and
update only authoritative current documentation. No check may be waived silently.

## Governance

This constitution is the highest project-level engineering governance document for
Cafe System 618. Feature specifications, plans, tasks, reviews, and implementation
decisions MUST demonstrate compliance. When a lower-level document conflicts with
this constitution, the constitution governs unless an amendment is ratified.
Existing production behavior that appears inconsistent MUST be documented as
brownfield compatibility or remediation debt and changed only through an explicit,
tested migration; the constitution does not authorize an unsafe unilateral rewrite.

Amendments require: (1) a written rationale; (2) an impact review covering existing
contracts, data, security, tests, and dependent Spec Kit templates; (3) an explicit
version change; and (4) approval by the project owner or designated maintainers.
Semantic versioning applies to this document: MAJOR for removal or incompatible
redefinition of a principle, MINOR for a new principle or materially expanded
obligation, and PATCH for clarification that does not change the obligation.

Each constitutional amendment MUST update the Sync Impact Report, dependent Spec Kit
artifacts, version, and Last Amended date. Compliance is reviewed during specification,
planning, task generation, code review, and completion verification. Exceptions MUST
be explicit, narrowly scoped, risk-assessed, owner-approved, time-bounded where
possible, and recorded with remediation; convenience is not sufficient justification.

**Version**: 1.0.0 | **Ratified**: 2026-09-09 | **Last Amended**: 2026-09-09
