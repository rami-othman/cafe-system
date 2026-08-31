# CURRENT AUTHORITATIVE STATUS

Cafe System 618 has a Laravel backend in `backend` and a Flutter Windows client
in `windows_application`. Tenant isolation is backend-authoritative. The test
suite is guarded to use `cafe_system_618_testing`; authentication remains
intentionally deferred.

## Current delivery state

Menu Management Admin is **COMPLETE through Publish / Versions**:

- Batch 8 — Pricing & Availability: **COMPLETE**
- Batch 9 — Menus & Composition: **COMPLETE**
- Batch 10 — Assignments & Schedules: **COMPLETE**
- Batch 11 — Review & Publish: **COMPLETE**

The implemented flow covers Catalog, modifiers, recipes/material configuration,
menus/sections/placements, exact Branch + Sales Channel assignments and schedules,
validation, resolved preview, publishing, immutable version history, comparison,
and rollback.

Published Menu Snapshots are versioned immutable payloads. Schema v3 defines
published Menu order by the serialized `menus[]` sequence and zero-based
`scopeOrder`; automatic publication uses exact-scope active assignment order.
Catalog Menu priority is not a published runtime-order field and must not be used
to re-sort a snapshot. Explicit `menuIds` retain the established canonical Menu
order, not request order. Historical payloads remain immutable and rollback copies
the selected historical payload unchanged.

## Current POS boundary

- Phase 12A — Runtime Contract: **COMPLETE**
- Phase 12B — Backend POS Runtime Sync API: **COMPLETE**
- Phase 12C — Snapshot-Aware Order Contract (backend): **COMPLETE**
- Phase 12D — Flutter Runtime DTOs + Sync Repository + Scoped Cache: **COMPLETE**
- Phase 12E — Published Menu presentation cutover: **COMPLETE**
- Phase 12F — Offline / reconnect / pending-version behavior: **COMPLETE**
- Phase 12G — Legacy cutover + final regression: **COMPLETE**

**BATCH 12 — COMPLETE.** Production POS follows Published Runtime Contract v1
only: Menu Management -> Publish -> Immutable Published Version -> POS Runtime
Contract v1 -> `/pos/menu-sync` -> scoped Flutter cache -> Published POS UI ->
version-bound cart -> snapshot-aware Order. It never falls back to the live
Catalog when publication, network, or contract/cache validation fails.
The bounded runtime overlay keeps Sold Out and Temporarily Unavailable state
fresh without republishing; published schedules remain backend-resolved.

Offline menu and cart preparation are supported. True offline transaction or
payment processing is not implemented. The legacy Catalog Menu endpoints and the
no-version `POST /orders` branch are retained as deprecated compatibility paths
for non-POS consumers and existing historical workflows. They are not used by
the production Windows POS. Historical orders
with no published version remain readable, refundable, and receiptable. Future
authenticated barista/terminal assignment may restrict visible Branch choices;
current Branch / cart isolation remains authoritative.

## Batch 12 closure verification

On the exact closure worktree: backend focused tests passed (41 tests / 485
assertions), the full Laravel suite passed (138 tests / 1,891 assertions), and
Pint, Dart format, and `git diff --check` passed. Manual Windows verification
passed: `flutter gen-l10n`, `flutter analyze`, `flutter test` (487 passed), and
`flutter build windows`. The built executable launched successfully and rendered
the Published POS screen.

## Pre-Auth hardening

### Pre-Auth Hardening A ✅ CLOSED

- `OrderLifecyclePolicy` permits normal mutation only for unpaid Draft/Held
  orders; completed and refunded orders are immutable.
- Payment and refunds use database locks, tenant/order-scoped idempotency keys,
  unique constraints, and durable locked number counters.
- Flutter supplies one key per payment/refund attempt; offline payments remain
  blocked.
- True PostgreSQL process-concurrency coverage passed for payment/refund
  idempotency and order/refund number contention.

### Pre-Auth Hardening B ✅ CLOSED

- Mutable admin feature Cubits are lazy and route-scoped; POS startup no
  longer creates Orders, Discounts, Reports, or Menu Management state.
- `PosCubit` remains the session POS workspace so cart and branch context
  survive a temporary route change. Its branch safety rule remains unchanged.
- Orders and Reports follow that authoritative branch only while their route is
  mounted; report requests pass the supported `branchId` contract.
- Router topology tests assert that POS does not request unvisited feature
  repositories and that Orders, Reports, and Discounts initialize independently.

### Pre-Auth Hardening C ✅ CLOSED

- `DiscountEligibilityService` is the authoritative runtime policy for managed
  discounts, including Branch-local date/day/time and overnight windows.
- Product/category targeting uses persisted immutable category identity for
  versioned Orders; legacy Orders retain their live-Catalog compatibility path.
- Payment-time revalidation covers tender restrictions and current policy state.
  Discount usage is consumed only by a successful payment with locked global and
  per-customer checks, and payment retries cannot double-consume it.
- Full Laravel verification passed: 149 tests / 1,985 assertions; Pint and
  `git diff --check` passed; `cafe_system_618_testing` migration rebuild and
  seed completed successfully. No Flutter files changed for Hardening C.

### Pre-Auth Hardening D ✅ CLOSED

- Publication now acquires its exact tenant + Branch + channel advisory lock
  before it starts the repeatable-read critical section. Candidate resolution,
  blocking validation, snapshot construction, checksum/no-change selection,
  version writes, and publication audit all use that one authoritative state.
- PostgreSQL worker coverage verifies same-scope serialization, no-change
  contention, cross-scope independence, and an independent-connection edit
  between validation and snapshot construction.
- Flutter has a small typed API error foundation for unavailable network,
  unauthenticated, forbidden, validation, conflict, server, and unknown paths.
  Safe generic EN/AR copy is available; useful 422 domain messages and stable
  backend codes are retained. POS cached-menu offline behavior remains distinct.

Closure verification passed locally: Laravel 152 tests / 2,003 assertions,
Flutter 496 tests, `flutter analyze`, and the Windows build all completed.

**PRE-AUTH HARDENING COMPLETE.**

## Pre-Auth handoff

Auth has not started. Platform Super Admin authentication/permissions already
exist as a separate security domain; upcoming tenant employee Auth/RBAC must not
be conflated with it.

The next phase is Tenant Employee Authentication, Roles, Permissions, Branch
Assignment, server-side authorization, actor identity/audit attribution, and
Flutter permission-aware navigation. It is not implemented by this baseline.

The hardening sequence is:

1. **Pre-Auth Hardening A** — Order lifecycle + payment/refund concurrency/idempotency
2. **Pre-Auth Hardening B** — Flutter route-scoped Cubits / shared app context cleanup
3. **Pre-Auth Hardening C** — Discount runtime correctness
4. **Pre-Auth Hardening D** — Publish validation race + docs/error hygiene
5. **Auth + Employee Roles + Permissions + Branch Assignment**

Hardening items 1–4 are closed; only the final tenant employee-auth handoff is
future work and it is not part of Batch 12.

## Important architecture notes

- Products, Variants, Modifier Groups, Modifier Options, and Menu Sections use
  Active / Inactive / Archived lifecycle semantics; archive takes precedence.
- Variant base recipes and Modifier Option material adjustments are configuration,
  not Inventory runtime. Exact decimal quantities and canonical units are
  authoritative.
- Published snapshots exclude operational availability state, remaining quantities,
  and Inventory runtime data. Rollback creates a new Version rather than
  reactivating historical data.
- The Flutter Windows app uses feature-based Cubit architecture. The Product
  Workspace remains the canonical Product parent.
- Phase 4K architecture cleanup and broader localization migration remain deferred.

## Batch 12 status

- 12A ✅ Runtime Contract
- 12B ✅ Backend POS Runtime Sync API
- 12C ✅ Snapshot-Aware Order Contract
- 12D ✅ Flutter Sync / Scoped Cache
- 12E ✅ Published POS UI Cutover
- 12F ✅ Offline / Reconnect / Pending Version
- 12G ✅ Legacy Cutover / Final Regression

**BATCH 12 — COMPLETE**
