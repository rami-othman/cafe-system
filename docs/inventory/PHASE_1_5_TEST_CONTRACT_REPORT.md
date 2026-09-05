# Phase 1.5 — Inventory Test Failure Triage and Contract Validation

## 1. Executive Summary

Phase 1.5 is complete for the Inventory Center contract suite. The initial `InventoryCenterApiTest` baseline had 8 failures. They were triaged before correction: four were test-fixture/scope defects, one was a stale test expectation following actor authentication, one was a stale cycle-count request, and five production defects were identified while executing the corrected workflows.

Final Inventory Center result: **25 passed, 0 failed, 314 assertions**.

The Phase 0/1 inventory security and foundation suites remain green: **11 passed, 67 assertions**. No new transfer-accounting work was started in this phase.

## 2. Baseline Results

Command run before Phase 1.5 corrections:

```powershell
docker compose exec -T backend php artisan test tests/Feature/InventoryCenterApiTest.php
```

| Result | Count | Notes |
| --- | ---: | --- |
| Passed | 16 | Existing Inventory Center contracts that already held. |
| Failed | 8 | Triaged individually below. |
| Assertions | 246 | Baseline output. |

## 3. Root Cause Classification

| Baseline failure | Root cause | Classification | Resolution |
| --- | --- | --- | --- |
| Stock-count approval flow returned 404 for the new item | The count only creates lines for items assigned to its warehouse; the test item was not assigned. | Test fixture isolation | Use a dedicated empty warehouse and explicitly assign the test item. |
| Cycle count list creation returned 422 | The implementation correctly requires `categoryFilters` for `countType=cycle`; the test omitted it. | Test contract stale | Supply a real category filter. |
| Count snapshot test could not find the test item | Seeded warehouse inventory created unrelated required count lines. After isolation, the snapshot cost exposed an additional production bug. | Fixture isolation + production defect | Isolate the count warehouse; correctly convert stored cost decimals when writing snapshot lines. |
| `lastPurchaseCost` became `0.0002` instead of `2.2500` | A decimal input was coerced to an integer before fixed-point formatting (`2.2500` became scaled integer `2`). | Production defect | Parse with `InventoryDecimal::cost()` before `unitCost()`. |
| Movement `conversionFactor` was numeric `12` | The API exposed SQLite's raw numeric value rather than the fixed six-decimal contract. `baseQuantity` had the same risk. | Production/API contract defect | Serialize factor and base quantity with `InventoryDecimal`. |
| Reconciliation checked 29 rows rather than 2 | The test invoked tenant-wide reconciliation after seeding all inventory, even though it intended to assert two rows in one warehouse. | Test scope defect | Call `dryRun($tenant, $warehouse)`. |
| Required-line submission never completed | The shared seeded warehouse contributed additional required count lines. | Fixture isolation | Use an isolated warehouse containing only the two explicit items. |
| Bar-check test first returned 500, then created a line for item 1 | `BarCheckController` transaction closures omitted `$request`; after fixing that, `StockCountService` used the template-line primary key as the inventory-item id. | Production defects | Capture `$request` in both controller closures; prefer `inventory_item_id` when materializing a template line. |

Additional contract correction: the approval test expected `approvedBy = null`, but authenticated approvals now record the authenticated owner. The test now asserts the real owner id, preserving the Phase 0/1 actor-security contract.

## 4. Contract Corrections

### Stock-count fixture contract

`StockCountService::create()` intentionally includes every active, assigned stock item at the selected warehouse. The focused tests now create an empty dedicated warehouse and assign only their intended items. This avoids weakening the real count contract or changing seed data.

### Cycle-count contract

`cycle` counts require at least one category. This was already enforced by `StockCountService::create()` and covered by another creation test. The list test now sends a valid category rather than expecting an invalid request to create a count.

### Reconciliation scope contract

`InventoryReconciliationService::dryRun()` supports tenant, warehouse, and item scopes. The two-row expectation belongs to the chosen test warehouse, not the whole seeded tenant.

### Bar-check materialization contract

The bar-check template line has both its own `id` and its `inventory_item_id`. Count-line creation now uses `inventory_item_id` when it exists. This preserves ordinary administrative count creation, where `items.id` is the inventory-item id.

## 5. Numeric API Contracts

The following response contract is now explicit and tested, including under SQLite:

| Field | API representation | Precision |
| --- | --- | --- |
| `minimumStock`, `reorderLevel` | string | 3 decimal places |
| `latestUnitCost`, `lastPurchaseCost`, movement `unitCost` | string | 4 decimal places |
| movement `conversionFactor` | string | 6 decimal places |
| movement `baseQuantity` | string | 3 decimal places |

The following production corrections implement the contract:

- `InventoryItemService` parses `lastPurchaseCost` into scaled cost units before formatting it.
- `InventoryItemController` serializes inventory numeric fields through `InventoryDecimal`.
- `StockMovementController` serializes conversion factor and base quantity through `InventoryDecimal`.
- `StockCountService` parses the stored balance average cost before storing the immutable count snapshot.

## 6. Tests Added or Adjusted

`InventoryCenterApiTest` now includes `test_inventory_numeric_api_contracts_use_fixed_precision_strings`, which verifies both values and JSON types for item costs, movement conversion factors, and base quantities.

Focused count and reconciliation tests now isolate their data with a test-only warehouse helper. This helper creates no demo data and does not change any production seeder or inventory rule.

The bar-check workflow additionally asserts that the stored template response contains the requested inventory item before starting the check. This catches a mismatch between template creation and count materialization.

## 7. Tests Run

| Command | Result |
| --- | --- |
| `docker compose exec -T backend php artisan test tests/Feature/InventoryCenterApiTest.php` | **PASS — 25 tests, 314 assertions** |
| `docker compose exec -T backend php artisan test tests/Feature/InventorySecurityAndSeederTest.php tests/Feature/FinancialInventoryFoundationApiTest.php` | **PASS — 11 tests, 67 assertions** |
| PHP syntax checks for modified production and test files | **PASS** |
| `git diff --check` | **PASS** (no whitespace errors) |

## 8. Regression Notes

The complete backend suite was also run:

```powershell
docker compose exec -T backend php artisan test
```

Result: **46 passed, 4 failed, 467 assertions**. The four failures are outside the Inventory Center contract scope and were not changed in this task:

| Test | Result | Evidence |
| --- | --- | --- |
| `DiscountManagementApiTest::test_tenant_and_branch_seed_data_is_idempotent` | FAIL | Expects 3 branches; current tenant seed data contains 4. |
| `PosApiSmokeTest::test_pos_order_flow_can_be_completed` | FAIL | Expects unauthenticated inventory/branch access; receives the expected Phase 0/1 `401`. |
| `ReportsOverviewApiTest::test_overview_is_tenant_isolated_and_returns_real_aggregates` | FAIL | SQLite SQL error: ambiguous `tenant_id` in `ReportsOverviewController::topProducts`. |
| `ReportsOverviewApiTest::test_overview_filters_dates_and_branches_and_uses_paid_sales_minus_refunds` | FAIL | Same ambiguous-column SQL error. |

These are recorded for later triage. They neither block the Inventory Center suite nor justify weakening the new authentication/tenant boundaries.

## 9. Files Changed

Production:

- `backend/app/Http/Controllers/Api/BarCheckController.php`
- `backend/app/Http/Controllers/Api/InventoryItemController.php`
- `backend/app/Http/Controllers/Api/StockMovementController.php`
- `backend/app/Services/InventoryItemService.php`
- `backend/app/Services/StockCountService.php`

Tests:

- `backend/tests/Feature/InventoryCenterApiTest.php`

Documentation:

- `docs/inventory/PHASE_1_5_TEST_CONTRACT_REPORT.md`

## 10. Phase 2 Boundary

No new warehouse-transfer lifecycle, transit, receipt, cancellation, or accounting behavior was designed or added during Phase 1.5. Existing transfer work in the dirty working tree was preserved and only exercised by the Inventory Center regression tests.

## 11. Final Status

| Requirement | Status |
| --- | --- |
| Full `InventoryCenterApiTest` | PASS — 0 failures |
| Count fixture contamination | Resolved through test isolation |
| Cycle-count filter contract | Corrected and covered |
| `2.2500` purchase-cost defect | Fixed and covered |
| Numeric factor/base-quantity contract | Fixed and covered |
| Reconciliation scope test | Corrected and covered |
| Bar-check template/line identity | Fixed and covered |
| Phase 0/1 security/foundation regression | PASS |
| New Phase 2 work | Not started |
