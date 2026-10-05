# Architecture Decision Log

This file records project-level architecture decisions. Add concise entries
when a decision affects future implementation.

## Decisions

### 2026-06-09: Flutter for Windows Desktop

Flutter is used for the Windows desktop application.

### 2026-06-09: Desktop-First Product Direction

The app is desktop-first, with possible future tablet support.

### 2026-06-09: Feature-Based Architecture

The project uses feature-based architecture under `lib/features`.

### 2026-06-09: MVC-Style Feature Structure

Each feature uses an MVC-style internal structure with `models`, `views`,
`controllers`, `widgets`, and `repositories`.

### 2026-06-09: Cubit Controllers

Cubit is used as the controller/state-management layer.

### 2026-06-09: Centralized Theme Values

Theme values should be centralized under `lib/core/theme`.

### 2026-06-09: Feature Logic Ownership

Feature-specific logic should stay inside its feature.

### 2026-06-09: Shared UI Location

Shared reusable UI should go inside `lib/shared`.
