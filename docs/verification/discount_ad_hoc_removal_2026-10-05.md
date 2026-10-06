# إزالة الخصم الحر ومراجعة متبقي خطة 2

التاريخ: 2026-10-05 — Asia/Damascus.

## ما تم في هذه المرحلة

- أُزيل زر «حر» ونافذة إدخال مبلغ/نسبة الخصم من POS، وأُزيل constructor طلب ad-hoc من Flutter. الاختيار الجديد يكون سياسة Manual محفوظة ومؤهلة أو Code.
- أُغلق إنشاء الخصم الحر لجميع الأدوار في Backend: الطلب المصرح له إلى preview بقصد ad_hoc أو مسار PUT القديم يعيد HTTP 422 مع DISCOUNT_AD_HOC_DISABLED؛ قد ترفض middleware الطلب غير المصرح له بـ403 قبل ذلك. مراجعة ad-hoc قديمة غير منفذة لا تستطيع إنشاء عملية جديدة.
- أُزيل خيار «تطبيق الخصومات الحرة» من واجهة منح صلاحيات Manager. المفاتيح القديمة في storage/catalog بقيت للتوافق فقط، ولا يمكن لأي grant إعادة فتح الإنشاء. لا توجد migration لحذف صلاحيات أو بيانات تاريخية.
- بقيت الخصومات الحرة المحفوظة قابلة للقراءة والإزالة الصريحة والتسوية، وبقي replay العمليات المكتملة صالحًا. حساباتها وallocations وsnapshots والإيصالات التاريخية لم تُحذف أو تُعد كتابتها.
- حافظت اختبارات السياسة المحفوظة وCode وcaps والجمع والضريبة والتقرير اليومي على assertions السلوك. استُبدل إدخال قيمة حرة في fixtures التي تحتاج خصمًا جديدًا باختيار سياسة محفوظة.
- تم التحقق، دون تطبيق migrations في هذه المرحلة، أن migrations خطة 2 الثلاث أصبحت Ran / batch 28 في Backend المحلي.
- engineReady=false وAutomatic العام مغلقان، ولم يُنفّذ تفعيل أو نشر أو commit. لا إغلاق لمهام القبول المتبقية بمجرد نجاح الاختبارات.

## معالجة Git المعتمدة

بعد عرض الاقتراح وموافقة المستخدم صراحة، حُذف فقط:

- output/discount-plan2-head-worktree
- output/discount-plan2-head-flutter.zip

تحققت المسارات المطلقة داخل workspace، وعدم وجود reparse points أو ملفات tracked في الهدفين قبل الحذف. أُضيف تجاهل لهذين المسارين فقط إلى .gitignore. التقارير والسجلات والصور الأخرى بقيت محفوظة.

قبل العمل كان Git يعرض 1825 ملفًا. نسخة HEAD كانت تتضمن 1508 ملفات ظاهرة في Git وملفات مولدة متجاهلة إضافية. حذف النسخة وZIP يزيل 1509 entries؛ اختلاف العدد النهائي عن 316 ناتج عن ملفات الكود والاختبارات والتوثيق الخاصة بهذه المرحلة. لم تُستخدم git clean أو reset أو حذف عام لمجلد output.

العدد النهائي المرصود: 323 مسارًا في Git، منها 248 غير متتبعة. بقيت 69 صورة غير متتبعة خارج النسخة المحذوفة، ولم تُحذف. الباقي يحتاج مراجعة وانتقاء ملفات الكود والتوثيق لاحقًا؛ لا يمثل مشروعًا مكررًا آخر يجب حذفه تلقائيًا.

تبويبات IDE المفتوحة داخل النسخة المحذوفة تُغلق، والعمل يكون على windows_application/test/cashier_inventory_screen_test.dart في المشروع الأصلي. تلك النسخة كانت export للمقارنة وليست worktree مسجلة.

## التحقق

قاعدة التشغيل المحلية لم تُستخدم للاختبارات. استُخدمت خدمات مشروع cafe-discount-acceptance-20261003 الموجودة، مع حفظ volumes. قبل الاختبارات تحقق tests/Fixtures/DiscountEngineEnvironment.php من APP_ENV=testing وhost=accept-postgres ومن:

- pgsql: cafe_system_618_testing
- pgsql_migrations: cafe_system_618_testing_migrations

الأوامر التي تغيّر بيانات الاختبار نُفذت بالتتابع. Flutter commands نُفذت بالتتابع أيضًا.

بعد الاختبارات أُعيد accept-backend وaccept-postgres إلى التوقف، وتحقق docker ps من ذلك. بقيت volumes الثلاثة الخاصة بالمشروع محفوظة، وخدمات Backend/PostgreSQL المحلية تعمل. أنهى Docker حاوية Backend بـ137 عند التوقف، وPostgreSQL بـ0؛ هذا ليس نتيجة اختبار أو فشل assertion.

| الفحص | النتيجة |
|---|---|
| Flutter focused: إعدادات، DTO، دورة POS، اختيار سياسة محفوظة، quote، dialog، إيصال الرصيد الصفري | 70 passed، exit 0 |
| flutter analyze --no-pub على المسارات السبعة المعدّلة | No issues found، exit 0 |
| Pint --test على عشرة ملفات PHP معدّلة | PASS، exit 0 |
| PHP syntax داخل Docker على الملفات الخمسة الأساسية | نجاح، exit 0 |
| مجموعة Backend الأولى | 40 passed / 1 failed، 624 assertions، exit 1 |
| المجموعة الخلفية النهائية بعد تصحيح fixture | 38 passed / 581 assertions، exit 0، 66.16s |
| DailyReportApiTest وTenantTaxAndValidationTest في المجموعة الأولى | 3 passed، لم تُكرر بعد تعديل fixture الخاص بـreplay |
| git diff --check | نجاح بعد تحديث التوثيق، exit 0 |

فشل المجموعة الخلفية الأولى كان في اختبار replay الجديد: assertJsonPath قارن ترتيب مفاتيح PHP قبل التخزين بترتيب JSONB بعد التخزين. صُحّح expected fixture ليمثل النتيجة المحفوظة فعلًا، مع الإبقاء على المقارنة الصارمة وعلى assertions عدم تكرار العملية والخصم وثبات الإجمالي. لا تغيير في كود المنتج لهذا الفشل. DailyReportApiTest وTenantTaxAndValidationTest نجحت في المجموعة الأولى؛ لم تُكرر هاتان المجموعتان بعد تصحيح fixture الوحيد.

محاولة syntax عبر PHP المحلي لم تُنفّذ بسبب Access denied؛ الفحص الفعلي استُكمل بنجاح داخل Docker. ليست نتيجة نجاح لـPHP المحلي. لم تُعد full suites أو مقارنة HEAD أو Windows/Web builds في هذه المرحلة؛ لم يُلاحظ التطبيق المترجم أو الإخراج الفعلي للطابعة بعد الإزالة.

## المتبقي في Flutter

| المهمة | التنفيذ الموجود | بوابة القبول المتبقية |
|---|---|---|
| D2-11 | Automatic/priority وdetail hydration وexplicit clear موجودة | Code مستهدف بالـvariants: إنشاء/تعديل/إعادة فتح؛ Automatic: إنشاء وتحويل وحفظ priority في بيئة اختبار معزولة |
| D2-13 | persistent cart وهوية الإنشاء وطابور mutations والتعافي موجودة | hold/resume، إزالة العميل، تغيير الفرع، clear/cancel والطلبات المتروكة وأثر shift close بتفاعل فعلي |
| D2-14 | discounts[] وpreview/confirmation وsuppression وpayment quote موجودة | Automatic/disjoint/cap وsuppression/undo، التحويل بين معرفي cash/card، إعادة تأكيد quote قديم، ورصيد صفري بسياسة محفوظة |
| D2-15 | breakdown في POS والإيصالات والتاريخ ودعم legacy موجود | pre-bill وإعادة فتح history وتعديل السياسة بعد الدفع دون تغيير الإيصال؛ الطباعة الفعلية غير مثبتة |
| D2-16 | header 2 وcompatibility وcontext invalidation موجودة | جلسات اختبار Automatic مع الصلاحيات، وتغير الفرع/العميل والجلسة دون عرض quote أو capability قديمة |

قضايا القبول المشتركة: Windows standalone Release، Manager/Employee على Windows، Web بالإنجليزية، EN/AR وRTL بأحجام مقيدة، وnative zero-balance. قبول Windows السابق كان عبر Debug integration runner مع build Release منفصل. الأدلة القديمة لتدفق ad-hoc أصبحت أدلة تاريخية؛ يجب إعادة السيناريوهات الجديدة باستخدام Manual أو Code محفوظ، خصوصًا quote القديم والتسوية الصفرية. لا حاجة لإعادة بناء الواجهات من الصفر؛ تُصلح العيوب التي يكشفها هذا القبول فقط.

## المتبقي في Backend

1. الأساس D2-01–D2-09 والمحرك والعقود والتزامن منفذة. نجاح إزالة الخصم الحر لا يعيد تصنيفها على أنها ناقصة التنفيذ؛ اختبار قبول Automatic المنتج النهائي ما يزال مطلوبًا.
2. تشغيل fixtures الاختبار المعزولة المجهزة لـAutomatic والتأكد من أن capability إنشاء سياسة Automatic مستقلة عن engineReady. لا تشغيل overrides على قاعدة التشغيل المحلية.
3. إعادة إثبات دورة policy → POS → quote → payment → receipt → usage/Finance، ومطابقة allocations والإجماليات، باستخدام المنتج النهائي دون إنشاء ad-hoc جديد. اختبارات المحرك الخلفية تغطي كثيرًا من هذه الحالات؛ التفاعل الحي على Flutter هو الفجوة الأساسية.
4. قبل rollout النهائي: مراجعة migration/rehearsal وتوافق البيانات والعملاء القدامى. قيود foundation مطبقة بالفعل؛ أي تعديل لاحق لها يكون migration additive جديدة، لا تعديل ملف migration مطبق.
5. D2-19 تتطلب تغيير capability العامة وتغيير CHECK الذي يمنع automatic_enabled، بعد استكمال بوابات القبول ومراجعة وتفويض منفصلين. automaticEnabled يبقى false حتى يختاره المقهى. لا يكفي تغيير engineReady وحده.
6. Full-suite baselines القديمة سجلت 44 إخفاقًا في Backend و22 في Flutter. هذا سجل سابق وليس نتيجة تشغيل جديدة. أثناء الإغلاق يجب فصل إخفاقات baseline عن أي regression جديد وعدم وصف full suite بأنها خضراء.

## ترتيب العمل الموصى به

1. قبول النسخة الحالية بعد إزالة الخصم الحر على Windows وWeb: لا زر ولا إدخال قيمة؛ Manual/Code صالحان؛ الطلب المباشر لا ينشئ خصمًا؛ التاريخ والرصيد الصفري محفوظان.
2. دفعة قبول D2-11/D2-14/D2-16 في البيئة المعزولة: Automatic، priority، أعلى/أقل توفير، disjoint، cap، suppression/undo، cash/card، quote القديم. تُجمع الأدلة مرة واحدة للمهمة والسيناريو والمنصة واللغة، وتُصلح العيوب المثبتة فقط.
3. دفعة D2-13/D2-15: دورة السلة والعميل والفرع والوردية، pre-bill/history والإيصالات. تستقل الطباعة عن إعادة الدفع.
4. بناء Windows/Web للنسخة النهائية وإجراء قبول Windows Release المستقل، ثم توثيق نتائج الفحوص والإخفاقات التاريخية وإغلاق المهام التي ثبتت فقط.
5. مراجعة rollout لـD2-19 ثم طلب تفويض مستقل لتطبيق migration التفعيل وتغيير capabilities. لا يتم التفعيل ضمن دفعات القبول.

## الملفات الخاصة بهذه المرحلة

- .gitignore
- backend/app/Services/DiscountEngineProtocol.php
- backend/app/Http/Controllers/Api/PosOrderController.php
- backend/app/Support/DomainErrorMessages.php
- backend/tests/Feature/DiscountAdHocRemovalTest.php، DiscountEngineIntentRoundTripTest.php، DiscountEngineTest.php، DiscountEngineCorrectionsTest.php، DiscountSecurityHardeningTest.php، DailyReportApiTest.php، TenantTaxAndValidationTest.php
- windows_application/lib/features/pos/controllers/pos_cubit.dart، models/discount_engine.dart، widgets/pos_cart_panel.dart، widgets/discount_engine_widgets.dart
- windows_application/lib/features/cafe_configuration/widgets/discount_manager_permissions.dart
- windows_application/test/features/pos/models/discount_engine_test.dart، widgets/configured_discount_only_test.dart
- docs/discount_settings_backend_contract.md، plans/discount_settings_automatic_combination_implementation_plan.md، windows_application/PROJECT_STATUS.md، وهذا التقرير

تغييرات Finance وخطة 1 الموجودة سابقًا في Git بقيت محفوظة، ولا تُنسب إلى هذه المرحلة.
