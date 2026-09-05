# Phase 2 — Transfer Accounting and State Safety Report

## Summary

Phase 0/1 was revalidated before this work: `InventorySecurityAndSeederTest` passed (6 tests, 24 assertions) and `FinancialInventoryFoundationApiTest` passed (5 tests, 43 assertions). Authentication, server-derived tenant/actor context, branch restrictions, lifecycle permissions, and isolated seed execution remained healthy.

This phase hardens the existing `WarehouseTransferService`; it does not replace its architecture or alter Flutter. Transfers now use a transfer-line **in-transit ledger**. A dispatched unit is always in exactly one of: destination stock, in-transit balance, or documented shortage. Source and destination physical balances continue to be updated only by `InventoryPostingService`.

## Accounting model selected

**Model B — explicit transfer/in-transit ledger balance and immutable transit movements.**

This was selected over a virtual warehouse because the current inventory model has physical warehouse balances and transfer-specific line data, while no generic virtual-location model exists. It avoids introducing a fake warehouse and preserves `InventoryPostingService` as the sole writer of physical `stock_balances`.

```text
dispatch Q:  source stock -Q; transfer-line in-transit +Q
receive R:   transfer-line in-transit -R; destination stock +R
shortage S:  transfer-line in-transit -S; immutable shortage record +S

For every dispatched line: dispatched = received + in_transit + shortage_closed
```

`warehouse_transfer_transit_balances` carries the current per-line quantity. `warehouse_transfer_transit_movements` is append-only accounting evidence with tenant, transfer, line, item, source/destination warehouses, type, before/after, reason, actor, timestamp, and idempotency key.

## Transfer lifecycle

| From | Action | To | Stock Effect | Reservation Effect | Ledger Effect |
|---|---|---|---|---|---|
| draft | submit | submitted | none | none | action operation/audit |
| submitted | approve | approved | none | source request reserved | action operation/audit |
| submitted | reject | rejected | none | none | rejection actor/reason/time + operation/audit |
| approved | dispatch | dispatched | source `transfer_out` through `InventoryPostingService` | consume/release exactly once | in-transit `dispatch` row + operation/audit |
| dispatched/partial | receive | partial/received | destination `transfer_in` through `InventoryPostingService` | none | in-transit `receipt` row per receipt line |
| dispatched/partial | close shortage | closed_shortage | no physical balance mutation | none | in-transit `shortage` row per outstanding line |
| draft/submitted | cancel | cancelled | none | none | cancellation actor/time/reason + operation/audit |
| approved | cancel | cancelled | none | source reservation released exactly once | cancellation actor/time/reason + operation/audit |

Terminal statuses reject incompatible actions. Update remains draft-only. The canonical backend values are the `TransferStatus` enum: `draft`, `submitted`, `approved`, `rejected`, `cancelled`, `dispatched`, `partially_received`, `received`, `closed_shortage`.

## Legal transition matrix

`TransferStatus` is the backend single source of truth. The service retains controlled `ValidationException` status errors for invalid transitions; API routes map each command to the independently authorized action.

Unsupported now (explicitly): damaged quantity, rejected quantity, excess receipt, and return-to-source during receipt. Supported: full receipt, multiple partial receipts, and generic documented shortage closure. Receipt quantities cannot exceed current outstanding/in-transit quantity.

## Idempotency strategy

- **Create:** requires `idempotencyKey`; existing unique `(tenant_id, idempotency_key)` transfer returns the original transfer.
- **Submit, approve, reject, dispatch, close-shortage, cancel:** require a command key. `warehouse_transfer_operations` stores every completed action; retry with the same action/key returns without another reservation, state change, movement, or audit event.
- **Receive:** requires a receipt key. The transfer row is locked before receipt-key lookup; a same-key retry returns without a second receipt or stock posting.
- **Physical movements:** retain deterministic `InventoryPostingService` movement keys, which are unique per tenant and replay-safe.
- **Transit movements:** have tenant-scoped unique idempotency keys.

## Concurrency protections

- Transfer command and receipt paths run in database transactions and lock the transfer row.
- Transfer line rows are locked before receive/shortage quantity calculations.
- Source balance reservation, dispatch, and destination receipt use `InventoryPostingService` balance row locks.
- Transit balance is locked before every dispatch, receipt, and shortage decrement.
- Receipt key lookup occurs after locking the transfer, avoiding the prior pre-lock duplicate receipt race. The receipt table uniqueness remains a database backstop.

The isolated CI test database is SQLite `:memory:`, which cannot execute independent simultaneous database connections safely. Sequential duplicate-command regression coverage is run; production concurrency safety is implemented by the transaction/row-lock design and unique constraints. A multi-process PostgreSQL race test remains recommended before production rollout.

## Shortage handling

Closing a shortage no longer merely changes transfer metadata. For every outstanding line it now writes:

- current transit balance decrement;
- immutable `warehouse_transfer_transit_movements.type = shortage` row;
- transfer, line, item, source/destination context;
- shortage quantity, reason, actor, timestamp, tenant, and idempotency key;
- existing line/transfer shortage metadata.

Previous `transfer_out` and `transfer_in` rows remain immutable. The shortage is a documented loss from the in-transit state, not a retroactive mutation of history.

## Cancellation/rejection audit

The migration adds `cancelled_by`, `cancelled_at`, and `cancellation_reason` to `warehouse_transfers`. Cancellation now requires a reason and writes all three values. Approved cancellation still releases the reservation under the existing lock and cannot be repeated with a different stock effect. Rejection continues to require and persist reason, actor, and timestamp.

## Database changes

- Added `TransferStatus` backed enum/value definition.
- Added `warehouse_transfer_transit_balances`, unique by tenant and transfer line.
- Added immutable `warehouse_transfer_transit_movements`, indexed by transfer/line and unique by tenant/idempotency key.
- Added cancellation actor/time/reason fields.
- All changes are forward-only Laravel migrations; no historical movement was deleted or modified.

## Reconciliation behavior

`InventoryReconciliationService::dryRun()` remains read-only. In addition to stock-movement-to-balance differences, it now reports `transferTransitDifferences` whenever:

```text
dispatched_base_quantity - received_base_quantity - shortage_closed_quantity
!= recorded quantity_in_transit
```

It never auto-repairs either physical or transit data.

## Tests added

- Expanded the existing transfer shortage lifecycle regression from 18 to 22 assertions. It verifies transit `8 -> 2 -> 0` for dispatch 8, receive 6, close shortage 2, and exactly three transit ledger rows.
- Added a multiple-receipt lifecycle test: dispatch 100; receive 40, 30, 30; final transit 0, source 0, destination 120 (opening 20 + received 100), and transfer status `received`.
- Existing security test verifies no Phase 0 tenant/actor/permission regression.

## Test commands and results

| Command | Passed | Failed | Assertions |
|---|---:|---:|---:|
| `docker compose exec -T backend php artisan test --filter=InventorySecurityAndSeederTest` | 6 | 0 | 24 |
| `docker compose exec -T backend php artisan test --filter=FinancialInventoryFoundationApiTest` | 5 | 0 | 43 |
| `docker compose exec -T backend php artisan test --filter=test_transfer_reserves_dispatches_receives_partially_and_closes_shortage_idempotently` | 1 | 0 | 22 |
| `docker compose exec -T backend php artisan test --filter=test_transfer_multiple_receipts_reconcile_source_destination_and_transit` | 1 | 0 | 15 |

The broader `InventoryCenterApiTest` still has the Phase 1 documented non-transfer fixture/contract failures; they were not hidden or changed in this accounting phase.

## Numeric end-to-end reconciliation

### Full receipt test

Starting: Main Store/source = 100, Bar/destination = 20; transfer = 100.

| Event | Source | Destination | In transit | Shortage |
|---|---:|---:|---:|---:|
| Draft / submit | 100 | 20 | 0 | 0 |
| Approve | 100 (reserved 100) | 20 | 0 | 0 |
| Dispatch | 0 | 20 | 100 | 0 |
| Receipt 40 | 0 | 60 | 60 | 0 |
| Receipt 30 | 0 | 90 | 30 | 0 |
| Receipt 30 | 0 | 120 | 0 | 0 |

Ledger rows: one physical `transfer_out`, three physical `transfer_in`, one transit `dispatch`, and three transit `receipt` rows.

### Shortage test

Starting source = 10, destination = 0; transfer = 8.

| Event | Source | Destination | In transit | Shortage |
|---|---:|---:|---:|---:|
| Dispatch | 2 | 0 | 8 | 0 |
| Receive 6 | 2 | 6 | 2 | 0 |
| Close shortage | 2 | 6 | 0 | 2 |

The immutable transit ledger has exactly dispatch, receipt, and shortage records, so `2 + 6 + 2 = 10` is fully explained.

## Files changed

- `backend/app/Domain/Inventory/TransferStatus.php` — canonical backend status definition.
- `backend/app/Domain/Inventory/TransferTransitLedger.php` — locked immutable in-transit accounting ledger.
- `backend/app/Domain/Inventory/WarehouseTransferService.php` — uses transit ledger, unified action idempotency, cancellation audit fields, receipt lock ordering.
- `backend/app/Domain/Inventory/InventoryReconciliationService.php` — read-only transit consistency reporting.
- `backend/app/Http/Controllers/Api/WarehouseTransferController.php` — requires command/create idempotency keys and cancellation reason input.
- `backend/database/migrations/2026_08_29_000003_add_transfer_transit_ledger_and_cancellation_audit.php` — forward schema changes.
- `backend/tests/Feature/InventoryCenterApiTest.php` — transit shortage and multi-receipt reconciliation proof.
- `backend/tests/Feature/InventorySecurityAndSeederTest.php` — authenticated transfer create fixture now has required idempotency key.

## Remaining issues

Intentionally postponed to frontend Phase 3:

- Flutter transfer-line create/edit UI and API token integration presentation.
- Flutter typed status mapping, filter/pagination integration, and status chips.
- Demo transfer seed data.

Also still pending hardening work: a PostgreSQL multi-process concurrency integration test, schema-level status CHECK constraint (database-vendor migration decision), separate damaged/rejected/excess receipt concepts, and broader existing InventoryCenter fixture-contract failures.

## Final verdict

1. **Can dispatch duplicate stock deductions?** No for same command key; transfer/balance locks and deterministic movement keys prevent duplicate effective dispatch.
2. **Can receive duplicate destination stock?** No for same receipt key; transfer lock, receipt key, movement keys, and transit balance prevent duplicate effect.
3. **Can approval over-reserve stock?** No in the locked normal path; reservation validates `on_hand - reserved`.
4. **Is partial receiving safe?** Yes for full/multiple partial receipt and shortage closure; received cannot exceed dispatched/outstanding.
5. **Is closed shortage now fully traceable?** Yes, through immutable in-transit shortage ledger rows plus transfer metadata/audit.
6. **Are retries safe?** Yes for create and action/receipt requests that provide their now-required idempotency keys.
7. **Are concurrency races handled?** The service uses locks/unique constraints and receipt lock ordering; dedicated simultaneous PostgreSQL test remains pending.
8. **Are transfer movements mathematically reconcilable?** Yes under the selected source + destination + in-transit + documented-shortage model.
9. **Are transfer lifecycle tests green?** The focused transfer lifecycle tests are green (37 assertions). Broader inventory fixture failures remain documented.
10. **Is Backend transfer logic ready for Flutter integration?** Backend accounting is ready for an authenticated, idempotency-key-aware Flutter integration; transfer-line UI remains intentionally deferred to Phase 3.
