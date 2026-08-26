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

Current verification status (2026-08-20):

- Pricing UI refinement (2026-08-22): removed the non-functional Back and
  Refresh buttons from the Variant Price Overrides screen. Native system back
  handling remains in place.

- Variant Pricing fix (2026-08-22): a successful scoped-rule save now releases
  the edit lock and preserves the selected context. Change Price edits an exact
  selected-context rule or starts a new one; independent rules remain addable.

- Operational availability API: the list endpoint accepts standard HTTP
  `includeArchived=true` / `false` query values, matching the Flutter client.

- Backend: **118 tests, 1,720 assertions; Pint passed** (verified baseline;
  unchanged by the Batch 7.1 closure pass).
- Flutter: **343 tests, zero failures; `flutter pub get`, `dart format .`, and
  `flutter analyze` passed** in the final closure verification (the supplied
  pre-closure baseline was 337 tests). The current Codex-shell
  `flutter gen-l10n` invocation again timed out after 120 seconds without output;
  the previously completed local Windows generation remains authoritative.
- Repository: final `git diff --check` passed.

Recent product editor update (2026-08-19): Product images can now be selected
from the Windows file picker or dropped directly into the image box. Selected
files upload through the Laravel media endpoint and the saved product keeps the
returned hosted image URL; the old Image URL form field was removed.

Advanced disclosure border fix (2026-08-19): DetailsDisclosure now uses one
explicit light rounded ExpansionTile border, preventing the dark duplicate
top/bottom lines in the product editor Advanced section.

Material picker fix (2026-08-19): Recipe material search dialogs now load the
full available material list on open and when the search field is cleared.

Recipe refresh fix (2026-08-19): Returning from Manage Recipe after a
successful save now refreshes the parent Recipe & Materials workspace so the
new recipe is visible immediately.

Material effects drawer fix (2026-08-19): Material-effect routes now open as
transparent, keyed side panels with the parent catalog screen preserved
underneath, including a slide-in transition and constrained loading/error
states.

Material effects drawer refinement (2026-08-19): Reduced the panel elevation
and shadow opacity for a lighter, less visually dominant drawer edge.

Material effects backdrop refinement (2026-08-19): Lightened the modal scrim
so the underlying catalog page remains easier to read while the drawer is open.

Material Effect context closure (2026-08-20): The ID-based editor routes remain
unchanged. The editor now resolves and displays localized Product, Variant,
Modifier Group, and Modifier Option names from loaded catalog data, with
scope-specific breadcrumbs and an explicit retry state when related context is
missing or unavailable.

Modifier material unit editing fix (2026-08-19): Material-effect rows now use
compatible unit selectors, allowing supported conversions such as kg/g and
ml/l before saving.

Modifier material summary fix (2026-08-19): The modifier-group detail view now
loads saved global material profiles and shows each option's add/remove
material, quantity, and unit beneath its price.

The Menu Management UX redesign is complete through Batch 7. **Batch 7-P —
Recipe Correctness Preflight** is **COMPLETE**. **Navigation & Flow
Stabilization** is **COMPLETE**. **Batch 7.1 — Recipe UX Hardening & Completion**
is **COMPLETE**. **Batch 7 — Recipes & Materials** is **COMPLETE after closure
verification**.

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
- Batch 7.1 — Recipe UX Hardening & Completion — **COMPLETE**
- Batch 7 — Recipes & Materials — **COMPLETE after closure verification**

Navigation & Flow Stabilization: **COMPLETE**. The Product Workspace is the
canonical Product parent; Workspace tabs and Recipe Variant selection are URL
state, legacy Variants/Modifiers routes redirect to Workspace tabs, and
Recipe/Variant children retain Product and Variant identities for returns.
Batch 8 and Phase 4K remain **NOT STARTED**.

CURRENT APPROVED WORK: **Batch 10 — Assignments & Schedules, Group 1** is
implemented. The main workspace is now context-first, uses one bounded
collection preview for active assigned Menus, and defers Menu schedule-rule
requests until Manage Schedule is opened. **Group 2 — Reorder Menus** is
implemented as a focused exact-scope draft with accessible Up/Down controls
and one complete-scope sync on Done. Scopes containing archived diagnostic
Menu assignments block reordering because the current backend contract rejects
archived Menus in scope sync. **Group 3 — Add Menus** is implemented as a
directional exact-scope side sheet: one bounded all-lifecycle Menu list keeps
current-scope assignments and archived Menus visible but disabled, supports
local multi-selection, then performs one complete-scope sync followed by
authoritative scope reconciliation. Menu Schedule remains scheduled for its
dedicated follow-up group.

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
- UX batches after Batch 9 (Assignments & Schedules, Review / Preview / Publish,
  and Versions / Compare / Rollback).

## KNOWN ARCHITECTURE DEBT

### Batch 10 Runtime Fix — Save Schedule (Phase 2)

- Menu Schedule saves through `saveMenuSchedule(...)`: one complete rules PUT,
  one authoritative rules reload, then one bounded collection-preview refresh.
- A save now remains unsuccessful when either confirmation request fails; the
  drawer retains its dirty draft and presents only the localized generic save
  message while debug builds retain the technical request/response/stack trace.
- The Windows runtime verified RAMI / Downtown / POS: Monday changed from
  all-day to `07:00–22:00`, persisted in Laravel, and remained visible after
  closing and reopening the drawer.
- The known `Asia/Damascus` fixed-offset implementation was not changed. Save
  serializes local rule fields (`H:i`, `YYYY-MM-DD`, and explicit nulls) and
  does not depend on that preview/check timezone conversion path.

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
