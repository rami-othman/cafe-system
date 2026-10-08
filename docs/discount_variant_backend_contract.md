# Discount product variant contract — backend Plan 1

Discount V3 Phase 1 (2026-10-07) adds variant scope to Package / Bundle requirements and a per-discount `combinationBehavior`: see [Discount V3 Phase 1 contract](discount_v3_phase1_contract.md).

Date: 2026-10-01 (Asia/Damascus). Scope: D1-01 through D1-08 only.

Current staged-engine authority (2026-10-03): see the [Plan 2 backend contract](discount_settings_backend_contract.md) for additive priority, discounts[], review/quote/replay, policy-specific usage and capability gates. The Plan 1 verification/history below records its original phase; its single-discount client behavior remains the compatible default.

## Routes and authorization

All routes use authenticated tenant context; client tenant headers cannot widen access.

| Route | Permission | Purpose |
|---|---|---|
| `POST /api/v1/discounts` | `discounts.manage` | Create a policy |
| `PUT` / `PATCH /api/v1/discounts/{id}` | `discounts.manage` | Full policy replacement |
| `GET /api/v1/discounts/{id}` | `discounts.view` | Complete saved detail |
| `GET /api/v1/discounts/references/products` | `discounts.manage` | Active product selector |
| `GET /api/v1/discounts/references/products/{productId}/variants` | `discounts.manage` | Active variants for one active product |

Reference routes precede the dynamic discount route. Catalog management routes still require Menu management permission. Reference permission grants no additional Menu access. Only names, identities and lifecycle flags are returned; no prices, costs, recipes or Inventory configuration.

Existing apply/remove/payment routes, branch authorization, case-insensitive Code application and coupon secrecy are preserved. Manual and Code policies support percentage and fixed; `per_unit` remains limited to fixed/product scope. One applied policy replaces the previous discount. Completed payment consumes at most one usage per order, including idempotent replay.

## Create/update request

Example of a complete, unconstrained product policy (IDs are illustrative):

```json
{
  "name": "Selected sizes",
  "code": null,
  "description": null,
  "applicationMode": "manual",
  "type": "fixed",
  "scope": "product",
  "fixedAmountBasis": "per_unit",
  "value": "5.00",
  "conditions": null,
  "startsAt": null,
  "endsAt": null,
  "startDate": null,
  "endDate": null,
  "activeDays": [],
  "startTime": null,
  "endTime": null,
  "minimumOrderAmount": "0.00",
  "maximumDiscountAmount": null,
  "usageLimit": null,
  "usageLimitPerCustomer": null,
  "perCustomerDailyUsageLimit": null,
  "customerEligibilityMode": "all",
  "customerGroupIds": [],
  "customerIds": [],
  "paymentMethodIds": [],
  "channelKeys": [],
  "isActive": true,
  "appliesToAllBranches": true,
  "branchIds": [],
  "targetProductIds": [12, 20],
  "targetCategoryIds": [],
  "bundleRequirements": [],
  "productVariantSelections": [
    {"productId": 12, "variantMode": "selected", "variantIds": [101, 102]},
    {"productId": 20, "variantMode": "all", "variantIds": []}
  ]
}
```

For Code use `applicationMode: "code"` and a nonempty code. Existing dates, overnight schedules, branches, groups, selected customers, channels, payment methods, bundle requirements and usage limits retain their established validation and full replacement semantics. Nullable fields clear through explicit `null`; empty target arrays clear the corresponding targets where the scope permits. Time writes use `HH:mm`; detail returns database `HH:mm:ss`. Monetary inputs accept JSON numbers or decimal strings with at most two nonzero decimal places. Percentages range from zero through 100. Zero configured policies remain valid; free-form POS manual discounts retain their separate validation.

`targetProductIds` remains the parent product authority. `productTargets` is still the existing read-only array of `{id, name, isActive}`; its shape is unchanged.

## New selection validation and legacy compatibility

- When supplied, `productVariantSelections` must be a list with exactly one entry for every target product. Each write entry has exactly `productId`, `variantMode`, and `variantIds`.
- `all` requires an empty list. `selected` requires a nonempty list of unique positive integer identities belonging to that product and tenant.
- Reject duplicate products/variants, missing/extra products, malformed entries, unknown modes, foreign IDs and wrong-parent variants. Explicit selections require active, non-archived products and variants.
- Non-product scopes omit the field entirely, including when empty. `null` is invalid, not a clear command.
- Legacy policies and creates omitting the field mean all variants.
- Legacy updates omitting the field preserve saved variant IDs for retained products, including saved inactive/archived variants; new products default to all and removed products lose their variant rows. Existing validation still rejects inactive/archived parent products on writes.
- A new client sends all entries explicitly. A saved inactive/archived variant remains visible; explicitly resubmitting it is rejected and requires correcting/removing that selection. Omission is only the legacy preservation exception.
- Explicit `selected` → `all` clears variant rows. Empty `selected` is never interpreted as all. Switching away from product scope removes parent/variant targets atomically.

Validation responses use the existing HTTP 422 envelope with localized `message` and `errors`. Selection errors are keyed by `productVariantSelections`; parent product errors use `targetProductIds`. No new error-code envelope is introduced. Runtime rejection retains `DISCOUNT_ITEMS_NOT_ELIGIBLE`, customer/branch/schedule/usage/payment codes. Foreign reference products return 404, missing permission 403, and invalid page/search parameters 422.

## Detail response addition

Create, update, list and detail use the existing `data` envelope and retain every existing management response field. The additive field is explicit for every saved product target; it is `[]` for other scopes.

```json
{
  "data": {
    "targetProductIds": [12, 20],
    "productTargets": [
      {"id": 12, "name": "Coffee", "isActive": true},
      {"id": 20, "name": "Tea", "isActive": true}
    ],
    "productVariantSelections": [
      {
        "productId": 12,
        "variantMode": "selected",
        "variantIds": [101, 102],
        "product": {"id": 12, "name": "Coffee", "nameAr": "قهوة", "nameEn": "Coffee", "isActive": true, "archivedAt": null},
        "variants": [
          {"id": 101, "name": "Small", "nameAr": "صغير", "nameEn": "Small", "isActive": true, "archivedAt": null},
          {"id": 102, "name": "Large", "nameAr": "كبير", "nameEn": "Large", "isActive": false, "archivedAt": "2026-10-01 10:00:00"}
        ]
      },
      {
        "productId": 20,
        "variantMode": "all",
        "variantIds": [],
        "product": {"id": 20, "name": "Tea", "nameAr": "شاي", "nameEn": "Tea", "isActive": true, "archivedAt": null},
        "variants": []
      }
    ]
  }
}
```

This is a response excerpt, not the entire policy. Flutter must hydrate from full detail and preserve all existing policy fields. Strip read-only `product`/`variants` metadata from selection write entries. Do not replace saved IDs with the currently fetched active-reference page. Check both `isActive` and `archivedAt`; archival can occur without setting `isActive` false. Selected IDs are sorted ascending in detail; entries follow the saved parent targets.

## Reference pagination

Both reference routes accept `search` (optional, maximum 100 characters, case-insensitive substring across default/Arabic/English names), `perPage` (1–100; default 20), and `page` (positive integer). Stable ordering is name then ID. Every count/page is tenant scoped. Products and variants must be active and non-archived; saved unavailable selections come from detail instead.

Example: `GET /api/v1/discounts/references/products?search=coffee&perPage=100&page=2`.

```json
{
  "data": [
    {"id": 120, "name": "Coffee", "nameAr": "قهوة", "nameEn": "Coffee", "isActive": true, "archivedAt": null}
  ],
  "meta": {"currentPage": 2, "lastPage": 2, "perPage": 100, "total": 101}
}
```

The variant route returns the same selector shape and pagination envelope. The requested product ID is carried in the path. Continue through `meta.lastPage` to reach products/variants beyond the first 100, and keep saved selections independently of pages/searches.

## Matching, precision and history

All three calculations use one matcher. An item must match the product parent and, when rows exist for that parent, its persisted `order_items.product_variant_id`. A null legacy variant qualifies for all only. Names, live prices, live default variants and catalog lifecycle flags never infer or replace pinned line identity. Catalog archival after configuration preserves saved selection identity and the current pinned order rules.

The base is persisted modifier-inclusive `order_items.total`; quantities use the existing three-decimal order-line scale. Minimum spend uses the whole order's pre-discount subtotal. Product matching does not broaden through an OR product predicate.

- Percentage: eligible subtotal × percentage / 100, exact decimal.
- Fixed/per_order: apply value once, capped at the eligible subtotal.
- Fixed/per_unit: compute value × each eligible quantity exactly, cap each line at its persisted selling total, sum without intermediate cent rounding, then apply the policy cap.
- Apply policy maximum and eligible-subtotal caps, prevent negative amounts, then round the final policy amount to two decimals, HALF_UP.
- Aggregate unpaid order totals exactly. Compute tax on subtotal minus discount, rounding tax to cents HALF_UP at the existing tax boundary, then add tax.

Example: two eligible quantities of `0.500` at fixed `0.01` produce exact half-cent contributions; the sum is `0.01`, not `0.02`. A 50% discount on eligible `0.03` rounds to `0.02`. Cent-boundary differences from the previous float implementation can affect unpaid recalculation only. Existing API monetary number formats remain unchanged; internal calculated amounts are exact decimal strings used for database writes. This phase does not refactor unrelated Menu/Finance calculations.

Draft/held cart and customer mutations revalidate or remove ineligible policies; payment rejects invalid policy changes before settlement/usage. Paid/refunded order recalculation returns the original persisted order unchanged. Policy/catalog edits do not rewrite historical item, discount, payment or receipt totals.

## Storage, locks and rollout

Apply existing migrations through `2026_09_30_000002_add_fixed_amount_basis_to_discounts.php`, then `2026_10_01_000001_create_discount_product_target_variants.php`, before deploying this backend and then the Flutter client. No non-testing migration was authorized or applied in this phase.

The additive table stores tenant, policy, parent product, variant and `discount_target_id`, with a product-only discriminator for the composite FK. Composite constraints enforce both parent target identity and variant tenant/product ownership. Uniqueness is tenant/policy/product/variant. Lookup/FK indexes support matching and parent deletion. Parent replacement cascades child cleanup inside the same transaction; variant hard deletion is restricted to prevent selected silently becoming all. Soft archival keeps rows readable.

Create/update validates inside the persistence transaction as well as at the request boundary. Updates lock the same policy row used by apply/recalculation/payment. Legacy preserved IDs are read only after that lock. Detail serialization takes a shared policy lock so readers cannot observe intermediate parent/child replacement. No duplicate JSON authority, blanket backfill or historical order rewrite is introduced. Absence of variant rows means all, so legacy records need no backfill.

Do not downgrade to a backend that ignores these rows while selected policies remain executable. Disable affected discount operations until a safe roll-forward if a downgrade is necessary. Production deployment/migration remains a separately authorized operation.

## Verification record

All Laravel runs were serial. The primary database was confirmed as `cafe_system_618_testing`; migration/independent-worker tests confirmed `cafe_system_618_testing_migrations`. No development/production migration command was run. Existing Laravel test database lifecycle traits were used; no manual database reset or reseed was used to recover a failing check.

| Final check | Result |
|---|---|
| Required five Discount suites, exact command below | 27 passed, 289 assertions, 74.38s |
| Variant backend + variant concurrency/migration + snapshot POS suites | 19 passed, 238 assertions, 54.41s |
| POS/payment/receipt/refund regression group below | 42 passed, 348 assertions, 195.31s |
| Existing concurrent final-use payment/usage regression | 1 passed, 7 assertions, 39.94s |
| Scoped Pint (`--test`, 11 changed PHP files excluding existing route-file formatting) | Passed |
| `php -l routes/api.php` | Passed |
| `git diff --check` | Passed |

```powershell
docker compose exec -T backend php artisan test --filter='DiscountManagementApiTest|DiscountV1ContractTest|DiscountV2BackendTest|DiscountSecurityHardeningTest|DiscountRuntimeEligibilityTest'

docker compose exec -T -e APP_ENV=testing -e DB_DATABASE=cafe_system_618_testing -e DB_URL= backend php artisan test --filter='DiscountVariantBackendTest|DiscountVariantConcurrencyTest|SnapshotAwarePosOrderApiTest'

docker compose exec -T -e APP_ENV=testing -e DB_DATABASE=cafe_system_618_testing -e DB_URL= backend php artisan test --filter='PosApiSmokeTest|SnapshotAwarePosOrderApiTest|MoneyIdempotencyApiTest|OrderRefundableBalanceApiTest|RefundAccountingApiTest|ReceiptTemplateConfigurationTest|PosPrintingApiTest'

docker compose exec -T -e APP_ENV=testing -e DB_DATABASE=cafe_system_618_testing -e DB_URL= backend php artisan test --filter='PreAuthFinancialConcurrencyTest::test_concurrent_final_discount_usage_is_consumed_once'
```

The broad regression command matched six existing classes; `PosPrintingApiTest` is not a class in this checkout. Receipt/print-job runtime checks are in `PosApiSmokeTest`. Snapshot tests overlap between the two groups; the counts above are individual command results, not unique-test totals.

The new contract/runtime/reference tests first produced four expected failures before implementation. Final concurrency verification observes real PostgreSQL row-lock waits from independent PHP workers; polling clears PostgreSQL statistics snapshots inside the parent transaction. The existing final-use race initially failed before usage checks because its old shift fixtures lacked a cash drawer. That test now provisions testing-only Finance mappings and binds both competing orders to one open drawer shift, preserving every payment/usage assertion and adding worker-result diagnostics. No production payment/shift behavior was relaxed.

No remaining backend verification blockers. A repository-wide suite, Flutter checks and physical printer output were not run for this backend phase. Only D1-01 through D1-08 are marked complete; D1-09 onward and Plan 2 remain pending.

## Changed file inventory

- `backend/app/Http/Controllers/Api/DiscountController.php`: validation, policy lock, atomic persistence coordination, consistent detail serialization and exact apply persistence.
- `backend/app/Services/DiscountProductVariantService.php`: selections, legacy preservation, lifecycle metadata and child storage.
- `backend/app/Services/DiscountEligibilityService.php`: shared item matcher and exact policy calculations.
- `backend/app/Services/PosPricingService.php`: exact unpaid totals/tax and paid-history guard.
- `backend/app/Http/Controllers/Api/DiscountReferenceController.php` and `backend/routes/api.php`: bounded Discount selectors and permission routes.
- `backend/database/migrations/2026_10_01_000001_create_discount_product_target_variants.php`: additive schema and referential protections.
- `backend/tests/Feature/DiscountVariantBackendTest.php`, `DiscountVariantConcurrencyTest.php`, `SnapshotAwarePosOrderApiTest.php`, `PreAuthFinancialConcurrencyTest.php`, and `backend/tests/Fixtures/DiscountVariantWorker.php`: contract/security/runtime/history/migration/payment/concurrency evidence.
- This document and `plans/discount_create_edit_variant_implementation_plan.md`: Flutter handoff and verified backend task status.

Initial worktree contained only the two untracked implementation plans. Plan 2 was preserved without edits. No frontend files, commits or deployment artifacts were changed.
## Plan 2 engine addendum — 2026-10-03

Plan 1 target/variant matching and legacy single replacement remain intact. The staged backend engine reuses that matcher; the current multi-policy settlement guard is policy-specific `(tenant_id,order_id,discount_id)`, superseding any foundation description of one usage per whole order. Authoritative operational review/quote/allocations, compatibility and activation gates are documented in `docs/discount_settings_backend_contract.md`. Automatic remains publicly unavailable; `engineReady=false`. Flutter implementation and final acceptance remain separate phases.

