# Discount System V3 — Phase 2 contract (multi-discount backend runtime)

Source plan: [plans/discount_system_v3_implementation_plan.md](../plans/discount_system_v3_implementation_plan.md). Builds on [discount_v3_phase1_contract.md](discount_v3_phase1_contract.md). Backend only: no Flutter UI, Automatic Discounts stay disabled (`automaticEnabled=true` is still rejected, `engineReady=false`).

## 1. Architecture findings

- `order_discounts` was already multi-row and `discount_usages` was already unique on `(tenant_id, order_id, discount_id)` (migration `2026_10_03_000002`; the Phase 1 note that it was unique per order was stale). Neither needed a structural change.
- The single-discount limit was the saved *intent*: `order_discount_intents.intent` held one `{source, discountId}`. It now holds either that legacy object or an ordered list. `DiscountResolutionService::intents()` normalizes both.
- One engine is extended; there is no parallel one. `DiscountResolutionService::resolve()` keeps its legacy selection (`selectSingle`) for 0 or 1 explicit intent, including its Automatic candidate handling, and uses the new V3 path (`resolveSet`) for 2+ explicit intents.
- Refunds work from the completed payment amount (`payments.amount`, net of discounts) and never read discount rows, so they are correct for any number of discounts and unaffected by later policy changes. No refund code changed.
- Receipt / order detail already serialize `discounts[]` and `requiresDiscountBreakdown` from `DiscountEngineProtocol::state()`.

## 2. Schema (one additive migration)

`2026_10_12_000001_add_order_discount_application_sequence`: `order_discounts.application_sequence` (smallint, nullable, `>= 1`) + index `(tenant_id, order_id, application_sequence, id)`. Rows written before V3 keep NULL and sort by id. Rollback drops the column and index. Per-discount policy context is stored in the existing `calculation_metadata` (`calculationVersion 2`: sequence, capped, stacking, effective policy) and `policy_snapshot` (`combinationBehavior`, `capped`, `sequence`).

## 3. Intent contract (API)

Same endpoints, contract version stays `2` (`X-Discount-Contract: 2`).

`POST /orders/{order}/discounts/preview`

| action | body | meaning |
|---|---|---|
| `set` (new) | `intents: [{source: configured_manual\|code, discountId \| code}, ...]` 1..10 | one reviewed, ordered set that **replaces** every explicit intent |
| `apply` (legacy) | `intent: {...}` | replaces the whole set with exactly one discount (never additive) |
| `remove` | | clears all explicit intents |
| `suppress`/`undo` | | unchanged (Automatic only) |

The client sends intent only. A coupon code is resolved to `discountId` and never stored. `ad_hoc` is not accepted in a set. Money fields are never accepted. A duplicate discount (including the same coupon by code twice) returns 422 `DISCOUNT_DUPLICATE_INTENT`. `apply` (`POST .../discounts/operations`) re-resolves, compares the review fingerprint (`DISCOUNT_REVIEW_STALE`) and saves the **applied** result: excluded requests are not saved. Operation identities stay idempotent.

`GET /orders/{order}/discount-state` adds `explicitIntents[]` (ordered; `explicitIntent` = first, for old clients), `policy`, and per discount `sequence`, `combinationBehavior`, `capped`. `GET /discount-capabilities` adds `supportsMultipleDiscounts`, `maximumRequestedDiscounts` (10) and `policy`.

## 4. Quote / review result (`preview`, `payment-quote`, `apply` result)

Existing keys kept. New keys on every result (legacy single path included):

- `requested[]`: `{position, source, discountId}` in reviewed order.
- `discounts[]`: authoritative applied list in application order; each has `sequence` (1-based), `amount`, `allocations[]` per line, `combinationBehavior`, `capped` (clamped by the total cap), `stage`.
- `excluded[]`: `{position, discountId, name, source, code, conflictsWith[]}`; also mirrored into the legacy `reasons[]`.
- `policy`: effective policy `{allowMultipleDiscounts, effectiveMaximumDiscounts, stackingMode, allowMultipleCoupons, allowCouponWithConfigured, allowOrderAfterItemDiscounts, maximumTotalDiscountPercent, conflictResolution, settingsVersion}`.
- `totals` = `{subtotal, discountTotal, taxTotal, total}` (`total` is the payable amount), `fingerprint`, `reviewId`/`quoteId`, `expiresInSeconds`.

Flutter must not recalculate money.

## 5. Policy enforcement

Effective maximum count = `allowMultipleDiscounts ? maximumDiscountsPerOrder : 1`; the saved value is never rewritten. A request that cannot wholly coexist is **resolved, not rejected**: the retained set is chosen by `conflictResolution` and every dropped request is reported in `excluded[]` with a stable code. Individual ineligibility (inactive, expired, wrong branch/channel/customer/payment method, minimum, usage limits, no matching items/variants) still **throws** the existing domain code (422) in strict contexts (preview, apply, quote, payment) and is excluded only during draft/held cart recalculation.

Exclusion codes, checked in this order: `MULTIPLE_DISCOUNTS_DISABLED`, `EXCLUSIVE_DISCOUNT_CONFLICT`, `MAXIMUM_DISCOUNT_COUNT_EXCEEDED`, `MULTIPLE_COUPONS_DISABLED`, `COUPON_COMBINATION_NOT_ALLOWED`, `ORDER_ITEM_COMBINATION_NOT_ALLOWED` (structural, pre-calculation), then from the sequential calculation: `SAME_ITEM_STACKING_DISABLED`, `MAXIMUM_TOTAL_DISCOUNT_EXCEEDED`, `DISCOUNT_ITEMS_NOT_ELIGIBLE` (nothing left to discount), and `DISCOUNT_CONFLICT` (generic fallback). Existing codes were reused; `DISCOUNT_QUOTE_STALE` was not added: staleness keeps the established `ORDER_TOTAL_CHANGED` (payment quote) and `DISCOUNT_REVIEW_STALE` (review). New thrown code: `DISCOUNT_DUPLICATE_INTENT`.

- Level: product, category and bundle (package) discounts are item-level; `scope=order` is order-level. A coupon is `source=code`; configured is `configured_manual`.
- `exclusive`: cannot coexist with any other applied discount, including another exclusive one. Individual behavior can only restrict the cafe policy.

## 6. Application order and calculation

1. Retained set = result of `conflictResolution`.
   - `best_saving`: among all structurally valid subsets (depth-first with pruning, at most 10 requested) the highest total saving; ties: fewer applied discounts, then lexicographically lower discount ids.
   - `priority`: candidates sorted by priority **descending** (higher number is stronger, unchanged from the legacy engine), then discount id ascending; each is kept if the set stays structurally valid and every kept discount still produces a saving.
2. **Authoritative sequence** = item-level first, then order-level; within a level, the reviewed (`intents`) order. Conflict resolution never reorders retained discounts. Persisted as `application_sequence` and in the saved intent list; payment replays it.
3. Each discount is calculated sequentially on what the previous ones left (e.g. 100 → 10% → 90 → 20% → 72, total 28), integer cents, HALF_UP, largest-remainder allocation per line. A package after another discount is priced on the remaining value of its matched lines (`min(bundleAmount, recomputed)`, identical on pristine lines).
4. The existing `maximumTotalDiscountPercent` budget is shared by the whole set: later discounts are clamped (`capped=true`) or excluded (`MAXIMUM_TOTAL_DISCOUNT_EXCEEDED`). No other cap exists.
5. `different_items_only`: an item that an earlier discount already reduced is invisible to later discounts (actual allocation, not target definition), so a broad discount is calculated on the disjoint remainder and excluded only if none remains. `allowOrderAfterItemDiscounts=true` is the explicit exception: an order-level discount then runs on the residual of all lines after item-level discounts. Two order-level discounts always overlap. `same_item_allowed`: no masking.
6. Payable amount can never go negative (every step is clamped to the residual line balance).

Packages use Phase 1 selected-variant matching unchanged (Regular does not satisfy a Large requirement).

## 7. Quote, apply and payment safety

- The fingerprint hashes the ordered requested intents, the whole tenant policy set and targets, the full settings row (incl. `version`, all V3 flags), applied rows (incl. `application_sequence`), order, lines and result. Any change to order, discount, usage-relevant state, or Cafe Policy makes an existing review/quote stale. A policy edit that leaves the money identical still invalidates it.
- Payment (`confirmQuote`) re-resolves the **saved** intent list strictly and compares fingerprints, then persists the result and consumes usage. Retrying payment replays the stored payment (`PAYMENT_IDEMPOTENCY` unchanged).
- Usage: `consumeUsage` runs per applied discount, locks discount rows in ascending id order, re-checks global, per-customer and per-customer-per-day (branch-local business date) limits, and skips an existing `(order, discount)` row. One order consumes one usage per distinct discount, never twice for the same discount.
- Locking is unchanged: the per-tenant advisory lock (`20402`, shared with settings writes), the order row lock and the existing operation/payment idempotency locks. No new global lock.
- Held/draft orders: saved rows are pinned until the cart changes; a cart edit re-resolves the saved intent set non-strictly under the current policy (dropped discounts are excluded, the saved intent list is not rewritten). Paid orders and their rows/allocations are never rewritten.
- Zero-balance orders settle as before (`method = zero_balance`, usage and accounting unchanged).

## 8. Legacy client compatibility

`POST /orders/{order}/discounts/apply` and `DELETE .../discounts` (no contract header) still apply one discount and replace the previous one; `requiresContract()` is not widened by `allowMultipleDiscounts`. An order that already carries engine/multi-discount state returns `DISCOUNT_CLIENT_UPDATE_REQUIRED` to such clients. The v2 `preview`/`apply` with a single `intent` keeps replace semantics. Orders serialize `discount` (null when more than one) plus `discounts[]` / `requiresDiscountBreakdown` as before.

## 9. Phase 3 must know

- Send `action: "set"` with the full desired list; read `explicitIntents` and `discounts[].sequence` from `discount-state`. To add a discount, send the current list plus the new one; to remove one, send the list without it.
- Always show `excluded[]` from the review: with best_saving a newly added discount can displace an existing one. Map `code` to messages.
- Coupon text is never returned or stored; identify discounts by `discountId`/`name`.
- Automatic Discounts are not discovered when 2+ explicit intents are requested.
- Per-discount coupon code is not in order history; only name, source and amount.
