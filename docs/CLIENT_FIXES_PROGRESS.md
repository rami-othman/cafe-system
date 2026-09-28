# سجل تنفيذ خطة إصلاح ملاحظات العميل — 2026-09-28

المرجع: `docs/CLIENT_FIXES_PLAN_2026-09-28.md`. الفرع: `fix/client-feedback-2026-09-28`.
ترتيب التنفيذ الفعلي: T4 ← T7 ← T6 ← T5 ← T3 ← T8 ← T9 ← T10 (T1/T2 كانت خلصت مسبقاً، T0 مؤجلة لصاحب المشروع).

---

## T4 — الإغلاق اليومي: النقد المتوقع من الدفاتر + الفرق مسموح ومرحّل

**الحالة:** منجزة، staged.

**الملفات المعدّلة:**
- `backend/app/Services/DailyClosingSummaryService.php`
- `backend/app/Services/DailyClosingReadinessService.php`
- `backend/app/Services/DailyClosingService.php`
- `backend/app/Http/Controllers/Api/DailyClosingController.php`
- `windows_application/lib/features/finance_inventory_setup/models/finance_setup_models.dart`
- `windows_application/lib/features/finance_inventory_setup/views/daily_closing_workspace_screen.dart`

**ما تم:**
1. `DailyClosingSummaryService::summarize()`: حقنت `FinancialAccountBalanceQuery`. `cash.openingCash` و`cash.expectedCash` أصبحا مجموع رصيد الدفاتر (`summary()['balance']`) لكل مواقع الصندوق النقدية للفرع، لليوم السابق واليوم الحالي على التوالي، بدل الاعتماد فقط على `opening_cash` للورديات. أضفت `cash.otherMovements = ledgerClosing − (ledgerOpening + بنود الحركة المعروفة)`. بنود التفصيل (`cashSales`, `cashRefunds`, `expensesCash`, `supplierPaymentsCash`, `customerPaymentsCash`, `customerRefundsCash`, `transfersIn`, `transfersOut`) بقيت كما هي للعرض فقط.
2. `DailyClosingReadinessService`: `CASH_DIFFERENCE` أصبح `warning` بدل `blocking`.
3. `DailyClosingService`:
   - حقنت `CashVarianceService`.
   - `close()`: عند فرق ≠ صفر، `cashDifferenceReason` إجباري (وإلا 422 على `closing`)، ثم يقرأ `branches.shift_close_destination_financial_location_id` — إذا فارغ يرمي `ValidationException` برسالة عربية واضحة بدل تخمين موقع، وإلا يرحّل القيد عبر `CashVarianceService::post(...)` بـ `sourceType='daily_closing_cash_variance'`, `sourceId=daily closing id`, `entryDate=business_date`. يخزّن `cash_variance_journal_entry_id`, `cash_difference_reason`, `cash_difference_reason_detail`.
   - `present()`: أضاف `variance => [amount, accountCode, accountName, journalEntryId]` (الحساب من `CashVarianceService::account()`، ملفوف بـ try/catch حتى لا تنكسر شاشات القائمة إذا الحساب الافتراضي محذوف).
4. `DailyClosingController::close()`: تحقق جديد `cashDifferenceReason` (نفس قائمة `ShiftController::DIFFERENCE_REASONS` — مكرّرة حرفياً بثابت خاص محلي لأنها `private const` بالكنترولر الآخر) و`cashDifferenceReasonDetail`.
5. Flutter: أضفت `otherMovements` لـ `DailyClosingCashFigures` وموديل جديد `DailyClosingVariance` لـ `DailyClosingDetail.variance`. الشاشة: `_CashBreakdown` تعرض «حركات أخرى غير مفسّرة»، وقبل الإغلاق مع فرق ≠ صفر يظهر `_CashDifferenceReasonDialog` (نفس رموز الأسباب العربية المستخدمة بإغلاق الوردية، مكرّرة محلياً بدل استيراد feature الوردية) يجمع السبب (وتفصيله إذا "سبب آخر") قبل استكمال تأكيد الإغلاق، وبانر الإغلاق يعرض رقم قيد الفرق إذا وُجد.

**انحراف عن الخطة:** لا يوجد انحراف جوهري. رسالة "لا يمكن ترحيل فرق الإغلاق اليومي..." نص إضافي دقيق (الخطة لم تحدد نصاً حرفياً لهذه الحالة، فقط طلبت "رسالة عربية واضحة").

**مؤجل:** كتابة اختبار `DailyClosingVarianceTest` (مؤجلة صراحة لـ T10 حسب تعليمات المستخدم).

**الفحوصات:**
- `php -l` عبر `docker exec cafe-system-backend-1` على الملفات الأربعة: نجح، بدون أخطاء صياغة.
- لا يوجد migration جديد بهذه المهمة (الأعمدة المطلوبة أضيفت مسبقاً بـ T1).
- `flutter analyze lib/features/finance_inventory_setup`: نظيف (0 مشاكل) بعد إصلاح ملاحظة `use_null_aware_elements`.
- تأكدت عبر `grep` أنه لا يوجد بناء آخر لـ `DailyClosingCashFigures`/`DailyClosingDetail` خارج ملف الموديلات قد ينكسر بإضافة الحقول الإجبارية الجديدة.

**نقطة الحفظ:** `git add` للملفات الستة أعلاه فقط (staged بشكل منفصل عن T1/T2).

---

## T7 — الفواتير بتاريخ سابق (كل الأنواع) مع سبب إجباري

**الحالة:** منجزة، staged.

**ملفات جديدة:**
- `backend/database/migrations/2026_10_08_000003_add_backdate_reason_to_invoices.php` — `backdate_reason` + `backdated_by` على `supplier_invoices`, `sales_invoices`, `sales_credit_notes`.
- `backend/app/Support/BackdatePolicy.php` — `reason()` (يرمي إذا التاريخ سابق بدون سبب ≥3 أحرف) و`closedDayWarning()`.
- `windows_application/lib/shared/widgets/backdate_reason_field.dart` — يظهر فقط إذا `documentDate` قبل اليوم.

**الباك إند:**
- `SupplierInvoiceService::create/update`: يحسب `backdate_reason`/`backdated_by` عبر `BackdatePolicy::reason()`. `post()`: يعيد نفس الفحص (يحمي مسودة قديمة عُدّلت بدون المرور بهذا المسار).
- `PurchasePostingOrchestrator::post()`: الدفع التلقائي والاستلام التلقائي يستخدمان الآن `$invoice->invoice_date` دائماً (تجاهل `$paymentDate`/`$receiptDate` القادمين من الواجهة).
- `SalesInvoiceService::create/update`: نفس آلية `BackdatePolicy`. `SalesInvoicePostingService::post()`: نفس الفحص قبل `assertPostingAllowed`.
- `SalesInventoryMovementService::consume()/restore()`: باراميتر أخير `?string $occurredAt`. `SalesInvoiceInventoryConsumptionService::consume()` يمرر `$invoice->invoice_date` (مسار `sales_invoice_line` فقط — مسار POS `order_item` لم يتأثر). `SalesCreditNotePostingService` يمرر `$note->credit_date` إلى `restore()`.
- `SalesCreditNoteService::create()`: نفس آلية `BackdatePolicy` على `credit_date`. `SalesCreditNotePostingService::post()`: نفس الفحص قبل الترحيل.
- الكنترولرز الثلاثة (Supplier/Purchase, Sales Invoice, Sales Credit Note): تحقق `backdateReason` بالحفظ، و`backdateReason`/`isBackdated`/`createdAt` بالرد، و`warnings: [DAY_ALREADY_CLOSED]` (عبر `BackdatePolicy::closedDayWarning`) بعد الترحيل إذا اليوم مُغلق — تحذير غير مانع.

**Flutter:**
- `DioApiClient::postEnvelope` جديدة (مثل `getEnvelope` لكن لـ POST) — تُستخدم لقراءة `warnings` بجانب `data` بعد الترحيل.
- `PurchasingRepository::postPurchase` و`SalesRepository::post`/`postCreditNote` أصبحت تُرجع سجل (record) `(الفاتورة, warnings)` بدل الفاتورة فقط؛ استدعاءاتها بشاشات الشراء/البيع تعرض كل تحذير كـ SnackBar برتقالي.
- `purchase_invoice_form_screen.dart` و`sales_screens.dart` (فاتورة البيع اليدوية): `BackdateReasonField` تحت منتقي التاريخ + رفض الحفظ محلياً بدون سبب (نفس فحص الباك إند، تجربة أسرع للمستخدم).
- `purchase_posting_dialog.dart`: حذفت منتقيي «تاريخ الاستلام» و«تاريخ الدفع»، وأضفت سطر قراءة فقط «التاريخ المحاسبي: {تاريخ الفاتورة}». `PurchasePostingChoice.paymentDate/receiptDate` ما زالا موجودين ويُملآن بتاريخ الفاتورة (توافق شكل الـ API فقط، الباك إند يتجاهلهما فعلياً).
- شاشات التفاصيل (شراء، بيع، إشعار دائن) وقوائمها: «تاريخ الإنشاء»، شارة «بتاريخ سابق»، وسبب التاريخ السابق عند وجوده.
- **مؤجل عمداً:** `CreateCreditNoteScreen` (إنشاء مرتجع) ليس فيها منتقي تاريخ إطلاقاً بالكود الحالي (لا `creditDate` تُرسَل أبداً من الواجهة) — الخطة نصت "نموذج المرتجع **إن وُجد** منتقي تاريخ"، وبما أنه غير موجود لم أُضِف حقل السبب هناك؛ شاشة التفاصيل تعرض السبب/الشارة إن وُجدا من مصدر آخر (API مباشر) لكن لا مسار حالياً لإدخالهما من هذه الشاشة تحديداً.

**فحوصات:**
- `php -l` على كل ملفات PHP الـ14 المعدّلة/الجديدة (عبر `docker exec cafe-system-backend-1`): نجح.
- `php artisan migrate --force` (نفس الحاوية): طبّق `2026_10_08_000003` بنجاح.
- `flutter analyze` على `lib/features/purchasing`, `lib/features/sales`, `lib/shared/widgets/backdate_reason_field.dart`, `lib/core/network/dio_api_client.dart`: 0 أخطاء (فقط ملاحظات `info` أسلوبية موجودة مسبقاً بملفات لم ألمسها بنفس الأسطر، تحققت بـ diff أنها ليست من تعديلاتي).

**انحراف عن الخطة:** لم أنشئ `backend/tests/Feature/BackdatedInvoicesTest.php` (مؤجل صراحة لـ T10 حسب تعليمات المستخدم بعدم كتابة اختبارات قبلها).

**نقطة الحفظ:** `git add` لكل ملفات T7 أعلاه (منفصلة عن T4/T1/T2).

---

## T6 — الرصيد داخل بطاقة الحساب

**الحالة:** منجزة، staged.

**الملفات المعدّلة:**
- `backend/app/Services/FinancialAccountBalanceQuery.php` — دالتان جديدتان: `balanceWithChildren($tenantId, $accountId)` و`balancesForAccounts($tenantId, $accountIds)` (المستخدمة داخلياً من الأولى أيضاً). الأرصدة تُجمع مع كل الحسابات الأبناء (تكرارياً عبر `parent_account_id`)، بقيود `posted` فقط. **استعلامان فقط** بغض النظر عن عدد الحسابات المطلوبة: استعلام لبنية الشجرة الكاملة للـtenant (id/parent/normal_balance)، ثم استعلام مجمّع واحد (`GROUP BY financial_account_id`) على `journal_entry_lines`. لا يوجد استعلام رصيد منفصل لكل حساب.
- `backend/app/Http/Controllers/Api/FinancialAccountController.php`: `show()` يستخدم `balanceWithChildren()`. `index()` يستخدم `balancesForAccounts()` مرة واحدة لكل حسابات الصفحة الحالية. `serialize()` أضاف `balance`, `totalDebit`, `totalCredit`, `lastMovementDate` (افتراضياً `'0.00'`/`null` لو لم تُمرَّر — يبقي `store/update/status` كما هي دون كسر).
- Flutter: `FinancialAccount` (بـ`finance_setup_models.dart`) أضاف نفس الحقول الأربعة. `financial_accounts_screen.dart`: بطاقة كبيرة «الرصيد الحالي» (`CurrencyFormatter`) أعلى تفاصيل الحساب — أحمر إذا الرصيد سالب (عكس الطبيعة) — وتحتها إجمالي المدين/الدائن/آخر حركة، وعمود «الرصيد» جديد بجدول الحسابات.

**فحوصات:**
- `php -l` على الملفين: نجح.
- لا migration بهذه المهمة.
- `flutter analyze` على `financial_accounts_screen.dart` و`finance_setup_models.dart`: نظيف (0 مشاكل).

**انحراف عن الخطة:** لا يوجد. لم أوسّع `minWidth` لجدول الحسابات بعد إضافة العمود الجديد (تفصيل عرض بسيط، لا يكسر شيئاً).

**نقطة الحفظ:** `git add` لملفات T6 الأربعة (منفصلة عن T4/T7/T1/T2).

---

## T5 — توحيد تعريفات المبيعات

**الحالة:** منجزة، staged. راجعت التنفيذ الجزئي الموجود وأكملت الناقص منه.

**الملفات المعدّلة:** `backend/app/Support/SalesTotals.php`؛ `backend/app/Services/{ShiftSnapshotService,DailyClosingSummaryService,ShiftHistoryQueryService,FinanceKpiQueryService,FinanceDashboardQueryService,SalesReportingQueryService,CashierDashboardService}.php`؛ `backend/app/Http/Controllers/Api/{ReportsOverviewController,DailyReportController,DailyClosingController,SalesInvoiceController,SalesReportController}.php`؛ `windows_application/lib/features/shift/{models/shift_models.dart,models/shift_assessment.dart,repositories/shift_repository.dart,repositories/shift_mock_repository.dart,views/shift_closing_step1_operations.dart,views/shift_closing_step4_review.dart,views/shift_closing_step5_success.dart,views/shift_history_screen.dart,views/shift_report_screen.dart,widgets/shift_strings.dart}`؛ `windows_application/lib/features/finance_inventory_setup/{models/finance_setup_models.dart,views/daily_closing_screen.dart,views/daily_closing_workspace_screen.dart,views/finance_overview.dart}`؛ `windows_application/lib/features/reports/{models/reports_overview.dart,views/reports_overview_screen.dart}`؛ `windows_application/lib/features/sales/{models/sales_models.dart,views/sales_screens.dart}`؛ `windows_application/lib/l10n/{app_ar.arb,app_en.arb,app_localizations.dart,app_localizations_ar.dart,app_localizations_en.dart}`.

**التحقق:** `php -l` على كل ملفات PHP المعدّلة نجح داخل الحاوية. `flutter gen-l10n` نجح. `flutter analyze --no-fatal-infos` على مجلدات shift/finance_inventory_setup/reports/sales نجح دون أخطاء أو warnings؛ بقيت 28 ملاحظة info قديمة في ملفات sales. `git diff --ignore-cr-at-eol --check` بلا أخطاء. لم أكتب أو أشغّل اختبارات تنفيذاً لتأجيلها إلى T10.

**انحرافات ضرورية عن قائمة الملفات في الخطة:** أضفت `FinanceDashboardQueryService` و`SalesReportController` و`SalesInvoiceController` وملفات موديلات/شاشة التقارير لتصل المفاتيح الثلاثة إلى الواجهات المذكورة في T5. لم ألمس ملف `windows_application/PROJECT_STATUS.md` الموجود مسبقاً كملف unstaged.

**مؤجل:** اختبارات `SalesTotalsTest` واختبارات API وFlutter المذكورة في الخطة إلى T10.

---

## T3 — الإغلاق بتاريخ سابق

**الحالة:** منجزة، staged.

**الملف المعدّل:** `backend/app/Services/HistoricalShiftCloseService.php`.

**ما تم:** الفرق يحتاج سبباً ثم يُرحّل عبر `CashVarianceService::post()` بتاريخ الفترة. خزّنت الفرق ورقم القيد على الوردية. الوردية الاستمرارية تبدأ بالمعدود. التحويل إلى الخزنة بتاريخ الفترة، والرصيد الممرّر يضم الفرق. وصفت حركة الاستمرار بالعربي.

**انحراف لازم:** حدّثت مبلغ حركة الاستمرار و`period.transferAmount` ليطابقا تحويل `counted − closing_float` بعد الفرق؛ بقاء المبلغ المتوقع القديم كان سيُظهر حركة/تقريراً مخالفين للتحويل الفعلي.

**الفحص:** `php -l` نجح. لا migration ولا ملفات Flutter في T3. مراجعة `git diff --ignore-cr-at-eol` أكدت تاريخ الفترة والقيد والرصيد. الاختبارات مؤجلة إلى T10.

---

## T8 — تبويبات تفاصيل المادة

**الحالة:** منجزة، staged. نُفّذت تعديلات الكود رغم تأجيل T0 لصاحب المشروع.

**الملفات المعدّلة:** `backend/app/Http/Controllers/Api/InventoryItemController.php`؛ `windows_application/lib/features/inventory/{views/item_details_screen.dart,controllers/inventory_cubit.dart,controllers/inventory_state.dart,models/inventory_models.dart,repositories/inventory_repository.dart}`.

**ما تم:** سجل شراء الكافيه والمصنع صار من سطور فواتير الموردين المرحّلة، ويعرض كمية الاستلام بالوحدة الأساسية والحالة حتى إن لم يُستلم المخزون. أضفت تلميح المادة المشابهة عند غياب استخدام الوصفات، وصفّرت حالة المادة عند تبديل المعرّف، وعرضت أخطاء التبويبات برسالة إعادة المحاولة. رقم المرجع صار رابطاً للمستند المدعوم حسب نوع الحركة.

**انحراف ضروري:** أضفت حقول `referenceNumber`/`referenceId` المحلولة من سطر الفاتورة أو الاستلام في رد الحركات لربط الرقم بالمستند الصحيح، و`receivedUnit` لأن `received_quantity` مخزّنة بالوحدة الأساسية بينما `quantity` بوحدة الشراء. أضفت حالة/موديل/repository لتوصيل `meta.hint` إلى الشاشة.

**الفحوصات:** `php -l` نجح؛ `flutter analyze lib/features/inventory` نظيف؛ `git diff --ignore-cr-at-eol --check` بلا أخطاء. الاختبارات المذكورة مؤجلة إلى T10.

---

## T9 — التسميات المالية

**الحالة:** منجزة، staged.

**الملفات المعدّلة:** `docs/FINANCE_GLOSSARY_AR.md`؛ `backend/database/migrations/2026_10_08_000002_arabize_default_finance_names.php`؛ `backend/app/Http/Controllers/Api/{PaymentController,RefundController,ReportsOverviewController}.php`؛ `backend/app/Services/{CashTransferService,CustomerPaymentService,CustomerRefundService,DailyClosingService,FinancialAccountBalanceQuery,FinancialAccountService,FinancialReportQueryService,FinancialSetupService,JournalEntryService,PurchasePostingOrchestrator,SalesCreditNotePostingService,SalesInvoicePostingService,ShiftSnapshotService,SupplierInvoiceService,SupplierPaymentService}.php`.

**ما تم:** وثّقت القاموس، وعرّبت الأسماء الافتراضية والقيود الجديدة ورسائل التحقق المالية ضمن المسارات المذكورة. ترحيل البيانات القائمة يقتصر على الأسماء الإنجليزية الافتراضية المطابقة حرفياً ولا يغيّر `code` أو أوصاف القيود القديمة. ملفات تحويل إغلاق الوردية والإغلاق التاريخي كانت أوصافها العربية مطبّقة من T2/T3.

**انحرافات:** أضفت `FinancialReportQueryService` و`SalesInvoicePostingService` و`FinancialAccountService` و`FinancialAccountBalanceQuery` و`DailyClosingService` لتعريب النصوص المالية الظاهرة المذكورة بخطوة البحث في الخطة. لم أعدّل ملفات Flutter لأن فحص `Text('[A-Z]` في المجلدات المحددة لم يجد نصوصاً مطابقة.

**الفحوصات:** `php -l` لكل ملفات PHP المعدّلة نجح؛ `php artisan migrate --force` نجح وطبّق ترحيل T9؛ `git diff --ignore-cr-at-eol --check` نظيف. الاختبارات إلى T10.
