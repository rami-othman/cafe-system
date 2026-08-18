# Menu Management Architecture

## Current authoritative status

Menu Management is implemented end-to-end for catalog administration, Modifier
Library, recipes/material configuration, menu composition, assignments/schedules,
validation/preview/publishing, and version history. UX-G0-A through UX-G0-D are
complete; UX-G0-E is awaiting only a locally rerun `flutter gen-l10n` after the
Codex environment timed out.
The authoritative project-status record is
[`windows_application/PROJECT_STATUS.md`](../windows_application/PROJECT_STATUS.md).

UX Batch 7 — Recipes & Materials is the next approved UX work. It has not
started. Phase 4K architecture cleanup is deferred.

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

POS Published Snapshot Sync/local cache, Inventory runtime, authentication, and
combos are deferred. Phase 4K may assess the large shared Menu repository,
oversized Menu screens/services, overlapping published-version and recipe models,
combined Recipe Cubits, broad lint suppressions, and legacy POS Catalog coupling.
None of that work belongs to UX-G0.

## Historical note

Superseded phase-by-phase implementation narration was removed in UX-G0-E because
it contained obsolete “not started” and status/count claims. Git history retains
the detailed dated record.
