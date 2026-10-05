# Menu Management UX characterization — Batch 0

This document records the presentation baseline before the approved Menu
Management navigation or screen migrations begin. It is deliberately a
characterization record, not a replacement UX plan.

## Shell and route behavior

`AppShell` owns the global sidebar, top bar, responsive sidebar rail, and main
content slot. `DesktopPageLayout` supplies the current Menu Management page
background and padding. The shared `AppTheme` owns the warm Cafe System 618
palette, Manrope typography, 48-pixel buttons, borders, and focusable Material
controls.

Every path beginning with `/menu-management` maps to the global sidebar's
`menuManagement` destination through `_activeDestinationFor`. Therefore, all
deep links retain the Menu Management sidebar highlight today.

| Route family | Current parent destination | Current contextual navigation |
| --- | --- | --- |
| `/menu-management/products`, product create/detail/edit, variants, pricing, availability, operational availability, recipe and simulation routes | Menu Management | Products chip is shown on catalog/detail only; deeper screens use local back/action links or no shared breadcrumb. |
| `/menu-management/modifiers`, create/detail/edit, and modifier adjustment routes | Menu Management | Modifiers chip is shown on library/detail only. |
| `/menu-management/menus`, create/detail/edit, placements | Menu Management | Menus chip is shown on list/detail only; Menu Detail has `Back to menus`. |
| `/menu-management/assignments` | Menu Management | Assignments & schedules chip. |
| `/menu-management/review` | Menu Management | Review & preview chip. |
| `/menu-management/catalog-setup` | Menu Management | Catalog setup chip. |

`MenuManagementTabs` remains the existing screen-local ChoiceChip navigation in
Batch 0 and Batch 1. No routes, query parameters, redirects, shell destination
mapping, or deep-route highlighting have changed. Standard breadcrumbs do not
exist yet; expected future context is the approved route hierarchy such as
`Products / Latte / Large / Recipe` and `Menus / Main Menu / Composition`.

## Existing dirty-state protection

The established screen-level leave guards remain the behavior source of truth:

- Product Editor, Menu Editor, and Modifier Group Editor guard dirty forms.
- Product Modifier Assignments, Menu assignment/schedule editing, and Menu
  section editing guard unsaved mutations.
- Variant Price Overrides and Scheduled Availability guard dirty edits before
  leaving; pricing also guards context changes.

`ContextBar` does not introduce a new dirty-state model. Its optional
`onBeforeContextChange` callback lets a later screen delegate a requested
context switch to its existing guard.

## Widget-test contract and known keys

The reusable harness is `test/support/menu_management_test_harness.dart`. It
pumps the real application theme and localization delegates at 1280, 1440, or
1920 pixels in English/LTR or Arabic/RTL, resets the test surface on teardown,
and provides helpers for overflow and directionality assertions.

Existing behavioral keys are retained and are not renamed in this batch:

- Catalog/detail: `create-product-action`, `product-catalog-search`,
  `product-actions-<id>`, `edit-product-action`, `manage-variants-action`,
  `manage-modifiers-action`, `manage-availability-action`.
- Variants/recipes: `add-variant-action`, `manage-recipe-<id>`,
  `manage-price-overrides-<id>`, `manage-availability-<id>`,
  `recipe-quantity-<index>`, `adjustment-quantity-<index>`.
- Availability/pricing: `save-availability-rules`, `add-availability-rule`,
  `availability-entity`, `availability-branch`, `availability-channel`,
  `add-branch-override`, `add-channel-override`, `add-branch-channel-override`,
  `save-price-overrides`, and `override-price`.
- Operational availability: `operational-variant-selector`,
  `operational-branch-filter`, `operational-channel-filter`, and the existing
  `operational-override-*` editor keys.

## Directionality and technical values

Existing Menu Management technical fields include SKU, barcode, matched override
ID, publication ID, checksum, IDs, version numbers, timestamps, prices, and unit
codes. The new `MenuContextItem.isTechnical` renders its value LTR while the
surrounding ContextBar follows locale direction. The Batch 1 tests exercise
long Arabic labels, RTL headers/context/disclosures, and LTR technical values.

## Batch 2 implementation note

All Menu Management routes now render inside `MenuModuleScaffold` through the
existing AppShell route wrapper. `MenuModuleNavigation` is the single route to
parent-destination registry for the six module destinations:

- Catalog: Products, Modifiers, Catalog Setup.
- Menus: Menus, Assignments & Schedules.
- Release: Review & Publish.

It selects the correct destination for current deep routes without changing the
route definitions, query parameters, redirects, or backend interactions. Deep
routes receive concise breadcrumbs generated from their route context. Entity
names are not available to the global route wrapper, so this batch uses
localized non-technical labels such as `Product` and `Variant` rather than URL
IDs; future entity workspace batches can provide loaded display names.

The AppShell now uses a neutral Menu Management top bar that deliberately hides
the Orders/POS operational Branch tabs. Branch and Channel remain selected only
through the existing Menu Management screen controls.

At 1280 and 1440, the global sidebar collapses to its established icon rail
while Menu Management is open. This preserves practical content width beside
the compact or labeled module rail without changing global navigation behavior
on non-Menu-Management routes. It returns to the full global sidebar at 1920.

`MenuManagementTabs` is intentionally a non-rendering compatibility shim so
existing isolated screen imports remain safe while no page can render a second
navigation system. It is a Phase 4K cleanup finding; no unrelated cleanup was
performed in this batch.
