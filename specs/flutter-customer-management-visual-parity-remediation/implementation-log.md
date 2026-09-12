# Implementation Log: Flutter Customer Management — Visual Parity Remediation

## 2026-09-12 T066-T084 verification checkpoint

The golden harness was corrected to render the current Flutter composition at
the test boundary: an authenticated server-capability session, the existing
`AppShell`/sidebar, `AppTopBar`, and `CustomerManagementScaffold` now surround
the deterministic Customer Management fixtures. No production route, Cubit,
repository, API, or payload behavior was changed by this correction. The
baselines were regenerated with the same pinned Windows widget-test renderer.

The owned baseline inventory is 81 PNGs:

| Owner | Routes/states | Locale/direction | Viewports | Artifact root | Review checkpoint |
| --- | --- | --- | --- | --- | --- |
| Customer screens | list, detail, create, edit | English/LTR and Arabic/RTL | 1440x900, 1280x800, 500x800 | `windows_application/test/features/customer_management/goldens/baselines/customer_screens/` | Representative list review: rejected pending full matrix acceptance |
| Group screens | group list, detail, create, edit | English/LTR and Arabic/RTL | 1440x900, 1280x800, 500x800 | `windows_application/test/features/customer_management/goldens/baselines/customer_group_screens/` | Representative group-list review: rejected pending full matrix acceptance |
| Dialogs | Add Members, lifecycle, member removal, unsaved change | English/LTR and Arabic/RTL | 1440x900, 1280x800, 500x800 | `windows_application/test/features/customer_management/goldens/baselines/customer_dialogs/` | Representative Add Members review: rejected pending full matrix acceptance |
| State matrix | customer/group collections, loading, empty, no-results, forbidden, not-found, validation, pending progress | English/LTR | 1280x800 | `windows_application/test/features/customer_management/goldens/baselines/customer_states/` | Representative error/create review: rejected pending full matrix acceptance |

Side-by-side reference checkpoints used `01_customer_list.png`,
`04_customer_list_error.png`, `07_customer_groups_list.png`, and
`13_customer_create.png` from
`windows_application/design_refs/customer_management_design_reference/screens/`.
The corrected artifacts now include the existing shell/sidebar and module tabs.
The supplied references still contain prototype-only preview navigation and
data-dependent demo rows; those are intentional exclusions under the spec.
Because every mandatory baseline has not received an explicit accepted review
record, the reviewer result remains `rejected`/unaccepted for T072 and T073,
with checkpoint date 2026-09-12. Automated pixel comparison is not being used
as visual acceptance.

Serial verification after the shell-mounted regeneration:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test --concurrency=1 test/features/customer_management/goldens/customer_screens_golden_test.dart` | 0 | 24 baselines compared. |
| `flutter test --concurrency=1 test/features/customer_management/goldens/customer_group_screens_golden_test.dart` | 0 | 24 baselines compared. |
| `flutter test --concurrency=1 test/features/customer_management/goldens/customer_dialogs_golden_test.dart` | 0 | 24 baselines compared. |
| `flutter test --concurrency=1 test/features/customer_management/goldens/customer_states_golden_test.dart` | 0 | 9 baselines compared. |
| `flutter test test/features/customer_management/customer_management_scope_guard_test.dart` | 0 | Extended prototype/data/authority exclusions pass. |
| `dart format --output=none --set-exit-if-changed` on changed presentation/golden/test paths | 0 | 55 files checked, 0 changed. |
| Scoped `flutter analyze` on changed presentation/golden/test and route/shell paths | 0 | No issues found. A directory-wide run also reports one pre-existing info at `repositories/customer_management_repository_test.dart:266`; it is outside the presentation remediation. |
| `flutter test --concurrency=1 test/features/customer_management` | 0 | 127 passed, 0 failed. |
| Route/shell regression list from T077, serially | 0 | Routing 4, top refresh 1, request topology 4, bilingual shell 8, sidebar auth 8, form navigation 1; 26 total. |
| `git diff --check` | 0 | No whitespace errors; Git emitted only LF/CRLF working-copy warnings. |

The Windows build was attempted with `flutter build windows`; after roughly
70 seconds with no output it was interrupted (exit 1), no Release executable
was produced, and only a pre-existing Debug executable was present. The Web
build was likewise silent for roughly 70 seconds and was interrupted (exit 1);
`build/web/main.dart.js` remained stale at 2026-09-08 and was not treated as a
current artifact. T079 and T080 therefore remain unpassed.

The final path review confirms that visual-remediation edits are confined to
Customer Management presentation/localization/test/golden assets and this
feature's spec/log artifacts. Backend, database, deployment, repository,
Cubit, route-contract, global-theme, and unrelated dirty-worktree paths were
not reset or overwritten. The only test-only fixture values are in the golden
test directory, and the production scope guard reports no prototype data,
hard-coded presentation copy, tenant header, phone/number authority,
unsupported metrics/history/orders, or group status editor. T082 and T083 are
complete; T084 remains open because T072/T073/T078 visual acceptance and the
two platform build gates are unresolved.

## 2026-09-12 resumed US1 checkpoint (T018-T024)

T018-T020 were resumed from their pending checklist state. The tests were first
extended as presentation red coverage, then the existing Customer Management
routes were updated to use the scoped `cmvp*` hierarchy copy. Static group routes
were placed before the generic customer-id route so `/customers/groups` and its
children retain their existing identities instead of being interpreted as a
customer id. The shared scaffold now exposes a stable content anchor; no Cubit,
repository, API, authorization, or payload semantics were changed.

Serial verification from `windows_application`:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/app/customer_management_routing_test.dart` | 0 | 4 passed, including all eight direct route identities, selected tabs, localized hierarchy, and existing route targets. |
| `flutter test test/features/customer_management/views/customer_management_scaffold_test.dart` | 0 | 3 passed across resize, narrow layout, Arabic/RTL, and child identity. |
| `flutter test test/features/customer_management/customer_management_access_test.dart` | 0 | 2 passed; capability remains server-authoritative and role names do not grant access. |
| `flutter test test/shared/widgets/app_sidebar_auth_test.dart` | 0 | 8 passed; owner/manager capability grant, refresh, and revocation remain fail-closed. |

The route loop consumes unrelated pre-existing shell layout exceptions after
each navigation so route identity assertions are not confused with the later
collection/layout work; those layout issues remain subject to the dedicated
US2/US5 checks.

T024 is complete on the user's local verification. The ARB parity check
completed with valid JSON and 58 matching `cmvp*` keys in each locale
(`missing_en=` and `missing_ar=` empty), and the generated accessors expose the
new keys. The user supplied a completed local `flutter gen-l10n` run from
`windows_application`; its output reports `ar: 120 untranslated message(s)`
and points to the optional `untranslated-messages-file` report setting. This
is a localization coverage warning, not a generation failure, and it does not
block the generated Customer Management accessors.

The non-interactive agent probe produced no output and was interrupted after
45 seconds (exit 1); it is recorded as an environment/interactive caveat and
not substituted for the user's successful local run.

This log records current evidence for the visual-parity remediation only. Existing
dirty-worktree changes are user-owned and remain protected.

## T024-T025 completion checkpoint (2026-09-12)

T024 is marked complete from the user's local `flutter gen-l10n` verification.
The command reported `ar: 120 untranslated message(s)` and the optional
`untranslated-messages-file` setting; this is a translation-coverage warning,
not a generator failure. The agent's non-interactive probe remained silent and
was interrupted after 45 seconds, so that separate caveat is not presented as
local generation evidence.

T025 was run serially from `windows_application`:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/app/customer_management_routing_test.dart` | 0 | 4 passed. |
| `flutter test test/features/customer_management/views/customer_management_scaffold_test.dart` | 0 | 3 passed. |
| `flutter test test/features/customer_management/customer_management_access_test.dart` | 0 | 2 passed. |
| `flutter test test/shared/widgets/app_sidebar_auth_test.dart` | 0 | 8 passed. |
| `flutter test test/features/customer_management/customer_form_navigation_test.dart` | 0 | 1 passed. |

No route, capability, scaffold, or unsaved-navigation regression was observed.

## T026-T036 US2 collection checkpoint (2026-09-12)

Red coverage was added before the collection edits for the exact 760/759
breakpoint, long bilingual values, supported fields/exclusions, group/member
records, authoritative result counts, and pagination metadata/direction. The
initial serial red results were attributable to missing `CustomerManagementSurface`,
missing result counts, missing pagination footer identity, and one test-side
tooltip cast that was corrected before the green rerun.

Implemented presentation-only changes:

- Customer and group collections now use the shared bordered surface and switch
  to card records below 760 logical pixels; group cards use a local transparent
  Material so ListTile ink behavior remains valid inside the decorated surface.
- Member records use the same surface vocabulary and retain only authoritative
  customer identity, primary raw phone, lifecycle, view, and remove actions.
- Pagination now exposes a stable integrated footer, preserves `CustomerPageMeta`
  as its only source of page state, wraps at narrow widths, and mirrors icons in
  RTL.
- Customer and group list filters are surfaced in bordered containers and show
  localized counts from response metadata. Existing Cubit/repository callbacks,
  bounded queries, filters, page resets, and lifecycle actions were not changed.

Serial green verification after implementation and formatting:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/features/customer_management/widgets/customer_collection_test.dart` | 0 | 3 passed. |
| `flutter test test/features/customer_management/widgets/customer_group_components_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/widgets/customer_pagination_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/views/customer_list_screen_test.dart` | 0 | 7 passed. |
| `flutter test test/features/customer_management/views/customer_group_screens_test.dart` | 0 | 2 passed. |

T036 reused the existing matching localized `cmvp*` vocabulary verified at
T024; no new unsupported copy or prototype field was introduced.

## T038-T047 US3 and deferred regression checkpoint (2026-09-12)

The detail/form red checkpoint was exercised with missing raw-number and form
surface anchors; those assertions failed before the corresponding keys were
implemented. The green implementation uses four responsive detail surfaces,
localized information/phone/group/notes section headings, and a keyed
constrained form surface. Existing backend-returned values, raw phones,
read-only customer number, archived groups, validation, single-flight save,
and dirty-navigation behavior remain unchanged.

T037 was run serially after the T046 localization checkpoint:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/features/customer_management/widgets/customer_collection_test.dart` | 0 | 3 passed. |
| `flutter test test/features/customer_management/widgets/customer_group_components_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/widgets/customer_pagination_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/views/customer_list_screen_test.dart` | 0 | 7 passed. |
| `flutter test test/features/customer_management/views/customer_group_screens_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/controllers/customer_list_cubit_test.dart` | 0 | 8 passed. |
| `flutter test test/features/customer_management/controllers/customer_group_list_cubit_test.dart` | 0 | 4 passed. |
| `flutter test test/features/customer_management/repositories/customer_management_repository_test.dart` | 0 | 9 passed. |

T047 was also run serially:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/features/customer_management/views/customer_detail_screen_test.dart` | 0 | 3 passed. |
| `flutter test test/features/customer_management/views/customer_form_screen_test.dart` | 0 | 8 passed. |
| `flutter test test/features/customer_management/customer_form_navigation_test.dart` | 0 | 1 passed. |
| `flutter test test/features/customer_management/controllers/customer_detail_cubit_test.dart` | 0 | 5 passed. |
| `flutter test test/features/customer_management/controllers/customer_form_cubit_test.dart` | 0 | 10 passed. |
| `flutter test test/features/customer_management/controllers/customer_lifecycle_cubit_test.dart` | 0 | 6 passed. |

## T066-T073 golden checkpoint (2026-09-12)

The deterministic golden harness loads the bundled Manrope and IBM Plex Sans
Arabic fonts, pins locale/direction, viewport, DPR, Material theme, and test
fixtures, and owns the required screen, group-screen, dialog, and state-matrix
test files. The four golden tests generated 81 PNGs under
`windows_application/test/features/customer_management/goldens/baselines/`:
24 customer-screen rows, 24 group-screen rows, 24 dialog rows, and 9 state
rows. Generation used the Flutter widget-test renderer with
`flutter test --update-goldens`; the four comparison commands then passed with
exit 0 and one test case per matrix owner.

Representative side-by-side review was performed against the supplied
`01_customer_list.png` reference. The generated content-only harness image is
not accepted: it intentionally omits the existing AppShell/sidebar context and
uses deterministic test identities rather than the reference's data-dependent
prototype rows. The same exclusion applies to the remaining generated rows
until the harness is mounted at the real shell geometry and each required
reference comparison is reviewed. Therefore T067-T071 are complete as test and
artifact ownership, but T072 remains open with a documented `rejected` review
result, and T073 is not marked complete. Automated pixel comparison passing is
not treated as visual acceptance.

Golden comparison commands (serial, current evidence):

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/features/customer_management/goldens/customer_screens_golden_test.dart` | 0 | 1 matrix owner passed; 24 baselines compared. |
| `flutter test test/features/customer_management/goldens/customer_group_screens_golden_test.dart` | 0 | 1 matrix owner passed; 24 baselines compared. |
| `flutter test test/features/customer_management/goldens/customer_dialogs_golden_test.dart` | 0 | 1 matrix owner passed; 24 baselines compared. |
| `flutter test test/features/customer_management/goldens/customer_states_golden_test.dart` | 0 | 1 matrix owner passed; 9 baselines compared. |

## T057-T065 US5 state checkpoint (2026-09-12)

The US5 red checkpoint initially failed because the state panel had no geometry
contract or loading skeleton API. The state matrix and accessibility additions
then verified distinct empty/no-results, retryable, forbidden, not-found, and
validation treatments, authorized recovery actions, Arabic/RTL mixed-direction
values, and narrow action reachability. The implementation adds inert geometry-
specific loading skeletons with a loading semantic announcement, distinct icon
and copy treatments, and preserves stale collections during refresh with a
direction-neutral linear progress indicator. Existing real Cubit handlers remain
the source of create, clear, retry, load, and mutation transitions.

The existing `cmvp*` English/Arabic state vocabulary was already present and
generated at T024/T046. No new ARB key was required at this checkpoint. The
user's local `flutter gen-l10n` evidence remains the controlled generation
record: valid generated accessors plus the non-blocking Arabic 120-untranslated
coverage warning; the agent's separate non-interactive probe was interrupted
after 45 seconds and is not represented as a pass.

Serial verification:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/features/customer_management/widgets/customer_management_state_panel_test.dart` | 0 | 3 passed across collection/detail/form geometry and 1440x900, 1280x800, 500x800, 760, and 759 sizes. |
| `flutter test test/features/customer_management/customer_management_state_matrix_test.dart` | 0 | 5 passed across empty/no-results, validation, forbidden/not-found, and retryable refresh states. |
| `flutter test test/features/customer_management/customer_management_accessibility_test.dart` | 0 | 3 passed across tooltip semantics, narrow actions, Arabic/RTL, and overflow checks. |
| `flutter test test/features/customer_management/customer_management_scope_guard_test.dart` | 0 | 1 passed after tightening prototype-only token matching and adding tenant/fake-id guards. |
| `flutter test test/features/customer_management/controllers/customer_group_list_cubit_test.dart` | 0 | 4 passed. |

T057 and T058-T065 are recorded as complete for the focused state checkpoint.
Golden generation/review and full platform/build closure remain later gates.

## T048-T051 and T086 US4 group checkpoint (2026-09-12)

The group detail/form red checkpoint first failed on missing identity/date,
member-surface, and keyed name-only form anchors. The shared confirmation red
checkpoint first failed to compile against the pending-state contract. The
candidate dialog checkpoint exposed an intrinsic-dimension failure when a lazy
results viewport was placed in an unconstrained `AlertDialog`; the final dialog
uses a viewport-aware bounded size. One initial membership assertion was
corrected because the existing dialog title and action intentionally shared the
same localized phrase; the production behavior was then verified through the
stable action key and localized selection count.

Implemented US4 presentation changes preserve the existing group/member Cubits,
bounded queries, selection ownership, lifecycle callbacks, name-only form
contract, and authoritative refresh behavior. Group detail now has identity/date
and bounded member-control surfaces, group forms use a constrained name-only
surface, candidate dialogs expose localized search/empty/loading/selection and
mutation states, and confirmations share keyed cancel/confirm/pending styling.
The shared page header wraps identity/status content at narrow widths. Form
navigation now delegates directly to the existing guarded navigation controller
when scoped, avoiding a duplicate confirmation while retaining the unscoped
fallback.

Serial verification:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/features/customer_management/views/customer_group_screens_test.dart` | 0 | 3 passed. |
| `flutter test test/features/customer_management/views/customer_group_form_screen_test.dart` | 0 | 1 passed. |
| `flutter test test/features/customer_management/views/customer_group_membership_test.dart` | 0 | 1 passed. |
| `flutter test test/features/customer_management/widgets/customer_confirmation_dialog_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/views/customer_group_lifecycle_test.dart` | 0 | 1 passed; confirmation remains non-optimistic. |
| `flutter test test/features/customer_management/controllers/customer_group_membership_cubit_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/controllers/customer_group_detail_cubit_test.dart` | 0 | 3 passed. |
| `flutter test test/features/customer_management/controllers/customer_group_form_cubit_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/customer_form_navigation_test.dart` | 0 | 1 passed; stay, Escape dismissal, draft retention, resize, and confirmed leave remain green. |

T048-T051, T052-T056, and T086 are recorded as complete for this focused US4
checkpoint. T057 remains deferred until the US5 localization/state checkpoint
as required by the task dependency order.

## T001 — Initial scope and worktree baseline

- Date/checkpoint: 2026-09-12, before remediation edits.
- Repository root: `C:/Users/Rami/Desktop/Important Files/CAFE SYSTEM/cafe_backend`.
- Current branch: `feaature/customar-managment`.
- Feature directory from `.specify/feature.json`: `specs/flutter-customer-management-visual-parity-remediation`.
- Permitted remediation boundary: `windows_application/lib/features/customer_management/` presentation files, `windows_application/lib/l10n/` resources and generated localization output at named checkpoints, `windows_application/test/` Customer Management visual/widget tests and golden assets, and this feature log/spec artifacts. Backend, database, deployment, API/query/payload, repository, Cubit, route-contract, global-theme, and unrelated worktree changes are out of scope.
- Protected initial dirty-worktree paths (captured by `git status --short`):
  - `.specify/memory/constitution.md`
  - `.specify/templates/plan-template.md`
  - `.specify/templates/spec-template.md`
  - `.specify/templates/tasks-template.md`
  - `backend/app/Http/Controllers/Api/AuthController.php`
  - `backend/app/Http/Controllers/Api/CustomerController.php`
  - `backend/app/Http/Controllers/Api/PosOrderController.php`
  - `backend/app/Services/SaleConsumptionService.php`
  - `backend/bootstrap/app.php`
  - `backend/database/seeders/CustomerAndTableSeeder.php`
  - `backend/routes/api.php`
  - `backend/tests/Feature/Admin/MenuManagement/FullMenuManagementLifecycleApiTest.php`
  - `backend/tests/Feature/AuthPhaseOneTest.php`
  - `backend/tests/Feature/DiscountRuntimeEligibilityTest.php`
  - `backend/tests/Feature/InventoryCenterApiTest.php`
  - `backend/tests/Feature/ProductInventoryTrackingE2ETest.php`
  - `backend/tests/Feature/TenantTaxAndValidationTest.php`
  - `docker-compose.yml`
  - `windows_application/lib/app/app_router.dart`
  - `windows_application/lib/app/app_shell.dart`
  - `windows_application/lib/core/services/service_locator.dart`
  - `windows_application/lib/features/auth/models/auth_session.dart`
  - `windows_application/lib/l10n/app_ar.arb`
  - `windows_application/lib/l10n/app_en.arb`
  - `windows_application/lib/l10n/app_localizations.dart`
  - `windows_application/lib/l10n/app_localizations_ar.dart`
  - `windows_application/lib/l10n/app_localizations_en.dart`
  - `windows_application/lib/shared/widgets/app_sidebar.dart`
  - `windows_application/test/app_shell_bilingual_test.dart`
  - `windows_application/test/features/auth/auth_session_cubit_test.dart`
  - `windows_application/test/shared/widgets/app_sidebar_auth_test.dart`
  - Existing untracked Customer Management/backend paths shown by the same snapshot are also protected, including `backend/app/Domain/Customer/`, `backend/app/Http/Controllers/Api/Admin/CustomerManagement/`, `backend/app/Http/Controllers/Api/CustomerCapabilityController.php`, `backend/app/Http/Controllers/Api/CustomerGroupLookupController.php`, `backend/app/Http/Middleware/EnsureCustomerPermission.php`, `backend/app/Http/Requests/Customer/`, `backend/app/Http/Resources/Customer/`, `backend/app/Models/Customer.php`, `backend/app/Models/CustomerGroup.php`, `backend/app/Models/CustomerPhone.php`, `backend/app/Services/Customer/`, the two Customer migrations, `backend/tests/Feature/Customer/`, `backend/tests/Fixtures/ConcurrentCustomerEligibilityWorker.php`, `backend/tests/Unit/Customer/`, `plans/`, `specs/`, `windows_application/design_refs/customer_management_design_reference/`, `windows_application/lib/app/customer_management_route_locations.dart`, `windows_application/lib/features/customer_management/`, `windows_application/test/app/customer_management_routing_test.dart`, `windows_application/test/features/auth/auth_session_storage_contract_test.dart`, and `windows_application/test/features/customer_management/`.

T001 is complete when this baseline remains unchanged except for explicitly scoped
remediation files and this log.

## T002 — Route, screen, and guarded-navigation inventory

The existing route contract contains eight Customer Management routes. All are
mounted inside the existing `ShellRoute`/`AppShell` and are selected by the current
GoRouter location; no route changes are part of this remediation.

| Route | Screen owner | Current module tab | Existing hierarchy/actions and preserved identity |
| --- | --- | --- | --- |
| `/customers` | `CustomerListScreen` | Customers | Customer list, search/status/group filters, create-customer route, row view/edit/lifecycle actions, bounded pagination. |
| `/customers/new` | `CustomerFormScreen(customerId: null)` | Customers | Create form, guarded Cancel, save; keys include `customer-name-field`, `customer-email-field`, `customer-birth-date-field`, `customer-notes-field`, `customer-add-phone`, `customer-form-cancel`, `customer-form-save`. |
| `/customers/:customerId` | `CustomerDetailScreen` | Customers | Detail identity/status, edit route, lifecycle actions, overview information/phones/groups/notes; customer id is parsed as a positive route id. |
| `/customers/:customerId/edit` | `CustomerFormScreen(customerId)` | Customers | Edit form with backend number and loaded draft, lifecycle section, guarded Cancel, save; same stable form keys plus phone-row keys `customer-phone-row-*`. |
| `/customers/groups` | `CustomerGroupListScreen` | Customer Groups | Group search/status filters, create-group route, row view/edit/lifecycle actions, bounded pagination. |
| `/customers/groups/new` | `CustomerGroupFormScreen(groupId: null)` | Customer Groups | Name-only group form, guarded Cancel, save; keys include `customer-group-name`, `customer-group-error`, `customer-group-save`. |
| `/customers/groups/:groupId` | `CustomerGroupDetailScreen` | Customer Groups | Group identity/status/member count, edit/add-member actions, member search, bounded member collection/pagination, remove-member confirmation; keys include `customer-group-add-members`, `customer-group-remove-confirm`. |
| `/customers/groups/:groupId/edit` | `CustomerGroupFormScreen(groupId)` | Customer Groups | Existing group name edit, guarded Cancel, save, positive route-id parsing. |

Current `CustomerManagementScaffold` exposes the selected tab through its
`groupsSelected` route-derived boolean and keeps the child route widget below it.
Existing loading/error/empty semantics are supplied by
`CustomerManagementStatePanel`; form dirty state is protected by
`UnsavedNavigationGuard`, `guardedGo`, and `PopScope`. The visual work may add
labels, descriptions, breadcrumbs, and decoration but must preserve these keys,
callbacks, route ids, Cubit providers, draft retention, dialog return values, and
guard behavior.

## T003 — Reference-to-composition inventory

The supplied numbered screenshots and the bundled HTML reference were reviewed as
visual input only. Adopted composition and required exclusions are:

| Reference | Adopted composition | Required exclusion/qualification |
| --- | --- | --- |
| `01_customer_list.png` | Warm module background, compact module tabs, page header, bordered filters, result summary, warm table header, status pills, bounded rows, action menu, integrated footer. | Prototype order-count and last-visit columns are not supported and remain absent. |
| `02_customer_list_loading.png` | Same collection geometry with inert skeleton rows. | No readable demo names, numbers, or fake data. |
| `03_customer_list_empty.png` | Centered empty state inside the collection surface with create action. | Create action remains caller-authorized and real. |
| `04_customer_list_error.png` | Centered retryable error state with distinct warning treatment. | Retry repeats current Cubit criteria; no simulated success. |
| `05_customer_group_details.png` | Group identity/status header, member count, member search, bordered member collection and remove/view actions. | Only authoritative member data and supported actions are shown. |
| `06_customer_group_create.png` | Constrained group form card and reachable footer. | Reference description and editable status controls are explicitly excluded; production group form stays name-only. |
| `07_customer_groups_list.png` | Group page header, bordered filters, lifecycle segments, compact table/card records, member count, optional creation date, actions. | Values come from the bounded backend page; no inferred count/status. |
| `08_customer_order_history.png` | None beyond the general header/surface language. | Orders, order history, order filters, metrics, and order-derived totals are explicitly excluded. |
| `09_customer_details_overview_top.png` and `10_customer_details_overview_bottom.png` | Responsive detail card grid for identity/customer information, phones, groups, notes, with header status and actions. | Prototype metrics and recent/order-history surfaces are excluded. |
| `11_customer_edit_top.png` and `12_customer_edit_bottom.png` | Constrained form card, separated information/phone/group/notes/lifecycle sections, raw values, read-only edit number, reachable footer. | Backend-generated number is never editable or predicted; archived group behavior remains authoritative. |
| `13_customer_create.png` | Create form hierarchy, phone/group/notes sections, constrained card and footer. | No prototype values or unsupported controls are copied into production. |

The HTML reference contains the same prototype shell/state vocabulary, including a
developer/demo switcher and unsupported order/metric/group-description/status
surfaces. Those are reference-only and are not reachable from production code.

## T004 — Frozen behavior boundary

The presentation layer consumes, without modification, the existing
`CustomerManagementRepository`, models, Cubits, route locations, and focused
regressions. Frozen semantics include:

- Customer list requests use `CustomerListQuery(search, status, groupId, page,
  perPage)` with default page size 25; search debounces 300 ms, Enter submits
  immediately, clear resets criteria/page, and status/group changes reset page 1.
- Group list requests use `CustomerGroupListQuery(search, status, page, perPage)`
  with the inactive status excluded by the model contract; search debounces 300 ms
  and existing clear/page behavior remains unchanged.
- Group members and eligible candidates use the same bounded query type. Candidate
  selection persists in the membership Cubit across paging/relayout; add/remove
  mutations are single-flight and authoritative success refreshes the group/member
  view.
- Customer/group detail and form Cubits retain generation/stale-response guards,
  backend values, validation mapping, draft retention on failure, stable phone row
  identity, and single-flight save/lifecycle semantics. The repository derives
  tenant identity from the bearer-token client and sends no `X-Tenant-Id`.
- Existing focused behavior tests remain the authority: controller tests under
  `test/features/customer_management/controllers/`, repository tests under
  `test/features/customer_management/repositories/`, route/shell/access tests,
  form navigation tests, lifecycle/membership view tests, and existing collection,
  detail, form, accessibility, state-matrix, localization, race, and scope-guard
  tests. This feature adds presentation coverage only.

## Task status

- [x] T001 — initial scope and worktree baseline recorded.
- [x] T002 — route/screen/guard inventory recorded.
- [x] T003 — numbered reference and HTML mapping recorded.
- [x] T004 — controller/repository boundary and regression inventory recorded.

## T005 — Pre-change focused regression baseline

Resolved directory target before execution: `windows_application/test/features/customer_management/` contained these 26 files, all included by the directory command:

```text
controllers/customer_detail_cubit_test.dart
controllers/customer_form_cubit_test.dart
controllers/customer_group_detail_cubit_test.dart
controllers/customer_group_form_cubit_test.dart
controllers/customer_group_list_cubit_test.dart
controllers/customer_group_membership_cubit_test.dart
controllers/customer_lifecycle_cubit_test.dart
controllers/customer_list_cubit_test.dart
customer_form_navigation_test.dart
customer_management_access_test.dart
customer_management_accessibility_test.dart
customer_management_localization_test.dart
customer_management_race_test.dart
customer_management_scope_guard_test.dart
customer_management_state_matrix_test.dart
models/customer_drafts_test.dart
models/customer_models_test.dart
repositories/customer_management_repository_test.dart
shared_phone_warning_test.dart
views/customer_detail_screen_test.dart
views/customer_form_screen_test.dart
views/customer_group_form_screen_test.dart
views/customer_group_lifecycle_test.dart
views/customer_group_membership_test.dart
views/customer_group_screens_test.dart
views/customer_lifecycle_test.dart
views/customer_list_screen_test.dart
widgets/customer_collection_test.dart
```

Commands were run serially from `windows_application`:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter test test/features/customer_management` | 0 | 93 passed, 0 failed. |
| `flutter test test/app/customer_management_routing_test.dart` | 0 | 3 passed, 0 failed. |
| `flutter test test/app_shell_bilingual_test.dart` | 0 | 8 passed, 0 failed. |
| `flutter test test/shared/widgets/app_sidebar_auth_test.dart` | 0 | 7 passed, 0 failed. |
| `flutter test test/features/customer_management/customer_form_navigation_test.dart` | 0 | 1 passed, 0 failed. |

No timeout, skip, unavailable toolchain, or pre-existing failure occurred in this
baseline set. Flutter printed only its normal “new version available” notice on
the first command. This is behavioral baseline evidence; visual remediation tests
remain to be added.

## Task status

- [x] T005 — pre-change focused regression baseline recorded.

## T085 — Resolved presentation vocabulary before UI/ARB edits

The existing Customer Management ARB vocabulary was compared before any
remediation UI or ARB edit. Both `app_en.arb` and `app_ar.arb` contain the same 77
`customerManagement*` keys (including metadata entries); no customer-management
key is missing from either locale and no duplicate customer-management property was
found in the source. The broader ARB files have unrelated legacy parity drift, but
that is outside this feature and is not repaired here.

The following vocabulary is frozen for the remediation. Existing keys are reused
where possible; the `cmvp*` keys are the only new presentation copy planned.

| Surface | English | Arabic intent |
| --- | --- | --- |
| Module/page | `customerManagementTitle`, `customerManagementCustomers`, `customerManagementGroups` | إدارة العملاء، العملاء، مجموعات العملاء |
| Page descriptions | `cmvpCustomersDescription`, `cmvpGroupsDescription`, `cmvpCustomerDetailDescription`, `cmvpCustomerFormDescription`, `cmvpGroupDetailDescription`, `cmvpGroupFormDescription` | Concise localized descriptions for managing customers, groups, details, and forms |
| Breadcrumbs | `cmvpBreadcrumbCustomers`, `cmvpBreadcrumbGroups`, `cmvpBreadcrumbDetails`, `cmvpBreadcrumbEdit`, `cmvpBreadcrumbCreate` | العملاء/المجموعات، التفاصيل، التعديل، الإضافة |
| Collection controls | Existing `customerManagementSearch`, `customerManagementStatus`, `customerManagementGroupsLabel`, `customerManagementAll`, `customerManagementActive`, `customerManagementInactive`, `customerManagementArchived`, `customerManagementClearFilters` | Existing established Arabic terms; group list omits inactive because its query contract forbids it |
| Collection metadata | `cmvpCustomersCount`, `cmvpGroupsCount`, `cmvpMembersCount`, existing `customerManagementPage`, `customerManagementPreviousPage`, `customerManagementNextPage` | Localized counts and page navigation derived only from response metadata |
| Actions/tooltips | Existing create/view/edit/save/cancel/lifecycle/add/remove keys plus `cmvpMoreActions`, `cmvpOpenActions`, `cmvpSelectRow`, `cmvpRemoveGroup` | More/open actions, row semantics, and remove-member semantics |
| Detail/form sections | `cmvpInformationSection`, `cmvpPhoneSection`, `cmvpGroupsSection`, `cmvpNotesSection`, `cmvpLifecycleSection`, `cmvpGeneratedNumberHint`, `cmvpCreatedAt`, `cmvpAbsenceValue`, `cmvpManageGroups` | معلومات، الهواتف، المجموعات، الملاحظات، الحالة، الرقم المُنشأ من الخادم، تاريخ الإنشاء، غير متاح، إدارة المجموعات |
| Group/member surfaces | `cmvpGroupName`, `cmvpMemberSearch`, `cmvpNoMembers`, `cmvpNoCandidates`, `cmvpCandidateSearch`, `cmvpSelectedCount`, `cmvpAddMembersDialogTitle`, `cmvpConfirmRemoveMember` | اسم المجموعة، بحث الأعضاء، حالات عدم وجود أعضاء/مرشحين، البحث، عدد المحدد، عناوين الحوار والتأكيد |
| State surfaces | Existing `customerManagementLoading`, `customerManagementEmptyCustomers`, `customerManagementEmptyGroups`, `customerManagementNoResults`, `customerManagementAccessDenied`, `customerManagementNotFound`, `customerManagementRetry`, `customerManagementClearFilters` plus `cmvpLoadingCustomers`, `cmvpLoadingGroups`, `cmvpLoadingRecord`, `cmvpForbiddenTitle`, `cmvpNotFoundTitle`, `cmvpRetryableTitle`, `cmvpNoResultsTitle`, `cmvpEmptyTitle`, `cmvpStateLoadingSemantics` | Distinct loading, empty, filtered, retryable, forbidden, and not-found titles/messages with no fake data |
| Forms/dialogs | Existing validation/consequence keys plus `cmvpSubmitting`, `cmvpAddingMembers`, `cmvpRemovingMember`, `cmvpDiscardChangesMessage`, `cmvpDialogCancel`, `cmvpDialogConfirm` | Progress, destructive consequence, cancel, confirm, and guarded-navigation copy |

No vocabulary authorizes prototype order history, metrics, spending, group
description, directly editable group status, fake records, or new navigation.

## T006-T011 — Foundational red checkpoint

The five new foundational widget tests were run serially before their production
widgets existed:

| Test target | Exit | Expected failure |
| --- | ---: | --- |
| `customer_management_visual_tokens_test.dart` | 1 | Missing `customer_management_visual_tokens.dart`. |
| `customer_management_page_header_test.dart` | 1 | Missing `customer_management_page_header.dart`. |
| `customer_management_surface_test.dart` | 1 | Missing `customer_management_surface.dart`. |
| `customer_management_module_tabs_test.dart` | 1 | Missing `customer_management_module_tabs.dart`. |
| `customer_management_overflow_menu_test.dart` | 1 | Missing `customer_management_overflow_menu.dart` and dependent symbols. |

These are attributable pre-implementation compilation failures, not passes. The
overflow test was corrected to import Flutter's keyboard constants before the green
implementation checkpoint. No existing behavioral source or tests were modified.

## Task status

- [x] T006 — visual-token red tests recorded.
- [x] T007 — page-header red tests recorded.
- [x] T008 — surface red tests recorded.
- [x] T009 — module-tab red tests recorded.
- [x] T010 — overflow-menu red tests recorded.
- [x] T011 — serial foundational red checkpoint recorded.

## T012-T017 — Foundational visual primitives green checkpoint

Implemented the five module-scoped presentation primitives:

- `customer_management_visual_tokens.dart` reuses existing colors, spacing,
  radii, and text styles, fixes the exact `760` breakpoint, constrains readable
  content to 720 logical pixels, and preserves a 48-pixel minimum target.
- `customer_management_page_header.dart` renders direction-aware hierarchy,
  breadcrumbs, identity/status slots, and wrapping desktop/narrow actions.
- `customer_management_surface.dart` provides bordered warm-header/body/footer
  slots and a centered readable-width mode.
- `customer_management_module_tabs.dart` derives selection from the caller and
  invokes only the supplied existing-list callback.
- `customer_management_overflow_menu.dart` renders only caller-provided actions,
  uses a keyboard-capable Material popup, blocks row-tap propagation, and relies
  on the framework's trigger-focus restoration.

Verification, run serially from `windows_application` after implementation:

| Command/target | Exit | Result |
| --- | ---: | --- |
| `flutter test test/features/customer_management/widgets/customer_management_visual_tokens_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/widgets/customer_management_page_header_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/widgets/customer_management_surface_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/widgets/customer_management_module_tabs_test.dart` | 0 | 2 passed. |
| `flutter test test/features/customer_management/widgets/customer_management_overflow_menu_test.dart` | 0 | 2 passed. |
| Scoped `flutter analyze` over the five new Dart sources and five tests | 0 | No issues found. |

An initial scoped analysis returned exit 1 for three `use_null_aware_elements`
infos in the page header; those were corrected, and the rerun above is clean.

## Task status

- [x] T012 — module visual tokens implemented.
- [x] T013 — responsive localized-ready page header implemented.
- [x] T014 — bordered surface slots implemented.
- [x] T015 — direction-aware module tabs implemented.
- [x] T016 — caller-authorized accessible overflow menu implemented.
- [x] T017 — foundational tests and scoped analysis passed.

## T018-T023 — Shared scaffold and route presentation checkpoint

Red characterization results before the corresponding migration:

- `flutter test test/app/customer_management_routing_test.dart` exited 1 because
  the route had no `CustomerManagementModuleTabs` and no page-title/description
  keys.
- `flutter test test/features/customer_management/views/customer_management_scaffold_test.dart`
  exited 1 because the existing scaffold still rendered `SegmentedButton`
  directly instead of the new module-tabs primitive.
- `flutter test test/shared/widgets/app_sidebar_auth_test.dart` exited 0 with 7
  passes, establishing that the existing fail-closed capability/sidebar contract
  was already green and required no sidebar production edit.

Implemented `CustomerManagementScaffold` with the module background, direction-aware
padding, bounded content region, route-derived module tabs, and stable supplied
child. All six existing Customer Management screens now use
`CustomerManagementPageHeader` for their title/description/hierarchy/action
region; route loading, existing callbacks, Cubit providers, form guards, and
positive route-id parsing remain unchanged.

Green verification after the scaffold/header migration:

| Command | Exit | Result |
| --- | ---: | --- |
| `flutter analyze` over the six screens, scaffold, route test, and scaffold test | 0 | No issues found. |
| `flutter test test/app/customer_management_routing_test.dart` | 0 | 3 passed. |
| `flutter test test/features/customer_management/views/customer_management_scaffold_test.dart` | 0 | 2 passed. |
| `flutter test test/shared/widgets/app_sidebar_auth_test.dart` | 0 | 7 passed. |
| `flutter test test/features/customer_management/customer_form_navigation_test.dart` | 0 | 1 passed. |

## T024 — Localization generator blocker

After T085 and the scaffold/header migration, the planned bilingual `cmvp*`
vocabulary was added to `app_en.arb` and `app_ar.arb`. Both files parse as valid
JSON. The controlled command `flutter gen-l10n` produced no output and remained
running for roughly 40 seconds; it was interrupted with Ctrl+C and returned exit
1. The generated files showed no new write timestamp and were not treated as
updated or verified. No hand-edit was made to generated localization output.

Per the implementation skill and the feature plan, this is an unpassed checkpoint
and implementation stops here rather than claiming generated accessors are current.
T025 and all later tasks remain pending until the generator/toolchain issue is
resolved. Existing production code currently uses only already-generated keys, so
the working tree remains type-safe, but the new `cmvp*` vocabulary is not yet
available through `AppLocalizations`.

## Task status

- [ ] T018 — partial route characterization recorded; full mounted eight-route coverage remains pending.
- [ ] T019 — partial scaffold characterization recorded; locale-switch coverage remains pending.
- [ ] T020 — existing capability/sidebar regression run recorded; no new assertions were added yet.
- [x] T021 — serial route/scaffold/access red checkpoint recorded.
- [x] T022 — shared content scaffold implemented.
- [x] T023 — six screens adopted the shared page header.
- [ ] T024 — blocked by stalled `flutter gen-l10n`; generated output not verified.
- [ ] T025 — held because T024 is unpassed.

## Task status

- [x] T085 — vocabulary and locale parity inventory recorded before ARB/UI edits.
