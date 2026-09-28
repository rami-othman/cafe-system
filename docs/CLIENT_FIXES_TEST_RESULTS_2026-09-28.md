# نتائج اختبارات T10 — خطة إصلاح ملاحظات العميل (2026-09-28)

المرجع: `docs/CLIENT_FIXES_PLAN_2026-09-28.md`، `docs/CLIENT_FIXES_PROGRESS.md`. الفرع: `fix/client-feedback-2026-09-28`.

## منهجية الفحص

`php artisan test` بهذا المستودع يشغّل كل الاختبارات (~1040) بعملية PHP واحدة مشتركة، وقاعدة بيانات
Postgres مشتركة يُعاد إنشاؤها بـ `RefreshDatabase` لكل صف اختبار — هذا يجعل التشغيل الكامل عرضة
لتضارب أقفال (`deadlock`) حقيقي إذا تزامن أكثر من تشغيل، ولانتفاخ فشل غير مرتبط عند تشغيله بالتوازي مع
نفسه. لتفادي نتائج مضلِّلة: كل فشل ظهر بالتشغيل الكامل أُعيد تشغيله **بمعزل** (ملف الاختبار وحده) قبل
اعتباره فشلاً حقيقياً.

## جدول التصنيف (لكل فشل ناتج فعلياً عن T1–T9)

| الاختبار | السبب | التصنيف | ماذا عُدِّل |
|---|---|---|---|
| `DailyClosingListAndPaymentBreakdownTest::payment_breakdown_is_grouped_by_real_payment_method_and_nets_refunds` | T9 غيّر اسم طريقة الدفع الافتراضية من `Cash` إلى `نقدي` | تغيير مقصود (T9) | `keyBy('method')['Cash']` → `['نقدي']` + تعليق `behaviour changed in T9` |
| `DailyClosingConcurrencyTest::close_ignores_client_supplied_totals_and_always_uses_backend_calculated_values` | `makePayment()` بالفكسشر لا تنشئ قيداً محاسبياً، وT4 صار يشتق النقد المتوقع من رصيد الدفاتر لا من `orders`/`payments` مباشرة | فجوة فكسشر (T4) | أضفت `DailyClosingFixtures::postCashSaleLedger()` (قيد مدين موقع الصندوق / دائن 4000) واستدعيتها بعد `makePayment()` في هذا الاختبار فقط؛ لم تُعدَّل `makePayment()` ولا القيم المتوقعة |
| `DailyClosingConcurrencyTest::test_historical_snapshot_is_frozen_even_after_new_legitimate_data_lands_...` | نفس سبب أعلاه | فجوة فكسشر (T4) | نفس الحل: `postCashSaleLedger()` بعد `makePayment()` الأولى فقط (البيع المتأخر بعد الإغلاق لا يحتاجها لأنه لا يفحص `expectedCash`) |
| `ShiftDrawerLifecycleTest::test_13_close_fails_when_drawer_ledger_differs_from_counted_cash` | T2: فرق العدّ لم يعد يمنع الإغلاق برسالة `closingCash` — صار يتطلب `cashDifferenceReason` ويُرحَّل للحساب 6180 | تغيير مقصود (T2) | أعدت تسمية الاختبار وكتابته: يتحقق أولاً من 422 على `cashDifferenceReason`، ثم يغلق فعلياً بسبب ويتحقق من القيد والتحويل وتصفير رصيد الدرج |
| `ShiftDrawerLifecycleTest::test_historical_close_date_defines_period_but_transfer_has_actual_execution_date` | T3: تاريخ تحويل الإغلاق التاريخي صار تاريخ الفترة المُغلَقة نفسه، لا تاريخ التنفيذ الفعلي | تغيير مقصود (T3) | `transfer_date` المتوقع: `2026-09-27` → `2026-09-26` + تعليق `behaviour changed in T3` |
| `CashSaleMainSafeTransferRegressionTest::a_mismatched_close_leaves_the_shift_open_and_creates_no_transfer` | نفس سبب T2 أعلاه | تغيير مقصود (T2) | `assertJsonValidationErrors('closingCash')` → `assertJsonValidationErrors('cashDifferenceReason')` + تعليق |
| `PurchasingPhase2ApiTest::test_unified_purchase_post_honours_explicit_payment_and_receipt_dates` | T7: `PurchasePostingOrchestrator` صار يتجاهل `paymentDate`/`receiptDate` القادمين من الطلب ويستخدم `invoice_date` دائماً | تغيير مقصود (T7) | أعدت تسمية الاختبار وكتابته: يرسل تواريخ مختلفة (2026-09-20/21) ويتحقق أنها **تُتجاهَل** وأن الدفع/الاستلام/حركة المخزون كلها بتاريخ الفاتورة 2026-09-17 |
| `PurchasingPhase2ApiTest::test_unified_purchase_post_rejects_payment_date_in_a_closed_period` | نفس سبب T7 أعلاه — إغلاق فترة أغسطس لم يعد ذا معنى بما أن `paymentDate` المرسل لم يعد يُستخدم | تغيير مقصود (T7) | أعدت تسمية الاختبار: يُغلق الآن فترة **سبتمبر** (تشمل `invoice_date`=2026-09-17) بدل أغسطس، ويتحقق من رفض الترحيل بسبب الفترة المغلقة على تاريخ الفاتورة نفسه |
| `BackdatedInvoicesTest`, `CustomerPaymentApiTest` (21 اختبار)، `ArabicValidationErrorPresentationTest`، `PurchaseLineCostPrecisionApiTest`، `PurchasingPhase1/2/3ApiTest`، `SalesCreditNoteDirectCashApiTest`، `SalesInvoiceLinePricingTest`، `SalesInvoicePhaseOneApiTest`، `SalesInvoicePhaseTwoApiTest`، `SalesInvoicePosCrossPathCharacterizationTest` | T7: أي فاتورة بتاريخ سابق لليوم الفعلي (تاريخ اليوم الحقيقي 2026-09-28) تتطلب `backdateReason` الآن. هذه الملفات كانت تستخدم تواريخ ثابتة (`2026-09-01`, `2026-09-12`, `2026-09-17`, `2026-09-19`...) صارت بحكم مرور الوقت تواريخ ماضية | تغيير مقصود (T7) | أضفت `'backdateReason' => 'بيانات اختبار بتاريخ سابق'` بجانب كل `'invoiceDate' => '2026-XX-XX'` حرفي بهذه الملفات (13 ملفاً، ~85 موضعاً) — لا تغيير على القيم أو المنطق المُختبَر |
| `windows_application/test/features/shift/shift_cash_contract_test.dart` (Flutter) | T5: الباك إند صار يرسل دائماً `salesSum`/`salesTotal`/`salesNet` بجانب `grossSales`/`discounts`؛ الموديل الحالي لم يعد يحسب `salesTotal` محلياً كـfallback | تغيير مقصود (T5) | أضفت المفاتيح الثلاثة للـ JSON الوهمي بالاختبار (`100.00`/`90.00`/`90.00`) + تعليق |
| `windows_application/test/features/inventory/models/inventory_dashboard_model_test.dart` (Flutter) | T8: الباك إند أعاد تسمية حقل مرجع الحركة من `reference` إلى `referenceNumber` | تغيير مقصود (T8) | غيّرت مفتاح الـ JSON الوهمي `'reference'` → `'referenceNumber'` + تعليق |
| `windows_application/test/sales_profitability_screen_test.dart` (Flutter) | T5: تسميات «إجمالي/مجموع المبيعات» تغيّرت | تغيير مقصود (T5) — **عدّله نموذج آخر بنفس الجلسة**، تحقّقت أنه صحيح ولم ألمسه | (سبق تعديله) |

## أخطاء حقيقية أُصلحت بالكود (لا بالاختبار)

| الملف | الخطأ | الإصلاح |
|---|---|---|
| `backend/tests/Feature/Concerns/DailyClosingFixtures.php::postCashSaleLedger()` (كتبتها بنفس T10) | `SQLSTATE[42702] Ambiguous column "id"` — استعلام `financial_locations` join `financial_accounts` بدون تأهيل `id` | أهّلت العمود إلى `financial_locations.id` |

## فشل واحد غير مرتبط بـ T1–T9 (وُجد أثناء الفحص، لم يُصلَح)

- `PurchasingPhase1ApiTest::test_purchasing_center_show_returns_lines_and_related_payments`: يفشل بـ
  "يجب تحديد الفرع للدفع النقدي" (ثم بعد إضافة `branchId`: "الصندوق المحدد غير متاح لهذا الفرع"). فحصت
  `git diff` على `SupplierPaymentService.php` — التغيير الوحيد هناك هو ترجمة نص الرسالة لهذه المهمة
  بالذات (T9)؛ منطق التحقق نفسه لم يتغيّر، والفكسشر أصلاً لم يكن يرسل `branchId`. **هذا عطل موجود مسبقاً
  في الفكسشر لا علاقة له بخطة T1–T9** — رجعت عن محاولة إصلاحه (كان سيفتح طبقة ثانية من نفس المشكلة في
  اختيار الموقع النقدي الصحيح للفرع) وتركته كما كان ليقرره صاحب المشروع بشكل منفصل.

## فشل واسع غير مرتبط بـ T1–T9 (موجود مسبقاً في المستودع)

عند تشغيل المجموعة الكاملة دفعة واحدة يظهر عدد كبير من الفشل الإضافي (عشرات الاختبارات) في ملفات لم
تُلمَس إطلاقاً بخطة T1–T9: `PreAuthFinancialConcurrencyTest` (اختبارات تزامن حقيقية عبر عمليات متوازية
تضرب نفس قاعدة postgres — حساسة جداً للحمل)، `Manufacturing\ManufacturingCoreFlowTest`،
`DiscountRuntimeEligibilityTest`، `CustomerAgingAndStatementTest`، `Phase12AuthorizationApiTest`،
`AuthPhaseOneTest`، `BranchCashDrawerTest`، `CashierAuthorizationApiTest`،
`Cafe618*DemoSeederTest` (×3)، وحالة إضافية واحدة بـ`FinanceDashboardSalesAndCogsTest` بنفس نمط
"الصندوق غير متاح لهذا الفرع". تحققت من عدة عيّنات بمعزل تام: رسائل الخطأ (`NO_OPEN_SHIFT`، فرع/موقع
نقدي غير متطابق، تناقض تعداد نتائج تزامن) لا علاقة لها بأي من التغييرات بـT1–T9 (لا شيفت، لا فرق نقدي،
لا فواتير بتاريخ سابق، لا تسميات)، والملفات نفسها بلا أي `git diff` بهذه الجلسة. **هذا دين اختبارات
موجود مسبقاً بالمستودع (على الأغلب حساسية تزامن/بيانات فكسشر legacy)، خارج نطاق خطة 2026-09-28،
ويحتاج فحصاً منفصلاً من صاحب المشروع.**

## ملخص الأرقام

- **الاختبارات الجديدة المطلوبة بالخطة (T1، T4، T5، T6، T7، T8):** 7 ملفات جديدة —
  `CashVarianceAccountTest`, `ShiftCloseVarianceTest`, `DailyClosingVarianceTest`,
  `BackdatedInvoicesTest`, `FinancialAccountBalanceCardTest`, `InventoryItemTabsTest`,
  `SalesTotalsTest` — **كلها ناجحة** عند التشغيل المعزول.
- **اختبارات قديمة عدّلت توقعها لتغيير سلوك مقصود:** 4 حالات (T2 ×2، T3 ×1، T7 ×2) + 13 ملفاً لتواريخ
  الفواتير (T7) — **كلها ناجحة الآن**.
- **فجوة فكسشر واحدة (T4) ظهرت باختبارين:** أُصلحت بإضافة قيد محاسبي حقيقي، **بدون** تغيير القيم
  المتوقعة أو `makePayment()` — **ناجحة الآن**.
- **Flutter:** ملف واحد فقط (`shift_cash_contract_test.dart`) و`inventory_dashboard_model_test.dart`
  عُدِّلا لنفس سبب "الحقول الجديدة صارت دائماً موجودة بالرد" — **`flutter test` كامل: 1513 ناجح، 22 فشل
  غير مرتبط (تحقّقت أن كل ملف بهذه الـ22 بلا أي `git diff` بهذه الجلسة: مسارات عملاء/كاشير/مصادقة/
  Golden tests/Orders لم تُلمَس إطلاقاً بـT1–T9).**
- **الباك إند (آخر تشغيل كامل بعد الإصلاحات):** 799 ناجح، 240 فاشل، اختبار واحد متخطّى، 8398 تأكيداً. ما زالت حزمة PHP الكاملة فاشلة؛ يلزم تشخيص الإخفاقات المتبقية قبل اعتبار T10 مكتملة.

## نتيجة `php artisan test` الكاملة (بعد كل إصلاحات T10)

```
Tests: 240 failed, 1 skipped, 799 passed (8398 assertions)
Duration: 1382.32s
```

هذه نتيجة `php artisan test --compact` الكاملة المسجّلة في `backend/storage/logs/client_fixes_php_test.log`. الاختبارات الجديدة المذكورة أعلاه نجحت عند تشغيلها بمعزل؛ هذا لا يجعل الحزمة الكاملة ناجحة.

## نتيجة `flutter test`

```
+1513 -22
```

كل الـ22 فشلاً مُتحقَّق أنها موجودة مسبقاً (نفس القائمة قبل وبعد إصلاحاتي، في ملفات لم يلمسها T1–T9:
`app/customer_management_routing_test.dart`, `app/cashier_route_guard_test.dart`,
`cashier_dashboard_screen_test.dart`, `cashier_inventory_screen_test.dart`, `core/tax_config_test.dart`,
`features/auth/auth_session_storage_contract_test.dart`,
`features/cafe_configuration/cafe_configuration_cubit_test.dart` (فشل تحميل)،
`features/customer_management/goldens/*` (٤ ملفات)،
`features/finance_inventory_setup/views/cash_banks_screen_test.dart` (خطأ `ProviderNotFoundException`
لـ`AuthSessionCubit` غير مرتبط بأي تعديل)، `features/orders/widgets/orders_payment_screen_test.dart`
(×3)، `features/sales/sales_phase_three_test.dart` (×2 — `CustomerPaymentDialog` لم تُلمَس إطلاقاً)،
`orders_screen_test.dart`).

## `flutter analyze`

نظيف عبر كل المجلدات المعدّلة (`shift`, `finance_inventory_setup`, `reports`, `sales`, `purchasing`,
`inventory`, `shared`, `core/network`) — فقط ملاحظات `info` أسلوبية قديمة (`curly_braces_in_flow_control_structures`
إلخ) بنفس الأسطر الموجودة قبل هذه الجلسة، تحقّقت بـ`git diff` أنها ليست من أي تعديل اليوم.
