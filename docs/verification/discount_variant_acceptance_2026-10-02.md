# Plan 1 discount variant acceptance evidence — 2026-10-02

> Correction 2026-10-03: historical partial evidence only. F1/F2/F3 block closure. Windows callbacks are not pointer acceptance; cross-origin Web and Windows POS/payment/receipt remain unverified. D1-13/D1-14 reopened.

## Environment (isolated, explicitly identified)

- Compose project `cafe-discount-acceptance`: its own Postgres 16 container/volume, database `cafe_discount_acceptance_testing`, `APP_ENV=testing`, backend published on `localhost:18100` (the repo-owned dev stack `cafe_backend` and its database were not started or touched). DB host/name/env were printed from inside the container before migrating.
- `php artisan migrate --force` and `db:seed` ran only against that database. Test account: seeded `owner@cafe618.local`, authenticated through the real login screen/endpoint; no auth or permission bypass.
- Fixtures created through authenticated owner APIs: products 10 Acc Tea (variants Small/Large/XL), 11 Acc Cake (Slice/Whole), 12 Acc Latte (45 variants), 45 filler products; a published POS menu (version 1) with Tea and Cake; one open shift on Main Branch (tax 8%).
- Web was served same-origin through a local proxy (see finding F1) at `http://localhost:18000`; Windows used `API_BASE_URL=http://localhost:18100/api/v1`.

## Web (real Chromium via Playwright CLI, Flutter semantics enabled)

Release build with `--dart-define=API_BASE_URL=http://localhost:18000/api/v1`.

| Check | Result |
|---|---|
| Login with the isolated owner, Discounts list, Create | passed |
| Product picker: page 2 of 3 then, with the backend stopped, a new search | error + Retry shown; Previous/Next both `[disabled]`; no stale `n / m` counter ([screenshot](discount_web_en_product_search_failure_nav_disabled.png)) |
| Retry | repeated `page=1&search=Acc Tea` and recovered; search `Acc` then Next requested `page=2&search=Acc` (page 2 / 3) |
| Variant picker (Acc Latte, 45 variants): page 2 of 3, backend stopped, search `Size 3` | same disabled state ([screenshot](discount_web_en_variant_search_failure_nav_disabled.png)); retry repeated the query; `Size` + Next requested page 2 |
| Mixed targets | Tea selected(Small), Latte selected(2 variants incl. one chosen on page 2 and one from a later search), Cake all → saved payload `selected [10]`, `all`, `selected [35,44]` |
| Save, reopen, edit | extra fields (description, conditions, 7 weekdays, 08:00–23:00, min 5, max 100, usage 50/2/1, channel POS) set via API; after UI edit all unchanged |
| Unavailable saved variant (Latte Size 21 archived) | stays visible with message; Activate disabled; Save as Draft sent no request; removing the chip then saving worked ([screenshot](discount_web_en_edit_unavailable_saved_variant.png)) |
| Arabic/RTL | rail on the right, form mirrored, product row/chips/close icon mirrored, Arabic product name ([create form](discount_web_ar_rtl_create_form.png), [product row](discount_web_ar_rtl_product_variant_mode.png)); AR create fixed/per_unit 3 on Tea Small saved |
| POS UI → payment → receipt (AR) | cart Tea Small×2 (20), Tea Large×1 (20), Cake (15) = 55; applying the AR-created per_unit policy: discount −6 (Large excluded), tax 3.92, total 52.92; paid cash; receipt shows 55 / −6 / 3.92 / 52.92 ([receipt](discount_web_ar_pos_receipt_totals.png)); backend order and receipt API returned identical totals |

## Windows (compiled Windows app, `integration_test/discount_variant_acceptance_live_test.dart`)

`flutter test integration_test/discount_variant_acceptance_live_test.dart -d windows --dart-define=API_BASE_URL=http://localhost:18100/api/v1 --dart-define=ACCEPTANCE_COMPOSE=<compose file>` → `+1: All tests passed!`, exit 0 (final run policies 50/51 saved; latest saved selections `[10]`, `all`, `[44,50]` / `[44,51]`).

The test logs in through the real login screen, then for EN and AR: asserts directionality/mirrored geometry and no layout exception; creates a fixed/per_unit product policy; in the product picker reaches page 2, stops the isolated backend, performs a new search (asserts error, both navigation buttons disabled, no counter), restarts it, retries, navigates to page 2 of the recovered query; adds three products; Tea selected→Small, Cake all, Latte selected with a page-2 row plus a failed-then-retried search row; saves; reads the saved detail through the app repository; adds extra policy fields and archives one saved variant through the API; reopens Edit, asserts the unavailable target is visible and Activate disabled, removes it, saves, and asserts every non-target policy field is unchanged and the other selections are intact.

## Backend POS/payment API (isolated backend, published-menu snapshot path)

Order `publishedMenuVersionId=1`: Tea Small×2 (10) + Tea Large×1 (20), subtotal 40, tax 8%.

| Scenario | Backend result |
|---|---|
| Manual percentage 10% targeting Small | discount 2.00, total 41.04 |
| Manual fixed/per_order 5 targeting Small | 5.00 once, total 37.80 |
| Manual fixed/per_unit 3 targeting Small (qty 2) | 6.00, total 36.72 |
| Code (case-insensitive) 50% targeting Large | 10.00, total 32.40 |
| Policy selecting only XL (no such line) | 422 `DISCOUNT_ITEMS_NOT_ELIGIBLE`; previous Code discount unchanged |
| All variants 10% | 4.00, total 38.88 |
| Pay 36.72 (per_unit) | accepted; receipt subtotal 40 / discount 6 / tax 2.72 / total 36.72 equals order and payment |

Note: the legacy no-version order path does not pin variant identity (lines have `variantId: null`), so these checks use the published-menu path the real POS uses.

## Findings (not changed here)

- F1: The Web client cannot log in cross-origin to this backend: CORS `allowed_headers` (`backend/config/cors.php`) lacks `X-App-Locale`, which `DioApiClient` always sends, so the browser preflight fails. This acceptance used a same-origin proxy. Needs a backend CORS/deployment decision outside Plan 1.
- F2: `DiscountsCubit.loadDiscounts` can `emit` after close (error path) when its route is left while the list is loading; seen once as "Cannot emit new states after calling close". Pre-existing, out of this narrow fix.
- F3: In the Windows integration viewport, pointer taps on form controls inside the nested scrollables did not hit-test; the Windows test therefore invokes those controls' own callbacks (dropdowns, mode chips, selector buttons, Activate, chip delete, picker rows and the search field after focus loss). Dialog buttons and picker navigation use real pointer taps. The web run used real pointer/semantics interaction.
