# Project Status

## Current Authoritative Status

Phase 4E and Phase 4F are complete. The Review workflow's Versions tab is scoped
by Branch + Channel and renders a metadata-only paginated History. Snapshot payload
is explicit, diagnostic, read-only, and opt-in. Backend generates comparison and it
may be bounded; `truncated=true` means only part of the difference set is returned.
Rollback creates a new immutable Version; historical Versions are never reactivated.
No-change rollback creates no Version and refreshes History and Current Version.
Phase 4G — Catalog Setup is complete: Categories, Reporting Categories, and Kitchen
Stations are manageable through the desktop client, with non-destructive
archive/restore and Product Editor integration verified. Phase 4H — COMPLETE:
Recipes / Consumed Materials Configuration provides Variant Recipe editing,
Global/Product/Variant Modifier Adjustment routes, and Backend-authoritative
Simulation. Materials use stable `inventory_items` identity; no runtime stock
behavior or automatic Inventory availability exists, and POS Published Snapshot Sync
remains later work. Authentication, Combos, and broader localization migration remain
unimplemented.

## Historical Phase Log

Phase 4G — Flutter Catalog Setup: Complete after Flutter verification. Catalog
Categories, Reporting Categories, and Kitchen Stations are managed at
`/menu-management/catalog-setup`; archive/restore is non-destructive and persisted
reorder remains Backend-authoritative. Product Editor integration preserves its draft
and refreshes reference values. Final Menu Management Regression and POS Published
Snapshot Sync are not started. Inventory, Recipes, Authentication, and Combos are
not started.

Current authoritative phase status: Phase 4E — Complete; Phase 4F — Complete;
Phase 4G — Complete; Phase 4H — Recipes / Consumed Materials Configuration —
Complete.

Phase 4B — Product Catalog Administration: Complete

Phase 4C.1 — Menus and Sections: Complete

Phase 4C.2 — Product Placements and Ordering: Complete

Phase 4C.3 — Branch/Channel Assignments and Menu Schedules: Complete

Phase 4D.1 — Variant Price Overrides: Complete

Phase 4D.2 — Scheduled Product Availability: Complete

Phase 4D.3A — Operational Availability Overrides: Complete

Phase 4D.3B — Operational Resolution Diagnostic: Complete

Phase 4B — Product Catalog Administration: Complete. Phase 4C — Complete. Phase 4D.1 — Variant Price Overrides: Complete. Phase 4D.2 — Scheduled Product Availability: Complete. Phase 4D.3A — Operational Availability Overrides: Complete. Phase 4D.3B — Operational Resolution Diagnostic: Complete. Phase 4D — Pricing and Availability: Complete. Phase 4E.1 — Menu Validation UI: Complete. Phase 4E.2 — Resolved Menu Preview UI: Complete. Phase 4E.3 — Publishing and Current Version: Complete.

## Phase 4E publishing status

Phase 4E.1 — Menu Validation UI: Complete.
Phase 4E.2 — Resolved Menu Preview UI: Complete.
Phase 4E.3 — Publishing and Current Version: Complete after the Flutter analyzer
and full suite pass. Publishing is integrated into `/menu-management/review` and
uses the Backend-authoritative validation and immutable-version APIs. Current
Version displays metadata only; no snapshot browsing was added. Phase 4F — Version
History, Comparison and Rollback: Complete. POS Sync remains unimplemented, and
the screen-by-screen localization migration remains paused.

## Project Name

Cafe System 618

## Current Goal

Maintain the working Flutter Windows POS, Orders, Discounts, and Reports flows
while preparing the foundation for the approved Full Menu Management Flow.

## Current Phase

Phase 4A — Foundation and Read-only Catalog: Complete

Phase 4B.1 — Product General Editor: Complete

Phase 4B.2 — Variants and Base Pricing: Complete
Phase 4B.3 — Modifier Library: Complete
Phase 4B.4 — Product–Modifier Assignment: Complete
Phase 4B.5 — Product Archive, Restore and Catalog Finalization: Complete

Phase 4C.1 — Menus and Sections: Complete
Phase 4C.2 — Product Placements and Ordering: Complete
Phase 4C.3 — Branch/Channel Assignments and Menu Schedules: Complete

Phase 4D.1 — Variant Price Overrides: Complete
Phase 4D.2 — Scheduled Product Availability: Complete
Phase 4D.3A — Operational Availability Overrides: Complete

Phase 4D.3B — Operational Resolution Diagnostic: Complete

## Completed Work

- Phase 4C.3: tenant-safe Branch/Channel Menu assignment administration is
  complete. The Assignments & Schedules route loads active tenant Branches and
  actual SalesChannel values, presents assigned and eligible active Menus
  separately, and performs complete-scope transactional assignment syncs for
  assignment, activation, removal, and contiguous ordering. Menu lifecycle,
  assignment active state, and schedule state remain distinct. Menu schedule
  rules remain Menu-owned complete sync sets, are fixed to the selected scope
  in this UI, support weekly day, date-range, priority, active, and overnight
  time values, preserve inherited and out-of-scope rules in the complete payload,
  and treat no active governing rules as unrestricted. The branch
  timezone is shown but not client-evaluated. Preview, publishing, versions,
  pricing, product availability, POS sync, authentication, combos, and
  inventory were not added.

- Phase 4C.2: tenant-scoped Product Placement listing, picker, supported display
  overrides, move within the same Menu, complete active-placement ordering, and
  archive/restore are implemented. Hidden placements remain stored but differ from
  archived placements; Product lifecycle is separate. A Product is unique only among
  active placements in one Section. Archived Menus and Sections are read-only.
  Assignments and schedules remain Phase 4C.3; no Pricing, Availability, Preview,
  Publishing, POS Sync, Authentication, Combos, or Inventory UI was added.

- Phase 4C.1: tenant-scoped Menu list/detail/editor, soft archive/restore,
  section create/edit/archive/restore, and complete active-section ordering are
  implemented. Archived Menus are diagnostic/read-only. Product Placements,
  assignments, schedules, Preview, Publishing, and Version History UI remain
  out of scope.

- Phase 4B.5: Product archive/restore is complete. Catalog and Product Detail
  use the real soft-delete endpoints, show status and archive timestamps, keep
  archived details diagnostic/read-only, and guard stale editor, Variant, and
  Modifier Assignment routes. Archive/restore refresh catalog and detail data
  without resetting server-side filters; archive does not change Orders or
  published historical snapshots. Restore does not publish or reassign a
  Product. `isActive` is intentionally distinct from archived state.

- Phase 4B.3: Modifier Library complete. It provides typed Group and Option
  APIs, archive/restore, active-option reordering, and no Product assignment.

- Added the Menu Management sidebar destination and routes for the read-only
  Product Catalog and Product Detail screens.
- Integrated the real tenant-scoped Laravel Admin Catalog endpoints for
  products, categories, reporting categories, and kitchen stations.
- Added typed catalog models, pagination envelope handling, backend repository,
  Cubits, filter reference loading, and focused route/model/repository/Cubit/UI
  tests. No mock Menu repository or mutation UI exists.
- Added Create Product and Edit Product General screens. Create submits the
  single active Default Variant required by the backend; Edit only sends
  product-level fields and shows its existing Default Variant read-only.
- Added Variant and Base Pricing management with active/archived filters,
  create/edit, dedicated Default selection, archive replacement, restore, and
  persisted active-Variant ordering. Catalog and Product Detail data refresh
  after Variant changes; Branch/Channel Price Overrides and Modifier Library
  UI remain deferred.

- Retired the old mock-based Flutter Menu Management prototype, including its
  routes, sidebar destination, dependency registrations, and dedicated tests.
- Confirmed the approved Full Menu Management Flow as the next major track;
  it has not been implemented yet.
- Retained the backend `menu/categories` and `menu/products` endpoints as the
  temporary POS Catalog API.

- Created the initial Flutter project scaffold.
- Added foundation dependencies for routing, state management, dependency
  injection, value equality, and currency formatting.
- Created the feature-based folder structure.
- Added the app entry point, router, desktop shell placeholder, core utilities,
  shared widgets, and POS placeholder screen.
- Added general documentation/control files for future Codex work.
- Implemented shared theme/design system foundation.
- Implemented desktop app shell with sidebar, topbar, main content slot, and
  right panel slot.
- Implemented static POS screen UI with product area and cart panel.
- Fixed responsive/adaptive layout behavior for POS shell and static POS UI.
- Implemented POS Cubit with fake data interactions, cart updates, order type
  selection, and local totals calculation.
- Fixed POS search field focus/typing bug and improved search field
  spacing/alignment.
- Fixed POS search field visual design by removing nested input border and
  aligning icon/text spacing.
- Fixed compact window overflow bugs in topbar and collapsed sidebar.
- Implemented product customization/modifiers dialog with local selection state
  and cart integration.
- Implemented POS discount dialog with coupon code input, available discount
  cards, and local totals integration.
- Fixed POS discount dialog coupon Apply button text wrapping and added compact
  layout coverage.
- Implemented POS payment flow modal with local cash/card/wallet payment
  handling and cart clearing on completion.
- Implemented receipt preview modal with completed order snapshot after local
  payment.
- Updated receipt preview Print Receipt placeholder to close the dialog and
  show payment completion feedback.
- Implemented Select Customer modal and connected optional customer selection
  to the POS cart flow.
- Fixed Select Customer dialog footer button wrapping and blocked hidden
  filtered selections from being confirmed.
- Implemented Orders screen with fake active/held order data, filters,
  responsive order cards, and sidebar routing.
- Adjusted Orders card grid widths to keep cards closer to the design while
  still wrapping responsively.
- Implemented Order Details side panel with fake detail data, customer info,
  item breakdown, payment summary, and timeline.
- Implemented local Refund Flow modal from Order Details with full/partial
  refund selection and validation.
- Connected POS order flow to Laravel backend API using Dio for catalog loading,
  backend order creation, cart item updates, discounts, payment, and receipt
  preview.
- Fixed backend POS product category mapping so products returned with
  `categoryId` display under the selected category tabs.
- Connected Orders screen and Order Details side panel to Laravel backend using
  Dio.
- Implemented the Create Discount Policy UI with local form state, responsive
  policy sections, POS preview, configuration summary, sticky actions, sidebar
  routing, and automated route/layout coverage.
- Implemented the Figma-based Discounts & Coupons list with typed local mock
  data, Cubit-backed search/status/pagination state, summary cards, table
  actions, and preserved Create Discount routing.
- Completed a full POS and Orders flow audit across Flutter, Dio, Laravel, and database behavior. See docs/POS_FLOW_AUDIT.md.
- Implemented Flutter-side canonical cart configuration matching, defensive quantity merging, and serialized cart mutations.
- Implemented Flutter payment submission guards, payment/receipt separation, uncertain-payment verification, and receipt retry recovery.
- Implemented safe backend product-detail loading and Flutter order-context persistence for customer and order type.
- Removed Flutter table selection for the current phase; all new orders use `tableId: null`.
- Fixed the available POS discounts response so it is always returned as a JSON
  list after inactive or expired discounts are filtered out.
- Made POS coupon matching case-insensitive so backend coupon codes work
  regardless of how they were capitalized when created.
- Connected the Orders branch selector to backend branch IDs, so order queries
  no longer use a stale hard-coded branch ID.
- Connected the Daily Operational Report to the Laravel API, including daily
  sales KPIs, hourly sales, payment and order breakdowns, products, refunds,
  discounts, and recent transactions populated by the POS demo seeder.

## In Progress

- None. The English/Arabic localization foundation exists, while the
  screen-by-screen translation migration is paused. Menu Validation UI (4E.1),
  Resolved Menu Preview UI (4E.2), and Publishing and Current Version (4E.3) are
  complete and verified; Version History/Comparison/Rollback (4F) is complete.
  POS Sync remains not started.

## Next Step

Phase 4D.1 — Variant Price Overrides: Complete. Phase 4D.2 — Scheduled Product Availability: Complete. Phase 4D.3A — Operational Availability Overrides: Complete. Phase 4D.3B — Operational Resolution Diagnostic: Complete. Phase 4D — Pricing and Availability: Complete. Phase 4E.1 — Menu Validation UI: Complete. Phase 4E.2 — Resolved Menu Preview UI: Complete. Phase 4E.3 — Publishing and Current Version: Complete. Keep Version History,
Phase 4H — Recipes / Consumed Materials Configuration: Complete. Materials use
stable `inventory_items` identity; no runtime stock behavior or automatic Inventory
availability exists. POS sync UI remains deferred.

## Architecture Decisions

- Flutter is used for the Windows desktop app.
- The app is desktop-first, with possible future tablet support.
- The project uses feature-based architecture.
- Each feature uses an MVC-style internal structure.
- Cubit is used as the controller/state-management layer.
- Theme values should be centralized.
- Feature-specific logic should stay inside its feature.
- Shared reusable UI should go inside `shared`.

## Important Constraints

- Do not create feature-specific documentation until requested.
- Do not create `POS_FLOW.md` yet.
- Do not add database or local storage yet.
- Keep changes focused and avoid unrelated refactors.
- Avoid over-engineering.

## Open Questions

- Detailed component states are not fully defined yet.
- The expected Manrope variable font file still needs to be added if absent.
- Tablet support requirements are not defined yet.

## Recent Changes Log

- 2026-08-02: Verified Flutter Phase 4E.1 Menu Validation and Phase 4E.2
  Resolved Menu Preview. Review requests now forward a sanitized optional Backend
  evaluation timestamp (`at`) to both validation and preview endpoints. Added
  focused contract, stale-response, duplicate-request, filtering, independent
  error-state, and no-assigned-menu coverage. No Laravel behavior, publishing,
  version workflow, POS Sync, or translation migration was added.

- 2026-08-01: Added official Flutter English/Arabic localization infrastructure
  (`gen_l10n` ARB files), app locale persistence, runtime top-bar language
  selection, RTL-aware shared shell geometry, localized backend-value/entity-field
  helpers, and locale-aware formatting utilities. No Laravel Backend behavior or
  Menu Management functionality changed.

- 2026-06-09: Implemented shared theme/design system foundation with warm
  artisan cafe colors, Manrope typography registration, spacing/radius/size
  tokens, shared button/text-field/card updates, and design-system
  documentation.
- 2026-06-09: Implemented the desktop app shell with fixed sidebar, topbar,
  main content slot, and right panel placeholder based on the approved Figma
  POS screen.
- 2026-06-09: Implemented the static POS screen UI inside the app shell with
  mock product cards, category/search controls, static cart items, order type
  selector, totals, secondary actions, and pay button.
- 2026-06-09: Fixed POS responsive behavior with centralized breakpoints,
  collapsed sidebar rail at medium/compact widths, hidden inline cart in compact
  mode, adaptive topbar cart action, bounded search width, adaptive product
  grid columns, and safer cart rows.
- 2026-06-09: Implemented POS Cubit fake-data interactions for loading
  products/categories, category and search filtering, cart add/update/remove,
  order type selection, Cancel cart clearing, and local subtotal/tax/total
  calculations.
- 2026-06-09: Created general project documentation/control files:
  `AGENTS.md`, `PROJECT_STATUS.md`, `README.md`, `docs/ARCHITECTURE.md`,
  `docs/CODEX_WORKFLOW.md`, `docs/ROADMAP.md`, `docs/DESIGN_SYSTEM.md`, and
  `docs/DECISIONS.md`.
- 2026-06-09: Established the initial Flutter app foundation with app routing,
  desktop shell placeholder, core/shared folders, POS placeholder files, and
  foundation dependencies.
- 2026-06-16: Implemented POS discount dialog with coupon entry, fake available
  discount cards, local validation, applied discount state, and pre-tax totals
  integration.
- 2026-06-16: Fixed the POS discount dialog coupon Apply button wrapping issue
  and covered compact discount dialog layout behavior with widget tests.
- 2026-06-16: Implemented POS payment flow modal with cash amount entry, quick
  cash buttons, payment method selection, local fake card/wallet completion,
  split-payment placeholder, and cart clearing after completion.
- 2026-06-17: Implemented receipt preview modal with local completed-order
  snapshot, thermal receipt paper preview, placeholder WhatsApp/print actions,
  and receipt snapshot Cubit coverage.
- 2026-06-17: Updated the receipt preview Print Receipt placeholder so it
  dismisses the preview and shows `Payment completed`.
- 2026-06-17: Implemented Select Customer modal with fake local customers,
  cart header selection, receipt customer snapshot display, and payment reset
  to Walk-in Customer.
- 2026-06-17: Fixed Select Customer dialog footer button wrapping and disabled
  confirmation when the selected customer is filtered out of the visible list.
- 2026-06-20: Implemented Orders screen with fake active/held order data,
  filters, responsive order cards, local placeholder actions, and sidebar
  routing.
- 2026-06-20: Adjusted Orders card grid widths to keep order cards compact and
  responsive across desktop window sizes.
- 2026-06-20: Implemented Order Details side panel with fake detail data,
  customer info, item breakdown, payment summary, placeholder actions, and
  timeline.
- 2026-06-20: Implemented local Refund Flow modal from Order Details with
  safety warning, full/partial refund selection, amount validation, reasons,
  manager notes, and local refund state updates.
- 2026-06-20: Connected POS order flow to Laravel backend API using Dio for
  catalog loading, backend order creation, cart item updates, discounts,
  payment, and receipt preview.
- 2026-06-20: Fixed POS product grid filtering by mapping backend product
  `categoryId` values to category names and returning `categoryName` from the
  menu products API.
- 2026-06-20: Connected Orders screen and Order Details side panel to Laravel
  backend using Dio, including list/detail endpoints, filter mapping, status
  mapping, and safe placeholders for order actions.
- 2026-07-06: Implemented the desktop-first Create Discount Policy UI from the
  supplied Figma reference and screenshot, including the `/discounts/create`
  route, active Discounts sidebar state, local-only policy controls, responsive
  form cards, POS preview, summary panel, sticky actions, and widget coverage.
- 2026-07-12: Implemented guarded Flutter payment submission, confirmed-payment
  cart clearing before independent receipt retrieval, receipt retry recovery,
  uncertain-payment order-status verification, and focused payment tests.
- 2026-07-12: Implemented explicit backend product-detail loading, safe
  no-fallback failure handling, and serialized order-context persistence for
  customer and type updates. Table selection is intentionally deferred; all
  POS order creation sends `tableId: null`.
- 2026-07-15: Implemented the desktop-first Discounts & Coupons list from
  Figma node 66:2 with local-only filtering and pagination, reusable discount
  widgets, active sidebar routing, and a local branch selector in the shared
  top bar. No discount backend or calculation logic was added.
- 2026-07-15: Fixed the Discounts table action-cell overflow at the desktop
  sidebar breakpoint by matching the two Figma row actions, with a shell-level
  regression test at 1200 px.
- 2026-07-29: Retired the old Flutter Menu Management prototype because it
  represented the wrong flow; the approved replacement remains future work.
- 2026-07-18: Fixed the available POS discounts API response to reindex the
  filtered collection. This lets the Flutter POS dialog display active
  discounts when earlier records are inactive or expired.
- 2026-07-18: Made POS coupon matching case-insensitive so lowercase backend
  codes such as `zaher` apply correctly from the Flutter discount dialog.
- 2026-07-18: Connected Orders branch selection to backend branch data and
  passed the selected branch ID to order-list API requests.

- 2026-08-01: Completed Phase 4D.2 Scheduled Product and Variant Availability. Product-owned complete-sync rules support Product/Variant, Global/Branch/Channel/Branch + Channel contexts, weekly/date/overnight windows, priority, active state, immutable drafts, inherited diagnostics, authoritative preview, and archived read-only safeguards. Operational Availability is a separate runtime overlay.

- 2026-08-01: Completed Phase 4D.3A Operational Availability Overrides. Product and Variant runtime records support Branch + all-channels or Branch + exact-channel scope, Available, Sold Out, temporary unavailable-until, reason, informational remaining quantity, clear confirmation, backend validation mapping, expired diagnostics, and archived read-only safeguards.

- 2026-08-01: Completed Phase 4D.3B Operational Resolution Diagnostic and Phase 4D final verification. The existing route uses the backend product operational preview endpoint with an optional Variant query context, real Branch and SalesChannel runtime selection, matched source presentation, explicit Available and no-override fallback distinction, stale response protection, and expired-record fallback diagnostics. Scheduled Availability, publishing, immutable snapshots, Inventory, and POS remain separate.
