# Codex Workflow

Codex agents should follow this workflow when working on Cafe System 618.

## 1. Read Project Instructions

Before making changes, read:

- `AGENTS.md`
- `PROJECT_STATUS.md`

Use those files to understand the current phase, constraints, and next step.

## 2. Keep Changes Focused

Make only the changes required by the current task. Avoid large unrelated
refactors, folder moves, dependency changes, or feature work unless explicitly
requested.

## 3. Preserve Architecture

Follow the feature-based MVC/Cubit architecture:

```txt
feature_name/
  models/
  views/
  controllers/
  widgets/
  repositories/
```

Keep Cubits in `controllers`, feature screens in `views`, and reusable global
UI in `shared`.

## 4. Verify Work

Run the analyzer after changes:

```bash
flutter analyze
```

Fix analyzer errors before reporting completion. If tests are changed or added,
run the relevant tests as well.

## 5. Update Project Status

Update `PROJECT_STATUS.md` after each task. Keep the update short and include:

- completed work
- current in-progress item, if any
- next recommended step
- recent changes log entry

## 6. Final Response

Summarize:

- files created or changed
- verification commands run
- any unresolved issues
- next recommended step
