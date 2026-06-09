# Architecture

Cafe System 618 uses a feature-based architecture with an MVC-style internal
structure for each feature. Cubit is used as the controller and
state-management layer.

## Global Folders

```txt
lib/
  app/
  core/
  shared/
  features/
```

## `app`

The `app` folder contains application-level wiring:

- root `App` widget
- router setup
- desktop shell layout
- future app-level navigation concerns

This folder should not contain feature business logic.

`AppShell` is the global Windows desktop layout. It owns the adaptive sidebar,
topbar, main content slot, and optional right panel slot. Feature pages render
inside the shell content area through the router and should not recreate global
navigation chrome.

Shell responsiveness is based on centralized tokens in
`lib/core/constants/app_sizes.dart`:

- `>= 1200`: expanded sidebar, topbar, and full inline right panel.
- `900-1199`: collapsed sidebar rail, topbar, and reduced inline right panel.
- `< 900`: collapsed sidebar rail and content only; right panel content is not
  included inline and can be exposed by compact-mode controls.

## `core`

The `core` folder contains foundation code used across the application:

- constants
- theme values
- errors and failures
- service locator setup
- utilities such as responsive helpers and formatting

Core files should be generic and not depend on a specific feature.

## `shared`

The `shared` folder contains reusable UI and layout primitives:

- common buttons
- inputs
- cards
- dialogs
- loading and empty states
- reusable layouts

Shared widgets should stay generic. If a widget only makes sense for one
feature, keep it inside that feature.

## `features`

The `features` folder contains product areas such as auth, POS, orders,
payments, discounts, shifts, and reports.

Every feature should follow this structure:

```txt
feature_name/
  models/
  views/
  controllers/
  widgets/
  repositories/
```

## Feature Folder Responsibilities

### `views`

Views are route-level or screen-level widgets. A view composes feature widgets,
connects to the feature Cubit, and handles screen layout. Views should not
contain business logic.

### `widgets`

Widgets are feature-specific UI components used by the feature views. They
should be focused, reusable inside the feature, and receive the data they need
through constructors.

### `controllers`

Controllers contain Cubits and state files. Cubits receive user intent from the
UI, coordinate state changes, and communicate with repositories when data access
is needed.

### `models`

Models contain feature data objects and value types. They should be simple,
predictable, and kept close to the feature that owns them.

### `repositories`

Repositories isolate data access for a feature. They may later coordinate with
API clients, databases, or local storage, but those integrations should only be
added when explicitly required.
