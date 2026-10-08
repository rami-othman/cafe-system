# Discount System V3 — Phase 1 contract and completion report

Source plan: [plans/discount_system_v3_implementation_plan.md](../plans/discount_system_v3_implementation_plan.md) (unchanged).
Date: 2026-10-07. Scope: domain, database and API foundation only. **The runtime is still the single-managed-discount engine.** Nothing here enforces multiple discounts, stacking, coupon combination or conflict resolution; that is Phase 2.

## 1. Cafe Discount Policy (`tenant_discount_settings`)

Extended additively (migration `2026_10_11_000001`). Same endpoints, same `expectedVersion` optimistic lock, same Owner / authorized-Manager boundary (`discounts.settings.manage`), same audit.

| API field | Column | Values | Default / legacy rows |
|---|---|---|---|
| `allowMultipleDiscounts` | `allow_multiple_discounts` | boolean | `false` |
| `stackingMode` | `stacking_mode` | `different_items_only`, `same_item_allowed` | `different_items_only` |
| `allowMultipleCoupons` | `allow_multiple_coupons` | boolean | `false` |
| `allowCouponWithConfigured` | `allow_coupon_with_configured` | boolean | `false` |
| `allowOrderAfterItemDiscounts` | `allow_order_after_item_discounts` | boolean | `false` |
| `maximumDiscountsPerOrder` | `maximum_discounts_per_order` | integer 1..10 | `1` |
| `conflictResolution` | `conflict_resolution` | `best_saving`, `priority` | `best_saving` |
| `maximumTotalDiscountPercent` | *(existing)* `maximum_total_discount_percent` | null or (0, 100], 4 dp | unchanged |

- `maximumTotalDiscountPercent` was **not** duplicated. The legacy column is the single source of truth and existing tenant values are untouched.
- `lowest_saving` is not a V3 `conflictResolution` value. It remains only in the legacy `selectionStrategy` field.
- GET always returns the V3 fields (defaults when no row exists). PUT accepts them as **optional** fields: an older client that sends only the legacy eight fields keeps working and never resets saved V3 values. Types are strict (JSON booleans / integer). Unknown fields are still rejected.
- DB `CHECK discount_settings_v3_policy_check` backs the enums and the 1..10 range.
- Cross-field rules are deliberately not enforced in Phase 1 (for example `maximumDiscountsPerOrder > 1` with `allowMultipleDiscounts=false` is storable). Phase 2 must treat the effective maximum as 1 when `allowMultipleDiscounts=false`.

### Legacy / internal fields (kept, not removed)

`automaticEnabled`, `selectionStrategy`, `combinationMode`, `orderDiscountBehavior`, `couponBehavior`, `manualBehavior`, `allowAutomaticSuppression` stay readable and writable and **still drive the current runtime**. They are engine terminology and should leave the public Settings UI in Phase 3 (`DiscountSettingsService::LEGACY_DEFAULTS` marks them). `automaticEnabled=true` is still rejected (`DISCOUNT_ENGINE_NOT_READY`); `engineReady` is still `false`.

## 2. Per-discount `combinationBehavior` (`discounts.combination_behavior`)

Migration `2026_10_11_000002`. Values `follow_cafe_policy` (default, also for every existing row) and `exclusive`; DB `CHECK discount_combination_behavior_check`.

- Create/update accept `combinationBehavior`; list/detail return it.
- Omitted on update keeps the saved value (older clients cannot reset an exclusive discount).
- Meaning: a discount may only restrict the cafe policy. It can never widen it. **Not enforced yet** (Phase 2).

## 3. Package / Bundle variant requirements

Table `discount_bundle_requirement_variants` (migration `2026_10_11_000003`), modeled on `discount_product_target_variants`:

- Composite FKs: `(discount_bundle_requirement_id, tenant_id, discount_id, product_id)` → `discount_bundle_requirements` (cascade) and `(product_variant_id, tenant_id, product_id)` → `product_variants` (restrict). A wrong-product or cross-tenant variant cannot be stored; a hard-deleted variant cannot silently turn `selected` into `all`.
- **A requirement with no rows means all variants.** No backfill.

API (`bundleRequirements[]`): `{ productId, quantity, variantMode: all|selected, variantIds: int[] }`; reads also return `variants: [{id,name,nameAr,nameEn,isActive,archivedAt}]`.

Write rules (422 on any violation, nothing is persisted): `variantMode` required when `variantIds` is sent; `selected` needs 1+ ids; `all` needs none; ids are positive integers, no duplicates (rejected, consistent with product-variant selections); every id must belong to the requirement's product and tenant and be active and not archived. Neither field sent (older client): the saved selection for that product is preserved. Read of a legacy row: `variantMode: "all"`, `variantIds: []`.

Runtime (`DiscountEligibilityService::bundleSubtotal`, `DiscountResolutionService::bundleWeights`) now ignores order lines whose variant is not selected; a `selected` requirement is not satisfied by a line with no variant. Quantity, "every requirement must match", one package per order and the subtotal basis are unchanged. Paid-order `policy_snapshot.bundleRequirements[]` additionally carries `variantMode`/`variantIds`, and the engine fingerprint includes the new table.

## 4. Short generated coupon codes

`App\Services\CouponCodeGenerator`, used by `POST /discounts/generate-code`:

- 5 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no `O 0 I 1`), `random_int`, uppercase.
- Collision check is tenant-scoped, case-insensitive and ignores soft-deleted discounts, with at most 16 attempts, then a 422 on `code`. The partial unique index `discounts_tenant_lower_code_unique (tenant_id, LOWER(code)) WHERE deleted_at IS NULL` (already present) remains the final authority at save time; the generate endpoint does not reserve a code. If two clients save the same generated code, the loser gets a 422 validation error on `code` (create and update both catch the unique violation; no 500), and the client calls `generate-code` again. Proven by `DiscountV3CouponSaveRaceTest` with an independent worker process.
- Existing and manually entered codes are untouched: stored uppercase, up to 100 characters, same uniqueness. Old `CPN-XXXX-XXXX` codes keep working.

## 5. Flutter (contract compatibility only)

No Settings redesign and no new UI controls. `DiscountDetail`/`DiscountUpsertRequest` carry `combinationBehavior` (default `follow_cafe_policy`) so edits never reset it. `DiscountBundleRequirement` carries `variantMode/variantIds/variants`; they are omitted from writes when the server did not send them. The create/edit screen restores a saved variant scope, writes it back on save, shows it read-only (`Selected variants: Large, Iced`) and resets it to all variants when the row's product changes. `SavedDiscountSettings.policy` (`DiscountCafePolicy`) parses the V3 policy with safe defaults; `DiscountSettingsDraft.toJson` is unchanged, so the current Settings screen does not send V3 fields. **Phase 3 handoff:** package variant picker, `combinationBehavior` selector (hidden now because it would be a meaningless control before Phase 2), and the Settings policy UI.

## 6. Phase 2 must know

- Policy fields are persisted but ignored by the runtime; read them from `DiscountSettingsService::read()`.
- `DiscountResolutionService::requiresContract()` still keys off legacy `combinationMode`/`maximumTotalDiscountPercent`/automatic; decide how V3 `allowMultipleDiscounts` replaces that gate. Legacy `apply` still deletes all `order_discounts` and inserts one row.
- `discount_usages` is still unique per order in the legacy path; V3 usage rules belong to Phase 2.
- `maximumTotalDiscountPercent` is already consumed by the engine budget; keep it as the only total-limit source.
- A bundle already matches by variant; same-item stacking must use `discount_product_target_variants` and the new table consistently.
- The DB is PostgreSQL-only (partial/expression indexes, advisory locks, composite FKs).
- Existing `productVariantSelections` quirk: an empty list is rejected by `sometimes|required|array`; clients must omit it for non-product scopes.

## 7. Verification (2026-10-07)

See the final implementation report in the session; focused suites: `DiscountV3PolicySettingsTest`, `DiscountV3PackageVariantsTest`, `DiscountV3CouponsAndCombinationTest`, Flutter `discount_v3_contract_test.dart` and an edit-screen test in `create_discount_policy_screen_test.dart`.
