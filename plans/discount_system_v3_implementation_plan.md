# Discount System V3 — Implementation Plan

## Purpose

This plan defines the next major Discount System improvement for Cafe System.

The goal is to preserve the strong existing discount foundation while correcting the product model around Discount Settings and extending the system to support:

- Variant-level targeting inside Package / Bundle discounts.
- Short generated coupon codes.
- Cafe-configurable discount policy.
- Multiple discounts on the same order.
- Optional same-item stacking.
- Per-discount exclusivity.
- Global safety limits.
- A cleaner, business-oriented Discount Settings experience.
- Full POS, payment, receipt, history, and regression compatibility.

This is an incremental evolution of the existing system, not a rewrite.

---

# 1. Product Principles

## 1.1 Cafe Policy, Not Developer Policy

Cafe System must not hard-code one universal discount policy for every cafe.

The platform provides capabilities.

Each cafe Owner or authorized Manager decides the cafe's policy through Discount Settings.

Examples of decisions the cafe may control:

- Whether multiple discounts may exist on one order.
- Whether multiple discounts may affect the same item.
- Whether multiple coupon codes may be used.
- Whether coupon discounts may combine with configured discounts.
- Whether order-level discounts may be applied after item-level discounts.
- Maximum number of discounts per order.
- Maximum total discount percentage.
- How conflicts between eligible discounts are resolved.

The system must enforce the selected cafe policy consistently across POS, quote, payment, receipt, history, and backend APIs.

---

## 1.2 Global Policy + Individual Discount Policy

The cafe-wide Discount Settings define the maximum allowed behavior.

Each Discount Policy may further restrict itself.

Initial per-discount combination behavior:

```text
follow_cafe_policy
exclusive
```

Meaning:

- `follow_cafe_policy`: the discount follows the current cafe policy.
- `exclusive`: the discount cannot combine with any other discount.

An individual discount may restrict the cafe-wide behavior, but must not override the cafe's global safety rules.

---

## 1.3 No Rewrite of the Existing Discount Foundation

Preserve the existing:

- Discount models and lifecycle.
- Tenant isolation.
- Branch targeting.
- Product/category targeting.
- Variant-level product targeting.
- Customer and customer-group targeting.
- Channel targeting.
- Payment-method targeting.
- Date/time/weekday constraints.
- Global and customer usage limits.
- Daily customer limits.
- Bundle/package structure.
- Payment-time revalidation.
- Quote/fingerprint/stale detection.
- Historical order behavior.
- Existing audit behavior where compatible.
- Existing authorization boundaries until the future unified permissions project replaces them.

Use additive migrations and backward-compatible contracts wherever practical.

---

# 2. Confirmed Product Decisions

## 2.1 Package / Bundle Variant Targeting

Package requirements must support variant-level targeting.

Each package requirement can target:

```text
Product
├── All Variants
└── Selected Variants
```

Example:

```text
Large Latte ×1
+
Chocolate Cookie ×1
```

The implementation should reuse the existing product-variant targeting concepts and validation patterns where practical.

Do not create a completely separate variant architecture for packages unless repository constraints require it.

---

## 2.2 Short Coupon Codes

System-generated coupon codes should be short and practical.

Target:

```text
5 characters by default
```

Examples:

```text
K7M4P
A9X2D
R6F8Q
```

Requirements:

- Case-insensitive uniqueness within the tenant.
- Backend-generated.
- Collision-safe retry.
- Preserve support for existing long coupon codes.
- Do not migrate or invalidate existing coupon codes.
- Prefer an unambiguous character set.
- Exclude confusing pairs where practical, such as `O/0` and `I/1`.
- Manual/custom coupon entry remains subject to existing validation unless explicitly changed by implementation findings.

---

## 2.3 Multiple Discounts Per Order

The system must support more than one configured/code discount on the same order.

Conceptually:

```text
Order
├── Discount A
├── Discount B
├── Coupon C
└── Future Automatic Promotion
```

Whether combinations are valid is controlled by Cafe Discount Policy and each discount's individual combination behavior.

---

## 2.4 Same-Item Stacking Is Cafe-Configurable

The system must not choose one mandatory behavior.

Cafe Settings must allow the cafe to choose between:

```text
Different items only
```

or:

```text
Allow stacking on the same item
```

Examples:

Different-items-only:

```text
Latte  → Discount A
Cookie → Discount B
```

Allowed.

But:

```text
Latte
├── Discount A
└── Discount B
```

Not allowed.

Same-item stacking enabled:

```text
Latte
├── Discount A
└── Discount B
```

Allowed if all other policy rules pass.

---

## 2.5 Same-Item Calculation Method

For V1 of multi-discount stacking, use deterministic sequential application.

Example:

```text
Original = 100
Discount A = 10%
Result = 90
Discount B = 20%
Final = 72
```

Do not expose calculation-method selection as a Cafe Setting in this phase.

Do not simply add percentages together.

Backend calculation order must be deterministic and covered by tests.

---

## 2.6 Conflict Resolution

When the system cannot apply all eligible discounts because of cafe policy or exclusivity, the public product behavior should support:

```text
best_saving
priority
```

Do not expose `lowest_saving` as a normal cafe-facing option.

Legacy/internal values may remain temporarily for compatibility if repository constraints require them, but the new public model should not depend on them.

---

# 3. Target Cafe Discount Policy

The new Discount Settings screen represents the cafe's business policy.

Expected public settings:

```text
Allow multiple discounts on one order
```

If enabled:

```text
Stacking behavior:
- Different items only
- Allow stacking on the same item
```

Additional policy controls:

```text
Allow multiple coupon codes

Allow coupon + configured discount

Allow item-level + order-level discount

Maximum discounts per order

Maximum total discount percentage

Conflict resolution:
- Best saving
- Priority
```

Future automatic-promotion settings may integrate with this model later, but should not force premature rollout of unfinished automatic behavior.

---

# 4. Automatic Discounts

The existing automatic-discount engine foundation should be preserved.

However:

- Do not expose low-level automatic-engine controls unnecessarily.
- Do not activate unfinished automatic behavior just because backend foundations exist.
- Automatic settings should only become public when the feature is production-ready.
- Future public choices should use business language.

Expected future behavior:

```text
Automatic Promotions
[ ON / OFF ]

When multiple automatic promotions qualify:
- Best saving
- Priority
```

Automatic suppression/removal should eventually be expressed in business language such as:

```text
Allow authorized managers to remove an automatic promotion
Reason required
```

This is not the primary implementation target of the current phases unless required for compatibility.

---

# 5. Navigation and Product Structure

Preferred module structure:

```text
Discounts
├── Policies
└── Settings
```

`Discount Settings` should behave as part of the Discounts domain, not as a technical engine page.

The existing Cafe Settings location may be kept temporarily during implementation if routing risk is high, but the final product direction should be Discounts → Settings.

---

# 6. Permissions Direction

Current discount authorization may remain for this implementation.

Owner and Manager should manage Discount Settings according to the existing project authorization model.

Employee should not manage cafe-wide Discount Settings unless the current project policy explicitly grants that capability.

Do not expand the old discount-specific permission UI unnecessarily because a unified permission system is planned later.

Avoid exposing stale permissions such as free/ad-hoc discount creation when the product no longer supports that behavior.

Keep backend authorization centralized so it can migrate later to the unified permission system.

---

# 7. Delivery Strategy

Implement in four phases.

Do not combine the backend multi-discount engine and Flutter/POS rollout into one phase.

Each phase must end with focused tests and a clear handoff.

---

# PHASE 1 — Domain, Database, Contracts, Package Variants, Short Coupons

## Objective

Prepare the full domain and persistence model without changing production POS behavior to multi-discount yet.

## Scope

### A. Cafe Discount Policy Model

Add or adapt the tenant-level settings model to support:

```text
allow_multiple_discounts
stacking_mode
allow_multiple_coupons
allow_coupon_with_configured
allow_order_after_item_discounts
maximum_discounts_per_order
maximum_total_discount_percent
conflict_resolution
```

Recommended values:

```text
stacking_mode:
- different_items_only
- same_item_allowed

conflict_resolution:
- best_saving
- priority
```

Use repository naming conventions where appropriate.

Do not expose obsolete internal engine terminology in new public contracts.

### B. Individual Discount Combination Behavior

Add per-discount behavior:

```text
combination_behavior:
- follow_cafe_policy
- exclusive
```

Requirements:

- Existing discounts must remain valid.
- Existing rows should default safely.
- Prefer `follow_cafe_policy` for legacy discounts unless repository behavior requires a safer compatibility value.
- Migration must be additive.

### C. Package Variant Requirements

Extend package/bundle requirements to support:

```text
Product + All Variants
```

or:

```text
Product + Selected Variant IDs
```

Requirements:

- Same-tenant validation.
- Product/variant ownership validation.
- Active/non-archived validation consistent with existing discount target rules.
- Edit/read round-trip.
- Legacy package requirements without variant configuration continue to mean all variants.
- Reuse existing variant-target concepts where practical.
- Add backend contract documentation if the project currently maintains such docs.

### D. Short Coupon Generation

Change generated coupon behavior to approximately five characters.

Requirements:

- Backend authoritative.
- Tenant-scoped uniqueness.
- Case-insensitive collision protection.
- Retry on collision.
- Existing long codes remain valid.
- No destructive migration.
- Tests must include deterministic collision simulation where practical.

### E. API Contract Preparation

Prepare the contracts needed by later phases.

Do not yet enable multi-discount mutation behavior in POS if the runtime engine is not complete.

## Phase 1 Tests

Cover at minimum:

- Existing discounts still load.
- Existing coupon codes still work.
- New short codes generate correctly.
- Coupon collision retry.
- Combination behavior validation.
- Legacy discounts default safely.
- Package all-variant behavior.
- Package selected-variant behavior.
- Invalid cross-tenant variant rejected.
- Invalid product/variant relationship rejected.
- Edit preserves selected variants.
- Migration compatibility.

## Phase 1 Exit Criteria

Phase 1 is complete when:

- DB/domain contracts are stable.
- Package variants are persisted and round-trip correctly.
- Short coupons are generated safely.
- Existing production POS behavior is not unintentionally changed.
- Focused backend tests pass.

---

# PHASE 2 — Multi-Discount Backend Engine and Payment Safety

## Objective

Upgrade the backend runtime from one managed discount per order to a policy-driven multi-discount model.

This is the highest-risk phase.

## Scope

### A. Multi-Discount Order Runtime

Support multiple configured/code discounts on one order.

Do not assume that every combination is valid.

The engine must evaluate:

```text
Cafe Policy
+
Individual Discount Combination Behavior
+
Discount Eligibility
+
Usage Limits
+
Order Context
```

before allowing the final combination.

### B. Policy Enforcement

The backend must enforce:

- Multiple discounts enabled/disabled.
- Different-items-only vs same-item stacking.
- Multiple coupons enabled/disabled.
- Coupon + configured discount enabled/disabled.
- Item-level + order-level combination enabled/disabled.
- Exclusive discount behavior.
- Maximum discounts per order.
- Maximum total discount percentage.
- Conflict resolution.
- Existing usage and eligibility rules.

The backend is authoritative.

Flutter must not decide final validity independently.

### C. Deterministic Same-Item Stacking

When same-item stacking is enabled:

- Apply discounts sequentially.
- Define a deterministic ordering.
- Ensure quote, payment, receipt, and history use the same ordering.
- Persist enough allocation detail to reproduce the applied result.

Do not let client ordering produce inconsistent totals.

### D. Package Variant Runtime Matching

The discount runtime must understand package requirements that target selected variants.

Examples:

```text
Large Latte qualifies
Regular Latte does not
```

Package matching must continue to honor quantity requirements and existing package semantics.

### E. Quote / Payment / Revalidation

Preserve and extend the existing safety model:

- Quote generation.
- Payment-time revalidation.
- Stale quote detection.
- Fingerprints.
- Concurrency control.
- Idempotent payment behavior.
- Historical/pinned order behavior.
- Zero-balance order behavior.
- Held/draft order compatibility.

If the order changes between quote and payment, discount validity must be re-evaluated.

### F. Auditability

Persist enough information to explain:

- Which discounts were applied.
- Their application order.
- Which order lines they affected.
- Per-discount monetary contribution.
- Why a candidate was excluded where the existing architecture supports reason codes.
- Which Cafe Policy was relevant at application time where practical.

### G. Stable Domain Errors

Return stable backend errors for policy violations such as:

```text
multiple_discounts_disabled
same_item_stacking_disabled
multiple_coupons_disabled
coupon_combination_not_allowed
order_item_combination_not_allowed
exclusive_discount_conflict
maximum_discount_count_exceeded
maximum_total_discount_exceeded
discount_conflict
```

Use project naming conventions.

## Phase 2 Tests

Include:

- One discount.
- Two discounts.
- Three discounts.
- Multiple discounts disabled.
- Different-items-only.
- Same-item stacking enabled.
- Same-item stacking disabled.
- Multiple coupons ON/OFF.
- Coupon + configured ON/OFF.
- Item + order ON/OFF.
- Exclusive + normal.
- Exclusive + exclusive.
- Maximum discount count.
- Maximum total percentage.
- Best-saving conflict resolution.
- Priority conflict resolution.
- Package selected variants.
- Sequential same-item calculations.
- Decimal precision.
- Payment-time stale detection.
- Retry/idempotency.
- Concurrency.
- Zero-balance totals.
- Held/draft compatibility.
- Historical orders remain pinned.

## Phase 2 Exit Criteria

Do not proceed to Flutter multi-discount UI until:

- Multi-discount backend totals are deterministic.
- Payment revalidation is correct.
- Concurrency/idempotency tests pass.
- Existing single-discount behavior remains compatible.
- Focused backend suite is green.

---

# PHASE 3 — Discount Settings, Discount Management, and POS UI

## Objective

Expose the new product model clearly to Owner/Manager and integrate multi-discount usage into the operational app.

## Scope

### A. Rebuild Discount Settings as Cafe Policy

Replace technical engine-oriented wording with business policy controls.

Expected structure:

#### General Policy

```text
Allow multiple discounts on one order
```

#### Combining Discounts

```text
Stacking:
- Different items only
- Allow stacking on the same item

Allow multiple coupon codes

Allow coupons with configured discounts

Allow order-level discount after item-level discounts
```

#### Safety Limits

```text
Maximum discounts per order

Maximum total discount %
```

#### Conflict Resolution

```text
When discounts conflict:
- Give the customer the best saving
- Use discount priority
```

Do not show obsolete/internal concepts such as:

```text
disjoint_items
lowest_saving
manualBehavior
couponBehavior
```

unless temporarily required for backward compatibility and clearly hidden from normal product UI.

### B. Discount Create / Edit

Add:

```text
Combination Behavior
- Follow Cafe Policy
- Exclusive
```

Package requirements must support:

```text
All Variants
Selected Variants
```

Coupon creation/edit should display short generated codes cleanly.

Priority should only be shown where it has a meaningful role under the final conflict-resolution model.

Avoid showing technically valid but product-meaningless controls.

### C. POS Multi-Discount Workflow

POS must allow users to add more than one eligible discount when Cafe Policy permits it.

The UI must:

- Show currently applied discounts.
- Distinguish coupon/configured discounts.
- Allow removing a specific applied discount if authorized.
- Explain policy rejection clearly.
- Prevent client-only combinations that backend will reject.
- Always use backend quote results as authoritative.

Examples of user-facing rejection messages:

```text
This coupon is exclusive and cannot be combined with another discount.

This cafe allows only one discount per item.

Multiple coupon codes are disabled by Cafe Policy.

Maximum 3 discounts are allowed on this order.

This combination would exceed the cafe's maximum discount limit.
```

### D. Order Totals and Receipt Presentation

Display each applied discount separately where practical.

Example:

```text
Latte 10%                 -1,000
WELCOME                    -500
Bundle Offer               -750
--------------------------------
Total Discounts           -2,250
```

Update:

- POS cart.
- Payment dialog.
- Order detail.
- Receipt preview.
- Printed receipt.
- Order History.
- Refund presentation where affected.

Do not break historical orders created under the old discount model.

### E. Navigation

Preferred final navigation:

```text
Discounts
├── Policies
└── Settings
```

If moving routes during the same phase creates unacceptable risk, preserve compatibility redirects or stage the route change carefully.

### F. Localization

All new UI must support:

- English.
- Arabic.
- RTL.
- Clear business language.
- Consistent terminology across Settings, Create/Edit, POS, Receipt, and History.

## Phase 3 Tests

Flutter coverage should include:

- Owner access.
- Manager access.
- Employee restriction.
- Settings load/save.
- Same-item stacking selector.
- Multiple coupons toggle.
- Coupon + configured toggle.
- Order + item toggle.
- Maximum count.
- Maximum percentage.
- Conflict resolution.
- Follow Cafe Policy.
- Exclusive discount.
- Package variant picker.
- Short coupon display.
- Multi-discount POS add/remove.
- Policy rejection messages.
- Receipt totals.
- Order detail/history.
- EN/AR/RTL.
- Unsaved Settings behavior where applicable.

## Phase 3 Exit Criteria

Phase 3 is complete when:

- Owner/Manager can understand and configure Cafe Discount Policy without engine jargon.
- Create/Edit supports per-discount exclusivity.
- Package variants work end to end.
- POS can use multiple discounts according to backend policy.
- Receipts and order details display the correct breakdown.
- Focused Flutter tests pass.

---

# PHASE 4 — Regression, Hardening, Migration Safety, and Release

## Objective

Prove the new system is safe for production and that existing discount behavior was not broken.

No major new functionality should be added in this phase.

## Regression Matrix

Test at minimum:

```text
Single discount
Multiple discounts

Different-items-only
Same-item stacking

Multiple coupons ON
Multiple coupons OFF

Coupon + configured ON
Coupon + configured OFF

Item + order ON
Item + order OFF

Exclusive discount
Follow Cafe Policy

Maximum count
Maximum percentage

Best saving
Priority

Package all variants
Package selected variants

Existing long coupon
New short coupon

Owner
Manager
Employee

Held order
Draft order
Payment retry
Payment revalidation
Zero-balance order
Refund
Receipt
Order History

English
Arabic
RTL
```

## Backend Quality Gates

Run:

```text
Focused Discount tests
Relevant POS/payment tests
Relevant order/refund/receipt tests
Full backend test suite
Pint
git diff --check
```

Investigate failures before classifying them as unrelated.

## Flutter Quality Gates

Run:

```text
Focused Discount tests
POS tests
Order tests
Receipt tests
Full Flutter test suite
flutter analyze
dart format --set-exit-if-changed
git diff --check
```

## Build Gates

Require successful release builds for supported operational targets:

```text
Windows release build
Android release build
```

Run Web checks where affected by shared Flutter code.

## Manual Acceptance

Perform at least one end-to-end acceptance scenario covering:

```text
Owner changes Cafe Discount Policy
→ creates/edits discounts
→ package uses selected variants
→ short coupon generated
→ multiple discounts applied in POS
→ same-item policy enforced
→ payment succeeds
→ receipt is correct
→ order history preserves applied discounts
```

Repeat representative flow in Arabic/RTL.

---

# 8. Backward Compatibility Requirements

Do not break:

- Existing discounts.
- Existing long coupon codes.
- Existing orders.
- Existing published/historical order snapshots.
- Existing usage counters.
- Existing tenant isolation.
- Existing branch/customer/channel/payment constraints.
- Existing zero-balance behavior.
- Existing receipt/history records.

Use additive migrations.

Avoid destructive schema replacement in this feature.

If a legacy field becomes obsolete:

- Keep it temporarily if required for safe migration.
- Stop exposing it in new public UI.
- Document planned cleanup separately.

---

# 9. Non-Goals for This Plan

Unless implementation findings prove otherwise, do not expand this plan into:

- Full unified permission-system implementation.
- Loyalty redesign.
- Automatic promotion rollout before production readiness.
- New tax behavior.
- New pricing behavior.
- New modifier-discount model.
- Branch-specific Discount Settings unless a real requirement emerges.
- User-selectable stacking calculation algorithms.
- Large redesign of unrelated Cafe Settings.

---

# 10. Implementation Rules for Codex / Claude

When implementing any phase:

1. Read this full plan first.
2. Inspect the current repository before changing architecture.
3. Treat current source code as the source of truth.
4. Preserve existing contracts unless the phase explicitly changes them.
5. Prefer additive migrations.
6. Do not silently delete legacy data.
7. Do not rewrite unrelated Discount code.
8. Keep backend authoritative for eligibility, policy, totals, and payment validation.
9. Do not perform authoritative discount calculations only in Flutter.
10. Add focused tests before broad regression.
11. Stop and report if repository reality materially conflicts with this plan.
12. Do not implement later phases early unless required to keep the current phase compiling and tested.
13. Keep changes scoped and reviewable.
14. Update relevant project documentation/handoff notes when a contract changes.
15. Do not commit or push unless explicitly requested.

---

# 11. Phase Summary

| Phase | Scope |
|---|---|
| Phase 1 | Domain + DB + policy contract + package variants + short coupons |
| Phase 2 | Multi-discount backend engine + policy enforcement + payment safety |
| Phase 3 | Discount Settings + Create/Edit + POS + receipt/history Flutter integration |
| Phase 4 | Full regression + hardening + build + manual acceptance |

---

# 12. Definition of Done

This feature is complete when:

- Cafe Owner/Manager can define the cafe's Discount Policy.
- The system supports multiple discounts per order when policy allows.
- The cafe can choose different-items-only or same-item stacking.
- The cafe can control multiple coupons and coupon/configured combinations.
- Individual discounts can be exclusive or follow Cafe Policy.
- Maximum discount count and total discount limits are enforced.
- Package discounts support selected variants.
- New generated coupon codes are short and collision-safe.
- POS, payment, receipt, refund, and history remain correct.
- Historical orders remain stable.
- Backend and Flutter regression suites pass.
- Windows and Android release builds pass.
- EN/AR/RTL acceptance succeeds.
