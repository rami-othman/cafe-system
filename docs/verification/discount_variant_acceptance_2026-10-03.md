# Plan 1 closure verification - 2026-10-03 (Asia/Damascus)

Status: Plan 1 CLOSED. F1/F2/F3 passed; D1-13/D1-14 closed after observed interactions. Ready for Plan 2 as a separate authorized task; Plan 2 has not started. Full analyzer retains 29 pre-existing informational diagnostics (exit 1), no errors/warnings; scoped analysis is clean.

## Testing environment and fixture

Compose: `windows_application/integration_test/fixtures/discount_acceptance.compose.yml`, project `cafe-discount-acceptance-20261003`, separate PostgreSQL container and volumes. API `http://localhost:18100/api/v1`; static release Web `http://localhost:18000`, served by Python without a proxy. Operational project `cafe_backend` was only inventoried/read for image/vendor dependencies; no operational migrations, seeding or data writes.

Before migrations/seed/fixture mutations the container reported `APP_ENV=testing`, host `accept-postgres`, database `cafe_discount_acceptance_testing`. Existing migrations and base seed ran ONLY there. Guarded reproducible fixture script: `windows_application/integration_test/fixtures/create_discount_fixture.py`, run from repo root. Owner account is the seeded isolated testing owner. API creates Tea product 10 (Small 10 at 10.00, Large 11 at 20.00, XL 12), Cake 11, Latte 12 (45 variants) and 45 filler products. Published POS menu version 1, Main Branch tax 8%, drawer-backed open shift. No permission bypass.

Expected amounts recorded BEFORE POS execution: Small x2 = 20.00, Large x1 = 20.00; subtotal 40.00, fixed/per_unit 4.00 on Small only = discount 8.00, tax (40 - 8) x8% = 2.56, total 34.56. Large alone must be ineligible and rejected with discount remaining 0. Fixture manifests: `discount_acceptance_expected_2026-10-03.json`, `discount_acceptance_fixture_2026-10-03.json`.

## F2 - disposal

Permanent tests added before the fix. Initial lifecycle test command exit 1: all ten late success/error completions failed with emit-after-close across list, branches, references, save and delete. After guarded completions: exit 0, 22 tests. Active failures remain visible through the existing safe errors. Successful writes still return true; failed writes false; closed entry points issue no requests. Duplicate submit checks keep the single repository call; disposal does not retry or mutate state.

## F1 - CORS and real browser

Only `X-App-Locale` was added to explicit allowed headers. Origins, Super Admin handling, methods, credentials and auth/tenant rules retained. New approved/denied preflight and unauthenticated EN/AR Discount tests plus existing CORS/bootstrap tests: final exit 0, 6 tests / 34 assertions. Initial run exit 1: bootstrap inherited the acceptance Super Admin URL; a one-origin response contains the approved origin even for a denied caller. Final run clears Super Admin env only for that historical bootstrap test and tests the explicit two-origin configuration (no wildcard or loosened access).

Real Chromium browser: release Flutter Web on localhost:18000, API on localhost:18100. Real EN login POST /auth/login returned 200, real AR login returned 200. Authenticated GET /discounts and /discounts/metrics returned 200 for both locales. Captured request headers show `x-app-locale: en` / `ar`, referer localhost:18000; response `Access-Control-Allow-Origin: http://localhost:18000`, credentials true, Vary Origin. Screenshots: `discount_cross_origin_en_2026-10-03.png`, `discount_cross_origin_ar_2026-10-03.png`. Arabic preference set through the existing persisted Web locale preference, then real AR login exercised; no client header removal or same-origin proxy.

Denied-origin browser test from `http://127.0.0.1:18000`: unauthenticated GET /discounts with X-App-Locale rejects with TypeError. Chromium console explicitly reports preflight blocked because no Access-Control-Allow-Origin. An optional credential submission from the unapproved origin was rejected by automatic review and was NOT submitted or retried; the safe preflight-only browser check and backend tests establish denial.

## Command results so far (serial verification)

| Command | Result | Final exit |
|---|---|---|
| lifecycle test before fix | 10 reproduced disposal failures | 1 |
| lifecycle test after fix | 22 passed | 0 |
| CORS/bootstrap/cloud tests first run | 4 pass / 2 fixture-environment failures | 1 |
| CORS/bootstrap/cloud final, SUPER_ADMIN_WEB_URL empty for bootstrap, --do-not-cache-result | 6 passed / 34 assertions | 0 |
| flutter test --concurrency=1 test/features/discounts | 103 passed | 0 |
| flutter test --concurrency=1 test/features/pos/widgets/discount_dialog_test.dart | 2 passed | 0 |
| flutter test --concurrency=1 test/discounts_routing_test.dart | 2 passed | 0 |
| flutter test --concurrency=1 test/app/route_scoped_request_topology_test.dart | 4 passed | 0 |
| scoped flutter analyze (Discounts, topology, harness) | no issues, before final harness changes | 0 |
| flutter analyze | 29 existing Info in Sales and Printer test, untouched | 1 |
| scoped dart format | changed only owned files | 0 |
| scoped Pint first run | line endings, subsequently normalized | 1 |
| flutter build web (sandboxed) | stalled; interrupted, unverified | 1 |
| flutter build web (elevated), API_BASE_URL=http://localhost:18100/api/v1 | fresh release built | 0 |
| Windows test with unquoted define paths | argument parsing failure, no interaction | 1 |
| first real pointer Windows run | progressed to second variant page; offscreen cached last row failed hit-test | 1 |
| second real pointer Windows run | EN save through pointer succeeded; POS assertion assumed ineligible policies hidden, but contract retains isEligible=false | 1 |
| testing-only migrations | completed | 0 |
| testing-only base seed | completed | 0 |
| guarded fixture final run | published version 1, ready shift, manifest | 0 |

Fixture setup had intermediate nonzero runs (all exit 1) while correcting auth payload/token key, exact search filtering, product variants, category, draft/active menu setup, default draft list filtering, authoritative assignment scope, output encoding and one overlap with deliberate backend stop. They did not touch operational data. The final fixture script succeeds and uses the confirmed API contracts.

## F3 - Windows acceptance

Harness uses real native view metrics, center alignment when revealing nested-scroll targets, actual pointer taps on hit-testable controls/checkboxes/delete icons, and real text input. Hit-test warnings are fatal. No onPressed/onChanged/onSelected/onDeleted calls. Callback reads are only disabled-state assertions or option label inspection. No application design change or UI defect fix was made.

The initial failure concerned a cached offscreen CheckboxListTile: ensureVisible's default edge alignment did not expose its center. Center alignment and the actual Checkbox hit target progressed through search/page/failure/retry, mixed selections and EN save. The second failure was an incorrect harness contract assumption, not an eligibility defect: server supplies ineligible policy with reason. The corrected gate asserts isEligible=false AND attempts pointer application, requires backend rejection and unchanged zero discount, then adds Small and verifies eligibility/apply/payment/receipt.

Final compiled Windows run: exit 0, 1 integration test, 04:03, both EN/AR. Native view 1264 x 681 logical pixels, no synthetic larger test surface. Actual text input and pointer events exercised controls, including real scrolling for the lazily built cart Add Discount button. No application interaction defect was proven, so no UI source was changed.

Observed for EACH locale: Create with RTL/LTR direction and mirrored rail assertions; product selection; All/Selected toggles; selected Small plus All Cake and two selected Latte variants; product and variant search/page 2; actual isolated-backend stop causing failure, disabled page navigation, retry and resumed navigation; retained selections; pointer Activate and backend persistence; pointer sibling-policy attempt rejected (isEligible=false, zero discount); Small x2 added with Large x1; pointer policy apply; displayed POS and PaymentDialog totals; pointer cash confirmation; opened receipt; full API totals equality; reopened Edit; archived saved Latte target stays visible and blocks Activate; pointer remove unavailable chip; pointer Activate; non-target fields remain identical and Latte retains Size 30. No weakened financial assertions.

Runtime proof:
```
ACCEPTANCE[en] pointer POS order 3: 40 - 8 + 2.56 = 34.56; payment and receipt equal backend.
ACCEPTANCE[en] saved 28: Tea selected [10], Cake all, Latte selected [44,50].
ACCEPTANCE[en] edit preserved all non-target fields.
ACCEPTANCE[ar] pointer POS order 4: 40 - 8 + 2.56 = 34.56; payment and receipt equal backend.
ACCEPTANCE[ar] saved 29: Tea selected [10], Cake all, Latte selected [44,51].
ACCEPTANCE[ar] edit preserved all non-target fields.
04:03 +1: All tests passed!
```

Screenshots captured from the compiled native app RepaintBoundary and visually inspected: `windows_en_create.png`, `windows_en_create_targets.png`, `windows_en_edit_unavailable.png`, `windows_en_pos_totals.png`, `windows_en_receipt.png`; corresponding `windows_ar_*` files. Receipt screenshots visibly show subtotal 40, discount 8, tax 2.56, total 34.56. Form screenshots show approved design and RTL; unavailable chip and disabled save are visible.

Additional intermediate pointer run: exit 1, EN sibling rejection passed, but cart Add Discount was not built outside the lazy ListView viewport after adding Small. Harness now scrolls that actual cart Scrollable until the button is built/visible before tapping. This was a harness visibility correction; no application UI fix.

Reproduce from the repo root:
```
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml up -d
# Verify APP_ENV/testing + accept-postgres + cafe_discount_acceptance_testing before any setup.
# On a NEW isolated acceptance database only: artisan migrate --force, artisan db:seed --force.
python windows_application/integration_test/fixtures/create_discount_fixture.py
```
Then from `windows_application` (PowerShell), use absolute paths so Docker owns only the test project:
```
flutter test -d windows integration_test/discount_variant_acceptance_live_test.dart --dart-define=API_BASE_URL=http://localhost:18100/api/v1 "--dart-define=ACCEPTANCE_COMPOSE=C:/Users/Rami/Desktop/Important Files/CAFE SYSTEM/cafe_backend/windows_application/integration_test/fixtures/discount_acceptance.compose.yml" "--dart-define=ACCEPTANCE_SCREENSHOTS=C:/Users/Rami/Desktop/Important Files/CAFE SYSTEM/cafe_backend/docs/verification"
```
The harness rechecks actual database identity before login/mutations and restarts only accept-backend in teardown. Do not run fixture setup concurrently with this deliberate failure/retry test. Test records retained in the isolated backend for evidence; operational records untouched.


## Final verification and closure

All verification commands executed serially. Final scoped analysis: exit 0, no issues (61.2s). Full flutter analyze: exit 1, exactly 29 pre-existing Info in Sales repository/screens and printer receipt_renderer_test; no errors/warnings, unrelated files not changed. These are not claimed green.

| Final command | Result | Exit |
|---|---|---|
| flutter test -d windows integration_test/discount_variant_acceptance_live_test.dart (defines above) | EN/AR real pointer acceptance, 1 passed, 04:03 | 0 |
| flutter analyze lib/features/discounts test/features/discounts test/app/route_scoped_request_topology_test.dart integration_test/discount_variant_acceptance_live_test.dart | no issues | 0 |
| flutter analyze | 29 prior Info, no errors/warnings | 1 |
| dart format --output=none --set-exit-if-changed lib/features/discounts/controllers/discounts_cubit.dart test/features/discounts/controllers/discounts_cubit_test.dart integration_test/discount_variant_acceptance_live_test.dart | 3 files, 0 changed | 0 |
| docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T accept-backend vendor/bin/pint --test config/cors.php tests/Feature/DiscountCorsTest.php | 2 files PASS | 0 |
| git diff --check | no whitespace errors across the preserved dirty worktree | 0 |
| flutter build windows --dart-define=API_BASE_URL=http://localhost:18100/api/v1 | fresh Release, 124.0s | 0 |
| flutter build web --dart-define=API_BASE_URL=http://localhost:18100/api/v1 | fresh Release, 178.5s, used for real cross-origin browser | 0 |

New code file scope: backend/config/cors.php and backend/tests/Feature/DiscountCorsTest.php; DiscountsCubit lifecycle and its permanent tests; integration acceptance harness and guarded fixture files. Existing variant and pagination code preserved. Updated Plan 1, handoff, PROJECT_STATUS and historical/current acceptance evidence. No UI implementation changes, schema/pricing/eligibility redesign, Plan 2 work, commits or deployment. All migrations, seed and mutations were confined to the confirmed isolated testing database. No acceptance gate remains for the requested F1/F2/F3 scope.

A documentation edit attempt exited 1 due to Python default Windows encoding before writing any file; repeated with explicit UTF-8 exited 0. Earlier unsuccessful commands are retained above rather than described as passes.
