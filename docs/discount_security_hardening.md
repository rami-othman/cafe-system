# Discount security, correctness and UX hardening

Applies to Discount System V3 + Automatic Promotions. Nothing here changes the
engine, quote/payment fingerprints, usage accounting, refund usage policy or
historical snapshots.

## Roles

| | Owner | Manager | Employee |
|---|---|---|---|
| Manage / view policies, coupon codes | yes | per `discounts.view` / `discounts.manage` | **never** |
| Cafe Discount Settings | yes | when granted | never |
| Apply eligible discounts and enter coupons in POS | yes | yes | yes, no approval |
| Suppress Automatic Promotions | yes | when granted | never |

- `DiscountAccess::allows()` denies `discounts.view` / `discounts.manage` to the
  `employee` role **regardless of stored grants**, so a stale legacy row is inert.
- Migration `2026_10_15_000001` removes only `role = employee` rows for those two
  permissions (idempotent). Manager, Owner and POS-apply grants are untouched.
- New tenants provision Employees with `apply_configured` + `apply_manual` only.
- `PUT /discounts/role-permissions/employee` rejects `view`, `manage` and anything
  outside the Employee-assignable set (422).
- `GET /discounts/available` (POS list) now requires `discounts.apply_configured`
  instead of `discounts.view`.
- Flutter: Discounts is removed from the Cashier sidebar, dashboard quick access
  and Cashier route allow-list; `/discounts`, `/discounts/create`,
  `/discounts/settings` also redirect non-Owner/Manager roles. This is UX only.

## Coupons

- `code` is returned by `GET /discounts` and `GET /discounts/{id}` only to actors
  who can `manage` policies. Others receive `code: null` and `hasCode: true`, and
  cannot search by code. POS endpoints never return codes (unchanged).
- Failed typed-coupon redemptions are rate limited (`CouponAttemptGuard`,
  `config/discount_engine.php`): 10 failures / 5 min per tenant+user and 40 /
  5 min per tenant+IP (shared cafe network). Only failures count; successes,
  configured-discount previews and cart reads are never throttled; there is no
  tenant-wide key and branch is not a key. A success does not reset the counters.
- Throttled: HTTP 429, `code: COUPON_ATTEMPTS_THROTTLED`, `Retry-After` header and
  `retryAfterSeconds`.
- A typed code that is unknown, inactive, not started, expired, out of hours,
  outside the branch/channel, or exhausted returns the identical
  `DISCOUNT_NOT_FOUND` (legacy `POST /orders/{id}/discounts/apply`: identical 404).
  Order-context failures (minimum, customer, items, tender) stay specific for the
  cashier and still spend attempt budget. The internal domain code remains in logs.
- Coupon length stays 5; attempts never consume usage.

## Audit (`OperationalAuditService`)

New actions: `discount.created`, `discount.updated` (before/after + `changedFields`
+ `codeChanged`), `discount.activated`, `discount.deactivated` (only on a real
change), `discount.archived`, `discount.role_permissions.replaced`,
`discount.legacy.applied`, `discount.legacy.removed`. Existing
`discount.settings.updated` and `discount.engine.*` events are unchanged and not
duplicated.

Redaction is now recursive. Always redacted: `password`, `token`, `access_token`,
`refresh_token`, `token_hash`, `remember_token`, `secret`, `api_key`,
`authorization`, `pin`. On discount entities / `discount.*` actions also `code`,
`coupon`, `coupon_code`. A bare `code` on Finance/Sales rows is deliberately kept.
Discount audit state never contains the coupon text, only `hasCode` / `codeChanged`
(a hash of a 5-character code would be brute-forceable, so none is stored).

## Status, timezone and "Valid until"

- Date validity has one definition, `DiscountEligibilityService::validityStatus()`,
  evaluated on each branch's own calendar day (start and end inclusive); legacy
  `starts_at` / `ends_at` keep UTC-instant semantics.
- Management `status` is `inactive`, else `active` if any applicable branch is live,
  else `scheduled`, else `expired`. `branchStatuses` lists every applicable branch.
  The POS list uses the order's branch.
- POS list items expose `validUntil` + `validUntilKind` (`date` | `instant`) +
  `validUntilTimezone`. End date wins over a legacy instant.

## Bundles

`bundleSubtotal` uses BigDecimal with one HALF_UP rounding of the matched total
(was float). Package economics, one-package-per-order and allocation are unchanged.

## Zero-value discounts — Product decision required (not changed)

Configured zero-value Manual/Code policies are **documented, tested behavior**
(`discount_settings_backend_contract.md`: "Configured zero Manual/Code remains
valid", "zero configured legacy consumption is retained";
`DiscountRuntimeEligibilityTest`). The inconsistency is real and now pinned by
`DiscountStageBHardeningTest`:

| Path | Explicit zero-value discount |
|---|---|
| Automatic OFF (`selectSingle`) | applied at 0.00, snapshotted, **consumes usage** |
| Automatic ON (V3 `resolveSet`) | dropped (no saving), **no usage** |
| Automatic promotion | never applied, no usage (both modes) |

`maximumDiscountAmount = 0` has no special meaning (null means unlimited) and caps
savings at zero. Recommended decision: require positive `value` and positive
`maximumDiscountAmount` on create/update, stop consuming usage for 0.00 in
`selectSingle`, keep historical rows readable. Needs Product sign-off because it
reverses a documented contract.

## Follow-ups (out of scope, unchanged)

Cashier-selected precedence over Automatic, Best Saving top-8, refund usage
restoration, one-package-per-order, saved-this-month metric, split payments,
priority semantics, Automatic rollout defaults, tenant-wide locking, general
finance architecture, Unified Permission System. Also noted: an overnight window
(e.g. 22:00–02:00) combined with an `end_date` expires at the branch-local
midnight after `end_date`, even if the window is still open; `PosPricingService`
line totals still use float arithmetic (not touched).
