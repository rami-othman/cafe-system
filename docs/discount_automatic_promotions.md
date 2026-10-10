# Automatic Promotions — product rules and contract

Builds on the Discount V3 contracts ([Phase 1](discount_v3_phase1_contract.md), [Phase 2](discount_v3_phase2_contract.md), [Phase 3](discount_v3_phase3_contract.md)) and the [Phase 4 acceptance](discount_v3_phase4_acceptance.md). Date: 2026-10-09.

## 1. Product decisions

| Question | Decision |
|---|---|
| Who turns it on? | Each cafe, in **Discount settings → Automatic promotions** (Owner, or a Manager with `discounts.settings.manage`). It is off for every cafe until they opt in; no data is changed by the rollout. |
| What is a promotion? | An active discount whose application mode is **Automatic**. It can be created and edited at any time; it only applies while the cafe has promotions on. |
| Which rules apply? | The same Cafe Discount Policy as manual discounts and coupons: multiple discounts, same-item stacking, order-after-items, maximum count, maximum total %, best saving / priority, and per-discount Exclusive. There are no separate engine settings. |
| Cashier's choice vs promotion | A discount the cashier chose is **never displaced** by a promotion. Promotions are added around it only as far as the policy allows. With "one discount per order", a chosen discount wins over any promotion. |
| Several promotions qualify | Best saving: the combination with the highest total saving (ties: fewer discounts, then lower ids). Priority: higher priority first (then lower id), each kept if it still fits and saves something. At most 8 promotions are considered per order (the 8 best standalone savings, or the 8 highest priorities). |
| Not eligible / zero saving | Silently not applied (expired, inactive, wrong branch/channel/customer, minimum not met, usage limit reached, no matching items, zero value). Not shown as "Not applied": nobody asked for it. |
| Payment-method restriction | A promotion limited to a tender waits until the tender is chosen. The result is `provisional` with `DISCOUNT_TENDER_PENDING`, and the payment quote applies it. |
| Removing a promotion from one order | Only roles with `discounts.automatic.suppress`, only while "Allow managers to remove a promotion" is on, and only with a reason (audited). It can be restored. It applies to that order only. |
| Older apps | Once a cafe turns promotions on, older POS clients are refused (`DISCOUNT_CLIENT_UPDATE_REQUIRED`) before any discount change or payment, as for multi-discount orders. |

## 2. Backend changes

- **Migration `2026_10_13_000001_allow_automatic_discounts`.**
  - Removes only `NOT automatic_enabled` from `discount_settings_values_check`; every other rule is unchanged.
  - No row is updated.
  - `down()` refuses while any cafe has promotions on (roll forward instead of silently switching cafes off).
- **Gates opened:**
  - `PUT /cafe-configuration/discount-settings` accepts `automaticEnabled: true`.
  - `POST/PUT /discounts` accepts `applicationMode: automatic` (still without a code).
  - `engineReady` is `true` in settings and capabilities, and `automaticPolicyCreationAvailable` is `true`.
- **Engine (`DiscountResolutionService::resolveWithAutomatic`).** Used when the cafe has `automaticEnabled`.
  1. Explicit intents are resolved exactly like `resolveSet`, including strict errors in preview, apply, quote and payment.
  2. Promotions are discovered and ranked, then added by `conflictResolution` without displacing any explicit discount.
  3. The usual sequence applies (item level, then order level; explicit before promotions within a level), with sequential stacking, the shared total cap and integer cents.
  4. With promotions off, the previous engine path is unchanged. That path includes the testing-only isolated Automatic authority used by the Plan 2 tests.
- **Persistence.**
  - Promotions are written to `order_discounts` with `source: automatic` and the usual snapshot, allocations and sequence.
  - They are **never saved as explicit intents** (`set` stores only explicit discounts); every resolution recomputes them.
  - Payment consumes one usage per applied promotion, exactly like other discounts.
- **Staleness.** Creating, editing or ending a promotion, a policy change, or a cart change changes the fingerprint. An open review then fails with `DISCOUNT_REVIEW_STALE` and an open quote with `ORDER_TOTAL_CHANGED`. Payment never settles stale math.
- **Discount state.** `suppressions[]` now includes the promotion `name` (additive).

## 3. Flutter changes

- **Discount settings:**
  - A new **Automatic promotions** card with two switches:
    - **Apply automatic promotions.** Inactive against an older backend that cannot run them.
    - **Allow managers to remove a promotion from an order.** Kept but inactive while promotions are off.
  - The live summary shows whether promotions are on.
  - **Reset** turns promotions off and restores removal to allowed.
- **Create/Edit:** choosing **Automatic** explains what it does, and warns when the cafe has promotions off.
- **POS:**
  - Promotions appear as **Automatic promotion / عرض تلقائي** lines without the ordinary remove button.
  - **Remove promotion** (with reason) and **Restore promotion** appear for authorized roles.
  - Removed promotions are listed by name.
- **Receipt:** the printed source label is **Automatic promotion / عرض تلقائي**.

## 4. Verification

- **Backend:**
  - New `DiscountAutomaticPromotionsTest` (14 tests). It covers:
    - opt-in and cafe isolation
    - best saving and priority
    - combining under the policy, and the total cap
    - an explicit discount never displaced, and Exclusive
    - silent ineligibility
    - cart changes
    - set saving only explicit intents
    - suppression and undo with the promotion name
    - tender-pending promotions
    - payment, idempotency and usage limits
    - staleness after a new promotion
    - the 8-candidate limit and determinism
    - blocking legacy clients
    - the rollback refusal
  - Old "automatic is locked" assertions were updated to the new product decision; they now assert that creating an automatic discount with a coupon code is still rejected.
  - All Discount backend tests: **195 passed**, 3144 assertions.
- **Flutter:**
  - New `discount_automatic_settings_test.dart` (4).
  - Create/Edit Automatic notice (2).
  - Suppression name parsing (1).
  - Updated source label.
  - Settings, discounts, POS, printer and shared suites pass, except the 3 known baseline `orders_payment_screen_test` failures.
- **Not yet done:**
  - native Windows manual acceptance in EN/AR
  - a physical receipt
  - applying the migration to a real database

## 5. Rollout

1. Deploy the backend and run `php artisan migrate` (adds no data; every cafe stays off).
2. Deploy the updated POS/Windows client to every till of a cafe **before** that cafe turns promotions on. Older clients are refused once it does.
3. The cafe creates its promotions (Discounts → Create → Automatic), checks them, then turns on **Automatic promotions** in Discount settings.
4. **To stop:** turn the switch off; promotions stay saved and simply stop applying. Paid orders keep their snapshots.
