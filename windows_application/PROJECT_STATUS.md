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

Current POS still consumes legacy Catalog/Menu endpoints. Published Snapshot → POS
consumption, local snapshot cache, offline synchronization, Inventory runtime,
stock deduction, and reservations are **NOT IMPLEMENTED**.

## Pre-Merge Hardening

1. Unsaved navigation guard: **COMPLETE**
2. Snapshot ordering contract: **COMPLETE**
3. Localization/UI cleanup: **COMPLETE**
4. Final merge verification: **PENDING**

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

## Next major integration

**Published Menu Snapshot / POS Consumption** — not implemented. This is the next
major integration after merge.
