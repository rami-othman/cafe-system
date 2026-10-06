# Discount variant Flutter handoff — Plan 1

Date: 2026-10-01 (Asia/Damascus).

F1/F2/F3 runtime acceptance passed on 2026-10-03; D1-13/D1-14 closed on actual compiled Windows pointer/text and cross-origin Web evidence. The 2026-10-02 callback/same-origin results below remain historical and limited. Plan 2 has not started. Final checks and closure are recorded in the current acceptance report.

## 2026-10-02 pagination correction

`DiscountTargetPageState` now records `pageQuery`, the query that produced the
last successful page. A search change clears the retained page (items,
`currentPage`, `lastPage`); loading and error states disable Previous/Next and
hide the `n / m` counter; Retry repeats the failed query and requested page.
Saved selections, unavailable metadata and selections outside fetched pages are
untouched, as are stale-response protection and explicit all/selected
semantics. Files: `discount_targets_cubit.dart`,
`discount_product_targets.dart`. Permanent tests:
`test/features/discounts/discount_picker_pagination_test.dart` (7: product and
variant pickers, EN/AR, failed new search, retry, navigation after recovery,
failed page navigation and loading lock); all fail against the previous code.

## Implemented behavior

- Full detail hydrates edit, including variant metadata and all previous policy
  fields. Legacy product targets default visibly to All variants. Legacy
  `startsAt`/`endsAt` are also preserved; `HH:mm:ss` writes normalize to `HH:mm`.
- Product writes include one selection per parent, with only `productId`,
  `variantMode`, `variantIds`. Other scopes omit the entire field. Empty selected
  mode, duplicate identities, mismatched parents and unavailable saved targets
  cannot be explicitly saved. All mode clears IDs explicitly.
- Products and variants use the documented Discount reference endpoints with
  `getEnvelope`, server search, pages and retained `meta`. Blank searches are
  omitted. Product and variant selectors can navigate beyond 100 records.
- The form-owned `DiscountTargetsCubit` receives the existing injected Discount
  repository through `DiscountsCubit.createTargetsController()`. Its immutable
  state holds selections separately from pages. Metadata accumulates only for
  fetched pages; selected identities survive searches/page changes. Per-parent
  request generations and a form epoch reject stale responses after newer
  queries/pages, picker dismissal, removal or scope changes. The form disposes
  this controller on exit.
- Variants load on demand. Each product has its own page/search/cache. Removing
  a product removes dependent selections and invalidates its outstanding request.
  Retry repeats the failed requested page/query.
- Unrelated reference failures are collected per section and displayed with safe
  retry/forbidden messages. Successful categories/groups/customers/payment
  methods remain available, and the new product selector loads independently.
  Saved field identities are not cleared by reference failures.
- Saved unavailable products/variants use detail metadata and check both
  `isActive` and `archivedAt`. The form preserves them until deliberate correction
  or removal. It never silently changes Selected variants to All variants.
- EN/AR controls, summary targeting and an explicitly illustrative preview retain
  the existing form design. No eligibility, payable amount or tax authority moved
  into Flutter. Manual/Code, fixed/percentage, per_order/per_unit and the existing
  single-discount replacement remain unchanged.
- Controller and UI prevent concurrent submissions. Known parent/variant error
  keys receive localized labels; unknown server text and exceptions are not shown.

## Observed verification

Flutter commands ran serially from `windows_application`.

| Final check | Result | Exit |
|---|---|---|
| `flutter test --concurrency=1 test/features/discounts` | 83 passed (76 + 7 new) | 0 |
| `flutter test --concurrency=1 test/features/pos/widgets/discount_dialog_test.dart` | 2 passed | 0 |
| `flutter test --concurrency=1 test/discounts_routing_test.dart` | 2 passed | 0 |
| `flutter test --concurrency=1 test/app/route_scoped_request_topology_test.dart` | 4 passed | 0 |
| Scoped `flutter analyze` (lib/test Discounts, topology test, acceptance test) | No issues | 0 |
| `flutter analyze` | 29 existing Info findings in Sales and a Printer test; no errors/warnings, none in Discounts | 1 |
| Scoped `dart format --set-exit-if-changed` | 0 changed | 0 |
| `git diff --check` | Passed | 0 |
| `flutter build web` / `flutter build windows` (release, after the fix) | built | 0 / 0 |
| `flutter test integration_test/discount_variant_acceptance_live_test.dart -d windows` (isolated backend) | 1 passed | 0 |

The 2026-10-01 coverage (exact serialization/omission, detail-to-form-to-save
equality, mixed modes, unavailable preservation/removal, paging beyond 100,
stale responses, scoped failures/retry, duplicate submissions, EN/AR constrained
layouts) is unchanged and still passing.

## Platform and API acceptance (2026-10-02)

Run against an isolated testing backend (own Postgres/database/volume,
`APP_ENV=testing`, seeded `owner@cafe618.local` through the real login; no
operational data, no auth bypass). Full evidence, screenshots and exact steps:
[acceptance report](verification/discount_variant_acceptance_2026-10-02.md).

- Web (real browser): EN/AR + RTL; product and variant search/pagination;
  failure (backend stopped), disabled navigation, retry, navigation; mixed
  all/selected; save/reopen/edit with every extra policy field preserved;
  archived saved variant stays visible and blocks Activate/Draft until removed;
  POS, payment and receipt totals 55 - 6 + 3.92 = 52.92 equal the backend.
- Windows (compiled app, `integration_test`): the same Create/Edit flows in EN
  and AR including RTL geometry, failure/retry/navigation, mixed targets, saved
  detail via the app repository, unavailable correction and field preservation.
- Backend API: Manual/Code exclude sibling variants; percentage, fixed/per_order
  and fixed/per_unit amounts and tax-after-discount totals match; payment and
  receipt equal the order.

Limits: on Windows the form controls are invoked through their own widget
callbacks (pointer taps on them did not hit-test in the integration viewport);
Windows POS/payment/receipt screens and a Windows RTL screenshot were not
exercised (POS totals were verified in the Web UI and the API). The Web client
cannot log in cross-origin because backend CORS does not allow `X-App-Locale`
(F1); acceptance used a same-origin proxy.

## Changed file inventory

All Flutter paths below are relative to `windows_application/`.

- `lib/features/discounts/models/discount_detail.dart`
- `lib/features/discounts/models/discount_upsert_request.dart`
- `lib/features/discounts/models/discount_form_references.dart`
- `lib/features/discounts/models/discount_product_selection.dart` (new)
- `lib/features/discounts/repositories/discounts_repository.dart`
- `lib/features/discounts/controllers/discounts_cubit.dart`
- `lib/features/discounts/controllers/discount_targets_cubit.dart` (new controller/state)
- `lib/features/discounts/views/create_discount_policy_screen.dart`
- `lib/features/discounts/widgets/discount_product_targets.dart` (new)
- `lib/features/discounts/widgets/discount_pos_preview_card.dart`
- `lib/l10n/app_en.arb`, `app_ar.arb`, and generated `app_localizations.dart`,
  `app_localizations_en.dart`, `app_localizations_ar.dart`
- `test/features/discounts/discount_variant_targets_test.dart` (new)
- `test/features/discounts/discount_variant_repository_test.dart` (new)
- `test/features/discounts/discount_picker_pagination_test.dart` (new, 2026-10-02)
- `integration_test/discount_variant_acceptance_live_test.dart` (new, 2026-10-02)
- `test/features/discounts/models/discount_detail_test.dart`
- `test/features/discounts/controllers/discounts_cubit_test.dart`
- `test/features/discounts/views/create_discount_policy_screen_test.dart`
- `test/features/discounts/views/discounts_list_screen_test.dart`
- `test/app/route_scoped_request_topology_test.dart` (Discount fake only)
- `PROJECT_STATUS.md`

Scoped documentation: this handoff, its screenshot, and
`plans/discount_create_edit_variant_implementation_plan.md` task status.
The existing dirty backend implementation and Plan 2 were preserved. No backend
code, migrations, shared financial behavior, packages, commits, deployment or
non-testing data changes were made.

## 2026-10-03 F1/F2/F3 closure corrections

F2: DiscountsCubit ignores late success/error state emissions after close for list, branches, references, save and delete; duplicate-write guards and true/false mutation outcomes retained. Permanent lifecycle regressions fail before the fix and pass after it. Active errors retain safe mapping.

F1: backend explicit allowed headers now include X-App-Locale. CORS tests preserve approved origins, deny unknown origins and require authentication. Real Web release on localhost:18000 authenticated to localhost:18100, EN/AR locale headers and Discount responses observed; no proxy.

F3: harness now uses actual pointer/text interaction, center-aligned scroll visibility and the actual hit target, with fatal missed taps. No callback invocation. Windows POS/payment/receipt gate added against a reproducible guarded isolated fixture, expected 40 - 8 + 2.56 = 34.56. Final Windows run exit 0 (1 test, 04:03). Actual EN/AR Create/Edit, RTL, search/page/failure/retry, persisted selections, unavailable chip removal, sibling rejection and selected-variant apply/pay/receipt passed. EN order 3 / AR order 4: 40 - 8 + 2.56 = 34.56 equal backend. Screenshots visually inspected. D1-13/D1-14 closed on observed interactions.

Updated evidence and exact command exit codes: [2026-10-03 acceptance](verification/discount_variant_acceptance_2026-10-03.md). Prior 2026-10-02 acceptance remains historical partial evidence.

Plan 1 final closure 2026-10-03: F1/F2/F3 and D1-13/D1-14 CLOSED on observed acceptance. Ready for Plan 2; Plan 2 has NOT started. Final Windows/Web Release builds exit 0; scoped analyze/format/Pint exit 0; full analyzer exit 1 with 29 prior Info only. See current acceptance evidence for every command exit and screenshots.

## 2026-10-04 Plan 2 Flutter integration

The subsequent authorized phase adds integer priority and Automatic creation/conversion using `automaticPolicyCreationAvailable`, independently of `engineReady`. Public creation and activation remain unavailable; review and quote remain supported. Existing detail hydration, omitted fields, intentional null clears and Plan 1 target pagination/all-selected semantics are retained. Code-to-Automatic sends explicit `code:null`.

Compiled Windows EN/AR pointer/text acceptance now uses the Plan 2 review/quote flow, retaining variant sibling rejection, full mixed-target edit round trips and unavailable-target correction. EN order 14 / AR order 15 both prove **40 − 8 + 2.56 = 34.56** across Backend/POS/quote/payment/receipt, including lost-create/operation/payment responses and explicit stale-quote confirmation. Final Windows integration exit 0 (1 test, 04:15). The header assertion in the asynchronous Dio probe uses SDK `expectSync`; a focused before/after regression reproduces the prior test-only `D2_GENERIC` transport failure while retaining missing-header rejection. Final scope/gaps and source inventory: [Plan 2 Flutter verification](verification/discount_settings_flutter_2026-10-04.md). This update does not mark Plan 2 or D2-19 complete.

The final real Web payment follow-up separately verifies ad-hoc `2.50` review and cash stale-quote confirmation (order 16, total `8.10`), and null-tender zero settlement/receipt (order 18, total `0.00`, canonical `zero_balance` shown correctly). The sole Backend integration exception canonicalizes normalized intent key order after JSONB serialization; calculations and Plan 1 target rules are unchanged. No new-phase Code create/edit or isolated Automatic pointer acceptance is claimed; those Plan 2 gates remain open.
