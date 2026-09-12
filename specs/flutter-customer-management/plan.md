# Implementation Plan: Phase 2 — Flutter Customer Management

**Branch**: `flutter-customer-management` | **Date**: 2026-09-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/flutter-customer-management/spec.md`

## Summary

Build the tenant-wide Customer Management module inside the existing Flutter
Windows/Web shell. The module will use `go_router`, `flutter_bloc`, GetIt, the
shared `DioApiClient`, generated Arabic/English localization, and existing shared
widgets to provide bounded customer/group collections, direct-load detail routes,
transactional create/edit forms, lifecycle actions, and group membership flows.

The Flutter client will treat the Customer domain API as authoritative: it will
preserve raw phone input and archived memberships, submit complete customer drafts,
render only server-confirmed lifecycle changes, ignore superseded requests, and
never derive permissions, customer numbers, normalized phone values, history, or
metrics locally.

Two Phase 1 contract gaps block complete implementation and must be resolved and
contract-tested before Flutter integration begins:

1. the authenticated session has role identity but no authoritative
   `customer.manage` capability for distinguishing permitted from unpermitted
   managers; and
2. the current group endpoints return an unpaginated active-only collection with no
   member count, bounded member list, or bounded eligible-candidate query.

These are prerequisite completions of the assumed Phase 1 contract, not permission
to invent Flutter workarounds or broaden Phase 2 into a backend-domain redesign.

## Technical Context

**Language/Version**: Dart SDK `^3.12.1`; Flutter project language level inherited from `windows_application/pubspec.yaml`

**Primary Dependencies**: Flutter, `flutter_bloc 9.1.1`, `equatable 2.0.8`, `go_router 17.3.0`, `get_it 9.2.1`, `dio 5.9.2`, `intl 0.20.2`, `skeletonizer 2.1.0`, generated Flutter localization

**Storage**: No new client persistence. Customer/group state and form drafts remain in memory; Laravel/PostgreSQL remains authoritative. Existing secure auth-session storage is reused unchanged.

**Testing**: `flutter_test` widget/unit tests, repository contract tests using production models/repositories, router/shell tests, Windows and Web build/smoke gates

**Target Platform**: Existing Flutter Windows desktop and Web targets

**Project Type**: Brownfield cross-platform Flutter client consuming an existing Laravel JSON API

**Performance Goals**: Search dispatch after a 300 ms pause; Enter and clear dispatch immediately; one request per deliberate page/filter transition; stale responses never replace newer criteria; stable interaction and scrolling at supported Windows/Web sizes

**Constraints**: Bounded server pagination only; no fabricated records or metrics; no automatic mutation retry; no client phone/name normalization; all strings localized; keyboard-accessible RTL/LTR UI; preserve drafts across request failures, locale changes, and responsive relayouts

**Scale/Scope**: Eight stable routes covering customer and group administration; four bounded collection contexts (customers, groups, group members, add-member candidates); Arabic/English; Windows/Web; Phase 2 only

## Constitution Check

*GATE: Must pass before implementation. Re-check after the prerequisite API contract is frozen and after Flutter design is complete.*

- **Tenant and authorization — PASS (frozen Phase 1 contract)**: Customers and groups are
  tenant-owned but tenant-wide, so Phase 2 introduces no branch selector or branch
  ownership rule. `DioApiClient` already supplies the opaque bearer token and strips
  `X-Tenant-Id`; Flutter must not send a tenant ID. Every endpoint remains protected
  by backend Customer authorization and Platform Super Admin remains separate.
  Owner visibility can be derived from the authenticated role, but manager
  visibility is provided by the frozen tenant-authenticated
  `GET /customer-management/capabilities` contract. A role-only guess or a call to
  the owner-only manager-configuration endpoint remains prohibited.
- **Domain authority and scope — PASS**: Laravel Customer Management owns identity,
  phones, groups, membership validity, lifecycle, normalization, and validation.
  Flutter owns only presentation, transient drafts, request coordination, and
  navigation. POS quick-create/selection, Orders attachment, loyalty, discounts,
  import, history, metrics, and backend-domain redesign remain excluded.
- **History and data safety — PASS**: No schema, import, or historical-record write
  is planned. Archive/deactivate/restore are distinct API commands. Archived groups
  already assigned to a customer stay visible in drafts and are removed only by an
  explicit user action. There is no hard-delete UI.
- **Exact semantics — PASS**: Money, tax, inventory quantity, conversion, and
  accounting are N/A because the screens neither request nor calculate them. Raw
  phone strings and backend customer numbers are preserved exactly. Birth date is a
  calendar date; timestamps are parsed as instants and formatted through existing
  localized/timezone-aware utilities when displayed. Client mutations are
  single-flight and are not retried automatically because a timed-out request may
  already have committed.
- **Contracts and scale — PASS (frozen Phase 1 contract)**: Customer list/detail and
  customer mutation contracts exist, including pagination and structured API errors.
  The frozen additive Phase 1 contract defines bounded group list/member/candidate
  queries, member counts, self capability discovery, and atomic add/remove commands.
  T007–T020 implement and verify it before any Flutter endpoint consumption. No
  unbounded fetch-and-filter fallback is acceptable.
- **UX and platforms — PASS**: Implement within `AppShell`, `AppSidebar`, existing
  design tokens/shared widgets, and generated `AppLocalizations`. The reference HTML
  is visual evidence only. Arabic RTL, English LTR, mixed-direction values, keyboard
  focus, semantics, responsive Windows/Web layouts, and distinct real-state screens
  are explicit implementation and test concerns.
- **Verification and scope — PASS**: Plan focused model/repository/cubit/widget/router
  tests, localization/layout coverage, Flutter analysis, formatting, Windows/Web
  build or established smoke gates, and `git diff --check`. Final diff review must
  exclude prototype data, Phase 4 regions, unrelated formatting, and pre-existing
  worktree changes. Backend prerequisite verification is reported separately from
  Flutter verification.

### Gate resolution required before implementation

Freeze and test an additive Phase 1 contract that provides:

- an authenticated self-capability signal containing `customer.manage` (owners and
  granted managers true; other actors false), returned during authentication/session
  validation or from a tenant-authenticated self-capabilities endpoint;
- paginated administrative group search with `search`, `status`, `page`, `perPage`,
  stable ordering, standard pagination metadata, and `memberCount`;
- paginated group-member search by group identity; and
- paginated eligible add-member candidate search that excludes current members and
  lifecycle-ineligible customers under backend tenant/permission rules.

The mutation contract must also define how one or more members are added and one
membership is removed without making Flutter reconstruct unknown membership sets.
Prefer explicit group membership commands with authoritative refreshed group/count
responses. If the approved contract instead uses complete-set replacement, it must
provide the complete bounded-safe version/concurrency semantics needed to prevent
lost updates. The contract owner must decide this in Phase 1; Flutter must not infer
it.

## Architecture and Design Decisions

### 1. Feature boundary and dependency flow

Use a dedicated `features/customer_management` vertical slice:

```text
views/widgets -> cubits and immutable states -> CustomerManagementRepository
              -> DioCustomerManagementRepository -> DioApiClient -> Phase 1 API
```

- Widgets receive display-ready state and emit user intent; they do not parse JSON,
  decide authorization, normalize search/phone data, or mutate entity objects.
- The repository interface makes cubits testable while the API implementation is the
  only production transport path.
- API models parse nullable/optional fields defensively but reject malformed required
  identity, lifecycle, and pagination values with a visible failure rather than
  manufacturing defaults that look valid.
- Reuse shared loading, empty, dialog, button, card, breadcrumbs, and responsive
  layout widgets. Add Customer-specific widgets only where the shared primitives do
  not encode the reference interaction.

### 2. Routing, shell, and access

Add stable routes under `/customers`:

```text
/customers
/customers/new
/customers/:customerId
/customers/:customerId/edit
/customers/groups
/customers/groups/new
/customers/groups/:groupId
/customers/groups/:groupId/edit
```

Register them as children of the existing `ShellRoute`, map every route to the
`customers` sidebar destination, and preserve tab selection from route location.
List routes own their query criteria; detail/edit routes load by numeric route ID and
never require list `extra` state. Invalid IDs and 404/403 outcomes render explicit
localized states.

Introduce one `CustomerManagementAccess` projection fed only by the authenticated
self-capability contract. Use it for sidebar visibility, route redirects, and control
visibility while retaining backend enforcement on every request. A 403 received
after permission revocation replaces the page with the forbidden state and does not
start an automatic retry loop.

Dirty create/edit routes participate in the existing unsaved-navigation guard. A
confirmed discard allows the pending navigation once; locale/viewport rebuilds do
not count as navigation and must retain the cubit/draft instance.

### 3. Models and API mapping

Define immutable models for:

- `Customer`, `CustomerPhone`, `CustomerGroupSummary`, and lifecycle enums;
- `CustomerGroup`, including backend-provided member count;
- generic `CustomerPage<T>` with `currentPage`, `lastPage`, `perPage`, and `total`;
- customer/group/member/candidate query values whose equality represents one
  request identity;
- `CustomerDraft`, `CustomerPhoneDraft`, and `GroupDraft`; and
- mutation failures mapped from `ApiException` by error type, stable code, and
  validation error key.

Serialization uses backend camelCase fields. Customer create/update sends only
specified writable fields: `name`, `email`, `birthDate`, `notes`, `phones`, and
`groupIds`. It never sends `customerNumber`, tenant identity, normalized phone,
validation status, metrics, or derived lifecycle. Preserve phone `rawNumber`
verbatim except for whatever the user explicitly edits.

Map nested validation paths such as `phones.0.rawNumber`, `phones.0.isPrimary`, and
`groupIds` back to stable draft row IDs so adding/removing a row after an error does
not attach a message to the wrong visible phone.

### 4. Collection request coordination

Give each collection its own cubit and immutable criteria object. Criteria changes
increment a request generation token. A response may update visible state only when
its generation and criteria still match the current request. Cancellation may reduce
work but is not the correctness mechanism.

- Typing schedules a 300 ms debounce.
- Enter cancels the timer and dispatches immediately.
- Clearing non-empty search cancels the timer and dispatches the unsearched first
  page immediately.
- Search or filter changes reset to page 1; page changes preserve all criteria.
- Refresh retains criteria and visible content only as explicitly marked stale while
  a progress indicator communicates refresh.
- Initial empty and filtered no-results remain distinct states.

Do not append pages into a client-owned master list. Render the current bounded page
and use server metadata for controls, counts, and enabled state.

### 5. Customer form semantics

The form cubit owns a draft initialized empty for create or from a freshly loaded
customer for edit. It tracks baseline equality for the dirty guard, stable phone-row
keys, locally useful validation, mapped backend validation, and single-flight submit
state.

- Zero phones is valid and serializes as an empty list when deliberately supplied.
- One or more phones require exactly one primary before submission.
- Removing the primary selects nothing automatically; the user must explicitly pick
  another primary unless the final phone was removed.
- Raw phone text is never normalized, formatted, rejected, or rewritten by Flutter.
- A shared-phone warning appears only from an approved authorized backend match
  signal. Without that signal, Phase 2 shows no speculative warning and never loads
  all customers to simulate it.
- Active groups may be newly selected. Assigned archived groups render separately,
  remain selected by default, and disappear only after explicit removal.

On success, navigate with replacement to `/customers/{id}` and let the detail cubit
render the returned entity immediately while also supporting a route-identity
refresh. On failure, retain the full draft and focus/announce the first actionable
error. Never retry a mutation automatically.

### 6. Lifecycle and membership mutations

Lifecycle controls come from the backend entity status and `allowedActions` rather
than a broad local role table. Deactivate, archive, restore, group archive, and group
restore open localized consequence dialogs. Activate may execute directly. While a
mutation is active, all conflicting controls for that entity are disabled.

Keep the old entity visible until success. On success, replace detail state from the
response and refresh affected collection cubits if mounted. On validation,
authorization, conflict, network, or server failure, retain the old entity and
present a localized retry-safe error.

Group details use the bounded members endpoint. The add-member dialog owns a
separate paginated candidate cubit plus a stable selected-ID set that survives page
changes during the open dialog. Successful add/remove commands clear only completed
selection state and reload both members and group summary/count from the server.
Removing a member always confirms with both localized customer and group names.

### 7. Presentation, localization, and accessibility

Translate every new label, tooltip, validation summary, dialog, status, empty state,
and semantic name in both ARB files, then regenerate localization output. Use
direction-neutral padding/alignment and directional icons through the current theme.
Wrap customer numbers, phones, email, and ISO-derived dates in explicit LTR/bidi
handling within otherwise RTL content without changing their values.

Adapt the reference hierarchy into the application shell:

- desktop-width tables with keyboard-reachable row actions;
- constrained-width forms with persistent primary actions;
- narrower layouts that replace wide tables with accessible record cards or
  horizontal regions whose actions remain reachable; and
- dialogs that trap focus, expose semantic names, restore focus on close, and meet
  the existing minimum target sizes.

Omit the reference's order-history tab, metric cards, recent-order rows, last-visit
and order-count columns, group description, prototype screen switcher, fake arrays,
and simulated toasts. Loading, empty, no-results, error, forbidden, and not-found
states come only from real cubit outcomes.

## Implementation Sequence

### Phase 0 — Resolve and freeze dependencies

1. Record the exact authenticated capability, group collection, group member,
   candidate, add, and remove contracts under the Customer domain specification.
2. Add/complete backend feature tests for tenant isolation, permissions, lifecycle
   eligibility, bounded pagination, stable ordering, duplicate exclusion, and
   concurrent membership behavior.
3. Verify the contract against the PostgreSQL test database and capture canonical
   success, validation, 403, 404, 409, and 422 payload fixtures.
4. Re-run this Constitution Check. Do not begin Flutter membership or manager-route
   visibility work while either blocker remains.

### Phase 1 — Client contracts and foundations

1. Add Customer models, enums, page metadata, query objects, draft objects, and
   strict JSON/request mapping tests.
2. Implement the repository interface and Dio implementation for every approved
   endpoint; map `ApiException` type/code/field errors without exposing raw backend
   messages as untranslated production copy.
3. Register the production repository in GetIt and provide explicit test injection.
4. Extend authenticated session/capability mapping using the approved self-capability
   response; cover secure storage/session refresh compatibility if the session shape
   changes.
5. Add all Arabic/English localization keys and shared Customer presentation tokens.

### Phase 2 — Routing and read-only customer workflows

1. Add route-location helpers, shell routes, sidebar access projection, active
   destination mapping, direct-route loading, and forbidden/not-found pages.
2. Implement customer collection cubit with immutable criteria, debounce/immediate
   search rules, generation-based stale-response rejection, refresh, pagination,
   and complete real-state coverage.
3. Build the responsive customer list against reference screens 01–04, excluding
   Phase 4 columns and fake data.
4. Implement customer detail loading and identity/contact/phone/group/note sections
   against reference screens 09–10 with metrics/history omitted.

### Phase 3 — Customer editing and lifecycle

1. Implement create/edit form cubit and draft mapping, stable phone row identities,
   primary invariants, archived group preservation, validation mapping, and dirty
   navigation protection.
2. Build create/edit views against reference screens 11–13 with accessible responsive
   layout and single-flight actions.
3. Implement lifecycle dialogs/actions with server-confirmed state replacement,
   conflict/error handling, and collection invalidation.
4. Navigate successful create/update to authoritative detail state.

### Phase 4 — Groups and memberships

1. Implement bounded group collection and group detail/member cubits.
2. Build group list, create/edit, and detail views against reference screens 05–07;
   omit description and use backend member counts.
3. Implement bounded add-member candidate search with cross-page selection, explicit
   membership commands, named remove confirmation, and authoritative refresh.
4. Add group lifecycle behavior and saved-group detail navigation.

### Phase 5 — Cross-cutting hardening and checkpoint

1. Cover Arabic RTL and English LTR, keyboard/focus/semantics, long mixed-direction
   values, locale/viewport changes with dirty drafts, and representative desktop/Web
   breakpoints.
2. Exercise late responses, rapid criteria changes, double submission, direct links,
   browser back/forward, permission revocation, conflict, offline, server, validation,
   forbidden, and not-found behavior.
3. Format changed Dart files, run focused tests, run relevant full Flutter tests and
   analysis, and complete Windows/Web build or established smoke gates.
4. Run `git diff --check`, inspect the final scoped diff and generated localization
   churn, scan the production path for prototype data/fake metrics/hard-coded user
   strings, and report any unavailable or failing check exactly.

## Test Strategy

### Model and repository contract tests

- Parse authoritative customer/group/page responses, nullable profile values,
  archived memberships, allowed actions, dates, and malformed required fields.
- Serialize create/update with zero/one/multiple phones, exact raw phone values,
  exactly one primary, active plus retained archived group IDs, and no forbidden or
  derived fields.
- Preserve `meta` from envelope responses and all criteria in query parameters.
- Map validation paths, `CUSTOMER_PERMISSION_DENIED`,
  `CUSTOMER_INVALID_TRANSITION`, conflicts, 404, network, timeout, and server errors.
- Assert mutation calls are issued once and are never transport-retried.

### Cubit tests

- Initial load, refresh, populated, empty, no-results, retry, forbidden, and
  not-found transitions.
- 300 ms debounce, immediate Enter/clear, page reset/preservation, and stale response
  rejection across search/filter/page/route changes.
- Draft dirty tracking, phone add/remove/primary changes, no implicit new primary,
  archived group preservation, mapped errors, single-flight submission, and draft
  retention on every failure class.
- Lifecycle old-state retention on failure and authoritative replacement on success.
- Add-member selection retained across result pages and cleared only after confirmed
  success; member/count refresh after add/remove.

### Widget and router tests

- Owner and permitted-manager destination/routes visible; employee and unpermitted
  manager hidden/redirected; backend 403 still wins after session permission drift.
- All eight routes load independently by identity and retain coherent tab/sidebar
  state through refresh and back/forward navigation.
- Customer/group tables or cards, actions, pagination, skeletons, empty/no-results,
  retry, forbidden, and not-found screens render from state without seeded data.
- Create/edit/lifecycle/add/remove dialogs preserve values, prevent duplicate actions,
  announce errors, and restore focus.
- Arabic RTL and English LTR snapshots/assertions cover bidi identifiers, semantics,
  focus traversal, long content, and representative Windows/Web viewports without
  clipped primary actions.
- Assert Phase 4 metrics/history/order tab and group description are absent.

### Verification commands

Run backend prerequisites serially against the dedicated PostgreSQL testing database;
do not run Laravel suites concurrently against one test database.

```powershell
docker compose exec -T backend php artisan test --filter='CustomerAuthorizationApiTest|CustomerGroupApiTest|CustomerManagementApiTest|CustomerSearchPaginationTest'

Set-Location windows_application
dart format --output=none --set-exit-if-changed lib test
flutter test test/features/customer_management
flutter test test/app_shell_navigation_transitions_test.dart test/app_shell_bilingual_test.dart test/app_shell_rtl_test.dart test/core/navigation/unsaved_navigation_guard_test.dart test/core/network/dio_api_client_test.dart
flutter analyze
flutter build windows
flutter build web

Set-Location ..
git diff --check
```

If repository-wide formatting would touch unrelated files, format only the changed
Customer Management and integration files and report that exact file set. A skipped,
timed-out, unavailable, interrupted, or failing command is not a pass. Run the full
Flutter suite at the final Phase 2 checkpoint if focused and integration gates are
green; report backend prerequisite and Flutter results separately.

## Project Structure

### Documentation (this feature)

```text
specs/flutter-customer-management/
├── spec.md
├── plan.md
└── tasks.md                 # Created later by $speckit-tasks
```

### Source Code (repository root)

```text
windows_application/
├── lib/
│   ├── app/
│   │   ├── app_router.dart
│   │   └── customer_management_route_locations.dart
│   ├── core/services/service_locator.dart
│   ├── features/auth/       # capability/session mapping only if approved contract uses session
│   ├── features/customer_management/
│   │   ├── controllers/
│   │   │   ├── customer_list_cubit.dart
│   │   │   ├── customer_detail_cubit.dart
│   │   │   ├── customer_form_cubit.dart
│   │   │   ├── customer_group_list_cubit.dart
│   │   │   ├── customer_group_detail_cubit.dart
│   │   │   └── customer_group_form_cubit.dart
│   │   ├── models/
│   │   │   ├── customer_models.dart
│   │   │   ├── customer_group_models.dart
│   │   │   ├── customer_queries.dart
│   │   │   └── customer_drafts.dart
│   │   ├── repositories/customer_management_repository.dart
│   │   ├── views/
│   │   │   ├── customer_list_screen.dart
│   │   │   ├── customer_detail_screen.dart
│   │   │   ├── customer_form_screen.dart
│   │   │   ├── customer_group_list_screen.dart
│   │   │   ├── customer_group_detail_screen.dart
│   │   │   └── customer_group_form_screen.dart
│   │   └── widgets/
│   ├── l10n/app_ar.arb
│   ├── l10n/app_en.arb
│   └── shared/widgets/app_sidebar.dart
└── test/
    ├── app/customer_management_routing_test.dart
    └── features/customer_management/
        ├── controllers/
        ├── models/
        ├── repositories/
        └── views/

backend/                     # Phase 1 prerequisites only; not Phase 2 UI ownership
├── app/Domain/Customer/
├── app/Http/Controllers/Api/Admin/CustomerManagement/
├── app/Http/Resources/Customer/
├── app/Services/Customer/
├── routes/api.php
└── tests/Feature/Customer/
```

**Structure Decision**: Keep the existing monorepo and add one Flutter vertical
feature slice. Integrate only at the established router, sidebar, service locator,
auth-capability, localization, and shared-widget seams. Backend paths are listed
solely because the assumed Phase 1 API must be completed and frozen before this plan
can be executed; they are not a second implementation of Customer rules in Flutter.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Manager navigation is guessed from role | Require an authenticated self-capability contract; backend 403 remains authoritative |
| Group screens fetch all tenants' records locally | Block implementation until bounded group/member/candidate endpoints exist |
| Late responses overwrite newer criteria | Generation/criteria equality gate on every collection and route load |
| Failed/timed-out mutation appears successful | No optimistic entity changes or automatic mutation retry; retain prior state/draft |
| Phone input is silently normalized or primary is reassigned | Preserve raw strings and require explicit primary selection |
| Archived membership is lost during edit | Model retained archived groups separately and include them unless explicitly removed |
| Phase 4 prototype data leaks into production | Explicit absence tests and final scan for metrics, orders, demo arrays, and simulated success |
| RTL and responsive adaptation breaks actions | Direction-neutral layout plus focused bidi, keyboard, semantics, and viewport tests |
| Existing dirty worktree is overwritten | Restrict edits to named integration seams and feature files; inspect diff before completion |

## Complexity Tracking

No Constitution violation is approved. The repository/cubit/model layers follow the
existing Flutter architecture and keep asynchronous coordination and API parsing out
of widgets. The two blocked contract items must be resolved in the authoritative
Customer backend; they do not justify an unbounded or role-guessed Flutter shortcut.
