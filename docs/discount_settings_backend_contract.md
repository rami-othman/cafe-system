# Discount settings backend contract — staged Plan 2 engine

Discount V3 Phase 1 (2026-10-07) additively extends the tenant settings response/PUT with the Cafe Discount Policy fields (optional on PUT, safe defaults, not enforced yet): see [Discount V3 Phase 1 contract](discount_v3_phase1_contract.md).

Current acceptance and corrections, 2026-10-05: [Arabic evidence report](verification/discount_plan2_acceptance_2026-10-05_ar.md). POS must reject a known missing shift before staging an early persistent-cart item. History's Print order reads the selected order's stored receipt and reprints with that order/branch identity; it never enters payment recovery or submits payment. A late receipt is discarded after details/context changes. Public Automatic remains disabled. [D2-19 review proposal](verification/discount_plan2_rollout_review_2026-10-05.md) is unapplied SQL only; activation migration/roll-forward acceptance is still open.

Product change, 2026-10-05: new POS free/ad-hoc discounts are disabled for every role. Valid `ad_hoc` apply previews, outstanding ad-hoc review confirmations and legacy `PUT /orders/{order}/discount` reject with HTTP 422 `DISCOUNT_AD_HOC_DISABLED` without changing an order. Completed operation/payment replay and saved legacy ad-hoc snapshots/intents remain readable; an existing unpaid intent can still be quoted, settled or explicitly removed. New applications select a saved eligible Manual policy or submit a Code. Flutter has no free-value entry or free-discount permission toggle. Existing `discounts.apply_manual` storage/catalog is retained for compatibility only and cannot reopen creation. No schema/history rewrite, activation or deployment is part of this change.

2026-10-03, Asia/Damascus. Backend engine phase, public `engineReady=false`. Product authority: `plans/discount_settings_automatic_combination_implementation_plan.md`. Foundation evidence remains in its original verification record. The staged engine contract below is the current runtime authority; the foundation settings API and permission boundary remain preserved.

## Staged engine contract and Flutter handoff

All operational paths below use existing tenant bearer/password/branch/operational middleware. Tenant identity is session-derived. POS needs no settings-administration permission. New clients send `X-Discount-Contract: 2` on every cart, review, quote and payment request. No header is needed for compatible legacy single Manual/Code defaults. Old clients receive HTTP 422 `DISCOUNT_CLIENT_UPDATE_REQUIRED` before Automatic, non-single, any configured global cap (including 100%), or engine-owned mutations/payment. Existing legacy apply/remove routes return `DISCOUNT_REVIEW_REQUIRED` for those engine-owned calculations, including clients with header 2. Capabilities, cart pricing and payment use the same activation rule. A newly configured cap applies to existing unpaid orders on their next calculation/review/quote; no background rewrite occurs. Previously issued quotes become stale through settings version/fingerprint. Completed payment and operation replay retain their original durable results before repricing.

Public capabilities remain `engineReady=false`, `automaticPolicyCreationAvailable=false`, `automaticEnabled=false`. Review and quote support is available; nondefault combination settings require the new contract. Automatic policies cannot be publicly created or converted until final rollout. Management validation supports `applicationMode: automatic` and integer `priority: 0..1000` behind that capability. New priority defaults to 0; omitted update priority preserves the old value. Automatic requires null code; Code-to-Automatic requires explicitly submitting `code:null`. Existing full detail hydration, nullable clearing and Plan 1 variant selections remain authoritative. Disabling Automatic preserves policies. Available-policy discovery remains Manual-only; coupon lookup occurs only for submitted explicit Code intent. Coupon text never enters operational DTOs, stored review payloads, snapshots or audit.

Isolated verification alone can set `discount_engine.isolated_automatic=true` (`DISCOUNT_ENGINE_ISOLATED_AUTOMATIC`) with APP_ENV=testing and actual PostgreSQL database exactly `cafe_system_618_testing` or `cafe_system_618_testing_migrations`. This authority changes engine discovery and creation capability without writing automatic_enabled=true or weakening the foundation CHECK. Operational capabilities report `automaticEnabled=true` under this guarded authority, while persisted settings still report `automaticEnabled=false` and `engineReady=false`. Creation availability is independent of engineReady. This is not an activation API.

### Endpoints and request shapes

All successful responses are HTTP 200 `{ "data": ... }`. IDs are tenant/order scoped. Money in new engine DTOs is an exact two-place decimal **string**. Existing numeric legacy fields retain their type.

| Method/path (prefix `/api/v1`) | Request | Result |
|---|---|---|
| GET `/discount-capabilities` | none | capabilities below |
| GET `/orders/{order}/discount-state` | none | saved state below, no repricing |
| GET `/orders/{order}/discount-operations/{identity}` | none | `{operationId,completed,result}`; missing completion gives false/null |
| POST `/orders/{order}/discounts/preview` | review request below | proposed resolution/review |
| POST `/orders/{order}/discounts/operations` | `{operationId:string(max120),reviewId:uuid}` | saved state plus operationId |
| POST `/orders/{order}/payment-quote` | `{paymentMethodId:integer|null}` | proposed resolution plus quoteId, paymentMethodId, method, expiresInSeconds=300 |
| GET `/orders/{order}/payment-summary` | existing query | legacy summary plus paymentMethods, discounts, discountContractVersion, discountCapabilities; read-compatible |
| POST `/orders/{order}/pay` | existing payment body plus quoteId | existing payment response; settlement transaction validates quote |

Review bodies select **one** action:

```json
{"action":"apply","intent":{"source":"configured_manual","discountId":12},"paymentMethodId":3}
{"action":"apply","intent":{"source":"code","code":"customer input"},"paymentMethodId":null}
{"action":"remove"}
{"action":"suppress","discountId":12,"reason":"Required nonblank explanation"}
{"action":"undo","discountId":12}
```

Intent fields are source-specific; mixed sources are rejected. New ad-hoc apply intents are disabled; ad_hoc in saved DTOs remains available for historical compatibility. Configured zero Manual/Code remains valid. `paymentMethodId` is optional in every review. Suppress/undo requires an Automatic policy of this tenant, draft/held unpaid lifecycle, allowAutomaticSuppression=true and `discounts.automatic.suppress`. Owner has implicit access; Manager needs an explicit Owner-administered grant through existing `PUT /discounts/role-permissions/manager`. This permission is Manager-only at DB/API boundaries and is **not** automatically granted. Settings management permission does not grant suppression. Suppression reason max500 is required; actor/reason and operational audit are persisted. Active suppression survives cart mutations and only undo removes it, scoped exclusively to its order; deleting an applied row is not suppression.

### Response shapes

Capabilities: `{contractVersion:2,engineReady:false,automaticPolicyCreationAvailable:boolean,automaticEnabled:boolean,settingsVersion:integer,supportsDiscountReview:true,supportsPaymentQuote:true,requiresPaymentQuote:boolean,canSuppressAutomatic:boolean}`. Header-2 clients always require quotes. `canSuppressAutomatic` reflects actor permission and setting; normal lifecycle checks still apply.

Resolution: `{discounts:[],totals:{subtotal,discountTotal,taxTotal,total},settingsVersion,provisional:boolean,reasons:[{discountId,code}],fingerprint:string}`. Each proposed discount has `{discountId:null|integer,source,stage,name,type,value,amount,priority,fixedAmountBasis,applicationMode,scope,allocations:[{orderItemId,amount}]}`. Sources are automatic/configured_manual/code/ad_hoc; stages items/order. Preview additionally returns `reviewId`, `before` and `after` totals, `removals` (complete previous list), `additions` (complete proposed list). These lists are review replacements, not minimal deltas. Reasons use existing eligibility codes plus DISCOUNT_SUPPRESSED and DISCOUNT_TENDER_PENDING. Never display raw messages; use recognized EN/AR mappings with safe generic fallback.

Saved state: `{orderId,explicitIntent,discounts,requiresDiscountBreakdown,discountContractVersion:2,totals,suppressions:[{discountId,reason,actorId}]}`. `explicitIntent` is null or the persisted normalized `{source,discountId}` for configured Manual/Code, or `{source:"ad_hoc",type,value,name}`; it never contains coupon text and is not fabricated for legacy rows. Cart recalculation may invalidate its applied row but keeps this intent and does not substitute Automatic; quote then returns the explicit eligibility error until review/removal. Saved discount entries include applied row `id`, policy `discountId`, name/source/stage/type/value/amount/settingsVersion/allocations. Legacy rows retain null source/stage/version and empty allocations, without inventing history. Order detail and receipt expose saved `discounts[]`; detail legacy `discount` is null when multiple rows exist. Use aggregate backend totals and every entry, never the first row as the whole discount. Payment summary adds active supported Finance-mapped `paymentMethods:[{id,name,type}]` for tender selection without Finance administration access.

### Review, quote, replay and errors

Reviews and quotes expire after 300 seconds. Client totals/allocations/amounts are never calculation inputs. Review identity binds normalized intent/action, tender, persisted order/items, complete policy set/targets/revisions, settings, customer/groups/channel, branch/timezone and current eligibility decisions. Apply re-evaluates under locks and compares fingerprint; changed context requires a new preview. Removal clears explicit intent then discovers Automatic again. Explicit intent is preserved under configured exclusivity and cannot be replaced by a more attractive Automatic policy.

Completed operation identity is durable, tenant-wide and bound to order plus reviewId. Repeating the same operation replays its stored response; a different request with the same identity is rejected. A failed/stale operation writes no completed operation. On uncertain response, read `/discount-operations/{identity}`, then saved state; the read waits for an in-flight order mutation before reporting completion. Retain the identity while investigating. Payment uncertainty is recovered by existing GET order detail `payments[]` and its `idempotencyKey`; completed payment replay wins before fresh quote validation, even after settings/policy changes. An empty payment read while a request may still be running is not proof of failure: keep the same identity and refresh this authoritative read until completion is known. Never create a new identity merely because a response was lost.

Payment body remains `{amount,method?,paymentMethodId?,idempotencyKey,quoteId,reference?,note?}`. `amount` is the existing received amount; the backend settles its own total. For a nonnull tender quote, submit both the quoted authoritative paymentMethodId and its canonical cash/card `method`; for a null-tender zero-balance quote omit both or submit null. Labels alone cannot establish tender. Before tender selection restricted Automatic candidates are excluded and resolution is provisional; explicit restricted intent remains pending. Null tender can settle only a nonrestricted zero balance. Selecting a valid tender may produce zero balance but creates the existing zero_balance settlement without a cash/account tender line.

Quote fingerprint includes original order/items and timestamps, settings version, **all tenant nondeleted policies and target revisions**, persisted customer/channel/branch/timezone and business date, resolved method/account mapping, evaluated time eligibility, suppression/intent/current snapshots, allocations and totals. New policies invalidate it even if not previously selected. Raw used_count is not a policy revision: current eligibility/exhaustion decisions are re-evaluated, allowing independently valid unlimited uses. Any changed result rejects even if cheaper or received cash covers it. No payment, usage, stock, snapshot or journal survives rejection. Each actual configured policy consumes once per `(tenant_id,order_id,discount_id)` after settlement; zero configured legacy consumption is retained. Preview/cart changes do not reserve usage. Allocations do not multiply usages or metrics. Refunds remain amount-based and never restore usage.

| HTTP | Stable code | Client action |
|---|---|---|
| 422 | DISCOUNT_CLIENT_UPDATE_REQUIRED | block mutation/payment; update client |
| 422 | DISCOUNT_ENGINE_NOT_READY | keep Automatic control unavailable (management also returns errors.applicationMode) |
| 422 | DISCOUNT_REVIEW_REQUIRED / DISCOUNT_REVIEW_STALE | fresh preview and explicit review |
| 422 | DISCOUNT_OPERATION_CONFLICT | identity reused for different order/review; investigate |
| 422 | DISCOUNT_SUPPRESSION_FORBIDDEN / DISCOUNT_SUPPRESSION_DISABLED | deny suppression/undo |
| 422 | PAYMENT_QUOTE_REQUIRED / ORDER_TOTAL_CHANGED | fresh quote and confirmation |
| 422 | PAYMENT_METHOD_INVALID / PAYMENT_TENDER_REQUIRED | refresh/select authoritative tender then quote |

Existing auth/branch 403, missing-order 404, validation 422 `{message,errors}`, DiscountAccess 403 and established eligibility/lifecycle/idempotency envelopes remain unchanged. No coupon text is returned in errors/metadata.

Eligibility codes for safe Flutter mapping (HTTP 422 for explicit intent/payment; Automatic candidates instead expose them in reasons): `DISCOUNT_NOT_FOUND`, `DISCOUNT_APPLICATION_MODE_INVALID`, `DISCOUNT_INACTIVE`, `DISCOUNT_NOT_STARTED`, `DISCOUNT_EXPIRED`, `DISCOUNT_DAY_NOT_ALLOWED`, `DISCOUNT_TIME_NOT_ALLOWED`, `DISCOUNT_BRANCH_NOT_ELIGIBLE`, `DISCOUNT_CHANNEL_NOT_ELIGIBLE`, `DISCOUNT_CUSTOMER_NOT_ELIGIBLE`, `DISCOUNT_CUSTOMER_REQUIRED`, `DISCOUNT_MINIMUM_NOT_MET`, `DISCOUNT_ITEMS_NOT_ELIGIBLE`, `DISCOUNT_PAYMENT_METHOD_NOT_ALLOWED`, `DISCOUNT_USAGE_LIMIT_REACHED`, `DISCOUNT_DAILY_USAGE_LIMIT_REACHED`, `DISCOUNT_BOGO_UNSUPPORTED`. An invalid explicit intent must be removed or reviewed anew; never silently replace it with Automatic. Payment validation retains `NO_OPEN_SHIFT`, `PAYMENT_METHOD_INVALID`, `ACCOUNTING_CONFIGURATION_MISSING`, `INSUFFICIENT_STOCK`, `PAYMENT_VALIDATION_FAILED`; completed identity mismatch is HTTP 409 `PAYMENT_IDEMPOTENCY_CONFLICT`. Existing order lifecycle codes and auth envelopes remain from the established POS contract.

### Calculation and physical lock graph

Correction acceptance (2026-10-04): a configured `maximumTotalDiscountPercent` also makes `requiresPaymentQuote=true` for legacy capability reads; header-2 requests always require quotes. Default `null` cap with Automatic off, single combination and no engine-owned state keeps the established legacy path.

Fixed product `per_unit` allocation weights are the exact per-line `min(value × quantity, remaining line balance)` contributions. Policy cap then global budget scale these contributions proportionally with exact largest remainder; selling-price weights are retained for approved fixed `per_order` and percentage behavior. Bundle weights retain exact required-quantity × pinned-unit-price bases, limited by actual line balances, while the established one-bundle aggregate amount/rounding boundary remains authoritative. Aggregate HALF_UP may need a cent on a subcent contribution; each allocation is bounded by its exact contribution rounded upward to one cent and by the actual remaining order-line cents. Subcent remainders tie by order-item ID; positive allocations reserve disjoint identities. Allocation sums equal the selected rounded amount exactly. Examples: quantities/prices `1×100` and `10×1` at fixed `1/unit` allocate `1.00/10.00`; the `100.00/0.01` overlap case totals `1.01`; two `0.333×1.00` bundle bases total `0.67` and allocate `0.34/0.33`.

`DiscountResolutionService` is the orchestration authority, reusing DiscountEligibilityService and Plan 1 variant matching. Positive actual cents after quantity, policy cap then original-subtotal global budget determine highest/lowest saving. Priority is higher first, ID ascending. Automatic zero candidates are excluded. Disjoint selection is greedy, recalculated after each selection; policies apply once and only positive allocation item IDs reserve overlap. Fixed/per_order applies once across its group; fractional per_unit stays exact. Category uses item non-overlap; bundle retains existing amount computation and remains exclusive. Item-group/order comparison follows strategy; monetary ties prefer fewer policies then sorted policy IDs. Priority group uses its highest participating priority then the smallest ID at that priority. after_items uses residual balances only with disjoint_items; minimum spend uses original subtotal. Exact BigDecimal/BigInteger HALF_UP and largest remainder by item ID ensure allocation sums, residual caps, nonnegative values and subtotal ceiling. Existing tax and bundle semantics remain.

Payment: order FOR UPDATE → tenant-wide payment identity advisory hash (seed 20405) → completed replay → physical drawer FOR UPDATE → shift FOR UPDATE (no shared-to-exclusive upgrade) → tenant advisory `(20402,tenant)` → warehouse context binding (implicit warehouse FK KEY SHARE) → full policy parents ID ascending FOR UPDATE → owned snapshots/allocations/usages → sale-consumption/movement identity → warehouse/balances/outbound lots → source journal/account mapping → tenant numbering FOR NO KEY UPDATE → journal posting. Quote: order FOR UPDATE → tenant advisory `(20402,tenant)` → warehouse binding/FK KEY SHARE → policy parents/resolution/quote. Both paths acquire the engine gate before any warehouse FK lock, including an unbound legacy order. Order creation already acquires the gate before inserting its warehouse FK. The previous quote-binding-before-gate sequence was dynamically reproduced as a PostgreSQL wait cycle against an already-bound stock payment on 2026-10-04; the new deterministic regression checks the actual HTTP paths and inventory/accounting effects. Re-entering already-held locks does not reverse acquisition. Order creation uses drawer then shared shift. Order cart/review operations use order then tenant gate/policies, never acquire shift/drawer afterward. Settings writer uses tenant gate then settings row and audit, without orders. Policy create/edit/status/delete uses tenant gate then parent/targets, covering absent settings and policy-set phantoms. Operation identity adds advisory hash key after tenant gate (seed 20404). Implicit FK KEY SHARE occurs on tenant/order/policy/user and financial references. Journal/customer payment numbering uses FOR NO KEY UPDATE so tenant FK key-share does not cause an upgrade cycle while still serializing the counter.

Refund, cash source, POS cash location, manual/automatic shift close and legacy shift adoption consistently prelock physical drawer before exclusive shift. Reconciliation already locks drawer then sorted shifts, without orders. Existing Finance documents lock their own document/invoice/payment domain before these seams; accounting source-event idempotency and account/period semantics remain unchanged. Stock count's shift/warehouse path does not take financial drawers; balance and lot ordering remains InventoryPostingService authority. This graph is audited for the affected callers; test evidence covers the listed engine/payment races, not a proof of every possible unrelated Finance transaction schedule.

### Migration and frontend sequence

New additive `2026_10_03_000003_create_discount_engine_protocol.php` adds priority, Automatic/no-code constraint, normalized order intent, durable review/operation/quote tables and suppression permission constraint. Protocol identities have tenant-wide uniqueness and composite tenant/order FKs. Down refuses while engine snapshots or protocol/intent data exist, including early Automatic cart snapshots without a quote; foundation runtime down still refuses multi-policy usage. Roll forward preserves paid history. No operational migration was executed. Final activation needs a **new additive migration** deliberately replacing the foundation automatic-enabled CHECK while retaining its other constraints, plus final capability gate changes after frontend/acceptance. Never edit the applied foundation migration.

Flutter phase sequence: load operational capabilities; persist cart using existing serial mutation/create identity; render complete saved discounts and aggregate totals; preview one intent or suppression action; confirm review with durable operation identity and recover through its GET; select paymentMethods ID; obtain fresh POST quote; present quote changes/provisional state; confirm pay with same quote/method and durable payment identity; on stale quote refresh and obtain explicit confirmation. Render receipts/history from saved lists and legacy fallback without recalculation. Safe EN/AR codes, permission/lifecycle suppression controls, Automatic/priority detail hydration behind capability, settings draft/version conflict and RTL/layout tests are implemented in the 2026-10-04 Flutter phase. Public Automatic remains unavailable; implementation is distinct from rollout. See [Flutter evidence and open acceptance gates](verification/discount_settings_flutter_2026-10-04.md). D2-19 stays open.

Integration correction 2026-10-04: fingerprinting canonicalizes normalized intent object key order because PostgreSQL JSONB reorders keys. This permits ad-hoc preview → stored review → operation without a false `DISCOUNT_REVIEW_STALE`. Values and all existing context checks remain part of the hash; real intent changes still reject. Calculations, compatibility, lock ordering, public capabilities and activation constraints are unchanged. Outstanding pre-correction reviews/quotes may need a fresh explicit review; completed operation/payment replay retains its existing authority.

Historical Flutter settlement evidence from the earlier report includes native EN/AR cash and Web orders 16/17/18. These records do not prove acceptance of the current saved-policy-only flow. Current 2026-10-05 Web evidence uses saved policies for cash/card, stale-quote reconfirmation, committed-response recovery, and zero_balance order 8; native Windows interaction remains unverified. Receipt previews preserve canonical zero_balance and now localize the generic discount aggregate label while retaining a custom historical label. This is presentation only; payment and pricing remain server-authoritative. See the current Arabic report for exact identities, effects and remaining gates.

## Tenant settings API

`GET /api/v1/cafe-configuration/discount-settings` and `PUT` at the same path use opaque tenant bearer authentication (`api.token`) and `password.changed`, outside branch middleware and general Owner-only Cafe Configuration middleware. Tenant identity comes exclusively from the authenticated session; headers/body cannot select another tenant. Invalid, revoked, expired, mismatched-tenant or platform credentials do not establish a tenant session. Existing authentication/password/tenant-operational error envelopes remain unchanged.

Both methods require effective tenant role Owner or Manager **and** `DiscountAccess` authorization for `discounts.settings.manage`. Owner has existing implicit access. Manager requires the explicit tenant role grant. Employee, factory_manager and platform sessions are denied. A malformed tenant_role_id referencing another tenant is rejected by this settings boundary; the legacy role relationship itself is not redesigned. Profile, Tax, non-printing branch configuration and permission administration stay Owner-only. There are no branch overrides.

GET and successful PUT return HTTP 200 with exactly `{ "data": { ... } }`:

```json
{
  "data": {
    "automaticEnabled": false,
    "selectionStrategy": "highest_saving",
    "combinationMode": "single",
    "orderDiscountBehavior": "exclusive",
    "couponBehavior": "exclusive",
    "manualBehavior": "exclusive",
    "maximumTotalDiscountPercent": null,
    "allowAutomaticSuppression": true,
    "version": 0,
    "engineReady": false
  }
}
```

`DiscountSettingsService::DEFAULTS` is the sole backend defaults authority. The database requires explicit values rather than duplicating defaults. Missing-row GET returns version **0** and does not create settings/audit/order/financial records. The existing authentication middleware may update session `last_used_at` as usual. The first successful save creates version **1**; every accepted save, including identical values, advances by one. Versions are server integers. No row ID, actor, coupon or tenant detail is exposed.

PUT is a full replacement. Send every eight editable fields above plus required `expectedVersion` (JSON integer, 0..2147483646). Do not send `version` or `engineReady`. Unknown/read-only fields are rejected. Boolean fields require actual JSON booleans; string/numeric booleans are rejected. Enums are case-sensitive strings:

| Field | Type / accepted values | Default |
|---|---|---|
| automaticEnabled | boolean; true rejected while engine unavailable | false |
| selectionStrategy | highest_saving / lowest_saving / priority | highest_saving |
| combinationMode | single / disjoint_items | single |
| orderDiscountBehavior | exclusive / after_items | exclusive |
| couponBehavior | exclusive / follow_combination_rules | exclusive |
| manualBehavior | exclusive / follow_combination_rules | exclusive |
| maximumTotalDiscountPercent | null or numeric >0..100, up to four decimal places; response JSON number | null |
| allowAutomaticSuppression | JSON boolean | true |

`after_items` requires `disjoint_items`. Numeric input follows Laravel numeric conventions (number or numeric decimal string); PostgreSQL stores exact `numeric(7,4)`. The response follows existing management numeric serialization conventions. Four-place precision prevents silent database rounding of a positive tiny budget to zero.

Errors use `{ "message": "safe generic text", "code": "..." }`, plus `errors` mapping fields to arrays of safe validation strings for validation failure. Submitted confidential values are never echoed.

| HTTP | Stable code | Meaning |
|---|---|---|
| 403 | DISCOUNT_SETTINGS_FORBIDDEN | Authenticated actor lacks allowed role/grant |
| 422 | DISCOUNT_SETTINGS_VALIDATION_FAILED | Missing, unknown, read-only, wrong type, range, enum or invalid combination |
| 422 | DISCOUNT_ENGINE_NOT_READY | Valid request tries automaticEnabled=true |
| 409 | DISCOUNT_SETTINGS_VERSION_CONFLICT | expectedVersion does not equal current version, including first-row competition |

Validation precedes activation checking; activation precedes saving/version comparison. A stale save must refetch GET and explicitly review before sending a fresh version. A repeated save with the old version conflicts rather than silently replaying. Unexpected failures use the existing safe server-error handler; settings/version/audit roll back together. `engineReady` is a server capability, always false in this phase and absent from storage/client writable fields. A database check additionally disallows automatic activation until a future explicitly authorized migration removes that guard.

## Persistence, permissions and locking

`tenant_discount_settings`: existing bigint ID identity, unique tenant_id referencing tenants, typed eight fields, positive integer version, tenant-safe `(updated_by,tenant_id)` user FK, timestamps. Enum/range/combination/activation checks enforce invariants even outside HTTP. Each save acquires PostgreSQL transaction advisory lock `(20402, tenant_id)` then settings `FOR UPDATE`; that lock serializes absent-row creation as well as updates. Unique tenant remains the final database invariant. Expected version comparison, settings write, actor metadata and `OperationalAuditService::record` before/after states occur in one transaction. Audit action `discount.settings.updated`, entity `tenant_discount_settings`, null branch, authenticated actor. No order locks or repricing occur.

The existing four-permission `DiscountAccess::CATALOG` remains the legacy default list; `ALL_PERMISSIONS` includes `discounts.settings.manage` and `discounts.automatic.suppress`. Every catalog consumer was reviewed: original permission migration, DefaultTenantRoleService, role-permission API and security tests. The original migration deliberately continues seeding only the four legacy permissions. The foundation upgrade extends the permission constraint, rejects Employee settings grants at DB/API levels, and grants **settings management** once to existing Manager tenant roles without restoring revoked old permissions. New Manager roles receive the same intended initial settings grant. `tenant_roles.discount_settings_grant_initialized` records that initialization; later missing settings grants are explicit revocations and provisioning must not restore them. Suppression requires a separate explicit grant and has no automatic provisioning. Legacy defaults are now provisioned only for newly created roles, preserving existing missing/revoked grants. Owner-only `PUT /discounts/role-permissions/manager` can include/remove these permissions through the existing full replacement envelope. Manager cannot administer permissions.

