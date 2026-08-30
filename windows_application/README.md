# Cafe System 618 Windows Application

Flutter desktop client for Cafe System 618. The authoritative Menu Management
status and contracts are in [PROJECT_STATUS.md](PROJECT_STATUS.md); the companion
backend/domain record is [Menu Management Architecture](../docs/MENU_MANAGEMENT_ARCHITECTURE.md).

Menu Management currently covers catalog and variants, Modifier Library and product
assignments, recipes/material adjustments, menu composition, assignments/schedules,
review/publish, and version history. It keeps lifecycle, scheduled availability,
operational availability, and menu publication as separate concerns.

Operational temporary-unavailability mutations submit an offset-less Branch-local
timestamp. Flutter must not send `DateTime.toIso8601String()` for that field; the
backend Branch timezone is authoritative.

UX-G0, Batch 7-P, Navigation & Flow Stabilization, Batch 7.1, and Batches 8–11
are complete. The Product Workspace remains the canonical Product parent; Recipe
and Material Effect child routes retain Product/Variant/Option IDs and do not use
display-name URL parameters. Batch 12 is complete: production POS uses the
Published Runtime Contract v1 through `/pos/menu-sync`, a scoped cache, Published
POS UI, a version-bound cart, and snapshot-aware Orders. Offline menu and cart
preparation are supported; true offline transaction or payment processing is not.
Legacy Menu APIs and the no-version order path are deprecated compatibility
interfaces and are not used by the production Windows POS.

Final manual closure verification on the current worktree passed: `flutter
gen-l10n`, `flutter analyze`, `flutter test` (487 passed), and `flutter build
windows`. The built Windows executable was launched successfully and rendered the
Published POS screen.

Verification gate (run each command independently):

```sh
flutter pub get
flutter gen-l10n
dart format .
flutter analyze
flutter test --reporter compact
```
