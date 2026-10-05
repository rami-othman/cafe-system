# Batch 11 — Review & Publish Design Reference

Status: APPROVED as the implementation reference for Batch 11.

## Authority

- The real Flutter Windows application shell is authoritative.
- These Claude references are authoritative for Review & Publish content, workflow, hierarchy, density, and state presentation inside the existing shell.
- Do **not** implement the dark-brown prototype state-switcher bar shown at the top of the screenshots/HTML.
- Do **not** replace or redesign the existing Cafe System 618 Windows navigation shell to match the prototype shell.

## Domain rules that must remain true

- Publish scope is exact Branch + Sales Channel.
- Multiple assigned Menus may be published in one scope.
- Automatic Menu order follows exact-scope Assignment order.
- Validation Errors block Publish; Warnings do not.
- `NO_ASSIGNED_MENU` is a scope-level blocking readiness issue.
- Preview values for pricing, availability, sellability, visibility, and schedules are backend-authoritative.
- Preview hidden/unavailable toggles affect Preview only, not Publish payload semantics.
- Publish creates an immutable Menu version when content changed; no-change is a successful state with no new version.
- Do not claim Publish immediately pushes content live to POS; current POS snapshot sync is not implemented yet.
- Version history is manager-facing; do not surface checksum, publication IDs, or raw snapshot JSON as primary UX.
- Compare is category/ID-level from the current backend. Do not invent unsupported old-value → new-value prose.
- Restore creates a **new current version** from the historical snapshot. It does not reactivate or mutate the old version and does not delete newer history.

## Implementation notes

- Use canonical ARB localization and existing RTL conventions.
- History/detail/compare should load on demand; do not preload all version data with the Readiness view.
- Validation issues must scale to many rows and should remain grouped/filterable.
- Only offer precise navigation where the backend response provides enough context.
- In the no-menu state, route the CTA to the existing Assignments & Schedules workspace. Use the production localized label for that route (not a new "customizations" module).
- Error states should be local to the affected panel when possible.

## Included reference states

1. readiness_ready.png
2. readiness_warnings_only.png
3. readiness_errors_warnings.png
4. readiness_no_menus.png
5. readiness_loading.png
6. readiness_error.png
7. preview_normal.png
8. preview_error.png
9. publish_confirmation.png
10. publish_blocked.png
11. publish_success.png
12. publish_no_changes.png
13. publish_revalidation_failed.png
14. versions_history.png
15. versions_empty.png
16. versions_error.png
17. version_detail.png
18. compare_versions.png
19. compare_truncated.png
20. compare_no_differences.png
21. restore_confirmation.png
22. restore_success.png
23. claude_reference.html

`restore_success.png` demonstrates successful restore messaging together with a separate history-refresh failure. Treat those as independent local states rather than coupling restore success to history-load success.
