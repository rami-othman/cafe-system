# Cafe 618 Inventory — Claude UI map

## Source audit

Read and parsed on 2026-08-23:

- `design_reference/inventory/Cafe618 Inventory Module.dc.html` (78,454 B)
- `design_reference/inventory/Cafe618 Inventory Extensions.dc.html` (51,560 B)
- `design_reference/inventory/Cafe618 Inventory Operations.dc.html` (79,413 B)
- `design_reference/inventory/github.md` (1,403 B)

The files define 19 total entries: seven Module entries (including the visual
kit), four Extensions screens, and eight Operations screens. This is 18 actual
Inventory screens/workspaces plus one Design Kit. Module is
the Arabic RTL authority. Extensions and Operations use English LTR source
layouts; their geometry, table structure, dialogs and state behaviour must be
preserved while all user-facing copy is localized to Arabic RTL.

## Shared visual contract derived from the HTML/CSS

| Element | Exact source value |
| --- | --- |
| Reference canvas | 1440px wide, 900px high, 16px outer radius, 1px `#E7E2DA` border, `#FAF7F2` body; outer page background `#EDE7DE`. |
| Sidebar | 236px wide, 28px × 16px padding, `#F0EDED`, 44px navigation rows, 8px radius, 6px row gap; active `#FEC29E`. Module places it on RTL inline-start. |
| Top bar | 64px high, 24px horizontal padding, 4px branch-tab gap; active branch has 2px `#231005` underline. Shift pill uses 7px dot, 11px text and 999px radius. |
| Content | Module pages use 28px × 32px padding; Extensions use 20px × 32px; Operations use 24px × 32px. Standard section gaps are 16–20px. |
| Typography | IBM Plex Sans Arabic, weights 400/500/600/700. Page title 22px in Module and 18px in Extensions/Operations; subtitle 13px; table header 12px; rows 13px; KPI label 11px. |
| Controls | Filters: 38px high; primary buttons: 40px; form fields: 40–42px; 8px control radius. Search/filter surfaces use `#FAF7F2`, border `#E7E2DA`. |
| Cards/tables | White card, 12px radius; tables use `#F4E7D3` 44px header; typical table rows are 52–60px; horizontal table containers scroll at declared 900–1260px minimum widths. |
| Dialogs | Overlay `rgba(35,16,5,.4)`; white 400/420/440px dialog, 16px radius, 24px padding, large destructive warning icon. |
| State colours | success `#2E7D32`/`#E3F5E8`; warning `#9B4D12`/`#FFE6D1` or `#FFF8F1`; danger `#C62828`/`#FFF1F0`; info `#1B5AAA`/`#E4EEFF`; muted `#6B6B6B`. |
| Directionality | Whole Inventory module is RTL. Numeric values, SKUs, dates and conversion formulas explicitly use LTR/right-aligned local islands. |

## Screen/workflow map

Classification: **A** reuse as-is, **B** reuse + visual correction, **C** refactor, **D** missing — build new.

## Module secondary navigation

The Extensions source is the only Claude export that defines a module
secondary-navigation list. Its complete, source-supported sequence is rendered
in Arabic RTL as: **نظرة عامة / المواد المخزنية / أرصدة المخازن / حركات
المخزون / جرد المخزون / تحويلات المخازن**. Units & Conversions and the
Operations workspaces are intentionally not added to that secondary list:
Operations does not define a corresponding tab list, and Units is an
Operations screen. They remain route/context-action destinations rather than
invented navigation tabs.

| Source | Screen/workflow | Source-derived filters, columns, actions and important states | Current implementation | Class |
| --- | --- | --- | --- | --- |
| Module | Design kit | Colour/type/button/filter/KPI/badge/table-state references; statuses include in/low/out, active/inactive, movement and approval states. | Shared token system resembles the source but uses Manrope/LTR shell. | B |
| Module | Inventory Overview | Actions: Start Count, Add Movement. Filters: branch, warehouse, date range, item/movement search. Four KPIs; warehouse-value bars; low-stock panel; latest-movements table: item, movement type, quantity, warehouse, time. | Dashboard, filters, KPIs, alerts and movement table exist. | B |
| Module | Inventory Items | Add item; search item/SKU; type, category, stock status, active status filters; pagination. Table: item, SKU, type, unit, available qty, reorder level, average cost, stock status, view/edit/delete. | Items list, filtering, pagination, item dialog and details route exist; source action geometry/localization differs. | B |
| Module | Item Details | Breadcrumb; Edit Item/Add Movement; KPI cards total qty/value/minimum/last movement; balances table: warehouse, branch, qty, available, avg cost, value; recent history. | Metadata, balances and history exist. | B |
| Module | Warehouse Balances | Warehouse selector; KPIs total items/value/low/out; item search + stock status. Table: item, actual, available, avg cost, total value, stock status. | Balances screen largely exists. | B |
| Module | Inventory Movements | Add Movement; filters date range, warehouse, item, type, employee; 1180px table: date/time, item, warehouse, type, qty, cost, employee, reference, details. Immutable-ledger subtitle. | Ledger and details exist, but date/employee/reference source fields are absent. | B |
| Module | Add Movement | Four movement-type cards; warehouse/item; current/available/unit/avg-cost summary; LTR quantity and conditional unit-cost/reason fields; notes; expected-balance panel; confirm dialog before irreversible post. | Guided form and backend validation exist, but lacks exact four-card/confirmation design and idempotency input. | B |
| Extensions | Stock Counts list | Start Count; filters date, branch, warehouse, status, creator; KPIs draft/in-progress/pending approval/posted variance; 1080px table: count #, warehouse, date, creator, items counted, variance value, status, actions. | Basic count list/start flow exists; no required filters/KPIs/action mapping. | C |
| Extensions | Stock Count Workspace | Breadcrumb + metadata; cancel; search/variance filter; 1080px editable table: item, SKU, unit, expected, counted, variance, avg cost, variance value, reason; sticky auto-save action bar; Save Draft, Submit, Approve & Post; irreversible confirm dialog. | Detail is read-only; service supports lines and lifecycle. | C |
| Extensions | Warehouse Transfers list | Create Transfer; filters date, source, destination, branch, status; KPIs draft/pending/in-transit/received; 1260px table: #, source, destination, requested, dispatched, received, items, value, status, action. | No transfer domain/API/UI. | D |
| Extensions | Transfer Workspace | Breadcrumb/status; source/destination cards; add-item search; 1180px lines: item, SKU, unit, source available, requested, dispatched, editable received, unit cost, total, delete; shortage reason warning; notes; summary; sticky save/cancel/receive; irreversible receipt confirmation. | No transfer domain/API/UI. | D |
| Operations | Recipes & Product Costing | Create Recipe; search/branch/category/status; four KPI cards; 1180px table: product, version, consumption location, recipe cost, selling price, gross profit, margin, status, View/Edit. | Recipe schema exists but no API or Flutter screen. | D |
| Operations | Recipe Builder | Product, Bar/Kitchen segmented consumption type, consumption warehouse, version; 900px ingredients table: ingredient, SKU, unit, available, required, wastage, avg cost, line cost, delete; Add Ingredient; costing panel; notes; version warning; Cancel/Save Draft/Activate. | No implementation. | D |
| Operations | Suppliers | Add Supplier; search/status/category/branch; four KPI cards; 1000px table: supplier, contact, phone, categories, last purchase, outstanding, status, action; selected supplier side panel with rating, POs, invoices and supplied items. | No domain/API/UI. | D |
| Operations | Purchase Orders list | Create PO; filters date, supplier, branch, warehouse, status; KPIs draft/pending/received/outstanding; 1240px table: PO, supplier, destination, order date, expected delivery, total, payment, status, action. | No domain/API/UI. | D |
| Operations | Receive Purchase Order | Breadcrumb/status; supplier/destination/order/delivery fields; item-add search; 1240px lines item, SKU, unit, ordered, editable received, unit price, discount, tax, total, delete; shortage warning; notes/attachment; financial summary; Cancel/Record Payment/Receive Items. | No domain/API/UI. | D |
| Operations | Reorder Suggestions | Branch/warehouse/category/urgency/supplier filters; KPIs; urgency-grouped 1180px table item, warehouse, available, reorder level, suggested qty, cost, estimated cost, preferred supplier, Add to PO/View/Dismiss; suggested-PO side panel grouped by supplier. | Only low-stock dashboard alerts exist. | D |
| Operations | Units & Conversions | Search; 1000px table item, base unit, purchase unit, LTR formula, consumption unit, status, edit. 440px dialog has source/target/factor, default purchase/consumption toggles and computed formula. | Item-pair conversion list/dialog exists but not unit roles/defaults/base model. | C |
| Operations | Barcode Operations | Lookup/count/receiving scan modes; scan/type field; ready state; matched item/balance/unit/cost cards; quantity update/continue actions; missing-in-selected-warehouse error; recent scan activity. | Item barcode field only. | D |

## Mandatory interaction/state details

All list screens need loading, empty, validation, API-error and forbidden states in the same table/card shell. Inventory mutations must refresh from server truth. Count posting, transfer receipt and manual movement have modal confirmations. Count and transfer workspaces have sticky action bars. Reports is present only as a shell destination in the exports and remains out of scope.
