# Discount System V3 — Phase 4 acceptance (final hardening)

Source plan: [plans/discount_system_v3_implementation_plan.md](../plans/discount_system_v3_implementation_plan.md). Contracts: [Phase 1](discount_v3_phase1_contract.md), [Phase 2](discount_v3_phase2_contract.md), [Phase 3](discount_v3_phase3_contract.md). Checkpoints: Phase 1+2 `a5d8857`, Phase 3 `2822c06`. Date: 2026-10-08.

**Status: PHASE 4 CODE VERIFIED — MANUAL ACCEPTANCE PENDING.** Automated gates pass. Native Windows GUI acceptance, a live POS session and physical printing were not performed.

## 1. Scope reviewed

- **Backend:** Cafe Discount Policy, create/edit and `combinationBehavior`, package variant requirements, coupon generation and redemption, the multi-discount engine, `order_discounts`/usages, quote/apply/payment, refunds, paid snapshots, receipt/history serialization, and legacy single-discount compatibility.
- **Flutter:** Settings, Policies navigation, Create/Edit, the package variant picker, POS selection, the applied/excluded review, cart and payment, receipt and history, and EN/AR/RTL.

Phases 1–3 already map every acceptance item in sections 3–11 of the Phase 4 brief to a test. The `DiscountV3*` suites cover policy, packages, coupons, the engine, payment and concurrency. Gaps were only closed where an end-to-end flow had been tested in pieces (§4).

## 2. Environment

- **Backend:** the local Docker `cafe_backend-backend-1` container (PHP **8.4.25**, PHPUnit 12.5.28) against the local PostgreSQL 16 test database `cafe_system_618_testing`.
  - The fixture asserts the database name.
  - No dev, operational or production database was migrated, seeded or written.
  - Nothing was deployed.
- **PHP 8.5 is not installed on this machine:** the host has 8.3 without `pdo_pgsql`, and Docker has 8.4. Every run used `-d memory_limit=1G`.
- **bcmath is missing in the container.** Only a Phase 2 test helper calls `bcdiv` (`DiscountV3MultiDiscountEngineTest::line`); application code does not. Runs used an out-of-repo polyfill via `-d auto_prepend_file=/tmp/bcpoly.php`. Without it, those 3 tests error on the undefined function. With it, they pass (25/25).
- **The local `backend/.env` has `APP_LOCALE=en`** (`.env.example` ships `ar`). 10 locale-dependent, non-discount tests fail for that reason only (§6).
- **Flutter:** 3.44.8 stable on Windows 11.
- **Environment incident:** during the run, drive C: reached 0 bytes free. That crashed the Dart compiler in two Flutter runs and stopped the Docker engine.
  - Only this session's Android Gradle intermediates were deleted (`windows_application/build/app` and today's Android plugin build folders).
  - Results below come only from runs that completed normally.

Exact commands (from `cafe_backend/`):

```
docker exec cafe_backend-backend-1 php -d memory_limit=1G -d auto_prepend_file=/tmp/bcpoly.php vendor/bin/phpunit --filter Discount
docker exec cafe_backend-backend-1 php -d memory_limit=1G -d auto_prepend_file=/tmp/bcpoly.php vendor/bin/phpunit --log-junit /tmp/p4-full.xml
docker exec -e APP_LOCALE=ar cafe_backend-backend-1 php -d memory_limit=1G vendor/bin/phpunit --filter 'ArabicValidationErrorPresentationTest|test_04_database_unique_violation|test_28_shift_lifecycle_errors|test_03_concurrent_opens'
cd windows_application && flutter test --concurrency=3 --reporter json
flutter analyze ; dart format --set-exit-if-changed <touched files>
flutter build windows --release ; flutter build apk --release ; flutter build web --release
docker exec cafe_backend-backend-1 vendor/bin/pint --test tests/Feature/DiscountV3Phase4AcceptanceTest.php ; git diff --check
```

## 3. Automated results

| Gate | Result |
|---|---|
| Backend Discount (`--filter Discount`, includes the new Phase 4 suite) | **181 passed**, 2994 assertions, exit 0 |
| Backend full regression (one run) | 1218 tests: **1164 passed**, 41 failures + 12 errors, 1 skipped, 13026 assertions. **No Discount test fails.** See §6. |
| Flutter full suite | **1749 passed, 22 failed**, the same 22 historical failures (§6) |
| `flutter analyze` (full) | 29 info-level findings, all pre-existing (sales and receipt-renderer test), none in touched files |
| `dart format` on touched Dart files | clean |
| Pint on the touched PHP file | pass |
| `git diff --check` | clean |
| Windows release build | exit 0 (176 s) |
| Android release APK | exit 0 (506 s, 82.2 MB). `flutter doctor` reports unaccepted Android SDK licenses; the build still succeeded. KGP deprecation warning from `desktop_drop` / `file_picker`. |
| Web release build | exit 0 (131 s); `PosCubit` is shared code |

## 4. End-to-end scenarios verified (automated, real HTTP + PostgreSQL)

New `backend/tests/Feature/DiscountV3Phase4AcceptanceTest.php` (4 tests, 115 assertions):

1. **Coupon retention (critical regression).** Apply coupon A, add configured B (A is re-sent by id), then remove B: A stays applied with the backend total. Removing every discount, or dropping the coupon from a set, revokes id-only retention (`DISCOUNT_NOT_FOUND`).
2. **Foreign coupon ids are rejected cleanly.** Each of these returns 422 with no SQL, PDO, stack or framework text in the body, and the saved intent is untouched:
   - a foreign-tenant coupon id
   - an unknown id
   - a configured id sent as a coupon
   - a non-numeric id
   - a negative id
3. **Coupon expires between quote and payment.** Payment is rejected with `DISCOUNT_EXPIRED`, with no payment and no usage. After the coupon is restored, a fresh quote settles once and consumes two usages.
4. **Dormant policy values.** Settings are max 3, same-item stacking, multiple coupons, coupon+configured, order-after-items, priority and 40 %.
   - Turning multiple discounts off keeps all of them (effective max 1).
   - A legacy eight-field PUT resets nothing.
   - Turning it back on restores max 3. Automatic stays off.

Already covered by Phase 1–3 suites and re-run green here:

- 100 → 10 % → 20 % = 28 / 72 sequential stacking
- different-items-only allocation
- exclusive, coupon and item/order rules
- count and total-% caps
- best-saving and priority with deterministic ties
- strict ineligibility
- set/apply idempotency, legacy replace semantics and stale review/quote
- payment-method change after quote (`ORDER_TOTAL_CHANGED`)
- concurrent last-use, duplicate payment, policy and discount races, and two clients editing one order
- per-customer and daily limits
- zero-balance settlement
- paid snapshots unchanged after policy edits
- refunds from paid net
- package variants (Large satisfies, Regular does not; quantity, all/selected, edit, invalid/cross-tenant rejection, legacy rows)
- 5-character codes, collisions, case-insensitive uniqueness and long legacy codes

Flutter (focused suites, all green):

- POS multi-discount (16)
- Settings V3 (8)
- presentation and receipt (9)
- routing (9)
- Create/Edit (40)
- configured-discount POS (3)

Receipt rasters for multiple discount lines at 58 mm and 80 mm and Arabic RTL are covered by `multi_discount_presentation_test.dart` and `receipt_renderer_test.dart`.

## 5. Defects found and fixed

**D4-01. A new client on an older backend silently replaced an existing discount** (brief §11). When the backend did not advertise `supportsMultipleDiscounts`, adding a discount to an order that already had an explicit discount sent the legacy replace-one `apply`, which drops the existing discount.

- **Fix** (`PosCubit.discountRequestAdding` / `_previewDiscount`):
  - The first discount still uses legacy `apply`.
  - Adding to an existing explicit intent sends **no request** and shows the existing localized `DISCOUNT_CLIENT_UPDATE_REQUIRED` message ("Update this app…").
  - Automatic lines are not explicit, so they don't trigger the block.
  - Removal is unchanged.
- **Regression test:** `multi_discount_v3_test.dart`, "an older backend uses apply for the first discount but never silently replaces an existing one". It replaces the Phase 3 test that asserted the destructive replace.
- A first version also counted automatic lines. That broke `configured_discount_only_test.dart` (2 tests); it was narrowed to explicit intents and both pass.

**D4-02. The Cafe Configuration "Discount settings" item switched modules (UX, reported in manual review).** In Phase 3 the item pointed to `/discounts/settings`, so clicking it inside Cafe Configuration jumped to the Discounts module. The sidebar, header and tabs all changed.

- **Fix:**
  - `/cafe-configuration/discount-settings` again renders the same `DiscountSettingsScreen` inside the Cafe Configuration layout (same access rule: Owner, plus Manager), and the item points there.
  - Discounts → Settings (`/discounts/settings`) remains the second entry point, with its Policies/Settings tabs.
  - Both entry points use the same cubit and backend endpoint.
- **Regression tests:** `discount_settings_routing_test.dart` covers:
  - direct access for each role: the path stays, the Cafe Configuration navigation is shown, and the Discounts tabs are not
  - a new test where Owner and Manager tap the item from Printing and stay in Cafe Configuration

**D4-03. Cafe Discount Policy screen redesign (UX, from manual review).** Behavior, keys and saved values are unchanged; only presentation changed.

- **New shared components** in `lib/shared/widgets/settings_ui.dart`, reusable by any settings page:
  - `SettingsPageHeader`
  - `SettingsSectionCard`
  - `SettingsSwitchTile`
  - `SettingsChoiceCards`
  - `SettingsNumberStepper`
  - `SettingsCompactField`
  - `SettingsNotice`
  - `SettingsActionBar`
  - `SettingsSummaryRow`
- **The screen:**
  - Four section cards (General, Combining, Safety limits, Conflict resolution), each with an icon and a one-line description.
  - Stacking and conflict resolution are selectable cards.
  - The maximum count is a 1–10 stepper and the cap is a compact % field.
  - While multiple discounts are off, the Combining card explains how to enable it; dormant values are still never changed.
  - A status badge shows Default values, Saved or Unsaved changes.
  - A sticky bottom bar holds Reload, Reset and Save.
  - The live "In effect now / After you save" summary uses allowed/not-allowed icons. It sits beside the settings at 1100 px and wider, and below them on narrower screens.
- **Accessibility:** each choice card is one merged semantics node (label, selected state and tap).
- **Tests:**
  - New `test/shared/widgets/settings_ui_test.dart` (6).
  - `discount_policy_v3_settings_test.dart` extended for the hint, status, layout and stepper.
- **Not yet verified:** rendered EN/AR at 900 and 1600 px in an offscreen visual check only; native Windows review is still pending.

No backend defect was found. No monetary, tax, usage or locking rule changed.

## 6. Known unrelated baseline failures

- **Backend: 43 of the 53 failures match the saved Plan 2 full-run record** (`docs/verification/discount-plan2-20261005-full-backend.xml`, 44 failures; `ExampleTest` health now passes). By class:

  | Failures | Class |
  |---|---|
  | 10 | SupplierAccountsPayable |
  | 5 | ManufacturingCoreFlow |
  | 5 | FinanceDashboard\* |
  | 4 | demo seeders |
  | 3 | AuthPhase\* |
  | 2 | ReportsOverview |
  | 2 | SalesReportingUnion |
  | 2 | ShiftCashSummary |
  | 2 | SmartSearch |
  | 1 each | BranchCashDrawer, CashierAuthorization, CustomerAging, Phase12Authorization, PurchasingPhase1, SalesInvoiceLinePricing, StagingInitializer, WarehouseConfigurationRepair |

- **Backend: the other 10 come from the environment.** They are 7 `ArabicValidationErrorPresentationTest`, 2 `ShiftDrawerLifecycleTest` (04, 28) and 1 `ShiftOpenConcurrencyTest` (03). They expect the Arabic default locale. With `APP_LOCALE=ar` all 18 tests in those groups pass.
- **Flutter: the 22 failures** are the same tests the Phase 3 record reproduced at HEAD:
  - cashier route guard (2), customer-management routing (2) and goldens (4)
  - cashier dashboard and inventory (3), auth session storage (2)
  - tax label (1), cash banks (1), menu navigation (1)
  - orders payment screen (3; also failing with this phase's changes stashed)
  - sales phase three (2), orders screen (1)

## 7. Manual / live acceptance

**Executed:** none. No Windows GUI automation was used in this session, and no live POS session or printer was available. Widget tests are not claimed as manual verification.

**Pending checklist** (Windows release build, isolated backend, EN then AR/RTL):

1. Discounts → Policies / Settings:
   - Owner saves.
   - Manager follows grants.
   - Employee is blocked.
   - Turning off multiple discounts with max 3, then reloading and turning it back on, still shows max 3.
2. Create/edit a discount with Exclusive and a priority. Edit an unrelated field and reload: targets, branches, customers and channels are unchanged.
3. Package: Large Latte ×1 + Cookie ×1, with Large selected. Regular Latte does not qualify. Search and page the picker, then edit and reload: the chips are restored.
4. POS:
   - Add coupon A and configured B, then review, confirm, pay, check the receipt and order history. The totals must match on every screen.
   - Remove B and confirm A remains.
   - Remove A and confirm the cart is clear.
5. Excluded discount: with multiple discounts off, the review shows "Not applied" with its reason.
6. Stale review/quote: change the policy while the payment dialog is open; the cashier must confirm the refreshed total again.
7. Print the 58 mm and 80 mm receipts with two discounts, in EN and AR.
8. Optional: connect to a pre-V3 backend; adding a second discount shows "Update this app…".

## 8. Printing

The renderer and serialization tests pass for multiple lines, "Total discounts", single-discount legacy receipts, Arabic/RTL, and 58/80 mm. **Physical printing: NOT VERIFIED** (no printer hardware).

## 9. Remaining release blockers / actions

- Manual acceptance (§7), including native Windows EN/AR and a physical receipt.
- Before release, re-run the backend on the intended PHP 8.5 image with `bcmath` and `APP_LOCALE=ar`, to remove the two environment caveats above.
- Android SDK licenses are unaccepted on this machine; `desktop_drop` / `file_picker` need Built-in Kotlin migration before a future Flutter version.
- None is a code defect in Discount V3.
