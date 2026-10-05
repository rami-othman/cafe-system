# Cafe Configuration — Implementation Notes

## Purpose

The Claude HTML and screenshots in this directory are VISUAL / UX REFERENCES.

They are not the authoritative backend or business-rule contract.

When the reference conflicts with the current Laravel backend, project
architecture, tests, or the rules below, the implementation rules below win.

## Approved Module Structure

Cafe Configuration

- Overview
- Cafe Profile
- Branches
- Team & Access
- Tax

Cafe Configuration is a top-level Owner-only module.

Do not replace or expand the existing Settings screen.

## Existing App Shell

Reuse the existing Cafe System Flutter AppShell, sidebar, top bar, routing,
localization, and responsive behavior.

Do not rebuild the application shell from the Claude HTML.

The standalone HTML frame itself is not production UI.

## Required Corrections To Claude Reference

### Team & Access

Owner:

- Show Protected
- Show All Branches
- Do not expose Team Management actions for Owner

Archived member:

- Do not expose Activate
- Do not expose Restore
- Archived users cannot currently be restored

Deactivated member:

- May expose Activate

Active member:

- May expose Deactivate

Password rules:

- Manager temporary password: minimum 10 characters
- Employee temporary password: minimum 8 characters
- Role-change/reset-password validation follows the target/new role

Employee:

- Login identifier is username
- Email is still required by the current backend

Manager:

- Login identifier is email

Manager/Employee:

- Must have at least one active branch assignment

Inactive branches:

- Must not be selectable for new branch assignments

Owner branch semantics:

- Owner has implicit All Branches access
- Do not represent Owner using user_branches pivots
- Branch filtering should treat Owner as having access to every active branch

Edit Team Member:

- Validate name
- Validate email
- Validate username when Employee
- Validate branch assignments
- Validate conditional temporary password

Team list:

- Support backend pagination
- Search/filter by role, status, and branch

Do not include prototype-only controls such as:

- Populated
- Loading
- Empty
- Error

Those are reference/demo states only.

### Branches

Branch create/edit fields:

- name
- address
- phone
- timezone

Currency:

- read-only SYP

Branch status:

- must come from backend
- do not hard-code Active

New branch:

- initialize timezone from Cafe Profile timezone in Flutter
- backend still validates final IANA timezone

Do not expose Owner actions for:

- deactivate
- activate
- archive
- restore
- delete

These remain deferred.

### Cafe Profile

Editable:

- name
- email
- phone
- timezone

Read-only:

- currency
- status

Do not expose:

- slug
- plan
- subscription
- billing
- logo upload

Timezone must support valid IANA timezones, not only the short list shown in
the prototype.

### Tax

UI representation:

- percentage, e.g. 8%

API representation:

- fractional numeric value, e.g. 0.08

Valid UI range:

- 0% through 100%

Existing orders retain their historical tax snapshot.
Updated tax applies to newly created orders.

Do not implement:

- branch tax
- product tax
- inclusive tax
- multiple rates
- exemptions

### States

Real implementation must handle:

- initial loading
- empty
- load failure + retry
- validation 422
- saving/creating/updating
- mutation failure
- success feedback

Disable mutation buttons while requests are in progress.

Do not duplicate mutation requests.

## Backend Contracts

Cafe Profile:

- GET /api/v1/cafe-configuration/profile
- PUT /api/v1/cafe-configuration/profile

Branches:

- GET /api/v1/cafe-configuration/branches
- POST /api/v1/cafe-configuration/branches
- GET /api/v1/cafe-configuration/branches/{branch}
- PUT /api/v1/cafe-configuration/branches/{branch}

Tax:

- GET /api/v1/cafe-configuration/tax
- PUT /api/v1/cafe-configuration/tax

Team & Access:

- Reuse the existing roles/employees APIs.

## Authorization

Cafe Configuration v1:

Owner:

- allowed

Manager:

- hidden in Flutter
- forbidden by backend

Employee:

- hidden in Flutter
- forbidden by backend

Do not implement final granular permissions in this feature.

## Deferred

Do not implement as part of Cafe Configuration:

- Shift Open / Close
- Shift reconciliation
- final granular RBAC
- custom roles
- Owner branch lifecycle mutation
- user restore
- multiple tax modes
- Inventory
- Financial Reports
- subscription/billing

## Screenshot Set

The package contains the screenshots actually supplied for implementation reference:

- Overview
- Cafe Profile
- Branches populated
- Branches loading
- Branches empty
- Branches error
- Create Branch
- Team & Access
- Add Manager
- Add Employee
- Tax

The standalone HTML remains the primary reference for additional interactive states/dialogs
that are not represented by a separate PNG in this package.
