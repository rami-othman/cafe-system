# Feature Specification: Flutter Customer Management — Visual Parity Remediation

**Feature Branch**: `flutter-customer-management-visual-parity-remediation`

**Created**: 2026-09-12

**Status**: Draft

**Input**: User description: "Bring all implemented Flutter Customer Management screens into close visual and structural parity with `windows_application/design_refs/customer_management_design_reference/` while preserving the verified Customer Management behavior and authority boundaries."

## Overview

This feature remediates the presentation of the existing Flutter Customer Management module on Windows and Web. It aligns the implemented customer and customer-group screens with the composition, hierarchy, density, spacing, colors, tables, cards, dialogs, and state treatments demonstrated by the supplied design-reference screenshots and HTML.

This is a presentation-only phase. Existing backend contracts, tenant-scoped authorization, routes, Cubits, repositories, lifecycle rules, raw-phone handling, bounded pagination, localization architecture, accessibility behavior, and unsaved-navigation behavior remain authoritative and behaviorally unchanged. The reference may influence how approved data and actions are arranged, but it cannot introduce data, controls, calculations, business rules, or navigation that the current Customer Management contract does not support.

## Clarifications

### Session 2026-09-12

- Q: At what available content width should collection tables switch to the narrow card layout? → A: Below 760 logical pixels for every customer, group, and member collection.
- Q: How should a new golden baseline be approved as visually faithful to its design reference before it becomes the regression standard? → A: Require a documented side-by-side checklist review against the applicable reference.
- Q: Must every loading, empty, error, validation, and progress state be captured at every locale and viewport combination? → A: Use layered coverage without a full cross-product.
- Q: Should the reference-inspired colors, spacing, typography, and component styling be limited to Customer Management or modify the application-wide theme? → A: Keep new styling scoped to Customer Management.
- Q: Which rendering environment should be authoritative for stored golden baselines? → A: Use one deterministic Flutter widget-test baseline set on the pinned Windows toolchain; keep platform smoke gates separate.
- Q: Which complete viewport/locale matrix is required for layout acceptance? → A: Every supported screen family and both dialog types must be verified at 1440×900 English/LTR, 1440×900 Arabic/RTL, 1280×800 English/LTR, 1280×800 Arabic/RTL, 500×800 English/LTR, and 500×800 Arabic/RTL.
- Q: Can a passing pixel comparison approve a golden baseline by itself? → A: No. Every mandatory baseline also requires an explicit accepted side-by-side review record; a rejected or unreviewed baseline cannot satisfy SC-002 or SC-003.

### Authoritative Precedence

When sources disagree, implementation and review MUST apply this order:

1. Existing backend API and authorization contracts.
2. `specs/flutter-customer-management/spec.md` and its approved functional requirements.
3. The numbered design-reference screenshots and `customer_management_reference.html` for visual composition only.
4. The current Flutter UI implementation.

The higher-priority source wins without requiring a clarification. Visual parity means a close adaptation of the reference using only contract-supported content and actions; it does not mean copying the prototype's behavior or data model.

### Existing Behavior Baseline

The remediation MUST preserve the existing implemented behavior, including:

- capability-based, fail-closed access using the authenticated `customer.manage` projection, with backend authorization remaining final;
- the eight existing customer and group routes and their current direct-load behavior;
- server-side bounded customer, group, member, and eligible-member collections;
- 300 millisecond search debounce, immediate Enter submission, immediate clear, page reset rules, criteria retention, in-flight coalescing, and stale-response rejection;
- backend-generated customer identity, exact raw phone preservation, explicit primary-phone selection, archived membership retention, and single-flight saves;
- backend-returned lifecycle and `allowedActions`, confirmation requirements, no optimistic mutation, and no automatic mutation retry;
- authoritative group membership selection and mutation behavior, including selection retained across bounded candidate pages while the dialog remains open;
- localized Arabic/English text, explicit mixed-direction value handling, and dirty-form navigation confirmation; and
- distinct real loading, empty, no-results, forbidden, not-found, validation, conflict, network, timeout, server, mutation-progress, and success outcomes.

No prior test count is treated as current verification for this remediation.

## Design Reference Analysis

All 13 PNG files under `windows_application/design_refs/customer_management_design_reference/screens/` and the bundled `customer_management_reference.html` were reviewed for this specification.

| Reference | Adopted presentation contract | Required adaptation or exclusion |
| --- | --- | --- |
| `01_customer_list.png` | Shared shell content region, compact module tabs, title/description/action row, bordered filter surface, result count, warm table header, status badges, compact row overflow menu, and table footer | Show only customer number, name, primary phone, group summary, lifecycle, and allowed actions. Omit last visit and order count. Data and filter results remain server-provided. |
| `02_customer_list_loading.png` | The final list geometry remains stable while repeated skeleton rows occupy the table body | Do not show prototype rows or replace the bounded request with local data. |
| `03_customer_list_empty.png` | Centered empty-state icon, title, explanation, and primary create action inside the collection card | Creation is shown only when already authorized by the existing module access contract. |
| `04_customer_list_error.png` | Centered error icon, message, and retry action inside the collection card | Forbidden and not-found remain distinct non-retrying states; retry repeats the existing criteria only for retryable failures. |
| `05_customer_group_details.png` | Group identity/status/count header, edit/add-member action placement, member search, member table, and restrained row actions | Omit group description. Lifecycle actions remain derived from authoritative state and confirmation rules. Member data remains bounded and server-provided. |
| `06_customer_group_create.png` | Constrained single-card form, clear heading hierarchy, and grouped footer actions | Retain only the writable group name. Omit description and directly editable status. The same composition is adapted for edit. |
| `07_customer_groups_list.png` | Module tabs, title/description/action row, search plus segmented status filter, bordered group table, status badges, and compact overflow actions | Use server-provided name, member count, lifecycle, and creation date when available. The segmented control maps only to supported Active, Archived, and All criteria. |
| `08_customer_order_history.png` | General visual vocabulary only, such as card borders, filter density, table treatment, and footer spacing | The Orders tab, order history, order filters, order rows, totals, and payment/order status data are entirely out of scope and MUST NOT appear. |
| `09_customer_details_overview_top.png` | Customer identity/status header, compact edit/overflow actions, and card-grid composition | Omit overview/orders tabs and all metric cards. Use only contract-supported profile information. |
| `10_customer_details_overview_bottom.png` | Stacked information-card rhythm and desktop content geometry | Omit recent orders and all derived order/visit/spending content. |
| `11_customer_edit_top.png` | Constrained form card; customer identity, read-only number, paired optional fields, compact phone rows, and group chips | Raw phone values and current form semantics stay unchanged. Prototype duplicate-phone behavior is unavailable unless an authorized backend signal exists. |
| `12_customer_edit_bottom.png` | Section dividers, notes area, lifecycle area, and primary/cancel footer placement | Lifecycle remains action-based and server-authoritative, not directly editable form state. |
| `13_customer_create.png` | Create-page heading, explanatory copy, information/phone/group/note sections, and end-aligned save/cancel actions | Customer number remains backend-generated. No status selector, fake identity, or unsupported field is added. |
| `customer_management_reference.html` | Warm neutral palette, compact spacing scale, rounded bordered surfaces, directional layout, responsive wrapping, badges, menus, dialogs, skeletons, and the composition represented by the numbered screens | Exclude its prototype screen switcher, hard-coded arrays, client filtering, simulated mutations/toasts, duplicate-phone scan, group description/status editing, metrics, visits, recent orders, and Orders tab. Existing shell, theme, routing, localization, and state remain authoritative. |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Navigate a Cohesive Customer Module (Priority: P1)

An authorized administrator moves among customer and customer-group routes and sees a consistent module scaffold, compact module tabs, localized breadcrumbs, page headings, descriptions, and correctly placed primary actions without any change to routing or access behavior.

**Why this priority**: A shared hierarchy is the foundation for every remediated screen and makes the module feel like one coherent part of the existing application.

**Independent Test**: Open each of the eight existing routes directly and through in-module navigation in Arabic and English, then verify the selected module tab, breadcrumbs, heading, description, and actions while access and route identities remain unchanged.

**Acceptance Scenarios**:

1. **Given** an authorized session on any Customer Management route, **When** the page renders, **Then** the existing application shell remains in place and the Customer Management content uses the shared visual scaffold.
2. **Given** a customer route, **When** the compact module tabs render, **Then** Customers is selected; **given** a group route, **Then** Customer Groups is selected.
3. **Given** a detail, create, or edit route, **When** breadcrumbs render, **Then** they describe the existing route hierarchy and invoke only existing guarded navigation behavior.
4. **Given** a user without the existing capability, **When** navigation or a direct route is evaluated, **Then** the remediation neither exposes the destination nor weakens the current forbidden behavior.

---

### User Story 2 - Scan and Operate on Visual Collections (Priority: P1)

An authorized administrator scans customer, group, and group-member collections in dense but readable tables on desktop and accessible record layouts on narrow screens, using compact filters, overflow actions, and integrated pagination.

**Why this priority**: Customer and group collections are the module's primary entry points and currently diverge most visibly from the reference.

**Independent Test**: Render populated customer, group, and group-member results with long values and multiple pages; exercise every supported filter, row action, page control, and narrow-layout alternative without changing any request or mutation semantics.

**Acceptance Scenarios**:

1. **Given** a populated customer page on desktop, **When** it renders, **Then** the approved customer fields appear in a bordered table with a reference-aligned header, badges, compact action menu, and pagination footer.
2. **Given** a populated group page, **When** it renders, **Then** name, authoritative member count, lifecycle, optional creation date, and available actions appear without a description or editable-status field.
3. **Given** an action menu, **When** it is opened by pointer or keyboard, **Then** only actions permitted by existing entity state and `allowedActions` are shown, focus is contained appropriately, and focus returns to the trigger when it closes.
4. **Given** a narrow viewport, **When** a collection cannot fit as a readable table, **Then** it uses an accessible card/record treatment with all primary data and actions reachable without clipping.
5. **Given** pagination metadata, **When** the footer renders or a page button is invoked, **Then** labels and enabled states reflect that metadata and existing criteria are preserved.

---

### User Story 3 - Read and Edit Customers in Reference-Aligned Cards (Priority: P1)

An authorized administrator reads a customer's contract-supported profile in a card grid and creates or edits a customer in a constrained, sectioned form card that closely follows the reference while preserving all existing draft and lifecycle behavior.

**Why this priority**: Detail and form screens carry the densest information and must gain visual hierarchy without changing Customer domain semantics.

**Independent Test**: Render customer detail, create, and edit with zero/multiple phones, active/archived groups, optional values, long text, each lifecycle, validation errors, and a dirty draft at desktop and narrow sizes.

**Acceptance Scenarios**:

1. **Given** a loaded customer, **When** detail renders, **Then** identity and status appear in the page header and customer information, phones, groups, and notes appear in responsive cards using only backend-returned values.
2. **Given** missing optional data, **When** detail renders, **Then** localized absence values occupy the correct card locations without fabricated values or collapsed structure.
3. **Given** create or edit state, **When** the form renders, **Then** approved fields are grouped into customer information, phones, groups, notes, and edit-only lifecycle areas inside one constrained card.
4. **Given** an edit route, **When** the immutable customer number renders, **Then** it is visually read-only and remains exactly backend-provided.
5. **Given** a dirty form, **When** locale, direction, or viewport changes, **Then** all draft values and stable phone rows remain intact; **when** navigation is attempted, **Then** the existing discard confirmation still governs it.
6. **Given** a lifecycle or save operation, **When** it is pending or fails, **Then** the remediated buttons, progress, messages, and focus behavior reflect the existing non-optimistic, single-flight state.

---

### User Story 4 - Manage Groups and Memberships in Focused Surfaces (Priority: P2)

An authorized administrator creates or edits a name-only group, inspects its members, and adds or removes memberships through visually focused, keyboard-accessible dialogs.

**Why this priority**: Group workflows share the module vocabulary but must retain their narrower API contract and bounded membership behavior.

**Independent Test**: Render group list/detail/create/edit plus add-member and removal/lifecycle confirmations with populated, empty, paginated, loading, and failure states in both locales and responsive layouts.

**Acceptance Scenarios**:

1. **Given** group create or edit, **When** the form renders, **Then** it uses the reference-aligned form card but exposes only the group name and the existing save/cancel behavior.
2. **Given** group detail, **When** it renders, **Then** identity, lifecycle, authoritative member count, actions, member search, collection, and pagination are visually structured without a group description.
3. **Given** the Add Members dialog, **When** candidates load, **Then** search, selectable candidate rows, selection count, pagination, error/empty treatment, and actions fit the dialog without replacing bounded server queries.
4. **Given** a lifecycle or remove-member confirmation, **When** the dialog opens, **Then** its localized title, consequence, named customer/group context where required, cancel action, and confirm action follow the common dialog composition and keyboard behavior.

---

### User Story 5 - Understand Every Real State Across Platforms (Priority: P1)

An authorized administrator can distinguish and recover from every real Customer Management state in English/LTR and Arabic/RTL on Windows desktop, Web desktop, and narrow layouts.

**Why this priority**: Visual parity is incomplete if it covers only populated prototype screens or breaks accessibility, localization, or failure recovery.

**Independent Test**: Drive deterministic fixtures for loading, refreshing, empty, no-results, retryable error, forbidden, not-found, validation, conflict, mutation progress, and success; compare approved golden images and exercise keyboard/semantic behavior.

**Acceptance Scenarios**:

1. **Given** an initial collection load, **When** it is pending, **Then** a deterministic skeleton preserves the final surface geometry and exposes an appropriate loading announcement.
2. **Given** no records and no criteria, **When** the collection renders, **Then** an empty state offers its authorized create action; **given** active criteria, **Then** a distinct no-results state offers clear/reset.
3. **Given** a retryable failure, **When** its state renders, **Then** the card contains a localized retry action that repeats existing criteria; forbidden and not-found states do not offer automatic or misleading retry.
4. **Given** Arabic or English, **When** any remediated surface renders, **Then** layout direction, alignment, icon direction, focus order, and mixed-direction values are correct without changing stored/displayed values.
5. **Given** the approved visual-regression matrix, **When** golden tests run, **Then** every baseline comparison passes and any intentional baseline update is reviewed against the authority and exclusion rules in this specification.

### Edge Cases

- Long Arabic and English customer/group names MUST wrap or ellipsize according to the surface while preserving an accessible full value through detail content, tooltip, or semantics.
- Long raw phone values, customer numbers, email addresses, and dates MUST retain explicit LTR isolation inside RTL layouts and MUST NOT be reformatted to fit.
- Empty group options, zero phones, no groups, archived assigned groups, and absent optional fields MUST preserve the existing meaning while maintaining card geometry.
- An overflow menu near any viewport or scroll boundary MUST remain fully reachable and MUST not be clipped behind the table, scaffold, or window edge.
- A table with the maximum bounded page size MUST scroll within the intended content region without hiding the integrated pagination footer or primary page action.
- A narrow viewport MUST not require horizontal scrolling to reach save, cancel, create, retry, clear, lifecycle, add-member, remove-member, or pagination controls.
- Loading over a previously loaded entity/page MUST follow existing refresh semantics; presentation changes MUST NOT relabel stale content as a newly confirmed success.
- Validation text, mutation errors, and translated labels that occupy multiple lines MUST not overlap inputs, menus, footer actions, or dialog controls.
- Opening and closing a menu or dialog with Escape, Enter, Space, Tab, Shift+Tab, or pointer input MUST preserve a logical focus path and restore focus to a usable origin.
- Resizing or switching locale while an action menu or dialog is open MUST not mutate data, duplicate a request, or discard a form/candidate selection.
- Optional `createdAt` on a group MUST render a localized absence value when unavailable; it MUST not be synthesized.
- Test fixture data MAY be used only in automated tests and golden generation; no fixture, screenshot payload, or prototype array may be reachable from production code.

## Requirements *(mandatory)*

### Functional Requirements

#### Scope and Authority Preservation

- **FR-001**: The feature MUST modify only Flutter presentation, localization resources needed by that presentation, and visual/widget test assets; it MUST NOT change backend code, backend contracts, database schema, deployment configuration, or Customer domain rules.
- **FR-002**: Existing Customer Management route locations, route identity loading, application-shell ownership, sidebar capability behavior, and unsaved-navigation guards MUST remain behaviorally unchanged.
- **FR-003**: Existing repository methods, endpoint paths, request payloads, pagination envelopes, query parameters, error mapping, and bearer-token tenant scoping MUST remain unchanged; the client MUST NOT send `X-Tenant-Id`.
- **FR-004**: Existing Cubit request coordination and mutation semantics MUST remain unchanged, including debounce timing, immediate Enter/clear, generation checks, in-flight coalescing, criteria retention, single-flight mutations, and no automatic mutation retry.
- **FR-005**: The remediated UI MUST render lifecycle status and actions only from backend-returned state and `allowedActions`; no status, permission, count, identity, eligibility, or mutation success may be inferred from the reference.
- **FR-006**: Customer numbers and raw phone values MUST be displayed and submitted without normalization, formatting, generation, prediction, or replacement introduced by this feature.
- **FR-007**: No production path may contain reference demo data, fake records, screen-state switches, simulated success/toasts, or client-side filtering of an unbounded collection.

#### Shared Scaffold, Navigation, and Page Geometry

- **FR-008**: All eight existing Customer Management routes MUST use one shared content scaffold that supplies consistent content bounds, direction-aware outer padding, vertical rhythm, and responsive behavior inside the existing application shell.
- **FR-009**: The scaffold MUST render a compact Customers/Customer Groups module tab control aligned to the logical start edge; selection MUST derive from the current route and tab activation MUST navigate only to the existing list routes.
- **FR-010**: Every route MUST render a localized page title and concise description; detail/create/edit routes MUST additionally render localized breadcrumbs reflecting the existing route hierarchy.
- **FR-011**: Page-level primary and secondary actions MUST occupy the reference-aligned header area on desktop and stack in logical reading order on narrow layouts without clipping.
- **FR-012**: Desktop content MUST use a bounded readable width while collection surfaces may expand to the available content width; forms and dialogs MUST remain visually constrained and centered within that region.
- **FR-013**: The presentation MUST use a consistent module vocabulary for neutral page background, white surfaces, warm accent/table-header fills, borders, radii, spacing, typography hierarchy, status colors, focus indicators, and disabled states. New reference-inspired tokens and reusable components MUST remain scoped to Customer Management, while consuming existing application-wide theme values where they already fit; this feature MUST NOT modify the global application theme or duplicate constants per screen.

#### Customer and Group Collections

- **FR-014**: Customer and group list pages MUST provide a bordered filter surface containing the existing search and contract-supported filters, with a segmented lifecycle control where all represented criteria map exactly to the existing server query.
- **FR-015**: Customer list status segments MUST represent All, Active, Inactive, and Archived; group list segments MUST represent All, Active, and Archived. Selecting a segment MUST invoke the existing Cubit filter behavior and reset to page 1 as already defined.
- **FR-016**: The customer group filter MUST remain a bounded server-sourced option control and MUST preserve long-name usability without widening or overflowing the filter surface.
- **FR-017**: A populated desktop customer table MUST display only customer number, name, primary phone/absence, bounded group summary, lifecycle status, and actions.
- **FR-018**: A populated desktop group table MUST display group name, authoritative member count, lifecycle status, optional server-provided creation date/absence, and actions.
- **FR-019**: Group-member presentation MUST display only customer number, name, primary phone/absence, lifecycle status, and available view/remove actions.
- **FR-020**: Customer and group row actions MUST use a compact overflow menu on desktop where multiple actions exist. The menu MUST preserve existing visibility, confirmation, pending, and failure rules and MUST not cause the row's navigation action to fire.
- **FR-021**: Every customer, group, and member collection MUST switch from its desktop table to an accessible card or record layout when its available content width is below 760 logical pixels. The narrow layout MUST retain the same contract-supported information and actions without an unreadable squeezed table.
- **FR-022**: Pagination MUST appear as an integrated footer of its associated table/card surface, show localized current-range/page information derived from response metadata, and expose direction-correct previous/next controls.

#### Customer Detail and Form Presentation

- **FR-023**: Customer detail MUST use a responsive card grid containing only customer information, all phones, groups, and notes, with identity, lifecycle badge, edit, and lifecycle overflow actions in the page header.
- **FR-024**: Customer detail MUST NOT show tabs when only contract-supported overview content exists and MUST NOT show metrics, spending, order count, average order value, first/last visit, recent orders, order history, or an Orders tab.
- **FR-025**: Customer create/edit MUST use one constrained form card with visually separated sections for customer information, phones, groups, notes, and edit-only lifecycle actions.
- **FR-026**: The customer information section MUST show only name, email, birth date, and the read-only backend customer number on edit; create MAY show localized explanatory text that the number is backend-generated but MUST NOT show an editable or predicted number.
- **FR-027**: Phone rows MUST visually group raw number, type, primary selection, and remove action while retaining stable row identity and all existing primary/raw-value behavior.
- **FR-028**: Active group options and retained archived memberships MUST be visually distinguishable without making archived groups newly selectable or implicitly removable.
- **FR-029**: Customer form save/cancel actions MUST remain reachable at all supported sizes, display existing submission progress, preserve drafts on failure, and invoke the existing save and guarded-cancel behavior only once.

#### Group Detail, Forms, and Dialogs

- **FR-030**: Group detail MUST present group name, lifecycle badge, authoritative member count, edit/lifecycle/add-member actions, member search, member collection, and pagination in the reference-aligned hierarchy.
- **FR-031**: Group create/edit MUST use a constrained card with the name field and existing save/cancel behavior only; group description and directly editable group status MUST be absent.
- **FR-032**: The Add Members dialog MUST provide a localized title, close/cancel behavior, bounded search, deterministic loading/empty/error states, selectable customer identity rows, current selection count in the confirm action, integrated candidate pagination, and mutation progress.
- **FR-033**: Confirmation dialogs MUST share a consistent reference-aligned layout and preserve all existing localized consequence copy, named customer/group context, confirm requirements, single-flight behavior, and post-close focus restoration.

#### Loading, Empty, Error, and Mutation States

- **FR-034**: Initial customer and group collection loading MUST use deterministic skeleton rows matching the final table/card geometry; skeletons MUST not contain readable fake customer or group data.
- **FR-035**: Detail and form loading MUST use geometry-appropriate skeletons or stable placeholders rather than an unstructured full-page spinner.
- **FR-036**: Empty and no-results states MUST be visually distinct, centered within the associated surface, localized, and expose only the existing authorized create or clear action appropriate to the state.
- **FR-037**: Retryable error, forbidden, and not-found states MUST use distinct localized icon/title/message/action treatments. Forbidden and not-found MUST not expose automatic retry, while retryable errors MUST repeat the current request criteria through the existing handler.
- **FR-038**: Validation, conflict, timeout, network, server, and mutation-progress presentation MUST remain attached to the existing real state and MUST never clear entered data or display an unconfirmed success.

#### Localization, Responsiveness, and Accessibility

- **FR-039**: Every new title, description, breadcrumb, state label, menu item, tooltip, semantic label, pagination phrase, and dialog phrase MUST use the established Arabic/English localization system; production widgets MUST contain no new hard-coded user-visible copy.
- **FR-040**: All layouts MUST mirror correctly between English LTR and Arabic RTL using direction-aware alignment, padding, menu anchoring, breadcrumb order, and directional icons while explicitly isolating customer numbers, raw phones, email addresses, and dates as LTR values.
- **FR-041**: The module MUST support Windows desktop, Web desktop, and narrow layouts. Automated layout coverage MUST verify customer list, customer detail, customer create, customer edit, customer-group list, customer-group detail, customer-group create, customer-group edit, the Add Members dialog, and confirmation dialogs (including lifecycle, member-removal, and unsaved-change confirmations where applicable) at every matrix row: 1440×900 English/LTR, 1440×900 Arabic/RTL, 1280×800 English/LTR, 1280×800 Arabic/RTL, 500×800 English/LTR, and 500×800 Arabic/RTL. Every row MUST have zero overflow exceptions, clipped primary actions, or unreachable controls.
- **FR-042**: All interactive controls MUST be keyboard reachable with visible focus, descriptive semantics/tooltips, logical focus order, and non-color-only status/error meaning. Visually compact icon controls MUST retain at least the application's established minimum interactive target size.
- **FR-043**: Menus and dialogs MUST support standard keyboard activation/dismissal, keep focus within modal content while open, and restore focus to the invoking control or another documented logical target when closed.

#### Visual Regression and Verification

- **FR-044**: Golden tests MUST cover the populated or ready presentation of customer list, customer detail, customer create, customer edit, customer-group list, customer-group detail, customer-group create, customer-group edit, the Add Members dialog, and confirmation dialogs at every FR-041 viewport/locale/direction matrix row. “Representative desktop” MUST NOT substitute for either required desktop size.
- **FR-045**: Golden tests MUST additionally cover Web-desktop geometry for the shared scaffold and both primary collections; this supplemental Web geometry does not replace any FR-041 matrix row.
- **FR-046**: Golden coverage MUST use a layered state matrix rather than a full state-by-locale-by-viewport cross-product. At one declared desktop geometry, BOTH the customer collection and customer-group collection MUST each cover loading, empty, filtered no-results, retryable error, and forbidden presentation. Collection list routes have no entity identifier and cannot produce a contract-valid not-found result, so collection-level not-found MUST NOT be invented; not-found coverage MUST instead exercise the existing customer-detail and customer-group-detail route contracts. Mutation-capable forms and dialogs MUST additionally cover validation/failure and in-progress presentation. Targeted widget tests MUST verify that all additional reachable states remain overflow-free and direction-correct under Arabic/RTL and narrow constraints.
- **FR-047**: Golden baselines MUST be generated from deterministic test fixtures and stored only under test assets. Before acceptance, every new or intentionally updated mandatory baseline MUST have one side-by-side review record containing: route/screen, state, locale, text direction, viewport, reference image, generated artifact path, intentional exclusions, known data-dependent differences, reviewer result (`accepted` or `rejected`), rejection reason, and date/checkpoint. Only an explicit `accepted` result satisfies design acceptance; an automated pixel comparison alone is insufficient, and any rejected or unreviewed mandatory baseline prevents SC-002 and SC-003 from passing. Baselines MUST NOT copy excluded prototype content merely to reduce screenshot differences.
- **FR-048**: Stored golden baselines MUST be generated and compared through one deterministic Flutter widget-test renderer on the project's pinned Windows toolchain, with bundled fonts loaded explicitly. Web-desktop geometry MUST be exercised in that widget-test harness; actual Windows and Web runtimes remain subject to their separate build/smoke gates. Golden comparison MUST have zero unexplained differences. Any tolerance required for renderer-specific antialiasing MUST be documented, constrained to nondeterministic edge pixels, and MUST NOT mask layout, text, color, clipping, or state differences.
- **FR-049**: Existing Customer Management controller, repository, routing, authorization, localization, accessibility, state-matrix, and scope-guard tests MUST remain passing after remediation; visual tests supplement and do not replace behavioral assertions.
- **FR-050**: Changed Dart and localization files MUST pass scoped formatting and static analysis; the focused Customer Management test suite, golden suite, relevant shell/router/unsaved-navigation regressions, Windows build/smoke gate, Web build/smoke gate, and `git diff --check` MUST complete successfully before this feature is declared complete.
- **FR-051**: Final scope inspection MUST find zero backend changes, API/payload/query changes, new Customer business rules, fake production data, unsupported fields, group descriptions/status editors, order/history/metric content, deployment changes, or overwritten unrelated worktree changes.

### Key Entities

- **Customer Management Visual Scaffold**: The shared presentation frame within the existing shell, including module tabs, breadcrumbs, content bounds, page header, descriptions, and responsive spacing. It owns no domain state.
- **Collection Surface**: A presentation of one existing bounded server page, its criteria controls, table/card body, real-state treatment, compact actions, and metadata-derived pagination footer.
- **Detail Card Grid**: A responsive read-only arrangement of contract-supported customer or group information. It calculates no new Customer values.
- **Form Surface**: A visual composition over an existing Customer or Group draft and Cubit. It neither adds fields nor changes serialization or dirty-state rules.
- **Action Menu**: A compact presentation of actions already allowed by current entity state and authorization. It introduces no new action or transition.
- **State Surface**: A deterministic visual treatment for one existing loading, empty, no-results, forbidden, not-found, validation, conflict, retryable error, progress, or success state.
- **Visual Regression Baseline**: A test-only reviewed image for one declared locale, direction, viewport, route, and state combination. It is evidence of presentation and not a source of production data or behavior.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All eight existing Customer Management routes render the shared scaffold with the correct selected module tab, localized page hierarchy, and no route or capability-behavior change in automated tests.
- **SC-002**: Every screen and dialog named by FR-041 passes all six exact viewport/locale/direction rows with zero Flutter overflow exceptions, clipped primary actions, or unreachable controls, and every corresponding mandatory baseline has an explicit `accepted` review result.
- **SC-003**: One hundred percent of the golden matrix required by FR-044 through FR-046 passes with zero unexplained visual differences and one explicit `accepted` checklist record per mandatory baseline; automated pixel success alone does not pass this criterion.
- **SC-004**: Automated inspection and behavioral tests find zero occurrences of customer metrics, spending totals, average order value, first/last visit, recent orders, order history, Orders tab, group description, directly editable group status, unsupported fields, or fake/demo production data in rendered Customer Management UI.
- **SC-005**: Every customer, group, and member collection test confirms that displayed records, counts, filters, and pagination derive from the existing bounded server response and that all existing criteria/request semantics remain unchanged.
- **SC-006**: Every lifecycle, save, add-member, and remove-member regression confirms a single request, no optimistic success, unchanged prior data on failure, and authoritative replacement/refresh on success.
- **SC-007**: Accessibility tests confirm keyboard reachability, visible focus, logical traversal, semantic names, modal focus containment/restoration, non-color-only statuses/errors, and direction-correct navigation for every remediated action surface.
- **SC-008**: The complete focused Customer Management suite, golden tests, relevant shell/router/unsaved-navigation regressions, scoped static analysis/formatting, Windows and Web build or established smoke gates, and `git diff --check` finish successfully with results recorded as current evidence; a timeout, stall, skip, or missing artifact is not a pass.
- **SC-009**: Final diff review confirms no backend, database, deployment, Customer contract/domain, repository behavior, Cubit behavior, or unrelated dirty-worktree change was introduced or overwritten by this feature.

## Explicit Exclusions

- Customer metrics, spending totals, average order value, first/last visit, recent orders, order history, order filters, and an Orders tab.
- Group descriptions and directly editable group lifecycle/status fields.
- Fields, actions, or relationships unsupported by the current backend API.
- Duplicate/shared-phone lookup UI unless a separately approved authorized backend match contract exists; this feature does not create one.
- Fake/demo records, prototype screen selectors, simulated requests, simulated mutation success, and production screenshot fixtures.
- Client-owned authorization, tenant selection, Customer normalization, eligibility, lifecycle, pagination, aggregation, or other business rules.
- Backend, database, route-contract, repository-contract, or deployment changes.
- POS customer selection/quick-create, order attachment, discounts, loyalty, marketing, import, or any other later-phase Customer work.

## Assumptions

- The current Customer Management behavior represented by its production models, repositories, Cubits, routes, localized strings, and focused tests is the baseline to preserve.
- The existing application shell remains visually authoritative outside the Customer Management content region; the standalone HTML shell and developer switcher are not copied.
- Existing theme primitives may be extended with Customer presentation tokens or reusable widgets when necessary, provided the result stays inside the presentation boundary and does not create a competing application-wide design system.
- Breadcrumb labels and page descriptions may require new Arabic/English localization entries, but they do not authorize new routes or navigation outcomes.
- A group creation date is optional because the current model accepts a nullable backend value; absence is shown explicitly rather than invented.
- Golden fixtures may use representative deterministic customers/groups only inside test code and may cover values not present in production at test time.
- Responsive adaptation takes precedence over literal pixel placement when needed to preserve readability, accessibility, and action reachability.
- The historical implementation log reports focused successes and incomplete or stale broader build evidence; all completion claims for this remediation require fresh verification.

## Constitutional Alignment *(mandatory)*

- **Tenant, authorization, and branch access**: No authorization or tenant-scope behavior changes. Existing bearer-token tenant context and `customer.manage` capability projection remain authoritative; the UI remains a fail-closed convenience and backend 403 remains final.
- **Domain authority and boundaries**: Laravel Customer Management remains the sole authority for customer identity, phones, groups, membership, lifecycle, normalization, validation, and pagination. Flutter changes only how already-approved state and intent are presented.
- **History, lifecycle, and data evolution**: No schema or data evolution occurs. Existing deactivate/archive/restore semantics and retained historical memberships are preserved; no hard-delete or history/order UI is introduced.
- **Exact semantics and time**: The feature adds no financial, quantity, tax, conversion, or time calculation. Raw phones and customer numbers remain exact; birth dates and optional timestamps keep their existing presentation semantics.
- **API, state, and scale**: Existing stable APIs, bounded server collections, state machines, error mapping, and request coordination are preserved. No local unbounded collection or alternative business rule is permitted.
- **Localization and platforms**: Arabic/English, RTL/LTR, Windows/Web, narrow responsive behavior, accessibility, and the existing application shell/design system are mandatory and verified through widget, semantic, layout, and golden tests.
- **Transactions, retries, and verification**: Existing atomic backend mutations, client single-flight behavior, and no-automatic-retry rule remain unchanged. Completion requires fresh focused regression, golden, static, build/smoke, whitespace, scope, and dirty-worktree evidence; no deployment is performed.
