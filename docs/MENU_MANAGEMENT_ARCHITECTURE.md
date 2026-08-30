# Menu Management Architecture

## Current authoritative status

Menu Management is implemented end-to-end for catalog administration, Modifier
Library, recipes/material configuration, menu composition, assignments/schedules,
validation/preview/publishing, and version history. UX-G0, Batch 7-P, Navigation
& Flow Stabilization, and Batch 7.1 are **COMPLETE**. Batch 7 — Recipes &
Materials is **COMPLETE after closure verification**.
The authoritative project-status record is
[`windows_application/PROJECT_STATUS.md`](../windows_application/PROJECT_STATUS.md).

Batches 8 through 11 are complete through Publish / Versions. Batch 12 is
complete: 12A Runtime Contract, 12B Backend POS Runtime Sync API, 12C
Snapshot-Aware Order Contract, 12D Flutter Sync / Scoped Cache, 12E Published
POS UI Cutover, 12F Offline / Reconnect / Pending Version, and 12G Legacy
Cutover / Final Regression. Production POS uses Published Runtime Contract v1
through `/pos/menu-sync`, retains placement/version identity through the cart,
and creates snapshot-aware orders. Legacy Catalog endpoints and the no-version
order path remain deprecated compatibility interfaces only.

The Product Workspace is the canonical Product parent. Recipe and Material
Effect child routes remain ID-based and preserve Product, Variant, Modifier Group,
and Modifier Option identity without display-name query parameters. Phase 4K
architecture cleanup remains deferred.

## Core domain contracts

### Lifecycle

Products, Variants, Modifier Groups, Modifier Options, and Menu Sections use three
states: Archived when their soft-delete timestamp exists; otherwise Active when
`is_active` is true; otherwise Inactive. Archived wins over `is_active`.
Archive and restore are non-destructive. Inactive is configurable and is not an
archive state. A Variant cannot be created for, or restored to, an inactive or
archived Product. Menu publication has its own status model and is not a substitute
for the three-state lifecycle.

### Modifiers

Modifier Groups define selection type, requiredness, minimum/maximum selections,
and quantity permission. Quantity-enabled groups may permit more selections than
distinct active Options; quantity-disabled groups may not. Group creation is atomic
with its submitted Options, and every Option mutation validates the resulting group
state. `priceDelta` is signed exact decimal money and is distinct from configured
Variant selling price.

### Recipes

Variants own Base Recipes. Modifier Option material profiles can be Global,
Product-specific, or Variant-specific; resolver precedence is backend-authoritative.
Components retain `inventory_items` identity, exact decimal quantity, and canonical
unit. This configuration does not implement inventory runtime, stock deduction, or
reservations.

### Prices and availability

Configured Variant base prices and Variant Price Overrides must be strictly greater
than zero. A Modifier `priceDelta` may be negative. POS resolves base/effective
price plus signed adjustments and rejects a final unit price below zero.

Operational temporary-unavailability input is an offset-less Branch-local
`YYYY-MM-DDTHH:mm:ss` time. Backend Branch timezone is authoritative; persistence
uses the resulting canonical instant and reads return Branch-local time. Scheduled
availability, operational availability, lifecycle, visibility, and publication are
separate layers.

### Publication

Validation and Preview are backend-authoritative diagnostics. Publishing produces
immutable Branch + Channel snapshots/version history only when semantic content
changes; rollback creates a new Version and never reactivates old history.
Published snapshots deliberately exclude operational availability runtime state,
remaining quantities, and Inventory runtime data.

Snapshot schema v3 defines Menu runtime order as the serialized `menus[]`
sequence, with each Menu's zero-based `scopeOrder` repeating that position.
Automatic Branch + Channel publications use exact-scope active assignment order;
explicit `menuIds` retain established canonical Menu order. Catalog
`menu.priority` is excluded from v3 snapshot Menu entries, and future POS
consumers must not use it to re-sort a snapshot. Historical snapshots retain
their original payload; rollback copies the selected payload verbatim into a new
Version.

### POS runtime sync (Phase 12B)

`GET /api/v1/pos/menu-sync?branchId={id}&knownVersionId={optional}` is the
single POS runtime bootstrap/sync endpoint. Its channel is always server-bound to
`pos`; clients cannot select another sales channel. A response contains Branch
context, version metadata, the POS runtime contract v1 static menu projection,
and a fresh runtime overlay. When `knownVersionId` is the current published
version ID, `upToDate` is true and the static menu is `null`, while runtime state
is still returned. A valid Branch with no POS publication returns HTTP 200 with
`version`, `menu`, and `runtime` all `null`.

Static menu configuration and schedule-rule definitions come only from the
immutable `PublishedMenuVersion.payload_json`; draft Catalog, price, placement,
and schedule edits cannot leak into this endpoint. The mapper supports source
snapshot schemas v2 and v3 and always exposes `runtimeContractVersion: 1`; an
unknown source schema returns HTTP 409 with
`UNSUPPORTED_MENU_SNAPSHOT_SCHEMA`. The v3 `menus[]` sequence / `scopeOrder` is
preserved exactly. Runtime availability is evaluated at request time in the
Branch timezone: published schedule rules are evaluated server-side, while live
operational availability is bulk-resolved for the exact Branch + POS scope.
Inventory runtime is intentionally excluded.

### Snapshot-aware POS orders (Phase 12C)

`POST /api/v1/orders` remains backward-compatible. A request without
`publishedMenuVersionId` takes the deprecated legacy live-Catalog compatibility
path; production Flutter POS does not use it. A request with it is the strict
snapshot-aware path: every item must include `productId`, `placementId`,
`variantId`, and `modifierOptionIds`; client price fields are ignored.

For a new versioned order, the supplied version must be the current immutable POS
version for the authenticated Tenant and requested Branch. A stale or foreign,
wrong-Branch, or non-POS version is rejected; historical versions are therefore
not a price-selection mechanism. The new order stores that version in
`orders.published_menu_version_id`. Draft and held versioned orders are pinned:
later item mutations re-use their stored version even if a newer publication is
current.

Products, placements, variants, modifier membership/selection limits, names,
prices, and published schedules are resolved only from `payload_json` (v2/v3).
The resolver loads and evaluates the snapshot once per operation. Its only live
data is the bounded Branch/POS operational overlay, so Sold Out and Temporarily
Unavailable states take effect without republishing. Order items retain selected
variant and placement identities plus stored unit/line monetary values; modifier
rows retain their charged price delta. Completed historical totals never need a
later Catalog or snapshot lookup.

## Performance contracts retained by UX-G0

- Modifier Library returns a bounded Option preview with its Group page; it does
  not fetch Options per Group for list preview.
- Product Modifier Assignments receive material-impact indicators without an
  Option-by-Option profile fetch.
- Product detail supplies Variant Recipe summary/counts, avoiding a Recipe request
  per Variant.
- Product Workspace uses backend-authoritative counts rather than partial list
  length.
- Modifier Library and Menu List use debounce plus request tickets so stale
  responses cannot replace the current filter state.

## Deferred work and Phase 4K debt

Inventory runtime, authentication, and combos remain deferred. Published POS
Snapshot Sync/local cache is complete. Phase 4K may assess the large shared Menu
repository, oversized Menu screens/services, overlapping published-version and
recipe models, combined Recipe Cubits, broad lint suppressions, and legacy POS
Catalog coupling. None of that work belongs to UX-G0.

## Batch 12 final cutover (Phase 12G)

This section supersedes the earlier Phase 12 delivery notes above. Phases 12A
through 12G are complete; Batch 12 is closed.

```text
Menu Management -> Publish -> Immutable Version -> POS Runtime Mapper
-> GET /pos/menu-sync -> Flutter tenant/branch/pos-scoped cache
-> Published POS UI -> version-bound cart -> snapshot-aware Orders
```

Production POS always sends `publishedMenuVersionId`. Every new line includes
`productId`, `placementId`, `variantId`, `modifierOptionIds`, and quantity;
client price fields are ignored. The runtime/cache is the only production menu
source. Startup, refresh, reconnect, branch switch, browse, product tap,
customization, search, and cart navigation make zero calls to the legacy Catalog
menu endpoints. Product tap makes no menu detail, modifier, or price request.

Runtime responses are parsed and scope-validated before atomic cache replacement.
Malformed/unsupported responses preserve a valid cache and never activate live
Catalog data. No-publication, no-cache offline, and invalid-contract states are
intentional blocking states, not fallbacks. Valid cached menus remain usable for
browse/customization/cart construction offline, while create/pay/receipt and all
server mutations remain blocked and are never queued as fake transactions.

Static changes discovered while a cart/order is active are held as one pending
version; the cart stays pinned to its immutable version and the pending version
activates atomically after the cart clears. Restore makes a new current version;
source snapshot v2 is mapped backend-side to runtime contract v1. Dynamic
operational availability is the only live overlay. Published schedules are
resolved backend-side, so unpublished schedule edits do not affect POS.

Orders with `published_menu_version_id = null` remain readable and operational
for history, details, receipts, and refunds; they are not artificially migrated.
Offline menu and cart preparation are supported, while true offline transaction
or payment processing is not implemented.

## Pre-Auth handoff

The approved next sequence is Pre-Auth Hardening A (Order lifecycle +
payment/refund concurrency/idempotency), Pre-Auth Hardening B (Flutter
route-scoped Cubits / shared app context cleanup), Pre-Auth Hardening C (Discount
runtime correctness), Pre-Auth Hardening D (Publish validation race + docs/error
hygiene), then Auth + Employee Roles + Permissions + Branch Assignment. These
are future phases and are not implemented by Batch 12.

### Legacy API and order-path audit

| Reference | Classification | Final decision |
| --- | --- | --- |
| `/menu/categories`, `/menu/products`, `/menu/products/{id}` routes/OpenAPI | E - compatibility API intentionally retained | Deprecated; production POS uses `/pos/menu-sync` only. |
| Laravel `PosApiSmokeTest` | C - compatibility regression | Retained to protect existing contract. |
| Admin Catalog/Pricing tests | B - non-POS use | Retained. |
| Flutter `PosRepository` legacy menu methods/local data | C - deterministic fake/local fixture data | Retained and isolated from backend production mode. |
| Flutter legacy repository tests | C - test fixture | Retained. |
| Earlier POS audit/handoff/integration prose | D - superseded documentation | Historical only; this section is authoritative. |

The no-version `POST /orders` path is E - deprecated external compatibility.
External usage cannot be proved absent, so it remains, but production Flutter POS
never uses it and it is not a runtime-failure fallback.

## Historical note

Superseded phase-by-phase implementation narration was removed in UX-G0-E because
it contained obsolete “not started” and status/count claims. Git history retains
the detailed dated record.
