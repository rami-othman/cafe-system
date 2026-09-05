# Finance Phase 0B — Final Validation & Closure

## 1. Executive Summary

**PHASE 0B: COMPLETE — READY FOR PHASE 1**

Phase 0B now closes the Finance Core safety prerequisites without starting a Finance business-feature phase. The POS/Finance-sensitive API surface is bearer-token protected, tenant context comes from the authenticated token rather than a production `X-Tenant-Id` header, financial request replays are tenant-scoped and fingerprint-checked, paid orders are immutable through normal order/discount actions, refunds serialize on the payment row, and the reusable journal reversal/posting infrastructure is in place.

- Backend validation: **77 passed, 666 assertions, 0 failures**.
- Flutter validation: complete `flutter test` completed successfully; the focused payment-retry suite passed **8 tests**. `flutter analyze` reported **0 errors, 0 warnings, 28 info-level lints**.
- Scope discipline: no POS/refund/inventory automatic journal posting, no COGS mapping, no Finance Phase 1 feature, and no fake ledger mapping was introduced.

During independent closure review, three genuine Phase 0B gaps were found and fixed:

1. Idempotency replay initially compared only the target order/branch, not the complete request payload.
2. A second payment with a new key could still be inserted after an order was paid; several paid-order mutation routes were also still reachable.
3. A tenant-A order could be created with a guessed tenant-B branch ID because validation used global `exists` rules.

The fixes are covered by the final test suite.

## 2. Original Phase 0B Objectives

1. Authenticate POS/Finance tenant-sensitive APIs with bearer tokens.
2. Make orders, payments, and refunds idempotent per tenant.
3. Protect refund remaining-balance calculation from concurrent requests.
4. Block normal cancellation or mutation of paid financial orders.
5. Add immutable journal reversal support.
6. Add an orchestration-only `AccountingPostingService` that reuses `JournalEntryService`.
7. Validate the complete backend and Flutter baseline without starting Phase 1.

## 3. Pre-existing Work Discovered

The working tree already contained the primary Phase 0B implementation before this closure pass:

- Route grouping around `api.token` in [api.php](../../backend/routes/api.php).
- `idempotency_key` migration and initial order/payment/refund replay handling.
- Refund transaction locking, paid-order cancellation guard, journal reversal, and `AccountingPostingService`.
- POS Cubit/repository support for a payment idempotency key and a retry-focused Flutter test.
- Auth-aware report/discount/POS test updates and the unrelated `ReportsOverviewController` ambiguous-column repair.

The code, not the earlier summary, was treated as the source of truth. The closure fixes described in §4 were made after this inspection.

## 4. Work Completed During Phase 0B

- Protected branches, reports, shifts, menu, customers, tables, POS state, discounts, orders, payments, and refunds through `api.token` route groups.
- Added tenant-unique nullable idempotency keys to `orders`, `payments`, and `payment_refunds`.
- Added tenant-unique request fingerprints (`SHA-256` over canonicalized validated payload) for safe replay/conflict distinction.
- Added a locked-order check in payment creation: an order is payable only while `payment_status = unpaid`.
- Added tenant/branch/table/customer/shift context checks during order creation and contextual order updates.
- Made normal order and discount mutations reject any order that has a payment record.
- Locked the payment before refund remaining-balance calculation; the refund insert and order update remain in the same transaction.
- Added journal reversal linkage/auditing and a DB uniqueness backstop for one reversal per tenant/original entry.
- Made `AccountingPostingService` require a positive source ID plus a non-empty source event, and rely on a database unique constraint as the duplicate-posting race backstop.

## 5. Files Changed

### Backend

- `app/Http/Controllers/Api/{PosOrderController,PaymentController,RefundController,DiscountController,JournalEntryController,ReportsOverviewController}.php`
- `app/Services/{JournalEntryService,AccountingPostingService}.php`
- `app/Support/IdempotencyFingerprint.php`
- `routes/api.php`

### Database

- `database/migrations/2026_08_29_000004_add_finance_core_safety_fields.php`
- `database/migrations/2026_08_29_000005_add_finance_idempotency_fingerprints.php`

### Flutter

- `lib/features/pos/controllers/pos_cubit.dart`
- `lib/features/pos/repositories/pos_repository.dart`

### Tests

- `tests/Feature/{AccountingPostingServiceTest,MoneyIdempotencyApiTest,RefundConcurrencyApiTest}.php`
- Updated `PosApiSmokeTest`, finance-foundation, reports, daily-report, and discount tests.
- `test/features/pos/controllers/pos_backend_payment_test.dart`

### Documentation

- This report.

## 6. Authentication Hardening

All listed POS/Finance-sensitive routes are inside `api.token` middleware: branches, reports, shifts, menu, customers, tables, POS state, discounts, orders (including pay/refund), and `/finance/*`.

`AuthenticateApiToken` hashes the bearer token, verifies expiry and an active non-deleted user, then places token-derived `tenant_id` and actor data in the request. `TenantContext` accepts `X-Tenant-Id` only when `APP_ENV=testing`; production headers cannot select another tenant.

Evidence:

- Route inspection: `php artisan route:list --path=api/v1 --json` showed `api.token` for each relevant route.
- `PosApiSmokeTest::test_unauthenticated_pos_requests_are_rejected`.
- `DiscountManagementApiTest::test_discounts_require_authentication`.
- Tenant isolation tests in `PosApiSmokeTest` and `FinancialInventoryFoundationApiTest`.

Flutter uses `DioApiClient` as the real repository path. Its request interceptor removes `X-Tenant-Id` and adds `Authorization: Bearer <token>`. Debug runs call the real `/auth/login` endpoint in `dev_auth_bootstrap.dart`; production may supply `API_TOKEN` or call `setBearerToken()` after login.

## 7. Order Idempotency

`POST /orders` accepts optional `idempotencyKey`. The database has a tenant-scoped unique key and stores the validated request fingerprint. A same-tenant replay with the same canonical request returns the original order; changed items, quantities, context, or other validated input return HTTP 409. Different tenants can reuse the same textual key.

The unique constraint is the concurrency backstop. `QueryException` recovery only reuses the row after its fingerprint matches; it does not treat a duplicate-key exception as unconditional success.

Evidence: `MoneyIdempotencyApiTest` covers same replay and changed-order payload conflict.

## 8. Payment Idempotency

`POST /orders/{order}/pay` fingerprints the validated payment payload plus the route order ID. A matching replay returns the original payment; a changed method, amount, reference/note, or order ID returns 409. A new key on an already-paid order is rejected inside the transaction after `lockForUpdate()` on the order row.

Amounts introduced in the Phase 0B critical path are converted through `Money::cents()` and persisted as `Money::decimal()`, avoiding new float arithmetic in payment acceptance/change calculation.

Evidence: `MoneyIdempotencyApiTest`, `PosApiSmokeTest`, and `pos_backend_payment_test.dart`.

## 9. Refund Idempotency

`POST /orders/{order}/refunds` uses the same tenant-key/fingerprint pattern. A matching replay returns the original refund; reuse against another order or changed refund payload returns 409. The key is not consumed by a rejected validation attempt because no refund row is inserted.

Evidence: `MoneyIdempotencyApiTest` exercises cross-tenant key reuse, changed request conflicts, foreign-order conflicts, and failed-then-corrected use.

## 10. Refund Concurrency Protection

Inside one `DB::transaction()`, `RefundController` locks the completed payment row **before** summing completed refunds for that payment, checks the cent-based remaining balance, inserts the refund, and updates the order. Therefore two PostgreSQL transactions targeting one payment serialize at the payment row; the later transaction reads the prior committed refund before it can insert.

`RefundConcurrencyApiTest` proves the balance boundary under the test harness. Important limitation: PHPUnit is configured with SQLite `:memory:`, and its two requests are sequential. SQLite does not faithfully exercise PostgreSQL `FOR UPDATE` concurrency. The production PostgreSQL migration preview and implementation were inspected, but an actual parallel PostgreSQL test against an isolated database was not run in this closure. This is a test-coverage limitation, not a known implementation defect.

## 11. Paid Order Cancellation Protection

Normal cancellation now rejects any order whose `payment_status` is not `unpaid`. The guard also applies to normal order update, add/update/remove item, hold, legacy discount add/remove, and DiscountController apply/remove actions. Explicit refund remains the only financial correction flow in this phase.

Evidence: `PosApiSmokeTest` asserts all of these post-payment paths return 422 while payment/refund history remains intact.

## 12. Journal Reversal

Journal statuses are **only `draft` and `posted`**. There is intentionally no `reversed` status:

- A posted original entry stays `posted` and immutable.
- A reversal is a separate `posted` entry with `source_type = journal_reversal` and `reversal_of_id` pointing to its original.
- `isReversed` on a response means **the original has a reversal document**; it does not mean the row's own status changed.

`JournalEntryService::reverse()` locks the original, verifies it is posted and not previously reversed, swaps every debit and credit in a new draft, posts through the existing `post()` method, and writes `journal_entry.reversed` audit data. The schema has both a self-FK and a tenant/original uniqueness constraint.

Evidence: `FinancialInventoryFoundationApiTest` verifies swapped balanced lines, original immutability, cross-tenant rejection, one reversal only, and audit data.

## 13. AccountingPostingService

`AccountingPostingService` is an orchestration layer, not a parallel ledger. It:

- resolves active tenant-scoped accounts by code, never raw database IDs;
- requires a source type, positive source ID, and non-empty source event;
- creates a draft and posts it through the existing `JournalEntryService` in one transaction;
- checks debit/credit validity through that existing service;
- writes `accounting_posting.created` audit data;
- deduplicates by `tenant_id + source_type + source_id + source_event` at both service and database levels.

The DB unique index is the race backstop. If a competing transaction wins, the service re-reads and returns the original entry. No adapter chooses accounts or contains hard-coded account IDs.

No controller calls any adapter yet. In particular, POS sales, refunds, expenses, suppliers, waste, stock counts, and transfers do **not** automatically create journals in Phase 0B.

## 14. Money Precision

New money-critical payment/refund comparison work uses `Money::cents()` and `Money::decimal()`. Journal lines already use this helper. Legacy POS pricing, report totals, payment summary, discount calculations, and shift calculations still contain float casts/rounding; these were not refactored because they predate Phase 0B and are outside this closure scope.

## 15. Database Constraints and Indexes

| Table | Protection |
|---|---|
| `orders` | unique `(tenant_id, idempotency_key)` plus nullable fingerprint |
| `payments` | unique `(tenant_id, idempotency_key)` plus nullable fingerprint |
| `payment_refunds` | unique `(tenant_id, idempotency_key)` plus nullable fingerprint |
| `journal_entries` | unique `(tenant_id, source_type, source_id, source_event)` and unique `(tenant_id, reversal_of_id)`; `reversal_of_id` self-FK `nullOnDelete()` |

`php artisan migrate --pretend` against the configured PostgreSQL connection generated valid PostgreSQL `ALTER TABLE`/constraint SQL and made no writes. SQLite refresh-database tests exercised fresh migration application. A rollback was source-reviewed; a live PostgreSQL rollback was deliberately not executed against the non-test database.

## 16. Flutter Changes

`PosCubit.completeBackendPayment()` derives one stable key from the backend order ID (`pos-payment-order-<id>`). The first backend pay attempt, retry after a definite retryable failure, and retry after an uncertain result use the same logical key. A different order uses a different key. The Cubit blocks double confirmation while submitting; on uncertain network loss it fetches the order before allowing another submission.

The repository forwards the optional key in the real `orders/{id}/pay` JSON request. `pos_backend_payment_test.dart` proves double-confirmation suppression, stable key reuse after retry, and uncertain-response verification behavior.

## 17. Tests Added / Updated

- `AccountingPostingServiceTest`: balanced posting, source-event replay, tenant account lookup, inactive/unknown account rejection, and rollback on imbalance.
- `MoneyIdempotencyApiTest`: tenant-key isolation, matching replay, changed-payload conflicts for order/payment/refund, foreign-order conflicts, and non-consuming validation failure.
- `RefundConcurrencyApiTest`: refund boundaries and intended serialized-balance behavior (with SQLite concurrency limitation noted in §10).
- `FinancialInventoryFoundationApiTest`: journal reversal and finance tenant isolation.
- `PosApiSmokeTest`: authenticated golden path, idempotent pay/refund, paid-order immutability, and branch-ID cross-tenant rejection.
- `pos_backend_payment_test.dart`: Flutter payment idempotency key lifecycle.

## 18. Full Backend Test Results

Command:

```text
docker compose exec -T backend php artisan test
```

Result: **77 passed, 666 assertions, 0 failures, 0 skipped** in 13.22 seconds.

## 19. Flutter Test Results

Commands:

```text
flutter test
flutter test test/features/pos/controllers/pos_backend_payment_test.dart --reporter compact
```

The complete suite exited successfully. The focused payment suite completed **8/8** tests. The executor truncated the verbose full-suite tail, so a total Flutter test count was not captured; no failure output or non-zero exit was returned.

## 20. Flutter Analyze Results

Command:

```text
flutter analyze
```

Result: **0 errors, 0 warnings, 28 info-level findings**. Most are existing Inventory view/style/deprecation lints. One info is in `pos_repository.dart` for an optional-map-entry style preference introduced with the optional idempotency key; it is non-functional and does not affect compilation or behavior.

## 21. Regression / Smoke Validation

The authenticated backend smoke path is covered by `PosApiSmokeTest`:

```text
token-authenticated branch/POS state/menu/customer load
→ open shift
→ create order
→ apply discount
→ pay
→ exact payment replay
→ receipt/print
→ refund
→ paid-order normal mutation/cancel rejection
```

The test proves a single payment row on payment replay and preserves the order/payment rows after rejected cancellation. The service tests separately prove ledger source-event dedupe. No automatic ledger posting was invoked.

Existing Finance Setup, Chart of Accounts, and Journal Entry API contracts remain bearer-token accessible and their foundation/reversal endpoint tests pass. There is no dedicated Finance Flutter widget test; static analysis compiled the feature and no Finance UI source changed in Phase 0B.

## 22. Remaining Technical Debt

- The refund concurrency test does not use truly concurrent PostgreSQL sessions (§10).
- Legacy POS/report/shift float arithmetic remains outside Phase 0B.
- `ShiftController::close()` remains refund-unaware; this is explicitly deferred to POS/Shift Finance integration.
- Finance authorization remains the existing coarse `FinancialActor` owner/manager gate; granular Finance permissions are future work.
- Finance Flutter screens lack focused widget/integration tests.

## 23. Explicit Deferred Features

Phase 0B does **not** include:

- Finance Dashboard
- Cash & Banks
- Expenses
- Suppliers/AP
- POS automatic journal posting
- POS COGS posting
- Inventory automatic accounting posting
- Reconciliation
- Daily Closing
- Financial Reports

## 24. Phase 0B Acceptance Matrix

| Criterion | Result | Evidence |
|---|---|---|
| Full backend suite passes | PASS | 77 tests / 666 assertions |
| Flutter has no new errors | PASS | `flutter analyze`: 0 errors/warnings |
| POS tenant-sensitive APIs authenticated | PASS | Route inspection + POS/discount auth tests |
| Tenant isolation preserved | PASS | Token-derived `TenantContext`; POS/Finance isolation tests; order context validation |
| Order idempotency works | PASS | `MoneyIdempotencyApiTest` |
| Payment idempotency works | PASS | API and Flutter payment tests |
| Refund idempotency works | PASS | `MoneyIdempotencyApiTest` |
| Same key cannot mutate into another request | PASS | fingerprints + changed-payload tests |
| Cross-tenant same key works | PASS | payment tenant-key test |
| Flutter retry reuses same payment key | PASS | focused Cubit test |
| Refund race protected | PASS | locked payment + transaction; see SQLite limitation §10 |
| Paid order normal cancellation blocked | PASS | `PosApiSmokeTest` |
| Journal reversal correct | PASS | reversal test assertions |
| Original journal immutable | PASS | original stays posted, no edit/delete routes |
| Duplicate journal reversal prevented | PASS | lock, service check, DB unique constraint |
| Duplicate accounting source event prevented | PASS | service + DB uniqueness |
| DB-level uniqueness protects financial posting races | PASS | migration + `AccountingPostingService` handling |
| AccountingPostingService reuses JournalEntryService | PASS | `createDraft()` then `post()` only |
| No hard-coded account database IDs | PASS | tenant account-code resolution |
| No fake COGS | PASS | no business adapter wired |
| No Finance inventory cost calculation | PASS | no Inventory posting integration |
| Existing Finance UI still works | PASS | no UI changes; shared bearer client, static compile, finance endpoint tests |
| No Phase 1 feature implemented accidentally | PASS | no new Finance business UI/table/integration |

## 25. FINAL DECISION

**PHASE 0B: COMPLETE — READY FOR PHASE 1**

The Phase 0B safety and infrastructure scope is closed. The PostgreSQL concurrency test limitation and the listed legacy technical debt should remain visible, but neither requires Phase 1 functionality to be added before starting the next planned phase.
