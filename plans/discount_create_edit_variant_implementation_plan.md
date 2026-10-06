# خطة 1: إنشاء وتعديل الخصومات واستهداف الـ Variants

التاريخ: 2026-10-01 — Asia/Damascus.

Status 2026-10-03: F1/F2/F3 acceptance passed. D1-13/D1-14 closed on observed compiled Windows EN/AR pointer interactions and cross-origin Web. Final checks: docs/verification/discount_variant_acceptance_2026-10-03.md. Plan 2 has not started.

الخطة التالية: [إعدادات الخصومات والتطبيق التلقائي والجمع](discount_settings_automatic_combination_implementation_plan.md).

## 1. ترتيب التنفيذ والحدود بين الخطتين

**ابدأ بهذه الخطة أولًا، ثم نفّذ خطة 2.**

هذه الخطة تقدم خصومات فعلية على Variants محددة باستخدام مساري Manual وCode الحاليين، وتثبت قاعدة مطابقة الأسطر والحساب التي سيعتمد عليها المحرك التلقائي لاحقًا.

| الخطة | المسؤولية |
|---|---|
| خطة 1 | اختيار المنتجات والـ Variants، عقد الحفظ والتعديل، مطابقة الأسطر، الحساب، والتوافق مع السياسات القديمة |
| خطة 2 | إعدادات المقهى، Automatic، الأولوية، الجمع، المحرك، مزامنة POS المبكرة، الدفع، توزيع الخصومات، والإيصالات |

لا تعرض خيار Automatic ولا تسمح بإنشاء سياسات تلقائية في هذه المرحلة. إضافة الخيار وحقول الأولوية إلى Create/Edit مملوكة لخطة 2 بعد جاهزية المحرك. لا تنشئ placeholders أو قواعد حساب داخل Flutter.

لا تحتاج هذه المرحلة إلى تغيير قاعدة «خصم واحد يستبدل الخصم السابق» أو قيد استخدام الخصم الواحد لكل طلب.

## 2. أساس المراجعة من المصدر الحالي

- `backend/app/Http/Controllers/Api/DiscountController.php`: إدارة السياسات، full-policy replacement، validation، syncTargets، Manual/Code، واستبدال الخصم الحالي.
- `backend/app/Services/DiscountEligibilityService.php`: أهلية السياسة، eligibleSubtotal، perUnitFixedAmount، إعادة التحقق واستهلاك الاستخدام.
- `backend/app/Services/PosPricingService.php`: إجماليات الطلب والضريبة بعد الخصم.
- `backend/app/Http/Controllers/Api/PosOrderController.php`: حفظ product_variant_id في أسطر الطلب، مع مسار قديم قد تكون هوية الـ Variant فيه null.
- `backend/app/Http/Controllers/Api/Admin/Catalog/ProductCatalogController.php` و`backend/app/Http/Resources/Catalog/ProductDetailResource.php`: تفاصيل المنتج والـ Variants، ومجموعة منتجات paginated بحد 100 للصفحة.
- `windows_application/lib/features/discounts/`: النماذج، repository، Cubit، والنموذج الحالي. يتم تحميل DiscountDetail الكامل قبل التعديل.
- النموذج الحالي يجلب أول صفحة منتجات فقط ويحتفظ ببيانات مرجعية مختصرة، دون Variants.
- `backend/tests/Feature/DiscountRuntimeEligibilityTest.php`: تغطية المبلغ الثابت per_unit، السقوف، إعادة الحساب، الدفع، والاستخدام.
- `.specify/memory/constitution.md` و`windows_application/AGENTS.md`: السلطة الخلفية، الدقة، التاريخ، الترجمة، والبنية القائمة.

هذه مراجعة ملفات وليست إثباتًا بأن migrations مطبقة في أي بيئة. أعد التحقق من المصدر وحالة المخطط عند التنفيذ.

## 3. النتيجة المطلوبة للمستخدم

عند اختيار scope=product، يختار المستخدم منتجًا أو عدة منتجات. لكل منتج يظهر:

1. All variants / جميع الأنواع، أو Selected variants / أنواع محددة.
2. قائمة متعددة الاختيار عند اختيار Selected variants.
3. أسماء المنتج والأنواع بلغتي التطبيق دون تغيير IDs.
4. حالات loading / retry / empty / inactive selection / forbidden.

| القرار | سلوك هذه المرحلة |
|---|---|
| نوع الخصم | percentage أو fixed |
| قيمة الخصم | قيمة واحدة مشتركة بين أهداف السياسة |
| اختلاف القيمة بين الأنواع | إنشاء سياسات منفصلة؛ لا rule builder لقيم مختلفة داخل السياسة |
| fixedAmountBasis | per_order أو per_unit للخصم الثابت على المنتجات |
| جميع الأنواع | تشمل الأنواع المؤهلة الموجودة وأي نوع جديد يضاف لاحقًا |
| أنواع محددة | تشمل IDs المختارة فقط؛ النوع الجديد لا ينضم تلقائيًا |
| البداية عند اختيار منتج جديد | All variants مع تسمية واضحة |
| الأنواع غير النشطة/المؤرشفة | لا تُختار لإعداد جديد؛ الاختيارات السابقة تظل مرئية مع حالة واضحة |
| إزالة المنتج | إزالة اختيارات أنواعه من draft وpayload |
| تغيير scope | تنظيف أهداف المنتجات والأنواع غير المتوافقة |
| category / order / bundle | تبقى قواعدها الحالية؛ استهداف Variant داخل bundle خارج النطاق |
| applicationMode | Manual وCode فقط |

الحفظ في Selected variants دون اختيار أي نوع مرفوض. لا يُفسر الاختيار الفارغ على أنه جميع الأنواع.

## 4. عقد API المقترح والتوافق

احتفظ بـ targetProductIds كقائمة المنتجات وبحقل productTargets الحالي كتفاصيل عرض. **لا تستخدم productTargets الموجود لعقد جديد مختلف.**

أضف حقلًا مستقلًا باسم `productVariantSelections`:

```json
{
  "scope": "product",
  "type": "fixed",
  "fixedAmountBasis": "per_unit",
  "value": "5000.00",
  "targetProductIds": [12, 20],
  "productVariantSelections": [
    {"productId": 12, "variantMode": "selected", "variantIds": [101, 102]},
    {"productId": 20, "variantMode": "all", "variantIds": []}
  ]
}
```

هذا مثال جزئي؛ بقية حقول السياسة الحالية مطلوبة حسب العقد القائم. الأسماء مقترحة ويجب توثيق عقدها النهائي قبل كتابة DTOs.

- عند تقديم الحقل، يجب أن يوجد entry واحد بالضبط لكل targetProductId، دون منتجات إضافية أو مكررة.
- all يتطلب variantIds فارغة، selected يتطلب قائمة غير فارغة وفريدة.
- IDs صحيحة وتابعة لنفس tenant ونفس المنتج، والمنتج والنوع صالحان للإعداد الجديد.
- الأنواع غير النشطة القائمة في التفاصيل لا تُحذف من draft بصمت؛ يتطلب الحفظ تصحيحها أو إزالة الاختيار، وفق validation الحالية للأهداف غير النشطة.
- scope غير product يتطلب عدم وجود productVariantSelections.
- استرجاع التفاصيل يرجع الاختيار الصريح لكل منتج مع تفاصيل الأنواع اللازمة لإظهار الاختيارات القديمة.
- السياسات القديمة دون بيانات أنواع تُقرأ كـ all.
- إنشاء من عميل قديم دون الحقل يستمر كخصم شامل للمنتج.
- تحديث من عميل قديم دون الحقل يحافظ على اختيارات الأنواع للمنتجات التي بقيت، ويجعل المنتجات المضافة all، ويحذف اختيارات المنتجات المزالة. هذا استثناء توافق موثق يمنع توسيع سياسة selected بصمت.
- العميل الجديد يرسل الحقل كاملًا؛ الانتقال selected -> all يتم صراحة، وليس بحذف مفتاح JSON.
- بقية الحقول تظل full-policy replacement، مع nullable clears، دون فقد schedules أو groups أو customers أو channels أو bundle أو usage limits.
- لا توسع اطلاع POS على coupon codes.

## 5. نموذج التخزين المقترح

استخدم discount_targets الحالية كمرجع أهداف المنتج. أضف جدولًا مخصصًا مثل `discount_product_target_variants` يحتوي tenant_id، discount_id، product_id، product_variant_id والتواريخ.

- وجود صفوف أنواع لمنتج مستهدف يعني selected؛ غيابها يعني all.
- unique على tenant + discount + product + variant، مع indexes لمسار resolution.
- لا تخزن قائمة مكررة في JSON أو في أعمدة أخرى كمصدر سلطة ثانٍ.
- تحقق transactional من parent product target وملكية variant قبل الحفظ.
- selected الفارغ ممنوع في API؛ الحذف المقصود لكل الأنواع يمثل all فقط عندما يرسل العميل ذلك صراحة.
- تغيير scope أو إزالة parent target ينظف صفوف الأنواع التابعة في نفس transaction.
- المهاجرات additive/forward-only، دون تعديل order_items أو paid order_discounts التاريخية ودون destructive reset.
- archival لا يحذف IDs اللازمة للتفاصيل والتاريخ. راجع قيود FK بما يوافق soft deletion الحالي.

لا يلزم backfill لجميع السياسات: غياب الصفوف الجديدة يحافظ على الاستهداف القديم الشامل للمنتج.

## 6. مطابقة الأسطر والحساب

أنشئ مسارًا موحدًا لمطابقة أسطر الخصم في خدمة الخصومات القائمة أو helper صغير تابع لها. يستخدمه eligibleSubtotal وperUnitFixedAmount، وتستدعيه خطة 2 لاحقًا.

لكل سطر:

```text
المنتج غير مستهدف -> غير مؤهل
المنتج مستهدف وmode=all -> مؤهل حسب بقية شروط السياسة
المنتج مستهدف وmode=selected -> product_variant_id يجب أن يكون ضمن IDs لهذا المنتج
```

- لا تضف OR product_id يلتف على فلتر الأنواع.
- لا تستنتج Variant من الاسم أو السعر أو defaultVariant الحالي.
- سطر legacy بـ variant_id=null مؤهل لـ all فقط، وغير مؤهل لـ selected. لا تعديل جماعي للتاريخ أو تخمين للهوية.
- هوية وأسعار السطر تأتي من الطلب المحفوظ ونسخة القائمة المنشورة المثبتة، لا من سعر catalog الحالي.
- نسبة الخصم على مجموع الأسطر المطابقة فقط.
- fixed/per_order مرة واحدة على المجموع المؤهل؛ لا يتضاعف بعدد الأنواع أو المنتجات.
- fixed/per_unit يضرب القيمة في quantity للأسطر المطابقة، مع سقف قيمة كل سطر ثم سقف السياسة.
- base يظل شاملًا للـ modifiers الداخلة في selling total؛ minimum spend يظل whole-order pre-discount subtotal.
- حافظ على tax-after-discount وترتيب caps ومنع الإجماليات السالبة.

### الدقة

الكود الحالي يستخدم floats في أجزاء من DiscountEligibilityService وPosPricingService. لا تنسخ هذا النمط في الحساب الجديد.

- الحسابات الجديدة ومراحل الحساب المتأثرة تستخدم decimal exact / integer minor units بالاستفادة من `App/Support/Money` والبنية decimal المتاحة.
- quantities تدعم scale المخطط، ولا تُحوّل إلى integer عدد قطع افتراضيًا.
- قرّب مبلغ السياسة إلى خانتين HALF_UP عند الحد المالي النهائي؛ per_unit يجمع حاصل الضرب exact بعد line caps ثم يطبق policy cap ويقرب مرة واحدة.
- tax يقرب عند حد tax الحالي، دون إعادة تصميم معدل الضريبة أو الـ Finance.
- أضف أمثلة fractional quantity وcent boundaries. أي فرق عن float القديم على unpaid order يُوثق؛ التاريخ لا يعاد حسابه.
- حافظ على wire formats القائمة؛ لا تحوّل API الحالي كله إلى decimal strings في هذا العمل. parser الجديد يقبل number/string، والحساب الخلفي لا يعتمد على float.

## 7. تحميل المراجع والصلاحيات

- استبدل تحميل أول 100 منتج فقط باختيار يدعم server-side search وpagination واستبقاء selected IDs خارج الصفحة.
- حمّل أنواع المنتج عند الحاجة، مع cache مؤقت لكل productId ومنع الاستجابة القديمة من استبدال اختيارات منتج آخر.
- يمكن إعادة استخدام product detail، لكن endpoint الحالي يحتاج menu.management؛ لا تمنح مستخدم Discount صلاحية Menu واسعة فقط لكي يعمل selector.
- إذا تعارضت الصلاحيات، أضف endpoint مرجعي محدود تابع للخصومات: قائمة المنتجات paginated وتفاصيل variants، باستخدام discounts.manage والـ tenant نفسه. لا تعيد recipe/cost أو بيانات غير لازمة.
- listing المرجعي لا يغير قواعد POS المنشورة ولا يستعمل كبديل runtime menu.
- validation وlookup في الباك إند؛ UI filtering ليس حاجز أمان.

## 8. مهام التنفيذ المرتبة

### P1-A — تثبيت العقد والمخطط

- [x] D1-01: إعادة مراجعة الحالة الحالية والـ dirty tree، وتوثيق payloads والحقول الموجودة؛ لا حذف عمل غير متعلق.
- [x] D1-02: تثبيت productVariantSelections، omitted/clear semantics، سياسة inactive IDs، والـ error codes.
- [x] D1-03: إضافة migration للجدول والقيود مع اختبارات توافق السياسات القديمة.

### P1-B — الباك إند والحساب أولًا

- [x] D1-04: transactional validation/persistence/detail serialization مع الحقول القديمة دون تغيير شكل productTargets.
- [x] D1-05: بناء matcher موحد يغطي all/selected/null legacy وtenant/product ownership.
- [x] D1-06: دمجه في percentage/fixed/per_unit وإعادة الحساب والدفع مع exact monetary calculations في المسارات المتأثرة.
- [x] D1-07: توفير selectors مصرح بها وpaginated، دون توسيع menu permissions.
- [x] D1-08: توثيق العقد وتأكيد اختبارات backend قبل بدء Flutter.

### P1-C — Flutter Create/Edit

- [x] D1-09: تحديث DiscountDetail وDiscountUpsertRequest وreferences/repository/Cubit/state بصورة lossless.
- [x] D1-10: إضافة selector لكل منتج، وتصفية/بحث الأنواع والاختيارات المتعددة وحالات الخطأ.
- [x] D1-11: تنظيف dependent selections، hydration من detail، ومقاومة responses القديمة/الضغط المتكرر.
- [x] D1-12: تحديث sidebar summary وpreview wording والـ list عند الحاجة دون حساب eligibility محلي؛ المثال التوضيحي ليس quote قابلًا للدفع.
- [x] D1-13: Observed 2026-10-03 compiled Windows EN/AR pointer/text Create/Edit, RTL screenshots, All/Selected, search/page/failure/retry, preserved selections and unavailable correction. Final integration test exit 0; callback evidence is historical only.

### P1-D — الإغلاق والتسليم

- [x] D1-14: Observed 2026-10-03 Windows POS sibling rejection and selected-variant pointer apply/pay/open receipt. EN order 3 / AR order 4: 40 - 8 + 2.56 = 34.56 equal backend. Real cross-origin Web login/Discount EN/AR passed. All command exit codes in current evidence.
- [x] D1-15: Handoff and DTO/selector evidence retained; current runtime evidence supersedes historical partial acceptance. Plan 2 unstarted.

### دليل Flutter — 2026-10-02 (بعد تصحيح الترقيم وإغلاق القبول)

- التصحيح: ترقيم منتقي المنتجات/الأنواع كان يخلط بحثاً جديداً ببيانات ترقيم قديمة (فشل صفحة 1 لبحث جديد يترك «التالي» مفعلاً ويطلب صفحة 3 من البحث الجديد). الآن `pageQuery` يربط البيانات الوصفية بالاستعلام الناجح، وتُمسح عند تغيّر الاستعلام، وتُعطّل أزرار التنقل ويُخفى عداد الصفحات أثناء التحميل والخطأ، وإعادة المحاولة تكرر الاستعلام والصفحة الفاشلين. الملفان: `discount_targets_cubit.dart` و`discount_product_targets.dart`. الاختبارات الدائمة (منتجات + أنواع، EN/AR): `test/features/discounts/discount_picker_pagination_test.dart` — 7 اختبارات، وتفشل جميعها دون الإصلاح.
- Discounts: 83 اختباراً، POS Discount dialog: 2، Discounts routing: 2، عزل طلبات التوجيه: 4؛ جميعها خروج 0.
- التحليل المحدد (يشمل `integration_test`): لا ملاحظات، خروج 0. التحليل الكامل: 29 Info سابقة في Sales واختبار Printer دون أخطاء/تحذيرات، خروج 1 (لم تُعدّل). التنسيق المحدد و`git diff --check`: خروج 0.
- بناء Web وWindows (release) بعد الإصلاح: خروج 0.
- القبول المصادق عليه ضد باك إند اختبار معزول (Postgres/DB/volume منفصلة، `APP_ENV=testing`): Web في متصفح حقيقي وWindows عبر `integration_test/discount_variant_acceptance_live_test.dart` (1 اختبار، خروج 0)؛ باك إند POS/دفع/إيصال عبر الـ API ومسار القائمة المنشورة؛ ثم POS→دفع→إيصال بواجهة Web بالعربية: 55 − 6 + ضريبة 3.92 = 52.92 مطابق للباك إند. التفاصيل واللقطات والملاحظات F1–F3: [تقرير القبول](../docs/verification/discount_variant_acceptance_2026-10-02.md).
- لم تُعدّل تغييرات Backend الموجودة أو خطة 2، ولم تُنفّذ commits أو deployment أو migrations على بيانات تشغيلية (migrations/seed على قاعدة الاختبار المعزولة فقط).
- التسليم وجرد الملفات: [تقرير Flutter](../docs/discount_variant_flutter_handoff.md).

## 9. الاختبارات ومعايير القبول

| المجموعة | الحالات المطلوبة |
|---|---|
| Contract | create -> detail -> edit -> save دون فقد الحقول؛ all/selected، omitted legacy، explicit clears، malformed shapes/duplicates |
| Security | foreign tenant/product، inactive/archived new targets، unauthorized references، branch enforcement في apply/payment |
| Runtime | selected variant فقط؛ sibling variant مستبعد؛ mixed products؛ modifiers؛ quantity fractional؛ per_order لا يتضاعف |
| Caps/precision | line cap، policy cap، zero policy الحالية، 100%، cent boundaries، tax-after-discount |
| Lifecycle | cart/customer mutations، held/resume، payment-time revalidation، paid snapshot بعد policy/catalog edit |
| Flutter | تحميل detail وليس list DTO، paging أكثر من 100 منتج، inactive saved selection، retry، stale response، field errors، duplicate submit |
| Layout | EN/AR في مقاسات مقيدة، التقاط RenderFlex/layout exceptions وRTL geometry |

نفّذ Laravel serially على testing database فقط:

```powershell
docker compose exec -T backend php artisan test --filter='DiscountManagementApiTest|DiscountV1ContractTest|DiscountV2BackendTest|DiscountSecurityHardeningTest|DiscountRuntimeEligibilityTest'
```

أضف suite الجديدة للاختبارات أعلاه، ثم POS/Payment/Refund regression المناسبة. لا تُضعف assertions الحالية؛ replacement test يبقى صحيحًا هنا.

نفّذ Flutter بصورة متسلسلة دون تنازع SDK lock:

```powershell
cd windows_application
flutter gen-l10n
flutter test --concurrency=1 test/features/discounts
flutter test --concurrency=1 test/features/pos/widgets/discount_dialog_test.dart
flutter analyze
```

شغّل format/Pint المناسبين للملفات المعدلة ثم `git diff --check`. نتائج هذه الأوامر ليست منفذة وقت كتابة الخطة.

تُغلق المرحلة عندما يعمل Manual وCode على الأنواع المحددة، وتحافظ السياسات القديمة على all، وتتطابق فاتورة POS والدفع والإيصال، وتمر فحوص العقد والأمان واللغة والحساب.

## 10. Rollout والمخاطر

- نشر المخطط additive ثم backend ثم العميل الجديد؛ لا تطبيق migrations على غير testing دون خطوة نشر مصرح بها.
- اختبار migration من مخطط قديم ببيانات تاريخية على نسخة اختبار، والتحقق أن paid amounts لا تتغير.
- العميل القديم يحافظ على targets selected أثناء edit بفضل omitted semantics، لكنه لا يقدم UI لعرضها؛ نسخة العميل المطلوبة لاستخدام الميزة تُذكر في release notes.
- archive بعد configuration: لا تعتمد على catalog price الحالي ولا توسع selected تلقائيًا. طبّق lifecycle للطلب المثبت واتبع إعادة التحقق الحالية دون تخمين.
- لا تعالج bugs مجاورة واسعة أو تعيد بناء menu/tax/auth ضمن هذه الخطة.
- rollback للتطبيق لا يحذف targets الجديدة ولا يفتح مسار حساب يتجاهلها؛ إذا لزم downgrade غير متوافق، أوقف عمليات الخصم المتأثرة حتى roll-forward آمن.

## 11. بوابة الانتقال إلى خطة 2

يجب أن تكون مطابقة الأنواع، الحفظ الكامل، الدقة، والصلاحيات مثبتة قبل محرك Automatic. يمكن تصميم settings schema بالتوازي على الورق، لكن التنفيذ الافتراضي يبقى خطة 1 ثم خطة 2.

ملاحظة تاريخية: عند كتابة الخطتين كان الطلب يخص التخطيط فقط. تنفيذ Backend ثم Flutter المذكور في سجل الحالة تم بتفويض مستقل؛ هذا الملف لا يمنح إذناً بالنشر أو commit.

Plan 1 final closure 2026-10-03: F1/F2/F3 and D1-13/D1-14 CLOSED on observed acceptance. Ready for Plan 2; Plan 2 has NOT started. Final Windows/Web Release builds exit 0; scoped analyze/format/Pint exit 0; full analyzer exit 1 with 29 prior Info only. See current acceptance evidence for every command exit and screenshots.
