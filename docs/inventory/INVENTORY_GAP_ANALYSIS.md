# Cafe 618 Inventory — source-derived gap analysis

## Baseline and audit scope

The confirmed uncommitted working tree is the implementation baseline. It must
not be reset, restored, cleaned, discarded or overwritten. This audit compared
the three parsed Claude exports and `github.md` against `windows_application`
and the Laravel backend, routes, migrations, seeders and tests.

`github.md` says the Claude export was grounded in the real shared Flutter
shell/tokens and that the original sync had seven Arabic RTL inventory screens.
The current repository now contains a partial Inventory Center implementation;
it is therefore a reuse/refactor target, not a duplicate-UI opportunity.

## Classification summary

| Classification | Workflows |
| --- | --- |
| A — reuse as-is | None. Every current screen requires Arabic RTL, IBM Plex Sans Arabic, or a source-derived interaction/data correction. |
| B — reuse + visual correction | Shared design kit/shell, Overview, Inventory Items, Item Details, Warehouse Balances, Inventory Movements, Add Movement. |
| C — refactor | Stock Counts list, Stock Count Workspace, Units & Conversions. |
| D — missing — build new | Warehouse Transfers list/workspace, Recipes list/builder, Suppliers, Purchase Orders list/receiving workspace, Reorder Suggestions, Barcode Operations. |

## Execution status — Phase 1 hardening

| Item | Actual status |
| --- | --- |
| RTL physical shell | Resolved: `AppShell` now relies on Flutter RTL `Row` placement instead of reversing children a second time. A 1440×900 widget test asserts the 236px Inventory sidebar is physically right-aligned and content remains left. |
| Source shell geometry | Resolved for Inventory configuration: 236px sidebar, 64px top bar, 36px mark, directional 28×16 sidebar padding, and directional 28×32 content padding. LTR defaults are retained. |
| Branch runtime data | Resolved: `OperationalBranchRepository` now requires the API client. The former Downtown fallback is an explicit fake used only by non-backend test setup. |
| Source map/navigation | Resolved: the map records 19 entries, and the Arabic RTL secondary list mirrors the six Extensions tabs. Operations and Units are not invented as tabs. |
| Inventory decomposition | In progress: screen/controller extraction remains required before the advanced workflows. |
| Phase 2–7 workflows | Not started in this execution pass; no transfer, recipe, purchasing, reorder, or barcode backend logic has been represented as complete. |
| Dashboard management view | Resolved within the existing dashboard endpoint and Inventory Cubit: server-derived stock KPIs, warehouse item/alert summaries, low-stock reorder context, movement categories, daily stock-value trend points, and explicit loading/empty/error/permission states are available. Transfer and purchase-order actions remain disabled because their workflows are still deferred. |
| Dashboard — Recent inventory activity | Resolved: the dashboard is a bounded RTL operational feed (not a ledger) with server-filtered movement type, existing date/warehouse scope, type-specific status treatment, reference/user/timestamp metadata, an empty state, and a route to the full movement ledger. |
| Dashboard — Analytics insights | Resolved: the dashboard endpoint supplies scoped, server-derived 7/30/90-day stock-value points plus real waste and sale-consumption summaries. The RTL dashboard presents a compact full-width trend and balanced waste/consumption cards with loading and empty states; no client-side business calculations or new inventory workflows were added. |
| Inventory Items module | Resolved: the central item workflow now has extracted RTL list, form and details views; server-owned stock/status/cost data; search, paging and category/type/status/warehouse filters; structured unit/conversion, tracking, cost and warehouse-assignment validation; and display-only stock quantities. Recipe usage and purchase-history tabs are intentionally empty until those deferred modules provide real data. |

## Flutter gaps

| Area | Evidence | Required resolution |
| --- | --- | --- |
| Module structure | Inventory is one `inventory_screens.dart`, one `InventoryCubit` and one state, despite unrelated dashboard/item/count/unit responsibilities. | Keep the existing feature directory but split views/widgets, repositories/models and Cubits by the source workflows. Do not create a second Inventory implementation. |
| Directionality | `AppShell` uses sidebar-first LTR `Row`; `AppSidebar` has a right border and all Inventory strings are English. The Module export is RTL. | Add an RTL-capable shell configuration and Arabic Inventory labels. Preserve local LTR direction for numeric values, SKU, date and conversion formula cells. |
| Typography | `pubspec.yaml` bundles only Manrope; Claude imports IBM Plex Sans Arabic weights 400–700. | Bundle and configure IBM Plex Sans Arabic, then scope it to Inventory without uncontrolled system fallback. |
| Shared branch context | `AppTopBar` watches/updates `OrdersCubit`; Inventory reaches OrdersCubit for branch warehouse filtering. | Extract shared operational branch context and migrate POS, Orders and Inventory without changing existing page behaviour. |
| Source geometry | Existing shared widgets are related to the reference, but Module dimensions differ and Extension/Operations layouts are not implemented. | Add configurable shared components/tokens; use source sizes from UI map instead of global breaking changes. |
| Existing current screens | Current dashboard/items/details/balances/movements/forms are backed by real APIs, including some loading/error states. | Reuse their repository/domain work, translate, make RTL and add missing source filters/tables/dialogs/states. |
| Counts | Backend service has lifecycle and line-upsert support; Flutter details screen is read-only. | Refactor into the editable source workspace with sticky action bar and source filters/KPIs. |
| Units | Item conversion pairs and catalog endpoint exist. | Refactor for base/purchase/consumption roles, formula, defaults and source dialog/table. |
| Tests | No Inventory Flutter repository/Cubit/widget/golden suite was found. | Add per-workflow test coverage and source-sized goldens after reusable widgets stabilize. |

## Backend gaps

| Requirement | Existing correct foundation to preserve | Missing or unsafe work |
| --- | --- | --- |
| Warehouse-specific balances | `stock_balances` has tenant + warehouse + item identity. `StockMovementService` transacts, locks balances, calculates weighted average and rejects negative stock. | Add idempotency operation identity and use one service for all future stock writers. |
| Immutable ledger | No update/delete routes; manual movement requires reasons for waste/adjustments/count variance. | Add source-required transfer, receipt and consumption references/idempotency while retaining immutable rows. |
| Stock counts | Draft → in_progress → submitted → approved → posted/cancelled and variance movements exist. | Add query filters/KPIs/metadata needed by source; lock/snapshot expected count balances consistently and expose editable workspace APIs. |
| Units | Controlled static catalog and tenant-scoped pair conversions exist. | Add persistent controlled units or authoritative catalog roles, item base/purchase/consumption units, normalized conversion resolution and defaults. |
| Transfers | Nothing exists. | New tenant-scoped transfer/line schema, lifecycle, authorization, source/destination locking, immutable outbound/inbound movements, partial receipt/shortage reason/cancellation/idempotency. |
| Recipes and sale consumption | Legacy recipes, lines, settings and sale-consumption tables exist; phase documentation describes intent. | No controller, routes, repository or consumption service. Lines lack controlled unit conversion. Integrate idempotently with successful payment transaction only. |
| Suppliers and POs | Nothing exists. | Supplier, supplier-item, PO, PO line, receipt and receipt line domain plus partial receiving, weighted-average update and financial fields shown by source. |
| Reorder | Dashboard exposes low-stock alerts. | Per warehouse/item rules and server-derived urgency suggestions with preferred supplier and dismiss/action state. |
| Barcode | Optional unique `inventory_items.barcode` exists. | Mappings/lookup, operational scan modes/activity and safe quantity update flow. |
| Seed data | Inventory Center seeds items, warehouse types, movements and a count. | Extend with source-shaped transfer, conversion, recipe, supplier, PO/partial receipt, reorder and barcode scenarios through services. |

## API/test delta

Existing endpoints cover the reusable Module flows: dashboard, balances, units,
conversion items, item CRUD/detail, movements and counts. Missing endpoints
cover all D workflows and stock-count workspace queries. Existing stock-changing
requests lack an explicit idempotency key. `InventoryCenterApiTest` already
covers tenant scope, controlled pairs, weighted average manual movements,
negative stock, waste reason and single count post. Add the mandated transfer,
partial receipt, conversion, recipe-payment idempotency, barcode and reorder
coverage, then Flutter repository/Cubit/widget/golden tests.

## Resolved audit blocker

The Claude files and baseline confirmation are now available. The visual audit
blocker is resolved; implementation begins with the shared operational/RTL
foundation because it is required by every B/C/D workflow.
# Bar Check implementation status

The first Bar Check slice now introduces a tenant-scoped template and template
line model, attaches a `SHIFT_CHECK` to the existing stock-count tables, and
blocks shift close when an active required template has not been posted for
that shift. The Flutter Bar Check center, template editor, count workspace,
and manager-review state remain to be connected to these endpoints.
