# Plan 2 Flutter and integration verification — 2026-10-04

Scope: D2-10 through D2-18, including the Flutter part of D2-11. D2-19 is excluded. The corrected Backend contract remains authoritative. Pre-existing dirty Backend/Plan 1 work was preserved. No commits, deployment, dependency upgrades, operational migrations, pricing changes, lock-order changes, printer transport changes, or public flag changes were made.

## Implemented behavior

- Cafe Configuration Discount Settings uses the existing feature/Cubit/repository/router/DI architecture, all eight replacement fields and `expectedVersion`. Server version and `engineReady` are read-only. Saved state and local draft are separate; reset affects the draft, duplicate saves are blocked, conflict refresh preserves the draft and requires explicit review. Owner and the specifically granted Manager have narrow access; other configuration administration remains denied to Manager. Full replacement Manager grants keep settings and suppression permissions separate.
- Create/Edit hydrates priority and Automatic capability independently of activation. Integer priority is 0..1000. Conversion clears code explicitly. Existing conditions, Plan 1 selected/all variant targets, unavailable targets, pagination and omitted-field semantics remain intact. Public Automatic creation/conversion and activation stay unavailable.
- POS uses operational capabilities without settings administration, header 2, existing serial mutations, a retained immutable create identity, authoritative order lifecycle and totals, complete saved discount lists and normalized explicit intent. Confirmed discount operations use durable identities; uncertain responses recover through operation GET plus saved state. Review and suppression are explicit actions, including reason and authorized undo.
- Payment uses the Backend payment-method ID and canonical method, fresh quote, exact decimal strings and received tender. Stale/required quote errors require a new explicit confirmation. Unknown payment outcomes retain their identity and use authoritative payment records. Printing is independent of settlement.
- POS, quote, payment summary, order details, pre-bill and receipts render all persisted discount rows and aggregate totals, with compatible legacy fallback and no fabricated historical allocations. Recognized errors have safe EN/AR mappings; unknown text is never shown.
- Permanent tests cover settings drafts/conflicts/permissions/routes/revocation, capability/priority round trips, variant targeting, exact DTOs, serialized mutation and recovery, review/suppression/intent, stale/tender/zero payment, disposal, and pointer/text widget interactions at constrained EN/AR sizes.

## Completed regression commands

Flutter commands were serial on the shared SDK. Database-mutating Backend suites were serial on explicitly confirmed isolated databases. The user subsequently instructed that completed full suites and HEAD comparison must not be repeated.

| Command / log | Final result | Exit |
|---|---|---:|
| Required `flutter gen-l10n` | Completed; EN/AR generated files regenerated | 0 |
| Scoped `dart format` | Explicit touched paths only | 0 |
| Focused Flutter group, `output/discount-plan2-focused-verified.txt` | 430 passed | 0 |
| Operation recovery UI regression, `output/discount-plan2-operation-ui-fix.txt` | 26 passed | 0 |
| Payment/protocol focused regression, `output/discount-plan2-payment-focused.txt` | 27 passed | 0 |
| Final protocol probe, `output/discount-plan2-probe-after.txt` | 2 passed; valid asynchronous read and missing-header rejection | 0 |
| Final receipt/protocol group, `output/discount-plan2-receipt-final.txt` | 14 passed | 0 |
| Zero-balance receipt before correction, `output/discount-plan2-zero-receipt-before.txt` | 2 EN/AR regressions fail on the observed cash label | 1 |
| Receipt/protocol/tax group, `output/discount-plan2-zero-receipt-focused.txt` | 18 passed / 1 existing tax-label failure, already recorded in the completed HEAD comparison; historical source unchanged | 1 |
| Final receipt/protocol regression, `output/discount-plan2-zero-receipt-final.txt` | 16 passed | 0 |
| Final zero-receipt scoped analysis, `output/discount-plan2-zero-receipt-analysis.txt` | 6 paths, no issues | 0 |
| Final hardening focused group, `output/discount-plan2-final-hardening.txt` | 91 passed | 0 |
| First full `flutter test --no-pub --concurrency=1`, `output/discount-plan2-full-flutter.txt` | 1674 passed / 23 failed; one added test failed in a run started before the final Orders change; its final source subsequently passed in the 91-test group | 1 |
| Unmodified HEAD export, exact 15 historical failing classes, `output/discount-plan2-flutter-head-baseline-verified.txt` | 67 passed / same 22 historical failures | 1 |
| Full `flutter analyze --no-pub`, `output/discount-plan2-full-analysis.txt` | Existing info-level findings only; no errors/warnings in this run | 1 |
| Initial Windows release build, `output/discount-plan2-windows-build.txt` | Built release executable | 0 |
| Initial Web release build, `output/discount-plan2-web-build.txt` | Built release Web | 0 |
| Web release rebuild, `output/discount-plan2-web-build-final.txt` | Built release Web, 130.8 s | 0 |
| Windows release rebuild, `output/discount-plan2-windows-build-final.txt` | Built release executable, 164.1 s | 0 |
| Final settlement Web release, `output/discount-plan2-web-build-settlement.txt` | Built release Web, 95.0 s; optional Wasm dry run succeeds | 0 |
| Final settlement Windows release, `output/discount-plan2-windows-build-settlement.txt` | Built release executable, 80.8 s | 0 |
| Final scoped analysis, `output/discount-plan2-analysis-final.txt` | 18 scoped Settings/protocol/payment/receipt/acceptance paths; no issues | 0 |
| Compiled native full EN/AR acceptance, `output/discount-plan2-windows-final-acceptance.txt` | 1 passed, 04:15 | 0 |
| Final native payment-only acceptance, `output/discount-plan2-windows-payment-final.txt` | 1 passed, 00:35, final source and order 19 | 0 |
| Corrected Backend focused regressions, JUnit `backend/storage/app/discount-flutter-focused-2026-10-04.xml` | 143 passed / 2095 assertions | 0 |
| Full Backend suite, `output/discount-plan2-backend-full.txt` and JUnit `discount-flutter-full-2026-10-04.xml` | 1097 passed / 44 failed / 1 skipped / 11567 assertions | 2 |
| Final `git diff --check` | Completed after documentation updates; no whitespace error (existing LF/CRLF notices only) | 0 |

The full Backend failing `(class, method)` set exactly matches the previously recorded HEAD baseline (`discount-engine-head-result.xml`): no added or missing failures. The 22 historical Flutter failures were independently reproduced on an unmodified HEAD export; assertions and unrelated source were not changed. One added test failed in a run begun before the final source changes; the final focused group passes it. Do not read the full-suite exits as success. No final-source full-suite rerun is claimed or required after the user's instruction not to repeat it.

Backend command environment: `APP_ENV=testing`, `APP_LOCALE=ar`, `DB_DATABASE=cafe_system_618_testing`, `DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations`, empty `DB_URL` and `SUPER_ADMIN_WEB_URL`; executed in existing `accept-backend` through `php artisan test --do-not-cache-result`. Focused filter included Discount Engine/Corrections/Concurrency/Settings/Foundation/Variant/Management/V1/V2/Security/Eligibility/CORS, POS smoke/snapshot, money idempotency, receipt configuration, order lifecycle and real sale suites. A subsequently demonstrated Web ad-hoc serialization defect required the narrow fingerprint correction documented below.

## Live acceptance and evidence

Both surfaces use the existing `cafe-discount-acceptance-20261003` Docker project and its existing volumes. Default API database: `cafe_discount_acceptance_testing`; host: `accept-postgres`; application environment: `testing`. The three already-reviewed additive Discount foundation/protocol migrations were applied only to this confirmed isolated acceptance database after status/identity checks. Existing normal/migration regression databases remain isolated. No operational data was touched.

Web release acceptance uses actual Playwright pointer interaction and text entry, real cross-origin bearer login (`localhost:18000` → `localhost:18100`), no business callback or proxy. Flutter semantics activation is accessibility infrastructure only. Native acceptance uses the compiled Windows integration runner, actual tester pointer/text interaction with fatal hit-test misses, real authenticated PostgreSQL services and Backend DTOs. Fault injection drops selected responses only after real server completion.

| Observed scenario | Evidence / result |
|---|---|
| Web Owner Settings save | `discount-plan2-web-ar-settings.png`; persisted cap 25 |
| Web authorized Manager Settings | `discount-plan2-web-ar-manager-settings.png`; direct Profile/Tax/Branches/Team denied |
| Web grant revocation / retry | `discount-plan2-web-ar-manager-revoked.png`; server 403 clears authority; original full grants restored |
| Web unsupported Employee direct route | `discount-plan2-web-ar-unsupported-role.png`; real dedicated fixture login, redirected to dashboard |
| Web draft reset / strategy at 500 px | `discount-plan2-web-ar-500-strategy.png`, `discount-plan2-web-ar-500-draft-reset.png`; reset draft only, Save disabled on defaults |
| Public Automatic creation gate | `discount-plan2-web-ar-public-policy-gate.png`; unavailable localized explanation and no selectable Automatic option |
| Web Manual selected-variant create/edit/reopen | `discount-plan2-public-policy.json`, `discount-plan2-web-ar-manual-reopen.png`; policy 32, Small variant only, priority edited 321 → 322 through real fields and Save |
| Web selected tender / payment / receipt | `discount-plan2-web-ar-public-quote.png`, `discount-plan2-web-ar-public-receipt.png`; cash ID selected, received `100.00`, Backend total `10.80`; receipt displays 10 + 0.80 = 10.80 |
| Windows Settings save/reset/reopen/conflict | `discount-plan2-windows/windows_en_settings.png`, `windows_en_settings_conflict.png`; real fields, 409 and explicit draft review |
| Windows variant create/detail/search/retry/unavailable correction | `windows_en_create.png`, `windows_en_create_targets.png`, `windows_ar_edit_unavailable.png`; final EN/AR run passed |
| Windows uncertain create recovery / explicit operation | `windows_en_lost_create.png`, `windows_en_explicit_review.png`, `windows_en_pos_totals.png`; same create identity replay; lost operation recovered by GET; 40 − 8 + 2.56 = 34.56 equals Backend |

Earlier failed/overlapping browser navigation and shared-service stops generated console errors. They are not reported as zero-error acceptance. Windows and Web acceptance must run sequentially because the existing retry scenario stops the shared Backend. No physical printing acceptance is claimed.

Final sequential Windows run: `flutter test integration_test/discount_plan2_acceptance_live_test.dart -d windows --no-pub` with API base URL `http://localhost:18100/api/v1`, the existing compose path, and screenshot directory defines. **1 native integration test passed, final exit 0, 04:15** (`output/discount-plan2-windows-final-acceptance.txt`). This is a compiled Windows Debug integration executable; release build verification is a separate command. EN order **14** and AR order **15** both prove subtotal **40**, discount **8**, tax **2.56**, total **34.56**, equal across POS, saved state, quote, payment and actual Backend receipt. Lost create replay retains the same immutable request; lost operation uses GET recovery. The selected cash method comes from operational `paymentMethods`. A settings-version change rejects the old quote, leaves the order unpaid, fetches a fresh quote and requires another pointer confirmation. Exactly two payment requests (one rejected stale quote plus one settlement) use the same idempotency key and received amount string `100.00`; the committed payment response is deliberately lost and recovered by GET order payments, without another pay request.

Final native screenshots are in `discount-plan2-windows/`: `windows_en_quote.png`, `windows_ar_quote.png`, `windows_en_stale_quote.png`, `windows_ar_stale_quote.png`, `windows_en_receipt.png`, `windows_ar_receipt.png`, plus Settings/review/cart/create/detail captures. Arabic receipt and English stale-quote screenshots were visually inspected. Strict pointer hit testing and `tester.takeException()` checks passed in the complete EN/AR run. Source inspection corrected the new raster renderer's Arabic source labels; transport and physical output were not changed or accepted.

After the final Web order-18 interaction had finished and the browser moved to `about:blank`, the final-source native **payment-only** mode was run sequentially: the same command with `ACCEPTANCE_PAYMENT_ONLY=true` and screenshots in `discount-plan2-windows-payment-final/`. **1 passed, exit 0, 00:35** (`output/discount-plan2-windows-payment-final.txt`). This is a focused acceptance rerun, not a repeated Flutter full suite or complete Settings/variant acceptance run. Order **19** again proves **40 − 8 + 2.56 = 34.56**, valid operational payment-method parsing, lost-create/operation recovery, explicit stale quote confirmation, committed-but-lost payment recovery and receipt equality. The new receipt model preserves the canonical method. `windows_en_receipt.png` was visually inspected; screenshot and authoritative final-gate JSON agree. No D2_GENERIC failure remains in this observed native payment path.

## Windows payment failure investigation

Initial failures: `operational payment methods did not load`, `code=D2_GENERIC`, no quote methods, unresolved totals. Completed diagnostic runs exited 1; see `discount-plan2-windows-payment-diagnostic.txt`, `discount-plan2-windows-payment-only.txt`, `discount-plan2-windows-payment-trace.txt`.

Actual isolated saved state for Windows order 11: normalized `configured_manual` intent with policy 34, saved amount `8.00`, allocations `4.00 + 4.00`, aggregate subtotal `40.00`, tax `2.56`, total `34.56`. The direct payment summary returns `canPay=true`, no blocker and real cash method ID 1.

The instrumented native trace proves successful capabilities HTTP 200 and typed parsing (`review=true`, `quote=true`). The first saved-state read succeeds. The dialog's second saved-state read raises a transport `ApiException` with null status/code and unknown type before `payment-summary` is requested. Safe diagnostics capture request path/status, cause type, parsed availability and Cubit authority only, without raw exception contents or coupons. Product code must change only after the underlying cause is demonstrated.

The underlying cause was the harness's Flutter `expect` inside Dio `onRequest`, not Backend pricing or a payment-method DTO. Flutter SDK `widget_tester.dart:472` invokes `TestAsyncUtils.guardSync`; it throws across the active awaited widget zone. Dio wraps this `FlutterError` as an unknown transport exception before sending `discount-state`. The callback-safe SDK `expectSync` retains the exact same `X-Discount-Contract == '2'` matcher. A deterministic asynchronous valid saved-state read reproduces the failure before the fix (exit 1, `discount-plan2-probe-before-verified.txt`), then passes after it. Existing lifecycle/quote/recovery widget tests plus the new regression: 27 passed, exit 0 (`discount-plan2-payment-focused.txt`). A missing-header negative regression also keeps the assertion meaningful. No payment application code or Backend source change was needed for this failure.

The diagnostic failures remain retained as failed runs; only the final completed Windows acceptance is a pass. The payment-method response and DTO were valid, and no invented endpoint or pricing override was needed.

## Demonstrated Backend integration correction

Real Web ad-hoc preview (`fixed`, `2.50`) repeatedly returned `DISCOUNT_REVIEW_STALE` on immediate confirmation, even after fresh explicit review. `discount_reviews.payload` is JSONB, which reorders the four intent object keys; the fingerprint previously hashed their PHP insertion order. `DiscountResolutionService::fingerprint` now sorts only the normalized intent keys before hashing. Values and every existing context component stay bound. No calculations, compatibility rules, allocations, lock ordering or flags were changed. Completed operation/payment replay remains authoritative; outstanding old reviews/quotes can require a fresh explicit review.

Permanent PostgreSQL `DiscountEngineIntentRoundTripTest` exercises fixed and percentage ad-hoc preview → persisted JSONB → confirmed operation → replay → quote → settlement, plus tampered real intent values rejected with no operation or discount mutation. Before correction: **1 failed / 5 assertions, exit 1** (`discount-plan2-intent-before.txt`). With the correction, the existing Engine/Corrections/Concurrency group had **39 passed**, while the new test's stale HTTP assertion incorrectly expected 409 (the contract specifies 422): **39 passed / 1 failed / 753 assertions, exit 1** (`discount-plan2-intent-regressions.txt`). Only that expected status was corrected to the authoritative 422, retaining the exact error-code and no-write assertions. Final new regression: **1 passed / 38 assertions, exit 0** (`discount-plan2-intent-final.txt`). Scoped Pint passes **2 files, exit 0**; both PHP syntax checks exit 0.

The isolated service's PHP settings are `opcache.enable_cli=1`, `opcache.validate_timestamps=0`; mounted source does not reload in its running server automatically. It was restarted only after the database suite finished, using the same project and volumes. This explains the initially unchanged browser result after the source edit; it is not a reason to bypass review or pricing authority.

## Final Web quote, payment and receipt observations

After Windows acceptance had completed, real Arabic Web release pointer/text interactions produced order **16**. Ad-hoc fixed `2.50` was previewed, explicitly confirmed and persisted after the JSONB correction. Saved state, POS, payment quote and actual Backend receipt agree: **10.00 − 2.50 + 0.60 = 8.10**. The applied row and allocation remain exact decimal strings; explicit ad-hoc intent remains saved.

The user selected operational cash **ID 1**, entered received tender **`100.00`**, and confirmed the quote. A guarded external settings-version change made that quote stale. The first pay was rejected with `ORDER_TOTAL_CHANGED`; the dialog fetched a fresh quote and required another actual pointer confirmation. Exactly two observed payment requests used the **same** durable identity and `100.00`, with different quote IDs; no automatic retry occurred. `discount-plan2-web-final-payment.json` contains the authoritative saved state/receipt. Screenshots: `discount-plan2-web-ar-ad-hoc-review.png`, `discount-plan2-web-ar-ad-hoc-quote.png`, `discount-plan2-web-ar-stale-quote.png`, `discount-plan2-web-ar-ad-hoc-receipt.png`. The last two were visually inspected.

The scoped observer recorded three pre-correction ad-hoc HTTP 422 responses and the intentional stale-payment HTTP 422, with **zero runtime/layout errors**. The older browser console had 23 errors from earlier scenarios; no claim of zero global console errors is made. Locator timeouts while activating semantics, using an incorrect accessible label, or loading a deep path on the basic static server are automation/hosting gaps, not acceptance passes. No business/widget callback was invoked for Web interactions.

Order **17** proved null-tender zero balance through the real UI: fixed `10.00`, tax `0.00`, payable `0.00`, one request with received string `0.00`, quote identity and payment identity, **no method or paymentMethodId fields**. Authoritative `GET orders/17` returns exactly one matching completed `zero_balance` payment and receipt total zero. The temporary cap-100 fixture was written only after database/gate identity checks; all eight original settings were restored (version 27, cap null, auto off). `discount-plan2-web-zero-payment.json` records these observations. A diagnostic utility mistakenly requested a nonexistent nested payments path and exited 1; recovery verification was corrected to the documented existing order-detail `payments[]` read, exit 0. No endpoint was added or used by the application.

This scenario exposed a precise receipt-display defect: the authoritative receipt returned `payment.method="zero_balance"`, but the legacy typed method mapper fell back to cash, so the preview showed Cash. `OrderReceipt` now preserves its optional canonical `settlementMethod`; the preview uses the existing localized zero-balance text for that recognized method. Other tender labels and legacy fallback stay intact. No financial calculation, settlement, transport, raster/printer platform or localization dependency changed. The EN/AR regression fails before this correction (2 failures, exit 1), then the final receipt/protocol group passes 16 tests, exit 0. The separate tax-label failure is one of the already documented 22 historical failures and was left untouched.

Final corrected Web release (95.0 s build, exit 0) was reloaded and accepted through real pointer/text input. Order **18** again settles `10.00 − 10.00 + 0.00 = 0.00`, with exactly **one** HTTP 200 pay request, received `0.00`, quote/idempotency identities and no tender fields. The actual preview now shows **رصيد صفري دون وسيلة دفع**, matching Backend `zero_balance`. Scoped runtime/layout diagnostics are empty. `discount-plan2-web-zero-payment-after.json`, `discount-plan2-web-ar-zero-quote-after.png` and `discount-plan2-web-ar-zero-receipt-after.png` are the final evidence; the receipt screenshot was visually inspected. The earlier order-17 screenshot remains before-correction evidence. Both zero orders have one matching completed order-detail payment, without repeated settlement. Final Windows release also compiles (80.8 s, exit 0); its subsequent focused native payment result is recorded separately.

## File inventory

This inventory names files edited or added in the Flutter/integration phase. Shared files also contain preserved earlier changes; the complete dirty Git diff is not attributed to this phase. No reviewed Backend file was reset or rewritten.

| Area | Files, relative to `windows_application/` unless indicated |
|---|---|
| App/network/DI | `lib/app/app_router.dart`, `lib/core/network/dio_api_client.dart`, `lib/core/services/service_locator.dart` |
| Settings models/repositories | `lib/features/cafe_configuration/models/discount_settings.dart`, `repositories/discount_settings_repository.dart` in the same feature |
| Settings/permissions Cubits | `lib/features/cafe_configuration/controllers/discount_settings_cubit.dart`, `discount_permissions_cubit.dart` |
| Settings/grants UI | `lib/features/cafe_configuration/views/discount_settings_screen.dart`, `views/team_tax_screens.dart`, `widgets/discount_manager_permissions.dart`, `widgets/discount_settings_summary.dart`, `widgets/cafe_configuration_navigation.dart` |
| Policy Cubit/models | `lib/features/discounts/controllers/discounts_cubit.dart`, `discounts_state.dart`, `models/discount_detail.dart`, `models/discount_form_references.dart`, `models/discount_upsert_request.dart` |
| Policy transport/form | `lib/features/discounts/repositories/discounts_repository.dart`, `views/create_discount_policy_screen.dart`, `widgets/discount_localization.dart`, `widgets/discount_pos_preview_card.dart` |
| POS controllers/transport | `lib/features/pos/controllers/pos_cubit.dart`, `pos_state.dart`, `repositories/pos_repository.dart` |
| POS typed DTOs | `lib/features/pos/models/discount_engine.dart`, `discount_workspace.dart`, `backend_order.dart`, `order_receipt.dart`, `order_receipt_mapper.dart`, `payment_summary.dart` |
| POS/review/payment UI | `lib/features/pos/views/pos_screen.dart`, `widgets/pos_cart_panel.dart`, `widgets/discount_engine_widgets.dart`, `widgets/quoted_payment_dialog.dart`, `widgets/receipt_preview_paper.dart` |
| Order/history | `lib/features/orders/controllers/orders_cubit.dart`, `models/order_detail.dart`, `repositories/orders_repository.dart`, `views/orders_screen.dart`, `widgets/order_detail_totals_section.dart` |
| Receipt raster data/rendering | `lib/features/printer/models/receipt_data.dart`, `services/receipt_renderer.dart`; no transport edits |
| Localization | `lib/l10n/app_en.arb`, `app_ar.arb`, generated `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ar.dart` |
| Settings/routing tests | `test/features/cafe_configuration/discount_settings_test.dart`, `test/app/discount_settings_routing_test.dart`, `test/app/route_scoped_request_topology_test.dart` |
| Policy/Plan 1 regression tests | `test/features/discounts/controllers/discounts_cubit_test.dart`, `models/discount_detail_test.dart`, `models/discount_upsert_request_test.dart`, `views/create_discount_policy_screen_test.dart`, `views/discounts_list_screen_test.dart`; preserved variant-target/pagination suites run in focused groups |
| Engine DTO/lifecycle tests | `test/features/pos/models/discount_engine_test.dart`, `controllers/discount_engine_lifecycle_test.dart`, `discount_engine_fixture.dart` |
| Payment/review/receipt tests | `test/features/pos/widgets/discount_engine_widgets_test.dart`, `zero_balance_receipt_test.dart`, `test/features/orders/widgets/quoted_order_payment_test.dart`, `test/app/discount_acceptance_protocol_probe_test.dart` |
| Native acceptance/probe | `integration_test/discount_plan2_acceptance_live_test.dart`, `integration_test/fixtures/discount_contract_probe.dart` |
| Isolated fixture tools | `integration_test/fixtures/discount_plan2_fixture.py`, `discount_plan2_automatic_fixture.php`, `discount_plan2_automatic.compose.yml`, `discount_plan2_catalog_fixture.py`; the Automatic override/catalog tools are prepared but unexecuted/unverified, not acceptance evidence |
| Necessary Backend exception | Repository-root `backend/app/Services/DiscountResolutionService.php` (normalized intent key canonicalization only), `backend/tests/Feature/DiscountEngineIntentRoundTripTest.php` |
| Documentation/evidence | `PROJECT_STATUS.md`; repository-root Plan 2, `docs/discount_settings_backend_contract.md`, `docs/discount_variant_flutter_handoff.md`, this report; `docs/verification/discount-plan2-*` JSON/screenshots and `output/discount-plan2-*` logs |

The Windows payment failure correction changes only the acceptance harness/probe and its new regression. Subsequent real payment/receipt acceptance demonstrated two separate narrow defects: JSONB intent fingerprint ordering and the zero-balance receipt label. These are documented independently and do not alter rollout authority.

## Remaining acceptance / activation gate

Windows operational methods, configured-Manual review, cash quote, explicit stale confirmation, uncertain create/operation/payment recovery, totals and receipt **EN/AR are passed**, not remaining blockers. Web Arabic ad-hoc review/cash stale confirmation/settlement and null-tender zero settlement are passed as described above. These do not complete every Plan 2 live gate.

| Required evidence still open | Precise gap |
|---|---|
| Isolated Automatic creation/conversion and engineReady distinction | Permanent capability tests exist; the prepared testing-only discovery override/catalog fixture was not applied or executed in this narrowed payment follow-up. No live Automatic policy was created in this phase. |
| Automatic discovery, disjoint combination, global cap, suppression/undo | Backend and Flutter focused coverage exist; authenticated pointer acceptance on both surfaces remains unperformed. |
| New-phase variant-targeted Code create/edit | Manual create/edit is observed; Code form was not saved/reopened in this phase. Prior Plan 1 evidence is separate. |
| Live hold/resume, customer removal and branch change | Implemented and permanent lifecycle tests exist; these new-phase pointer scenarios remain unobserved. |
| Two distinct supported tender IDs | Real null-to-cash selection and selected ID 1 passed; cash-to-card switching remains unobserved in this fixture. |
| Final Web English quote/payment/receipt | Arabic is observed; the POS accessibility tree does not expose the shell language control in the current browser session. No callback or locale-storage bypass is claimed as interaction acceptance. |
| Native Manager/unsupported-role Settings interactions | Owner Settings is observed on Windows; Owner/Manager/Employee access and revocation are observed on Web. The corresponding native Manager/Employee pointer sessions remain unobserved. |
| Windows standalone Release UI / zero-balance UI | Release compilation is verified separately from the compiled Debug integration runner. Standalone Release interaction and native zero-balance pointer acceptance remain unobserved. |
| History/pre-bill live reopening and physical print | Models/renderers/regressions retain saved/legacy data; new-phase live history/pre-bill reopening and physical printer output remain unobserved. |

D2-19 stays unchecked; `engineReady=false`, public creation false, Automatic enabled false, foundation CHECK unchanged. A later rollout review needs these open gates explicitly assessed and separately authorized. This phase does not activate or deploy, and Plan 2 is not marked complete.

## Final authority and service restoration

Read-only final verification (exit **0**) confirms the actual default isolated database/host/environment, public capabilities `{contractVersion:2,engineReady:false,automaticPolicyCreationAvailable:false,automaticEnabled:false,supportsDiscountReview:true,supportsPaymentQuote:true}`, settings version **28** with defaults/cap null, and the original five full Manager grants restored. `discount_settings_values_check` still contains **`NOT automatic_enabled`** and all its original enum/range/combination checks. An earlier read-only utility expected the formatted CHECK to contain literal `false` and exited 1; inspecting PostgreSQL's actual definition resolved this assertion wording, without any schema/contract change. `discount-plan2-final-gates.json` also confirms one paid order-19 payment and receipt `34.56`.

`docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml stop accept-backend accept-postgres` exits **0**. Final read-only service/volume verification exits **0**: original backend container `f7aae98d777a` is stopped (container exit 137), original PostgreSQL `ac1aae592bb1` is stopped (exit 0), matching the initial stopped state. Existing `accept-data`, `accept-storage`, `accept-cache` and external `cafe_backend_backend_vendor` volumes remain. No `down`, volume removal, new project or Automatic override was used. Artifact: `discount-plan2-service-restoration.json`.

Interrupting the temporary Python Web server session returned exit **1** but left its child listening. The first cleanup check also exited 1; PowerShell `Stop-Process` failed with a host `NullReferenceException` (exit 1). The full command line was verified as task-owned PID **19200**, serving exactly this workspace's `windows_application/build/web` on localhost **18000**. Native `taskkill /PID 19200 /F` exited **0**, and the final port/process check exited **0**: no Web listener or native acceptance executable remains. No user IDE process was stopped. These cleanup failures are retained as failures, followed by verified restoration.

Task closure is limited to D2-10/D2-12 implementation with recorded evidence, D2-17 completed verification execution (including explicitly nonzero historical baselines), and D2-18 documentation/evidence. D2-11 and D2-13–D2-16 are implemented but remain unchecked for their listed live acceptance gaps. D2-19 remains open. No whole-Plan-2 completion or rollout readiness approval is claimed.

Automatic approval review earlier rejected reading an existing stored password hash and checking a guessed password; that action was not executed or bypassed. Dedicated isolated fixture accounts using explicit `Hash::make` allowed unsupported-role acceptance instead. There is no pending approval request or credential-probing blocker.
