# Phase 2 Implementation Log

## 2026-09-10 — Phase 0 discovery

### T001 — Starting worktree

- Branch: `feaature/customar-managment`.
- The worktree already contained modifications to the SpecKit constitution/templates,
  customer/POS/backend code, Docker Compose, and existing backend tests; it also
  contained untracked Phase 1 Customer domain code, migrations, tests, plans,
  specifications, and the Customer Management design reference. None were staged,
  reverted, or otherwise modified by this task.
- No pre-existing diagnostic was rerun as part of this snapshot. Memory notes an
  earlier backend full-suite result of `512 passed, 4 failed, 1 skipped`; it is
  historical only and is not a current result.

### T002 — Existing Phase 1 Customer seams

- Administrative customer routes are under
  `/v1/admin/customer-management/customers`, protected by
  `api.token`, `password.changed`, and `customer.permission:customer.manage`.
  `CustomerManagementController` and `CustomerManagementResource` already provide
  bounded customer collection metadata and customer profile/lifecycle responses.
- Administrative group CRUD/lifecycle routes are under
  `/v1/admin/customer-management/customer-groups` with the same middleware.
  `CustomerGroupService::list()` is currently active-only and unpaginated;
  `CustomerGroupResource` has no `memberCount`; no group member/candidate query or
  add/remove membership command route exists.
- `CustomerAccess` is the existing tenant-authenticated authority: owners and
  managers with the tenant `customer.manage` permission pass `assertCanAdminister`.
  Its truth is not exposed through a self-capability endpoint, and the existing
  role-permission endpoint is owner-only configuration, not self discovery.
- Customer create/update group replacement is currently owned by `CustomerService`
  and `SyncCustomerGroupsRequest`; it cannot safely serve the group-detail UI,
  because it requires the caller to reconstruct an entire membership set.

### T003 — Flutter reuse seams

- `app_router.dart` uses one `GoRouter` with a `ShellRoute` and per-route
  `BlocProvider`/`MultiBlocProvider` composition. Customer routes must remain in
  that shell and derive their state from route IDs rather than cached extras.
- `AppSidebar` is the existing destination/navigation component and reads generated
  `AppLocalizations`; it is the seam for the authorized Customers destination.
- `service_locator.dart` registers production repositories lazily against one
  `DioApiClient`, with explicit test composition branches. The customer repository
  must use that same registration pattern.
- `DioApiClient.getEnvelope()` preserves paginated Laravel `data` plus `meta`; its
  authenticated interceptor removes `X-Tenant-Id`. `AuthSession`,
  `AuthRepository`, and session storage are the compatibility seam for a new
  server-provided self capability.

### T004 — Visual reference review

- Screens 01–04 establish the existing-shell customers tab, filters/search, bounded
  table/card rows, loading skeleton, empty state, retryable error state, and primary
  creation action.
- Screens 05–07 establish group list/detail/create hierarchy, member rows, add-member
  action, lifecycle treatment, and list member count. The reference's description
  and in-form status controls are excluded because Phase 1 does not own them.
- Screens 09–13 establish customer identity/contact/phone/group/note sections,
  immutable customer-number display, form phone primary/type controls, group chips,
  and create/edit structure. Screens 08–10's order history, recent orders, spend,
  counts, visits, and order tab are Phase 4 prototype material and are excluded.
- All thirteen numbered PNGs and the README/HTML were reviewed. The visual reference
  is presentation evidence only: no prototype arrays, client filtering, fake metrics,
  or hard-coded production strings may be reused.

### T007–T011 — Backend prerequisite red checkpoint (blocked)

- Added the requested self-capability and group list/member/candidate/membership
  command contract tests. They remain unchecked because their required red run could
  not begin.
- Command attempted serially from the repository root:
  `docker compose exec -T backend php artisan test --filter='CustomerAuthorizationApiTest|CustomerGroupApiTest'`.
- Result: Docker could not read `C:\\Users\\Rami\\.docker\\config.json` and could not
  connect to `npipe:////./pipe/docker_engine` (`Access is denied`). This is an
  environment access failure, not evidence that the new tests fail for the expected
  missing API behavior.
- Per the implementation plan, no production backend or Flutter implementation was
  started after this failed red checkpoint. T007–T011 must be resumed by running the
  focused suite with Docker access, recording the expected 404/contract failures,
  then implementing T012–T020.

### T007–T020 — Backend prerequisite implemented and verified

- The elevated Docker red run reached Laravel and failed as intended: the capability,
  member/candidate, and member-command routes returned 404; the group list lacked
  pagination metadata. The focused result was 4 failed, 8 passed (88 assertions).
- Implemented the frozen tenant-authenticated self-capability endpoint, bounded
  administrative group listing with `memberCount`, bounded members/candidates, and
  atomic add/remove commands. New command routes remain `customer.manage` protected;
  the self capability endpoint is authenticated but intentionally returns false for
  unauthorized tenant roles.
- Focused green run: `CustomerAuthorizationApiTest|CustomerGroupApiTest` — 12 passed,
  113 assertions.
- Broader serial checkpoint: `CustomerAuthorizationApiTest|CustomerGroupApiTest|CustomerRoutePermissionMapTest|CustomerManagementApiTest|CustomerSearchPaginationTest` — 20 passed, 1 opt-in performance benchmark skipped, 247 assertions. It was rerun after formatting with the same result.
- Pint test initially reported two style issues; Pint fixed only the changed group
  controller and route import order. Recheck passed on 11 backend files. `git diff --check`
  exited 0; it emitted only pre-existing CRLF conversion warnings for SpecKit files.

### T012-T020 - Fresh checkpoint verification

- Re-ran the required serial backend checkpoint on 2026-09-10:
  `docker compose exec -T backend php artisan test --filter='CustomerAuthorizationApiTest|CustomerGroupApiTest|CustomerRoutePermissionMapTest|CustomerManagementApiTest|CustomerSearchPaginationTest'`.
  Result: 20 passed, 1 opt-in performance benchmark skipped, 247 assertions, 10.32 s.
- Ran Pint test mode against the Customer prerequisite production and test paths:
  `docker compose exec -T backend ./vendor/bin/pint --test app/Domain/Customer app/Http/Controllers/Api/Admin/CustomerManagement/CustomerGroupController.php app/Http/Controllers/Api/CustomerCapabilityController.php app/Http/Requests/Customer/AddCustomerGroupMembersRequest.php app/Http/Requests/Customer/ListCustomerGroupMembersRequest.php app/Http/Requests/Customer/ListCustomerGroupsRequest.php app/Http/Resources/Customer/CustomerGroupResource.php app/Services/Customer/CustomerGroupService.php routes/api.php tests/Feature/Customer/CustomerAuthorizationApiTest.php tests/Feature/Customer/CustomerGroupApiTest.php tests/Feature/Customer/CustomerRoutePermissionMapTest.php`.
  Result: 17 files passed.
- `git diff --check` completed with exit code 0. Its only output was pre-existing
  CRLF conversion warnings for SpecKit files; it reported no whitespace errors.

### T021-T032 - Flutter foundation checkpoint

- The pre-existing untracked model/draft tests and model files were inspected before
  changes. A new structural parser regression was added: malformed `phones` must
  throw a `FormatException`, rather than reaching an unchecked type error or being
  treated as an empty collection. It failed first, then passed after strict list
  parsing was introduced.
- Added the repository contract test and authenticated-session capability storage
  tests. The T021-T024 combined red run failed as intended because the Customer
  Management repository was absent and `AuthSession.customerManagementAllowed` did
  not exist. The existing model and draft tests passed in that red run; no earlier
  red evidence was available for those inherited, untracked files.
- Implemented immutable query equality correction, strict customer collection
  parsing, the bounded production Customer Management repository, fail-closed
  capability persistence, one client-side access projection, service-locator
  registration, a localized-failure model, and numeric route-location builders.
  The repository only uses the frozen backend endpoints and `DioApiClient`; it does
  not send `X-Tenant-Id`, fetch unbounded collections, normalize phones, generate
  customer numbers, or retry mutations.
- Green focused command (from `windows_application/`):
  `flutter test test/features/customer_management/models/customer_models_test.dart test/features/customer_management/models/customer_drafts_test.dart test/features/customer_management/repositories/customer_management_repository_test.dart test/features/auth/auth_session_storage_contract_test.dart`
  Result: 9 passed.
- `git diff --check` completed with exit code 0. It emitted only existing CRLF
  conversion warnings for SpecKit files and the edited auth-session file; no
  whitespace error was reported.
- Targeted `flutter analyze` was started for the changed foundation paths but did
  not produce a completion result before this checkpoint; it is not recorded as a
  pass and must be re-run during T038/T100.

### T033 - Customer Management localization

- Added Customer Management English and Arabic strings for titles, tabs,
  lifecycle states, filters, absence/error states, profile labels, pagination,
  actions, dirty-discard copy, and named group-member removal confirmation.
- `flutter gen-l10n --verbose` completed with exit code 0 and regenerated only
  `app_localizations.dart`, `app_localizations_en.dart`, and
  `app_localizations_ar.dart`. Flutter reported 120 untranslated Arabic messages
  outside the newly added Customer Management keys.
- Verified generated accessors for `customerManagementTitle` and
  `customerManagementRemoveMemberConfirm` in English, Arabic, and the abstract
  localizations class.

### T023-T038 - Flutter Foundations reconciliation

- Expanded the controlled-Dio production repository contract test to exercise
  every approved Customer Management endpoint, bounded query, create/update
  payload, membership payload, and 403/404/409/422/network/timeout/server
  failure mapping. Added capability storage/access coverage for owner, granted
  and ungranted manager, employee, legacy capability absence, and revocation.
- Reconciled the inherited implementations for T026-T034 against their source:
  strict models/drafts, bounded repository, failure projection, service
  registration, fail-closed capability persistence, access projection,
  localization, and numeric route builders were already present and were not
  duplicated. Added the remaining Customer Management module scaffold,
  pagination, confirmation primitive, eight route registrations, and route
  builder coverage without beginning any US1 screen work.
- Focused Phase 3 verification (from `windows_application/`):
  `flutter test test/features/customer_management/models/customer_models_test.dart test/features/customer_management/models/customer_drafts_test.dart test/features/customer_management/repositories/customer_management_repository_test.dart test/features/auth/auth_session_storage_contract_test.dart test/features/customer_management/customer_management_access_test.dart test/app/customer_management_routing_test.dart`
  completed with `24` passing tests.
- Targeted static analysis:
  `flutter analyze lib/app/app_router.dart lib/app/customer_management_route_locations.dart lib/features/customer_management lib/features/auth/models/auth_session.dart lib/features/auth/repositories/auth_repository.dart lib/shared/widgets/app_sidebar.dart`
  completed with `No issues found`.
- `git diff --check` completed with exit code 0. It printed only existing CRLF
  conversion warnings for pre-existing modified files; it reported no whitespace
  errors.

### T021 - Customer model parser

- Added coverage for nullable profile fields, every lifecycle value, allowed
  actions, invalid lifecycle metadata, malformed pagination metadata, and malformed
  action entries. The new malformed-action case failed first because the parser
  silently dropped non-string values.
- Made `allowedActions` a strict required string collection; malformed action
  metadata now rejects the server response instead of changing its meaning.
- Green command from `windows_application/`:
  `flutter test test/features/customer_management/models/customer_models_test.dart`
  Result: 7 passed.

### T022 - Customer draft serialization

- Added multiple-primary and stable-row-ID coverage, plus a deliberate nullable
  field-clearing regression. The latter failed first because `copyWith` could not
  clear email, birth date, or notes without recreating the whole draft.
- Added explicit clear flags while preserving every phone row and its caller-owned
  stable row ID. Raw phone serialization remains unchanged.
- Green command from `windows_application/`:
  `flutter test test/features/customer_management/models/customer_drafts_test.dart`
  Result: 4 passed.

### T039-T040 - Customer controller regression start (in progress)

- Added focused controller regressions for duplicate in-flight list loads,
  stale list responses, and preserving the direct-detail entity during refresh.
  The required initial red command was:
  `flutter test test/features/customer_management/controllers/customer_list_cubit_test.dart test/features/customer_management/controllers/customer_detail_cubit_test.dart`.
  It failed as intended: list request count was `2` rather than `1`, and detail
  refresh cleared the loaded entity (`null` rather than customer ID `3`).
- `CustomerListCubit` now coalesces an identical in-flight query while retaining
  its generation gate; `CustomerDetailCubit` retains the entity for same-ID
  refreshes. Both retain `isClosed` and late-response protections.
- Green focused command:
  `flutter test test/features/customer_management/controllers/customer_list_cubit_test.dart test/features/customer_management/controllers/customer_detail_cubit_test.dart test/features/customer_management/models/customer_models_test.dart test/features/customer_management/models/customer_drafts_test.dart test/features/customer_management/repositories/customer_management_repository_test.dart`
  Result: 22 passed.
- T039/T040 remain unchecked: their full required state matrices and widget
  coverage have not yet been completed.

### T039-T042 — additional US1 red/green evidence (in progress)

- Added an explicit detail refresh-failure retention/retry regression and initial
  list/detail widget coverage for authoritative fields, pagination, no-phone,
  archived group, phone type/primary, and excluded Phase 4 values.
- Red run: `flutter test test/features/customer_management/controllers/customer_list_cubit_test.dart test/features/customer_management/controllers/customer_detail_cubit_test.dart test/features/customer_management/views/customer_list_screen_test.dart test/features/customer_management/views/customer_detail_screen_test.dart`.
  The new detail retention assertion failed as intended: after a refresh error,
  customer ID `3` was `null`. Widget tests initially lacked generated
  localization delegates; that test-harness error was corrected before assessing
  production behavior. The remaining intentional UI gap was the absent group
  filter.
- Updated detail failure state to retain the same direct-loaded customer and
  added a bounded server-query group filter using groups present in the rendered
  server page; selection still delegates to `CustomerListCubit.setGroup` and
  therefore performs no local filtering.
- Green rerun of the same command: `8` passing tests.
- T039–T042 remain unchecked: the full required controller and widget state
  matrices (including all error, debounce, route-change, responsive-width, and
  absence-state cases) still require explicit tests and verification.

### T039/T041 — authoritative bounded group-filter correction (in progress)

- Regression test added for `CustomerListCubit.loadGroupOptions()`. Its initial
  focused run failed to compile as intended because neither that bounded lookup
  nor `CustomerListState.groupOptions` existed.
- Replaced the page-derived group-filter choices with a separate repository call:
  `listGroups(const CustomerGroupListQuery(perPage: 25))`. The selected ID still
  flows only through `CustomerListCubit.setGroup`, which sends `groupId` to the
  backend customer collection query. No unbounded group collection or local
  customer filtering was introduced.
- A long authoritative group name exposed a desktop filter overflow during the
  focused rerun. The group dropdown now expands within its bounded control and
  ellipsizes display text without changing the name or ID.
- Focused command from `windows_application/`: `flutter test
  test/features/customer_management/controllers/customer_list_cubit_test.dart
  test/features/customer_management/controllers/customer_detail_cubit_test.dart
  test/features/customer_management/views/customer_list_screen_test.dart
  test/features/customer_management/views/customer_detail_screen_test.dart`.
  Result: 9 passed.
- Targeted `flutter analyze` on the changed list controller/state/view and tests:
  no issues. Scoped `dart format` completed. `git diff --check` exited 0 with
  only existing CRLF warnings.

### T039-T050 - US1 bounded customer read-only MVP checkpoint

- Added the remaining red/green coverage for list debounce after a 300 ms pause,
  immediate Enter and clear, criteria-preserving status/page requests, duplicate
  in-flight coalescing, stale response rejection, retry retention, direct-detail
  route changes, late responses, forbidden/not-found mapping, empty and forbidden
  collection states, localized absence values, server pagination, backend-provided
  edit actions, and explicit exclusion of Phase 4 metrics/history/order fields.
- The required red run was observed before the final implementation edits. It
  exposed the missing empty-state creation action; one initial assertion also used
  the wrong existing localization text and was corrected before the green run.
- Completed the US1 implementation with a single bounded clear-filters request,
  localized empty/no-results recovery actions, backend-authoritative edit actions
  in desktop and narrow collection layouts, and feature-owned detail-screen style
  cleanup. No client filtering, fake records, generated customer numbers, or
  Phase 4 data was introduced.
- Final focused checkpoint from windows_application:
  flutter test test/features/customer_management test/app/customer_management_routing_test.dart
  - 42 tests passed, including the 500 px narrow record layout check.
- Final changed-file formatting check passed with dart format --output=none
  --set-exit-if-changed on the Customer Management controllers, views, widgets,
  and US1 tests.
- Targeted analysis had no errors; one pre-existing info remains in
  test/features/customer_management/repositories/customer_management_repository_test.dart:266.
- git diff --check exited 0; only existing LF/CRLF conversion warnings for
  unrelated/pre-existing modified files were emitted.

### T051-T061 - US2 customer create/edit form checkpoint

- Added red-first controller, widget, navigation, and shared-phone contract
  coverage for create/edit initialization, zero phones, stable phone row IDs,
  explicit primary changes, active and archived groups, local and nested
  backend validation, single-flight submission, failure retention, returned
  identity navigation, dirty Cancel navigation, and narrow-width actions.
- The required red run was observed before implementation. It failed to
  compile because the planned `CustomerFormCubit`, `CustomerFormState`, and
  `CustomerFormScreen` files did not yet exist.
- Implemented `CustomerFormState`/`CustomerFormCubit`, reusable form sections,
  create/edit screen modes, direct edit loading, read-only customer numbers,
  exact raw phone serialization, archived-group retention/removal, localized
  validation, authoritative create/update success handling, and the existing
  unsaved-navigation guard. Create success navigates to the returned customer
  detail ID; failures retain the draft and do not navigate.
- No shared-phone warning was added. Phase 1 exposes no approved authorized
  match endpoint, so the warning remains intentionally unreachable and the
  client performs no tenant-wide local scan or block.
- Final focused command from `windows_application`:
  `flutter test test/features/customer_management test/app/customer_management_routing_test.dart`
  - 59 tests passed, including the US1 regression tests and the 500 px form
    action reachability check.
- Targeted `flutter analyze` on the customer-management implementation,
  routing, localization accessors, and tests reported no errors; one
  pre-existing info remains at
  `test/features/customer_management/repositories/customer_management_repository_test.dart:266`.
- Scoped Dart formatting completed successfully. `git diff --check` exited 0;
  only existing line-ending conversion warnings for unrelated/pre-existing
  modified files were emitted.
- `flutter gen-l10n` was attempted but hung without output and was stopped.
  Both ARB files parse as valid JSON, and the generated localization
  declarations/accessors were synchronized manually for the new US2 strings.
### T062-T064 - US3 lifecycle red checkpoint

- Added lifecycle cubit and widget tests covering valid status/`allowedActions`
  transitions, single-flight/no-optimistic mutation, authoritative replacement,
  collection refresh callbacks, invalid transitions, permission revocation, all
  mapped failure classes, localized consequence dialogs, progress/disabled
  controls, restored-Inactive behavior, retry-safe failure copy, and focus
  restoration.
- The required red command was run from `windows_application/`:
  `flutter test test/features/customer_management/controllers/customer_lifecycle_cubit_test.dart test/features/customer_management/views/customer_lifecycle_test.dart`.
- It failed as expected because the planned `CustomerLifecycleCubit`,
  `CustomerLifecycleState`, and `CustomerLifecycleActions` production files did
  not yet exist. The initial test-only import separator error was corrected and
  the second run reached only the expected missing-production-file failures.

### T065-T068 - US3 lifecycle checkpoint

- Implemented `CustomerLifecycleState`/`CustomerLifecycleCubit` with backend
  action validation against lifecycle plus `allowedActions`, single-flight
  mutation behavior, no optimistic changes, authoritative success replacement,
  collection refresh callback, and prior-entity retention for validation,
  forbidden, not-found, conflict, timeout, network, and server failures.
- Added localized deactivate/archive/restore consequence dialogs and immediate
  activate behavior. Actions are filtered from the returned entity contract and
  are wired into customer list, detail, and edit views. Edit lifecycle success
  updates the loaded entity while preserving a dirty profile draft.
- US3 focused red/green command completed from `windows_application/`:
  `flutter test test/features/customer_management/controllers/customer_lifecycle_cubit_test.dart test/features/customer_management/views/customer_lifecycle_test.dart`
  - initial red reached the expected missing-production-file failures;
  - final result: 8 tests passed.
- Full Customer Management regression command completed from
  `windows_application/`:
  `flutter test test/features/customer_management test/app/customer_management_routing_test.dart`
  - result: 68 tests passed.
- Targeted analysis completed with `No issues found` for the router, Customer
  Management implementation, and US3 tests. `git diff --check` completed with
  no whitespace errors; only existing LF/CRLF conversion warnings were emitted.
- `flutter gen-l10n` was attempted twice but hung without producing the new
  accessors. The ARB files were updated and only the seven new US3 accessors
  were synchronized in the generated localization Dart files; no unrelated
  localization churn was introduced.
- Final verification after formatting: the exact changed Dart-file format check
  exited 0 with 14 files and 0 changed; scoped `flutter analyze` on the US3
  implementation/tests exited 0 with `No issues found`; and the repository
  `git diff --check` exited 0 with only pre-existing line-ending warnings.

### T069-T075 - US4 red checkpoint

- Added the planned group-list, group-detail, group-form, membership, lifecycle,
  and screen contract tests before creating the US4 production files.
- The required red run reached the expected missing-production-file failures:
  `CustomerGroupListCubit`, `CustomerGroupDetailCubit`,
  `CustomerGroupFormCubit`, `CustomerGroupMembershipCubit`, and the group
  screens/components were not yet present. The harness-only membership import
  typo was corrected before implementation.

### T076-T084 - US4 implementation checkpoint

- Implemented independent group list/detail/form/membership cubits with bounded
  server queries, 300 ms search debounce plus immediate Enter/clear, immutable
  criteria, generation-based stale-response rejection, retry state retention,
  dirty-form protection, cross-page candidate selection, and single-flight
  authoritative mutations.
- Added responsive group list, group detail/member, name-only group form, add
  member dialog, named remove confirmation, and archive/restore controls. Group
  descriptions and client-generated counts/statuses are intentionally absent;
  archived memberships remain visible and lifecycle changes occur only after
  backend success.
- Added the four group route implementations to the existing shell and kept
  all reads on the frozen bounded endpoints.
- Focused US4 command from `windows_application`:
  `flutter test --reporter compact test/features/customer_management/controllers/customer_group_list_cubit_test.dart test/features/customer_management/controllers/customer_group_detail_cubit_test.dart test/features/customer_management/controllers/customer_group_form_cubit_test.dart test/features/customer_management/controllers/customer_group_membership_cubit_test.dart test/features/customer_management/views/customer_group_form_screen_test.dart test/features/customer_management/views/customer_group_lifecycle_test.dart test/features/customer_management/views/customer_group_screens_test.dart`
  - result: 14 tests passed.
- Broader customer-management checkpoint from `windows_application`:
  `flutter test --reporter compact test/features/customer_management test/app/customer_management_routing_test.dart`
  - result: 82 tests passed.
- Targeted `flutter analyze` for Customer Management, router, and US4 tests:
  `No issues found`.
- `git diff --check` exited 0 with only pre-existing line-ending conversion
  warnings for unrelated modified files.

### T085-T090 - US5 real-state and scope red checkpoint

- Added the US5 state matrix, localization, accessibility, race, and
  production-scope guard tests under
  `windows_application/test/features/customer_management/`.
- The required red run for the initial state matrix failed for the expected
  missing behavior: group empty state used the customer creation label,
  validation failures used the generic request-failed copy, and member refresh
  failures rendered the empty/no-results fallback without a retry action.
- The initial localization run failed because the Arabic phone-type accessor
  rendered mojibake rather than the localized `محمول` value. The focused scope
  guard and late-response tests then passed against the existing production
  paths.

### T091-T094 - US5 cross-cutting hardening

- State panels now distinguish validation, empty, no-results, forbidden, and
  not-found outcomes; empty group creation uses the group label; member
  collection failures retain a separate retryable failure; and retry does not
  disguise authorization/not-found states as empty data.
- Corrected Arabic Customer Management localization values, localized phone
  types and separators, explicit LTR rendering for identifiers/phones, long
  group-name tooltip/semantics, responsive list/detail headers, and RTL-aware
  pagination icons. Group descriptions, Phase 4 metrics/history, fake records,
  and client-side filtering remain absent.
- Added late-response/disposal coverage for customer/detail/candidate flows and
  guarded detail/group membership lifecycle paths from post-close emissions.
- Formatting check for the exact changed Dart files completed with zero changed
  files. `git diff --check` completed with no whitespace errors; it emitted
  only existing LF/CRLF conversion warnings.

### T095 - US5 verification checkpoint

- Focused command from `windows_application`:
  `flutter test --reporter compact test/features/customer_management test/app/customer_management_routing_test.dart`
  - result: 93 tests passed.
- Targeted analysis command:
  `flutter analyze lib/features/customer_management test/features/customer_management lib/app/app_router.dart lib/app/customer_management_route_locations.dart`
  - result: no Customer Management diagnostics; one pre-existing info remains
    at `test/features/customer_management/repositories/customer_management_repository_test.dart:266`.
- `flutter gen-l10n` was attempted but hung without output and was stopped;
  both ARB files were validated as JSON and the required generated accessors
  were synchronized manually without unrelated localization regeneration.
- Shell/localization/navigation/network regression command:
  `flutter test --reporter compact test/app/customer_management_routing_test.dart test/app_shell_navigation_transitions_test.dart test/app_shell_bilingual_test.dart test/app_shell_rtl_test.dart test/core/navigation/unsaved_navigation_guard_test.dart test/core/network/dio_api_client_test.dart`
  - result: 15 passed and 6 failed in the existing shell bilingual checks for
    missing `Customers`/`العملاء` sidebar labels across inventory, finance, and
    reports. No shell files were changed for US5; these failures remain
    separately reported rather than claimed as feature failures or fixed out of
    scope.

### T096-T107 - Final verification and scope audit

- T096 formatting: `dart format --output=none --set-exit-if-changed` passed for
  all 78 changed Dart files under `windows_application/lib/` and
  `windows_application/test/`; no formatting rewrite was required.
- T097 focused Flutter suite: `flutter test test/features/customer_management`
  passed with 92 tests passed and no skips.
- T098 shell/localization/navigation/network regression repeated the prior
  result: 15 passed and 6 failed. The six failures are the existing bilingual
  sidebar assertions in `test/app_shell_bilingual_test.dart`, requiring
  `Customers` and its Arabic label on Inventory, Finance, and Reports shells.
  These are unrelated shell behavior and were not changed in this feature audit.
- T099 full Flutter suite was run serially with `flutter test`: 819 passed and
  23 failed. The Customer Management suite remained green. The failures were
  outside the feature-owned suite and included the six shell bilingual failures,
  existing Finance inventory-setup failures in daily-closing and cash/bank
  detail flows, Finance transaction overflow/localization failures, and the
  Finance paginated-table row-boundary failure. The focused Finance suite
  reproduced the unrelated split as 118 passed and 17 failed; combined with
  the six shell failures this accounts for all 23 full-suite failures. The full
  suite therefore is not claimed as passing; a second JSON-only failure-name
  extraction attempt stalled without producing a result and was stopped.
- T100 full `flutter analyze` completed with no errors and 7 informational
  diagnostics: 6 existing Menu interpolation infos and the existing Customer
  repository test curly-braces info at
  `test/features/customer_management/repositories/customer_management_repository_test.dart:266`.
- T101 build verification is incomplete, not passing: `flutter build windows`
  produced no output or Release artifact after approximately 9 minutes and was
  stopped; `flutter build web` likewise produced no output or updated artifact
  after approximately 3 minutes and was stopped. No build target is claimed as
  successful, and no deployment was performed.
- T102 backend Customer contract suite passed serially after the initial
  sandbox-only Docker access failure. Command:
  `docker compose exec -T backend php artisan test --filter='CustomerAuthorizationApiTest|CustomerGroupApiTest|CustomerRoutePermissionMapTest|CustomerManagementApiTest|CustomerSearchPaginationTest'`
  Result: 20 passed, 247 assertions, 1 skipped opt-in 100k benchmark. No
  testing data reset or development-data mutation was performed by this command.
- T103 `git diff --check` passed with no whitespace errors. Git emitted only
  existing LF/CRLF conversion warnings.
- T104 scope audit: feature-owned changes map to the Customer Management
  specification and its backend contracts, routing seams, localization keys,
  tests, and design-reference documentation. Existing unrelated worktree
  changes in shared constitution/templates, non-Customer backend domains,
  Docker configuration, and other application suites were preserved and are
  not claimed as part of this feature. No credential-like values or PII
  fixtures were introduced. Customer Management localization additions are
  limited to `customerManagement*` keys; the separate `taxNewOrdersOnly` key is
  adjacent pre-existing work, not part of this feature claim.
- T105 scope guard: searched Customer Management production code and integration
  seams for hard-coded UI copy, fake records, `X-Tenant-Id`, client phone
  normalization or customer-number generation, Phase 4 metrics/history/order
  fields, group descriptions, unsafe mutation retry, and unbounded requests.
  No violations were found. Customer/group/member reads use bounded server
  pagination; the form group picker is explicitly capped at 100; identifiers,
  phone values, and lifecycle actions remain backend authoritative.
- T106 final evidence summary:

  | Requirement area | Evidence | Result |
  | --- | --- | --- |
  | Customer list/detail/form/group/lifecycle behavior | `flutter test test/features/customer_management` | 92 passed |
  | Route and shell integration | Customer routing test plus T098 regression | Routing passed; 6 pre-existing shell bilingual failures |
  | Customer backend authorization/API/pagination | T102 serial Docker suite | 20 passed, 1 benchmark skip |
  | Formatting and whitespace | T096 and T103 | Passed |
  | Static analysis | T100 full `flutter analyze` | No errors; 7 pre-existing infos |
  | Full Flutter regression | T099 `flutter test` | 819 passed, 23 unrelated/pre-existing failures |
  | Windows/Web artifacts | T101 builds | Incomplete; both builds stalled without artifacts |

  Incomplete checks and unrelated failures above remain explicitly reported;
  no historical checkpoint count is presented as a current pass claim.

### Flutter Customer Management sidebar/access regression fix — 2026-09-11

- Reproduced the mounted-shell failure before production edits in
  `test/shared/widgets/app_sidebar_auth_test.dart`. With an already-mounted
  real `AppShell`/`AppSidebar` and `AuthSessionCubit`, a stale Owner session
  with `customerManagementAllowed: false` remained without `Customers` after
  `AuthSessionCubit.restore()` received and persisted a refreshed Owner session
  with `customerManagementAllowed: true`; the inverse Manager revocation case
  also remained visible. The red command was:
  `flutter test test/shared/widgets/app_sidebar_auth_test.dart`.
  Result: 4 initial visibility tests passed; 2 mounted-session transition
  tests failed at the expected sidebar assertions.
- Root cause: `AppShell` used `context.read<AuthSessionCubit?>()` twice during
  build. `read` does not subscribe the shell to `AuthSessionState`, so its
  existing sidebar retained the prior role/capability snapshot after a Cubit
  emission. `AuthSessionCubit.restore()` was already correct: on successful
  `auth/me`, it calls `_persistAndEnter(verified)`, which writes and emits the
  refreshed server capability.
- Production change: `windows_application/lib/app/app_shell.dart` now uses one
  reactive `context.select` of the `AuthSession` snapshot and derives both
  `actorRole` and `CustomerManagementAccess.allows(session)` from it. The
  server-authoritative capability projection is unchanged; no Owner-only
  customer rule was added and backend 403 remains final authority.
- Test updates:
  `test/shared/widgets/app_sidebar_auth_test.dart` now exercises real mounted
  AppShell/AppSidebar/AuthSessionCubit visibility for Owner, granted Manager,
  ungranted Manager, and Employee plus live grant and revocation updates.
  `test/features/auth/auth_session_cubit_test.dart` proves successful `auth/me`
  refresh replaces and persists a legacy missing capability, while offline
  restoration remains fail-closed. `test/app/customer_management_routing_test.dart`
  now exercises real `/customers` router denial/permitted behavior; the route
  constants test remains only route-value coverage. `test/app_shell_bilingual_test.dart`
  now registers an explicit granted Manager capability fixture, resolving its
  six missing-Customers sidebar failures without granting from role alone.
- Serial verification from `windows_application/`:
  - `flutter test test/shared/widgets/app_sidebar_auth_test.dart` — 7 passed.
  - `flutter test test/features/auth/auth_session_storage_contract_test.dart` — 3 passed.
  - `flutter test test/features/auth/auth_session_cubit_test.dart` — 9 passed.
  - `flutter test test/app/customer_management_routing_test.dart` — 3 passed.
  - `flutter test test/app_shell_bilingual_test.dart` — 8 passed.
  - `flutter test test/features/customer_management` — 92 passed.
  - `flutter analyze lib/app/app_shell.dart test/shared/widgets/app_sidebar_auth_test.dart test/features/auth/auth_session_cubit_test.dart test/app/customer_management_routing_test.dart test/app_shell_bilingual_test.dart` — no issues found.
- No manual runtime reproduction was required for this deterministic widget
  regression; the test updates the mounted shell without logout/relogin,
  navigation, or cold restart. No deployment, commit, reset, clean, reseed, or
  development-database modification occurred.
- Full-suite and Windows/Web build checks were not re-run for this focused
  regression. The earlier log's full-suite failures and stalled build attempts
  remain historical/unrevalidated blockers and are not treated as current
  focused-test failures.
