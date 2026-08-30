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

## Pre-Auth handoff

The approved next sequence is:

1. **Pre-Auth Hardening A** — Order lifecycle + payment/refund concurrency/idempotency
2. **Pre-Auth Hardening B** — Flutter route-scoped Cubits / shared app context cleanup
3. **Pre-Auth Hardening C** — Discount runtime correctness
4. **Pre-Auth Hardening D** — Publish validation race + docs/error hygiene
5. **Auth + Employee Roles + Permissions + Branch Assignment**

These phases are approved handoff work only and are not part of Batch 12.

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
