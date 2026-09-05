# Warehouse Transfer Audit Report

This report is the transfer-focused companion to [INVENTORY_AUDIT_REPORT.md](INVENTORY_AUDIT_REPORT.md). It records the exact flow found; it does not propose or apply implementation changes.

## Scope and finding

The Laravel transfer service is materially more complete than the Flutter workflow: it supports draft, submit, approval/reservation, dispatch, full/partial receipt, cancellation, rejection, and closed shortages. However, no API authentication or lifecycle authorization protects those actions. The active Flutter screen cannot add lines. Consequently the transfer feature is not production-ready.

## Architecture map

```text
TransfersScreen (active GoRouter route)
  -> InventoryCubit.createTransfer/updateTransfer/transferAction/receiveTransfer
  -> InventoryRepository
  -> DioApiClient
  -> WarehouseTransferController
  -> WarehouseTransferService
       -> InventoryPostingService on dispatch/receipt
  -> transfer / receipt / operation / movement / balance tables
```

The legacy `InventoryTransfersWorkspaceScreen` and `InventoryTransfersScreen` are not the active router targets. They must not be treated as proof of a usable live transfer experience.

## Lifecycle and accounting

| State | Available actual actions | Stock accounting |
|---|---|---|
| `draft` | update lines, submit, cancel | none |
| `submitted` | approve, reject, cancel | none |
| `approved` | dispatch, cancel | source reservation only |
| `dispatched` | receive all/part, close shortage | dispatch has source `transfer_out`; receipt has destination `transfer_in` |
| `partially_received` | receive remaining, close shortage | receipt movements only for quantities received |
| `received`, `rejected`, `cancelled`, `closed_shortage` | no intended stock-processing actions | terminal |

There is no backend `in_transit`; Flutter aliases `dispatched` and `partially_received` to that concept. There is no `pending approval`; Flutter aliases `submitted`.

## Verified protections

- Source and destination must differ and be active tenant locations.
- Transfer lines use positive decimal base quantities and active assigned items.
- Approval reserves source stock under a transaction and row lock.
- Dispatch and normal movement posting use row locks, unique balance scope and deterministic per-line idempotency keys.
- Full and partial receipt cannot exceed remaining quantity. Partial receipt requires a discrepancy reason.
- Update is draft-only; cancellation is forbidden after dispatch.

## Failing / unsafe areas

| Severity | Finding | Evidence |
|---|---|---|
| P0 | API is unauthenticated and tenant scope is header/fallback controlled. | `routes/api.php`, `TenantContext`, live unauthenticated GET returned 200. |
| P1 | No backend role permission for submit/approve/dispatch/receive/cancel. | form requests authorize all; actor-null bypasses branch check. |
| P1 | Routed UI creates empty drafts and cannot add lines. | active `TransfersScreen` / `_LocationDialog`. |
| P1 | Closed shortage has no stock movement/auditable ledger reconciliation. | `WarehouseTransferService::closeShortage`. |
| P1 | Non-dispatch action retries are not idempotent; receipt race needs conflict handling. | service action/receipt paths. |
| P2 | Cancellation has no persisted cancellation actor/time/reason. | transfer schema/service. |
| P2 | Active UI does local filtering, ignores server KPIs and omits terminal status filters. | `TransfersScreen`, `InventoryRepository::transfers`. |
| P2 | No runnable transfer regression suite because default seed crashes. | `InventoryCenterSeeder.php:63`. |

## Receiving support

Current implementation supports full receipt and partial receipt. It does not model damaged, rejected, missing, or excess quantities as distinct quantities/statuses. “Missing” can be expressed only as a generic discrepancy reason, then `close_shortage`; excess is rejected because receipt quantity cannot exceed remaining quantity.

## Required test evidence

The intended inventory transfer happy-path feature test exists, but was not executed because the default seeder fails before test assertions. The two executed test filters failed with 0 assertions. Therefore every lifecycle conclusion in this report is code-traced, not test-certified.

## Verdict

**Transfers production ready: NO.**

First remediate authenticated tenant/actor/branch authorization. Then restore the test database seed, decide/document the shortage ledger policy, and converge Flutter on a complete single transfer draft workflow. Do not use transfer seed/demo data as a workaround before those blockers are resolved.
