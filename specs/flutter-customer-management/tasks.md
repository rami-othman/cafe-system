# Tasks: Phase 2 — Flutter Customer Management

**Input**: [spec.md](./spec.md) and [plan.md](./plan.md)

**Visual references**: `windows_application/design_refs/customer_management_design_reference/README.md`, numbered screenshots in `screens/`, and `customer_management_reference.html`

**Scope**: Complete the missing Phase 1 API contracts that block the specified UI, then implement only the Phase 2 administrative Customer Management experience in the existing Flutter Windows/Web application.

## Required Task Format

- Every implementation task below uses `- [ ] Txxx [P?] [US?] Description with exact file path`.
- `[P]` means the task can be performed independently in different files after its phase prerequisites are complete.
- `[US1]` through `[US5]` map directly to the specification's user stories.
- Tests listed before implementation are intentional: add the test, run it, and record the expected failure before writing the production change.

## Non-Negotiable Execution Rules

1. Execute tasks in numeric order unless a task is marked `[P]` and all of its stated prerequisites are complete.
2. Before editing, run `git status --short`. Preserve every unrelated existing change; do not reformat or clean unrelated files.
3. Do not begin Phase 3 or later until the Phase 2 contract checkpoint is green. Do not replace a missing contract with local filtering, role guessing, fake records, or a second Customer business-rule implementation.
4. Tenant identity comes from the opaque bearer token. Never add `X-Tenant-Id` or a client-selected tenant ID to authenticated Customer requests.
5. Backend Customer services own permissions, lifecycle, normalization, phone validity, membership eligibility, pagination, and atomic writes. Flutter may perform usability checks but must display backend validation as authoritative.
6. Preserve phone `rawNumber` exactly as edited. Never silently normalize, format, merge, round, or replace it. Never auto-select another primary phone after the selected primary is removed.
7. Preserve existing archived group memberships unless the user explicitly removes them. Do not make archived groups selectable for new assignment.
8. Never show or synthesize order history, recent orders, total orders, spend, average order value, first/last visit, group description, loyalty redesign, discounts, or marketing data in Phase 2.
9. Do not automatically retry POST/PUT lifecycle or membership mutations. A timeout may occur after the server commits. Keep the prior entity/draft visible until an authoritative response succeeds.
10. All production strings must come from `app_en.arb` and `app_ar.arb`; verify Arabic RTL and English LTR. Do not hand-edit generated localization Dart files except through Flutter localization generation.
11. Run Laravel test commands serially against the shared PostgreSQL test database. Never run concurrent Laravel suites against that database.
12. After each task, run its focused test or static check. Mark the task complete only when its stated evidence passes. A skipped, timed-out, interrupted, unavailable, or failing command is not a pass.

---

## Phase 1: Baseline and Contract Decisions

**Purpose**: Capture repository truth and freeze exact contracts before implementation.

- [x] T001 Record the starting `git status --short`, current branch, and pre-existing diagnostics in `specs/flutter-customer-management/implementation-log.md`; do not stage, revert, or modify unrelated files.
- [x] T002 Inspect and summarize the existing Customer routes, controllers, resources, requests, and services from `backend/routes/api.php`, `backend/app/Http/Controllers/Api/Admin/CustomerManagement/`, `backend/app/Http/Resources/Customer/`, `backend/app/Http/Requests/Customer/`, and `backend/app/Services/Customer/` in `specs/flutter-customer-management/implementation-log.md`; explicitly confirm which planned capability/group/member contracts are absent before editing.
- [x] T003 Inspect the existing Flutter seams in `windows_application/lib/app/app_router.dart`, `windows_application/lib/shared/widgets/app_sidebar.dart`, `windows_application/lib/core/services/service_locator.dart`, `windows_application/lib/core/network/`, `windows_application/lib/features/auth/`, `windows_application/lib/l10n/`, and `windows_application/lib/shared/widgets/`; record the exact reusable patterns and do not introduce a replacement shell, router, network client, localization system, or state-management library.
- [x] T004 Review every numbered image in `windows_application/design_refs/customer_management_design_reference/screens/` and the reference README/HTML; record in `specs/flutter-customer-management/implementation-log.md` the Phase 2 elements to reproduce and the prohibited Phase 4/prototype elements to omit.
- [x] T005 Freeze the authenticated self-capability response, paginated group list, paginated group members, eligible candidates, add-member, and remove-member request/response shapes in `specs/customer-domain-foundation/spec.md`; use camelCase JSON, the existing pagination envelope, stable ordering, tenant-safe authorization, and explicit error behavior, and do not approve an unbounded complete-set workaround.
- [x] T006 Re-check the Constitution gate in `specs/flutter-customer-management/plan.md` after T005 and replace the two blocked/conditional statements only if the approved contracts provide authoritative manager visibility and bounded group membership operations; otherwise stop and report the unresolved contract rather than starting Flutter implementation.

**Checkpoint**: Contract decisions are explicit, scoped, and approved in the authoritative Customer specification.

---

## Phase 2: Phase 1 API Contract Completion (Blocking)

**Purpose**: Supply the authoritative backend capabilities assumed by Phase 2. All backend tests in this phase must pass before Flutter work starts.

### Tests first

- [x] T007 [P] Add failing owner/granted-manager/ungranted-manager/employee/self-capability response tests to `backend/tests/Feature/Customer/CustomerAuthorizationApiTest.php`; assert tenant-authenticated capability truth, Platform Super Admin separation, and no use of the owner-only manager-configuration endpoint for self-discovery.
- [x] T008 Add failing paginated group list contract tests to `backend/tests/Feature/Customer/CustomerGroupApiTest.php`; cover `search`, `status=active|archived|all`, `page`, default/capped `perPage`, normalized-name then ID ordering, standard `meta`, tenant isolation, and authoritative `memberCount`.
- [x] T009 Add failing bounded group-member and eligible-candidate query tests to `backend/tests/Feature/Customer/CustomerGroupApiTest.php`; cover search, page metadata, stable ordering, exclusion of existing members, exclusion of lifecycle-ineligible customers, archived group behavior, 403, foreign/missing 404, and no duplicate rows.
- [x] T010 Add failing add/remove membership command tests to `backend/tests/Feature/Customer/CustomerGroupApiTest.php`; cover atomic multi-add, named single removal semantics, duplicate/replayed commands, foreign/inactive/archived IDs, concurrent membership changes, retained unrelated memberships, authoritative refreshed `memberCount`, and rollback on one invalid ID.
- [x] T011 Run only T007–T010 tests with `docker compose exec -T backend php artisan test --filter='CustomerAuthorizationApiTest|CustomerGroupApiTest'`; record the expected failures and exact missing behavior in `specs/flutter-customer-management/implementation-log.md` before production edits.

### Implementation

- [x] T012 Implement the approved tenant-authenticated self-capability projection in the exact Phase 1-owned files named by T005, including `backend/app/Domain/Customer/CustomerAccess.php`, the selected controller/resource, and `backend/routes/api.php`; return `customer.manage` for owners and explicitly granted managers without widening employee or Platform Super Admin authority.
- [x] T013 Refactor `backend/app/Services/Customer/CustomerGroupService.php` group listing to accept approved bounded criteria, apply tenant/status/search constraints before pagination/counting, order by normalized name then ID, and compute `memberCount` without N+1 or result-duplicating joins.
- [x] T014 Update `backend/app/Http/Controllers/Api/Admin/CustomerManagement/CustomerGroupController.php` and `backend/app/Http/Resources/Customer/CustomerGroupResource.php` to return the frozen paginated group envelope and `memberCount`; preserve existing create/show/update/lifecycle shapes except for approved additive fields.
- [x] T015 Implement tenant-scoped bounded group-member and eligible-candidate queries in `backend/app/Services/Customer/CustomerGroupService.php` (or one clearly named Customer-domain query service if separation is needed); apply permission, group lifecycle, membership exclusion, customer lifecycle, search, ordering, and pagination before returning data.
- [x] T016 Add the approved group-member/candidate GET routes and controller methods in `backend/routes/api.php` and `backend/app/Http/Controllers/Api/Admin/CustomerManagement/CustomerGroupController.php`; reuse `CustomerManagementResource` projections and the standard pagination `meta` without exposing foreign-record details.
- [x] T017 Implement the approved atomic add/remove membership commands in `backend/app/Services/Customer/CustomerGroupService.php`, request validators under `backend/app/Http/Requests/Customer/`, controller methods, and `backend/routes/api.php`; lock affected rows, preserve unrelated memberships, reject invalid complete commands atomically, audit without PII, and return authoritative group/count state.
- [x] T018 Update `backend/tests/Feature/Customer/CustomerRoutePermissionMapTest.php` with every new Customer route and its exact permission so no sensitive route is left without Customer middleware.
- [x] T019 Run `docker compose exec -T backend php artisan test --filter='CustomerAuthorizationApiTest|CustomerGroupApiTest|CustomerRoutePermissionMapTest|CustomerManagementApiTest|CustomerSearchPaginationTest'` serially and record pass/fail counts in `specs/flutter-customer-management/implementation-log.md`.
- [x] T020 Run Pint in test mode on only changed backend PHP paths, then run `git diff --check`; fix only feature-owned formatting errors and record the exact commands/results in `specs/flutter-customer-management/implementation-log.md`.

**Checkpoint — HARD STOP**: Self-capability, bounded groups, bounded members/candidates, and atomic membership commands are contract-tested and green. If not, do not start Phase 3.

---

## Phase 3: Flutter Foundations (Blocking All User Stories)

**Purpose**: Build shared models, transport, access, localization, and routing foundations once.

### Tests first

- [x] T021 [P] Add failing model/parser tests for customer, phone, group summary, group, lifecycle, allowed actions, nullable fields, archived memberships, malformed required identity, and pagination metadata in `windows_application/test/features/customer_management/models/customer_models_test.dart`.
- [x] T022 [P] Add failing draft/serializer tests for zero/one/multiple phones, exact raw values, one explicit primary, stable phone row IDs, active plus retained archived group IDs, calendar birth dates, and exclusion of `customerNumber`, tenant ID, normalized values, metrics, and lifecycle in `windows_application/test/features/customer_management/models/customer_drafts_test.dart`.
- [x] T023 [P] Add failing repository contract tests for every approved Phase 1 endpoint/query/payload plus 403/404/409/422/network/timeout/server mapping in `windows_application/test/features/customer_management/repositories/customer_management_repository_test.dart`; exercise the production repository with a controlled Dio adapter, not an alternate payload builder.
- [x] T024 [P] Add failing auth capability parse/storage/refresh compatibility tests in `windows_application/test/features/auth/auth_session_storage_contract_test.dart` and `windows_application/test/features/customer_management/customer_management_access_test.dart`; cover owner, granted manager, ungranted manager, employee, missing legacy capability data, and permission revocation.
- [x] T025 Run T021–T024 and record their expected failures in `specs/flutter-customer-management/implementation-log.md` before production implementation.

### Models and repository

- [x] T026 [P] Implement immutable lifecycle, customer, phone, group-summary, group, page metadata, and query models in `windows_application/lib/features/customer_management/models/customer_models.dart`, `customer_group_models.dart`, and `customer_queries.dart`; use strict required-field parsing and equality suitable for request identity.
- [x] T027 [P] Implement `CustomerDraft`, stable `CustomerPhoneDraft` row identity, `GroupDraft`, dirty equality, and camelCase request serialization in `windows_application/lib/features/customer_management/models/customer_drafts.dart`; do not normalize raw phones or generate customer numbers.
- [x] T028 Define the testable repository interface and production Dio implementation in `windows_application/lib/features/customer_management/repositories/customer_management_repository.dart`; use `getEnvelope` for paginated responses, never send `X-Tenant-Id`, and never auto-retry mutations.
- [x] T029 Implement one localized presentation failure mapper from `ApiException.type`, stable `code`, and validation paths in `windows_application/lib/features/customer_management/models/customer_failure.dart`; retain machine-readable nested field paths and never show raw server text as untranslated production copy.
- [x] T030 Register the production Customer repository in `windows_application/lib/core/services/service_locator.dart` using the existing `DioApiClient`, with the same explicit test injection/reset pattern used by neighboring modules.

### Auth, localization, routing, and shared UI

- [x] T031 Extend the approved authenticated capability mapping in `windows_application/lib/features/auth/models/auth_session.dart`, `windows_application/lib/features/auth/repositories/auth_repository.dart`, and storage compatibility code only as required by T005; missing capability data must default closed for managers, while owners retain their server-defined capability.
- [x] T032 Implement the single `CustomerManagementAccess` projection in `windows_application/lib/features/customer_management/models/customer_management_access.dart`; sidebar/route/control visibility must consume the authoritative capability, and backend 403 must remain the final authority.
- [x] T033 [P] Add all Customer Management keys—including statuses, errors, absence values, confirmations, accessibility labels, tooltips, pagination, dirty-discard, and group membership copy—to `windows_application/lib/l10n/app_en.arb` and `windows_application/lib/l10n/app_ar.arb`; run Flutter localization generation and do not hard-code fallback UI strings.
- [x] T034 Add route constants/builders for all eight routes in `windows_application/lib/app/customer_management_route_locations.dart`; validate numeric IDs and keep route generation independent of cached list objects.
- [x] T035 Add failing shell/router/access tests for all eight direct routes, customers sidebar selection, Customer/Groups tab selection, refresh/back-forward behavior, and owner/granted-manager/ungranted-manager/employee visibility in `windows_application/test/app/customer_management_routing_test.dart`.
- [x] T036 Register all eight routes and scoped cubit providers in `windows_application/lib/app/app_router.dart`, add the authorized destination behavior to `windows_application/lib/shared/widgets/app_sidebar.dart`, and map every Customer route to active destination `customers`; preserve the existing `ShellRoute` and provider topology.
- [x] T037 [P] Implement shared Phase 2 widgets in `windows_application/lib/features/customer_management/widgets/customer_management_scaffold.dart`, `customer_management_state_panel.dart`, `customer_lifecycle_badge.dart`, `customer_pagination.dart`, `customer_bidi_value.dart`, and `customer_confirmation_dialog.dart`; compose existing shared primitives rather than creating a second design system.
- [x] T038 Re-run all Phase 3 tests, `flutter test test/app/customer_management_routing_test.dart`, targeted `flutter analyze` for changed files if supported, and `git diff --check`; record exact results before starting US1.

**Checkpoint**: Production models/repository/auth/access/localization/routes exist, all foundation tests pass, and no screen contains fake data.

---

## Phase 4: User Story 1 — Find and Inspect Customers (Priority: P1) 🎯 MVP

**Goal**: Authorized administrators can navigate to a bounded server-driven customer collection, search/filter/page it, and load a complete customer detail route.

**Independent Test**: With more than one backend page, search by identity/contact, filter status/group, change pages without losing criteria, open active and archived details directly, and observe only authoritative fields.

### Tests first

- [x] T039 [P] [US1] Add failing customer-list cubit tests for initial load, refresh, default status, group/status filters, page preservation/reset, 300 ms debounce, immediate Enter/clear, generation-based stale response rejection, duplicate response prevention, empty/no-results/403/error/retry in `windows_application/test/features/customer_management/controllers/customer_list_cubit_test.dart`.
- [x] T040 [P] [US1] Add failing customer-detail cubit tests for direct ID load, refresh, archived customer, 403, 404, network/server retry, route ID change, and late-response rejection in `windows_application/test/features/customer_management/controllers/customer_detail_cubit_test.dart`.
- [x] T041 [P] [US1] Add failing customer-list widget tests for reference screens 01–04, server metadata pagination, customer number/name/primary phone/group/status/actions, explicit no-phone, loading/empty/no-results/error/forbidden states, and absence of last-visit/order/spend columns in `windows_application/test/features/customer_management/views/customer_list_screen_test.dart`.
- [x] T042 [P] [US1] Add failing customer-detail widget tests for identity, all phones/type/primary, email, birth date, active plus archived groups, lifecycle, notes, absence values, direct reload, and explicit absence of metrics/recent orders/order-history tab in `windows_application/test/features/customer_management/views/customer_detail_screen_test.dart`.
- [x] T043 [US1] Run T039–T042 and record expected failures before implementing US1 in `specs/flutter-customer-management/implementation-log.md`.

### Implementation

- [x] T044 [US1] Implement immutable customer-list state and `CustomerListCubit` in `windows_application/lib/features/customer_management/controllers/customer_list_state.dart` and `customer_list_cubit.dart`; use an immutable criteria object plus generation token as the correctness gate, render one bounded page, and cancel debounce timers safely on close.
- [x] T045 [US1] Implement immutable direct-load detail state and `CustomerDetailCubit` in `windows_application/lib/features/customer_management/controllers/customer_detail_state.dart` and `customer_detail_cubit.dart`; never require router `extra` or a cached list item.
- [x] T046 [P] [US1] Implement responsive customer collection components in `windows_application/lib/features/customer_management/widgets/customer_collection.dart`; use a desktop table and accessible narrow record layout without clipping primary actions.
- [x] T047 [US1] Build `windows_application/lib/features/customer_management/views/customer_list_screen.dart` using T044/T046, the existing shell, localized real-state panels, bounded filters/pagination, and reference screens 01–04; do not include prototype arrays or Phase 4 columns.
- [x] T048 [P] [US1] Implement customer identity/contact/phone/group/note components in `windows_application/lib/features/customer_management/widgets/customer_detail_sections.dart` with explicit bidi handling and archived-group treatment.
- [x] T049 [US1] Build `windows_application/lib/features/customer_management/views/customer_detail_screen.dart` using T045/T048 and reference screens 09–10; render backend `allowedActions` and lifecycle state without metrics, recent orders, or an Orders tab.
- [x] T050 [US1] Run all US1 tests plus `windows_application/test/app/customer_management_routing_test.dart`; inspect rendered output at representative Windows and Web widths and record the checkpoint result in `specs/flutter-customer-management/implementation-log.md`.

**Checkpoint**: US1 is independently usable and testable as a read-only MVP with real bounded data.

---

## Phase 5: User Story 2 — Create and Edit Customers (Priority: P1)

**Goal**: Authorized administrators can create and edit complete customer aggregates while preserving raw phones, archived memberships, drafts, and backend validation.

**Independent Test**: Create with zero phones; create/edit multiple phones and explicit primary; change memberships including retained archived groups; fail validation without losing input; succeed into the saved detail route.

### Tests first

- [x] T051 [P] [US2] Add failing form-cubit tests for create/edit initialization, direct edit load, dirty equality, zero phones, stable phone row IDs, add/remove/type/primary changes, no implicit replacement primary, active group selection, archived group preservation/removal, local usability validation, nested backend error mapping, single-flight submit, failure retention, and success result in `windows_application/test/features/customer_management/controllers/customer_form_cubit_test.dart`.
- [x] T052 [P] [US2] Add failing form widget tests for reference screens 11–13, customer-number read-only behavior, phone controls, primary accessibility, group chips, archived group warnings, mapped field/general errors, loading/403/404, disabled duplicate save, and responsive keyboard operation in `windows_application/test/features/customer_management/views/customer_form_screen_test.dart`.
- [x] T053 [P] [US2] Add failing dirty-navigation tests for Cancel, sidebar, tabs, browser back/forward, direct route changes, confirmed discard, locale change, and viewport change in `windows_application/test/features/customer_management/customer_form_navigation_test.dart`; reuse the existing navigation guard contract.
- [x] T054 [P] [US2] Add failing shared-phone advisory tests in `windows_application/test/features/customer_management/shared_phone_warning_test.dart`; show it only when an authorized backend response supplies match data, allow deliberate continuation, and prove absence of a match contract causes no local tenant-wide scan or block.
- [x] T055 [US2] Run T051–T054 and record expected failures before implementing US2 in `specs/flutter-customer-management/implementation-log.md`.

### Implementation

- [x] T056 [US2] Implement `CustomerFormState` and `CustomerFormCubit` in `windows_application/lib/features/customer_management/controllers/customer_form_state.dart` and `customer_form_cubit.dart`; preserve complete drafts, stable row/error identity, explicit primary semantics, archived group IDs, single-flight submission, and authoritative response handling.
- [x] T057 [P] [US2] Implement reusable profile, phone-row, group-selection, validation-summary, and sticky action widgets in `windows_application/lib/features/customer_management/widgets/customer_form_sections.dart`; all values remain editable/preserved and all strings localized.
- [x] T058 [US2] Build create/edit modes in `windows_application/lib/features/customer_management/views/customer_form_screen.dart` from T056/T057 and reference screens 11–13; wire the existing unsaved-navigation guard and prevent route/locale/viewport rebuilds from recreating the draft cubit.
- [x] T059 [US2] Wire create/update repository calls so success replaces navigation with `/customers/{returnedId}` and seeds then refreshes authoritative detail state; validation, forbidden, conflict, timeout, network, and server failures retain the draft and never navigate.
- [x] T060 [US2] Implement the optional shared-phone warning in `windows_application/lib/features/customer_management/widgets/shared_phone_warning_dialog.dart` only against the approved authorized backend match contract; if no such contract was approved in T005, keep the widget unreachable and document the intentional omission in `implementation-log.md`.
- [x] T061 [US2] Run all US2 tests plus US1 regression tests and `git diff --check`; verify exact raw phone serialization and archived group retention, then record results in `specs/flutter-customer-management/implementation-log.md`.

**Checkpoint**: US2 creates and edits real aggregates without client-owned Customer rules or lost form data.

---

## Phase 6: User Story 3 — Manage Customer Lifecycle (Priority: P1)

**Goal**: Active, inactive, and archived customer transitions are explicit, confirmed where required, single-flight, and reflected only after backend success.

**Independent Test**: Deactivate, activate, archive, restore, and drive every failure class while checking list/detail/edit consistency and unchanged prior state on failure.

### Tests first

- [x] T062 [P] [US3] Add failing lifecycle cubit tests for valid actions from backend status/`allowedActions`, one in-flight mutation, no optimistic state, success replacement, affected-list invalidation, invalid transition, 403, 404, 409, timeout/network/server failure, and permission revocation in `windows_application/test/features/customer_management/controllers/customer_lifecycle_cubit_test.dart`.
- [x] T063 [P] [US3] Add failing lifecycle widget tests for localized named consequence dialogs, progress/disabled conflicting controls, restored customer remaining Inactive, error announcement, retry-safe copy, and focus restoration in `windows_application/test/features/customer_management/views/customer_lifecycle_test.dart`.
- [x] T064 [US3] Run T062–T063 and record expected failures before implementing US3 in `specs/flutter-customer-management/implementation-log.md`.

### Implementation

- [x] T065 [US3] Implement `CustomerLifecycleState` and `CustomerLifecycleCubit` in `windows_application/lib/features/customer_management/controllers/customer_lifecycle_state.dart` and `customer_lifecycle_cubit.dart`; call only the selected backend command, never auto-retry, and retain the pre-mutation entity on any failure.
- [x] T066 [US3] Add localized deactivate/archive/restore confirmation and immediate activate wiring to customer list, detail, and edit views through `windows_application/lib/features/customer_management/widgets/customer_lifecycle_actions.dart`; source visible actions from the entity contract.
- [x] T067 [US3] On lifecycle success, replace mounted detail/edit entity state from the response and refresh mounted customer collections with their existing criteria in `windows_application/lib/features/customer_management/controllers/customer_lifecycle_cubit.dart`; ensure Active/default-filter removal and restored-Inactive behavior come from refreshed backend results.
- [x] T068 [US3] Run all US3 tests plus US1/US2 regressions; manually inspect that failed requests never alter visible lifecycle state and record evidence in `specs/flutter-customer-management/implementation-log.md`.

**Checkpoint**: All customer lifecycle actions are authoritative, non-destructive, and independently verified.

---

## Phase 7: User Story 4 — Manage Groups and Memberships (Priority: P2)

**Goal**: Administrators can use bounded group collections, create/edit/inspect/lifecycle groups, and add/remove members through authoritative membership commands.

**Independent Test**: Search/page/filter groups; create/edit into group detail; page/search members; select eligible candidates across pages; add; confirm a named removal; archive/restore; refresh authoritative counts.

### Tests first

- [x] T069 [P] [US4] Add failing group-list cubit tests for bounded pagination, search debounce/Enter/clear, Active/Archived/All filters, stable criteria, stale responses, refresh, empty/no-results/403/error/retry, and member counts in `windows_application/test/features/customer_management/controllers/customer_group_list_cubit_test.dart`.
- [x] T070 [P] [US4] Add failing group-detail cubit tests for direct load, bounded member search/pagination, stale responses, group count consistency, 403/404/error/retry, and archived retained members in `windows_application/test/features/customer_management/controllers/customer_group_detail_cubit_test.dart`.
- [x] T071 [P] [US4] Add failing group-form cubit/widget tests for create/edit, name validation, dirty guard, single-flight save, authoritative success-to-detail navigation, failure retention, and explicit absence of description/status-edit controls in `windows_application/test/features/customer_management/controllers/customer_group_form_cubit_test.dart` and `windows_application/test/features/customer_management/views/customer_group_form_screen_test.dart`.
- [x] T072 [P] [US4] Add failing candidate/membership tests for bounded search, page-retained selection, existing/ineligible exclusion, duplicate prevention, atomic multi-add, named remove confirmation, unrelated membership retention, count/member refresh, and failure retention in `windows_application/test/features/customer_management/controllers/customer_group_membership_cubit_test.dart` and `windows_application/test/features/customer_management/views/customer_group_membership_test.dart`.
- [x] T073 [P] [US4] Add failing group lifecycle tests for archive/restore confirmation, retained members, no optimistic update, all error classes, and authoritative status/count refresh in `windows_application/test/features/customer_management/views/customer_group_lifecycle_test.dart`.
- [x] T074 [P] [US4] Add failing reference-layout tests for screens 05–07, module tabs, group rows, detail/member rows, accessible actions, localized absence/error states, responsive layouts, and no description in `windows_application/test/features/customer_management/views/customer_group_screens_test.dart`.
- [x] T075 [US4] Run T069–T074 and record expected failures before implementing US4 in `specs/flutter-customer-management/implementation-log.md`.

### Implementation

- [x] T076 [P] [US4] Implement `CustomerGroupListState/Cubit` in `windows_application/lib/features/customer_management/controllers/customer_group_list_state.dart` and `customer_group_list_cubit.dart` with the same immutable criteria/generation/debounce rules as customers, but without sharing mutable timers or result state.
- [x] T077 [P] [US4] Implement `CustomerGroupDetailState/Cubit` in `windows_application/lib/features/customer_management/controllers/customer_group_detail_state.dart` and `customer_group_detail_cubit.dart`; load group identity and bounded members independently by route ID and reconcile authoritative `memberCount` after refresh.
- [x] T078 [P] [US4] Implement `CustomerGroupFormState/Cubit` in `windows_application/lib/features/customer_management/controllers/customer_group_form_state.dart` and `customer_group_form_cubit.dart`; the only writable field is name, and success navigates to the returned group detail.
- [x] T079 [P] [US4] Implement `CustomerGroupMembershipState/Cubit` in `windows_application/lib/features/customer_management/controllers/customer_group_membership_state.dart` and `customer_group_membership_cubit.dart`; own bounded candidate criteria, stable cross-page selected IDs, one mutation at a time, and no local membership success before the backend response.
- [x] T080 [US4] Build `customer_group_list_screen.dart`, `customer_group_detail_screen.dart`, and `customer_group_form_screen.dart` under `windows_application/lib/features/customer_management/views/` against reference screens 05–07; omit description and derive all counts/status/actions from backend state.
- [x] T081 [US4] Build accessible group collection/member/candidate components and the add-member dialog under `windows_application/lib/features/customer_management/widgets/customer_group_components.dart`; candidates remain bounded and selected IDs survive page changes only while the dialog is open.
- [x] T082 [US4] Implement named remove confirmation and add/remove success refresh in `windows_application/lib/features/customer_management/views/customer_group_detail_screen.dart` and `windows_application/lib/features/customer_management/controllers/customer_group_membership_cubit.dart`; remove only the selected membership, reload members and group/count, and retain prior UI on failure.
- [x] T083 [US4] Implement group archive/restore through a single-flight lifecycle state in `windows_application/lib/features/customer_management/controllers/customer_group_detail_cubit.dart` and localized dialogs in `windows_application/lib/features/customer_management/widgets/customer_group_components.dart`; memberships remain represented after archive and status changes only after backend success.
- [x] T084 [US4] Run all US4 tests plus US1–US3 regressions and router tests; verify no endpoint loads an unbounded customer/group collection and record evidence in `specs/flutter-customer-management/implementation-log.md`.

**Checkpoint**: US4 is complete using only the frozen bounded membership contract.

---

## Phase 8: User Story 5 — Recover From Real UI States (Priority: P2)

**Goal**: Every route and mutation is understandable and recoverable across real loading, empty, no-results, authorization, validation, conflict, network, and server states in Arabic/English and Windows/Web layouts.

**Independent Test**: Drive every state in both locales and representative viewports with keyboard/focus/semantics assertions and no fake fallback data.

### Tests first

- [x] T085 [P] [US5] Add a state-matrix widget test covering initial loading, refresh, success, empty, filtered no-results, retryable error/retry, forbidden, not-found, validation, conflict, and mutation progress across every Customer/Group route in `windows_application/test/features/customer_management/customer_management_state_matrix_test.dart`.
- [x] T086 [P] [US5] Add Arabic RTL and English LTR tests for every screen/dialog/status/error/absence value, explicit bidi handling of customer numbers/phones/email/dates, long content, and untranslated-string detection in `windows_application/test/features/customer_management/customer_management_localization_test.dart`.
- [x] T087 [P] [US5] Add representative Windows desktop and Web/narrow layout tests for no clipped primary actions, reachable table/card content, minimum target sizes, visible focus, semantics, focus containment/restoration, and keyboard traversal in `windows_application/test/features/customer_management/customer_management_accessibility_test.dart`.
- [x] T088 [P] [US5] Add route/request race tests for rapid typing, filters, page changes, target changes, locale/viewport rebuilds, back/forward, cubit close, and responses after disposal in `windows_application/test/features/customer_management/customer_management_race_test.dart`.
- [x] T089 [P] [US5] Add production-path guard tests proving no seeded customer/group arrays, demo switches, hard-coded identifiers, simulated success, client-generated customer numbers, Phase 4 metrics/history, or group descriptions are reachable in `windows_application/test/features/customer_management/customer_management_scope_guard_test.dart`.
- [x] T090 [US5] Run T085–T089 and record expected failures before cross-cutting hardening in `specs/flutter-customer-management/implementation-log.md`.

### Implementation and hardening

- [x] T091 [US5] Complete all missing state branches and localized Retry/Clear actions in `windows_application/lib/features/customer_management/widgets/customer_management_state_panel.dart` and the six screens under `windows_application/lib/features/customer_management/views/`; keep empty/no-results distinct and never disguise 403/404 as empty or retry them endlessly.
- [x] T092 [US5] Correct RTL/LTR, mixed-direction isolation, long-text wrapping/tooltip access, directional icons, semantic names, focus order, dialog focus containment/restoration, and target sizes in `windows_application/lib/features/customer_management/views/` and `widgets/` without changing domain values.
- [x] T093 [US5] Correct responsive behavior at representative Windows and Web widths in `windows_application/lib/features/customer_management/widgets/customer_management_scaffold.dart` and the six screens under `windows_application/lib/features/customer_management/views/`; primary actions must remain reachable and locale/viewport changes must preserve drafts.
- [x] T094 [US5] Audit every async cubit under `windows_application/lib/features/customer_management/controllers/` for debounce disposal, generation checks, `isClosed`/lifecycle safety, duplicate mutation suppression, and no emissions after close; add focused regressions for every correction.
- [x] T095 [US5] Run the complete focused Customer Management suite and the existing shell/localization/navigation/network regression tests; record exact commands, durations, and results in `specs/flutter-customer-management/implementation-log.md`.

**Checkpoint**: All specified real states, languages, directions, accessibility behavior, and supported layouts are covered and green.

---

## Phase 9: Final Verification and Scope Audit

**Purpose**: Produce evidence before claiming Phase 2 complete.

- [x] T096 Run `dart format --output=none --set-exit-if-changed` on the exact changed Dart files under `windows_application/lib/` and `windows_application/test/`; if formatting is needed, run `dart format` only on those files and re-run the check.
- [x] T097 Run `flutter test test/features/customer_management` from `windows_application/` and record the complete pass/fail/skip result in `specs/flutter-customer-management/implementation-log.md`.
- [x] T098 Run `flutter test test/app/customer_management_routing_test.dart test/app_shell_navigation_transitions_test.dart test/app_shell_bilingual_test.dart test/app_shell_rtl_test.dart test/core/navigation/unsaved_navigation_guard_test.dart test/core/network/dio_api_client_test.dart` from `windows_application/` and record the complete result.
- [x] T099 Run the full `flutter test` suite from `windows_application/` after focused suites are green; do not run another Flutter test process concurrently, and record every pre-existing or feature failure in `specs/flutter-customer-management/implementation-log.md`.
- [x] T100 Run `flutter analyze` from `windows_application/`; separate new Customer Management diagnostics from unrelated pre-existing diagnostics in `specs/flutter-customer-management/implementation-log.md` and do not describe a partial run as full analysis.
- [x] T101 Run `flutter build windows` and `flutter build web` from `windows_application/`; capture either successful artifact or exact environment/toolchain/long-path blocker in `specs/flutter-customer-management/implementation-log.md` without claiming a blocked target passed.
- [x] T102 Re-run the focused backend Customer contract suite serially with `docker compose exec -T backend php artisan test --filter='CustomerAuthorizationApiTest|CustomerGroupApiTest|CustomerRoutePermissionMapTest|CustomerManagementApiTest|CustomerSearchPaginationTest'`; record it separately from Flutter results in `specs/flutter-customer-management/implementation-log.md`.
- [x] T103 Run `git diff --check` from the repository root, fix only whitespace errors introduced in feature-owned files, and record the result in `specs/flutter-customer-management/implementation-log.md`.
- [x] T104 Inspect `git status --short` and the complete feature diff; record in `specs/flutter-customer-management/implementation-log.md` that all changes map to requirements, unrelated user work is preserved, no secrets/PII fixtures were introduced, and generated localization changes are limited to new keys.
- [x] T105 Search `windows_application/lib/features/customer_management/` and its integration seams for hard-coded strings, fake data, `X-Tenant-Id`, local normalization/number generation, Phase 4 fields, descriptions, mutation retry, and unbounded requests; correct violations and record the audit in `specs/flutter-customer-management/implementation-log.md`.
- [x] T106 Update `specs/flutter-customer-management/implementation-log.md` with a final requirement-to-test/command evidence table, all incomplete checks, and all unrelated/pre-existing failures; never convert historical counts into current pass claims.
- [x] T107 Re-check every checkbox in `specs/flutter-customer-management/tasks.md` against actual committed or worktree evidence and mark only genuinely completed tasks; Phase 2 is complete only when T096–T106 are green or their unresolved blockers are explicitly reported without a success claim.

---

## Dependencies and Execution Order

### Phase dependencies

- **Phase 1** has no implementation dependency and establishes repository/contract truth.
- **Phase 2** depends on T005–T006 and blocks all Flutter tasks.
- **Phase 3** depends on the Phase 2 hard-stop checkpoint and blocks all user stories.
- **US1 (Phase 4)** depends on Phase 3 and establishes list/detail components reused by later stories.
- **US2 (Phase 5)** depends on Phase 3 and integrates with US1 detail routing.
- **US3 (Phase 6)** depends on US1 detail/list and US2 edit surfaces.
- **US4 (Phase 7)** depends on Phase 3 plus the Phase 2 group/membership contracts; it may reuse collection/form/state widgets but must keep independent cubit state.
- **US5 (Phase 8)** depends on all selected story implementations because it verifies the complete state matrix.
- **Final verification (Phase 9)** depends on all required stories and hardening tasks.

### Within each story

1. Add focused tests.
2. Run them and confirm the intended failure.
3. Implement models/state before cubits/repositories that consume them.
4. Implement controllers before screens that bind them.
5. Re-run the focused tests.
6. Run affected earlier-story regression tests.
7. Inspect the scoped diff before moving to the next checkpoint.

### Safe parallel opportunities

- T007 can run in parallel with the sequential T008–T010 group-test sequence because it edits a different test file; Laravel execution remains serial.
- T021–T024 can run in parallel after Phase 2 is green.
- T026 and T027 can run in parallel; T028 waits for both.
- Within each story, tasks explicitly marked `[P]` may run in parallel only when they do not edit the same file.
- T085–T089 can be authored in parallel after US1–US4 are implemented.
- Do not parallelize tasks that edit `app_router.dart`, `service_locator.dart`, ARB files, shared cubits, or the same test file.

## MVP and Incremental Delivery

1. Complete Phases 1–3.
2. Complete US1 and stop at T050 for a read-only bounded Customer Management MVP.
3. Add US2, then stop and validate customer aggregate create/edit.
4. Add US3, then stop and validate lifecycle behavior.
5. Add US4 only against the frozen bounded membership contract.
6. Complete US5 and the full verification phase before declaring Phase 2 complete.

## Completion Definition

A checkbox may be marked complete only when:

- its specified file change exists and stays within scope;
- its focused automated test was observed failing before implementation when the task says tests first;
- the focused test now passes;
- no backend/client authority boundary was duplicated or weakened;
- the result preserves raw/legacy/archived values exactly as specified; and
- the command and result are recorded in `specs/flutter-customer-management/implementation-log.md`.

The feature is not complete merely because screens render. It requires authoritative
real-state behavior, bounded API use, both locales/directions, both target builds or
accurately reported blockers, focused and broader regression evidence, analysis,
formatting, `git diff --check`, and a final scope/secrets/fake-state audit.
