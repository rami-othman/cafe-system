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

The POS route uses `PosCubit` for local fake-data interactions. The route shell
provides the Cubit above both the POS content view and the shell right cart
panel so product selection, cart updates, order type, and totals stay in one
feature-owned state object.

The Orders route uses its own `OrdersCubit` and `OrdersRepository` for fake
active and held order summaries. Orders filtering, local cancel, and local
complete behavior stay inside the `orders` feature and do not depend on POS
cart state.

### `models`

Models contain feature data objects and value types. They should be simple,
predictable, and kept close to the feature that owns them.

### `repositories`

Repositories isolate data access for a feature. They may later coordinate with
API clients, databases, or local storage, but those integrations should only be
added when explicitly required.

`PosRepository` retains deterministic fake categories/products for local widget
tests and carries non-menu POS/order API calls. Its legacy Catalog menu methods
are compatibility/fixture-only; backend production POS does not invoke them.

`OrdersRepository` owns order history/detail access, including historical legacy
orders whose `publishedMenuVersionId` is null.

## POS published runtime sync, presentation, and reconnect (Phases 12D–12F)

`PosMenuSyncRepository` is separate from the legacy `PosRepository`. It consumes
only `GET /pos/menu-sync` runtime contract v1, preserving published Menu /
Section / placement order and using backend-provided runtime sellability and
effective prices without local schedule or pricing resolution. `PosMenuSyncCubit`
owns refresh state while `PosCubit` remains transaction/cart state; the active
backend POS UI consumes only this published runtime path. `PosPublishedMenuPresenter`
preserves backend Menu/Section/placement ordering and maps identities into cards.
New versioned cart lines retain `publishedMenuVersionId`, `placementId`,
`productId`, `variantId`, and selected modifier option IDs, which are sent via
the snapshot-aware order request. The legacy Catalog endpoints are now
deprecated compatibility APIs and are not used by the published POS UI.

Static projections are scoped by configured tenant identity, branch, and `pos`
channel in an app-support JSON file. The cache stores context, version identity,
the static projection, last backend-evaluated runtime overlay, and sync time—not
credentials. The cached runtime overlay is explicitly stale while offline; the
client never resolves schedules or assumes that remotely sold-out items became
available.
A flushed temporary file is promoted with a recoverable previous-file rename so
an interrupted write can only recover a complete prior or next snapshot. A known
version is sent only from a valid same-scope cache; an up-to-date response without
that cache is retried once as a full sync. Versioned order DTO fields are ready,
but legacy cart/order calls do not synthesize snapshot identities.

Phase 12F renders a matching cached menu before its remote sync completes. API
request success or failure—not a network-interface indicator—is the reachability
authority. A failed sync keeps the saved menu available and exposes either an
offline or sync-error status; recovery uses bounded 10/30/90-second retries and
the existing manual Refresh action. Static version changes apply immediately only
to an empty session. An active cart or server draft retains `activeMenu`; the
newest valid remote menu is `pendingMenu` and applies atomically after the cart
clears. An authoritative no-publication response remains distinct from a network
failure: it is deferred only until an active cart completes, then removes the
menu. Local cart preparation is allowed while offline, but order creation,
server-held order changes, payment, final receipts, refunds, and inventory
mutations are not queued or simulated; the backend revalidates the snapshot when
an order is submitted after reconnect.
