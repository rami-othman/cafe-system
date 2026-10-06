# قبول Plan 2 الحالي — 2026-10-05

**Plan 2 غير مغلقة بالكامل.** لم يحدث commit أو push أو deployment أو تفعيل Automatic عام. هذا التقرير يميز المشاهدة الحالية عن السجلات السابقة؛ checkboxes التنفيذ ليست بديلًا عن قبول المنصات والأدوار. D2-11 وD2-13–D2-16 وD2-19 تبقى مفتوحة.

## المصدر والتغييرات

قُرئ git status قبل العمل والتعليمات والخطة والعقد وتقارير 2026-10-03/04/05. حُفظت تعديلات المستخدم السابقة؛ لا reset أو clean أو نسخة HEAD أو ZIP أو نسخ مشروع إلى output. migrations التشغيل المحلية تمت مراجعتها بـ migrate:status فقط: foundation/runtime/protocol مطبقة، exit 0؛ لا migration أو تعديل بيانات تشغيل.

تجهيز القبول القديم لم يكن قابلًا لنشر منتجاته: أُضيف تصنيف وربط menu بالفرع، وvariant Large غير مستهدف، وCard نشط مرتبط بحساب 1030. التغييرات تخص fixture المحروسة والمستأجر `discount-plan2-live-20261004` فقط. تشخيص fixture يعرض stable code وأسماء الحقول، دون raw messages أو tokens.

ثلاثة عيوب كشفها التفاعل الحالي وأُصلحت:

1. إضافة item مع عدم وجود وردية كانت تُعدّل السلة المحلية قبل رفض إنشاء الطلب؛ الضغط التالي يزيد الكمية. PosCubit يتحقق الآن من الوردية قبل staging. regression يثبت cart فارغة، صفر create requests، وعدم دخول uncertain recovery بعد محاولتين. Web المصحح، Employee، العربية، 960×700: تكرار الضغط ثم إغلاق النافذة أبقى السلة صفرًا ([شجرة النتيجة](discount-plan2-20261005-final-no-shift-web-ar.yml)).
2. Print order في history كان placeholder يعرض Printing will be added later. أصبح يجلب receipt المحفوظة عبر OrdersCubit ويعرض ReceiptPreviewDialog، مع إعادة طباعة تستخدم orderId وbranchId من الطلب المفتوح، لا آخر دفع POS. فشل receipt قابل لإعادة المحاولة دون tender؛ الاستجابة المتأخرة تُهمل بعد إغلاق/إعادة فتح التفاصيل أو إغلاق Cubit. اختبارات regression لا تضعف assertions الدفع أو الصلاحيات.

Backend الحسابي والأمني وترتيب الأقفال لم يُعدّل في هذه المتابعة. بقي رفض ad_hoc الجديد والـPUT القديم والمراجعات غير المنفذة لجميع الأدوار، وقراءة التاريخ وإزالته وتسويته وreplay المكتمل. التدفقات الحالية أدناه تستخدم سياسات محفوظة؛ أدلة ad_hoc القديمة لا تُغلقها.

3. لقطة إيصال history العربية أظهرت العنوان العام DISCOUNT. ReceiptPreviewPaper يترجم الآن الاسم العام فقط عبر posDiscount، مع الحفاظ على الاسم المخصص التاريخي. اختبار الإيصال باللغتين نجح (2،exit 0) مع بقاء assertions الخصم والتسوية، والتحليل المحدد للملفات الثلاثة المصححة نجح (exit 0). أُصلحت أيضًا أقواس الشرط الجديدة؛ لم يُكرر التحليل الكامل، ونتيجته السابقة 30 info موثقة أدناه. أول محاولة regression الجديدة أخفقت في توقع حالة الأحرف الإنجليزية؛ العرض يستخدم uppercase أصلًا، صُحح توقع العرض وبقي اختبار العربية يمنع DISCOUNT. قبول العرض المرئي على artifact النهائي لم يُعد بعد هذا التصحيح، فلا تُغلق بوابته باختبار widget.

## البيئة وحدود الإثبات

Compose المشروع الموجود: `cafe-discount-acceptance-20261003`، accept-backend/accept-postgres. كانا متوقفين قبل البداية (backend exited 137، postgres exited 0). خدمات cafe_backend التشغيل وsuper-admin كانت تعمل ولم تُستخدم للقبول. استُخدمت volumes القائمة ولم تُحذف.

قبل الكتابة تحققنا فعليًا: APP_ENV=testing، DB_HOST=accept-postgres؛ القاعدة الافتراضية `cafe_discount_acceptance_testing`. آلية Automatic الموجودة استخدمت override الموجود، ثم أُعيد إثبات actual database=`cafe_system_618_testing` وقاعدة migration=`cafe_system_618_testing_migrations` عبر DiscountEngineEnvironment، exit 0. لا override في Flutter. capabilities الاختبارية: automaticPolicyCreationAvailable=true، automaticEnabled=true للتشغيل، engineReady=false؛ settings المحفوظة automaticEnabled=false. foundation CHECK بقي كما هو. الاختبارات الكاملة تعطل isolated_automatic لعملية الاختبار.

Windows: بُني Release النهائي؛ شُغلت نسخ Release سابقة في هذه المتابعة مستقلًا وظهرت شاشة الدخول العربية. sky.get_window_state رصد عناصر الدخول، لكن set_value يفشل بأن العنصر غير موجود في cached app state؛ type_text أوقفه رصد user input حتى بعد إعادة القراءة والتفعيل. المستخدم أكد أنه لا يستخدم النافذة. تكررت المشكلة بعد إعادة البناء. artifact النهائي بعد تصحيح العنوان لم يُقبل تفاعليًا. **قبول تسجيل الدخول والأدوار والعمليات على Windows غير مثبت؛ لا يُستبدل بDebug runner أو callbacks.**

Web: Chromium عبر Playwright CLI؛ الضغط والكتابة في عناصر التطبيق والمواضع المرئية. تفعيل Flutter semantics كان إجراء وصول فقط، لا استدعاء business callbacks. عرض العربية RTL عند 960×700 مرصود. بعض عناوين Orders القديمة بقيت إنجليزية؛ aggregate DISCOUNT صُحح لاحقًا واختُبر باللغتين، دون إعادة مشاهدة على artifact النهائي؛ قبول الترجمة الكاملة مفتوح. لا طابعة متاحة؛ preview وفشل الإعداد ليسا طباعة فعلية.

## السيناريوهات المرصودة وربطها بالبيانات

| السيناريو | المنصة/اللغة/الدور | النتيجة الحالية والأثر | الدليل |
|---|---|---|---|
| Code create/edit/reopen | Web EN Owner | policy 19 تستهدف Tea/Regular 29 فقط، لا Large 31؛ 25% ثم20%، priority250 ثم275؛ أعيد فتح edit وأثبتت detail الحفظ | [created](discount-plan2-20261005-code-created.json)، [edited](discount-plan2-20261005-code-edited.json) |
| Code→Automatic | Web EN Owner، testing-only | حفظ mode automatic وpriority275 وRegular فقط؛ codePresent=false | [conversion](discount-plan2-20261005-automatic-converted.json) |
| Automatic جديدة | Web EN Owner، testing-only | policy20 order percentage10، priority700، draft؛ لم يبق حقل coupon في العرض | [created](discount-plan2-20261005-automatic-created.json) |
| Discovery عند تغير السلة والسقف والتقريب | Web EN Owner | order6: Tea10 → discount2/tax0.64/total8.64 عند cap20%. إضافة Cake15 لنفس الطلب → Tea4 +Cake1، cap5، tax1.60،total21.60، allocations بأسطر منفصلة | [first item](discount-plan2-20261005-automatic-first-item.json)، [disjoint/cap](discount-plan2-20261005-automatic-disjoint-cap.json) |
| Suppression reason ثم undo | Web EN Owner | reason مطلوب، preview ثم confirm؛ suppression17 مع actor14؛ إعادة الاكتشاف اختارت18/19. Undo بتأكيد مراجعة أعاد17/18؛ suppressions فارغة لاحقًا | [suppression](discount-plan2-20261005-suppression.json)، [held after undo](discount-plan2-20261005-held-again.json) |
| hold→resume→hold | Web EN Owner | نفس order6؛ POST resume بين holdين، وبعد كل hold السلة فارغة | [held again](discount-plan2-20261005-held-again.json)، [نقل HTTP](../../output/discount-plan2-20261005-web-transport.txt) |
| quote قديمة تتطلب تأكيدًا جديدًا | Web EN Owner، سياسات محفوظة | settings version2→3 بعد quote؛ POST pay أعاد422، عُرضت رسالة مراجعة quote الجديدة، لم يُدفع حتى الضغط التالي | [النقل والهوية](../../output/discount-plan2-20261005-web-transport.txt) |
| Card واستجابة غير مؤكدة | Web EN Owner | paymentMethodId3؛ route.fetch نفذ Backend200 ثم إسقاط الاستجابة؛ استعاد العميل GET order/receipt. نفس idempotencyKey للرفض القديم والتأكيد الجديد؛ دفعة واحدة21.60، usage17/18 مرة واحدة، journal واحد debit=credit26.60 | [recovered](discount-plan2-20261005-card-recovered.json)، [النقل](../../output/discount-plan2-20261005-web-transport.txt) |
| cash الحقيقي | Web EN Owner | order7: Cake15،discount3،tax0.96,total12.96؛ cash محفوظ، إيصال Cash ظهر | [cash](discount-plan2-20261005-cash-paid.json)، [نقل جميع الدفعات](../../output/discount-plan2-20261005-web-transport-final.txt) |
| zero_balance بسياسة محفوظة | Web EN Owner | policy21 Manual100%، اختيار من Available Discounts ثمreview/confirm؛ order8 discount15/tax0/total0؛ payment zero_balance واحدة،usage واحد،journal واحد متوازن15/15 | [zero saved](discount-plan2-20261005-configured-zero-paid.json) |
| snapshot بعد تعديل السياسة وreplay | Backend fixture مكمل لقبول Web | policy17 value4→8 بعد الدفع؛ receipt6 unchanged؛ replay نفس الهوية يرد النتيجة المدفوعة؛ effects وreceipt مطابقان وpaymentCount1 | [snapshot/replay](discount-plan2-20261005-paid-snapshot-replay.json)، [بعد replay](discount-plan2-20261005-card-replayed.json) |
| تغيير المستخدم والجلسة | Web AR Owner→Manager→Employee | logout/login فعليان، كل POS جديدة بلا cart/quote قديم. Manager وEmployee capabilities fresh: canSuppressAutomatic=false؛ لا يُعد غياب زر وحده إثبات رفض API لجميع حالات الدور | [نقل السياقات](../../output/discount-plan2-20261005-web-transport-final.txt)، regression السياق |
| history/details ثم receipt | Web AR Employee،960×700، بعد تصحيح history | فتح DINE-IN ثمDETAILS للطلب8 ثمPrint order فتح receipt المحفوظة؛ policy21 وإجمالي0 وطريقة تسوية مترجمة | [شجرة العرض](discount-plan2-20261005-final-history-zero-ar.yml)، [لقطة](../../output/playwright/discount-plan2-20261005-final-history-zero-ar.png) |
| pre-bill/إعادة الطباعة | Web EN Owner ثم AR Employee | pre-bill API/print job قبل الدفع انتهى بفشل printer not configured؛ history receipt ثمPrint وRetry أعادا رسالة آمنة لفشل settings. لا إعادة pay؛ receipt/effects محفوظة بلا تغير بعد محاولة history الأولى | [effects](discount-plan2-20261005-history-print-failed.json)، [مقارنة](../../output/discount-plan2-20261005-history-effect-check.txt)، [requests](../../output/discount-plan2-20261005-final-history-requests.txt) |

كل طلب order transport المرصود أرسل X-Discount-Contract:2. pay requests تتضمن معرفات وسائل حقيقية، لا Cash/Card UI labels فقط. lost-response inject نفذ السيرفر أولًا ثم قطع الاستجابة؛ ليس mock نجاح. replay اللاحق supplemental API، لا يُوصف كتفاعل UI جديد.

منتجات Tea/Cake غير متتبعة مخزنيًا: sale_consumptions=[] وstock movements=0، وذلك متطابق مع العقد. **لا يغلق هذا قبول live inventory لمنتج stock-tracked.** الاختبارات الخلفية الحالية تشمل concurrency بمخزون ووصفة فعلية وworkers/barriers؛ ليست بديلًا عن التدفق المرئي المتبقي.

تجارب Code/Automatic/payment نُفذت قبل التصحيحات المحدودة؛ أُعيد no-shift وhistory على البناء المصحح. guard detailsVersion وتصحيح عنوان الخصم الأخيران متحققان regression؛ إعادة القبول الكامل لجميع السيناريوهات على آخر artifacts تبقى مفتوحة. حدثت مهلات read/list متفرقة بعد حفظ policy ناجح؛ persistence backend مؤكدة، UI timeout ليست pass.

## حالة كل D2

| المهمة | الحالة | دليل/فجوة |
|---|---|---|
| D2-01 | تنفيذ مغلق | العقد الحالي وتحديث صلاحية الإنشاء وإزالة وصف الإنشاء الحر |
| D2-02 | تنفيذ مغلق | migrate:status، DiscountSettingsFoundationTest الحالي |
| D2-03 | تنفيذ مغلق | DiscountSettingsApiTest الحالي؛ expectedVersion/الحقول الثمانية محفوظة |
| D2-04 | تنفيذ مغلق | foundation/protocol واختبارات historical/replay الحالية |
| D2-05 | تنفيذ مغلق | DiscountEngineTest/Corrections: selection/allocation/caps/rounding |
| D2-06 | تنفيذ مغلق | اختبارات engine وWeb discovery/suppression أعلاه |
| D2-07 | تنفيذ مغلق | IntentRoundTrip/AdHocRemoval ومراجعة suppress/undo/replay الحالية |
| D2-08 | تنفيذ مغلق | اختبارات quote/payment؛ Web cash/card/lost response/zero المحفوظة |
| D2-09 | تنفيذ مغلق | PostgreSQL concurrency الحالية ضمن70 اختبارًا، workers/barriers قائمة |
| D2-10 | تنفيذ مغلق | focused Flutter settings/routes/drafts؛ قبولها السابق محفوظ لا بديل عن matrix الحالية |
| D2-11 | مفتوحة قبولًا | Web Code/Automatic ثبت؛ omitted/clear API regression؛ Windows النهائي والأدوار/اللغتين على آخر source غير مغلقة |
| D2-12 | تنفيذ مغلق | focused Flutter help/reset/layout؛ reset محلي فقط |
| D2-13 | مفتوحة قبولًا | durable create/serial mutations/hold-resume-hold وno-shift مثبتة؛ customer attach/remove،branch،lost mutation/abandoned draft/shift-close live وإعادة matrix Windows متبقية |
| D2-14 | مفتوحة قبولًا | disjoint/cap/suppression/undo/وسيلتان/stale/recovery/zero ثبتت Web؛ single/after_items/strategies/policy limits live،reject unauthorized suppression live،inventoryTracked والمنصات/الأدوار متبقية |
| D2-15 | مفتوحة قبولًا | placeholder مصحح،history zero receipt Web مثبت؛ legacy live/pre-bill مرئي ناجح،snapshot UI بعد edit،final matrix والطباعة الفعلية غير مثبتة |
| D2-16 | مفتوحة قبولًا | header2/session/user/caps combinations Web مثبتة؛ legacy client live،branch/customer/session revocation quote/caps،عدم عرض نتائج متأخرة عبرالمصفوفة متبقية |
| D2-17 | تحقق موثق؛ ليس green شاملًا | نتائج الأوامر تُثبت أدناه؛ Flutter الكامل قبل التصحيح، وبعده regression مركزة؛ لا ادعاء full final أو قبول مرئي شامل |
| D2-18 | توثيق حالي | هذا التقرير والخطة والعقد وPROJECT_STATUS ومقترح rollout؛ لا إغلاق acceptance بواسطة التوثيق |
| D2-19 | مفتوحة | [SQL للمراجعة فقط](discount_plan2_rollout_review_2026-10-05.md)، لا migration تفعيل منفذة أو اختبار rollout؛ لا تفويض تفعيل |

## الأوامر والنتائج الفعلية

بوابات القبول المتبقية مصنفة صراحة:

| البوابة | الحالة | الدليل أو العائق الدقيق |
|---|---|---|
| D2-11 Web إنشاء/تعديل/reopen Code وAutomatic | Passed ضمن السيناريوهات أعلاه | pointer/text وقراءة السياسات؛ omitted/clear مثبتة باختبارات العقد، لا جلسة UI لكل تركيب |
| D2-11 مصفوفة Windows Release والأدوار واللغتين | Unverified | native automation تفشل في إدخال بيانات الدخول؛ البناء والفتح لا يثبتان السيناريو |
| D2-13 السلة الدائمة وhold/resume/hold | Passed ضمن Web Owner EN | order6 نفسه وتسلسل HTTP وحالة Backend |
| D2-13 العميل/الفرع/الاستجابة المفقودة لمutation/إغلاق الوردية | Unverified | لم تُنفذ جلسة UI لهذه الحالات؛ تحتاج fixture سياقات ووردية مخصصة ومطابقة آثارها، ولا يُستبدل ذلك بالاختبارات الآلية |
| D2-14 discovery/disjoint/cap/suppression/undo/cash/card/stale/recovery/zero | Passed ضمن Web Owner EN | السيناريوهات والآثار المحفوظة أعلاه |
| D2-14 single/after_items/استراتيجيات الاختيار/حدود السياسة/رفض suppression غير المصرح/live stock-tracked | Unverified | لم تُنفذ السيناريوهات المرئية؛ fixtures الحالية لا تقدم هذه المصفوفة. اختبار العقد الناجح لا يغلقها |
| D2-15 history receipt/zero وعدم دفع ثانٍ عند فشل print | Passed ضمن Web Employee AR | preview وrequests ومقارنة الآثار بعد أول محاولة؛ لا إثبات طباعة فعلي |
| D2-15 pre-bill مرئي ناجح/legacy UI/snapshot UI بعد تعديل السياسة | Unverified | pre-bill الفعلي انتهى بفشل إعداد الطابعة؛ الباقي لم يُشاهد، وsnapshot/replay إثبات Backend مكمل فقط |
| D2-15 عنوان DISCOUNT في الإيصال العربي | Failed بالمشاهدة ثم صُحح | regression EN/AR نجحت؛ إعادة مشاهدة artifact النهائي Unverified، لذا لا تُغلق بوابة اللغة بالكامل |
| D2-15 الطباعة الفعلية وإعادة الطباعة | Unverified | لا طابعة متاحة؛ preview أو print job أو bytes ليست مخرجات ورقية |
| D2-16 header2 وتغيير المستخدم/الجلسة | Passed ضمن Web المحدد | transport وlogout/login Owner/Manager/Employee مع cart جديدة وcapabilities fresh |
| D2-16 العميل القديم والفرع/العميل/سحب الصلاحية وتأخر الرد عبر المنصات | Unverified | لا جلسة قبول UI مرصودة لهذه المصفوفة؛ regression لا تقوم مقامها |
| D2-19 rollout | Unverified ومفتوحة عمدًا | اقتراح للمراجعة فقط؛ قبول غير مكتمل، ولا مراجعة مستقلة أو تفويض تفعيل |

Logs في output تحمل EXIT_CODE. الأوامر الكاملة والبيئة الأساسية:

```powershell
docker compose exec -T backend php artisan migrate:status
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e DB_DATABASE=cafe_system_618_testing accept-backend php tests/Fixtures/DiscountEngineEnvironment.php
docker compose -f windows_application/integration_test/fixtures/discount_acceptance.compose.yml exec -T -e APP_ENV=testing -e APP_LOCALE=ar -e DB_DATABASE=cafe_system_618_testing -e DB_DATABASE_MIGRATIONS_TESTING=cafe_system_618_testing_migrations -e DB_URL= -e SUPER_ADMIN_WEB_URL= -e DISCOUNT_ENGINE_ISOLATED_AUTOMATIC=false accept-backend php artisan test --do-not-cache-result --log-junit=/tmp/discount-plan2-20261005-full.xml
flutter build windows --release --dart-define=API_BASE_URL=http://localhost:18100/api/v1
flutter build web --release --dart-define=API_BASE_URL=http://localhost:18100/api/v1
flutter test --no-pub --concurrency=1 --reporter=json
flutter analyze --no-pub
git diff --check
```

| الفحص | النتيجة | exit | log |
|---|---|---|---|
| Backend focused،9 suites discounts/settings/variants/concurrency |70 passed،1203 assertions،651.63s|0|[focused Backend](../../output/discount-plan2-20261005-focused-backend.txt)|
| Flutter focused settings/discount/quote/lifecycle/receipt |184 passed|0|[focused Flutter](../../output/discount-plan2-20261005-focused-flutter.txt)|
| no-shift regression |19 passed|0|[regression](../../output/discount-plan2-20261005-shift-regression.txt)|
| history/payment/lifecycle regression |25 passed|0|[regression](../../output/discount-plan2-20261005-history-regression.txt)|
| Pint scoped7files |PASS|0|[Pint](../../output/discount-plan2-20261005-pint.txt)|
| fixture Python syntax |passed|0|[syntax](../../output/discount-plan2-20261005-fixture-syntax.txt)|
| Windows final Release |Built،100.2s؛ app.so حديث موثق SHA256|0|[build](../../output/discount-plan2-20261005-windows-final-build.txt)|
| Web final Release |Built،115.9s؛ main.dart.js حديث موثق SHA256|0|[build](../../output/discount-plan2-20261005-web-final-build.txt)|
| Backend full current |1103 passed،44 failed (32 failures+12 errors)،1 skipped؛11686 assertions؛3196.79s|2|[full](../../output/discount-plan2-20261005-full-backend.txt)،[JUnit منزوع تفاصيل الإخفاق](discount-plan2-20261005-full-backend.xml)|
| Flutter full قبل التصحيح |1682 passed،22 failed،0 skipped؛ لم يُكرر بعد تضييق النطاق،25 regression بعد التصحيح نجحت|1|[classification](discount-plan2-20261005-flutter-classification.json)|
| analysis الكامل قبل تصحيح العنوان الأخير |30 info،صفر errors/warnings؛29 سابقة وواحدة للأقواس أُصلحت لاحقًا|1|[analysis](../../output/discount-plan2-20261005-analysis.txt)|
| analysis بعد تصحيح العنوان/الأقواس،3 ملفات محددة |No issues found|0|[analysis](../../output/discount-plan2-20261005-receipt-label-analysis.txt)|
| receipt label regression،EN/AR |2 passed|0|[regression](../../output/discount-plan2-20261005-receipt-label-regression.txt)|
| format final،8 ملفات محددة |لا تغييرات مطلوبة|0|[format](../../output/discount-plan2-20261005-format.txt)|
| diff final |لا عيوب whitespace؛ أُزيل سطر EOF إضافي أدخله تحديث التوثيق بعد محاولة exit2|0|[diff](../../output/discount-plan2-20261005-diff-check.txt)|

تشغيل Flutter الكامل قبل التصحيح:1682passed/22failed/0skipped،exit1. جميع22 هوية إخفاق تطابق السجل التاريخي المحفوظ، ولا هوية جديدة في المقارنة؛ هذه مقارنة evidence saved وليست baseline HEAD جديدة. لم نُعد إنشاء HEAD أوZIP. أول test history جديد فشل timeout لأن fixture لم تُكمل getOrderDetail؛ أُصلحت تهيئة fixture دون تغيير assertion، ثم25اختبارًا نجحت. محاولة Pint الأولى بمسار غير موجود exit1، ثم المسارات الفعلية7files exit0. مهلات locators/refs قديمة أخطاء أدوات وليست product regressions.

## حالة الإنهاء

Backend الكامل الحالي انتهى exit 2، لا exit 1 ولا pass. مقارنة الـ44 هوية إخفاق مع XML التاريخي المحفوظ وجدت44 مطابقة، وصفر هويات جديدة وصفر حالات تاريخية اختفت ([التصنيف](discount-plan2-20261005-backend-classification.json)). هذه مقارنة identities فقط، لا إعادة HEAD ولا برهان أن السبب الداخلي لكل إخفاق مطابق. JUnit يحتفظ بالأعداد وأسماء الاختبارات وعلامات النتائج دون failure bodies أو captured streams. زمن JUnit3188.52s وزمن Artisan3196.79s يشيران إلى نفس التشغيل؛ لم يُكرر. إخفاقات العملاء/Finance/التقارير/التهيئة خارج التصحيحات المحدودة لم تُصلح هنا.

أُعيدت خدمة accept-backend إلى Compose الأساسي، وتُحقق قراءةً فقط من APP_ENV=testing وhost=accept-postgres وactualDatabase=cafe_discount_acceptance_testing وisolatedAutomatic=false؛ engineReady/automaticPolicyCreationAvailable/automaticEnabled كلهاfalse، exit0 ([هوية الاستعادة](../../output/discount-plan2-20261005-restored-environment.json)). ثم أُوقفت accept-backend (exit137) وaccept-postgres (exit0)، مثل حالتيهما قبل البدء، بأمر stop exit0. backend container أُعيد إنشاؤه، ولم تُحذف volumes accept-data/storage/cache أو external vendor. خدمات cafe_backend/backend/postgres/pgadmin/super-admin بقيت Up دون restart ([الحالة النهائية](../../output/discount-plan2-20261005-services-final.txt)). خادم Web المؤقت أُوقف، ومتصفح القبول أُغلق. بيانات التشغيل لم تُكتب؛ fixtures وقواعد اختبار الخصومات المعزولة تغيرت واستخدمت full-suite refresh، لذلك أدلة الطلبات المحفوظة أعلاه تمثل لحظة السيناريو وليست وعدًا ببقائها بعد الاختبارات الكاملة.

تعديلات Git السابقة محفوظة؛ لم يحدث commit أو push أو reset أو clean أو deployment. حالة worktree النهائية محفوظة في [git status](../../output/discount-plan2-20261005-git-final.txt). تبقى بوابات القبول المفتوحة أعلاه كما هي؛ التفعيل العام غير جاهز للموافقة. المقترح النهائي للتفعيل ومخاطره محدد في وثيقة D2-19، لكنه غير مطبق وغير مختبر كتفعيل إلى حين استكمال القبول.

استكمال التوثيق بعد الانقطاع — 2026-10-06: أُزيل فقط سطر EOF إضافي أدخله تحديث PROJECT_STATUS، وgit diff --check النهائي exit0؛ لا إعادة اختبارات أو builds. إعادة قراءة docker ps exit0 وجدت accept-backend/accept-postgres متوقفين منذ15ساعة، كما تُركا. خدمات التشغيل الأربع كانت Up عند استعادة القبول بتاريخ2026-10-05، لكن الفحص الجديد وجد postgres exited0 منذ14دقيقة وbackend/super-admin/pgadmin exited137 منذ14–15دقيقة. لم تُصدر هذه المتابعة أوامر إيقاف أو تشغيل لتلك الخدمات، ولا يُفترض سبب توقفها؛ بقيت متوقفة دون تغيير. هذا يميز حالة الاستعادة المثبتة من الحالة المرصودة بعد الانقطاع.

أصغر خطوة تالية: استعادة إدخال pointer/text في Windows Release المستقل لإكمال مصفوفة الأدوار واللغتين، وتجهيز fixture الفرع/العميل/الوردية وحالات التركيب المتبقية في البيئة المعزولة نفسها؛ ثم مشاهدة الإيصال المصحح والطباعة على طابعة فعلية. تُغلق كل حالة بدليلها، قبل إعداد واختبار migration التفعيل additive والمراجعة المستقلة والتفويض المنفصل لـD2-19.
