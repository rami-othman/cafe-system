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

UX-G0 is **COMPLETE**. Batch 7-P, Navigation & Flow Stabilization, and Batch 7.1
are **COMPLETE**. Batch 7 — Recipes & Materials is **COMPLETE after closure
verification**. The Product Workspace remains the canonical Product parent;
Recipe and Material Effect child routes retain Product/Variant/Option IDs and do
not use display-name URL parameters. Batch 8 and Phase 4K are **NOT STARTED**.
POS Published Snapshot Sync and Inventory runtime remain deferred.

The supplied pre-closure baseline was 337 Flutter tests with zero failures. The
final closure verification is 343 Flutter tests with zero failures, alongside
118 backend tests with 1,720 assertions. The current Codex-shell
`flutter gen-l10n` command timed out without output; prior local Windows
generation passed.

Verification gate (run each command independently):

```sh
flutter pub get
flutter gen-l10n
dart format .
flutter analyze
flutter test --reporter compact
```
