# خطة 2: تبويب إعدادات الخصومات والمحرك التلقائي والجمع

متابعة المصدر والقبول — 2026-10-05: [تقرير القبول العربي الحالي](../docs/verification/discount_plan2_acceptance_2026-10-05_ar.md) هو مرجع الحالات المرصودة في هذه المتابعة. ثبت Web Code targeted create/edit/reopen، وإنشاء/تحويل Automatic testing-only، وdisjoint/cap/suppression/undo، وcash/card وquote قديمة وتعافي دفعة بسياسات محفوظة، والتسوية الصفرية بسياسة Manual محفوظة. كشف التفاعل عيب staging دون وردية وplaceholder طباعة history وأُصلحا. Windows Release بُني وشُغّل مستقلًا لكن أداة الإدخال لم تُثبت login/العمليات؛ لا إغلاق لمصفوفته أو للطباعة الفعلية. D2-11 وD2-13–D2-16 وD2-19 مفتوحة. [مقترح D2-19](../docs/verification/discount_plan2_rollout_review_2026-10-05.md) وثيقة غير مطبقة، وليست migration تفعيل مختبرة.

التاريخ: 2026-10-01 — Asia/Damascus.

تعديل متطلبات المنتج — 2026-10-05: أُلغي إنشاء الخصم الحر من POS لجميع الأدوار، بما فيه إدخال مبلغ/نسبة وطلبات `ad_hoc` الجديدة ومسار PUT القديم. التطبيق اليدوي يعني اختيار سياسة Manual محفوظة ومؤهلة، أو إدخال Code. مراجع الخصم الحر القديمة غير المنفذة لا تُطبّق؛ الخصومات المحفوظة والتاريخية تبقى قابلة للقراءة والتسوية والإزالة الصريحة، والعمليات المكتملة تبقى قابلة لإعادة قراءة نتيجتها. أي وصف لاحق لـad-hoc في التصميم الأصلي يخص التوافق مع البيانات القديمة فقط. بقيت D2-11 وD2-13–D2-16 وD2-19 مفتوحة؛ لم يُفعّل Automatic. تقرير هذه المرحلة: [إزالة الخصم الحر ومراجعة المتبقي](../docs/verification/discount_ad_hoc_removal_2026-10-05.md).

تحديث مرحلة Flutter والتكامل — 2026-10-04: نُفذت واجهات D2-10–D2-16 واختباراتها المركزة، مع بقاء بوابات القبول المحددة أدناه مفتوحة. أُغلق فشل Windows `D2_GENERIC` بعد تتبّع HTTP/DTO/Cubit إلى assertion في اختبار Dio وتصحيحه دون تغيير حسابات الدفع. قبول Windows المترجم EN/AR نجح، وقبول Web العربي أثبت إعادة تأكيد quote المتغير، الدفع والإيصال والرصيد الصفري. تصحيح Backend الوحيد اللاحق هو تثبيت ترتيب مفاتيح intent عند fingerprint بعد JSONB؛ لا تغيير في الحسابات أو lock ordering. لم تُعد الـ suites الكاملة أو مقارنة HEAD بعد طلب المستخدم. [الدليل والنتائج والفجوات](../docs/verification/discount_settings_flutter_2026-10-04.md). `engineReady=false` والتفعيل العام مغلقان؛ الخطة ليست مكتملة.

تصحيحات backend محدودة — 2026-10-04: أُغلقت ثغرة تجاوز السقف العام بالعميل القديم، وتوزيع fixed/per_unit وتداخل الأسطر، والتقريب المبكر لمكونات Bundle. أُعيد إنتاج دورة انتظار PostgreSQL بين أول quote لطلب غير مربوط بالمستودع ودفع طلب مربوط بمنتج stock-tracked ووصفة منشورة فعلية؛ أصبح قفل المحرك يسبق ربط المستودع في المسارين. الأدلة والأوامر النهائية في `docs/verification/discount_settings_corrections_2026-10-04.md`. تبقى `engineReady=false`، وتفعيل Automatic العام مغلقًا، وD2-11 backend-partial؛ لا تغيير في مهام Flutter أو اكتمال الخطة.

الحالة الحالية — 2026-10-03: foundations D2-01–D2-04 محفوظة ومتحققة. نُفذت مرحلة backend D2-05–D2-09 ومقدمات D2-11 الخلفية بتفويض مستقل؛ D2-11 تبقى backend-partial. إعادة التحقق النهائية: 269 اختباراً ناجحاً، exit 0؛ الـsuite الكامل: 1082 ناجحاً و44 فاشلاً وواحد skipped، exit 1، والإخفاقات الـ44 أعادها HEAD. engineReady=false وAutomatic غير متاحة علناً وخطة 2 ليست مكتملة. [العقد وتسليم Flutter](../docs/discount_settings_backend_contract.md)، [تحقق المحرك والقيود](../docs/verification/discount_settings_engine_2026-10-03.md)، و[تحقق foundations](../docs/verification/discount_settings_foundation_2026-10-03.md).

الحالة عند إعداد الخطة: خطة تنفيذ مقترحة مبنية على النقاش والمصدر الحالي. لم يبدأ التنفيذ حينها. القيم الافتراضية وقواعد التداخل كانت توصيات منتج صريحة للتنفيذ، وليست ميزات موجودة عند إعداد الخطة.

المتطلب السابق: [خطة إنشاء وتعديل الخصومات واستهداف الـ Variants](discount_create_edit_variant_implementation_plan.md).

## 1. ترتيب البدء وملكية العمل

**نفّذ خطة 1 أولًا.** ثم نفّذ هذه الخطة backend-first، وفعّل الميزات بعد اكتمال POS والدفع والإيصالات واختبارات التزامن.

هذه الخطة ليست UI tab فقط. تشمل settings authority، اختيار وتوزيع الخصومات، usage، payment quote، synchronization، عرض التفاصيل، والـ compatibility.

| العمل | المالك |
|---|---|
| المنتجات والـ Variants، matcher، fixed basis | خطة 1؛ يُعاد استخدامها هنا |
| Automatic وpriority في Create/Edit | هذه الخطة، بعد جاهزية backend engine |
| قواعد المقهى والصلاحيات والتبويب | هذه الخطة |
| POS/payment/receipt/usage متعددة الخصومات | هذه الخطة |
| overlap على نفس السطر، branch overrides | مؤجل، لا interactive placeholders |

## 2. الحقائق الحالية المؤثرة

- CafeConfigurationPolicy العامة Owner-only؛ Printing لديه استثناء Owner/Manager.
- Flutter navigation والـ router يسمحان للمدير حاليًا بتبويب Printing فقط.
- DiscountAccess له أربع صلاحيات تشمل manage/apply، وبعض seed defaults تمنحها للموظفين أيضًا. لا تستخدم discounts.manage وحدها لفتح settings مالية للمقهى.
- DiscountController يقبل Manual/Code فقط، وavailable يُرجع manual دون أكواد.
- apply وmanual override يحذفان كل order_discounts السابقة، وremove يحذف الجميع.
- PosOrderController يرسل discount واحدًا، وFlutter يحتفظ بـ AppliedDiscount واحد.
- discount_usages unique(order_id)، وconsumeUsage يتوقف إذا وجد أي usage للطلب.
- PosPricingService يجمع الصفوف، لكنه ليس محرك combination.
- published-menu cart محلي قبل lookup/Hold/payment؛ إجمالي تلقائي مباشر يحتاج server synchronization مبكرًا.
- payment summary الحالية تقرأ المبلغ المحفوظ، ولا تقدم quote جديدًا مرتبطًا بطريقة الدفع/نسخة الخصومات.
- ReceiptController يعرض discountTotal فقط، دون breakdown.

أعد التحقق من الملفات الحالية قبل التنفيذ. لا تعتبر schema أو migration status أو test counts القديمة دليل تشغيل.

| مسار المصدر | نقطة التعديل |
|---|---|
| `backend/app/Services/CafeConfigurationPolicy.php` و`backend/app/Domain/Discount/DiscountAccess.php` | صلاحية settings المحدودة، دون توسيع صلاحيات بقية configuration |
| `backend/app/Services/DefaultTenantRoleService.php` و`backend/routes/api.php` | grants المقصودة، API الإدارة، preview/quote/operational routes |
| `backend/app/Http/Controllers/Api/DiscountController.php` | Automatic/priority، explicit application، التوافق وحماية coupon codes |
| `backend/app/Services/DiscountEligibilityService.php` و`backend/app/Services/PosPricingService.php` | resolution، exact totals، usage، matcher خطة 1 |
| `backend/app/Http/Controllers/Api/PosOrderController.php` و`PaymentController.php` | discounts[]، create/mutations، quote guard، settlement |
| `backend/app/Http/Controllers/Api/ReceiptController.php` و`RefundController.php` | breakdown، إثبات ثبات amount refunds |
| `windows_application/lib/features/cafe_configuration/` و`lib/app/app_router.dart` و`lib/core/services/service_locator.dart` | التبويب، Cubit/repository/model، navigation، DI |
| `windows_application/lib/features/discounts/` و`lib/features/pos/` و`lib/features/printer/` | form integration، queued cart، quote/UI، receipt rendering |

الـ classes والـ endpoints الجديدة المسماة لاحقًا مقترحات تنفيذ؛ لا توجد الآن ولا يستدعيها العميل قبل نشر عقدها.

## 3. إعدادات V1 الافتراضية والعقد المقترح

الإعدادات tenant-wide. لا branch overrides في V1. الفرع وقناة البيع يبقيان شروطًا للسياسة نفسها.

| الحقل المقترح | الخيارات | الافتراضي |
|---|---|---|
| automaticEnabled | boolean | false |
| selectionStrategy | highest_saving / lowest_saving / priority | highest_saving |
| combinationMode | single / disjoint_items | single |
| orderDiscountBehavior | exclusive / after_items | exclusive |
| couponBehavior | exclusive / follow_combination_rules | exclusive |
| manualBehavior | exclusive / follow_combination_rules | exclusive |
| maximumTotalDiscountPercent | null أو نسبة أكبر من 0 وحتى 100 | null |
| allowAutomaticSuppression | boolean، Owner/Manager فقط مع reason | true |
| version | عدد increasing، read-only | نسخة ابتدائية |

- لا يسمح بـ after_items إلا مع disjoint_items؛ UI يخفي الخيار غير المناسب، والباك إند يرفض combinations غير الصالحة.
- follow_combination_rules لا يسمح بكسر single أو exclusive order rule.
- السقف نسبة لتجنب غموض العملات عبر الفروع. السقف النقدي والعملات المتعددة للإعدادات مؤجلان؛ عملة الطلب الحالية تبقى المرجع للعرض.
- null يعني لا سقف تجاري إضافي؛ دائمًا لا يمكن تجاوز المبلغ المؤهل أو subtotal.
- lowest_saving يقارن saving الموجب الفعلي، وليس value الخام؛ لا يجعل zero policy تفوز وتستهلك استخدامًا تلقائيًا.
- priority: عدد صحيح 0..1000 في السياسة؛ 0 الافتراضي، الأكبر أولًا. التعادل يحسم بـ discount ID تصاعديًا.
- الأعلى/الأقل بعد الكمية والأهداف وpolicy cap والميزانية المتبقية من global cap، وليس بمقارنة النسب مباشرة.
- جميع خيارات overlap المتتابع على نفس السطر مؤجلة. لا enum قابل للكتابة لميزة غير منفذة.

يظل التلقائي false للمقاهي الحالية والجديدة حتى التفعيل الصريح. تغيير combinationMode وحده لا ينشئ سياسات تلقائية.

## 4. الصلاحيات وواجهة الإعدادات

- أضف صلاحية مستقلة `discounts.settings.manage`، مع فحص role صريح Owner/Manager. Employee وfactory_manager وSuper Admin token لا يحصلون على سلطة tenant settings بهذا المسار.
- Owner مسموح ضمن حدود tenant؛ Manager يبدأ مخولًا لهذا التبويب بناءً على طلب المنتج، ويمكن للمالك سحب grant ضمن آلية role permissions الحالية.
- عند توسيع permission catalog، عدّل defaults عمدًا: لا تضف الصلاحية الجديدة إلى loop يمنح كل Discount permissions للـ Employee.
- Owner-only role permission administration تبقى كما هي؛ لا تعطي المدير تعديل grants.
- حدّث navigation/router/sidebar/session capability لفتح هذا التبويب فقط للمدير المخول؛ لا توسع assertCanManage العامة لبقية Profile/Tax/Branches.
- مراجعة branch-access middleware: settings tenant-wide ليست branch override، أما عمليات الطلب فتستخدم shared branch access.

التبويب: ثلاث مجموعات «التطبيق التلقائي»، «الجمع والتعارض»، «الحدود والتحكم» مع ملخص وصفي وشرح لكل اختيار.

- loading، forbidden، retry، validation، save conflict، unsaved navigation، saving، saved.
- مثال حسابي تعليمي ثابت البيانات بالـ backend preview أو نص أمثلة موثقة؛ لا calculator مالي مستقل في Flutter ولا quote صالح للدفع.
- Reset to defaults يعيد draft فقط؛ Save يحفظ ذريًا ويكتب audit، دون حوار approval عام إضافي.
- النص يوضح أن الإعدادات تشمل كل الفروع وأن الطلبات غير المدفوعة تستخدم النسخة الجديدة عند إعادة التسعير، والمدفوعة ثابتة.
- EN/AR، RTL/LTR، desktop shell الحالي، responsive Windows/Web.

## 5. التخزين وAPI الإعدادات

جدول مثل `tenant_discount_settings` بصف واحد لكل tenant وunique(tenant_id)، typed fields، version، updated_by والتواريخ. defaults واحدة في backend authority وليست نسخًا متفرقة في Flutter.

- GET/PUT مقترحان: `/api/v1/cafe-configuration/discount-settings` مع صلاحية مخصصة.
- GET يستخدم defaults الموثقة عند غياب الصف. save يتطلب expectedVersion، ويرجع conflict عند نسخة قديمة؛ إنشاء الصف الأول محمي بالـ unique/retry المحدد.
- version change وaudit before/after في transaction واحدة، باستخدام OperationalAuditService القائم.
- audit يسجل actor والوقت دون coupon codes أو بيانات غير لازمة.
- لا تغيير جماعي للفواتير عند save. الطلب غير المدفوع يعاد تقييمه عند next mutation/resume/quote؛ payment يمنع stale quote.
- operational clients يحصلون فقط على capability/flags اللازمة، مثل automaticEnabled وengineReady وsettingsVersion؛ لا تتطلب POS تحميل endpoint الإدارة ولا كشف إعدادات إدارية كاملة للموظف.
- engineReady يدل على عقد runtime متكامل في backend؛ ليس switch يستطيع المقهى تفعيله لتجاوز rollout gates.

## 6. إضافة Automatic إلى إنشاء/تعديل السياسة

بعد اكتمال المحرك الخلفي:

- دعم applicationMode=automatic مع percentage/fixed وبقية scopes الحالية.
- لا code لسياسة automatic؛ عند تغيير code -> automatic يلزم clear صريح.
- إضافة priority في persistence/detail/DTO/full-policy save، مع حماية omitted priority لعملاء قدامى عند update.
- hide/disable إنشاء أو تحويل السياسة إلى Automatic عندما automaticPolicyCreationAvailable=false، مستقلًا عن engineReady؛ لا تخمين capability من version number.
- تفعيل/تعطيل automaticEnabled لا يحذف السياسات التلقائية؛ تظهر في الإدارة كغير مطبقة تلقائيًا حاليًا.
- لا تُظهر سياسات automatic كعناصر يطبقها الموظف يدويًا، ولا تُكشف الأكواد من available.
- policy detail / list / preview يشرح mode وpriority وvariants بوضوح.
- automatic zero-value لا يُطبق ولا يستهلك usage. configured zero في Manual/Code يحافظ على سلوكه الحالي واختباراته.

## 7. محرك واحد للأهلية والاختيار والتوزيع

وسع طبقة الخدمات الحالية بخدمة orchestration محدودة مثل DiscountResolutionService. DiscountEligibilityService وmatcher خطة 1 يظلان authority لشروط السياسة؛ لا تعيد كتابة الشروط في settings controller أو Flutter.

مدخلات المحرك: tenant context، persisted Order/items، authoritative branch timezone، customer، channel، optional resolved paymentMethodId، settings version، explicit discount intent، suppression state.

مخرجاته: selected policies، positive exact amounts، allocations للأسطر، source، reasons/codes، provisional tender state، calculation fingerprint، totals.

### 7.1 single

- دون explicit selection: اختر automatic candidate موجبًا واحدًا وفق strategy.
- وجود code/manual explicit intent يحكم وفق exclusivity ولا يُستبدل تلقائيًا بعرض أعلى دون فعل واضح من المستخدم.
- manual/configured apply الحالي يستمر يدويًا وserver-authoritative، مع preview للانتقال قبل التنفيذ في الواجهة الجديدة.

### 7.2 disjoint_items

لتجنب حسابات غامضة مع fixed/per_order والـ caps، عرّف خوارزمية V1 بأنها **اختيار تدريجي ثابت الترتيب**، وليس وعدًا بإيجاد أفضل مجموعة رياضيًا:

1. حجز الأسطر التابعة للـ explicit item-scoped policy إذا كان الجمع مسموحًا.
2. احتساب saving لكل automatic item candidate على أسطره المؤهلة غير المحجوزة وميزانية السقف المتبقية.
3. اختيار candidate الأعلى/الأقل/الأولوية حسب setting؛ tie by ID.
4. تطبيقه مرة واحدة وتوزيع مبلغه وحجز الأسطر ذات allocation موجبة، ثم إعادة تقييم المرشحين الباقين.
5. عدم تطبيق نفس policy مرة ثانية على الطلب؛ عدد الأسطر أو الوحدات لا يضاعف usage.

قد تغطي السياسة الواحدة عدة أسطر. per_order يطبق مرة واحدة على المجموعة المؤهلة المتبقية، لا لكل سطر أو Variant. المثال والـ help text يشرحان أن «الأعلى» يعني أفضل توفير في كل خطوة، وليس optimization عالميًا.

- category policies item-scoped وتشارك في نفس قواعد non-overlap.
- bundle يبقى exclusive في V1 لتجنب تغيير semantics الخاصة بحزمة واحدة وquantities الحالية؛ لا partial bundle allocation في هذا العمل.
- orderDiscountBehavior=exclusive: اختر إما نتيجة item promotions أو policy order-wide واحدة، بالمقارنة على actual total saving؛ explicit exclusive intent يبقى حاكمًا.
- المقارنة بين مجموعة item promotions وorder candidate pure preview قبل persistence؛ لا تحفظ مجموعة ثم تحذفها لتجربة البديل. في priority تعتمد رتبة المجموعة على أعلى priority مشارك ثم أصغر ID؛ في التعادل المالي يُفضل الخيار الأقل عددًا من السياسات ثم IDs المرتبة.
- وجود explicit item intent مع follow_combination_rules يمنع order-exclusive candidate من إزاحته تلقائيًا؛ المقارنة بين البدائل التلقائية تعمل فقط دون intent يتعارض معها.
- orderDiscountBehavior=after_items: بعد item promotions، اختر order policy واحدة على المبلغ المتبقي. eligibility minimum spend يظل original subtotal. هذا هو التداخل الوحيد المسموح في V1، ولا يفتح عدة item promotions على نفس السطر.
- إذا كانت سياسة Code أو Manual محفوظة order-scoped هي الطلب الصريح، تُطبق في order stage عندما يسمح follow_combination_rules + after_items؛ وإلا فهي حصرية.
- coupon/manual policy item-scoped تتبع non-overlap عند السماح بالجمع. intent تاريخي محفوظ من ad_hoc يبقى order-scoped للقراءة والتسوية فقط، ولا يُنشأ جديد.
- explicit intent جديد واحد في V1 (code أو configured-manual)، دون عدة أكواد أو عدة manual intents؛ ad_hoc القديم للتوافق التاريخي فقط.

### 7.3 السقوف والدقة

- الحساب exact decimal/minor units فقط. quantity scale وrounding يتبعان خطة 1.
- policy cap أولًا، ثم ميزانية السقف العام النسبية من original pre-discount subtotal؛ round budget إلى خانتين HALF_UP.
- طبّق global budget حسب stage/ranking المحدد؛ لا توزيع غامض بعد الحساب يغير ترتيب الفوز.
- وزع fixed/per_order والسياسات capped proportionally على الأسطر المؤهلة باستخدام largest remainder، tie by order item ID، بحيث sum allocations = policy amount بالضبط.
- بعد_items allocations تستخدم residual line balances؛ احفظ stage لتفسير المبلغ.
- لا amount سالب، لا line allocation أكبر من المتبقي، ولا aggregate يتجاوز subtotal.
- money precision محدودة ومسجلة في snapshots، والـ tax الحالي بعد مجموع الخصومات دون tax redesign.

## 8. Code/Manual preview والإزالة والاستبعاد

أضف preview/apply protocol تابعًا لمحرك الخصومات، مثل POST `/orders/{order}/discounts/preview` للـ persisted order. لا يقبل client totals.

- preview يرجع قبل/بعد، الخصومات التي ستزال وتضاف، settings/order fingerprint، وreview token مرتبط بالـ intent.
- apply يتحقق من token/fingerprint؛ تغير السلة أو السياسة أو الإعدادات يتطلب preview جديدًا.
- لا تستبدل automatic policies بصمت عند code أقل توفيرًا؛ اعرض المبلغ النهائي وإجراء Apply للمراجعة.
- إزالة explicit intent تعيد discovery تلقائيًا حسب الإعدادات الحالية.
- استبعاد automatic policy محفوظ لكل order+discount+tenant، مع reason/actor/audit. Owner/Manager فقط وصلاحية suppression، وتفعل allowAutomaticSuppression.
- يعود الخصم عند undo exclusion صريح فقط، ولا يعود بسبب quantity mutation. لا ينتقل الاستبعاد لطلب جديد ولا لفاتورة أخرى.
- exclusion لا يتجاوز قواعد payment أو history؛ فقط draft/held unpaid.
- إزالة policy من الصفوف وحدها ليست suppression. legacy delete-all لا يُستخدم في UI الجديدة.
- التغييرات والإزالة لها operation identity/replay؛ في response غير مؤكدة اقرأ الحالة مرة قبل إعادة mutation. لا retry أعمى.

## 9. تعديلات schema الاستخدام والـ snapshots

- غيّر unique(order_id) إلى unique(tenant_id, order_id, discount_id)، مع فحص بيانات الاختبار/نسخة ترقية وconstraints دون حذف التاريخ.
- consumeUsage يتعامل مع كل policy على حدة، ويستعمل نفس composite identity. استعمال policy على عدة أسطر يسجل usage واحدًا.
- استهلاك usage بعد نجاح payment فقط؛ تلقائي لا يحجز usage عند preview أو cart mutation.
- snapshots الجديدة تستخدم source (automatic/configured_manual/code) وstage وsettingsVersion/policy calculation metadata؛ ad_hoc للقراءة التاريخية فقط، دون إنشاء جديد أو backfill يعيد حساب المدفوع.
- جدول allocations يربط order_discount بسطر الطلب ويحفظ مبلغ التوزيع. monetary rows authoritative، ومجموعها يساوي discount_amount.
- snapshot سياسة يحفظ اسمها ونوعها وقيمتها وأساس fixed ونمط أهدافها عند الدفع؛ edits اللاحقة لا تعيد كتابته.
- suppression state مستقل عن applied snapshot. حذف policy الحالي soft لا يمحو snapshots/usages السابقة.
- legacy paid discounts دون allocations تُقرأ كمبالغ إجمالية قديمة؛ لا اختلاق توزيع تاريخي.
- amount-based refund الحالي يظل على settlement التاريخي؛ لا item restock أو refund engine جديد. لا إعادة usage عند refund دون ميزة لاحقة محددة.
- metrics يجب أن يجمع المبالغ الفعلية لكل policy مرة، لا join يكررها بعدد allocations.

## 10. الدفع والتزامن وتغير السعر

quote جديد server-authoritative مرتبط بـ order revision/items، policy revisions، settings version، customer/channel، tender context، allocations، totals، والوقت المرجعي للصلاحية.

- جهّز quote عبر POST مخصص مثل `/orders/{order}/payment-quote`؛ GET summary يبقى read-compatible ولا يصبح mutation صامتًا.
- قبل اختيار tender: لا تطبق automatic payment-method-restricted candidate. اظهر أن المبلغ قابل للتحديث عند اختيار الطريقة؛ code/manual restricted يحتفظ بسلوك التحقق الحالي مع pending tender indication.
- عند اختيار الطريقة، resolve payment method الفعلي أولًا، ثم calculate quote؛ لا اعتماد على free-text وحده.
- no-tender/zero-balance لا يسمح لسياسة tender-restricted بإنشاء مبلغ صفري عبر تجاوز شرط طريقة الدفع. اختبر هذا المسار صراحة.
- pay يحتاج confirmed quote identity من العميل الجديد، ثم locks/revalidation وfingerprint مقارنة داخل transaction.
- إذا تغير الخصم أو المبلغ، حتى لو أصبح أقل أو amountReceived يغطيه، يرجع `ORDER_TOTAL_CHANGED`/code مكافئ ويُلزم quote جديدًا دون إنشاء payment أو usage أو Finance posting.
- expiry أو exhausted usage في automatic يعيد resolution؛ اختلاف النتيجة يمنع الدفع حتى المراجعة. code/manual invalid يرجع eligibility failure واضحًا.
- idempotent completed-payment replay يُفحص قبل quote revalidation؛ ضياع response لا يعيد الدفع ولا يتأثر بإعدادات تغيرت لاحقًا.
- ترتيب الأقفال الحالي موثق في العقد: بعد قفل الطلب، قفل محرك tenant يسبق ربط المستودع في quote والدفع، ثم أقفال الوردية والمالية والسياسات/usage حسب المصدر. تصحيح 2026-10-04 ألغى الوصف التصميمي القديم الذي وضع قفل المحرك بعد warehouse. تعديل settings لا يقفل orders؛ الدليل الحالي يستخدم PostgreSQL workers مستقلة وbarriers مرصودة.
- config update لا يقفل كل orders؛ تمنع optimistic version/fingerprint conflicts البيع بسعر لم يراجعه المستخدم.
- اكتشاف policies جديدة وتعديلها لا يفلت من quote fingerprint؛ استخدم revision/set identity يشمل candidate set وقواعد الجدولة، لا selected IDs فقط.

## 11. POS المبكر والعرض والـ compatibility

- عندما automaticEnabled=true أو يحتاج الطلب multi-discount review، persist cart عند أول item صالح باستخدام create idempotency الموجود.
- mutation queue الحالية تبقى المرجع؛ لا مسارات متوازية تضاعف create/add. pinned publishedMenuVersion والفرع والـ shift والـ customer محفوظة.
- عند عدم تفعيل التلقائي ولا وجود حاجة جديدة، حافظ على مسار local-cart القائم حيث يمكن ذلك.
- loading/sync تمنع تأكيد الدفع بمبلغ قديم. uncertain create يحافظ على identity والسلة ويقرأ/يتحقق قبل retry.
- clear cart/cancel يغلق draft صراحة؛ لا تضف job يحذف unpaid orders بصمت. أظهر الطلبات المتروكة في مسار الطلبات الحالي، مع اختبار أثر shift close.
- clear/hold/resume/branch change/customer mutation تحافظ على context ولا تستبدل cart غير فارغة.
- لا offline calculation للتلقائي أو الجمع؛ عند انقطاع الاتصال، اعرض unavailable ولا مبلغًا مخمنًا قابلًا للدفع.
- أضف `discounts[]` إلى order response مع id/source/name/type/value/amount/allocations والـ total/version.
- احتفظ بالحقول القديمة additive: discount legacy يمكنه تمثيل policy واحدة فقط. عند multiple، قدم مؤشر requiresDiscountBreakdown/contract capability؛ لا تقدم أول صف على أنه كل الخصم.
- Flutter BackendOrder/PosState ينتقلان إلى قائمة applied discounts مع aggregate backend total؛ local fallback القديم يبقى للlegacy فقط.
- العميل القديم لا يسمح له بالمبيعات automatic/multi التي لا يمكنه عرضها ومراجعة quote لها: capability/version enforcement قبل mutation/pay مع localized update-required. manual single القديمة تستمر حين automatic off والعقد متوافق.
- receipt API/models/renderer وPOS pre-bill/order detail/history تعرض breakdown دون recalculation؛ لا تغير printer transport ولا تربط printing failure بإعادة payment.
- أخطاء configuration/eligibility/quote/replay تُعرض عبر stable recognized codes وترجمة EN/AR مع generic fallback آمن؛ لا raw backend message أو exception أو stack trace في Flutter.
- mixed-version rollout: backend/schema أولًا، client supporting breakdown/quote ثانيًا، ثم engineReady/activation. لا تشغيل automatic أثناء وجود عملاء غير متوافقين بلا server guard.

## 12. مهام التنفيذ بالاعتماد

### P2-A — foundations، بعد إغلاق خطة 1

- [x] D2-01: إعادة مراجعة المصدر وتثبيت defaults/ranking/combination/quote compatibility في وثائق العقد.
- [x] D2-02: settings schema/version/audit وpermission محددة مع grant Manager وعدم grant Employee.
- [x] D2-03: settings GET/PUT واختبارات tenant/role/conflict/defaults.
- [x] D2-04: schema usage composite identity وsnapshots/allocations/suppression مع migration compatibility.

### P2-B — المحرك والدفع أولًا

- [x] D2-05: matcher/eligibility خطة 1 + exact scoring/selection/allocation/caps مع tests للأمثلة.
- [x] D2-06: automatic discovery، explicit intent/exclusivity، category/order/bundle boundaries، وsuppression.
- [x] D2-07: preview/apply/remove/undo APIs مع fingerprint وmutation replay وعدم expose codes.
- [x] D2-08: payment quote والتندر وstale quote guard، use consumption لكل policy، Finance/metrics/refund regression.
- [x] D2-09: PostgreSQL concurrency بالـ independent workers/barriers قبل إتاحة engineReady. تحققت 10 حالات محرك، بما فيها سباق المستودع مع المخزون الفعلي، و11 حالة التزامن المالي الحالية؛ التفعيل يبقى مغلقاً.

### P2-C — الإدارة وCreate/Edit

- [x] D2-10: tab/model/repository/Cubit/state/router/DI/session capability واختبارات permissions والـ settings draft. Flutter implemented; focused drafts/routes/revocation tests and authenticated Web Owner/Manager/Employee evidence plus native EN/AR Settings acceptance recorded on 2026-10-04.
- [ ] D2-11: Automatic وpriority في policy API وFlutter، مع detail hydration وexplicit clears. Web Owner EN بتاريخ2026-10-05 أثبت Code create/edit/reopen باستهداف Regular وحدها دون Large، وحفظ priority، وتحويل Automatic معcode:null، وإنشاء Automatic draft testing-only. omitted/clear محفوظان باختبارات Backend الحالية. القبول على Windows النهائي ومصفوفة الأدوار/اللغتين متبقيان؛ capability الإنشاء مستقلة عن engineReady.
- [x] D2-12: help text/summary/default reset وEN/AR/RTL؛ مثال اختيار saving بعد caps. Implemented with monetary-saving/cap examples, constrained layout tests, actual draft-only reset and EN/AR native evidence on 2026-10-04.

### P2-D — POS والإيصال

- [ ] D2-13: early persistent cart وserial mutations/recovery. Web2026-10-05 أثبت نفس order6 عبرhold→resume→hold والسلة الفارغة بعد hold؛ صُحح staging قبل رفض missing shift، معregression وقبول Web Employee AR. customer attach/remove وbranch/lost-mutation/abandoned-draft/shift-close live ومصفوفة Windows متبقية.
- [ ] D2-14: Web Owner EN2026-10-05 أثبت discovery/disjoint/cap/rounding/suppression reason/undo، وcash/card IDs حقيقية، وstale quote تأكيد جديد، وتعافي بعد إسقاط response وتسويةzero بسياسةManual محفوظة. أدلة ad_hoc السابقة تاريخية لا تثبت التدفق الجديد. single/after_items/strategies/limits ورفض suppression غير المخول live والمخزون المتتبع والمنصات/الأدوار متبقية.
- [ ] D2-15: صُحح placeholder Print order لقراءة receipt المحفوظة ومعاينتها وإعادة طباعة مستقلة. Web AR Employee أعادفتح order8/receipt منhistory، وفشل settings للطباعة لا يعيد الدفع. snapshot بعد تعديلpolicy/replay ثابتان. pre-bill ناجح مرئي وlegacy live ومصفوفة اللغات/Windows والطباعة الفعلية غيرمثبتة.
- [ ] D2-16: X-Discount-Contract:2 مرصود في نقل Flutter؛ تغييرOwner→Manager→Employee حدّث capabilities ومسحcart، وtesting-only يفصلcreationAvailable/engineReady/settings. legacy-client live وbranch/customer/revocation معquote/caps ومصفوفةWindows متبقية.

### P2-E — الإغلاق والتفعيل

- [x] D2-17: focused ثم full serial backend regression، Flutter focused/full analysis، layout checks، diff review. سجل 2026-10-05 الحالي وexit codes وتصنيف الإخفاقات في [تقرير القبول الحالي](../docs/verification/discount_plan2_acceptance_2026-10-05_ar.md). تشغيل Backend الكامل الجاري يُستكمل دون إعادة؛ أي تحقق إضافي يجب أن تبرره تعديلات جديدة أو إخفاق. لا نسخة HEAD جديدة ولا ادعاء green full-suite أو إغلاق قبول Windows التفاعلي والطباعة الفعلية.
- [x] D2-18: تحديث authoritative docs وPROJECT_STATUS خلال التنفيذ، migration/roll-forward notes وتقرير evidence. Final file/command/screenshot/gap inventory and authority/service-restoration evidence recorded on 2026-10-04; existing migration/roll-forward contract and untouched activation CHECK preserved.
- [ ] D2-19: تفعيل engineReady فقط بعد completion gates؛ automaticEnabled يبقى false حتى اختيار المقهى.

## 13. مصفوفة الاختبارات

| المجال | الحد الأدنى |
|---|---|
| Defaults/security | owner/manager/employee/factory role، foreign tenant، stale settings save، Manager لا يفتح Tax/Profile، defaults persisted/missing |
| Strategy | أعلى/أقل بعد quantity/caps، priority/tie، zero automatic مستبعد، code zero القديم محفوظ |
| Combination | single، disjoint، policy تغطي عدة أسطر، per_order مرة واحدة، category overlap، bundle exclusive، after_items، explicit intent |
| Allocation | cent remainder، fractional quantity، global percent cap، sum exact، no double metrics joins |
| Eligibility | dates/overnight/branch timezone، groups/customers/channel، minimum subtotal، payment-method ID |
| Suppression | reason required، authorization، survives cart changes، undo، no transfer to new order |
| Payment | stale quote حتى عند زيادة cash received، expiry، method switch، zero balance restricted tender، invalid method mapping، no partial usage/posting |
| Concurrency | final usage مع طلبين، overlapping multi-policy payments، config save vs pay، policy edit vs quote/pay، duplicate/uncertain replay |
| History | policy/settings edit لا يغير paid snapshot، legacy no allocations، amount refunds unchanged، receipt and Finance balance |
| POS | أول item persist، lost create response، repeated taps، queue order، hold/resume، abandoned drafts/shift close، customer removal، offline |
| UI | جميع tab states، conditional controls، summary، edit full-policy roundtrip، EN/AR compact layout/RTL، update-required |

التزامن يجب أن يستخدم PostgreSQL مستقل workers وحواجز deterministic؛ sequential calls أو sleeps ليست إثبات race safety. Laravel suites على shared testing DB تعمل serially.

راجع suites الحالية DiscountManagementApiTest، DiscountV1ContractTest، DiscountV2BackendTest، DiscountSecurityHardeningTest، DiscountRuntimeEligibilityTest وPreAuthFinancialConcurrencyTest. أضف suites settings/resolution/allocations/quote/compatibility بدل تحويل الاختبارات إلى assertions تعكس التنفيذ فقط.

اختبار replacement الحالي يبقى في default single؛ أضف branch coverage لإعداد الجمع بدل حذف ضمان الاستبدال الافتراضي. tests منع automatic القديمة تصبح اختبارات unsupported capability/validation بدل إضعاف coupon secrecy أو BOGO lockout.

أوامر مرحلة التنفيذ، وليست أوامر منفذة عند كتابة الخطة:

```powershell
docker compose exec -T backend php artisan test --filter='DiscountManagementApiTest|DiscountV1ContractTest|DiscountV2BackendTest|DiscountSecurityHardeningTest|DiscountRuntimeEligibilityTest|PreAuthFinancialConcurrencyTest'
```

ثم new suites وPOS/payment/receipt/refund/shift-close regressions، وبعد focused pass full serial Laravel suite.

```powershell
cd windows_application
flutter gen-l10n
flutter test --concurrency=1 test/features/discounts
flutter test --concurrency=1 test/features/cafe_configuration
flutter test --concurrency=1 test/features/pos
flutter analyze
```

تأكد من المسارات الموجودة، وأضف receipt/routing/payment widget suites المناسبة. شغّل Pint/Dart format ثم git diff --check. لا تشغل Flutter commands متزامنة على SDK lock مشترك.

## 14. بوابات القبول والنشر

1. يستطيع Owner وManager المخول تعديل settings، وEmployee لا يستطيع، دون widening لبقية Cafe Configuration.
2. auto off + single الافتراضي يحافظ على السلوك السابق، مع Manual/Code على variants من خطة 1.
3. كل اختيار visible له backend persisted contract، ولا UI placeholder للـ overlap المؤجل.
4. automatic/multi calculations exact وثابتة وقابلة للتفسير عبر allocations وبنفس النتيجة في POS/quote/payment/receipt/Finance.
5. الدفع يرفض quote المتغير قبل أي أثر مالي، والـ retry لا يستهلك usage مرتين.
6. usage لكل policy مرة لكل sale، global/per-customer/daily limits سليمة تحت التزامن.
7. paid/history/legacy receipts تظل قابلة للقراءة دون إعادة بناء التاريخ.
8. عميل قديم لا يدفع فاتورة جديدة لا يمكنه عرض تفاصيلها أو تأكيد quote لها.
9. EN/AR/Windows/Web حالات التشغيل مثبتة؛ لا يُدّعى physical printing pass دون ملاحظة فعلية.
10. migration rehearsal على testing data، بدون destructive resets، وroll-forward عملي موثق.

عند الحاجة لإيقاف rollout: أوقف activation الجديدة وعمليات البيع غير المتوافقة بشكل واضح، ولا تحذف snapshots أو allocations. تعطيل auto على طلب غير مدفوع يعيد تسعيره عند المراجعة التالية ويتطلب quote جديدًا؛ لا يعود التطبيق إلى ignore-multi schema.

## 15. قرارات محددة ومؤجلات

هذه الخطة تحدد recommendations اللازمة لتجنب أسئلة أثناء التنفيذ: tenant-wide، defaults safe، اختيار تدريجي ثابت، priority الأكبر أولًا، coupon/manual intent واحد، bundle exclusive، after_items اختياري، وcap نسبي.

تفاصيل priority والأولوية التدريجية والسلوك تجاه bundle هي توضيحات هندسية للسياسة العامة التي نوقشت، وليست ادعاء موافقة سابقة على كل enum. راجع جدول المنتج قبل implementation kickoff؛ لا حاجة لمزيد من تحليل المصدر لكتابة المهام، لكن تغيير هذه القرارات يقتضي تحديث الخطة أولًا.

مؤجل: عدة أكواد، عدة explicit manual intents، stacking عدة item policies على السطر نفسه، global combination optimizer، branch-specific settings، loyalty، BOGO، manager PIN، scheduler يعيد تسعير كل drafts في الخلفية، item-based returns، وقواعد قيم مختلفة داخل سياسة واحدة.

هذا الملف لا يمنح تفويضاً عاماً للتنفيذ أو النشر أو commit. التفويض اللاحق بتاريخ 2026-10-03 اقتصر على مرحلة backend D2-05–D2-09 ومقدمات D2-11؛ انتهى عند التسليم دون Flutter أو تفعيل أو نشر أو commits.

تفويض المستخدم اللاحق بتاريخ 2026-10-04 أتاح مرحلة Flutter والتكامل D2-10–D2-18 مع حدودها الصريحة. متابعة الدفع ضيّقت العمل إلى تتبّع السبب المثبت وتصحيحه والقبول المحدد، دون إصلاح الإخفاقات التاريخية أو إعادة الـ suites الكاملة. هذا التفويض يستثني D2-19 والتفعيل والنشر والـ commits.

تفويض2026-10-05 يتيح استكمال Flutter/Backend والقبول والتوثيق، وتصحيح العيوب المثبتة والفحوص الكاملة الحالية. يستثنيcommit/push/deployment/Automatic العام. تجهيز migration تفعيل فعلية يأتي بعد بوابات القبول؛ D2-19 تظل مفتوحة إلى مراجعة مستقلة وتفويض صريح. لم تُنشأ نسخةHEAD أوZIP ولم تُستخدم قاعدة التشغيل للاختبارات.
