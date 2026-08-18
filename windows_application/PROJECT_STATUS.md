# CURRENT AUTHORITATIVE STATUS

Cafe System 618 has a Laravel backend in `backend` and a Flutter Windows client
in `windows_application`. Menu Management is implemented across Catalog,
Modifiers, Recipes, Menus, Assignments & Schedules, Review/Publish, and Version
History. The temporary POS catalog remains separate from published menu snapshots.

Phase UX-G0 — Menu Correctness & Performance Gate is **COMPLETE**. Local Windows
verification confirmed that `flutter gen-l10n` completed successfully with no
error; every UX-G0-E gate below is green:

- UX-G0-A — Modifier Domain Correctness: **COMPLETE**
- UX-G0-B — API Performance & Flutter State Consistency: **COMPLETE**
- UX-G0-C — Lifecycle Semantics: **COMPLETE**
- UX-G0-D — Contract & Edge-Case Correctness: **COMPLETE**
- UX-G0-E — Documentation + Final Regression Gate: **COMPLETE**

Current verification status (2026-08-18):

- Backend: **118 tests, 1,720 assertions; Pint passed** (verified baseline;
  unchanged by the Batch 7.1 closure pass).
- Flutter: **337 tests, zero failures; `flutter pub get`, `dart format .`, and
  `flutter analyze` passed**. `flutter gen-l10n` is pending final local Windows
  verification: it exceeds the known Codex-shell timeout without output.
- Repository: final `git diff --check` passed.

The Menu Management UX redesign is complete through Batches 0–6. **Batch 7-P —
Recipe Correctness Preflight** is **COMPLETE**. **Batch 7.1 — Recipe UX
Hardening & Completion** is **VERIFICATION-GATED** pending the final local
Windows `flutter gen-l10n` check; this is focused hardening of the approved
Batch 7 direction, not a redesign.

## IMPLEMENTED FUNCTIONAL CAPABILITIES

- Catalog products, variants, categories, reporting categories, kitchen stations,
  reusable modifier groups/options, and Product-to-Modifier assignment.
- Three-state lifecycle controls and archive/restore for supported catalog and
  menu-composition entities.
- Variant base recipes; Global, Product, and Variant Modifier Option material
  adjustment profiles; inherited resolution and backend-authoritative simulation.
- Menus, sections, placements, assignment/schedule synchronization, validation,
  resolved preview, publication, immutable version history, comparison, and
  rollback.
- Branch/channel Variant Price Overrides, scheduled availability, and operational
  availability overlays.

## MENU MANAGEMENT UX STATUS

- Batch 0: characterization and guardrails — **COMPLETE**
- Batch 1: shared context foundation — **COMPLETE**
- Batch 2: module scaffold/navigation — **COMPLETE**
- Batch 3 / 3.1: Product Catalog and product rows — **COMPLETE**
- Batch 4 / 4.1: Product workspace — **COMPLETE**
- Batch 5: Menus and composition — **COMPLETE**
- Batch 6: Modifier Library — **COMPLETE**
- UX-G0-A through UX-G0-E — **COMPLETE**
- Batch 7-P — Recipe Correctness Preflight — **COMPLETE**
- Batch 7.1 — Recipe UX Hardening & Completion — **VERIFICATION-GATED**
  (pending local Windows `flutter gen-l10n`)

Navigation & Flow Stabilization: **COMPLETE**. The Product Workspace is the
canonical Product parent; Workspace tabs and Recipe Variant selection are URL
state, legacy Variants/Modifiers routes redirect to Workspace tabs, and
Recipe/Variant children retain Product and Variant identities for returns.
Batch 8 and Phase 4K remain **NOT STARTED**.

CURRENT APPROVED WORK: **Batch 7.1 — Recipe UX Hardening & Completion** only.
Do not begin Batch 8 or Phase 4K.

## AUTHORITATIVE DOMAIN RULES

### Modifier groups and options

- A group is Choose one or Choose multiple, Optional or Required, with
  `minSelections`, `maxSelections`, and `allowQuantity`.
- Quantity-enabled groups may set `maxSelections` above their distinct active
  Option count. Quantity-disabled groups may not exceed their available active
  distinct Options. Required groups require at least one selection.
- Group create persists all submitted Options atomically. Option create, update,
  activate/deactivate, archive, and restore validate the prospective group state.
- `priceDelta` is a signed exact decimal: positive is a surcharge, zero makes no
  adjustment, and negative is a reduction. It is not a configured selling price.

### Recipes and materials

- A Variant owns its Base Recipe. Modifier Option material profiles resolve by
  Global, Product, then Variant scope/override according to the backend resolver.
- Recipe configuration is separate from Inventory stock. Exact decimal quantities
  and canonical units are authoritative. Runtime inventory, stock deduction, and
  reservations are not part of Recipe configuration.

### Lifecycle

For Products, Variants, Modifier Groups, Modifier Options, and Menu Sections:

- Archived: an archive/deleted timestamp exists.
- Active: not archived and `isActive == true`.
- Inactive: not archived and `isActive == false`.

Archived takes precedence; inactive is not archived. Product lifecycle does not
cascade to Variants. A Variant cannot be created for, or restored to, an archived
or inactive Product. Menu publication status is separate from this three-state
lifecycle and is not forced into it.

### Pricing

- Product initial/default Variant price, Variant `basePrice`, and an effective
  replacement Variant Price Override are configured selling prices and must be
  strictly greater than zero.
- Modifier Option `priceDelta` remains signed and may be negative.
- POS final resolved unit price is base/effective price plus signed Modifier
  adjustments. It must be at least zero; a below-zero result is rejected, never
  clamped, absolutized, or silently corrected.

### Operational availability time

Temporary unavailability is entered as a Branch-local wall-clock timestamp.
Flutter sends `YYYY-MM-DDTHH:mm:ss` without a workstation/device offset. The
backend interprets it in the authoritative Branch timezone, persists the canonical
instant, and returns the corresponding Branch-local wall-clock time consistently.

## DEFERRED / NOT IMPLEMENTED

- POS Published Snapshot Sync and local snapshot cache.
- Inventory runtime: stock deduction, reservations, and automatic availability.
- Authentication remains intentionally deferred.
- Combos and broader localization migration.
- Phase 4K architecture cleanup.
- UX Batch 7 visual redesign and all later UX batches.

## KNOWN ARCHITECTURE DEBT

This is a Phase 4K concern only; no cleanup is authorized by UX-G0.

- `menu_catalog_repository.dart` remains a large shared Menu Management surface.
- `MenuCompositionService.php` and `MenuValidationService.php` have broad
  responsibilities; several Menu Management screens are oversized.
- Published-version and Recipe/Modifier transport/draft models overlap.
- `recipe_cubits.dart` groups multiple Cubits and states; some recipe screens use
  broad lint suppressions.
- The legacy POS Catalog is still coupled to legacy catalog routes rather than
  published snapshots.

## NON-AUTHORITATIVE HISTORICAL RECORD

Earlier Phase 4 and UX batch implementation notes were intentionally consolidated
into this document during UX-G0-E. They are not an additional source of current
status; consult git history when a dated implementation detail is needed.
