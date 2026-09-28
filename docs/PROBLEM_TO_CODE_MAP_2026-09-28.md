# خريطة المشاكل → الكود (للتحقق أثناء اختبار Staging)

> استخدم هذا الملف فقط للتحقق من "وين انحلّت كل مشكلة". التفاصيل الكاملة (السبب الجذري + الكود) في `docs/CLIENT_FIXES_PLAN_2026-09-28.md`. كل الأعمال أدناه **منفذة و `git add`-ed على الفرع `fix/client-feedback-2026-09-28`, غير مدفوعة (push) بعد.**

---

## 1) الإغلاق ما يتم (رفض أي فرق / preview قديم / drawer mismatch)
- **الوردية (اليوم):** `backend/app/Services/ShiftCloseService.php`, `backend/app/Services/ShiftClosePreviewService.php`, `backend/app/Http/Controllers/Api/ShiftController.php`
- **الوردية (تاريخ سابق):** `backend/app/Services/HistoricalShiftCloseService.php`
- **الإغلاق اليومي:** `backend/app/Services/DailyClosingService.php`, `backend/app/Services/DailyClosingSummaryService.php`, `backend/app/Services/DailyClosingReadinessService.php`
- **كيف تتحقق:** افتح وردية → بيع → دفعة مورد نقدية → عدّ يخالف المتوقع → اختر سبب → يجب أن يغلق (لا رسالة `counted_differs_from_expected` أو `drawer_ledger_mismatch`).

## 2) الفروقات ما بيعرف وين رايحة
- **منطق الترحيل:** `backend/app/Services/CashVarianceService.php` (جديد) + حساب `6180 — عجز وزيادة الصندوق` (يُنشأ تلقائياً — `backend/app/Services/FinancialSetupService.php`)
- **إعداد حساب الفروقات بالفرع:** `backend/app/Http/Controllers/Api/CafeConfiguration/BranchController.php` + شاشة `windows_application/lib/features/cafe_configuration/views/cafe_configuration_screens.dart`
- **عرضه بتقرير الوردية:** `windows_application/lib/features/shift/views/shift_closing_step4_review.dart`, `shift_closing_step5_success.dart`, `shift_report_screen.dart`
- **كيف تتحقق:** بعد إغلاق فيه فرق، افتح `1020`/`6180` بشاشة الحسابات المالية وشوف القيد المطابق للفرق.

## 3) النقد ما ينتقل للخزنة / بتاريخ غلط
- **تاريخ التحويل التاريخي:** `backend/app/Services/HistoricalShiftCloseService.php` (صار تاريخ الفترة بدل تاريخ اليوم)
- **وضوح التحويل بالتقرير:** `backend/app/Http/Controllers/Api/ShiftController.php` (`closingPayload`) + `windows_application/lib/features/shift/views/shift_closing_step4_review.dart`
- **كيف تتحقق:** أغلق وردية بتاريخ الأمس، افتح كشف حساب الخزنة الرئيسية بتاريخ الأمس — يجب أن يظهر المبلغ بنفس اليوم.

## 4) تسميات مالية غير متسقة/إنجليزية
- **القاموس الموحّد:** `docs/FINANCE_GLOSSARY_AR.md` (جديد)
- **ترحيل الأسماء الافتراضية القديمة:** `backend/database/migrations/2026_10_08_000002_arabize_default_finance_names.php`
- **الأوصاف/رسائل التحقق:** `backend/app/Services/{SupplierPaymentService,SupplierInvoiceService,CustomerPaymentService,CustomerRefundService,CashTransferService,ShiftCloseTransferService,HistoricalShiftCloseService,JournalEntryService,ShiftSnapshotService,FinancialAccountService,FinancialAccountBalanceQuery,FinancialReportQueryService,PurchasePostingOrchestrator,SalesCreditNotePostingService,SalesInvoicePostingService,DailyClosingService,FinancialSetupService}.php`, `backend/app/Http/Controllers/Api/{PaymentController,RefundController,ReportsOverviewController}.php`
- **كيف تتحقق:** افتح كشف حساب أي مورد/عميل — الأوصاف عربية بالكامل («دفعة مورد — ...»، «تحويل إغلاق الوردية ...»)، و`2000` صار اسمه «الذمم الدائنة – الموردون».
  > ملاحظة: القيود **القديمة** (قبل هذا التاريخ) تبقى بأوصافها الأصلية عمداً — التغيير للقيود الجديدة فقط.

## 5) تعريفات "إجمالي/صافي المبيعات" متضاربة
- **المصدر الموحّد:** `backend/app/Support/SalesTotals.php` (جديد) — `salesSum` (مجموع) / `salesTotal` (إجمالي، بعد خصم/مرتجع) / `salesNet` (صافي، بعد المشتريات والمصاريف المدفوعة أيضاً)
- **مطبّق بكل الشاشات:** `ShiftSnapshotService`, `DailyClosingSummaryService`, `ShiftHistoryQueryService`, `FinanceKpiQueryService`, `FinanceDashboardQueryService`, `SalesReportingQueryService`, `CashierDashboardService`, وواجهات `ReportsOverviewController`, `DailyReportController`, `DailyClosingController`, `SalesInvoiceController`, `SalesReportController`
- **Flutter:** `windows_application/lib/features/shift/**` (النماذج والشاشات)، `finance_inventory_setup/**`، `reports/**`، `sales/**`، وملفات الترجمة `l10n/app_ar.arb` / `app_en.arb`
- **كيف تتحقق:** بأي شاشة (وردية/إغلاق يومي/تقارير) يجب أن تشوف **ثلاث** قيم بأسماء واحدة بكل مكان: مجموع المبيعات، الإجمالي، صافي المبيعات، وهامش الربح محسوب من الإجمالي.

## 6) الرصيد غير ظاهر ببطاقة الحساب
- **Backend:** `backend/app/Services/FinancialAccountBalanceQuery.php` (دالة `balanceWithChildren`)، `backend/app/Http/Controllers/Api/FinancialAccountController.php`
- **Flutter:** `windows_application/lib/features/finance_inventory_setup/models/finance_setup_models.dart`, `views/financial_accounts_screen.dart`
- **كيف تتحقق:** افتح أي حساب (مثلاً `1020 — الخزنة الرئيسية`) — أعلى البطاقة يظهر "الرصيد الحالي" + إجمالي مدين/دائن + آخر حركة، ومطابق لدفتر الأستاذ.

## 7) فاتورة بتاريخ سابق: المواد والنقد لا يتبعان التاريخ
- **سياسة التاريخ السابق:** `backend/app/Support/BackdatePolicy.php` (جديد) + migration `backend/database/migrations/2026_10_08_000003_add_backdate_reason_to_invoices.php`
- **الشراء:** `backend/app/Services/PurchasePostingOrchestrator.php`, `backend/app/Services/SupplierInvoiceService.php`, `backend/app/Http/Controllers/Api/{PurchaseController,SupplierInvoiceController}.php`
- **البيع (يدوي):** `backend/app/Services/{SalesInvoiceService,SalesInvoicePostingService,SalesInvoiceInventoryConsumptionService,SalesInventoryMovementService}.php`, `backend/app/Http/Controllers/Api/SalesInvoiceController.php`
- **المرتجع/الإشعار الدائن:** `backend/app/Services/SalesCreditNoteService.php`, `backend/app/Http/Controllers/Api/SalesCreditNoteController.php`
- **Flutter:** `windows_application/lib/shared/widgets/backdate_reason_field.dart` (جديد)، `features/purchasing/{views/purchase_invoice_form_screen.dart,widgets/purchase_posting_dialog.dart,views/purchase_invoice_detail_screen.dart,views/purchasing_center_screen.dart,models/purchasing_models.dart}`، `features/sales/{views/sales_screens.dart,models/sales_models.dart}`
- **كيف تتحقق:** أنشئ فاتورة شراء بتاريخ الأمس بدون سبب → رفض. مع سبب → تُحفظ، شارة «بتاريخ سابق»، «تاريخ الإنشاء» = اليوم الفعلي. بعد الترحيل: قيد الدفع + استلام المخزون + حركة المخزون كلها بتاريخ الأمس. نفس الشيء لفاتورة بيع يدوية (تاريخ خصم المواد). إذا الأمس يوم مُغلق: تحذير برتقالي + يظهر بتقرير الأمس كـ"حركة بعد الإغلاق".

## 8) سجل المواد/الوصفات/الشراء غير مربوط (أو نسخة قديمة معروضة)
- **أولاً — تحقق من نسخة العميل:** `docs/CLIENT_FIXES_DIAGNOSTICS_2026-09-28.md` (نتيجة T0) — إذا كانت النسخة المنشورة قديمة، فبعض ما بالصورة يُحل تلقائياً بمجرد النشر + `Ctrl+Shift+R`.
- **Backend:** `backend/app/Http/Controllers/Api/InventoryItemController.php` (`purchaseHistory`, `recipeUsage`)
- **Flutter:** `windows_application/lib/features/inventory/{views/item_details_screen.dart,controllers/inventory_cubit.dart,controllers/inventory_state.dart,models/inventory_models.dart,repositories/inventory_repository.dart}`
- **كيف تتحقق:** مادة كافيه عليها فاتورة شراء مرحّلة غير مستلمة بعد → تظهر بسجل الشراء بحالة «غير مستلم». مادة مستخدمة بوصفة منتج → تظهر بتبويب استخدام الوصفات. تبديل بين مادتين بسرعة → لا تبقى بيانات المادة السابقة ظاهرة.

---

## ملفات مرجعية إضافية
- الخطة الكاملة (سبب كل مشكلة + الكود بالتفصيل): `docs/CLIENT_FIXES_PLAN_2026-09-28.md`
- سجل التنفيذ لكل مهمة (ما تم + الانحرافات + الفحوصات): `docs/CLIENT_FIXES_PROGRESS.md`
- قاموس التسميات: `docs/FINANCE_GLOSSARY_AR.md`
- سكريبت القبول اليدوي الكامل (7 خطوات متسلسلة تغطي كل الشكاوى دفعة واحدة): §5 من `docs/CLIENT_FIXES_PLAN_2026-09-28.md`
