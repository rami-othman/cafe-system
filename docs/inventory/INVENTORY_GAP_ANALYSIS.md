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
