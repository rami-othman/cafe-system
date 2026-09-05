# Inventory Technical and Functional Audit Report

**Audit mode:** read-only code tracing, safe local API reads, and isolated test execution.
**Audit date:** 2026-08-29
**Scope:** the Laravel and Flutter inventory module, with particular attention to warehouse transfers. No production application behaviour was changed during this audit.

## 1. Executive Summary

**Inventory completeness:** approximately **55%**.
**Transfer completeness:** approximately **45%**.
**Backend:** A substantial transfer/state/accounting implementation exists and uses database transactions and row locks. It is not production-safe because the v1 API is publicly reachable, tenant/user identity can be supplied by headers, lifecycle roles are not authorized, and test setup is broken.
**Flutter:** The routed transfer screen calls the real API, but it cannot add or edit transfer lines. It can therefore create an empty draft which it cannot submit. There are also two obsolete/conflicting transfer workspaces.
**Database:** The normal code path maintains a `(tenant, warehouse, item)` balance and immutable stock-movement rows. Transfer shortage closure has no balancing ledger entry; several cross-tenant relationships are application-enforced rather than database-enforced.
**Tests:** Relevant Laravel tests did not run: 23 Inventory Center tests and 5 Foundation tests failed during seeding with **0 assertions**. Flutter analysis did not return a result in the provided execution environment.

### Production conclusion

Inventory and warehouse transfers are **not safe for production**. The immediate blocker is unauthenticated/tenant-header-controlled API access (P0). The next blockers are the missing active Flutter line editor, missing backend lifecycle authorization, incomplete shortage audit trail, and a broken database seeder that prevents the intended automated test suite from executing.

## 2. Current Architecture

### Actual transfer call path

```text
GoRouter (/inventory/transfers, /inventory/transfers/:id)
  -> TransfersScreen
  -> InventoryCubit
  -> InventoryRepository
  -> DioApiClient (default http://localhost:8000/api/v1)
  -> GET/POST /v1/inventory/transfers and action endpoints
  -> WarehouseTransferController
  -> WarehouseTransferService
  -> InventoryPostingService (dispatch / receive only)
  -> warehouse_transfers, warehouse_transfer_lines,
     warehouse_transfer_operations, warehouse_transfer_receipts,
     warehouse_transfer_receipt_lines, stock_balances, stock_movements
```

| Layer | Actual implementation | Notes |
|---|---|---|
| Active Flutter route | `windows_application/lib/app/app_router.dart` -> `features/inventory/transfers/views/transfers_screen.dart` | This is the production-routed transfer UI. |
| State | `features/inventory/controllers/inventory_cubit.dart` / `InventoryState` | One large Cubit owns dashboard, items, warehouses, balances, movements, counts, bar checks, and transfers. |
| Flutter data | `features/inventory/repositories/inventory_repository.dart`, `core/network/dio_api_client.dart` | Direct JSON maps; transfer statuses are raw strings, not a typed enum. |
| Transfer API | `backend/routes/api.php`, `WarehouseTransferController` | Index, create, show, update, receive, and generic action routes exist. |
| Domain | `backend/app/Services/WarehouseTransferService.php` | Owns state changes, reservations, receipts, transfer operations. |
| Posting | `backend/app/Services/InventoryPostingService.php` | Owns balances and stock-movement ledger insertion for transfer out/in and other stock events. |
| Tenant/actor | `TenantContext`, `FinancialActor`, `AuthenticateApiToken` | Authentication middleware is defined but not applied to the v1 route group. |

### Other inventory architecture found

| Module | Flutter / API / domain evidence | State |
|---|---|---|
| Overview/dashboard | Inventory Cubit, dashboard endpoints/resources | PARTIAL: backed by API, but audit did not establish all dashboard counters under test. |
| Items/materials | `InventoryItemController`, `InventoryItemService`, item/warehouse assignment table | WORKING PATH PRESENT; authorization is not safe. |
| Warehouses/locations | `WarehouseController`, `WarehouseRequest`, financial foundation seeder | WORKING PATH PRESENT; authorization is not safe. |
| Stock balances | `InventoryBalanceController`, `stock_balances`, `InventoryPostingService` | PARTIAL: normal posting has protection; no independent reconciliation test executed. |
| Stock movements | `StockMovementController`, `InventoryPostingService`, `stock_movements` | PARTIAL: append-only API path; shortage closure is absent from ledger. |
| Transfers | Controller/service/Flutter screens | PARTIAL / UNSAFE; see transfer report. |
| Stock counts | `StockCountController`, `StockCountService`, count/line tables | PARTIAL; default seed crashes at a stale service call. |
| Bar checks/templates | `BarCheckController`, templates and Flutter views | PARTIAL; supplied runtime screenshot showed a `shortage_reason` property error, indicating migration/code alignment must be verified. |
| Units/conversions | conversion request/service/resolver | WORKING PATH PRESENT; no end-to-end test completed. |
| Lots/batches, suppliers, purchases/GRN, procurement | no inventory tables/routes/services found | NOT IMPLEMENTED (item flags `trackExpiry`/`trackBatch` exist without a lot/batch subsystem). |
| Costing | latest/unit cost and weighted-average calculations in `InventoryPostingService` | PARTIAL; no isolated cost reconciliation test executed. |

### Tenant, branch and permission design actually present

`TenantContext::id()` uses a request tenant attribute when set, otherwise accepts `X-Tenant-Id`, otherwise selects the first tenant. `FinancialActor::id()` accepts the authenticated actor when one exists, otherwise `X-User-Id`. `FinancialActor::assertBranchAccess()` returns without a branch check when there is no actor. `AuthenticateApiToken` exists but `routes/api.php` does not apply its `api.token` alias to `/v1` or inventory routes. Form requests such as `WarehouseRequest`, `InventoryItemRequest`, `StockMovementRequest`, `StockCountRequest`, and `StockCountLineRequest` all return `true` from `authorize()`.

This is not backend authorization. It is a major SaaS isolation failure.

## 3. Current Transfer Workflow

### Implemented statuses

```text
draft --submit--> submitted --approve--> approved --dispatch--> dispatched
  |                   |                  |                       |
  +--cancel-----------+--reject          +--cancel                +--receive (full)--> received
                                                                    |
                                                                    +--receive (partial)--> partially_received
                                                                                                  |
                                                                                                  +--receive--> received
                                                                                                  +--close-shortage--> closed_shortage
```

`cancel` is permitted only in `draft`, `submitted`, or `approved`. `reject` is only permitted in `submitted`. There is no literal backend `pending_approval`, `in_transit`, or `ready` state. The Flutter UI presents `submitted` as pending approval and presents `dispatched`/`partially_received` as in transit.

| From | Action | To | Who can actually do it | Stock / ledger effect | Database effect |
|---|---|---|---|---|---|
| draft | create/update lines | draft | Any caller able to reach API; no enforced role | none | transfer and lines inserted/replaced. Empty draft is allowed. |
| draft | submit | submitted | No enforced role | none | submitted actor/time set. |
| submitted | approve | approved | No enforced role | source quantity reserved, no ledger movement | `reserved_quantity` increased on balance; approval fields set. |
| submitted | reject | rejected | No enforced role | none | rejection fields set. |
| approved | dispatch | dispatched | No enforced role | source balance reduced; `transfer_out` movement per line | outbound movement IDs/dispatch fields; operation key recorded. |
| dispatched | receive all remaining | received | No enforced role | destination increased; `transfer_in` movement per receipt line | receipt + receipt lines; received fields/status. |
| dispatched/partial | receive less than remaining | partially_received | No enforced role | destination increased for received amount | receipt line(s), line receipts/status. Discrepancy reason required for partial. |
| dispatched/partial | close-shortage | closed_shortage | No enforced role | **no shortage/loss stock movement** | remaining becomes shortage-closed and transfer status changes. |
| draft/submitted | cancel | cancelled | No enforced role | none | status changes only. |
| approved | cancel | cancelled | No enforced role | reservation released, no ledger movement | balance reserved quantity reduced; status changes. |

Rows are locked during service actions. Dispatch has an operation idempotency record and receipt uses a unique receipt key. Submit, approve, reject, and cancel are state-protected but are not idempotent replay operations: a retry after a successful response loss receives a 422 invalid-state response.

## 4. Expected vs Actual

| Area | Expected | Actual | Status | Problem |
|---|---|---|---|---|
| API access | authenticated actor and server-derived tenant | public v1 group; tenant/user headers and first-tenant fallback | FAIL | P0 tenant data exposure and mutation risk. |
| Create transfer | source/destination and editable lines | active UI creates locations only; backend accepts empty draft | FAIL | user cannot make a usable transfer in routed UI. |
| State machine | controlled transitions and clear status mapping | service controls transitions; frontend aliases statuses; no role controls | PARTIAL | safe sequencing but unsafe authorization and semantic mismatch. |
| Dispatch accounting | one outbound movement, once only | transaction, locks and deterministic movement key exist | PARTIAL | static trace good; automated execution blocked. |
| Receipt accounting | receipt once, all quantities traceable | full/partial receipt exists; concurrent duplicate receipt key may surface DB error | PARTIAL | insufficient race test/error mapping. |
| Shortage accounting | immutable financial/inventory explanation | status/line fields only | FAIL | no ledger movement/reversal documenting the missing stock. |
| Cancellation | status-specific, auditable reversal | approved reservation released; no cancellation actor/time/reason fields | PARTIAL | audit history incomplete. |
| Search/filter/pagination | server-backed query and scalable list | backend supports filters; active UI loads all then filters locally, ignores KPIs/meta | PARTIAL | stale/incomplete list semantics and no pagination. |
| Tenant/branch isolation | backend-enforced | can be bypassed with no actor and headers | FAIL | IDOR/cross-branch risk. |
| Testability | isolated suite passes | seed crashes before assertions | FAIL | no regression confidence. |

## 5. Test Matrix

`PASS (code)` means the path was traced to explicit checks but could not be runtime-verified because the isolated suite is blocked. It must not be interpreted as a production sign-off.

| Scenario | Result | Evidence | Notes |
|---|---|---|---|
| 1. Create valid draft | PARTIAL | `WarehouseTransferService::create` | Backend supports it, but active UI cannot add lines. |
| 2. Same source/destination | PASS (code) | `assertLocations` | Service rejects equal IDs. |
| 3. Zero quantity | PASS (code) | line/receipt decimal validation and service quantity checks | Rejected. |
| 4. Negative quantity | PASS (code) | regex and decimal helper | Rejected. |
| 5. Quantity above available | PASS (code) | `adjustReservation` / posting checks | Approval reservation is capped by available stock. |
| 6. Submit draft | PARTIAL | `submit` action | Requires lines; runtime suite blocked. |
| 7. Submit twice | PARTIAL | state guard | No duplicate stock, but retry is 422 rather than idempotent replay. |
| 8. Approve | PARTIAL | `approve` action | Reserves source quantity under lock. |
| 9. Approve twice | PARTIAL | state guard | Safe from duplicate reservation via state; not retry-idempotent. |
| 10. Dispatch | PARTIAL | `dispatch`, `InventoryPostingService` | Outbound movement is keyed per transfer/line. |
| 11. Dispatch twice | PASS (code) | operation table + locked status | Same operation key returns without a duplicate movement. |
| 12. Receive | PARTIAL | `receive` + receipt records | Full and partial receipt code exists. |
| 13. Receive twice | PARTIAL | receipt unique key and status | Logical duplicate prevented; concurrent same key may return uncaught unique error. |
| 14. Cancel draft | PASS (code) | `cancel` action | No stock effect. |
| 15. Cancel pending/submitted | PASS (code) | `cancel` action | No stock effect. |
| 16. Cancel after dispatch | PASS (code) | allowed-status condition | Forbidden. |
| 17. Edit after dispatch | PASS (code) | `update` only permits draft | Forbidden. |
| 18. Unauthorized action | FAIL | public route group, permissive requests | No backend role authorization. |
| 19. Cross-tenant access | FAIL | unauthenticated live GET returned 200; `X-Tenant-Id` trust | IDOR risk. |
| 20. Cross-branch access | FAIL | null actor bypass in `assertBranchAccess` | Server does not require an actor. |
| 21. Disabled/deleted item | PASS (code) | transfer line validation | Active, non-deleted tenant item required. |
| 22. Disabled/deleted location | PASS (code) | location validation | Active, non-legacy location required. |
| 23. Concurrent dispatch/receive | PARTIAL | transactions/`lockForUpdate`, no runnable test | Design helps dispatch; receipt duplicate DB error behaviour needs a concurrent test. |
| 24. API validation failure | PASS (code) | controller/form requests/service exceptions | 422 path present; no full HTTP assertion ran. |
| 25. Flutter network/API error | PARTIAL | `DioApiClient` maps connection failures | Screenshot confirms unreachable-backend state; analyzer/widget test did not run. |

### Commands executed and blockers

| Command | Result |
|---|---|
| `docker compose exec -T backend php artisan test --filter=InventoryCenterApiTest` | **FAIL/BLOCKED:** 23 failed, 0 assertions. `InventoryCenterSeeder.php:63` calls `StockCountService::upsertLine()` with 3 arguments; signature requires 4. |
| `docker compose exec -T backend php artisan test --filter=FinancialInventoryFoundationApiTest --stop-on-failure` | **FAIL/BLOCKED:** 5 failed, 0 assertions, same seed error. |
| `flutter analyze` | **BLOCKED BY ENVIRONMENT/RUNNER:** command produced no output/exit code after the available runner interval. Reattempts with `flutter --version` and `cmd /c "flutter analyze & echo EXITCODE:%ERRORLEVEL%"` also returned no usable result. |
| read-only `GET http://127.0.0.1:8000/api/v1/inventory/transfers` with no authorization | **FAIL:** HTTP 200 with transfer data. |
| `php artisan inventory:reconcile` against local development data | **PASS (local data only):** checked 37 inventory scopes, found 0 differences. This does not test transfer lifecycle or authorization. |

## 6. Critical Bugs

### INV-P0-001 — Public inventory API and tenant/header impersonation

- **Severity:** P0 Critical
- **Files:** `backend/routes/api.php`; `backend/app/Support/TenantContext.php`; `backend/app/Support/FinancialActor.php`; `backend/app/Http/Middleware/AuthenticateApiToken.php`
- **Method/class:** v1 route group, `TenantContext::id`, `FinancialActor::id`, `FinancialActor::assertBranchAccess`
- **Reproduction:** send an unauthenticated GET to `/api/v1/inventory/transfers`; the local running backend returned HTTP 200 and transfer records. Change `X-Tenant-Id` to select scope. Calls with no actor skip branch access.
- **Current behaviour:** API identity is not enforced; request headers/fallback determine tenant/actor.
- **Expected behaviour:** every inventory endpoint must require authenticated identity and derive tenant and permitted branches server-side.
- **Business impact:** tenant data disclosure, cross-tenant stock manipulation, IDOR, audit attribution failure.
- **Suggested fix direction:** apply auth middleware to v1 inventory routes, remove header/first-tenant fallback outside tightly controlled tests, authorize every action through policies/permissions and server-side branch assignments.

### INV-P1-001 — Routed Flutter transfer UI cannot create transfer lines

- **Severity:** P1 High
- **Files:** `windows_application/lib/features/inventory/transfers/views/transfers_screen.dart`; `.../controllers/inventory_cubit.dart`; `backend/app/Services/WarehouseTransferService.php`
- **Method/class:** `TransfersScreen`, `_LocationDialog`, `WarehouseTransferService::create`
- **Reproduction:** open `/inventory/transfers`, choose locations, create; the request contains no lines. The backend accepts a draft, but submit rejects it for having no lines. The active details screen has no add/edit/remove-line controls.
- **Current behaviour:** unusable empty drafts are created.
- **Expected behaviour:** a draft must be line-editable before submission, or creation must include valid lines.
- **Business impact:** warehouse transfers cannot be completed from the live Flutter route.
- **Suggested fix direction:** consolidate on one routed transfer workspace and define a complete draft-line flow without changing accounting logic.

### INV-P1-002 — No backend authorization for inventory lifecycle actions

- **Severity:** P1 High
- **Files:** all inventory Form Requests listed in section 2; `WarehouseTransferController.php`; `WarehouseTransferService.php`
- **Method/class:** `authorize()` methods; controller action/receive; actor helper
- **Reproduction:** call action endpoints without an authenticated actor; routes and requests do not reject it and actor-null skips branch checks.
- **Current behaviour:** creation, approval, dispatch, receipt, cancellation, counts, and manual movements rely on UI hiding/status flags rather than enforced roles.
- **Expected behaviour:** backend permissions for view/create/edit/submit/approve/dispatch/receive/cancel/count/adjust.
- **Business impact:** unauthorized stock changes and unreliable audit attribution.
- **Suggested fix direction:** introduce a single authorization policy/ability map and enforce it in routes/controllers/services.

### INV-P1-003 — Automated inventory suites are blocked by broken default seeding

- **Severity:** P1 High
- **Files:** `backend/database/seeders/InventoryCenterSeeder.php:63`; `backend/app/Services/StockCountService.php:87`
- **Method/class:** `InventoryCenterSeeder`, `StockCountService::upsertLine`
- **Reproduction:** run either executed PHPUnit command in section 5.
- **Current behaviour:** seeder supplies three arguments to a four-argument service; relevant test classes fail before their first assertion.
- **Expected behaviour:** tests seed successfully and exercise inventory conditions.
- **Business impact:** broken fresh demo seeding and no regression protection.
- **Suggested fix direction:** align the seeder with the service contract and add a seed smoke test.

### INV-P1-004 — Closed shortages are not recorded in inventory movement ledger

- **Severity:** P1 High
- **Files:** `backend/app/Services/WarehouseTransferService.php`; `backend/app/Services/InventoryPostingService.php`
- **Method/class:** `WarehouseTransferService::closeShortage`
- **Reproduction:** dispatch a line, partially receive it, then close shortage. Inspect `stock_movements`.
- **Current behaviour:** source has a `transfer_out` and destination has only receipt `transfer_in` rows; remaining amount is merely flagged on a transfer line.
- **Expected behaviour:** shortage/loss/reconciliation event with transfer/line/reference/reason and an auditable stock/accounting effect according to the selected business policy.
- **Business impact:** ledger totals cannot independently explain the lost quantity.
- **Suggested fix direction:** decide ownership of in-transit stock and post an immutable shortage/reconciliation movement or explicit in-transit ledger entries.

### INV-P1-005 — Lifecycle retry/idempotency is incomplete and receipt race error handling is uncertain

- **Severity:** P1 High
- **Files:** `backend/app/Services/WarehouseTransferService.php`; transfer receipt/operation migrations
- **Method/class:** `action`, `receive`, `operationExists`, receipt create path
- **Reproduction:** retry submit/approve/reject/cancel after a successful server-side action whose response was lost; retry returns invalid-state 422. Race two same-key receive calls.
- **Current behaviour:** dispatch and close-shortage have operation idempotency. Other actions do not. Receipt unique constraint prevents duplicate rows, but the pre-check occurs before transfer lock and unique violation handling is not explicit.
- **Expected behaviour:** safe replay response for all externally retryable commands; concurrent duplicate receipt returns existing receipt rather than a 500.
- **Business impact:** clients may show false failures and concurrent integrations may receive server errors.
- **Suggested fix direction:** use a unified action/command idempotency table and catch/reload unique-key receipt races.

## 7. Frontend Problems

1. The routed screen is `TransfersScreen`; it creates only source/destination/idempotency key and has no draft-line editor.
2. `InventoryTransfersWorkspaceScreen` and `InventoryTransfersScreen` still implement another transfer UI but are not routed. They conflict with the active screen and use a different feature shape.
3. The active screen invokes `InventoryCubit.loadTransfers()` with no server filters. Search/status filters are in-memory only, and list pagination is absent although backend accepts filters and returns metadata.
4. KPI badges are calculated from the loaded client list and ignore backend `meta.kpis`; an incomplete/all-data response can make them wrong.
5. Filter choices omit `rejected`, `cancelled`, and `closed_shortage`, so those real backend statuses cannot be selected in the UI.
6. Transfer status is a raw string throughout models. Backend fields such as rejection/closure timestamps are not fully represented, increasing status mapping drift risk.
7. The old workspace filters item candidates using index-item `warehouseIds`, though the list response does not reliably carry assignment IDs. It can offer no selectable lines.
8. Network error UI is present (as shown in the supplied screenshot) but default base URL is local host; deployment/runtime configuration and widget-test coverage were not demonstrated.

## 8. Backend Problems

1. API authentication, authorization, tenant derivation, and branch enforcement are absent/bypassable (INV-P0-001 and INV-P1-002).
2. Transfer status is stringly typed; no database status constraint prevents invalid values written outside the service.
3. `WarehouseTransferService::create` permits empty drafts. This is defensible only if a functioning draft editor is active; it is not.
4. Submit/approve/reject/cancel do not use a durable idempotency command record.
5. There is no explicit handling for unique constraint conflict in simultaneous same-key receipt creation.
6. `InventoryPostingService` does not require `inventory_items.is_active` for all manual posting paths, whereas transfer-line validation does. Disabled-item safety is inconsistent across inventory operations.
7. No service-level, reusable permission matrix expresses who may view/create/edit/submit/approve/dispatch/receive/cancel/count/adjust; action flags are state-only.
8. Existing tests simulate tenant scope through trusted `X-Tenant-Id`, so they cannot detect the real authentication failure.

## 9. Database/Data Integrity Problems

1. **Strength found:** `stock_balances` has a unique `(tenant_id, warehouse_id, inventory_item_id)` index, and normal posting uses transactions, row locks, and idempotency keys. Local reconcile reported zero differences across 37 local scopes.
2. **Weakness:** no composite foreign keys ensure every source/destination warehouse, item, receipt, and transfer line belongs to the same tenant. Normal services check it; direct SQL/import bugs can violate it.
3. `warehouse_transfers.status` is an unconstrained string; no check/enum enforces the state set.
4. Transfer number is generated from the primary ID during serialization (`TR-0001`), not stored or uniquely constrained as a business field. It is unique in normal creation but exposes global sequence and has no configurable/concurrency domain rule.
5. `warehouse_transfer_lines`, receipts, and operations cascade on transfer deletion. There is no delete route, but an administrative/direct deletion would erase audit history.
6. Closure shortages have no stock-movement reconciliation record (INV-P1-004), so balance history cannot alone explain every transfer discrepancy.
7. Cancellation does not persist a cancellation actor/time/reason field; rejected and closed-shortage have stronger metadata than cancelled.
8. The same receipt key is unique per transfer rather than visibly including tenant. This is harmless with a transfer FK but inconsistent with tenant-scoped design.

## 10. Authorization / SaaS Isolation Problems

| Capability | Backend result | Risk |
|---|---|---|
| View transfers/balances/movements | FAIL | unauthenticated local read returned data. |
| Create/edit/submit transfer | FAIL | no mandatory actor/policy. |
| Approve/dispatch/receive/cancel | FAIL | state gates only; actor can be null. |
| Branch-restricted access | FAIL | `assertBranchAccess` is a no-op when actor is null. |
| Tenant isolation by ID | FAIL | `X-Tenant-Id` and first-tenant fallback are trusted. |
| Item/location tenant checks in normal transfer service | PASS (code) | service validates tenant/active records, but cannot substitute for endpoint authentication. |

## 11. Seeder/Data Problems

- Default inventory seeding is broken by the `upsertLine` signature mismatch, blocking fresh demo and test database creation.
- `FinancialInventoryFoundationSeeder` does create a central warehouse and main/bar/kitchen locations for branches; `TenantAccessSeeder` creates several branches/users. This is useful structural demo data.
- `InventoryCenterSeeder` assigns each catalog item to a single warehouse by a position/modulo rule and opens stock there. It does not create realistic source/destination assignments for a chosen transfer route.
- No transfer seed records were found for draft, submitted/pending, approved, dispatched/in-transit, partially received, received, rejected, cancelled, or closed shortage.
- No transfer receipt or transfer movement dataset was found to prove mathematical consistency.
- No complete bar-check template/realistic repeated count/lots/batches/procurement demo data was found.
- Local development data contained two drafts and three cancelled transfers only; there was no real seeded dispatched/received transfer available for the required end-to-end trace.

## 12. Missing Features

These are missing capabilities, distinct from defects:

1. A single active Flutter workflow to add/edit/delete transfer lines and notes in draft.
2. Explicit backend role/permission definitions for all inventory actions.
3. A defined in-transit/shortage accounting policy and corresponding immutable movement artifacts.
4. Demonstrated partial-receipt variants: damaged, rejected, missing, and excess quantities are not separate supported concepts. Current implementation supports partial receipt plus one discrepancy reason only; excess is rejected by remaining-quantity validation.
5. Lots/batches/expiry stock, suppliers/purchase receiving, and a procurement inventory intake workflow.
6. Server-side transfer pagination and fully connected UI filters/status history.
7. A complete realistic, reconciled client-demo seed set and an automated seed smoke test.

## 13. Dead / Duplicate / Unused Code

- `features/inventory/views/inventory_workflow_screens.dart::InventoryTransfersWorkspaceScreen` is not the routed transfer screen.
- `features/inventory/views/inventory_screens.dart::InventoryTransfersScreen` is likewise not the active route.
- `features/inventory/transfers/repositories/transfer_repository.dart` and `TransferViewState` are thin/partial abstractions while active requests still use the shared `InventoryRepository`/`InventoryCubit`.
- Two transfer UIs implement overlapping, inconsistent draft/detail responsibilities. This is a maintenance and correctness risk, not evidence that both flows work.

## 14. Required Fix Order

1. **Phase 0 — Security/data-integrity blockers:** require backend authentication, derive tenant/user on server, enforce branch and lifecycle permissions, remove header/fallback identity in production paths, and lock down all inventory endpoints.
2. **Phase 1 — Restore testability:** fix only the seeder/service contract, add seed smoke coverage, then run the currently blocked suites.
3. **Phase 2 — Transfer state/accounting contract:** document permissible states/transitions, cancellation metadata, replay/idempotency contract, and shortage/in-transit ledger policy.
4. **Phase 3 — Database and service hardening:** enforce tenant-consistent relations where possible, add status/business constraints and race-safe receipt handling; add reconciliation tests.
5. **Phase 4 — API and frontend convergence:** route one complete transfer workspace, implement draft lines, use server filters/pagination/meta, and type/map statuses consistently.
6. **Phase 5 — Demo data:** seed complete, mathematically reconciled examples for each transfer status and counts/bar checks.
7. **Phase 6 — Automated tests and polish:** add lifecycle, retry, authorization, cross-tenant, cross-branch, race, Flutter repository/widget tests; rerun analyze and integration checks.

## 15. Files That Need Modification

This is a planning list only; none was modified by this audit.

| Group | Likely files |
|---|---|
| Backend | `routes/api.php`; `TenantContext.php`; `FinancialActor.php`; `AuthenticateApiToken.php`; inventory form requests; `WarehouseTransferController.php`; `WarehouseTransferService.php`; `InventoryPostingService.php`; transfer/count controllers/resources. |
| Flutter | `app_router.dart`; `features/inventory/transfers/views/transfers_screen.dart`; shared inventory Cubit/state/repository/models; decide on removal/consolidation of legacy transfer screens. |
| Database | transfer, receipt/operation, stock-movement/balance migrations for constraints, audit metadata, and agreed shortage accounting. |
| Tests | `tests/Feature/InventoryCenterApiTest.php`; `FinancialInventoryFoundationApiTest.php`; new auth/isolation/race/reconciliation tests; Flutter transfer repository/widget/integration tests. |
| Seeders | `InventoryCenterSeeder.php`; `InventorySeeder.php`; transfer lifecycle and reconciled balance/movement demo seeders. |

## 16. Final Verdict

1. **Can warehouse transfers currently be used safely in production?** No.
2. **Is the Flutter screen fully connected to real backend data?** Partially. It reads/calls real endpoints, but the routed create flow cannot manage lines and filters are client-only.
3. **Does every transfer status work end-to-end?** No. Code implements statuses, but tests are blocked, UI omits several statuses, and no seeded end-to-end lifecycle exists.
4. **Are stock balances mathematically safe?** Partially in normal posting code; transactions/locks/unique balance keys are present, but shortage accounting is incomplete and lifecycle tests are not running.
5. **Are inventory movements fully traceable?** No. A closed shortage is not a movement ledger event and transfer history is cascade-deletable at database level.
6. **Is multi-tenant isolation safe?** No; this is a P0 failure.
7. **Are permissions enforced on backend?** No.
8. **Is demo/seed data sufficient?** No; default seed is broken and transfer lifecycle demo data is missing.
9. **What blocks a complete real-client demo?** Public/unsafe API access, unusable routed transfer creation, failing seed/tests, incomplete ledger shortage trace, and absent lifecycle demo data.
10. **What should be fixed first?** Apply authenticated tenant/actor/branch/permission enforcement before any UI or demo work.

### End-to-end transfer trace

The required real seeded `Main Store -> Bar` trace could **not** be executed. The seed is broken and no seeded dispatched/received transfer exists. The code-intended accounting is:

| Point | Source | Destination | Movement evidence |
|---|---:|---:|---|
| Before draft / after draft / submit / approve | unchanged available quantity; approved reserves source | unchanged | no stock movements before dispatch |
| After dispatch quantity Q | source balance `-Q` | unchanged | `transfer_out` per transfer line |
| After receipt quantity R | source remains dispatched balance | destination `+R` | `transfer_in` per receipt line |
| After close shortage Q-R | source unchanged | destination unchanged | **no movement for Q-R**; only line/status metadata |

This is an implementation trace, not a validated data result; no numeric X/Y seed values are available safely.

### Log and supplied runtime evidence

- Supplied UI evidence showed `Backend is not reachable. Start Laravel server on http://localhost:8000`, which aligns with the Flutter localhost default and requires runtime configuration/availability validation.
- Supplied UI evidence showed `Undefined property: stdClass::$shortage_reason`. The current code/migrations contain shortage fields, so this points to a database migration/code version mismatch at the observed runtime and should be checked during remediation.
- The tests provided the actionable current application error described above; no additional current inventory stack trace was found in the inspected log tail.
