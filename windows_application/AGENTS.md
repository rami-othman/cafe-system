# AGENTS.md

Instructions for Codex agents working on Cafe System 618.

## Project Overview

Cafe System 618 is a cafe and restaurant management system. It is currently a
Flutter Windows desktop application. The first implementation focus will be the
POS flow, but general foundation work must stay separate from feature-specific
implementation.

## Platform Priority

Windows desktop is the current priority. Future tablet support may be added
later, so avoid decisions that make responsive layouts difficult.

## Architecture Rules

- Use the approved feature-based architecture under `lib/features`.
- Keep global app setup in `lib/app`.
- Keep reusable foundation code in `lib/core`.
- Keep reusable UI and layouts in `lib/shared`.
- Do not move folders or rename architecture boundaries without explicit user
  approval.

## Feature MVC/Cubit Rules

Each feature must use this structure:

```txt
feature_name/
  models/
  views/
  controllers/
  widgets/
  repositories/
```

- `models`: feature data objects and state-related value types.
- `views`: screen-level widgets for routes.
- `controllers`: Cubits and state files.
- `widgets`: feature-specific UI pieces.
- `repositories`: feature data access abstractions.

## Flutter Coding Rules

- Keep files simple, focused, and compilable.
- Prefer small widgets with clear responsibilities.
- Do not put business logic inside view widgets.
- Use `const` constructors where practical.
- Avoid magic numbers. Use `app_sizes.dart`, `app_spacing.dart`, and theme
  constants.
- Add comments only when they explain non-obvious decisions.

## State-Management Rules

- Use Cubit as the controller/state-management layer.
- Keep Cubit state immutable.
- Use Equatable for state comparison.
- Do not introduce another state-management package without explicit approval.
- Keep feature state inside the owning feature unless it is truly shared app
  state.

## Routing Rules

- Use `go_router`.
- Keep route definitions in `lib/app/app_router.dart`.
- Route to screen-level widgets from feature `views` folders.
- Do not spread route constants through feature widgets.

## Dependency Injection Rules

- Use `get_it` through `lib/core/services/service_locator.dart`.
- Register repositories and Cubits in the service locator.
- Do not create service locators inside features.
- Do not add backend, database, or storage services until the task explicitly
  requires them.

## Theme Rules

- Centralize theme values under `lib/core/theme`.
- Use shared colors, text styles, spacing, radius, and sizes.
- Do not hardcode repeated UI values in feature screens.
- Do not finalize a design palette until the design-system task defines it.

## Desktop-First UI Rules

- Design primary layouts for Windows desktop.
- Use predictable desktop shells, panels, and dense scan-friendly layouts.
- Keep responsive helpers available for future tablet support.
- Do not build mobile-first screens unless explicitly requested.

## Change-Management Rules

- Make focused changes that match the current task.
- Avoid unrelated refactors.
- Avoid over-engineering and premature abstractions.
- Do not add backend integration, database/local storage, or complex business
  logic unless requested.
- Preserve user changes in the working tree.
- Run `flutter analyze` after code or dependency changes.
- Update `PROJECT_STATUS.md` after each task.
- Summarize changed files and recommend the next step in the final response.
