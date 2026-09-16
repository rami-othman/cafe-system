# Implementation Plan: Flutter Customer Management — Visual Parity Remediation

**Branch**: `flutter-customer-management-visual-parity-remediation` | **Date**: 2026-09-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/flutter-customer-management-visual-parity-remediation/spec.md`

## Summary

Remediate the six existing Customer Management screen implementations and two dialog families so their composition, hierarchy, density, spacing, colors, tables, cards, actions, and real-state treatments closely match `windows_application/design_refs/customer_management_design_reference/`. The work stays inside the existing Flutter Windows/Web module, preserves all routes, repositories, Cubits, backend-owned authorization and business behavior, and adds deterministic visual regression coverage.

The implementation will introduce module-scoped presentation tokens and a small set of reusable structural widgets, then migrate the existing scaffold, collections, details, forms, dialogs, and state panels onto those primitives. Every collection will switch from a desktop table to a record-card layout below 760 logical pixels of available content width. Golden tests will use bundled fonts and one pinned Windows Flutter widget-test renderer, with a layered matrix and documented side-by-side baseline review; actual Windows and Web behavior will remain covered by separate build/smoke gates.

## Technical Context

**Language/Version**: Dart SDK `^3.12.1`; Flutter SDK compatible with the existing `windows_application` lockfile and Windows toolchain

**Primary Dependencies**: Flutter Material 3, `flutter_bloc 9.1.1`, `equatable 2.0.8`, `go_router 17.3.0`, `get_it 9.2.1`, `dio 5.9.2`, `intl 0.20.2`, `skeletonizer 2.1.0`, generated `AppLocalizations`, bundled Manrope and IBM Plex Sans Arabic fonts

**Storage**: N/A — no storage, schema, cache, or persistence changes; existing in-memory Cubit state and backend persistence remain authoritative

**Testing**: `flutter_test` unit/widget/golden tests, existing Customer Management controller/repository/router/shell/accessibility/localization/state/scope tests, Windows and Web build/smoke gates, and `git diff --check`

**Target Platform**: Flutter Windows desktop and Flutter Web desktop, plus responsive layouts down to the specified 500×800 logical-pixel test viewport

**Project Type**: Brownfield cross-platform Flutter application consuming an unchanged Laravel JSON API

**Performance Goals**: Preserve current request counts and coordination; render one bounded page smoothly at the backend maximum page size; avoid intrinsic or nested unbounded layouts in scrolling tables/cards; retain immediate keyboard and pointer feedback during responsive relayout

**Constraints**: Presentation-only scope; no backend, database, deployment, repository-contract, payload, query, route, Cubit-behavior, or business-rule changes; no fake production data; no global theme edits; no automatic mutation retry; no optimistic success; all new copy localized; RTL/LTR and keyboard accessibility required

**Scale/Scope**: Eight existing routes, six screen implementations, two dialog families, three collection presentations, Arabic and English, desktop and narrow geometry, and the real-state/golden matrices defined by FR-044 through FR-048

## Constitution Check

*GATE: PASS before design. Re-check after the planned structure and verification strategy below: PASS.*

- **Tenant and authorization — PASS**: The feature neither reads nor changes tenant identity. Existing opaque bearer-token context, `customer.manage` capability projection, fail-closed route/sidebar behavior, and backend authorization remain unchanged. No `X-Tenant-Id`, role inference, branch rule, or Platform Super Admin path is added. Branch access is N/A because Customer Management remains tenant-wide and this phase adds no operational branch behavior.
- **Domain authority and scope — PASS**: Laravel Customer Management remains authoritative for identity, phones, groups, memberships, lifecycle, validation, counts, eligibility, and pagination. Flutter changes only composition and presentation. POS, loyalty, discounts, orders, history, metrics, imports, marketing, and all prototype-only behavior remain excluded.
- **History and data safety — PASS**: No schema, migration, import, deletion, or historical-record change is planned. Existing archive/deactivate/restore behavior and retained archived memberships are displayed without reinterpretation. Database rollout and rollback are N/A.
- **Exact semantics — PASS**: Money, tax, inventory quantities, conversions, accounting, and IANA-timezone decisions are N/A because this feature performs no such calculations. Customer numbers and raw phone values remain exact and explicitly LTR-isolated. Existing date/timestamp presentation is reused. Transaction, concurrency, and idempotency behavior remain owned by the unchanged backend and existing single-flight Cubits.
- **Contracts and scale — PASS**: Endpoint paths, payloads, error mapping, query criteria, and bounded server pagination are unchanged. Tables/cards render only the current bounded page and metadata. Loading, empty, no-results, forbidden, not-found, validation, conflict, timeout, network, server, progress, and success presentation stays connected to real existing state.
- **UX and platforms — PASS**: Work remains inside the existing `AppShell` and navigation. New style values are module-scoped and reuse matching global tokens without changing `AppTheme`. Arabic/English localization, RTL/LTR mirroring, mixed-direction values, visible focus, semantics, modal focus behavior, Windows/Web, and 760-pixel collection adaptation are explicit design and test requirements.
- **Verification and scope — PASS**: Tests are added before or alongside each visual slice. The plan includes focused and integration regression, deterministic goldens, side-by-side reference review, formatting, scoped analysis, Windows/Web build or smoke gates, `git diff --check`, final secret/scope inspection, and exact reporting of stalls, skips, or unrelated failures. Existing dirty-worktree changes must be preserved.

No constitutional violation or exception is required.

## Architecture and Design Decisions

### 1. Preserve the behavioral slice

Keep the existing dependency flow intact:

```text
views/widgets -> existing Cubits and immutable states
              -> CustomerManagementRepository
              -> existing Dio implementation and backend contracts
```

Presentation widgets may receive additional display configuration or callbacks already available from their parent, but they must not introduce endpoint calls, derive permissions or lifecycle transitions, filter unbounded records, normalize domain values, or mutate Cubit state during layout. Controller, repository, model, route-location, and service-locator files are read-only scope guards unless a failing preservation test proves a strictly presentation-required compatibility adjustment; such an adjustment requires revisiting the spec before implementation.

### 2. Add module-scoped visual primitives

Create a module-owned presentation layer under `lib/features/customer_management/widgets/`:

- `customer_management_visual_tokens.dart`: immutable module constants for content widths, the 760-pixel collection breakpoint, spacing, surface borders/radii, warm header/accent fills, status treatments, control density, skeleton geometry, and minimum interactive target size. Values should reuse `AppColors`, `AppSpacing`, `AppRadius`, and `AppTextStyles` where they already match; do not edit the global theme.
- `customer_management_page_header.dart`: responsive title, description, breadcrumbs, lifecycle/identity area, and primary/secondary action placement.
- `customer_management_surface.dart`: bordered white surface with consistent header/body/footer slots used by filters, tables/cards, details, and forms.
- `customer_management_module_tabs.dart`: compact Customers/Customer Groups navigation with route-derived selection and direction-aware alignment.
- `customer_management_overflow_menu.dart`: accessible, focus-restoring action menu that renders only caller-provided allowed actions and prevents row navigation propagation.

Prefer composing these primitives over adding screen-specific decoration constants. Existing shared application widgets remain authoritative outside the module.

### 3. Rebuild the shared content scaffold

Refactor `customer_management_scaffold.dart` to own the module background, direction-aware outer padding, bounded content width, module tabs, breadcrumbs/page hierarchy slots, and responsive vertical rhythm while remaining inside `AppShell`. Route selection continues to derive from the current `GoRouter` location and tab activation navigates only to the existing customer/group list routes.

The scaffold must preserve child identity across locale and viewport changes so Cubits, form drafts, candidate selections, and in-flight state are not recreated. Collection content may use the available width; detail/form content receives its specified readable constraint.

### 4. Standardize collection composition

Refactor `customer_collection.dart` and the group/member collection portions of `customer_group_components.dart` around one responsive rule based on local `LayoutBuilder` constraints:

- `maxWidth >= 760`: render the compact bordered desktop table.
- `maxWidth < 760`: render accessible record cards with the same approved fields and actions.

Build list screens from page header -> bordered filter surface -> result summary -> collection surface -> integrated pagination footer. Filters continue to call the current Cubit methods, with no changes to debounce, Enter/clear, page reset, or criteria retention. Use segmented lifecycle controls whose values map exactly to current query enums. Keep the group option control bounded and provide tooltip/semantics for long names.

Rows expose only the fields allowed by FR-017 through FR-019. Multiple actions use the shared overflow menu; a single primary navigation affordance may remain direct. Pagination reads only `CustomerPageMeta`, uses direction-correct icons, and stays visible with the bounded body scrolling inside its surface.

### 5. Compose detail and form surfaces

Refactor `customer_detail_sections.dart` and `customer_detail_screen.dart` into a responsive information-card grid for identity, customer information, all phones, groups, and notes. Keep lifecycle badge and allowed edit/lifecycle actions in the page header. Missing values use localized absence text; customer number, raw phones, email, and dates use `CustomerBidiValue` or equivalent explicit LTR isolation.

Refactor `customer_form_sections.dart` and `customer_form_screen.dart` into one constrained surface with customer information, phone rows, groups, notes, and edit-only lifecycle action sections. Preserve existing controller ownership, stable phone row keys, raw input, explicit primary selection, retained archived memberships, validation mapping, dirty guard, and single-flight submission. Footer actions remain reachable without horizontal scrolling.

Refactor `customer_group_detail_screen.dart`, `customer_group_form_screen.dart`, and the relevant group widgets using the same page/surface vocabulary. Group forms remain name-only. Group detail shows only identity, lifecycle, authoritative member count, actions, member search, bounded member collection, and pagination; nullable `createdAt` is displayed only where the server value exists or with localized absence text.

### 6. Unify dialogs, menus, and focus behavior

Evolve `customer_confirmation_dialog.dart` into the shared confirmation composition used by customer lifecycle, group lifecycle, and member removal. Before migrating or restyling the unsaved-change confirmation, characterize sidebar navigation, module-tab navigation, Cancel, browser back/forward, direct route change, dismissal/stay behavior, confirmed leave behavior, draft retention, return values, and focus restoration. Include the unsaved-change confirmation in the shared visual composition only if every characterized behavioral contract remains unchanged. Preserve localized consequence text, named context, destructive emphasis, single-flight disabling, Escape/cancel behavior, and focus restoration.

Refactor `CustomerGroupCandidateDialog` without moving its candidate Cubit or selection ownership. Use a constrained responsive dialog with title/close control, bounded search, candidate state body, selectable identity rows, integrated pagination, selection count in the confirm action, and mutation progress. Candidate selection must survive page changes and relayout while the dialog is open.

Use explicit `FocusNode` ownership where restoration cannot be guaranteed by the framework. Menus/dialogs must support Enter, Space, Escape, Tab, and Shift+Tab, expose semantic names/tooltips, and never depend on color alone.

### 7. Render deterministic real-state surfaces

Refactor `customer_management_state_panel.dart` to expose distinct variants for initial loading, empty, no-results, retryable error, forbidden, not-found, validation/failure, and mutation progress. The caller remains responsible for passing only currently authorized actions and existing retry/clear/create handlers.

Use `skeletonizer` or purpose-built inert boxes for loading geometry. Skeletons must match their final table/card/detail/form surface, contain no readable fake identity, and announce loading semantically. Refresh-over-existing-data must retain the existing stale-content semantics and must not resemble confirmed success.

### 8. Localization strategy

Before any UI or ARB edit, inventory every required new or changed page title/description, breadcrumb, tab, filter, overflow-menu item, status, empty/no-results/error/forbidden/not-found state, button, tooltip, semantic label, pagination phrase, and dialog title/message/action. Compare `app_en.arb` and `app_ar.arb` for duplicate keys, missing counterparts, and English/Arabic terminology drift, and record the resolved vocabulary in the implementation log. Apply ARB edits incrementally but regenerate only at the controlled checkpoints named in tasks. Each checkpoint MUST name and verify `windows_application/lib/l10n/app_localizations.dart`, `windows_application/lib/l10n/app_localizations_en.dart`, and `windows_application/lib/l10n/app_localizations_ar.dart`. Do not hand-edit generated localization files merely to bypass a failed or stalled generator; record that status exactly and do not claim generated output passed without verification.

All directional layout uses `AlignmentDirectional`, `EdgeInsetsDirectional`, `TextAlign.start/end`, and direction-aware icons/order. Domain identifiers remain unmodified LTR values within Arabic layouts.

### 9. Deterministic golden infrastructure

Add a Customer Management golden harness under `test/features/customer_management/goldens/`:

- load bundled Manrope and IBM Plex Sans Arabic fonts before capture;
- pin locale, text direction, surface size, device-pixel ratio, animation clock, theme, and deterministic test fixtures;
- use the Flutter widget-test renderer on the pinned Windows toolchain as the only stored-baseline authority;
- simulate Web-desktop geometry in the harness rather than maintaining browser-rendered baselines; and
- store images only under `test/features/customer_management/goldens/baselines/`.

The layered matrix is:

1. Customer list, customer detail, customer create, customer edit, customer-group list, customer-group detail, customer-group create, customer-group edit, Add Members, and confirmation dialogs in populated/ready state at all six exact rows: 1440×900 English/LTR, 1440×900 Arabic/RTL, 1280×800 English/LTR, 1280×800 Arabic/RTL, 500×800 English/LTR, and 500×800 Arabic/RTL.
2. Shared scaffold plus customer and customer-group primary collections at the declared Web-desktop geometry; this is supplemental and does not replace either desktop row above.
3. At one declared desktop geometry, the customer collection and customer-group collection EACH cover loading, empty, filtered no-results, retryable error, and forbidden. Their list contracts have no entity identity and therefore cannot produce not-found; customer-detail and customer-group-detail routes own not-found coverage instead. Mutation-capable forms/dialogs cover validation or failure and in-progress states.
4. Targeted non-golden widget tests exercise every additional reachable state under Arabic/RTL and narrow constraints.

Before accepting each new or intentionally changed mandatory baseline, record a side-by-side review containing route/screen, state, locale, text direction, viewport, reference image, generated artifact path, intentional exclusions, known data-dependent differences, reviewer result (`accepted` or `rejected`), rejection reason, and date/checkpoint. Every mandatory baseline must be explicitly accepted before SC-002 or SC-003 can pass; pixel comparison alone is not design acceptance. Pixel tolerance is permitted only for documented nondeterministic antialiasing edge pixels and may not mask structural, text, color, clipping, or state differences.

## Implementation Sequence

1. Capture a pre-change inventory: dirty-worktree paths, existing focused test status, current reference-to-route mapping, and current widget keys/semantics relied upon by tests.
2. Add failing characterization/widget tests for shared scaffold hierarchy, the 760-pixel collection breakpoint, module-scoped styling, approved fields/exclusions, and preserved callbacks/request counts.
3. Add visual tokens and shared page/surface/header/tab/menu primitives; migrate the shared scaffold without changing routes or state ownership.
4. Remediate customer and group list/filter/collection/pagination surfaces, then group-member records; verify desktop, narrow, RTL, long-value, and action propagation behavior.
5. Remediate customer detail and customer create/edit surfaces; verify optional values, multiple phones, archived memberships, validation, dirty navigation, and lifecycle/save preservation.
6. Remediate group detail and name-only group forms; verify member count, nullable creation date, bounded member state, and excluded description/status controls.
7. Characterize sidebar navigation, module-tab navigation, Cancel, browser back/forward, direct route change, dismissal/stay, confirmed leave, draft retention, return values, and focus restoration for unsaved changes; only then remediate Add Members and confirmation dialogs when those contracts remain unchanged.
8. Replace generic loading/empty/error presentation with geometry-appropriate skeleton and state surfaces while retaining real Cubit state and existing handlers.
9. Add/refresh Arabic and English localization entries and verify direction-aware layout and mixed-direction values.
10. Add the deterministic golden harness and layered baseline matrix; perform and document side-by-side reference review before accepting baselines.
11. Run focused tests after each slice, then complete the final regression/build/scope gates serially and record exact results. Do not repair unrelated shell, Finance, backend, or deployment failures in this feature.

## Verification Strategy

### Test-first checkpoints

- **Scaffold and scope**: mounted-shell/router tests prove all eight routes retain identity, selected module tab, capability behavior, and guarded navigation; scope-guard tests reject global-theme, backend, route-contract, fake-data, metrics/history, group-description, and editable-status drift.
- **Collections**: widget tests at 760, 759, 1280×800, 1440×900, and 500×800 verify table/card choice, approved columns, long values, integrated pagination, action propagation, RTL order, no overflow, and unchanged Cubit calls.
- **Details/forms**: widget tests cover missing and long optional values, zero/multiple phones, archived groups, stable draft values through relayout/locale change, lifecycle visibility, submission progress/failure, and reachable footer actions.
- **Dialogs/states**: keyboard and semantics tests cover menu/dialog activation, focus traversal/restoration, deterministic skeletons, state distinctions, retry rules, candidate paging/selection, mutation single-flight behavior, and the fully characterized unsaved-navigation contract.
- **Goldens**: every named screen/dialog passes all six exact FR-041 rows; both primary collections pass every reachable additional collection state; pixel comparison has zero unexplained differences; and every mandatory baseline has an explicit accepted review record.

### Final commands and gates

Run Flutter commands serially from `windows_application`:

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze <changed Dart files and focused test paths>
flutter test test/features/customer_management
flutter test test/app/customer_management_routing_test.dart test/app_shell_bilingual_test.dart test/shared/widgets/app_sidebar_auth_test.dart test/features/customer_management/customer_form_navigation_test.dart
flutter test <golden test target(s)>
flutter build windows
flutter build web
git diff --check
```

If the repository has an established faster Windows/Web smoke gate, it may run during intermediate checkpoints, but FR-050 still requires the final build or established final smoke evidence named in the implementation log. A timeout, stall, skip, unavailable toolchain, missing final output, or stale artifact is not a pass.

The final inspection must:

- compare changed paths with the initial dirty-worktree snapshot;
- confirm no backend, database, deployment, API/payload/query, repository, Cubit, route-contract, or global-theme change entered scope;
- search production Customer Management code for fake/demo values, hard-coded visible copy, `X-Tenant-Id`, client normalization/authority, unsupported metrics/history/orders, group descriptions, and editable group status;
- verify golden fixtures and baselines exist only under test assets;
- report focused successes separately from unrelated broader failures; and
- record commands, exit status, counts, artifacts, baseline review evidence, and blockers in this feature's implementation log when tasks are generated.

## Project Structure

### Documentation (this feature)

```text
specs/flutter-customer-management-visual-parity-remediation/
├── spec.md
├── plan.md
├── tasks.md                 # created later by $speckit-tasks
└── implementation-log.md    # created/updated during implementation
```

No `research.md`, `data-model.md`, or API contract artifact is required: the visual reference analysis and decisions are already resolved in `spec.md`, no entity changes exist, and all backend/API contracts are explicitly frozen.

### Source Code (repository root)

```text
windows_application/
├── design_refs/customer_management_design_reference/
│   ├── customer_management_reference.html
│   └── screens/
├── lib/
│   ├── core/theme/                         # consume only; do not modify globally
│   ├── l10n/
│   │   ├── app_en.arb
│   │   ├── app_ar.arb
│   │   └── generated localization output
│   └── features/customer_management/
│       ├── controllers/                    # behavior frozen
│       ├── models/                         # contracts frozen
│       ├── repositories/                   # contracts frozen
│       ├── views/
│       │   ├── customer_list_screen.dart
│       │   ├── customer_detail_screen.dart
│       │   ├── customer_form_screen.dart
│       │   ├── customer_group_list_screen.dart
│       │   ├── customer_group_detail_screen.dart
│       │   └── customer_group_form_screen.dart
│       └── widgets/
│           ├── customer_management_visual_tokens.dart
│           ├── customer_management_page_header.dart
│           ├── customer_management_surface.dart
│           ├── customer_management_module_tabs.dart
│           ├── customer_management_overflow_menu.dart
│           └── existing Customer Management widgets
└── test/
    ├── app/                                 # relevant routing regression
    ├── features/customer_management/
    │   ├── controllers/                     # existing behavior regression
    │   ├── repositories/                    # existing contract regression
    │   ├── views/                           # screen/layout interaction tests
    │   ├── widgets/                         # primitive/state/collection tests
    │   └── goldens/
    │       ├── customer_management_golden_harness.dart
    │       ├── *_golden_test.dart
    │       └── baselines/
    └── shared/                              # relevant shell/sidebar regression
```

**Structure Decision**: Extend the existing `windows_application` Customer Management vertical slice. Keep business state and transport layers unchanged, place reusable remediation primitives beside existing feature widgets, and colocate visual tests with the current Customer Management test suite. Do not create another package, shell, design system, backend surface, or production fixture source.

## Complexity Tracking

No constitution violations require justification.
