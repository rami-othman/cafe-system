# Feature Specification: Phase 2 — Flutter Customer Management

**Feature Branch**: `flutter-customer-management`

**Created**: 2026-09-10

**Status**: Draft

**Input**: User description: "Read `plans/customer_management_plan.md` and create a specification for Phase 2 — Flutter Customer Management using the screens in `windows_application/design_refs/customer_management_design_reference/`."

## Overview

Phase 2 adds the administrative Customer Management experience to the existing Flutter Windows/Web application. Authorized tenant owners and managers with Customer Management permission can find, inspect, create, edit, activate, deactivate, archive, and restore customers; they can also manage customer groups and memberships. The UI consumes the authoritative Phase 1 Customer Management API and preserves the established application shell, navigation, localization, and state-management patterns.

The supplied HTML and screenshots are the visual and interaction reference for this phase. They define the intended page hierarchy, tab structure, forms, tables, status treatments, dialogs, and loading/empty/error presentation. They do not authorize fake production data, client-side business rules, hard-coded Arabic-only text, or a replacement application shell.

Customer order history, recent orders, last-visit/order-count columns, and derived spending/order metrics shown in parts of the reference are Phase 4 capabilities. They are not delivered or synthesized in Phase 2. Phase 2 customer details contain identity, contact, groups, lifecycle, and notes only; the Phase 4 areas MUST remain absent until backed by their authoritative API.

## Clarifications

### Session 2026-09-10

- Q: After successfully creating or editing a customer, where should the UI navigate? → A: Open the saved customer's detail screen.
- Q: Should Phase 2 show and edit the customer-group description displayed in the design reference even though Phase 1 does not currently define that field? → A: Omit group descriptions in Phase 2.
- Q: How should customer and group searches trigger server requests while the administrator types? → A: Search after a 300 ms pause; Enter searches immediately.
- Q: After successfully creating or editing a customer group, where should the UI navigate? → A: Open the saved group's detail screen.
- Q: Should removing a customer from a group require confirmation before the membership request is sent? → A: Always require confirmation naming the customer and group.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find and Inspect Customers (Priority: P1)

An authorized administrator opens Customer Management from the existing application navigation, searches and filters the tenant's paginated customer collection, and opens a customer to inspect current profile and lifecycle information.

**Why this priority**: Finding and understanding a customer is the entry point for every administrative workflow and provides useful value without requiring a mutation.

**Independent Test**: Sign in as an authorized administrator, navigate to Customers, load more than one server page, search by supported identity/contact values, apply status and group filters, and open a result without relying on locally fabricated records.

**Acceptance Scenarios**:

1. **Given** an authorized owner or permitted manager, **When** the actor selects Customer Management in the existing shell, **Then** the customer list route opens inside that shell and preserves the current tenant and session context.
2. **Given** a successful administrative collection response, **When** the page renders, **Then** each row shows customer number, name, primary phone or an explicit no-phone value, group summary, lifecycle status, and available actions.
3. **Given** customer search text, **When** typing pauses for 300 milliseconds or Enter is pressed, **Then** the client requests a server-filtered first page and displays only the latest returned records and pagination metadata.
4. **Given** multiple result pages, **When** the administrator changes page, **Then** the current search and filters are retained and the requested server page is shown once.
5. **Given** a selected customer, **When** the detail route opens, **Then** it shows the current customer number, name, all phones and their types/primary designation, email, birth date, groups, lifecycle status, and notes returned by the backend.
6. **Given** an archived customer reached from an administrative result or direct authorized route, **When** details load, **Then** its archived state is explicit and no control implies it is available for new operational use.

---

### User Story 2 - Create and Edit a Customer (Priority: P1)

An authorized administrator creates a customer and later edits the customer's profile, multiple phones, primary phone, and memberships while the backend remains the authority for validation and atomic persistence.

**Why this priority**: Administrative maintenance is the core purpose of the Phase 2 module.

**Independent Test**: Create a customer without a phone, create one with multiple phones and exactly one primary, then edit profile fields, remove and add phones, change the primary phone, and replace group memberships while verifying real API success and validation responses.

**Acceptance Scenarios**:

1. **Given** valid create input with a non-blank name and no phone, **When** the administrator saves, **Then** one real customer is created and the UI opens the saved customer's detail route using the backend-generated identity and customer number.
2. **Given** two or more entered phones, **When** the administrator selects one as primary and saves, **Then** all entered raw phone values, phone types, and the single primary selection are submitted.
3. **Given** a customer with existing phones, **When** a phone is added, removed, or made primary, **Then** the form preserves all other unsaved values and does not silently rewrite or discard any raw phone value.
4. **Given** a phone matching another customer's normalized number, **When** the backend accepts shared phones, **Then** the UI warns without blocking, merging, or changing either customer and permits the administrator to continue deliberately.
5. **Given** active same-tenant groups, **When** the administrator selects or clears memberships and saves, **Then** the requested complete membership set is submitted atomically with the profile.
6. **Given** an archived group already assigned to the customer, **When** the edit form opens, **Then** the existing membership remains visible and preserved unless the administrator explicitly removes it, but the archived group cannot be newly selected.
7. **Given** invalid input or a backend validation response, **When** save fails, **Then** field and form errors are localized, entered values remain available for correction, no success navigation occurs, and no partial success is claimed.
8. **Given** a save request in progress, **When** the administrator activates save again, **Then** duplicate submission is prevented until the request completes.

---

### User Story 3 - Manage Customer Lifecycle (Priority: P1)

An authorized administrator changes a customer's lifecycle through explicit, confirmed actions and sees the backend-confirmed result reflected consistently across list, detail, and edit views.

**Why this priority**: Lifecycle controls protect operational use without destroying historical identity.

**Independent Test**: Deactivate an active customer, activate an inactive customer, archive a customer, restore it, and verify controls, confirmations, server errors, and refreshed states at every step.

**Acceptance Scenarios**:

1. **Given** an active customer, **When** the administrator chooses Deactivate, confirms the localized consequence dialog, and the backend succeeds, **Then** the customer is shown as Inactive and disappears from views filtered to Active.
2. **Given** an inactive customer, **When** Activate succeeds, **Then** the UI shows Active using the backend response.
3. **Given** an active or inactive customer, **When** Archive is confirmed and succeeds, **Then** the customer is shown as Archived and is absent from the default administrative list.
4. **Given** an archived customer, **When** Restore succeeds, **Then** the customer is shown as Inactive and activation remains a separate explicit action.
5. **Given** a lifecycle request that fails because of validation, authorization, conflict, network, or server error, **When** the response arrives, **Then** the prior displayed state remains, the failure is explained with a retry-safe localized message, and no optimistic success is retained.
6. **Given** a lifecycle mutation in progress, **When** the same or conflicting action is attempted, **Then** conflicting controls are disabled and only one request can affect the visible state at a time.

---

### User Story 4 - Manage Customer Groups and Memberships (Priority: P2)

An authorized administrator lists, searches, creates, edits, archives, restores, and inspects customer groups, and adds or removes group members using real bounded server results.

**Why this priority**: Groups organize customer administration but depend on the core customer navigation and profile workflows.

**Independent Test**: Create and edit a group, find it in filtered results, open its members, add eligible customers from a paginated server search, remove a member, archive and restore the group, and verify all changes after refresh.

**Acceptance Scenarios**:

1. **Given** the Customer Management module, **When** the administrator switches between Customers and Customer Groups, **Then** each destination has a stable route and selected-tab state within the existing shell.
2. **Given** the group list, **When** search or lifecycle filter criteria change, **Then** the client requests bounded server-filtered results and renders name, current member count, lifecycle status, creation date when supplied, and available actions.
3. **Given** a valid group name, **When** create or edit succeeds, **Then** the UI opens the saved group's detail route from the authoritative response without inserting a client-only record or description.
4. **Given** a group detail view, **When** it loads, **Then** current members are shown with customer number, name, primary phone, status, and explicit remove/view actions.
5. **Given** the Add Members flow, **When** the administrator searches, **Then** candidates come from bounded same-tenant server results, exclude customers already in the group and any customers/groups ineligible for new membership, and retain deliberate selections across result-page changes within that open flow.
6. **Given** one or more selected candidates, **When** Add succeeds, **Then** the group detail refreshes from authoritative state and each customer appears at most once.
7. **Given** a remove-member action, **When** the administrator confirms a localized dialog naming the customer and group and the request succeeds, **Then** only that membership is removed; neither the customer nor group is archived or deleted.
8. **Given** a group lifecycle action, **When** archive or restore is confirmed and succeeds, **Then** the UI reflects the backend state and retained memberships are not presented as deleted.

---

### User Story 5 - Recover From Real UI States (Priority: P2)

An administrator understands and can recover from initial loading, refresh, empty, no-results, validation, authorization, network, and server states in both supported languages and layout directions.

**Why this priority**: The module cannot be production-ready if it only represents the happy path shown by seeded prototype data.

**Independent Test**: Drive every collection and mutation through loading, empty, filtered-no-results, retryable error, validation error, forbidden, and success states in Arabic/RTL and English/LTR on Windows and Web.

**Acceptance Scenarios**:

1. **Given** an initial collection request, **When** it is pending, **Then** a stable skeleton or progress state matching the reference occupies the content area without showing stale records as current.
2. **Given** a successful zero-record response with no active criteria, **When** it renders, **Then** the localized empty state explains that no customers or groups exist and offers an authorized creation action.
3. **Given** a successful zero-record response with search or filters active, **When** it renders, **Then** a distinct no-results state shows the active criteria and offers a clear/reset action.
4. **Given** a retryable collection failure, **When** the error state renders, **Then** it provides a localized Retry action that repeats the same request criteria without duplicating records.
5. **Given** an authorization failure, **When** a route or operation is denied, **Then** the UI shows an appropriate localized access state and does not disguise it as an empty collection or retry indefinitely.
6. **Given** Arabic or English locale, **When** any list, form, dialog, message, or state renders, **Then** all user-facing text is localized and layout, focus order, table alignment, directional icons, and mixed-direction phone/email/number values are usable in RTL and LTR.

### Edge Cases

- A collection response arriving after newer search, filter, page, or route criteria MUST NOT replace the newer result.
- Refreshing or directly opening a detail/edit/group route MUST load by route identity and MUST NOT require an object cached from the list.
- A customer or group archived in another session between load and mutation MUST produce and retain the server conflict/validation outcome rather than being locally overwritten.
- Duplicate/shared phone warnings MUST remain advisory; duplicate rows within the same submitted customer remain a backend validation error and MUST be shown distinctly.
- Removing the current primary phone MUST require another remaining phone to become primary before save, unless the last phone is removed.
- A customer with no phone, email, birth date, notes, or groups MUST render explicit localized absence values without crashing or substituting fake values.
- Very long Arabic/English names, group names, phone strings, validation messages, and translated labels MUST wrap or truncate accessibly without hiding the full value from an available detail or tooltip treatment.
- Archived groups retained on a customer MUST remain distinguishable from selectable active groups.
- Changing locale, window size, or browser viewport during an in-progress form MUST not silently discard entered values.
- Browser back/forward and Windows navigation actions MUST preserve coherent route state and MUST not repeat a completed mutation.
- Closing or navigating away from a dirty create/edit form MUST require confirmation before discarding changes.
- A failed create/update/lifecycle/membership request MUST never add, remove, or change a record only in client state as though persistence succeeded.

## Requirements *(mandatory)*

### Functional Requirements

#### Access, Navigation, and Scope

- **FR-001**: The existing Flutter application shell MUST expose a Customer Management destination with stable customer-list, customer-create, customer-detail, customer-edit, group-list, group-create, group-detail, and group-edit routes.
- **FR-002**: The administrative module MUST be available to tenant owners and managers with Customer Management permission and MUST not expose administrative routes or controls to employees or other actors lacking that authority.
- **FR-003**: Client route/control visibility MUST be treated only as UX; every read and mutation MUST use the authenticated backend contract and surface authorization failures safely.
- **FR-004**: Customer and group context MUST remain tenant-wide. The client MUST NOT invent branch ownership or send a client-selected tenant identity to widen scope.
- **FR-005**: Direct/deep links and refreshes MUST resolve their own backend state, preserve the existing authenticated session/tenant context, and fail safely when the target is missing, foreign, archived outside the requested context, or forbidden.

#### Customer Collection and Details

- **FR-006**: The customer list MUST request bounded server-side pagination, search, status filtering, and group filtering; local filtering of an unbounded tenant collection is prohibited.
- **FR-006a**: Customer, group, group-member, and add-member searches MUST request the first server page after a 300 millisecond typing pause; Enter MUST submit immediately, and clearing a non-empty search MUST request the unsearched first page immediately.
- **FR-007**: Search MUST support the backend's customer number, displayed/normalized name, raw/normalized phone, and email behavior without duplicating normalization rules in Flutter.
- **FR-008**: Status criteria MUST include Active, Inactive, Archived, and All, while the initial/default list MUST follow the backend default that excludes Archived customers.
- **FR-009**: The list MUST render customer number, name, primary phone, group summary, lifecycle status, and actions. Phase 4-derived last visit, order count, or spend data MUST NOT be fabricated or required in Phase 2.
- **FR-010**: Pagination controls MUST derive their enabled state and labels from response metadata and preserve active search/filter criteria across page requests.
- **FR-011**: Customer details MUST display all Phase 1 profile fields returned by the backend: immutable customer number, name, phones with type and primary indication, email, birth date, groups including retained archived memberships, lifecycle status, and notes.
- **FR-012**: Customer details MUST NOT calculate or display customer order history, recent orders, total orders, paid spend, average order value, first visit, or last visit until the Phase 4 authoritative contract exists.

#### Customer Forms and Phones

- **FR-013**: Create and edit forms MUST support name, zero or more phones, one primary phone when phones exist, phone type, email, birth date, zero or more groups, and notes.
- **FR-014**: Customer number MUST be read-only wherever displayed and MUST come only from the backend; the client MUST NOT generate, edit, predict, or reuse it.
- **FR-015**: The form MAY provide immediate usability validation, but backend validation is authoritative and every returned field/general error MUST be associated with an understandable localized UI location.
- **FR-016**: Phone input MUST preserve the raw value typed by the user and MUST NOT silently normalize, format, reject, merge, or replace it beyond explicit editable presentation behavior.
- **FR-017**: When one or more phone rows exist, the form MUST allow exactly one to be selected as primary before submission. With zero phone rows, it MUST submit no primary phone.
- **FR-018**: The UI MUST support adding and removing phone rows, changing phone types, and changing the primary selection without resetting other form fields.
- **FR-019**: A possible shared-phone match MAY show the reference warning/dialog and link to the other customer only when the backend provides authorized match information; it MUST remain advisory and MUST allow deliberate continuation because shared phones are valid.
- **FR-020**: Group selection on a customer form MUST offer only active groups for new assignment, visibly preserve already assigned archived groups, and never silently remove a retained membership.
- **FR-021**: Create/update submission MUST be single-flight, preserve input on failure, use the backend's atomic profile/phone/membership operation, and refresh or replace local state only from a successful authoritative response.
- **FR-021a**: After a successful customer create or update, the UI MUST open the saved customer's detail route and render the authoritative backend response; it MUST NOT remain on the form or return to the collection automatically.
- **FR-022**: A dirty customer or group form MUST request confirmation before cancel/navigation discards unsaved input.

#### Lifecycle and Customer Groups

- **FR-023**: Customer controls MUST expose only transitions valid for the currently returned state: deactivate Active, activate Inactive, archive Active/Inactive, and restore Archived to Inactive.
- **FR-024**: Deactivate, archive, restore, customer-group archive, and customer-group restore actions MUST require a localized confirmation explaining the operational consequence; activation MAY be immediate but MUST still show mutation progress and failure.
- **FR-025**: Lifecycle state MUST change in the UI only after backend success, after which affected list/detail/edit data MUST be refreshed or consistently updated from the authoritative response.
- **FR-026**: The group collection MUST support bounded server-side pagination/search and Active, Archived, and All filtering, and MUST display group name, member count, lifecycle status, and available actions.
- **FR-027**: Group create/edit MUST support the Phase 1 writable group name field and MUST omit the description control shown in the design reference; Phase 2 MUST NOT add client-only or backend-persisted group descriptions.
- **FR-027a**: After a successful group create or update, the UI MUST open the saved group's detail route and render the authoritative backend response; it MUST NOT remain on the form or return to the collection automatically.
- **FR-028**: Group details MUST show identity, lifecycle status, current member count, and a bounded/searchable member collection, without a group description.
- **FR-029**: Adding group members MUST use bounded server-side candidate search, exclude ineligible/already assigned candidates, support deliberate multi-selection, and submit memberships through the authoritative same-tenant backend operation.
- **FR-030**: Removing a group member MUST first require a localized confirmation that names both the customer and group. After confirmation and backend success, the UI MUST remove only the membership and refresh both the member collection and reported count.

#### State, Localization, Accessibility, and Platforms

- **FR-031**: Every collection and detail route MUST define initial-loading, refreshing, success, empty, filtered-no-results, retryable-error, forbidden, and not-found states using real request outcomes.
- **FR-032**: Every mutation MUST define idle, in-progress, validation-error, authorization-error, conflict, retryable-error, and success states and MUST prevent duplicate/conflicting submissions while in progress.
- **FR-033**: Stale responses MUST be ignored or cancelled when a newer search, filter, page, target, or route request supersedes them.
- **FR-034**: All user-visible labels, messages, validation errors, confirmations, tooltips, status names, and accessibility semantics MUST use the established Arabic/English localization system; production strings MUST NOT be hard-coded in widgets.
- **FR-035**: Every referenced screen and state MUST work in Arabic RTL and English LTR, including directional navigation, focus traversal, table alignment, menus, dialogs, and mixed-direction customer numbers, phone numbers, dates, and email addresses.
- **FR-036**: The UI MUST meet the application's established accessibility practices for keyboard navigation, visible focus, semantic control names, non-color-only status/error communication, dialog focus containment/restoration, and minimum interactive target sizing.
- **FR-037**: The module MUST support the existing Windows and Web targets and adapt to their supported window/viewport sizes without horizontal clipping of primary actions or inaccessible table/form content.
- **FR-038**: The implementation MUST reuse the existing shell, navigation, design tokens/components, dependency injection, API client, state-management conventions, routing, and localization architecture; it MUST NOT ship the standalone reference HTML or its prototype screen switcher as production UI.
- **FR-039**: Production UI MUST contain no seeded customer/group arrays, demo switches, fake metrics, hard-coded identifiers, client-side authorization bypasses, or simulated mutation success.

#### Verification and Scope

- **FR-040**: Focused Flutter tests MUST cover navigation/authorization visibility, customer list rendering, server search/filter/pagination, detail loading, create/edit, phone add/remove/primary behavior, shared-phone warning behavior, group assignment, lifecycle confirmations and failures, group CRUD/membership flows, dirty-form protection, stale-response handling, and loading/empty/no-results/error/retry states.
- **FR-041**: Widget or integration coverage MUST exercise Arabic RTL and English LTR plus representative Windows-sized and Web-sized layouts, keyboard focus, and semantic labels.
- **FR-042**: Contract-facing tests MUST use the production repositories/API models and validate serialization/error mapping against Phase 1 responses rather than hand-built alternate business rules.
- **FR-043**: Changed Dart files MUST be formatted; focused Flutter tests and relevant `flutter analyze` checks MUST pass; Windows and Web build/smoke verification MUST be completed at the phase checkpoint; and `git diff --check` MUST pass before Phase 2 is declared complete.
- **FR-044**: Phase 2 MUST NOT implement POS customer search/select/quick-create or order attachment (Phase 3), history/metrics (Phase 4), legacy import, loyalty/tier redesign, discounts, marketing, snapshots, or backend-domain redesign.

### Visual Reference Contract

- **VR-001**: `screens/01_customer_list.png` through `screens/04_customer_list_error.png` define the customer list's visual hierarchy and distinct populated, loading, empty, and error treatments.
- **VR-002**: `screens/05_customer_group_details.png` through `screens/07_customer_groups_list.png` define the group tabs, collection, detail/member table, and create/edit form composition.
- **VR-003**: `screens/09_customer_details_overview_top.png` and `screens/10_customer_details_overview_bottom.png` define customer detail identity/contact/group/note composition only; their metrics and recent-order regions are excluded by FR-012.
- **VR-004**: `screens/11_customer_edit_top.png` through `screens/13_customer_create.png` define the customer form hierarchy, multi-phone controls, primary selection, group chips, lifecycle controls, and action placement.
- **VR-005**: `screens/08_customer_order_history.png` is retained as a Phase 4 design reference and MUST NOT cause Phase 2 to request, calculate, or fake order history.
- **VR-006**: The reference's colors, density, spacing, typography hierarchy, badges, table/form structure, and dialog patterns SHOULD be matched through the application's existing design system, with necessary responsive, localization, and accessibility adaptations taking precedence over pixel identity.

### Key Entities

- **Customer Management Session State**: Current customer search, lifecycle/group filters, requested page, sort contract when supported, loading/error state, and visible bounded result metadata. It is transient UI state, not a second customer store.
- **Customer Form Draft**: Editable name, raw phone rows and types, primary selection, email, birth date, group selections, and notes plus dirty/submission/validation state. The backend response remains authoritative after save.
- **Customer View**: Read-only projection of customer identity, profile, all phones, group memberships, and lifecycle returned by Phase 1.
- **Customer Group View**: Read-only projection of group identity, lifecycle, member count, and bounded members.
- **Membership Selection Draft**: Transient selected eligible customer identifiers in the Add Members interaction; it creates no membership until backend success.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In automated tests, every authorized administrative destination is reachable through the existing shell and by direct route on both Windows and Web, while unauthorized actors cannot access or invoke its controls.
- **SC-002**: Across a test dataset larger than one page, customer and group searches, lifecycle/group filters, and page changes display exactly the server-returned bounded results and retain criteria with no duplicate or stale rows.
- **SC-003**: All tested create/edit combinations—zero phones, one phone, multiple phones, primary changes, shared phones, group changes, and optional fields—either display the persisted backend response or retain the complete draft with mapped errors; no failed request appears successful.
- **SC-004**: Every tested customer/group lifecycle transition shows confirmation where required, prevents duplicate submission, and matches the backend state after refresh; rejected transitions leave the prior state unchanged.
- **SC-005**: Every customer/group collection and detail route passes automated loading, empty, no-results, forbidden/not-found, retryable error, retry, and success-state coverage without fake fallback data.
- **SC-006**: The complete Phase 2 flow passes representative Arabic/RTL and English/LTR widget tests with no clipped primary action, reversed mixed-direction identifier, inaccessible dialog focus, or untranslated production label.
- **SC-007**: Customer Management completes its focused Flutter test suite with all tests passing, introduces no relevant `flutter analyze` errors, builds or passes the established build-level smoke gate for Windows and Web, and passes `git diff --check` at the phase checkpoint.
- **SC-008**: Inspection of the production path finds zero demo customer/group datasets, simulated success paths, client-generated customer numbers, fake order metrics/history, or client-only lifecycle/authorization decisions.

## Assumptions

- Phase 1 provides the authorized administrative customer/group APIs, stable lifecycle errors, bounded pagination metadata, profile/phone/membership atomic mutations, and permission semantics specified in `specs/customer-domain-foundation/spec.md`.
- Owners have full Customer Management administration access. Managers require Customer Management permission. Employees do not enter this administrative module; their operational search, quick-create, and limited membership capabilities belong to later operational UI scope.
- New manually administered customers default to Active according to the Phase 1 backend contract; Phase 2 does not add a client-owned create-status rule.
- Restoring a customer returns it to Inactive; restoring a group returns it to Active. The UI uses the returned state and does not infer a different result.
- Duplicate/shared phone detection is advisory only when an authorized backend contract supplies a possible match; absence of such an endpoint does not permit loading all customers locally to detect duplicates.
- The HTML reference is a standalone design artifact. The numbered screenshots are stable visual examples; implementation planning will map their patterns to existing Flutter components after inspecting the current shell and design system.
- Group description is omitted even though it appears in the design reference because it is not part of the Phase 1 group entity contract; adding backend persistence for it is outside Phase 2.
- This phase changes no database schema and defines no new financial, quantity, tax, conversion, or accounting semantics.
- The authoritative tenant/branch IANA timezone governs any date/time presentation received from the backend. Birth date is a calendar date and is not shifted through a device timezone.

## Constitutional Alignment *(mandatory)*

- **Tenant, authorization, and branch access**: The UI consumes authenticated tenant-scoped data and never widens scope with client tenant identifiers. Owners and permitted managers receive administration navigation; backend authorization remains mandatory. Customers/groups are tenant-wide and not branch-owned, so no new branch-selection rule is introduced.
- **Domain authority and boundaries**: Customer Management owns customer profile, phones, groups, memberships, lifecycle, search, and eligibility contracts. Flutter presents and submits those contracts without reimplementing them. POS/order integration, Discounts, Loyalty, Phase 4 history/metrics, and legacy import stay outside this phase.
- **History, lifecycle, and data evolution**: The UI exposes deactivate/archive/restore as distinct non-destructive actions and never suggests hard delete. Existing historical relationships and archived memberships remain represented according to the backend. No schema/import work occurs.
- **Exact semantics and time**: No money, tax, inventory quantity, or conversion is calculated in Phase 2. Customer number and raw phones are preserved exactly. Birth dates remain calendar dates; any timestamps use backend-provided timezone-aware values and authoritative tenant/branch timezone presentation.
- **API, state, and scale**: Phase 1 APIs own validation, permissions, lifecycle, phone invariants, atomicity, tenant scope, and pagination. Flutter uses bounded server-side collections and explicit real loading, empty, no-results, validation, authorization, conflict, network, and server states while preventing stale-result replacement.
- **Localization and platforms**: Arabic/English, RTL/LTR, Windows/Web, accessibility, responsiveness, and the current Flutter shell/design system are mandatory. The standalone HTML is a design reference, not a production shell or source of hard-coded strings.
- **Transactions, retries, and verification**: Flutter prevents duplicate in-flight mutations and treats retries as potentially replayed requests, relying on backend transaction/idempotency semantics where provided. Focused production-path tests, contract tests, analysis, formatting, Windows/Web smoke/build gates, and `git diff --check` are required and must be reported exactly.
