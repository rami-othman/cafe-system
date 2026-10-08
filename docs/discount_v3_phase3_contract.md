# Discount System V3 — Phase 3 (Flutter integration)

Source plan: [plans/discount_system_v3_implementation_plan.md](../plans/discount_system_v3_implementation_plan.md). Builds on the [Phase 1](discount_v3_phase1_contract.md) and [Phase 2](discount_v3_phase2_contract.md) contracts. Automatic Promotions stay disabled and have no controls.

## 1. Backend contract fix (the only backend change)

**Defect.** Phase 2 requires the POS to send the complete desired list with `action: "set"`. But coupon text is never stored or returned, and a `code` intent accepted only `{source: "code", code}`. So after a reload a client could not re-send a coupon that was already applied (for example when removing another discount).

**Fix.** In `DiscountEngineProtocol::explicit`, a `set` list may keep a coupon by `{source: "code", discountId}` **only if that coupon is already a saved explicit intent of the same order**. Otherwise it returns `DISCOUNT_NOT_FOUND` ("Enter the coupon code again"). A policy id alone can never redeem a coupon, no other order can borrow it, and sending both `discountId` and `code` is still rejected. Test: `DiscountV3MultiDiscountEngineTest::test_an_applied_coupon_can_be_kept_by_id_in_a_full_set_but_never_redeemed_by_id`.

## 2. Flutter contract

- `DiscountCapabilities`: `supportsMultipleDiscounts`, `maximumRequestedDiscounts`, `policy`.
- `SavedDiscountState.explicitIntents` (falls back to `[explicitIntent]` for older backends). `SavedDiscount.sequence / combinationBehavior / capped` are all optional, so historical orders still parse.
- `DiscountResolution.excluded: List<ExcludedDiscount>` with `{position, discountId, name, source, code, conflictsWith}`.
- `DesiredDiscountIntent`: `configured(id)`, `coupon(code)` (typed this session) and `savedCoupon(id)` (already on the order).
- `DiscountReviewRequest.set(list)`.
- `PosCubit.discountRequestAdding / discountRequestRemoving` build the **complete** list from the saved backend intents (adding appends, removing drops; an empty list sends `remove`). When the backend does not advertise `supportsMultipleDiscounts`, the legacy replace-one `apply` request is used.

## 3. UX

- **Discounts → Policies / Settings.** The canonical route is `/discounts/settings`. The old `/cafe-configuration/discount-settings` path redirects there, and the Cafe Configuration nav item points to it. Owner and Manager see the Settings tab; the backend still authorizes every read and write.
- **Settings.** The screen is in business language and has four sections:
  - General: allow multiple discounts.
  - Combining: same-item stacking, multiple coupons, coupon with configured, order after items.
  - Safety limits: maximum count 1..10, and the maximum total %.
  - Conflict resolution: best saving or priority.
  - Combining controls are disabled, not reset, while multiple discounts are off, so dormant values are saved unchanged.
  - Legacy engine fields are carried in the draft unchanged and never shown.
  - Reset restores only the public policy defaults.
- **Create/Edit.**
  - A Combination dropdown (Follow Cafe Policy / Exclusive) with a one-line explanation.
  - Priority help explains that it applies only under priority conflict resolution and that higher numbers win.
  - Package requirements have All / Selected variants and use the same paged, searchable variant picker as product targets.
  - Selected-variant mode needs at least one variant before submit.
  - Changing the product clears the previous product's variants.
  - Edit restores the saved selection as chips.
- **POS.**
  - The cart lists every applied discount in backend sequence, with source, the backend amount, a "reduced by the maximum limit" note, a per-line remove action and the backend total.
  - Selected intents the backend no longer applies stay visible as "Selected but not applied".
  - The review dialog shows Applied and Not applied lines (with localized reasons) plus before and after totals.
  - The payment quote dialog shows the same summary.
  - A stale review re-previews automatically. A stale quote refreshes and needs a second confirmation, and the amount field follows the refreshed total unless the cashier typed one.
- **Receipt / history.** Each discount is a line (numbered when there are several) and the total is labelled "Total discounts". A single-discount receipt or order keeps the "Discount" label. The printed receipt uses business source labels (Coupon / Configured discount). Coupon text is not shown: Phase 2 does not persist it (product follow-up if needed).

## 4. Reason codes (EN/AR)

Mapped: `MULTIPLE_DISCOUNTS_DISABLED`, `SAME_ITEM_STACKING_DISABLED`, `MULTIPLE_COUPONS_DISABLED`, `COUPON_COMBINATION_NOT_ALLOWED`, `ORDER_ITEM_COMBINATION_NOT_ALLOWED`, `EXCLUSIVE_DISCOUNT_CONFLICT`, `MAXIMUM_DISCOUNT_COUNT_EXCEEDED`, `MAXIMUM_TOTAL_DISCOUNT_EXCEEDED`, `DISCOUNT_CONFLICT`, `DISCOUNT_ITEMS_NOT_ELIGIBLE`, `DISCOUNT_DUPLICATE_INTENT`, `DISCOUNT_CLIENT_UPDATE_REQUIRED`, `DISCOUNT_REVIEW_STALE`, `ORDER_TOTAL_CHANGED`. Raw codes are never displayed.

## 5. Phase 4 must know

- The backend contract fix (§1) needs live acceptance with a real coupon re-sent by id.
- Native Windows EN/AR acceptance of the new Settings, picker and multi-discount POS flows is not done (widget tests only).
- 151 pre-existing Dart files fail `dart format --set-exit-if-changed`, and `flutter analyze` reports 29 pre-existing infos (sales and receipt-renderer test). None are Phase 3 files.
