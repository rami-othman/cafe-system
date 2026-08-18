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

UX-G0-A through UX-G0-D are complete; UX-G0-E awaits only a locally rerun
`flutter gen-l10n` after the Codex environment timed out. The next approved work
is UX Batch 7 — Recipes & Materials; it has not started. Phase 4K cleanup, POS
Published Snapshot Sync, and Inventory runtime are deferred.

Verification gate (run each command independently):

```sh
flutter pub get
flutter gen-l10n
dart format .
flutter analyze
flutter test --reporter compact
```
