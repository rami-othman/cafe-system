# Menu Management Architecture

## Current Authoritative Status

Phase 4E and Phase 4F are complete. Flutter exposes a Versions tab in Review scoped
only by Branch + Sales Channel.
It calls the paginated history API for metadata only, fetches immutable Snapshot
payload only as an explicit read-only LTR diagnostic, and renders backend-bounded
comparison groups without a client-side recursive diff. `truncated` means the
comparison is non-exhaustive. Rollback sends only the supported optional reason,
creates a new immutable Version when content differs, never reactivates history,
and refreshes Current Version and History for new and no-change results. Phase 4G —
Catalog Setup is complete: Categories, Reporting Categories, and Kitchen Stations
are manageable through the desktop client, with non-destructive archive/restore and
Product Editor integration verified. Phase 4H — COMPLETE: Recipe configuration
belongs to a Variant; materials use stable `inventory_items` identities, exact
decimal strings, and canonical mapped units. Base Recipe, Global/Product/Variant
adjustment, and Backend-authoritative simulation routes are complete. No runtime
stock behavior or automatic Inventory availability exists; POS Snapshot Sync remains
later work. Authentication, Combos, and broad localization migration remain
unimplemented.

## Phase 4J — Menu Management UI/UX Final Polish

Status: **COMPLETE** after Flutter verification.

Phase 4J changed presentation only. It retains the existing route structure,
backend contracts, precedence rules, Recipe resolution, validation, snapshots,
publishing lifecycle, tenant boundaries, archive semantics, and rollback behavior.
The shared tab navigation now presents the current lifecycle as Build, Configure,
and Review & release. Review makes the non-mandatory Check Menu → Preview → Publish
→ Version History progression explicit. Recipe and Modifier screens use
manager-facing consumed-material and inheritance language; scheduled and
operational availability remain clearly separate layers.

Checksums, publication IDs, matched override IDs, raw snapshot data, and issue
codes remain available but are visually secondary technical diagnostics. New UI copy
has English and Arabic entries; this does not start the broader localization
migration. No Backend file or domain behavior changed.

### Phase 4K architecture findings only

- The existing findings remain: the large shared Menu Catalog repository, oversized
  Menu Management screens and backend services, overlapping transport/view models,
  combined Recipe Cubits, broad lint suppressions, and legacy POS Catalog coupling.
- Phase 4J adds no new architecture finding. No files were moved or redesigned.

Next: **Phase 4K — Architecture Cleanup**. Menu Management is not finally closed.

## Phase 4I — Full Menu Management Regression

Status: **COMPLETE** after all Backend and Flutter verification gates.

Baseline was 96 Backend tests / 1,344 assertions and 270 Flutter tests. Final
verification is 98 Backend tests / 1,476 assertions and 270 Flutter tests. Pint,
Dart formatting, Flutter analysis, and `git diff --check` pass.

Phase 4I is verification and regression only. The integrated Backend regression
uses real HTTP controllers and the real Catalog, Recipe, validation, preview,
publishing, comparison, and rollback services. It creates one tenant and a
realistic Latte graph with Catalog/Reporting categories, Kitchen Station, Small,
Medium, and Large Variants, Base Recipes, required Milk Type and optional
quantity-enabled Extra Shots, Variant Oat Milk adjustments, Menu Sections and
Placement, Branch + POS assignment, Menu and Product schedules, a Variant price
override, and an operational Available overlay. Product assignment necessarily
precedes Product/Variant modifier adjustment configuration because the existing
authoritative Recipe contract rejects overrides for an unassigned Group.

The test then exercises Backend-authoritative validation and resolved preview,
Recipe Simulation, schema-v2 Version 1 publication, price/Recipe/modifier material
changes, Version 2 publication, typed `priceChanges` and `recipeChanges`, and
rollback to a new Version 3. It verifies checksum and payload determinism,
historical immutability, exact Recipe decimal strings, and the absence of runtime
operational/remaining-quantity data from Published Snapshots. Archived Recipe
materials remain visible by stable ID in editable Recipes and old Snapshots, while
new writes are rejected until the material is restored.

Tenant isolation remains enforced throughout Categories, Reporting Categories,
Kitchen Stations, Products, Variants, Modifiers, Recipes, Menus, Sections,
Placements, Assignments, Pricing, Availability, Validation, Preview, Publishing,
Versions, comparison, and rollback. The existing focused suites cover foreign
route resources, submitted foreign IDs, atomic sync failures, and scope-specific
history. No permanent delete flow was added. Archive/restore remains
non-destructive, and historical Published Versions are never reconstructed.

One regression was confirmed and fixed: soft-deleted Category, Reporting Category,
and Kitchen Station relationships disappeared from Product Detail. Product
relationships now include their soft-deleted reference rows for diagnostics.
CatalogProductService still accepts only active, same-tenant references for new
writes and blocks Product restoration while required references remain archived.

### Windows manual smoke checklist

This checklist is practical guidance and **was not manually executed during Phase
4I**; automated tests cover the underlying contracts.

1. Start the Backend and Windows app, select the intended tenant context, then open
   Menu Management > Catalog Setup and confirm the Branch timezone.
2. Create a Product named Latte with localized English/Arabic names, stock tracking,
   Catalog/Reporting categories, Kitchen Station, cost, and Small/Medium/Large
   Variants with one Default Variant.
3. Open each Variant Recipe, add compatible consumed materials with exact decimal
   quantities, save, leave, and reopen to confirm persistence.
4. Create Milk Type and Extra Shots Modifier Groups and their Options; assign the
   Groups to Latte, configure Global and Variant adjustments, and run Recipe
   Simulation with Oat Milk plus two Extra Shots.
5. Create a Menu with at least two Sections, place Latte, reorder it, move it between
   Sections and back, and confirm hidden versus archived states remain distinct.
6. Assign the Menu to one Branch + Channel scope, add weekly/date and overnight
   schedules, and confirm displayed effective/inherited schedule diagnostics use
   the Branch timezone.
7. Configure Medium Variant price overrides and verify Branch + Channel, Branch,
   Channel, then Base Price precedence as context changes.
8. Configure Product/Variant Scheduled Availability separately from Operational
   Availability; verify Available, Sold Out, temporary expiration, and informational
   Remaining Quantity without expecting Inventory automation.
9. Open Review, run Validation, and confirm Backend errors block while warnings do
   not. Run Preview and inspect Menu > Section > Product > Variant > Modifier order,
   effective price, availability layers, sellability, reason codes, and Recipe
   summary counts.
10. Publish Version 1, change one effective Variant price, one Base Recipe component,
    and one Modifier material adjustment, validate again, and publish Version 2.
11. Open Versions, confirm the Current badge and opt-in Snapshot behavior, compare
    Version 1 to Version 2, and verify price and Recipe change groups.
12. Roll back to Version 1, confirm a new current Version is created, reopen Versions
    1 and 2 to confirm they are unchanged, then repeat representative Review/Version
    views in English and Arabic/RTL.

### Phase 4K architecture findings only

- `windows_application/lib/features/menu_management/repositories/menu_catalog_repository.dart`
  is approximately 55 KB and couples most Menu Management subdomains through one
  repository surface.
- `backend/app/Services/Menu/MenuCompositionService.php` and
  `MenuValidationService.php` are approximately 36 KB and 29 KB respectively and
  carry broad responsibilities that merit decomposition review.
- Several Flutter screens exceed 20 KB, led by `menu_review_screen.dart`,
  `availability_screen.dart`, and `menu_assignments_screen.dart`; view/controller
  extraction should be assessed without changing feature boundaries.
- Published Version concepts are represented by both `PublishedMenuVersion` in
  Review models and `PublishedVersion` in Version models. Modifier and Recipe
  record/draft models also overlap. These may be purposeful transport/view splits,
  but should be audited before consolidation.
- `recipe_cubits.dart` contains three Cubits and their States, and several Recipe
  screens use broad file-level lint suppressions. These are maintainability findings,
  not Phase 4I functional defects.
- The temporary POS Catalog continues to consume legacy routes rather than Published
  Snapshots. This coupling is known and must be handled only by the future POS Sync
  phase.

No files were moved and no architecture was redesigned in Phase 4I. POS Published
Snapshot Sync remains not implemented. Runtime Inventory integration remains not
implemented. Authentication remains deferred. Combos remain deferred. Broader
localization remains deferred.

## Historical Phase Log

## Phase 4G Flutter Catalog Setup

Flutter administers Catalog Categories, Reporting Categories, and Kitchen Stations
at `/menu-management/catalog-setup`, with an optional `tab` query. The UI uses the
tenant-safe Laravel reference APIs for list/search/status pagination, create/update,
soft archive/restore, and persisted ordering. No tenant ID, Product relationship,
usage count, or local identifier is submitted. Reporting Categories are analytics
classifications and do not control customer Menu placement. Product Editor opens the
matching manager without discarding its draft and refreshes reference values on
return, retaining an archived assigned reference in Edit mode. Phase 4H Recipes /
Consumed Materials Configuration is complete. Materials retain stable
`inventory_items` identity; runtime stock behavior and automatic Inventory
availability do not exist, and POS Sync remains later work. Authentication, Combos,
and broader localization migration remain unimplemented.

## Current Flutter Review & Preview status

Flutter Phase 4E.1 (Menu Validation UI) and Phase 4E.2 (Resolved Menu Preview
UI) are complete and read-only. Validation calls the Backend-authoritative
menu-specific or assigned-collection endpoint; only its returned `isValid`
value controls the displayed Can Publish state. Errors block future publishing;
warnings and information remain diagnostics and never trigger client-side
publishability calculations.

Resolved Preview calls the matching Backend endpoint and renders its ordered
resolved hierarchy, prices, availability layers, sellability, reason codes, and
modifier constraints. It is diagnostic data, not an immutable Published Snapshot,
and has no mutation, publish, version, comparison, rollback, or POS-sync control.
Requests contain only supported context: Branch, Sales Channel, optional evaluated
time (`at`), and the Backend-supported preview language/visibility controls.

Flutter Phase 4E.3 Publishing and Current Version is **Complete**. The Review
route's third tab uses `POST /api/v1/admin/menu-management/publish` and
`GET /api/v1/admin/menu-management/current-version` for the same Branch, Channel,
and selected Menu/collection context. One selected Menu is submitted through the
supported `menuIds` field; collection scope omits it and Backend resolves active
assignments. Current Version is metadata only: payload browsing is deliberately not
implemented. Backend reruns validation during every publication. Warnings require
explicit confirmation but allow publication; errors return a blocked state without
claiming a Version. Changed semantic content creates an immutable current Version;
identical semantic content records a no-change Publication and preserves the
Version. Runtime sold-out, temporary override, and remaining-quantity state are
excluded from immutable snapshots. Request tokens discard stale context, current
Version, and publish responses. Phase 4F Version History, comparison, and rollback
is **Complete**; POS Sync is unimplemented. The localization foundation exists;
screen-by-screen translation migration remains paused.

## Flutter Phase 4E.1 and 4E.2: Review & Preview

The read-only Flutter route `/menu-management/review` accepts optional `branchId`, `channel`, and `menuId` query parameters. It sanitizes unsupported channels and unavailable selections, loads real Branches and active assignments, and sends only Branch ID and Sales Channel context to `POST /api/v1/admin/menus/{menu}/validate` or `POST /api/v1/admin/menu-management/validate`. Backend `isValid` is the authoritative publishability result: errors block, warnings do not, and information is diagnostic.

The matching `POST /api/v1/admin/menus/{menu}/preview` and `POST /api/v1/admin/menu-management/preview` endpoints provide the resolved menu tree. Flutter does not reconstruct price or availability locally. It renders returned effective-price scope, scheduled availability, operational availability, final sellability, and reason codes distinctly, plus returned modifier selection constraints and option availability. Preview language (`default`, `ar`, `en`), hidden, and unavailable controls are limited to the Backend contract; evaluation uses the Branch timezone returned by Backend. Preview is diagnostic and is not a Published Snapshot payload. Publishing and Current Version are Phase 4E.3 complete; Version History, comparison, rollback, and POS sync remain out of scope.

## Phase status

## Phase 4C.1: Flutter Menus and Sections

Status: Complete after Flutter analyzer and the full test suite pass. Routes:
`/menu-management/menus`, `/create`, `/:menuId`, and `/:menuId/edit`.
Menus own Sections; ownership comes from the Menu route and is never submitted
by the user. Menu and Section archive/restore are soft lifecycle operations.
Archived Menus are diagnostic/read-only; restoring does not publish, assign a
Branch/Channel, or restore archived Sections. Active Section ordering submits
the complete ordered active set. Product Placements are implemented at Flutter
route `/menu-management/menus/:menuId/placements`; Branch/Channel assignments and
schedules remain Phase 4C.3. Publishing UI is not implemented.

## Phase 4C.2: Flutter Product Placements and Ordering

A Product remains Catalog-owned. A Placement is a tenant-scoped composition record
owned by one Section and contains only supported display overrides, `isVisible`,
`isFeatured`, and sort order. The same Product cannot have two active Placements in
the same Section but may appear in another Section. The Flutter screen reads the
Menu's authoritative Sections then lists each section's placements using
`GET /admin/menu-sections/{section}/placements?includeArchived=true`. It creates,
updates, moves only to eligible Sections in the same Menu, archives/restores and sends complete active section ordering with
the existing Menu Composition APIs. Hidden is not archived; Product archival is
also separate and remains diagnostic. Archived Menus and Sections prevent all
placement mutations. Assignments and schedules are deliberately not exposed until
Phase 4C.3; Preview, Publishing, Price Overrides, Availability, POS sync, and
Version History UI remain unimplemented.

`placementCount` is a diagnostic count of every non-archived Placement owned
by the same tenant and Section, including hidden Placements. It deliberately
does not mean visible/active Placement count; visibility is a separate
placement-level concern for Phase 4C.2.

## Phase 4C.3: Flutter Branch/Channel Assignments and Menu Schedules

Status: Complete. `/menu-management/assignments` requires an active tenant
Branch and one of the backend `SalesChannel` values. It lists assigned Menus and
eligible active, non-archived Menus separately. Assignment active state, Menu
lifecycle state, and schedule diagnostics are deliberately distinct. Scope sync
uses the complete transactional assignment set, so contiguous ordering, addition,
activation, and removal reload authoritative server state after success and restore
the previous visible order after a failed reorder.

The assignment `PUT` is a complete replacement of exactly one Branch + Channel
scope—not a partial update. Omitted assignments are permanently removed from that
scope only; their Menus, Sections, Placements, and other assignment scopes remain
unchanged.

Menu schedule rules remain directly owned by a Menu. The editor creates scoped
weekly/date/time/priority rules for the selected Branch/Channel, allows overnight
time periods, and preserves rules in other scopes during the Menu's complete rule
sync. No active scoped rules is shown as unrestricted. The selected Branch timezone
is displayed for context; this administration UI does not evaluate schedule status
in the local machine timezone. Rule omission follows the backend soft-delete sync
contract; Flutter must load and return all Menu rules so global/inherited and other
scope rules are preserved while only the exact selected scope is changed. There is
no individual restore endpoint. Preview, validation, publishing,
versions, price overrides, product availability, POS sync, authentication, combos,
and inventory remain out of this phase.

## Phase 4B.5: Flutter Product Archive, Restore and Catalog Finalization

Status: Complete after Flutter analyzer and full test suite pass. Products use
`POST /api/v1/admin/catalog/products/{product}/archive` and `/restore` with no
request payload. Archive is a soft delete: existing Orders and immutable
published snapshots are unchanged, and central Modifier Groups are not
deleted. Restore makes the Product editable again but does not publish it,
reassign it to Menus, restore archived Variants/Modifier Groups/Options, or
set operational availability.

The catalog retains server-side Active, Archived, and All filters across
lifecycle refreshes. `archivedAt`, not `isActive`, identifies archival; an
inactive Product is not automatically labelled archived. Archived details
remain diagnostic and read-only while preserving returned Variants and
Modifier assignments. The next Flutter increment is Phase 4C.2 Product
Placements; menu assignments and schedules follow in Phase 4C.3.

## Phase 4B.4: Flutter Product Modifier Assignment

Status: Complete after Flutter analyzer and full test suite pass. Route: `/menu-management/products/:productId/modifiers`. The assignment screen uses the Admin Catalog complete-sync API. Modifier Library owns shared Group and Option definitions; this screen only adds, removes, orders, and configures nullable product overrides. It labels Library Defaults, Product Overrides, and Effective Settings. Removing an assignment never deletes the Group or Options. Menu Builder, Availability, and publishing are still later phases; later publication snapshots use resolved assignments.

## Phase 4B.3: Flutter Modifier Library

Status: Complete after Flutter analyzer and tests pass. Routes are
`/menu-management/modifiers`, `/create`, `/:modifierGroupId`, and
`/:modifierGroupId/edit`. The central library owns reusable Modifier Groups and
their Options, with individual archive/restore and complete active-option
ordering. Option `priceDelta` is distinct from Variant `basePrice`.
Product Modifier Assignment and product-level overrides are implemented in
Phase 4B.4.

## Phase 4A: Flutter foundation and read-only Product Catalog

Status: Complete after the Flutter analyzer and full test suite pass.

The Windows Flutter application exposes `/menu-management`, which redirects to
`/menu-management/products`, and `/menu-management/products/:productId` for a
read-only product detail page. It uses the real tenant-scoped Admin Catalog
APIs: products, categories, reporting categories, and kitchen stations. List
filters, search, sorting, and pagination remain server-side; reference-data
failures do not prevent product-list use.

There is no mock Menu data or Menu repository. Phase 4A contains no create,
edit, archive, restore, variant, modifier, menu-builder, availability,
publishing, version-history, rollback, POS-sync, authentication, combo, or
inventory UI. Product editing, variants, and modifiers begin in Phase 4B.
POS continues to use the temporary `/api/v1/menu` Catalog API. Publishing UI
and authentication remain deferred.

## Phase 4B.1: Flutter Product General Editor

Status: Complete after the Flutter analyzer and full test suite pass.

Flutter now supports `/menu-management/products/create` and
`/menu-management/products/:productId/edit`. Create sends the Product general
fields plus exactly one required active Default Variant (`isDefault: true`,
`isActive: true`, `sortOrder: 0`) to `POST /api/v1/admin/catalog/products`.
The initial Variant name defaults to `Regular` but remains user-editable; a
standard Product requires its base price while an open-price Product can start
at zero.

General editing calls `PATCH /api/v1/admin/catalog/products/{product}` with
product fields only. It neither resends nor mutates Variants, and displays the
current Default Variant read-only. Full Variant/Pricing management starts in
Phase 4B.2. Modifier management, Menu Builder, Publishing UI, POS sync,
authentication, combos, and inventory remain unimplemented.

## Phase 4B.2: Flutter Product Variants and Base Pricing

Status: Complete. Flutter analyzer and full test suite pass.

`/menu-management/products/:productId/variants` manages a Product's active,
archived, and combined Variant lists. It supports create, edit, dedicated
Default selection, archive/restore, and complete active-list reordering. Base
Price and Cost Price are Variant fields; Branch and Channel Price Overrides
remain a later phase and are intentionally not shown in this UI.

Default selection always uses the dedicated endpoint. The Default Variant must
be active. Archiving the Default Variant requires choosing another active
Variant from the same Product; the only active Variant cannot be archived.
When a Product has no active Default Variant, restoring a Variant requires
`makeDefault: true` under the backend contract.

Every successful Variant mutation reloads Product Detail data and invalidates
the Product Catalog because the backend synchronizes the Default Variant's
base price, cost, SKU, and barcode into legacy Product fields for temporary POS
compatibility. Modifier Library management remains Phase 4B.3.

**Phase 1: Backend Menu Domain and Database Schema**

Status: Implemented — migrations and the full backend test suite pass in the backend container.

## Database environment safety

Phase 1 runtime verification previously used `cafe_system_618`, the development PostgreSQL database, because testing isolation was missing. That command may have deleted development data that was not recreated by seeders; no restoration is claimed by this repository.

Development uses `cafe_system_618`; Laravel tests and `--env=testing` migrations use only `cafe_system_618_testing`. Configure the ignored local `backend/.env.testing` from `backend/.env.testing.example` with the Docker PostgreSQL host, port, and local credentials, keeping `APP_ENV=testing` and `DB_DATABASE=cafe_system_618_testing`.

Create the test database once (from the repository root) without altering the development database:

```powershell
$exists = docker compose exec -T postgres psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'cafe_system_618_testing'"
if ($null -eq $exists -or $exists.Trim() -ne '1') { docker compose exec -T postgres createdb -U postgres cafe_system_618_testing }
```

Safe verification commands are `docker compose exec backend php artisan optimize:clear --env=testing`, `docker compose exec backend php artisan about --env=testing`, `docker compose exec backend php artisan migrate:fresh --seed --env=testing`, and `docker compose exec backend php artisan test`. Never run `migrate:fresh` against development or without `--env=testing`. An early Laravel configuration guard rejects the development database and non-test-suffixed names before destructive testing migrations can begin.

## Phase 2A: Backend Catalog APIs

Status: Complete only when the full backend suite passes. Phase 1 — Backend Menu Domain and Database Schema: Complete. Phase 1.5 — Isolated Testing Database: Complete. Phase 2A — Backend Catalog APIs: Complete. Phase 2B — Backend Menu Composition APIs: Complete. Phase 2C — Pricing and Availability APIs: Not started. Phase 3 — Preview, Validation, and Publishing: Not started.

Tenant Admin Catalog APIs are under `/api/v1/admin/catalog`, separate from the temporary POS `/api/v1/menu` namespace. They use the existing `TenantContext` (`X-Tenant-Id` and development first-tenant fallback); authentication remains deferred. The API manages Categories, Reporting Categories, Kitchen Stations, Products, Product Variants, Modifier Groups, Modifier Options, and reusable Product–Modifier Group assignments.

Product creation is transactional and requires one or more Variants with exactly one active Default Variant. The Default Variant mirrors its price, cost, SKU, and barcode into the legacy Product fields so the unchanged POS catalog still reads the correct values. Product and Variant archive/restore flows preserve records and order snapshots through soft deletes. Product references must be active and tenant-owned; archived reporting categories and kitchen stations cannot be newly assigned.

Modifier Groups are reusable. Their option counts, selection type, required minimum/maximum values, default options, and product-level overrides are validated before synchronization. Catalog changes are written to `menu_audit_logs` without using global observers.

## Phase 2B: Admin Menu Composition APIs

Tenant Admin Menu composition routes live under `/api/v1/admin/menus`; Product usage is available at `/api/v1/admin/catalog/products/{product}/menu-usage`. The controllers use the existing `TenantContext`, so `X-Tenant-Id` and the first-tenant development fallback remain in place and authentication is still deferred.

Menus are editable composition records, not Published snapshots. They support list filters (`search`, `status`, `branchId`, `channel`, `hasAssignments`), pagination, archive/restore, and transactional priority reordering. A restored Menu becomes `draft`; archival preserves all Sections, Placements, Assignments, and Availability Rules without affecting Catalog records.

Catalog Categories organize Products centrally. A Menu Section organizes the display of existing Products inside one Menu. A placement is display composition only: it references a Product and may override display name, description, or image, but never duplicates Product prices, Variants, Modifiers, kitchen routing, or reporting classification. Sections and placements are soft-deleted and can be restored; placements support reorder, move, and complete transactional synchronization.

Assignments are complete Branch/Channel configuration sets, allowing multiple Menus to target the same Branch/Channel and retaining a contiguous priority order. `GET`/`PUT /api/v1/admin/menu-management/assignments?branchId=&channel=` is the tenant-scoped scope contract used by Flutter: PUT receives the complete desired scope set (`menuId`, `priority`, `isActive`) and applies creation, activation, removal, and ordering atomically. Per-Menu `GET`/`PUT /api/v1/admin/menus/{menu}/assignments` remains available for Menu-scoped administration. Assignment removal does not archive its Menu or alter Sections, Placements, or immutable historical snapshots; assignments have no soft-archive/restore lifecycle in this contract.

Menu Availability Rules are Menu-owned complete schedule sets under `GET`/`PUT /api/v1/admin/menus/{menu}/availability-rules`; they do not belong to a Menu Assignment. Branch and Channel are optional in the backend, `dayOfWeek` is `0`–`6`, time pairs may cross midnight, and date/weekday constraints are conjunctive. The Flutter assignment screen fixes newly edited rules to its selected Branch/Channel and preserves all other Menu rules during sync. Omitted rules are soft-deleted by the backend sync and there is no independent rule restore endpoint. No active matching scoped rules means unrestricted—not unavailable. The UI displays the selected Branch timezone and does not evaluate effective schedule status using the local machine timezone. Preview, validation, publishing, history, pricing/availability overlays, and POS synchronization remain later phases.

Product Menu Usage returns active placement locations by default and accepts `includeArchived=true` for Admin diagnostics. All Menu composition changes write bounded before/after entries to `menu_audit_logs`, with `menu_publication_id = null`. Cross-tenant route resources return 404 and foreign submitted IDs return generic validation errors.

Pricing, Operational Availability, Preview, Publishing, snapshots, POS sync, Flutter, Authentication, Combos, Recipes, and Inventory remain untouched in Phase 2B. The temporary POS routes remain unchanged.

## Phase 2C.1: Variant Price Override APIs

Status: Complete only after the full backend test suite passes. Phase 2C.2 â€” Product Availability APIs: Not started.

Tenant Admin pricing routes are under `/api/v1/admin/catalog/product-variants/{variant}`:

- `GET /price-overrides` lists the non-archived overrides for a Variant.
- `PUT /price-overrides` transactionally synchronizes the complete set.
- `GET /effective-price?branchId=&channel=` previews the resolved price without changing the Variant, Product, or Order.

The supported scopes are `branch`, `channel`, and `branch_channel`. The client never submits a scope key; the backend constructs the canonical database key as `branch:{branchId|*}|channel:{channel|*}`. Branches must be active and owned by the current tenant, and channels use the `SalesChannel` enum. Duplicate canonical scopes are rejected.

Synchronization creates, updates, restores a same-scope soft-deleted override, and soft-archives any omitted active override in one transaction. Changes are logged in `menu_audit_logs` with `menu_publication_id = null`, using bounded scope and price data plus a summary.

Effective-price resolution is `branch_channel`, then `branch`, then `channel`, then the Variant `base_price`. Inactive, soft-deleted, foreign, and invalid/archived-branch overrides are ignored. Price Overrides never copy into `products.price` or `product_variants.base_price`; existing Order snapshots remain unchanged, and the temporary POS catalog does not consume overrides yet. Authentication remains deferred.

## Phase 4D.1: Flutter Variant Price Overrides

Status: Complete after Flutter analysis and the full Flutter suite pass. The desktop route is `/menu-management/products/:productId/variants/:variantId/pricing`, entered from active Variant Management rows. It displays Variant Base Price separately from configured overrides and supports exactly three scopes: Branch, Channel, and Branch + Channel. No global override is allowed because Base Price is the fallback.

The Flutter client loads the complete authoritative override list before permitting a draft change. `PUT /api/v1/admin/catalog/product-variants/{variant}/price-overrides` is complete synchronization, so it submits the entire intended set using only `scopeType`, `branchId`, `channel`, and `overridePrice`; it never sends tenant data, identifiers, computed scope keys, timestamps, or effective prices. Failed saves retain the local draft, while successful saves reload authoritative data. Duplicate normalized scopes are prevented locally and the Laravel validation result remains authoritative.

The Effective Price diagnostic calls `GET /api/v1/admin/catalog/product-variants/{variant}/effective-price` for selected active Tenant Branch and actual `SalesChannel` values. It displays backend `matchedScope` and never presents a client-calculated price as authoritative. Product or Variant archival makes the page read-only but keeps returned data diagnostic. Phase 4D.2 Scheduled Product and Variant Availability and Phase 4D.3A Operational Availability Overrides are complete. No Preview, Publishing, Version History, or POS Sync UI belongs to this phase.

## Phase 2C.2A: Scheduled Product Availability APIs

Status: Phase 2C.1 — Price Overrides: Complete. Phase 2C.2A — Scheduled Availability: Complete. Phase 2C.2B — Operational Availability: Complete only after the full backend test suite passes. Phase 3 — Preview, Validation, and Publishing: Not started.

`GET` and transactional `PUT /api/v1/admin/catalog/products/{product}/availability-rules` manage a Product's complete scheduled rule set. A rule with no `productVariantId` applies at Product level; a rule with a tenant-owned, non-archived Variant ID applies to that Variant only. Product and Variant rules may each target the global scope, a Branch, a Sales Channel, or an exact Branch + Channel pair. Branches must be active and tenant-owned; channels use `SalesChannel`.

`GET /api/v1/admin/catalog/products/{product}/availability-preview` is a narrow Admin diagnostic endpoint. It evaluates only saved scheduled rules at a supplied date/time. When `branchId` is supplied, evaluation uses that Branch's timezone; otherwise it uses the submitted timezone or application timezone.

Rules are positive availability windows. No applicable configured schedule means unrestricted availability. If a matching Variant-level scope exists it governs before Product-level rules; then Branch + Channel, Branch, Channel, and Global select the governing scope. Within that scope, a matching window with the highest priority wins. If its configured scope has no matching window at the requested time, availability is false with `outside_schedule`. Weekly day rules and date ranges are both conjunctive when present. A `22:00`â€“`02:00` rule is anchored on the starting date/day and correctly remains available after midnight. Rules are soft-deleted on synchronization omissions and audit to `menu_audit_logs` with no publication ID.

Scheduled availability is intentionally separate from Operational Sold Out/remaining quantity tables. The current POS does not consume these rules, and authentication remains deferred.

## Phase 2C.2B: Operational Availability and Sold Out APIs

Operational Availability is an immediate mutable runtime overlay, entirely separate from scheduled availability, structural product status, menu visibility, inventory, and publishing. Admin routes under `/api/v1/admin/catalog` manage Product- and Variant-level overrides for one active tenant Branch and either a `SalesChannel` or the internal `all` channel scope. `all` is not a public `SalesChannel` value; it means every channel in the selected Branch.

For a Variant request, resolution is deterministic: Variant + exact Channel, Variant + all Channels, Product + exact Channel, Product + all Channels, then no override (available). An explicit narrower `available` row therefore overrides a broader `sold_out` row. Expired non-available records (`unavailableUntil <= evaluated time`) are ignored but retained for diagnostics; evaluation uses the Branch timezone. The resolver intentionally does not inspect scheduled rules. A combined resolver belongs to a later preview/publishing phase.

Overrides support `available`, `sold_out`, and `temporarily_unavailable`. Temporary unavailability requires a future expiration. `available` normalizes reason and expiration to null. `remainingQuantity` is returned and audited but informational only: it is not deducted by Orders, does not infer sold-out state, and has no Inventory integration. PUT upserts a unique Product/Variant + Branch + Channel scope transactionally; DELETE clears only that exact runtime row and is idempotent. Changes use bounded audit snapshots in `menu_audit_logs` with no publication ID.

The list and single-product diagnostic preview endpoints are Admin-only. Archived Product/Variant records are hidden from the list by default (with `includeArchived=true` for diagnostics). POS does not consume operational overlays yet, and authentication remains deferred.

## Phase 3A: Menu Publish Validation

`POST /api/v1/admin/menus/{menu}/validate` validates one editable Menu for an active Branch and Sales Channel. `POST /api/v1/admin/menu-management/validate` validates supplied `menuIds`, or every active Menu Assignment for that Branch and Channel when IDs are omitted. Both return stable machine-readable issues grouped as `errors`, `warnings`, and `information`, plus a per-Menu summary. Errors are the only severity that blocks future publishing; warnings and information are diagnostic.

Validation is strictly read-only: it creates no audit logs, publications, versions, snapshots, or repairs. It reuses the price, scheduled availability, and operational availability resolvers using the Branch timezone. Base-price fallback, scheduled outside-window state, active sold-out state, absent Menu schedules, hidden placements, and legacy size-like modifier groups are warnings. Empty active Sections are also warnings when another Section can still provide visible placements. Missing/archived Categories and invalid catalog or modifier configurations are errors; missing reporting categories and kitchen stations are warnings.

The phase validates only editable data readiness. Publishing, snapshots, POS sync, Flutter, authentication, combos, and Inventory remain unimplemented. Status: Phase 3A — Menu Validation: Complete. Phase 3B — Menu Preview: Complete. Phase 3C — Publishing and Snapshots: Not started.

## Domain boundaries

`products` is the canonical Catalog Item entity. No `items`, `menu_items`, or `catalog_items` table exists. `product_variants` are sellable versions of a Product, beginning with one `Regular` Default Variant for each legacy Product.

`categories` organize the Catalog. `reporting_categories` are a separate sales and analytics classification. `menu_sections` organize display within a Menu, while `menu_item_placements` define a Product's appearance inside a Section. Placements never copy product pricing, variant, or modifier definitions.

```text
Central Catalog (products)
  -> Product variants and modifiers
  -> Menu composition (menus, sections, placements)
  -> Branch/channel assignments and availability rules
  -> Future draft validation, preview, and publishing
  -> Immutable published menu version
  -> Future POS sync + operational sold-out overlay
```

## Phase 1 schema

Reference tables: `reporting_categories` and tenant/optional-branch `kitchen_stations`.

Existing `products` has nullable localized names/descriptions, `product_type`, reporting category, kitchen station, and preparation time. Legacy `products.price`, `cost_price`, `sku`, and `barcode` remain temporarily so the POS Catalog API continues to work. New domain code will use `product_variants` in later phases.

The product-variants migration backfills a Default `Regular` Variant for each existing Product, including inactive Products, without changing IDs, prices, orders, or legacy Product fields. Existing Modifier Groups named Size, Sizes, or Cup Size are intentionally untouched; they require an explicit migration or manual review in a later phase.

Modifier groups now distinguish business purpose (`group_type`: choice, add_on, preparation_instruction) from selection behavior (`selection_type`: single/multiple). Options add `cost_delta` and structural `is_active`; the legacy operational `is_available` remains. Product/group pivot overrides and order-item-modifier quantity are additive.

Menu composition adds `menus`, `menu_sections`, `menu_item_placements`, and `menu_assignments`. Pricing adds `product_variant_price_overrides`, using a non-null canonical scope key. Scheduled availability uses explicit menu and product rule tables. Immediate operational availability is separate in product and variant operational availability tables; absent rows mean no operational override.

Publishing preparation adds `menu_publications`, immutable-intent `published_menu_versions`, and `menu_audit_logs`. Orders can later reference a Variant and a Published Menu Version while retaining their existing immutable product and price snapshots.

## Deferred application invariants

Portable database constraints cannot fully express tenant ownership and temporal domain rules. Phase 2 use cases must enforce: sellable active Products have active Variants; each Product has exactly one active Default Variant; related Products, Variants, Modifiers, Menus, Sections, Placements, Assignments, Branches, and Users share a Tenant; a Variant availability rule belongs to its Product; only one version is current per Tenant/Branch/Channel; and published payloads are immutable.

## Explicitly not included

No Admin Menu APIs, publish service, preview, snapshot generation, POS sync, Flutter Menu Management, authentication change, Combo logic, recipes, inventory/sold-out automation, or delivery integrations are implemented in this phase. The current POS endpoints remain temporary and use legacy Product fields:

- `GET /api/v1/menu/categories`
- `GET /api/v1/menu/products`
- `GET /api/v1/menu/products/{product}`

## Phase 3C.1: Publishing and Immutable Snapshots

Status: Phase 3A — Validation: Complete. Phase 3B — Preview: Complete. Phase 3C.1 — Publishing and Snapshots: Complete. Phase 3C.2 — Version History and Rollback: Not started.

`POST /api/v1/admin/menu-management/publish` publishes active assigned Menus for one tenant Branch and Sales Channel. `GET /api/v1/admin/menu-management/current-version?branchId=&channel=` returns current Version metadata only. Validation errors create a failed Publication and return 422; warnings permit publishing. Each flow records a pending Publication, validates, takes a PostgreSQL advisory transaction lock for its tenant/branch/channel scope, creates a deterministic static snapshot, and hashes canonical JSON with SHA-256. Changed payloads supersede the previous current Version; identical checksums record a no-change Publication without a duplicate Version. Database uniqueness additionally guarantees one current Version per scope.

Snapshots contain static localized Menu composition, active visible catalog records, schedule rules, effective Branch/Channel Variant prices, modifiers, and ordering. They deliberately exclude operational sold-out/temporary availability, remaining quantity, evaluated availability/sellability values, Preview time/context, and validation diagnostics. Authentication remains deferred. Version History, comparison, rollback, POS snapshot consumption/sync, Flutter, Combos, and Inventory remain unimplemented.

## Phase 3B: Resolved Menu Preview

Status: Phase 3A — Menu Validation: Complete. Phase 3B — Menu Preview: Complete. Phase 3C — Publishing and Snapshots: Not started.

`POST /api/v1/admin/menus/{menu}/preview` resolves one tenant-owned Menu and `POST /api/v1/admin/menu-management/preview` resolves supplied `menuIds`, or every actively assigned Menu for the requested Branch and Sales Channel when IDs are omitted. These are Admin diagnostics only; POS does not consume Preview. Requests accept `branchId`, a `SalesChannel` `channel`, optional `at`, `language` (`default`, `ar`, or `en`), `includeUnavailable` (default true), and `includeHidden` (default false). Branches must be active and tenant-owned; a cross-tenant route Menu returns 404 and foreign submitted IDs return 422. Authentication remains deferred.

The response is resolved, not persisted: it contains timezone context, `canPublish`, the existing validation result, and Menus with assignment/schedule state, Sections, Placements, Products, Variants, and active Modifier Groups/Options. It never creates a publication, version, snapshot, audit event, or availability row, and does not update timestamps or order data.

Menu schedules are positive windows. Active non-archived rules select Branch + Channel, Branch, Channel, then Global scope; the highest-priority matching rule within the governing scope applies. A governing scope with no matching window is unavailable, while no applicable active rule is unrestricted. Weekdays and date ranges are conjunctive, including overnight periods anchored to their starting date/day.

Preview reuses the existing effective price, product schedule, and operational availability resolvers. A Variant is sellable only when structurally active, scheduled available, operationally available, and validly priced. A Product also requires a visible Placement and at least one sellable Variant; Inventory is not considered. Hidden placements are omitted by default and retained diagnostically with `hidden` when requested. Unavailable Products remain by default and can be filtered with `includeUnavailable=false`, without hiding validation issues. Placement text overrides localized Product text; otherwise requested language, default, then other localized values are used without writes. Archived Modifier Groups/Options are excluded, active unavailable options retain `isAvailable`, and pivot overrides are applied. Publishing, snapshots, POS sync, Flutter, Combos, and Inventory remain untouched.

## Phase 3D Version History, Comparison, and Rollback

Admin Version history and detail are tenant-scoped; detail returns immutable snapshot payload only with `includePayload=true`. Comparisons are bounded structural summaries. Historical checksums are deliberately non-unique so rollback can create a new immutable Version with an older payload. A rollback never reactivates history: it marks the prior current Version `rolled_back` and creates a new current Version under the advisory lock. The one-current-per-scope constraint remains enforced. Authentication is deferred and POS Sync remains unimplemented.

## Phase 4D.2: Flutter Scheduled Product and Variant Availability

Status: Complete after Flutter analysis and tests pass. Flutter integrates `GET`/`PUT /api/v1/admin/catalog/products/{product}/availability-rules` and `GET /api/v1/admin/catalog/products/{product}/availability-preview`. The real contract intentionally has no separate Variant path: `productVariantId: null` is Product-level and a tenant-owned Variant ID is Variant-level. The PUT endpoint replaces the Product's complete rule set, so the client permits edits only after an authoritative load and always sends every retained Product and Variant rule on save.

Rules support the backend fields `productVariantId`, `branchId`, `channel`, one `dayOfWeek` (`0`–`6`), `startTime`, `endTime`, `startDate`, `endDate`, `priority`, and `isActive`. The screen presents Global, Branch, Channel, and Branch + Channel scopes; it does not invent timestamps, branch names, multiple weekdays, or variant endpoints absent from the resource. Preview remains backend-authoritative, using a supplied Branch timezone when a Branch is selected. Variant scope presence governs before Product rules, then Branch + Channel → Branch → Channel → Global. No governing rules means unrestricted; a governing scope with no matching rule window is `outside_schedule`; overnight windows are anchored to their starting date/day. Product or selected Variant archival makes mutation controls read-only. Operational overrides remain a separate runtime overlay.

## Phase 4D.3A: Flutter Operational Availability Overrides

Status: Complete after Flutter analysis and the full Flutter suite pass. Flutter integrates `GET /api/v1/admin/catalog/operational-availability` with `level`, `includeArchived`, and pagination, then filters returned records by the selected Product or Variant. It uses `PUT` and `DELETE /api/v1/admin/catalog/products/{product}/operational-availability` for Product records and the matching `/product-variants/{variant}/operational-availability` endpoints for Variant records. Clear requests contain only `branchId` and `channel`.

Operational overrides are mutable runtime overlays, not Scheduled Availability rules or immutable Published Snapshot data. The actual API requires an active tenant-owned Branch and either an actual `SalesChannel` or `all`; `all` means all channels in the required Branch and there is no branchless global override. Product and Variant records remain separate. The backend resolver, rather than Flutter, owns precedence: Variant exact Channel, Variant all Channels, Product exact Channel, Product all Channels, then Available. A narrower explicit `available` record can override a broader Sold Out record without removing it.

The Flutter editor supports `available`, `sold_out`, and `temporarily_unavailable`; temporary records submit `unavailableUntil` and the backend evaluates that timestamp in the Branch timezone. Expired records are retained and visibly diagnostic, never auto-cleared. `remainingQuantity` accepts null or zero-or-greater numeric metadata and is explicitly not Inventory synchronization or status automation. Product archive makes every mutation read-only, while Variant archive leaves Product-level overrides editable when the Product remains active.

## Phase 4D.3B: Flutter Operational Resolution Diagnostic

The existing Operational Availability route now includes a Backend-authoritative diagnostic. Product context sends `branchId` and a real `SalesChannel` to `GET /api/v1/admin/catalog/products/{product}/operational-availability-preview`; Variant context additionally sends `productVariantId` to that same actual endpoint. The API returns the resolved status, availability flag, matched level/scope/record, reason, optional quantity, and optional expiration. Flutter does not calculate precedence. It presents exact-channel and `all`-scope matches distinctly, makes an explicit Available override distinct from an Available fallback, and keeps expired temporary records visible but never calls them an active match. `all` remains an override scope rather than a runtime selector. Operational resolution remains independent of Scheduled Availability, publishing state, Inventory, and immutable snapshots; it is not a combined sellability result. Phase 4E — Validation, Preview and Publishing remains not started.
