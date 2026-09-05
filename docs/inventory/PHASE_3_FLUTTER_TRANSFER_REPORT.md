# Phase 3 — Flutter Warehouse Transfer Workflow

## Summary

The routed transfer UI is `TransfersScreen` at `/inventory/transfers` and `/inventory/transfers/:id`. This phase connected its list to server-side pagination/KPIs, introduced typed canonical status mapping, made creation include real source-filtered item lines, added stable command idempotency keys, and removed tenant-header use from the API client.

The inventory backend regression remains green: 31 tests and 338 assertions.

**Update:** The Flutter/Dart process hang blocking this phase has been resolved. A stale `flutter run -d windows` process tree (PID 16700 and its children, started earlier the same day against this exact project path) was left running from a prior session and held the toolchain busy. It was identified via `Get-CimInstance Win32_Process` (command line confirmed it referenced `C:\zaher\cafe_618\cafe-system\windows_application`) and terminated with `taskkill /T /F`. After that, `flutter --version`, `flutter pub get`, `flutter analyze`, and `flutter test` all ran to completion and returned promptly (analyze: ~3–80s, tests: ~7s) with no further hangs.

`flutter analyze` then surfaced 4 real compile errors, all inside Phase 3 files, which have been fixed:

1. `lib/core/network/dio_api_client.dart:29,31` — `Headers.authorizationHeader` does not exist on dio 5.9.2's `Headers` class (it only defines `acceptHeader`, `contentEncodingHeader`, `contentLengthHeader`, `contentTypeHeader`, `wwwAuthenticateHeader`). Fixed by using the literal header key `'authorization'`.
2. `lib/features/inventory/transfers/views/transfers_screen.dart:222` — the create-transfer dialog's `..._lines.map((line) => ListTile(...))` spread was missing one closing parenthesis for the `.map(` call itself, and the `AlertDialog`'s `content:`/`actions:` closing sequence had one stray `]` in place of a `)`. Both were genuine syntax bugs (not analyzer noise) that made the file fail to parse. Fixed by balancing the parentheses/brackets; verified with a custom Dart-string-interpolation-aware bracket scanner before and after.
3. `lib/features/inventory/transfers/views/transfers_screen.dart:222` (two sites) — `InventoryItem` has no `displayName` getter (the model exposes `name`, populated from the API's `displayName` JSON field in `InventoryItem.fromJson`). Fixed by using `.name`.

While in the same already-open file, the three `DropdownButtonFormField<int>(value: ...)` deprecation infos (Flutter's `value` param was deprecated in favor of `initialValue` after 3.33) were also fixed, since the file was already being touched for the errors above. No other file was modified — the legacy unrouted screens (`inventory_workflow_screens.dart`, `inventory_screens.dart`) and unrelated files were left untouched per scope.

## Old transfer frontend architecture

| Implementation | Routing | State/API behavior | Status |
| --- | --- | --- | --- |
| `transfers/views/transfers_screen.dart` / `TransfersScreen` | Active | `InventoryCubit` -> `InventoryRepository` | Canonical routed screen |
| `views/inventory_workflow_screens.dart` / `InventoryTransfersWorkspaceScreen` | None | Older overlapping workflow | Unrouted legacy candidate for removal |
| `views/inventory_screens.dart` / `InventoryTransfersScreen` | None | Legacy placeholder/list presentation | Unrouted legacy candidate for removal |

No route points at either legacy screen. They were not deleted in this phase because they remain in broad mixed-purpose source files and deletion would be a higher-risk unrelated refactor. They must not be re-routed.

## New canonical transfer architecture

```text
TransfersScreen
  -> InventoryCubit.loadTransfers / createTransfer / transferAction / receiveTransfer
  -> InventoryRepository.transfersPage / transfer APIs
  -> DioApiClient (Bearer token only)
  -> Laravel WarehouseTransferController
  -> WarehouseTransferService / TransferTransitLedger
```

## Screens completed

- Server-backed transfer list with title, KPI cards, search debounce, canonical status filter, loading/empty/error/retry behavior, and page navigation.
- Create-transfer dialog: source, distinct destination, real source-assigned item selection, unit, positive quantity, multiple lines, remove line, optional notes, and create idempotency key.
- Details workspace: real line quantities, lifecycle audit timeline, status badge, and backend-provided action availability.
- Receive dialog: real outstanding lines only, full or partial quantity entry, client-side positive/upper-bound checks, and required discrepancy reason for partial receipt.

## Status mapping

| Backend | Arabic UI label |
| --- | --- |
| `draft` | مسودة |
| `submitted` | بانتظار الاعتماد |
| `approved` | معتمد / جاهز للإرسال |
| `rejected` | مرفوض |
| `cancelled` | ملغي |
| `dispatched` | قيد النقل |
| `partially_received` | مستلم جزئياً / قيد النقل |
| `received` | مستلم |
| `closed_shortage` | مغلق بعجز |

`TransferStatus` is the typed Dart mapping. Raw status values are retained only at the JSON boundary for compatibility with the existing shared model.

## Permission/action matrix

The controller now derives `canEdit`, `canSubmit`, `canApprove`, `canReject`, `canDispatch`, `canReceive`, `canCloseShortage`, and `canCancel` from both status and `InventoryAccess` permissions. Flutter shows actions only when these response flags are true; Laravel middleware remains the security boundary.

| Status | Owner | Manager | Cashier |
| --- | --- | --- |
| Draft | edit, submit, cancel | edit, submit, cancel | read-only |
| Submitted | approve, reject, cancel | approve, reject, cancel | read-only |
| Approved | dispatch, cancel | dispatch, cancel | read-only |
| Dispatched / partial | receive, close shortage | receive, close shortage | read-only |
| Terminal | read-only | read-only | read-only |

## Create workflow

The create dialog calls `loadTransferItems(sourceWarehouseId)`, which calls the real `inventory/items?warehouseId=...` endpoint. Only items assigned to the chosen source are offered. It cannot submit with no lines, an identical warehouse, duplicate item line, or non-positive quantity. Laravel remains authoritative for stock availability and units.

## Approval, dispatch, receiving, and shortage workflows

- Submit, approve, dispatch, reject, cancellation, close-shortage, and receipt use the existing canonical endpoints.
- Every command receives an idempotency UUID generated once per transfer/action operation. The stateful screen keeps the same key for a retry after a response/network loss; it is not regenerated until a completed operation leaves the workspace.
- Rejection, cancellation, and shortage closure require a non-empty reason dialog.
- Receiving sends the backend's required line payload and reloads transfer/list state through the Cubit after success.

## Authentication integration

`DioApiClient` now removes `X-Tenant-Id` unconditionally and sends only `Authorization: Bearer <token>` when a token is supplied. `API_TOKEN` is a deployment/runtime dart define, and `setBearerToken()` is available for the authenticated application shell after `/auth/login`. Tenant and actor are never sent from Flutter headers.

## Search/filter/pagination

`WarehouseTransferController::index` now provides page metadata and server KPI metadata:

- `search`, `status`, `sourceWarehouseId`, `destinationWarehouseId`, `page`, `perPage`
- `currentPage`, `lastPage`, `perPage`, `total`, `kpis`

`InventoryRepository.transfersPage()` parses this contract. KPI cards use `meta.kpis`, not visible-page rows. The screen debounces search by 350ms and resets page to 1 for filter/search requests.

## API/resource changes

- Added `InventoryAccess::allows()` for response-level action availability; it does not replace endpoint authorization.
- Paged `/inventory/transfers` and added server-provided KPI metadata.
- Transfer resource action flags now include the authenticated actor's real permissions.
- No transfer accounting/state-machine behavior was changed.

## Tests

| Command | Result | Notes |
| --- | --- | --- |
| `docker compose exec -T backend php artisan test tests/Feature/InventoryCenterApiTest.php tests/Feature/InventorySecurityAndSeederTest.php` | 31 passed, 0 failed | 338 assertions |
| `flutter --version` | OK | Flutter 3.47.0 stable, Dart 3.13.0 |
| `flutter pub get` | OK | Dependencies resolved |
| `flutter analyze` | 0 errors; exit code 1 | All 4 real errors fixed (see Summary). Remaining 27 issues are all `info`-severity lints (deprecated-member/BuildContext-across-async/curly-braces style notices), 24 of them in the legacy unrouted `inventory_workflow_screens.dart`, which is out of scope for this phase and must not be re-routed or redesigned. `flutter analyze` reports non-zero exit whenever any info exists, so exit code is not 0, but there are no compile errors and none of the remaining issues are in the canonical routed transfer files. |
| `flutter test test/features/inventory/transfers` | 3 passed, 0 failed | `transfer_status_test.dart`, `transfer_view_state_test.dart` |
| `flutter test test/features/inventory` | 16 passed, 0 failed | Full inventory suite, no regressions |

`test/features/inventory/transfers/transfer_status_test.dart` (typed status + page/KPI parsing) and `transfer_view_state_test.dart` (list search/status filtering) both execute and pass now that the toolchain hang is resolved.

## Manual end-to-end result

Not executed through the live desktop UI in this session (no authenticated desktop session was available). Backend proof remains the isolated transfer lifecycle tests: dispatch/partial receipt/shortage and multiple receipt reconciliation are covered by `InventoryCenterApiTest`. Flutter-side proof is now the passing `flutter analyze` (0 errors) and passing widget/unit tests for the transfer feature and the full inventory suite.

## Remaining issues

1. Draft-details editing (changing existing source/destination/lines after initial creation) has repository/Cubit/API support but still needs its canonical edit dialog in `TransfersScreen`.
2. Source/destination selectors exist for creation; list-level source/destination filters still need visual selector controls even though repository/API support exists.
3. Confirmation copy for dispatch/receive should be made explicit before a client demo.
4. ~~Flutter analyzer and transfer tests must be rerun after resolving the hanging Dart processes.~~ Done: analyzer and transfer/inventory tests now run and pass with 0 compile errors.
5. Remove the two unrouted legacy transfer screen classes only after the focused Flutter checks are green (now true — this remains a deliberately separate follow-up, not done in this pass to avoid scope creep).

## Final verdict

1. **Can a user create a transfer with actual lines?** Yes, through the canonical create dialog and real source item endpoint.
2. **Can drafts be edited?** Partially; the API/Cubit support updates, but the canonical edit dialog remains outstanding.
3. **Is submit connected to backend?** Yes.
4. **Is approval connected?** Yes.
5. **Is dispatch connected?** Yes.
6. **Is full receive connected?** Yes.
7. **Is partial receive connected?** Yes, with reason validation.
8. **Is close-shortage connected?** Yes, with a required reason.
9. **Are permissions respected in UI and backend?** Yes for response action flags and backend middleware.
10. **Are idempotency keys handled correctly?** Yes for the active screen lifetime/retry path.
11. **Are search/filter/pagination server-backed?** Search/status/pagination are; list-level warehouse filter controls remain outstanding.
12. **Are all values real API data?** Yes; no transfer mock data was added.
13. **Are legacy transfer screens consolidated?** Active routing is consolidated, but source cleanup remains outstanding.
14. **Is Flutter analyze green?** No compile errors remain (fixed the auth-header, two `displayName`, and syntax-bracket bugs found in this pass). Exit code is still non-zero because of pre-existing `info`-level lints, almost entirely in the legacy unrouted `inventory_workflow_screens.dart`, which is intentionally out of scope for this phase.
15. **Is the transfer workflow ready for client demo data?** Not yet; the draft-edit dialog, list-level warehouse filter controls, and legacy screen removal from item 1–2 above remain outstanding, and no live desktop UI walkthrough has been performed.
