# Cafe System 618

Cafe System 618 is a cafe and restaurant management system built as a Flutter
application. The first product focus is the point-of-sale workflow, but this
repository is currently in the general project foundation phase.

## Platform Focus

The current priority is Windows desktop. Future tablet support may be added
later, so layout and architecture decisions should avoid blocking responsive
adaptation.

## Tech Stack

- Flutter
- Dart
- flutter_bloc / Cubit
- go_router
- get_it
- equatable
- intl

## Architecture Summary

The app uses a feature-based architecture under `lib/features`. Each feature
uses an MVC-style internal structure:

```txt
feature_name/
  models/
  views/
  controllers/
  widgets/
  repositories/
```

Cubit is the controller and state-management layer. Shared application setup
lives in `lib/app`, reusable foundation code lives in `lib/core`, and reusable
UI/layout primitives live in `lib/shared`.

## Run the App

```bash
flutter pub get
flutter run -d windows
```

## Analyze the App

```bash
flutter analyze
```

## Development Status

Current phase: Phase 1 — Project Foundation.

Next step: build the shared theme/design system before implementing feature
screens.
