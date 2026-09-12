# Tasks: Flutter Customer Management — Visual Parity Remediation

**Input**: `spec.md` and `plan.md` in `specs/flutter-customer-management-visual-parity-remediation/`

**Scope**: Flutter presentation, Customer Management localization, widget/visual tests, golden test assets, and this feature's evidence only. Backend, database, deployment, API/query/payload, repository, Cubit, route-contract, global-theme, and unrelated dirty-worktree edits are frozen.

**Tests**: Each presentation slice is test-first. Record the failing characterization and passing verification command, exit status, and result in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`. Run Flutter commands serially.

**Format**: `[ID] [P?] [Story] Description with exact file path`

## Phase 1: Setup and Baseline Evidence

**Purpose**: Establish reproducible scope, reference, behavior, and test baselines before implementation.

- [x] T001 Record the initial `git status --short`, current branch/feature directory, permitted path boundary, and protected unrelated dirty-worktree paths in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T002 Inventory all eight Customer Management routes, route-to-screen ownership, selected module tab, breadcrumbs, primary actions, existing widget keys/semantics, and guarded-navigation behavior in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md` using `windows_application/lib/app/app_router.dart`, `windows_application/lib/app/customer_management_route_locations.dart`, and `windows_application/lib/features/customer_management/views/`
- [x] T003 [P] Map each numbered file in `windows_application/design_refs/customer_management_design_reference/screens/` and the applicable HTML states in `windows_application/design_refs/customer_management_design_reference/customer_management_reference.html` to adopted composition and required exclusions in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T004 [P] Inventory existing Customer Management controller/repository request semantics and focused regression tests without modifying them, and record the frozen behavior boundary in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T005 Run `windows_application/test/features/customer_management/`, `windows_application/test/app/customer_management_routing_test.dart`, `windows_application/test/app_shell_bilingual_test.dart`, `windows_application/test/shared/widgets/app_sidebar_auth_test.dart`, and `windows_application/test/features/customer_management/customer_form_navigation_test.dart` serially from `windows_application/`; before execution record the complete resolved test-file list (including every file discovered under the directory target), then record exact commands, exit codes, pass/fail counts, timeouts, and pre-existing failures in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

**Checkpoint**: The pre-change state and protected behavior are documented; no production code has changed.

---

## Phase 2: Foundational Visual System (Blocking)

**Purpose**: Add test-proven module primitives shared by every story.

**Critical**: Complete this phase before migrating any screen.

- [x] T085 Inventory every required new or changed page title/description, breadcrumb, tab, filter, overflow-menu item, status, empty/no-results/error/forbidden/not-found state, button, tooltip, semantic label, pagination phrase, and dialog title/message/action; compare `windows_application/lib/l10n/app_en.arb` with `windows_application/lib/l10n/app_ar.arb` for duplicate keys, missing counterparts, and English/Arabic terminology drift; record the resolved vocabulary in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md` before T012 or any ARB/UI edit

### Tests

- [x] T006 [P] Add failing tests for module-scoped widths, the exact 760/759 collection breakpoint, spacing, borders, radii, warm surface treatments, status treatments, focus visibility, and minimum target sizing in `windows_application/test/features/customer_management/widgets/customer_management_visual_tokens_test.dart`
- [x] T007 [P] Add failing responsive and semantics tests for page title, description, breadcrumbs, identity/status content, and desktop/narrow action placement in `windows_application/test/features/customer_management/widgets/customer_management_page_header_test.dart`
- [x] T008 [P] Add failing composition tests for bordered header/body/footer slots and constrained versus expandable content in `windows_application/test/features/customer_management/widgets/customer_management_surface_test.dart`
- [x] T009 [P] Add failing LTR/RTL, route-derived selection, and existing-list-route callback tests for module tabs in `windows_application/test/features/customer_management/widgets/customer_management_module_tabs_test.dart`
- [x] T010 [P] Add failing keyboard, semantics, allowed-action, event-propagation, edge anchoring, dismissal, and focus-restoration tests for the overflow menu in `windows_application/test/features/customer_management/widgets/customer_management_overflow_menu_test.dart`
- [x] T011 Run T006–T010 tests and record their expected pre-implementation failures in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

### Implementation

- [x] T012 [P] Implement immutable module-only visual constants by reusing compatible application tokens without editing the global theme in `windows_application/lib/features/customer_management/widgets/customer_management_visual_tokens.dart`
- [x] T013 [P] Implement the responsive localized page hierarchy and action layout in `windows_application/lib/features/customer_management/widgets/customer_management_page_header.dart`
- [x] T014 [P] Implement reusable bordered header/body/footer surfaces with collection and readable-width modes in `windows_application/lib/features/customer_management/widgets/customer_management_surface.dart`
- [x] T015 [P] Implement compact direction-aware Customers/Customer Groups tabs whose selected value is supplied from existing route identity in `windows_application/lib/features/customer_management/widgets/customer_management_module_tabs.dart`
- [x] T016 [P] Implement the caller-authorized, keyboard-accessible, focus-restoring row overflow menu without business-rule inference in `windows_application/lib/features/customer_management/widgets/customer_management_overflow_menu.dart`
- [x] T017 Run the foundational widget tests and scoped analysis, then record passing evidence in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

**Checkpoint**: Reusable module primitives pass independently and no screen has acquired new behavior.

---

## Phase 3: User Story 1 — Navigate a Cohesive Customer Module (Priority: P1) MVP

**Goal**: All eight existing routes share a consistent scaffold, localized hierarchy, and route-derived module navigation without changing shell, route, access, or state ownership.

**Independent Test**: Direct-load and navigate among all eight routes in English and Arabic; verify shell retention, selected tab, breadcrumbs, headings/actions, capability denial, draft retention, and unchanged request counts.

### Tests

- [x] T018 [US1] Add failing mounted-router coverage for all eight route identities, module-tab selection, localized title/description/breadcrumbs, and existing navigation targets in `windows_application/test/app/customer_management_routing_test.dart`
- [x] T019 [P] [US1] Add failing desktop/narrow and LTR/RTL scaffold layout tests that assert stable child identity across resize and locale changes in `windows_application/test/features/customer_management/views/customer_management_scaffold_test.dart`
- [x] T020 [P] [US1] Extend capability and sidebar regression assertions so unauthorized navigation remains fail-closed in `windows_application/test/features/customer_management/customer_management_access_test.dart` and `windows_application/test/shared/widgets/app_sidebar_auth_test.dart`
- [x] T021 [US1] Run T018–T020 and record the expected presentation failures while proving access and route behavior remain unchanged in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

### Implementation

- [x] T022 [US1] Refactor the shared content wrapper to own module background, direction-aware padding, content bounds, tabs, hierarchy slots, and responsive rhythm while preserving child/Cubit identity in `windows_application/lib/features/customer_management/widgets/customer_management_scaffold.dart`
- [x] T023 [US1] Adopt the shared scaffold and page header without changing route loading or callbacks in `windows_application/lib/features/customer_management/views/customer_list_screen.dart`, `customer_detail_screen.dart`, `customer_form_screen.dart`, `customer_group_list_screen.dart`, `customer_group_detail_screen.dart`, and `customer_group_form_screen.dart`
- [x] T024 [US1] After T085, add matching English and Arabic titles, descriptions, breadcrumbs, tab labels, tooltips, and semantics to `windows_application/lib/l10n/app_en.arb` and `windows_application/lib/l10n/app_ar.arb`; at this controlled checkpoint regenerate and verify `windows_application/lib/l10n/app_localizations.dart`, `windows_application/lib/l10n/app_localizations_en.dart`, and `windows_application/lib/l10n/app_localizations_ar.dart`, recording any generator stall/failure exactly and never claiming generated output passed without verification
- [x] T025 [US1] Run the US1 router/scaffold/access tests and the existing unsaved-navigation regression, then record current evidence in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

**Checkpoint**: The route scaffold is independently coherent in both directions with behavior frozen.

---

## Phase 4: User Story 2 — Scan and Operate on Visual Collections (Priority: P1)

**Goal**: Customers, groups, and members use reference-aligned tables at widths of at least 760 and accessible record cards below 760, with bounded filters, authorized actions, and integrated pagination.

**Independent Test**: Exercise populated, long-value, multipage customer/group/member collections at 760, 759, 1440×900, 1280×800, and 500×800 in LTR/RTL while asserting unchanged Cubit calls.

### Tests

- [x] T026 [US2] Add failing customer collection tests for approved fields/exclusions, exact breakpoint behavior, long bidi values, group summaries, badges, menu propagation, bounded scrolling, and pagination metadata in `windows_application/test/features/customer_management/widgets/customer_collection_test.dart`
- [x] T027 [P] [US2] Add failing group and member table/card tests for approved fields, nullable `createdAt`, member count, allowed actions, long values, and 760/759 behavior in `windows_application/test/features/customer_management/widgets/customer_group_components_test.dart`
- [x] T028 [P] [US2] Add failing screen tests for bordered filters, exact customer/group lifecycle segments, bounded group options, Enter/clear behavior, page reset, criteria retention, RTL order, and request counts in `windows_application/test/features/customer_management/views/customer_list_screen_test.dart` and `customer_group_screens_test.dart`
- [x] T029 [P] [US2] Add failing direction-correct integrated-footer tests for current range/page, disabled states, and preserved criteria in `windows_application/test/features/customer_management/widgets/customer_pagination_test.dart`
- [x] T030 [US2] Run T026–T029 and record expected failures plus unchanged controller/repository behavior evidence in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

### Implementation

- [x] T031 [US2] Refactor customer tables/cards, warm headers, lifecycle/group display, caller-authorized menus, bounded body scrolling, and footer composition in `windows_application/lib/features/customer_management/widgets/customer_collection.dart`
- [x] T032 [P] [US2] Refactor group and member desktop/narrow records using only contract-supported fields and actions in `windows_application/lib/features/customer_management/widgets/customer_group_components.dart`
- [x] T033 [P] [US2] Refactor pagination into a direction-aware integrated surface footer driven only by `CustomerPageMeta` in `windows_application/lib/features/customer_management/widgets/customer_pagination.dart`
- [x] T034 [US2] Compose customer filters, result summary, collection surface, and pagination without altering Cubit calls in `windows_application/lib/features/customer_management/views/customer_list_screen.dart`
- [x] T035 [US2] Compose group filters, result summary, collection surface, and pagination without adding description/status-edit behavior in `windows_application/lib/features/customer_management/views/customer_group_list_screen.dart`
- [x] T036 [US2] After T085, add required localized segment, column, record, range, page, tooltip, and menu labels to `windows_application/lib/l10n/app_en.arb` and `windows_application/lib/l10n/app_ar.arb` without regenerating yet; T046 owns the next controlled generation checkpoint

**Checkpoint**: Each bounded collection works independently at desktop and narrow sizes without behavioral drift.

---

## Phase 5: User Story 3 — Read and Edit Customers in Reference-Aligned Cards (Priority: P1)

**Goal**: Customer detail and create/edit surfaces gain reference-aligned hierarchy while preserving exact values, drafts, validation, lifecycle authority, and single-flight saves.

**Independent Test**: Render detail/create/edit with missing and long values, zero/multiple phones, archived groups, validation/failure/progress, dirty drafts, resize, and locale changes at desktop/narrow sizes.

### Tests

- [x] T038 [P] [US3] Add failing detail-card tests for identity/status header, approved information only, all raw phones, groups, notes, absence text, responsive grid, bidi isolation, and prohibited metrics/orders/tabs in `windows_application/test/features/customer_management/views/customer_detail_screen_test.dart`
- [x] T039 [P] [US3] Add failing form tests for constrained sections, edit-only read-only backend number, stable phone-row identity, raw values, primary selection, archived memberships, reachable footer actions, validation, progress, failure draft retention, and single invocation in `windows_application/test/features/customer_management/views/customer_form_screen_test.dart`
- [x] T040 [US3] Extend resize/locale/dirty-navigation characterization so draft values and guarded cancellation survive relayout in `windows_application/test/features/customer_management/customer_form_navigation_test.dart`
- [x] T041 [US3] Run T038–T040 and record expected presentation failures while existing form/detail controller tests remain green in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

### Implementation

- [x] T042 [P] [US3] Refactor customer information, phones, groups, notes, absence values, and explicit LTR value presentation into responsive detail cards in `windows_application/lib/features/customer_management/widgets/customer_detail_sections.dart`
- [x] T043 [P] [US3] Refactor customer information, phone rows, groups, notes, and edit-only lifecycle sections without changing controller ownership or input semantics in `windows_application/lib/features/customer_management/widgets/customer_form_sections.dart`
- [x] T044 [US3] Compose identity/lifecycle/actions and the responsive detail-card grid using backend-returned values and `allowedActions` in `windows_application/lib/features/customer_management/views/customer_detail_screen.dart`
- [x] T045 [US3] Compose the constrained create/edit surface and reachable responsive footer while preserving save/cancel/dirty-guard behavior in `windows_application/lib/features/customer_management/views/customer_form_screen.dart`
- [x] T046 [US3] After T085 and T036, add required English/Arabic section, absence, helper, progress, tooltip, and semantic copy to `windows_application/lib/l10n/app_en.arb` and `windows_application/lib/l10n/app_ar.arb`; at this controlled checkpoint regenerate and verify `windows_application/lib/l10n/app_localizations.dart`, `windows_application/lib/l10n/app_localizations_en.dart`, and `windows_application/lib/l10n/app_localizations_ar.dart`, recording any generator stall/failure exactly and never claiming generated output passed without verification
- [x] T037 [US2] After T046, run `windows_application/test/features/customer_management/widgets/customer_collection_test.dart`, `windows_application/test/features/customer_management/widgets/customer_group_components_test.dart`, `windows_application/test/features/customer_management/widgets/customer_pagination_test.dart`, `windows_application/test/features/customer_management/views/customer_list_screen_test.dart`, `windows_application/test/features/customer_management/views/customer_group_screens_test.dart`, `windows_application/test/features/customer_management/controllers/customer_list_cubit_test.dart`, `windows_application/test/features/customer_management/controllers/customer_group_list_cubit_test.dart`, and `windows_application/test/features/customer_management/repositories/customer_management_repository_test.dart` serially; record results in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T047 [US3] Run detail/form/navigation widget tests and existing customer detail/form/lifecycle Cubit regressions serially; record results in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

**Checkpoint**: Customer reading and editing are independently testable at all required directions/sizes with authority preserved.

---

## Phase 6: User Story 4 — Manage Groups and Memberships in Focused Surfaces (Priority: P2)

**Goal**: Group detail/forms and membership dialogs use focused, accessible surfaces while retaining the name-only and bounded membership contracts.

**Independent Test**: Exercise group detail/create/edit, candidate paging/selection, add/remove, lifecycle, empty/loading/error, and confirmations in both locales and responsive layouts.

### Tests

- [x] T048 [P] [US4] Add failing group detail/form tests for reference hierarchy, authoritative count/lifecycle, nullable creation date, name-only form, excluded description/status editor, bounded member layout, and responsive actions in `windows_application/test/features/customer_management/views/customer_group_screens_test.dart` and `customer_group_form_screen_test.dart`
- [x] T049 [P] [US4] Add failing Add Members dialog tests for bounded search/results, deterministic states, identity rows, selection persistence across pages/relayout, count in confirm, progress, keyboard traversal, and single mutation in `windows_application/test/features/customer_management/views/customer_group_membership_test.dart`
- [x] T050 [P] [US4] Add failing shared confirmation tests for localized named context, consequence text, destructive emphasis, pending disablement, Escape/cancel, focus containment, and restoration in `windows_application/test/features/customer_management/widgets/customer_confirmation_dialog_test.dart`
- [x] T086 [US4] Before T055, characterize sidebar navigation, module-tab navigation, Cancel, browser back/forward, direct route change, dismissal/stay behavior, confirmed leave behavior, draft retention, dialog return values, and focus restoration in `windows_application/test/features/customer_management/customer_form_navigation_test.dart`; record the existing contract and failing visual-only expectations in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T051 [US4] Run T048–T050 and record expected presentation failures while existing membership/group Cubit tests remain green in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

### Implementation

- [x] T052 [P] [US4] Refactor group detail hierarchy and bounded member surface without adding unsupported fields or behavior in `windows_application/lib/features/customer_management/views/customer_group_detail_screen.dart`
- [x] T053 [P] [US4] Refactor group create/edit into a constrained name-only surface with existing save/cancel semantics in `windows_application/lib/features/customer_management/views/customer_group_form_screen.dart`
- [x] T054 [US4] Refactor `CustomerGroupCandidateDialog` layout, bounded states, paging, selection count, progress, keyboard behavior, and focus handling without moving Cubit/selection ownership in `windows_application/lib/features/customer_management/widgets/customer_group_components.dart`
- [x] T055 [US4] After T086, refactor lifecycle and member-removal confirmations into the shared accessible composition in `windows_application/lib/features/customer_management/widgets/customer_confirmation_dialog.dart`; migrate/restyle the unsaved-change confirmation only if sidebar navigation, module-tab navigation, Cancel, browser back/forward, direct route changes, dismissal/stay, confirmed leave, draft retention, return values, and focus restoration remain identical to the characterized contract
- [x] T056 [US4] After T085, add required English/Arabic group, membership, selection, dialog, consequence, tooltip, and semantic copy to `windows_application/lib/l10n/app_en.arb` and `windows_application/lib/l10n/app_ar.arb` without regenerating yet; T064 owns the next controlled generation checkpoint

**Checkpoint**: Group and membership workflows are independently accessible and retain bounded server authority.

---

## Phase 7: User Story 5 — Understand Every Real State Across Platforms (Priority: P1)

**Goal**: Every real loading, empty, no-results, error, validation, progress, and success state is distinct, localized, responsive, accessible, and visually regression-tested.

**Independent Test**: Drive deterministic fixtures through the layered state matrix in LTR/RTL and desktop/narrow geometries, then compare approved golden baselines on the pinned Windows renderer.

### State and Accessibility Tests

- [x] T058 [P] [US5] Add failing tests for deterministic table/card/detail/form skeleton geometry, inert non-readable placeholders, loading semantics, and refresh-over-existing-data treatment in `windows_application/test/features/customer_management/widgets/customer_management_state_panel_test.dart`
- [x] T059 [P] [US5] Extend failing state-matrix tests for distinct empty, no-results, retryable, forbidden, not-found, validation, conflict, timeout, network, server, progress, and success treatments with correct authorized actions in `windows_application/test/features/customer_management/customer_management_state_matrix_test.dart`
- [x] T060 [P] [US5] Extend keyboard/semantics/RTL/narrow tests for every remediated action surface, modal focus containment/restoration, non-color-only meaning, mixed-direction values, and no overflow in `windows_application/test/features/customer_management/customer_management_accessibility_test.dart`
- [x] T061 [US5] Run T058–T060 and record expected failures before state implementation in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

### State Implementation

- [x] T062 [US5] Refactor initial loading, geometry-specific skeletons, empty, no-results, retryable error, forbidden, not-found, validation/failure, and mutation-progress variants without introducing fake production data in `windows_application/lib/features/customer_management/widgets/customer_management_state_panel.dart`
- [x] T063 [US5] Wire only existing real Cubit states and authorized create/clear/retry handlers into the new state surfaces across `windows_application/lib/features/customer_management/views/customer_list_screen.dart`, `customer_detail_screen.dart`, `customer_form_screen.dart`, `customer_group_list_screen.dart`, `customer_group_detail_screen.dart`, and `customer_group_form_screen.dart`
- [x] T064 [US5] After T085 and T056, add matching English/Arabic state, loading announcement, recovery action, tooltip, and semantic copy to `windows_application/lib/l10n/app_en.arb` and `windows_application/lib/l10n/app_ar.arb`; at this controlled checkpoint regenerate and verify `windows_application/lib/l10n/app_localizations.dart`, `windows_application/lib/l10n/app_localizations_en.dart`, and `windows_application/lib/l10n/app_localizations_ar.dart`, recording any generator stall/failure exactly and never claiming generated output passed without verification
- [x] T057 [US4] After T064, run `windows_application/test/features/customer_management/views/customer_group_screens_test.dart`, `windows_application/test/features/customer_management/views/customer_group_form_screen_test.dart`, `windows_application/test/features/customer_management/views/customer_group_membership_test.dart`, `windows_application/test/features/customer_management/views/customer_group_lifecycle_test.dart`, `windows_application/test/features/customer_management/widgets/customer_confirmation_dialog_test.dart`, `windows_application/test/features/customer_management/customer_form_navigation_test.dart`, `windows_application/test/features/customer_management/controllers/customer_group_detail_cubit_test.dart`, `windows_application/test/features/customer_management/controllers/customer_group_form_cubit_test.dart`, `windows_application/test/features/customer_management/controllers/customer_group_membership_cubit_test.dart`, and `windows_application/test/features/customer_management/controllers/customer_group_list_cubit_test.dart` serially; record results in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T065 [US5] Run state-matrix and accessibility tests at 1440×900, 1280×800, 500×800, 760, and 759 constraints and record results in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

### Deterministic Golden Infrastructure

- [x] T066 [US5] Add a deterministic harness that loads bundled Manrope and IBM Plex Sans Arabic fonts and pins locale, direction, size, DPR, animation clock, theme, and fixtures in `windows_application/test/features/customer_management/goldens/customer_management_golden_harness.dart`
- [x] T067 [P] [US5] In `windows_application/test/features/customer_management/goldens/customer_screens_golden_test.dart`, own every populated/ready matrix row for customer list, customer detail, customer create, and customer edit: 1440×900 English/LTR, 1440×900 Arabic/RTL, 1280×800 English/LTR, 1280×800 Arabic/RTL, 500×800 English/LTR, and 500×800 Arabic/RTL
- [x] T068 [P] [US5] In `windows_application/test/features/customer_management/goldens/customer_group_screens_golden_test.dart`, own every populated/ready matrix row for customer-group list, customer-group detail, customer-group create, and customer-group edit: 1440×900 English/LTR, 1440×900 Arabic/RTL, 1280×800 English/LTR, 1280×800 Arabic/RTL, 500×800 English/LTR, and 500×800 Arabic/RTL
- [x] T069 [P] [US5] In `windows_application/test/features/customer_management/goldens/customer_dialogs_golden_test.dart`, own every populated/ready matrix row for the Add Members dialog and confirmation dialogs—including lifecycle, member-removal, and the unsaved-change dialog where T086 permits visual migration—at 1440×900 English/LTR, 1440×900 Arabic/RTL, 1280×800 English/LTR, 1280×800 Arabic/RTL, 500×800 English/LTR, and 500×800 Arabic/RTL
- [x] T070 [P] [US5] In `windows_application/test/features/customer_management/goldens/customer_states_golden_test.dart`, add supplemental Web-desktop geometry cases for the shared scaffold and both primary collections; at one declared desktop geometry require BOTH the customer collection and customer-group collection EACH to cover loading, empty, filtered no-results, retryable error, and forbidden, and cover not-found only on the contract-reachable customer-detail and customer-group-detail routes; also cover validation/failure and in-progress for mutation-capable forms/dialogs without inventing collection-level not-found
- [x] T071 [US5] Generate baselines only with the pinned Windows Flutter widget-test renderer into `windows_application/test/features/customer_management/goldens/baselines/`; do not accept browser-rendered or unexplained-difference baselines
- [ ] T072 [US5] For every mandatory baseline, record in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md` a side-by-side checklist containing route/screen, state, locale, text direction, viewport, reference image, generated artifact path, intentional exclusions, known data-dependent differences, reviewer result (`accepted` or `rejected`), rejection reason, and date/checkpoint; do not treat automated pixel comparison as design acceptance
- [ ] T073 [US5] Run `windows_application/test/features/customer_management/goldens/customer_screens_golden_test.dart`, `windows_application/test/features/customer_management/goldens/customer_group_screens_golden_test.dart`, `windows_application/test/features/customer_management/goldens/customer_dialogs_golden_test.dart`, and `windows_application/test/features/customer_management/goldens/customer_states_golden_test.dart` serially with zero unexplained differences; require an explicit `accepted` T072 result for every mandatory baseline before SC-002 or SC-003 may pass, and record renderer/toolchain, commands, exit status, and any narrowly documented antialiasing tolerance in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

**Checkpoint**: The layered visual/state matrix is approved and reproducible; no fixture is reachable from production code.

---

## Phase 8: Polish and Final Verification

**Purpose**: Prove scope, compatibility, quality, and build closure without absorbing unrelated failures.

- [x] T074 [P] Extend automated exclusions for fake/demo values, hard-coded visible copy, `X-Tenant-Id`, client phone/number authority, metrics/history/orders, group description, editable status, unbounded requests, and production golden fixtures in `windows_application/test/features/customer_management/customer_management_scope_guard_test.dart`
- [x] T075 Run `dart format --output=none --set-exit-if-changed` for every changed Dart file and `flutter analyze` for changed Dart and focused test paths from `windows_application/`; record exact outcomes in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T076 Run `flutter test test/features/customer_management` serially from `windows_application/` and record exact exit status and counts without treating historical counts as current evidence in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T077 Run `windows_application/test/app/customer_management_routing_test.dart`, `windows_application/test/app/top_refresh_route_test.dart`, `windows_application/test/app/route_scoped_request_topology_test.dart`, `windows_application/test/app_shell_bilingual_test.dart`, `windows_application/test/shared/widgets/app_sidebar_auth_test.dart`, and `windows_application/test/features/customer_management/customer_form_navigation_test.dart` serially; before execution record this complete resolved list plus any newly created route/shell/unsaved-navigation test file added by earlier tasks, then record focused successes separately from unrelated failures in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [ ] T078 Run `windows_application/test/features/customer_management/goldens/customer_screens_golden_test.dart`, `windows_application/test/features/customer_management/goldens/customer_group_screens_golden_test.dart`, `windows_application/test/features/customer_management/goldens/customer_dialogs_golden_test.dart`, and `windows_application/test/features/customer_management/goldens/customer_states_golden_test.dart` serially on the pinned Windows toolchain and confirm every mandatory baseline has an explicit accepted T072 review entry in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [ ] T079 Run `flutter build windows` from `windows_application/`, verify exit 0 and the updated executable artifact, and record any timeout/stall/missing artifact as not passed in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [ ] T080 Run `flutter build web` from `windows_application/`, verify exit 0 and current build artifacts, and record any timeout/stall/missing artifact as not passed in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T081 Run `git diff --check` and record the exact result in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T082 Compare the final changed-path inventory with T001 and confirm no backend, database, deployment, API/query/payload, repository, Cubit, route-contract, global-theme, generated-file churn outside localization, or unrelated worktree change was introduced or overwritten in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [x] T083 Inspect the final diff for secrets, fake production state, unsupported content, hard-coded visible copy, accessibility regressions, and test-only assets outside `windows_application/test/features/customer_management/goldens/`, recording findings in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`
- [ ] T084 Reconcile every FR-001–FR-051 and SC-001–SC-009 against current test/build/scope evidence, accurately list every skipped, timed-out, stalled, unavailable, failing, or unrelated gate, and record the final status in `specs/flutter-customer-management-visual-parity-remediation/implementation-log.md`

---

## Dependencies and Execution Order

### Phase Dependencies

- Phase 1 has no dependencies and freezes the baseline.
- Phase 2 depends on Phase 1 and blocks every user-story implementation.
- T085 is the first Phase 2 task and blocks T012–T016 plus every ARB/UI edit.
- Phase 3 (US1) depends on Phase 2 because every screen uses the scaffold.
- Phase 4 (US2), Phase 5 (US3), and Phase 6 (US4) depend on Phase 3; they may be implemented as separate slices after the scaffold, but shared-file edits must be serialized.
- Phase 7 (US5) depends on the final compositions from Phases 4–6; state tests may be written earlier, but golden baselines must not be accepted before those phases pass.
- Phase 8 depends on every selected story and is the only completion gate.
- T036 defers generation to T046, so T037 runs only after T046; T056 defers generation to T064, so T057 runs only after T064. T086 blocks T055.

### Story Dependency Graph

```text
Setup -> Foundation -> US1 Scaffold
                         |-> US2 Collections --|
                         |-> US3 Customer UI --|-> US5 States/Goldens -> Final Verification
                         |-> US4 Group UI -----|
```

### Within Each Story

1. Add characterization/widget tests and verify the intended presentation assertions fail.
2. Implement only the scoped presentation/localization slice.
3. Regenerate localization output through the established workflow; report a stall/failure rather than disguising it with a success claim.
4. Run the story tests and affected existing behavioral regressions serially.
5. Record command-level evidence before checking the task complete.

### Parallel Opportunities

- Tasks marked `[P]` target independent files and may be prepared in parallel only when they do not run Flutter tests against the same build output concurrently.
- Test commands, localization generation, golden generation/comparison, Windows build, and Web build remain serial.
- Customer collections, customer detail/form, and group surfaces can be developed as separate post-scaffold slices, but edits to shared widgets, ARB files, generated localization, or the implementation log must be coordinated serially.

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete US1 and validate all eight route scaffolds.
3. Complete US2 because the primary customer/group collections are the main operational entry points.
4. Stop and validate route, access, collection, RTL, narrow-layout, and request-count regressions before proceeding.

### Incremental Delivery

1. Shared scaffold and tokens.
2. Customer/group/member collections.
3. Customer detail and forms.
4. Group detail/forms and membership dialogs.
5. Real states, deterministic goldens, and final platform/build closure.

## Notes

- A checked task requires explicit evidence in `implementation-log.md`; inspecting an apparently correct implementation is not enough.
- Focused green tests do not establish full feature completion or Windows/Web build closure.
- Do not repair unrelated shell, Finance, backend, database, Docker, or deployment failures in this feature.
- Do not update a golden merely to make a failing comparison green; first complete and document the required side-by-side reference review.
- A timeout, stall, skipped command, unavailable toolchain, stale artifact, or missing final output is not a pass.
