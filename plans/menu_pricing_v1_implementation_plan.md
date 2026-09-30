# Menu Pricing V1 Implementation Plan

Status: Finalized product decisions; implementation not started.

This plan preserves the existing Laravel service structure, Flutter feature/Cubit architecture, and Review & Publish workflow.

## 1. Confirmed product contract

| Area | V1 behavior |
|---|---|
| Price identity | `Tenant + Menu + Variant + Branch + Channel` |
| Repeated placements | One menu-specific price per variant across all sections/placements of the same menu |
| Authorization | Owner and Manager allowed; Employee denied |
| Individual edits | Set any valid positive selling price |
| Reset | Remove the menu-specific override and restore inheritance |
| Manual review | Sets and resets coexist in one atomic reviewed batch |
| Bulk operations | Percentage/fixed increase and decrease |
| Bulk scope | All eligible variants in the selected menu/context, across all pages |
| Filters | Search/category filters affect browsing only |
| Bulk inheritance | Participating inherited items become menu-specific overrides |
| Rounding | Backend-authoritative exact decimal calculation with configurable commercial rounding |
| Activation | Save configuration, then Review & Publish |
| Tax | Existing tax logic remains unchanged |
| History | Existing orders retain pinned published prices |

Cost prices, modifier surcharges, tax configuration, and unrelated authorization remain outside this feature.

## 2. Price storage and resolution

Store one current menu-specific selling price per:

```text
Tenant + Menu + Variant + Branch + Channel
```

Resolve prices in this order:

```text
Menu-specific price
    -> if absent: Branch + Channel override
    -> Branch override
    -> Channel override
    -> Variant base price
```

Changing or resetting a menu-specific price must not modify shared catalog prices, another menu's overrides, or another branch/channel.

A variant repeated within the same menu is displayed and adjusted once. Its menu-specific price applies to every placement in that menu.

Existing menus retain shared-price fallback without a backfill. The UI identifies inherited prices and their source. Once an override exists, shared-price changes no longer affect that menu/context until the override is reset.

Do not update `product_variants.base_price`, shared price overrides, or the legacy `products.price` mirror through this feature.

## 3. Eligibility and scope

Eligible configuration rows require:

- Active, non-archived product and variant.
- Valid placement in the selected menu through a non-archived placement and active, non-archived section.
- Valid menu, branch, and channel context.

| Condition | Behavior |
|---|---|
| Temporarily sold out | Still configurable |
| Outside schedule | Still configurable |
| Hidden placement | Still configurable; visibility indicated |
| Repeated placement | Deduplicated by variant |
| Open-price product | Read-only; excluded from adjustments |
| Inactive/archived product or variant | Excluded |

Bulk target discovery is server-side. Pagination and browsing filters never reduce its scope.

Show prominently before preview and apply:

> This adjustment applies to all eligible prices in this menu, not only the currently filtered results.

Display the selected menu, branch, channel, and eligible variant count beside this warning.

## 4. Manual editing and reset

Manual drafts support item actions `set` and `reset`. Each variant has at most one draft action; changing its action replaces the previous draft action.

For `set`:

- Create or update the menu-specific override.
- Require a positive price within supported precision/range.
- Permit an increase or decrease.

For `reset`:

- Resolve the inherited price while ignoring the current menu-specific override.
- Preview the resulting value and source.
- Remove the override on apply.
- Do not store the inherited value as a replacement override.

Provide the UI action **Reset to inherited price**.

Sets and resets appear together in one **Review Price Changes** preview and apply in one transaction.

| Product/variant | Action | Current | Result |
|---|---|---:|---:|
| Latte | Set | 12,000.00 | 13,000.00 |
| Espresso | Reset to inherited | 8,000.00 | 7,500.00 — Branch override |
| Mocha | Set | 10,000.00 | 11,500.00 |

Any invalid requested item rejects the complete manual batch.

Resetting an override remains meaningful when the resulting price equals the current price: inheritance changes even though the monetary difference is zero.

When no override exists, show **Already inherited** and disable the normal reset action. A server request targeting an already inherited item returns an explicit unchanged result.

Reset immediately restores configured-price inheritance after apply; published selling prices change only through Review & Publish.

## 5. Bulk calculations and override creation

Support:

```text
percentage_increase
fixed_increase
percentage_decrease
fixed_decrease
```

Calculate from each variant's current effective configured price, whether menu-specific or inherited.

| Operation | Raw calculation |
|---|---|
| Percentage increase | `original × (1 + percentage / 100)` |
| Fixed increase | `original + amount` |
| Percentage decrease | `original × (1 − percentage / 100)` |
| Fixed decrease | `original − amount` |

Every participating inherited variant receives a menu-specific override containing the final reviewed price, including when rounding leaves its monetary value unchanged. This changes inheritance and must be recorded.

Existing menu-specific overrides are updated to the final reviewed price.

Show prominently in bulk preview:

> This adjustment will create menu-specific prices for inherited items. Future changes to their shared inherited prices will no longer affect them until they are reset to inherited pricing.

Show counts for participating inherited variants, existing menu-specific overrides, overrides to create, existing overrides to change, and monetarily unchanged prices.

Bulk operations remain separate from manual draft batches.

## 6. Validation and commercial rounding

Every persisted selling price must be strictly greater than zero.

Backend validation requires:

- Positive, finite percentage/fixed inputs.
- Percentage decrease less than `100`.
- Supported input precision and range.
- Positive raw adjustment results.
- Positive final results after rounding/precision normalization.
- Final prices within the existing `decimal(12,2)` range.

Reject the complete operation if any requested result is invalid. Never skip invalid requested rows, clamp prices, or partially apply a batch. Rounding must not rescue a zero or negative raw adjustment result.

| Mode | Calculation |
|---|---|
| `no_rounding` | Normalize raw result to database money precision |
| `round_up` | `ceil(raw / step) × step` |
| `round_down` | `floor(raw / step) × step` |

For `round_up` and `round_down`, accept any valid positive decimal `roundingStep` within supported money precision/range. No currency-specific preset list is enforced by the backend.

For `no_rounding`, use `roundingStep: null`. Normalize to two decimals using the existing positive-decimal database precision behavior (half-up), explicitly in the service so preview and persistence agree. This is precision normalization, not commercial step rounding.

Use exact decimal arithmetic throughout. Flutter renders backend calculations and does not perform authoritative rounding.

For raw price `12,300.53` and step `500`:

| Mode | Final price |
|---|---:|
| No rounding | 12,300.53 |
| Round up | 12,500.00 |
| Round down | 12,000.00 |

Persist the final price and exact reviewed decimal step without floating-point conversion.

## 7. Currency-aware Flutter presets

Use existing tenant/cafe currency metadata and formatting where available. Presets are UI conveniences, not domain restrictions.

| Currency characteristics | Example presets |
|---|---|
| SYP-like large-unit currency | `100`, `500`, `1000` |
| USD/EUR-like currency | `0.05`, `0.10`, `0.50`, `1.00` |

Always offer **Custom Step**. If metadata is unavailable, keep Custom Step available rather than assuming SYP.

Changing a rounding preset or custom step invalidates the current preview and requires recalculation. Format prices/steps using existing currency formatting while preserving exact decimal wire values.

## 8. Opposite-direction results

Commercial rounding may reverse final price movement. This is allowed.

```text
Original:       12,300.00
Increase:       2%
Raw:            12,546.00
Rounding:       Round down to 1,000
Final:          12,000.00
Difference:       -300.00
```

Do not change the rounding mode, clamp the result, or reject it solely because direction reversed.

The backend calculates:

```text
finalMovement: increase | decrease | unchanged
oppositeDirection: true | false
```

- Requested increase with a negative final difference: opposite direction.
- Requested decrease with a positive final difference: opposite direction.
- Zero final difference: unchanged, not opposite direction.

Return `oppositeDirectionCount` in the summary. When positive, Flutter displays prominently:

> 3 prices will move in the opposite direction because of the selected rounding rule.

Require explicit confirmation of those reviewed results before enabling Apply. Record that acknowledgement with the applied adjustment.

## 9. Database changes

Retain the planned three-table structure.

| Table | Purpose and fields |
|---|---|
| `menu_variant_prices` | Current price: tenant, menu, variant, branch, channel, positive final price, actor, timestamps |
| `menu_price_adjustments` | Context, actor, operation, amount, rounding mode/step, status, fingerprint, expiry, preview summary, confirmation data, applied timestamp |
| `menu_price_adjustment_items` | Variant, action, original price/source, prior override state/revision, raw price, final price/source, difference, movement, opposite-direction flag, dependency fingerprint |

Requirements:

- Unique constraint on `(tenant_id, menu_id, product_variant_id, branch_id, channel)`.
- `menu_variant_prices.price` uses `decimal(12,2)` with a positive-price constraint.
- Appropriate foreign keys and context query indexes.
- Store monetary values as exact decimals.
- Preserve raw calculated values and reviewed rounding steps as lossless canonical decimal values/strings.
- Preserve prior override existence and value.
- Distinguish configuration changes from monetary changes.
- Manual items use `set`/`reset`; their adjustment uses `manual_changes`.
- Reset physically removes the current override; adjustment/audit history remains.
- Manual changes use `no_rounding` with a null step.
- Audit rounding mode and step exactly as reviewed.

Use additive migrations. Do not rewrite shared prices or historical published snapshots.

## 10. Backend services and authorization

| Service | Responsibility |
|---|---|
| `MenuVariantPriceResolver` | Menu-specific resolution, inherited-only resolution, fallback delegation |
| `MenuPricingQueryService` | Eligible collection, overview, published-price comparison |
| `MenuPriceAdjustmentService` | Validation, calculation, previews, mixed manual actions, bulk apply, audit |

Keep shared pricing inside the existing catalog resolver.

Update menu-aware consumers `MenuPreviewService`, `MenuValidationService`, and `PublishedMenuSnapshotBuilder`. Each passes the owning menu identity and resolves prices consistently.

Use one centralized pricing authorization boundary:

```text
Owner   -> allowed
Manager -> allowed
Employee -> denied
```

Enforce it on overview, preview, status, and apply APIs, plus Flutter destination visibility/direct navigation. Use existing effective-role resolution and capability mechanisms where practical.

Do not scatter role checks or change unrelated Menu Management authorization. Structure the policy so a future `menu.pricing.manage` permission can replace its internal decision.

## 11. API contract

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/v1/admin/menus/{menu}/pricing` | Pricing overview |
| POST | `/api/v1/admin/menus/{menu}/pricing/adjustments/preview` | Preview bulk or mixed manual changes |
| GET | `/api/v1/admin/menus/{menu}/pricing/adjustments/{adjustment}` | Preview/application status |
| POST | `/api/v1/admin/menus/{menu}/pricing/adjustments/{adjustment}/apply` | Apply the stored reviewed adjustment once |

Overview parameters: `branchId`, `channel`, `search`, `categoryId`, `page`, `perPage`.

Return identity, configured price/source, inherited price/source, override presence, published price/version, eligibility, and currency metadata where available. Prices use exact decimal strings. Published comparison uses the matching menu/placement/variant in the current branch/channel snapshot; missing entries show **Not published**.

Bulk preview:

```json
{
  "branchId": 1,
  "channel": "pos",
  "operation": "percentage_increase",
  "amount": "2",
  "roundingMode": "round_down",
  "roundingStep": "1000.00"
}
```

Mixed manual preview:

```json
{
  "branchId": 1,
  "channel": "pos",
  "operation": "manual_changes",
  "items": [
    {"variantId": 10, "action": "set", "price": "13000.00"},
    {"variantId": 11, "action": "reset"},
    {"variantId": 12, "action": "set", "price": "11500.00"}
  ]
}
```

Manual validation:

- Require `price` for `set`; prohibit it for `reset`.
- Reject duplicate variant IDs and unsupported actions.
- Do not accept bulk amount/rounding controls on manual requests.

Bulk validation:

- Discover the complete target collection server-side.
- Do not accept a client-provided subset as the bulk target.
- Validate operation, amount, rounding mode, and step.

Apply references the stored adjustment and confirmation:

```json
{
  "previewFingerprint": "server-issued-fingerprint",
  "confirmReviewedResults": true,
  "acknowledgeOppositeDirection": true
}
```

Require opposite-direction acknowledgement only when the stored preview count is positive. Apply does not accept replacement prices, rounding settings, or target IDs.

Derive actor/tenant from authentication. Validate tenant ownership, menu membership, lifecycle, branch/channel, complete result validity, and adjustment ownership/context. Return stable domain codes and localized client mappings for invalid values, stale/expired previews, and denied access.

## 12. Preview contract

Every bulk row includes:

- Original effective price and source.
- Whether an override existed.
- Raw calculated price.
- Rounding mode and reviewed step.
- Final new price and signed difference.
- Final movement and opposite-direction flag.
- Configuration effect: create override, update override, or unchanged existing override.

```json
{
  "variantId": 10,
  "action": "set",
  "hadMenuOverride": false,
  "originalEffectivePrice": "12300.00",
  "originalSource": "branch_channel",
  "rawCalculatedPrice": "12546.00",
  "roundingMode": "round_down",
  "roundingStep": "1000.00",
  "finalNewPrice": "12000.00",
  "difference": "-300.00",
  "finalMovement": "decrease",
  "oppositeDirection": true,
  "configurationEffect": "create_override"
}
```

Manual previews show all sets and resets together. Reset rows include inherited result/source and `configurationEffect: remove_override`; the resulting value is not persisted as a replacement override.

Summary fields:

```text
eligibleVariantCount
inheritedVariantCount
menuOverrideVariantCount
overridesToCreateCount
overridesToUpdateCount
overridesToRemoveCount
finalIncreaseCount
finalDecreaseCount
unchangedPriceCount
configurationChangedCount
oppositeDirectionCount
```

Counts describe the reviewed target set. Manual resets can contribute to monetary movement counts but are not classified as opposite-direction bulk results. Also return context, operation, amount, rounding settings, excluded count, and expiry.

## 13. Atomic apply, stale detection, and retries

Apply must:

1. Authorize the actor and verify adjustment context.
2. Validate explicit confirmation and required acknowledgement.
3. Lock the adjustment and relevant records.
4. Revalidate target membership, eligibility, and dependencies.
5. Revalidate complete result validity.
6. Execute all reviewed sets/resets in one transaction.
7. Write audit records and mark the adjustment applied.

Stale detection includes override creation/update/removal; inherited price/source changes used by calculations; inherited dependency changes behind resets; relevant lifecycle/menu membership changes; and changes to the complete bulk eligible collection.

Use a consistent transaction/locking strategy covering pricing, composition, and shared-source races. Locking only new menu-price rows is insufficient.

A mixed manual batch is atomic. A bulk batch is atomic. One invalid requested result or stale dependency prevents the complete apply.

Repeated application returns the recorded result. After a timeout, retrieve status or retry the same adjustment ID; never automatically create a second adjustment.

Audit actor, context, operation, reviewed settings, acknowledgements, item actions, before/after configuration, and final prices.

## 14. Flutter workflow

Extend the existing `menu_management/pricing` feature with the planned models, repository methods, Cubits, states, views, and widgets.

Proposed files:

```text
pricing/models/menu_pricing_models.dart
pricing/models/menu_price_adjustment_models.dart
pricing/controllers/menu_pricing_cubit.dart
pricing/controllers/menu_pricing_state.dart
pricing/views/menu_pricing_screen.dart
pricing/widgets/menu_pricing_table.dart
pricing/widgets/price_adjustment_dialog.dart
pricing/widgets/price_adjustment_preview.dart
```

Integrate with `MenuCatalogRepository`, `MenuModuleNavigation`, `app_router.dart`, `service_locator.dart`, and English/Arabic localization resources. Route: `/menu-management/pricing`.

The Pricing tab contains required context selectors, browsing filters, grouped active variants, published/configured prices and sources, editable price/reset action, **Review Price Changes**, and **Adjust All Prices**.

Manual workflow:

```text
Edit/reset rows -> One mixed preview -> Confirm -> Atomic apply -> Review & Publish
```

Bulk workflow:

```text
Choose operation/amount
  -> Choose rounding/custom step
  -> Preview all eligible variants
  -> Review scope, inheritance, and direction warnings
  -> Explicit confirmation
  -> Atomic apply
  -> Review & Publish
```

Preserve manual drafts across pagination. Use existing unsaved-navigation guards when changing context or leaving. Require manual drafts to be reviewed/saved or discarded before starting bulk; do not silently combine them.

Any change to operation, amount, or rounding invalidates the previous preview.

Include English/Arabic localization, RTL, keyboard access, desktop-first layout, safe error mappings, and loading, empty, forbidden, failure, stale-preview, applying, and recovery states.

## 15. Publication, POS, tax, and history

After saving, display:

> Prices saved. Review and publish to update selling prices.

Preserve branch/channel collection publication. Do not replace the active collection with only the edited menu. Review exposes other pending changes and assignment/readiness blockers.

Configured prices for an unassigned context can remain saved, but the UI explains assignment is required for appearance in that scope. Determine pending price changes by comparison with the current published snapshot rather than a simple dirty flag.

Published `effectivePrice` receives the resolved menu-specific or inherited selling price. Preserve existing snapshot compatibility and avoid a schema-version change unless implementation proves one necessary.

POS preserves placement identity so the same variant can have different published prices in different menus. Verify cart merging respects these identities and client-submitted prices cannot override the snapshot.

Tax continues through existing POS calculations. Do not add tax-inclusive/exclusive settings or pre-apply tax to stored prices.

Held/draft orders retain pinned snapshot prices and existing stale-version behavior for new orders. Publication rollback restores a snapshot without undoing saved configuration. Legacy flows without menu context retain shared-price behavior.

## 16. Tests and acceptance criteria

| Area | Required proof |
|---|---|
| Authorization | Owner/Manager allowed; Employee denied through UI/direct routes/APIs |
| Isolation | Other menus, branches, and channels unchanged |
| Repeated placements | One menu price and adjustment per variant |
| Mixed manual batch | Sets/resets preview together and apply atomically |
| Manual validation | One invalid item rejects complete batch |
| Reset | Removes override, restores correct fallback/source, rejects invalid inherited result |
| Equal-value reset | Removes override and audits inheritance change |
| Bulk calculations | All four operations calculate correctly |
| Bulk scope | Filters/pages never reduce targets |
| Bulk inheritance | Every participating inherited item receives an override, even with zero monetary difference |
| Inheritance restoration | Reset reconnects item to shared pricing |
| Rounding | Modes, exact multiples, custom steps, two-decimal normalization verified |
| Currency presets | UI presets follow metadata; Custom Step always available |
| Backend step validation | Valid decimal steps accepted independently of presets |
| Step persistence | Stored/audited step matches reviewed decimal value |
| Opposite direction | Allowed, correctly flagged/counted, warned, explicitly acknowledged |
| Positive prices | Zero/negative raw or final results reject complete operation |
| Preview agreement | Reviewed final values match persisted values |
| Stale detection | Source, override, lifecycle, membership changes invalidate previews |
| Atomicity | Mid-apply failure leaves all prices unchanged |
| Idempotency | Retry cannot duplicate adjustment |
| Eligibility | Hidden/sold-out/scheduled items configurable; open-price items read-only |
| Publication | Saved prices activate only after publication; collection preserved |
| POS | Correct menu placement price used |
| Tax/history | Existing tax behavior and pinned historical prices preserved |
| Audit | Complete settings, actions, acknowledgements, before/after evidence |

Run focused Laravel suites serially against the designated test database, affected Flutter tests, and static analysis. Finish with English/Arabic Windows acceptance and an end-to-end scenario covering independent menu prices, mixed reset/set changes, bulk inheritance creation, opposite-direction rounding, and publication.

## 17. Delivery sequence: eight phases

| Phase | Deliverable | Completion gate |
|---|---|---|
| 1 | Final contracts, centralized access policy, additive migrations | Identity, positive-price constraints, authorization and schema checks pass |
| 2 | Menu-specific and inherited-only resolvers | Menu/context isolation and complete fallback tests pass |
| 3 | Overview, mixed manual preview, four bulk calculations, rounding and summary contracts | Preview, scope, inheritance, precision and direction tests pass |
| 4 | Atomic apply, stale detection, idempotency, audit | Mixed/bulk atomicity, concurrency, retries and audit tests pass |
| 5 | Menu preview/validation/publication integration | All menu price consumers agree; collection/history compatibility preserved |
| 6 | Flutter Pricing tab, currency presets, mixed review, warnings and confirmation | Focused widget/Cubit checks, localization and static analysis pass |
| 7 | POS, tax, historical compatibility and regression verification | End-to-end pricing and English/Arabic Windows acceptance complete |
| 8 | Migration-first deployment, smoke checks and release acceptance | Runtime migrations and authorized production smoke checks complete |

V1 acceptance requires authorized users to review and atomically apply mixed manual edits/resets or complete-menu bulk adjustments, then publish correct menu-specific selling prices while preserving other contexts, existing tax behavior, and historical orders.
