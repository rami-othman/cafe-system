# خطة إصلاح ملاحظات العميل — كافيه 6:18 (الإغلاقات، الحسابات، المشتريات، المواد)

> التاريخ: 2026-09-28 · المستودع: `cafe-system/` · الأساس: `origin/main` (`43c2678`) + cherry-pick `2d34328` (النسخة المنشورة عند العميل)
> هذه الخطة مكتوبة ليُنفّذها أي موديل (حتى الرخيص) مهمة مهمة. كل مهمة فيها: السبب الجذري، الملفات بالضبط، الكود المطلوب، الاختبارات، ومعيار القبول.

---

## 0. قواعد إلزامية للمنفّذ (اقرأها قبل أي تعديل)

1. الفرع: `fix/client-feedback-2026-09-28` مبني على `origin/main` + cherry-pick `2d34328`. (`main` المحلي قديم — لا تستخدمه.)
2. نفّذ المهام **بالترتيب** (T0 ← T9). كل مهمة = commit مستقل برسالة `fix(Tn): ...`.
3. لا تعدّل ملفات خارج القائمة المذكورة بالمهمة إلا إذا كان ضرورياً للاختبارات، واذكر السبب في رسالة الـ commit.
4. المال دائماً بالسنتات عبر `App\Support\Money` (`Money::cents()` / `Money::decimal()`). ممنوع `float` بأي حساب مالي في الباك إند.
5. أي قيد محاسبي يمر **فقط** عبر `App\Services\AccountingPostingService::post()` مع `sourceType` + `sourceId` + `sourceEvent` (هذا يضمن عدم التكرار).
6. بعد كل مهمة شغّل:
   - Backend: `cd backend && php artisan test --filter=<اسم الاختبارات المذكورة>` ثم في النهاية `php artisan test`.
   - Flutter: `cd windows_application && flutter analyze && flutter test`.
7. النصوص الظاهرة للمستخدم **بالعربي**. رسائل الباك إند في `backend/lang/ar/*.php` و`backend/lang/en/*.php` (نفس المفاتيح بالملفين).
8. لا تحذف أي اختبار قديم. إذا تغيّر سلوك مقصود (مثل السماح بالإغلاق مع فرق)، عدّل توقع الاختبار واكتب تعليقاً `// behaviour changed in T2 (client decision 2026-09-28)`.

---

## 1. ملخص المشاكل والسبب الجذري (نتيجة فحص الكود)

| # | شكوى العميل | السبب الجذري الفعلي بالكود | المهمة |
|---|---|---|---|
| 1 | «الإغلاق ما عم يتم بسبب آخر تحديث» | (أ) `ShiftCloseService::close()` يرفض أي فرق: `countedCents !== expectedCents` ← `counted_differs_from_expected`. (ب) `ShiftCloseTransferService` و`ShiftClosePreviewService` يرفضان إذا رصيد الصندوق المحاسبي ≠ النقد المتوقع من ملخص الوردية (`drawer_ledger_mismatch`) — أي حركة على الصندوق غير محسوبة بالملخص تقفل الإغلاق. (ج) منذ commit `31056d0` الواجهة ترسل دائماً `previewVersion`، والـ hash يشمل **كل** قيود الصندوق وكل حركات مخزن البار — أي بيع/حركة بين فتح المعاينة والتأكيد ← `historical_preview_changed`. (د) الإغلاق اليومي: `CASH_DIFFERENCE` عائق `blocking`. | T2, T3, T4 |
| 2 | «الفروق غير واضحة على وين عم تروح» | لا يوجد أي قيد للفروقات. `cash_difference` يُخزّن `0.00` دائماً بالوردية، وبالإغلاق اليومي يُخزّن رقم بدون قيد. لا يوجد حساب «عجز وزيادة الصندوق» بدليل الحسابات (`FinancialSetupService` السطور 69–91). الواجهة تطلب «سبب الفرق» لكن الباك إند يرفض أصلاً. | T1, T2, T4 |
| 3 | «المبلغ لا ينقل… بعد تحديث إغلاق الصندوق» | (أ) الإغلاق التاريخي (`HistoricalShiftCloseService` سطر ~139) يرحّل تحويل الصندوق ← الخزنة **بتاريخ اليوم** وليس تاريخ الفترة، فالخزنة لا ترى المبلغ في اليوم الصحيح. (ب) إذا `counted − closing_float = 0` لا يُنشأ تحويل أصلاً (`return null`) بدون أي رسالة. (ج) تقرير الإغلاق لا يعرض مبلغ التحويل ولا وجهته، فلا يمكن التأكد. | T0, T2, T3 |
| 4 | «مراجعة كامل الأسماء المالية» | أوصاف قيود إنجليزية (`Supplier Payment — …`, `POS Sale — …`, `User shift close 12`)، أسماء مواقع نقدية إنجليزية (`Main Safe`, `Cash Drawer`, `Bank`, `Cash`)، `2000 = الحسابات الدائنة` (الأدق: الذمم الدائنة – الموردون)، رسائل تحقق إنجليزية بخدمات المشتريات/الدفعات، وتسميات مبيعات متضاربة («إجمالي المبيعات» تعني أشياء مختلفة بشاشات مختلفة). | T5, T9 |
| 5 | تعريفات المبيعات (مجموع / إجمالي / صافي) | كل شاشة تحسب بطريقتها: `ShiftSnapshotService`, `DailyClosingSummaryService`, `ReportsOverviewController`, `SalesReportingQueryService`, `FinanceKpiQueryService`, `DailyReportController`, `CashierDashboardService`, `ShiftHistoryQueryService`، وبفلاتر `shift_models.dart` يحسب `netSales` محلياً. | T5 |
| 6 | «بدنا الرصيد يظهر داخل البطاقة» | `FinancialAccountController::show()` و`serialize()` لا يرجعان رصيداً، وشاشة `financial_accounts_screen.dart::_accountDetail()` لا تعرض رصيداً. | T6 |
| 7 | فاتورة بتاريخ سابق: المواد بالتاريخ الصحيح والنقد بتاريخ الإنشاء | **الشراء:** قيد الفاتورة يستخدم `invoice_date` ✔، لكن `PurchasePostingOrchestrator::post()` يضع `paymentDate ?? BranchLocalDate::today()` و`receiptDate ?? today()`، ونافذة `purchase_posting_dialog.dart` تبدأ التاريخين بـ `DateTime.now()`، وعند عدم وجود دفعة لا يُرسل `receiptDate` أصلاً. **البيع اليدوي:** خصم المواد (`SalesInventoryMovementService::consume`) بتاريخ اليوم دائماً. لا يوجد حقل «سبب التاريخ السابق»، والشاشات لا تعرض «تاريخ الإنشاء». | T7 |
| 8 | «سجل المواد والوصفات والشراء ما مربوط» | **صورة العميل من نسخة قديمة**: نص «لا تتوفر بيانات استخدام الوصفات بعد» حُذف من الكود في commit `1caac6b` (24-09)، والتكلفة تظهر `$0.21` بينما الكود الحالي يعرض `SYP`. إضافة لذلك: سجل الشراء لمواد الكافيه يعتمد فقط على الاستلامات المرحّلة (`purchase_receipt_lines`) فالفواتير غير المستلمة لا تظهر، وحالة الخطأ تُعرض كـ«فارغ»، وأعلام التحميل لا تُصفّر عند تغيير المادة. | T0, T8 |

---

## 2. القرارات المعتمدة من العميل (لا تغيّرها)

| الموضوع | القرار |
|---|---|
| فرق الإغلاق | **الإغلاق مسموح مع سبب إجباري**، والفرق يُرحَّل تلقائياً بقيد إلى **حساب يحدده المدير** (إعداد على مستوى الفرع). ننشئ الآن حساباً افتراضياً جديداً `6180 — عجز وزيادة الصندوق`. |
| نطاق تعريفات المبيعات | **بكل البرنامج** (الوردية، الإغلاق اليومي، النظرة المالية، تقارير المبيعات، لوحة الكاشير، سجل الورديات). |
| الفواتير بتاريخ سابق | **أي فاتورة** (شراء، بيع، بيع المصنع، مرتجع) مسموح بتاريخ سابق **مع سبب إجباري**. الفاتورة + المواد + النقد كلها بالتاريخ السابق، و«تاريخ الإنشاء» يظهر على الفاتورة. |
| فاتورة بتاريخ يوم مُغلق | **مسموح مع تحذير**: تُرحّل بالتاريخ المختار وتظهر كـ«حركة بعد الإغلاق» في تقرير ذلك اليوم. |
| «المشتريات» في صافي المبيعات | **افتراض** (العميل لم يحدد): المبالغ **المدفوعة فعلياً** للموردين خلال الفترة (وليس الفواتير الآجلة). على مستوى الوردية: ما خرج من صندوق الوردية للموردين. قابل للتعديل لاحقاً من مكان واحد (`SalesTotals`). |

### تعريفات المبيعات الرسمية (مصدر واحد للحقيقة)

```
مجموع المبيعات  salesSum   = كل المبيعات المكتملة خلال الفترة قبل أي خصم (قبل الخصومات، المرتجعات، المصاريف)
الإجمالي         salesTotal = salesSum − المرتجعات − الخصومات
صافي المبيعات   salesNet   = salesSum − المرتجعات − الخصومات − المشتريات (المدفوعة) − المصروفات (المدفوعة)
```
⚠️ مهم: **مجمل الربح وهامش الربح يُحسبان من `salesTotal` (الإجمالي) وليس من `salesNet`** — وإلا تُخصم المشتريات مرتين (مرة كمشتريات ومرة كتكلفة بضاعة مباعة).

---

## 3. المهام التنفيذية

### T0 — تشخيص قبل البرمجة (قراءة فقط، على قاعدة بيانات الإنتاج)

**الهدف:** تأكيد الأسباب على بيانات العميل الحقيقية + التأكد من نسخة البرنامج المنصّبة عنده.

1. **نسخة البرنامج عند العميل:**
   - على السيرفر: `grep -c "لا تتوفر بيانات استخدام الوصفات" /var/www/cafe18/main.dart.js` — إذا النتيجة > 0 فالويب قديم.
   - إذا العميل يستخدم نسخة Windows (`.exe`) — تأكد من تاريخ البناء. الصورة تُظهر `$` بالتكلفة و«لا تتوفر بيانات…» = نسخة أقدم من `1caac6b`.
   - بعد النشر: اطلب من العميل `Ctrl+Shift+R` (الويب يستخدم service worker ويخزّن النسخة القديمة).
2. **أسباب فشل الإغلاق من اللوغ:**
   ```bash
   grep -E "counted_differs|drawer_ledger_mismatch|historical_preview_changed|historical_transfer_insufficient|counted_below_float" backend/storage/logs/laravel*.log | tail -50
   ```
3. **ورديات مغلقة بدون تحويل للخزنة:**
   ```sql
   SELECT id, shift_number, closed_at, business_date, expected_cash, closing_cash,
          closing_float_amount, close_transfer_id, close_destination_financial_location_id, close_type
   FROM shifts
   WHERE status = 'closed' AND closed_at > now() - interval '21 days'
   ORDER BY closed_at DESC;
   ```
4. **تحويلات إغلاق بتاريخ مختلف عن يوم الوردية:**
   ```sql
   SELECT s.shift_number, s.business_date, s.closed_at::date AS closed_day, t.transfer_date, t.amount
   FROM shifts s JOIN cash_transfers t ON t.id = s.close_transfer_id
   WHERE t.transfer_date <> COALESCE(s.business_date, s.closed_at::date);
   ```
5. **فرق رصيد الصندوق المحاسبي عن ملخص الوردية للورديات المفتوحة:** شغّل `php artisan tinker` ثم لكل وردية مفتوحة قارن `ShiftCashSummaryService::summarize()['expectedCash']` مع `ShiftDrawerReadinessService::drawerLedgerBalance()` واطبع الفرق + قيود `journal_entry_lines` على `financial_location_id` الصندوق منذ `opened_at` غير المرتبطة بمصدر للوردية.
6. **المادة في الصورة (استخدام الوصفات):**
   ```sql
   SELECT id, name_ar, sku, owner_branch_id, unit FROM inventory_items WHERE name_ar ILIKE '%<اسم المادة>%';
   SELECT inventory_item_id, count(*) FROM variant_recipe_components WHERE inventory_item_id IN (<ids>) GROUP BY 1;
   ```
   إذا ظهرت نسختان من نفس المادة (نسخة مصنع `owner_branch_id` ≠ NULL ونسخة كافيه) فالوصفة مربوطة بالنسخة الأخرى — سجّلها بالتقرير.
7. اكتب النتائج في `docs/CLIENT_FIXES_DIAGNOSTICS_2026-09-28.md`. **لا تعدّل أي بيانات إنتاج.**

**معيار القبول:** ملف التشخيص موجود ويجيب: هل النسخة قديمة؟ ما أكثر رسالة فشل إغلاق؟ كم وردية بلا تحويل؟

---

### T1 — حساب «عجز وزيادة الصندوق» + إعداد الحساب لكل فرع

**ملفات جديدة:**
- `backend/database/migrations/2026_10_08_000001_add_cash_variance_accounting.php`
- `backend/app/Services/CashVarianceService.php`
- `backend/tests/Feature/CashVarianceAccountTest.php`

**ملفات معدّلة:**
- `backend/app/Services/FinancialSetupService.php` (قائمة الحسابات الافتراضية ~سطر 69–91)
- `backend/app/Http/Controllers/Api/CafeConfiguration/BranchController.php`
- `backend/app/Http/Resources/CafeConfiguration/BranchResource.php`
- طلب التحقق الخاص بتحديث الفرع (ابحث: `grep -rn "shiftCloseDestinationFinancialLocationId" backend/app/Http/Requests`)
- `windows_application/lib/features/cafe_configuration/models/cafe_configuration_models.dart`
- `windows_application/lib/features/cafe_configuration/controllers/cafe_configuration_cubits.dart`
- `windows_application/lib/features/cafe_configuration/views/cafe_configuration_screens.dart` (بجانب حقل وجهة الإغلاق ~سطر 571)

**الخطوات:**
1. الـ migration:
   ```php
   Schema::table('branches', fn (Blueprint $t) => $t->foreignId('cash_variance_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete());
   Schema::table('shifts', fn (Blueprint $t) => $t->foreignId('cash_variance_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete());
   Schema::table('daily_closings', function (Blueprint $t) {
       $t->foreignId('cash_variance_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
       $t->string('cash_difference_reason', 40)->nullable();
       $t->text('cash_difference_reason_detail')->nullable();
   });
   // لكل tenant موجود: أنشئ الحساب إذا غير موجود
   foreach (DB::table('tenants')->pluck('id') as $tenantId) {
       if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '6180')->exists()) {
           DB::table('financial_accounts')->insert([
               'tenant_id' => $tenantId, 'code' => '6180', 'name_ar' => 'عجز وزيادة الصندوق', 'name_en' => 'Cash Over / Short',
               'account_group' => 'expenses', 'normal_balance' => 'debit', 'is_active' => true, 'is_system_protected' => true,
               'created_at' => now(), 'updated_at' => now(),
           ]);
       }
   }
   ```
   (تحقق من أسماء أعمدة `financial_accounts` الإلزامية الأخرى من migration إنشائها قبل الكتابة.)
2. `FinancialSetupService`: أضف السطر
   `['code' => '6180', 'name_ar' => 'عجز وزيادة الصندوق', 'name_en' => 'Cash Over / Short', 'account_group' => 'expenses', 'normal_balance' => 'debit'],`
3. `CashVarianceService`:
   ```php
   final class CashVarianceService
   {
       public function __construct(private readonly AccountingPostingService $posting) {}

       /** الحساب المحدد من المدير للفرع، وإلا 6180. */
       public function account(int $tenantId, int $branchId): object
       {
           $id = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->value('cash_variance_account_id');
           $q = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at');
           $account = $id ? (clone $q)->where('id', $id)->first() : (clone $q)->where('code', '6180')->first();
           if (! $account) throw ValidationException::withMessages(['cashVarianceAccount' => __('shifts.variance_account_missing')]);
           return $account;
       }

       /**
        * $differenceCents = المعدود − المتوقع. سالب = عجز، موجب = زيادة. يرجع رقم القيد أو null إذا الفرق صفر.
        */
       public function post(Request $request, int $tenantId, int $branchId, int $locationId, int $differenceCents,
           string $entryDate, string $sourceType, int $sourceId, string $description, ?int $actorId): ?int
       {
           if ($differenceCents === 0) return null;
           $account = $this->account($tenantId, $branchId);
           $locationAccountCode = DB::table('financial_locations as l')->join('financial_accounts as a', 'a.id', '=', 'l.financial_account_id')
               ->where('l.tenant_id', $tenantId)->where('l.id', $locationId)->value('a.code');
           $amount = Money::decimal(abs($differenceCents));
           $short = $differenceCents < 0;
           return $this->posting->post($request, $tenantId, [
               'branchId' => $branchId, 'sourceType' => $sourceType, 'sourceId' => $sourceId,
               'sourceEvent' => 'CASH_VARIANCE_POSTED', 'entryDate' => $entryDate, 'description' => $description,
               'lines' => [
                   ['accountCode' => $account->code, 'debit' => $short ? $amount : '0.00', 'credit' => $short ? '0.00' : $amount, 'description' => $description],
                   ['accountCode' => $locationAccountCode, 'debit' => $short ? '0.00' : $amount, 'credit' => $short ? $amount : '0.00', 'financialLocationId' => $locationId, 'description' => $description],
               ],
           ], $actorId);
       }
   }
   ```
4. `BranchController` + `BranchResource`: أضف الحقل `cashVarianceAccountId` (قراءة/كتابة). التحقق: `nullable|integer` ويجب أن يكون حساباً فعّالاً لنفس الـ tenant، **ولا يكون حساب نقدية** (ليس مرتبطاً بأي `financial_locations`) — رسالة: «حساب الفروقات لا يمكن أن يكون صندوقاً أو خزنة».
5. Flutter: بشاشة إعدادات الفرع، تحت «وجهة تحويل النقدية عند إغلاق الوردية» أضف Dropdown بعنوان **«حساب فروقات الصندوق (عجز / زيادة)»** يجلب الحسابات من `finance/accounts?status=active` ويعرض `code — nameAr`، وقيمة فارغة = «الافتراضي: 6180 عجز وزيادة الصندوق».
6. `backend/lang/ar/shifts.php` + `en`: أضف
   - `'variance_account_missing' => 'حساب فروقات الصندوق غير محدد. حدده من إعدادات الفرع أو فعّل الحساب 6180.'`

**الاختبارات (`CashVarianceAccountTest`):** إنشاء الحساب عند الإعداد؛ حفظ حساب مختار للفرع؛ رفض حساب صندوق؛ `CashVarianceService::post` بعجز 500 ينتج قيد مدين 6180 / دائن الصندوق، وبزيادة العكس.

**القبول:** دليل الحسابات فيه `6180`، وشاشة الفرع تسمح باختيار حساب الفروقات.

---

### T2 — إغلاق الوردية العادي (اليوم): السماح بالفرق + ترحيله + وضوح التحويل

**ملفات معدّلة:**
- `backend/app/Services/ShiftCloseService.php`
- `backend/app/Services/ShiftClosePreviewService.php`
- `backend/app/Http/Controllers/Api/ShiftController.php`
- `backend/app/Support/ShiftClosePresentation.php`
- `backend/app/Services/FinancialTransactionSourceResolver.php`
- `backend/lang/ar/shifts.php`, `backend/lang/en/shifts.php`
- `backend/tests/Feature/ShiftDrawerLifecycleTest.php` (تعديل توقعات) + ملف جديد `backend/tests/Feature/ShiftCloseVarianceTest.php`
- Flutter: `features/shift/repositories/shift_repository.dart`, `features/shift/models/shift_models.dart`, `features/shift/views/shift_closing_step4_review.dart`, `features/shift/views/shift_closing_step5_success.dart`, `features/shift/views/shift_report_screen.dart`, `features/shift/widgets/shift_strings.dart`

**الخطوات (باك إند):**
1. **رصيد الصندوق المحاسبي هو المرجع للنقد المتوقع.** في `ShiftCloseService::close()`:
   - احقن `ShiftDrawerReadinessService $readiness` و`CashVarianceService $variance` بالـ constructor.
   - بدل `$expectedCents = Money::cents($summary['expectedCash']);` استخدم:
     ```php
     $drawer = $this->readiness->drawerLocation($tenantId, (int) $shift->branch_id, (int) $shift->financial_location_id, true);
     $expectedCents = Money::cents($this->readiness->drawerLedgerBalance($tenantId, $drawer));
     ```
   - في فرع `TYPE_MANUAL` احذف الرمي `counted_differs_from_expected` واستبدله:
     ```php
     $countedCents = Money::cents((string) $countedCash, 'closingCash');
     $differenceCents = $countedCents - $expectedCents;
     if ($differenceCents !== 0 && empty($extra['cash_difference_reason'])) {
         throw ValidationException::withMessages(['cashDifferenceReason' => __('shifts.difference_reason_required')]);
     }
     $varianceEntryId = $this->variance->post($request, $tenantId, (int) $shift->branch_id, (int) $shift->financial_location_id,
         $differenceCents, $transferDate ?? BranchLocalDate::today((int) $shift->branch_id), 'shift_cash_variance', (int) $shift->id,
         'فرق صندوق الوردية '.($shift->shift_number ?? $shift->id), FinancialActor::id($request, $tenantId));
     ```
   - `TYPE_AUTOMATIC`: `$countedCents = $expectedCents; $differenceCents = 0; $varianceEntryId = null;`
   - في تحديث الشفت: `'expected_cash' => Money::decimal($expectedCents)`, `'cash_difference' => Money::decimal($differenceCents)`, `'cash_variance_journal_entry_id' => $varianceEntryId`.
   - الترتيب مهم: **قيد الفرق أولاً ثم `$this->transfers->create(...)`** — بعد قيد الفرق يصبح رصيد الصندوق = المعدود، فيمر فحص `drawer_ledger_mismatch` داخل `ShiftCloseTransferService` بدون تعديل.
2. في `ShiftClosePreviewService::build()`:
   - احذف السطرين اللذين يضيفان `__('shifts.drawer_ledger_mismatch')` إلى `$issues`.
   - اجعل النقد المتوقع من الرصيد المحاسبي: `$expected = $historical ? $previousLedger : $ledger;` واستخدمه بدل `$cash['expectedCash']` في: `$transfer`, `$snapshot['drawer']['expectedCash']`, `metadata['expectedCash']`.
   - أضف للـ metadata: `'summaryExpectedCash' => $cash['expectedCash']`, و`'unexplainedCash' => Money::decimal(Money::cents($expected) - Money::cents($cash['expectedCash']))`.
   - `laterNetCash` = `Money::decimal(Money::cents($ledger) - Money::cents($previousLedger))`.
   - **أزل `$inventoryRows` (حركات مخزن البار) و`$ledgerRows` من الـ hash** عندما `! $historical`، واحتفظ بها فقط للتاريخي.
3. في `ShiftController::close()` (السطور ~222–236): تحقق `previewVersion` **فقط إذا** `$period->historical()`. للإغلاق بتاريخ اليوم تجاهل الـ version تماماً.
4. `closingPayload()`: أضف
   ```php
   'variance' => ['amount' => $shift->cash_difference, 'journalEntryId' => $shift->cash_variance_journal_entry_id,
                  'accountCode' => ..., 'accountName' => ...],   // من CashVarianceService::account()
   'transfer' => ['id' => $shift->close_transfer_id, 'amount' => <cash_transfers.amount>, 'date' => <transfer_date>,
                  'destinationName' => <financial_locations.name للوجهة>, 'floatLeft' => $shift->closing_float_amount,
                  'skippedReason' => $shift->close_transfer_id ? null : 'المبلغ المعدود يساوي العهدة المتبقية، لا يوجد ما يُحوَّل'],
   'unexplainedCash' => ...,
   ```
5. `ShiftClosePresentation`: تأكد أن `cashDifference` يقرأ `cash_difference` المخزّن (لم يعد صفراً دائماً).
6. `FinancialTransactionSourceResolver`: أضف `shift_cash_variance` → نوع «فرق صندوق» ويفتح تقرير الوردية (`shifts.id = source_id`)، و`daily_closing_cash_variance` → «فرق إغلاق يومي».
7. `lang/ar/shifts.php`:
   - `'difference_reason_required' => 'يوجد فرق بين النقد المعدود والمتوقع. اختر سبب الفرق ليتم ترحيله إلى حساب فروقات الصندوق.'`
   - عدّل `description` التحويل بـ `ShiftCloseTransferService` سطر 74 إلى: `'تحويل إغلاق الوردية '.($shift->shift_number ?? $shift->id)`.

**الخطوات (Flutter):**
1. `shift_repository.dart`: اقرأ `variance`, `transfer`, `unexplainedCash` من الرد، وأضف لها موديلات بسيطة في `shift_models.dart` (`ShiftCloseVariance`, `ShiftCloseTransfer`).
2. `shift_closing_step4_review.dart`: إذا الفرق ≠ 0 اعرض بطاقة صفراء: **«الفرق: {±X} ل.س — سيُرحّل تلقائياً إلى حساب {code} {name}»**، وسطر: **«سيُحوَّل {transferAmount} إلى {destination} ويبقى {float} عهدة بالصندوق»**.
3. `shift_closing_step5_success.dart` و`shift_report_screen.dart`: نفس المعلومات بعد الإغلاق مع رقم القيد، وإذا `skippedReason` موجود اعرضه.
4. إذا `unexplainedCash ≠ 0` اعرض تحذيراً (لا يمنع): **«حركات على الصندوق غير مرتبطة بهذه الوردية: X — راجع كشف حساب الصندوق»** مع زر يفتح دفتر الأستاذ للصندوق.
5. تأكد أن `ShiftAssessment.canClose` لا يمنع الإغلاق بسبب وجود فرق (يمنع فقط إذا الفرق ≠ 0 بدون سبب — هذا موجود بالـ cubit).

**الاختبارات (`ShiftCloseVarianceTest`):**
- إغلاق بعجز 1000 مع سبب ← الوردية `closed`, `cash_difference = -1000.00`, قيد مدين 6180 دائن الصندوق، التحويل = المعدود − العهدة.
- إغلاق بزيادة 500 مع سبب ← قيد معكوس.
- إغلاق بفرق بدون سبب ← 422 على `cashDifferenceReason`.
- إغلاق مطابق ← لا قيد فروقات.
- حساب مختار للفرع ← القيد على الحساب المختار.
- حركة يدوية على الصندوق خارج الوردية ← المعاينة `canClose = true` و`unexplainedCash ≠ 0`.
- إغلاق اليوم مع `previewVersion` قديم ← ينجح (لم يعد يُفحص).
- إعادة إرسال نفس الطلب ← نفس النتيجة بدون قيد مكرر.
- عدّل بـ `ShiftDrawerLifecycleTest` الاختبارات التي كانت تتوقع `counted_differs_from_expected`.

**القبول:** الكاشير يغلق مع فرق + سبب، التقرير يوضح أين ذهب الفرق وأين ذهب المبلغ، والخزنة يزيد رصيدها بنفس اليوم.

---

### T3 — الإغلاق بتاريخ سابق (Historical)

**ملفات:** `backend/app/Services/HistoricalShiftCloseService.php`, `backend/tests/Feature/HistoricalShiftCloseTest.php`

1. استبدل (سطر ~86):
   ```php
   if ($counted !== $expected) { throw ... counted_differs_from_expected }
   ```
   بـ:
   ```php
   $differenceCents = $counted - $expected;
   if ($differenceCents !== 0 && empty($data['cashDifferenceReason'])) {
       throw ValidationException::withMessages(['cashDifferenceReason' => __('shifts.difference_reason_required')]);
   }
   $varianceEntryId = $this->variance->post($request, $tenant, (int) $shift->branch_id, (int) $shift->financial_location_id,
       $differenceCents, $period->date, 'shift_cash_variance', (int) $shift->id,
       'فرق صندوق الوردية '.$shift->shift_number, (int) $shift->user_id);
   ```
   (احقن `CashVarianceService`.)
2. في تحديث الشفت: `'cash_difference' => Money::decimal($differenceCents)`, `'cash_variance_journal_entry_id' => $varianceEntryId`.
3. الوردية الاستمرارية: `'opening_cash' => Money::decimal($counted)` بدل `$expected`.
4. **تاريخ التحويل = تاريخ الفترة**: في استدعاء `$this->transfers->create(...)` استبدل `CarbonImmutable::now('UTC')->setTimezone($period->timezone)->toDateString()` بـ `$period->date`، ومرّر الرصيد الحالي بعد الفرق: `Money::cents($metadata['currentLedgerCash']) + $differenceCents`.
5. وصف حركة الاستمرار سطر ~145: `'تحويل إغلاق الوردية '.$shift->shift_number`.

**اختبارات:** إغلاق تاريخي بعجز مع سبب ← قيد الفرق بتاريخ الفترة؛ `cash_transfers.transfer_date = period date`؛ رصيد الخزنة `summary(..., to: period date)` يشمل المبلغ.

---

### T4 — الإغلاق اليومي: النقد المتوقع من الدفاتر + الفرق مسموح ومرحّل

**ملفات:**
- `backend/app/Services/DailyClosingSummaryService.php`
- `backend/app/Services/DailyClosingReadinessService.php`
- `backend/app/Services/DailyClosingService.php`
- `backend/app/Http/Controllers/Api/DailyClosingController.php`
- Flutter: `features/finance_inventory_setup/views/daily_closing_workspace_screen.dart`, `daily_closing_screen.dart` + الموديل والـ repository المقابلين (ابحث `grep -rn "expectedCash" windows_application/lib/features/finance_inventory_setup`)
- اختبار جديد `backend/tests/Feature/DailyClosingVarianceTest.php`

**المشكلة الإضافية المكتشفة:** `expectedCash` اليومي = مجموع `opening_cash` للورديات + حركات **كل** المواقع النقدية (ومنها الخزنة). رصيد الخزنة الافتتاحي غير محسوب بينما دفعات الموردين منها مخصومة ← الرقم المتوقع خاطئ بنيوياً فيظهر فرق دائم يمنع الإغلاق.

1. `DailyClosingSummaryService::summarize()`: احسب
   ```php
   $ledgerOpening = Σ FinancialAccountBalanceQuery::summary($tenant, $loc->financial_account_id, null, <اليوم السابق>, $loc->id)['balance']
   $ledgerClosing = Σ FinancialAccountBalanceQuery::summary($tenant, $loc->financial_account_id, null, $day, $loc->id)['balance']
   ```
   لكل موقع في `$cashLocationIds` (اجلب `financial_account_id` معها). اجعل `cash.openingCash = $ledgerOpening` و`cash.expectedCash = $ledgerClosing`، وأبقِ بقية البنود كتفصيل، وأضف `cash.otherMovements = expected − (opening + البنود)` لتفسير أي فرق.
2. `DailyClosingReadinessService`: غيّر `CASH_DIFFERENCE` من `'blocking'` إلى `'warning'`.
3. `DailyClosingService::close()`: إذا الفرق ≠ 0 ولم يُرسل `cashDifferenceReason` ← `ValidationException` (`closing` => `'يوجد فرق نقدي. اختر السبب ليُرحّل إلى حساب فروقات الصندوق.'`). وإلا رحّل عبر `CashVarianceService::post(... locationId = branches.shift_close_destination_financial_location_id, entryDate = business_date, sourceType = 'daily_closing_cash_variance', sourceId = daily closing id ...)` وخزّن `cash_variance_journal_entry_id`, `cash_difference_reason`, `cash_difference_reason_detail`.
4. `present()`: أضف `'variance' => [amount, accountCode, accountName, journalEntryId]`.
5. Controller: أضف التحقق `cashDifferenceReason` (نفس قائمة `ShiftController::DIFFERENCE_REASONS`) و`cashDifferenceReasonDetail`.
6. Flutter: بشاشة الإغلاق اليومي عند وجود فرق: قائمة أسباب + تفصيل، وسطر واضح **«سيُرحّل الفرق {X} إلى {حساب}»**، وبعد الإغلاق: رقم القيد.

**اختبارات:** يوم فيه دفعة مورد من الخزنة + وردية مغلقة مطابقة ← الفرق = 0 (كان سابقاً ≠ 0)؛ فرق مع سبب ← إغلاق + قيد؛ فرق بدون سبب ← 422.

---

### T5 — توحيد تعريفات المبيعات بكل البرنامج

**ملف جديد:** `backend/app/Support/SalesTotals.php`
```php
final class SalesTotals
{
    /** كل القيم بالسنتات. $salesSumCents = المبيعات قبل الخصم والمرتجع. */
    public static function make(int $salesSumCents, int $refundsCents, int $discountsCents, int $purchasesPaidCents, int $expensesPaidCents): array
    {
        $total = $salesSumCents - $refundsCents - $discountsCents;
        $net = $total - $purchasesPaidCents - $expensesPaidCents;
        return [
            'salesSum' => Money::decimal($salesSumCents),      // مجموع المبيعات
            'refunds' => Money::decimal($refundsCents),
            'discounts' => Money::decimal($discountsCents),
            'salesTotal' => Money::decimal($total),            // الإجمالي
            'purchasesPaid' => Money::decimal($purchasesPaidCents),
            'expensesPaid' => Money::decimal($expensesPaidCents),
            'salesNet' => Money::decimal($net),                // صافي المبيعات
        ];
    }
}
```
+ اختبار وحدة `backend/tests/Unit/SalesTotalsTest.php`.

**أين تُطبَّق (باك إند)** — أضف المفاتيح الجديدة **بجانب** القديمة (لا تحذف القديمة كي لا تنكسر شاشات أخرى)، واجعل `netSales` القديم = `salesTotal`:

| الملف | مصدر salesSum | المرتجعات/الخصومات | المشتريات المدفوعة | المصروفات المدفوعة |
|---|---|---|---|---|
| `ShiftSnapshotService` (`sales`) | `gross` الحالي (`total + discount_total`) | الموجودة | `shift_cash_movements` للوردية حيث `source_type='supplier_payment'` | باقي `expense` بالوردية + `expenses` المدفوعة من صندوق الوردية (من `ShiftCashSummaryService`) مطروحاً منها المشتريات |
| `DailyClosingSummaryService` (`sales`) | `orders_gross` | الموجودة | `supplier_total` (كل الدفعات المرحّلة باليوم) | `expense_paid` |
| `ShiftHistoryQueryService` سطر 62 | `grossSales` | الموجودة | كما بالوردية | كما بالوردية |
| `ReportsOverviewController` (~سطر 82–182) | مجموع `orders` قبل الخصم | مرتجعات + خصومات | `supplier_payments` المرحّلة بالفترة | `expenses` المدفوعة بالفترة |
| `SalesReportingQueryService` / `FinanceKpiQueryService` | `grossCents` | `discountsCents` + `reductions/refunds` | نفس الاستعلام أعلاه | نفس الاستعلام أعلاه |
| `DailyReportController` سطر 37–48 | `subtotal` | … | … | … |
| `CashierDashboardService` سطر ~204 | `grossCents` | `refundCents` + خصومات | صفر (لوحة الكاشير للمبيعات فقط) | صفر |

⚠️ `grossProfit` و`grossMargin` في `ReportsOverviewController`, `SalesReportingQueryService`, `FinanceKpiQueryService` تبقى على **`salesTotal`**.

**Flutter:**
1. `features/shift/widgets/shift_strings.dart`:
   - `grossSales = 'مجموع المبيعات'`
   - أضف `salesTotal = 'الإجمالي'`, `salesTotalHint = 'بعد المرتجعات والخصومات'`
   - `netSales = 'صافي المبيعات'`, `netSalesHint = 'بعد المرتجعات والخصومات والمشتريات والمصروفات'`
   - `ofGrossSales = 'من مجموع المبيعات'`, `totalNetSales = 'مجموع صافي المبيعات'`
2. `features/shift/models/shift_models.dart` سطر 99: احذف الحساب المحلي `netSales => grossSales - discounts - refunds` واقرأ `salesTotal`, `salesNet`, `purchasesPaid`, `expensesPaid` من الـ JSON (`shift_repository.dart` سطر ~239).
3. اعرض الثلاثة (مجموع / إجمالي / صافي) في: `shift_closing_step1_operations.dart`, `shift_closing_step4_review.dart`, `shift_closing_step5_success.dart`, `shift_report_screen.dart`, `shift_history_screen.dart` (عمود «صافي المبيعات» يقرأ `salesNet`، وأضف عمود «الإجمالي»).
4. `shift_assessment.dart` سطر 179: مطابقة المدفوعات تُقارن مع `salesTotal` (وليس الصافي الجديد).
5. `daily_closing_screen.dart` سطر 391، `daily_closing_workspace_screen.dart` سطور 168/206/234، `finance_overview.dart` سطر 346، `features/sales/views/sales_screens.dart` سطر 127: نفس الثلاثية.
6. `lib/l10n/app_ar.arb` (ثم `flutter gen-l10n`):
   - `reportsOverviewKpiNetSales` ← «الإجمالي» وتوضيحه «مجموع المبيعات بعد المرتجعات والخصومات». أضف مفتاحين جديدين `reportsOverviewKpiSalesSum` = «مجموع المبيعات» و`reportsOverviewKpiSalesNet` = «صافي المبيعات» مع توضيح.
   - `salesProfitabilityGrossSales` ← «مجموع المبيعات»، `salesProfitabilityNetSales` ← «الإجمالي».
   - `cashShiftsTotalSales` ← «مجموع المبيعات».
   - `expensesReportRatio` ← «نسبة المصروفات إلى الإجمالي»، `expensesReportNetSales` ← «الإجمالي».
   - `reportsOverviewKpiInfoGrossProfit` ← «الإجمالي مطروحاً منه تكلفة البضاعة المباعة.»
   - حدّث `app_en.arb` بالمقابل (Gross sales / Total / Net sales).

**اختبارات:** `SalesTotalsTest` (أرقام: مجموع 10000، مرتجع 500، خصم 300، مشتريات 2000، مصروف 700 ⇒ إجمالي 9200، صافي 6500)؛ اختبار API للوردية والإغلاق اليومي يتحقق من المفاتيح الجديدة؛ حدّث اختبارات Flutter التي تفحص النص «إجمالي المبيعات».

---

### T6 — الرصيد داخل بطاقة الحساب

**ملفات:**
- `backend/app/Http/Controllers/Api/FinancialAccountController.php`
- `backend/app/Services/FinancialAccountBalanceQuery.php` (دالة جديدة)
- `windows_application/lib/features/finance_inventory_setup/models/finance_setup_models.dart` (`FinancialAccount`)
- `windows_application/lib/features/finance_inventory_setup/views/financial_accounts_screen.dart`
- اختبار: `backend/tests/Feature/FinancialAccountBalanceCardTest.php`

1. `FinancialAccountBalanceQuery`: أضف
   ```php
   /** رصيد الحساب + كل أبنائه (للحسابات الأب)، مرحّل فقط. */
   public function balanceWithChildren(int $tenantId, int $accountId): array
   ```
   اجمع IDs الأبناء بشكل متكرر عبر `parent_account_id`، ثم استعلام واحد:
   `SUM(lines.debit), SUM(lines.credit)` من `journal_entry_lines` join `journal_entries` حيث `entries.status='posted'` و`lines.financial_account_id IN (...)`. طبّق `normal_balance` للحساب نفسه. أرجع `['balance','totalDebit','totalCredit','lastMovementDate']`.
2. `show()`: أضف للرد `'balance' => ..., 'totalDebit' => ..., 'totalCredit' => ..., 'lastMovementDate' => ...`.
3. `index()`: أضف `balance` لكل صف باستعلام **واحد مجمّع** `GROUP BY lines.financial_account_id` لحسابات الصفحة الحالية فقط (ممنوع استعلام لكل حساب). للحساب الأب اجمع أرصدة أبنائه من نفس النتيجة.
4. Flutter `FinancialAccount`: حقول `balance`, `totalDebit`, `totalCredit`, `lastMovementDate` (nullable).
5. `_accountDetail()`: أضف أعلى البطاقة (قبل «الرمز») بطاقة كبيرة: **«الرصيد الحالي»** بالعملة `CurrencyFormatter`، وتحتها «إجمالي المدين / إجمالي الدائن / آخر حركة»، ولون أحمر إذا الرصيد عكس الطبيعة (سالب).
6. جدول الحسابات (`DataCell` سطر ~396): عمود «الرصيد».

**القبول:** فتح `1020 — الخزنة الرئيسية` يعرض الرصيد ويطابق دفتر الأستاذ.

---

### T7 — الفواتير بتاريخ سابق (كل أنواع الفواتير) مع سبب إجباري

**قرار العميل (2026-09-28):** أي فاتورة (شراء، بيع يدوي، بيع المصنع، مرتجع مبيعات/إشعار دائن) **مسموح** تنحط بتاريخ سابق **بشرط كتابة السبب**. **الفاتورة والمواد والنقد كلها بالتاريخ السابق**، ويبقى **تاريخ الإنشاء** (اليوم الفعلي) ظاهراً على الفاتورة. إذا يوم التاريخ السابق مُغلق ← مسموح مع تحذير.

**الوضع الحالي بالكود (سبب المشكلة):**
- فاتورة الشراء: القيد بـ `invoice_date` ✔، لكن `PurchasePostingOrchestrator::post()` يضع الدفع `paymentDate ?? today()` والاستلام `receiptDate ?? today()`، ونافذة `purchase_posting_dialog.dart` تبدأ التاريخين بـ `DateTime.now()`.
- فاتورة البيع اليدوية: القيد بـ `invoice_date` ✔، لكن `SalesInventoryMovementService::consume()` لا يمرّر `occurredAt` ← **خصم المواد من المخزن يُسجَّل بتاريخ اليوم** (`InventoryPostingService` يستخدم `$now`).
- لا يوجد أي حقل «سبب التاريخ السابق» بأي فاتورة.

**ملفات جديدة:**
- `backend/database/migrations/2026_10_08_000003_add_backdate_reason_to_invoices.php`
- `backend/app/Support/BackdatePolicy.php`
- `backend/tests/Feature/BackdatedInvoicesTest.php`
- `windows_application/lib/shared/widgets/backdate_reason_field.dart`

**ملفات معدّلة (باك إند):**
- `app/Http/Controllers/Api/SupplierInvoiceController.php` (التحقق ~سطر 112 + الرد ~سطر 261)
- `app/Services/SupplierInvoiceService.php` (الإنشاء/التعديل ~سطر 751)
- `app/Http/Controllers/Api/PurchaseController.php` (`post()` + الرد ~سطر 306)
- `app/Services/PurchasePostingOrchestrator.php`
- `app/Http/Controllers/Api/SalesInvoiceController.php` (`data()` ~سطر 256 + serialize ~سطر 251)
- `app/Services/SalesInvoiceService.php` (سطر 33 و57)
- `app/Services/SalesInvoicePostingService.php`
- `app/Services/SalesInvoiceInventoryConsumptionService.php` (~سطر 131–138)
- `app/Services/SalesInventoryMovementService.php` (`consume()` ودالة إرجاع المخزون للمرتجع)
- `app/Http/Controllers/Api/SalesCreditNoteController.php` (~سطر 158 و178) + `app/Services/SalesCreditNoteService.php`

**ملفات معدّلة (Flutter):**
- `features/purchasing/views/purchase_invoice_form_screen.dart` (`_invoiceDate` سطر 156، منتقي التاريخ ~549، الـ payload ~670)
- `features/purchasing/widgets/purchase_posting_dialog.dart`
- `features/purchasing/views/purchase_invoice_detail_screen.dart` (~سطر 83 و263–271) + `purchasing_center_screen.dart` (القائمة)
- `features/purchasing/models/purchasing_models.dart`
- `features/sales/views/sales_screens.dart` (منتقي التاريخ ~1418، الـ payload ~1185، التفاصيل ~513، القائمة ~307)
- `features/sales/models/sales_models.dart`
- (شاشات المصنع تستخدم نفس الشاشات عبر `routeScope` — تأكد أنها تتغير تلقائياً.)

**الخطوات (باك إند):**
1. الـ migration: لكل جدول من `supplier_invoices`, `sales_invoices`, `sales_credit_notes`:
   ```php
   $t->text('backdate_reason')->nullable();
   $t->foreignId('backdated_by')->nullable()->constrained('users')->nullOnDelete();
   ```
2. `BackdatePolicy`:
   ```php
   final class BackdatePolicy
   {
       /** يرجع السبب المنظّف أو null إذا التاريخ ليس سابقاً. يرمي خطأ إذا سابق بدون سبب. */
       public static function reason(?int $branchId, string $documentDate, ?string $reason, string $field = 'backdateReason'): ?string
       {
           if ($documentDate >= BranchLocalDate::today($branchId)) return null;
           $reason = trim((string) $reason);
           if (mb_strlen($reason) < 3) {
               throw ValidationException::withMessages([$field => 'تاريخ المستند سابق لليوم. اكتب سبب التاريخ السابق.']);
           }
           return $reason;
       }

       /** تحذير (لا يمنع) إذا اليوم مُغلق بإغلاق يومي. */
       public static function closedDayWarning(int $tenantId, ?int $branchId, string $date): ?array
       {
           if (! $branchId) return null;
           $closed = DB::table('daily_closings')->where('tenant_id', $tenantId)->where('branch_id', $branchId)
               ->whereDate('business_date', $date)->where('status', 'closed')->exists();
           return $closed ? ['code' => 'DAY_ALREADY_CLOSED', 'date' => $date,
               'message' => "تم الترحيل بتاريخ يوم مُغلق ({$date}). ستظهر كحركة بعد الإغلاق في تقرير ذلك اليوم."] : null;
       }
   }
   ```
3. **عند الحفظ (إنشاء/تعديل)** لكل نوع فاتورة: أضف للتحقق `'backdateReason' => ['nullable', 'string', 'max:1000']`، ثم في الـ service:
   ```php
   $reason = BackdatePolicy::reason($branchId, $date, $data['backdateReason'] ?? null);
   // خزّن: 'backdate_reason' => $reason, 'backdated_by' => $reason ? $actorId : null
   ```
   (لفاتورة الشراء `$date = invoiceDate`، للبيع `invoiceDate`، للمرتجع `creditDate`.)
4. **عند الترحيل** (يحمي المسودات القديمة): في `PurchasePostingOrchestrator::post()` و`SalesInvoicePostingService` (قبل `assertPostingAllowed`) وخدمة ترحيل المرتجع: إذا التاريخ < اليوم و`backdate_reason` فارغ ← نفس رسالة الخطأ.
5. **كل الآثار بتاريخ الفاتورة:**
   - شراء — `PurchasePostingOrchestrator::post()`:
     - `'paymentDate' => $invoice->invoice_date` (تجاهل `$paymentDate` القادم من الواجهة للدفعة التلقائية المرتبطة بالترحيل).
     - `$this->receiveRemainingInventory(..., $invoice->invoice_date)`.
     - سند الدفع (`createPostedSupplierPaymentVoucher`) يأخذ `payment_date` تلقائياً ✔.
   - بيع — `SalesInventoryMovementService::consume()`: أضف باراميتر أخير `?string $occurredAt = null` وضع `'occurredAt' => $occurredAt` في مصفوفة `post()`. في `SalesInvoiceInventoryConsumptionService::consume()` مرّر `$invoice->invoice_date`. **لا تغيّر** مسار POS (`order_item`) — يبقى بدون تاريخ = الآن.
   - مرتجع/إشعار دائن: دالة إرجاع المخزون (`return_in`) تأخذ `occurredAt = $note->credit_date`.
   - تحصيل نقدي مباشر لفاتورة البيع: الشرط الحالي `paymentDate === invoice_date` بـ `SalesInvoicePostAndCollectService` سطر 62 صحيح — أبقه.
6. **التحذير:** بعد الترحيل اجمع `BackdatePolicy::closedDayWarning()` للتاريخ وأرجعها بالرد `warnings: [...]` (في `PurchaseController::post`, `SalesInvoiceController::post`, وترحيل المرتجع). سجّل `audit('invoice.backdated', ...)` مع السبب والتاريخ الأصلي وتاريخ الإنشاء.
7. **الرد (serialize):** أضف لكل فاتورة: `createdAt` (Y-m-d H:i بتوقيت الفرع)، `backdateReason`, `isBackdated` (= `invoice_date < DATE(created_at)`).

**الخطوات (Flutter):**
1. `backdate_reason_field.dart`: ويدجت يأخذ `DateTime documentDate` و`TextEditingController`؛ إذا `documentDate` قبل اليوم يظهر حقل إجباري **«سبب التاريخ السابق»** مع نص مساعد «الفاتورة والمواد والنقد ستُسجَّل بتاريخ {date}»، وإلا لا يظهر شيء.
2. استخدمه في نموذج فاتورة الشراء وفاتورة البيع (ونموذج المرتجع إن وُجد منتقي تاريخ)، وامنع الحفظ إذا الحقل ظاهر وفارغ، وأرسل `backdateReason` في الـ payload.
3. `purchase_posting_dialog.dart`: **احذف منتقيي «تاريخ الاستلام» و«تاريخ الدفع»** واعرض سطر قراءة فقط: «التاريخ المحاسبي: {تاريخ الفاتورة} (الاستلام والدفع بنفس التاريخ)». أبقِ حقلي `paymentDate/receiptDate` في `PurchasePostingChoice` = تاريخ الفاتورة للتوافق.
4. شاشات التفاصيل: بجانب «تاريخ الفاتورة» أضف **«تاريخ الإنشاء»** (`createdAt` بالساعة)، وإذا `isBackdated` أضف شارة برتقالية **«بتاريخ سابق»** + **«سبب التاريخ السابق: …»**.
5. شاشات القوائم (شراء/بيع): شارة صغيرة «بتاريخ سابق» بجانب التاريخ.
6. اعرض `warnings` بعد الترحيل كـ SnackBar برتقالي.

**اختبارات (`BackdatedInvoicesTest`):**
- فاتورة شراء بتاريخ 2026-09-20 بدون سبب ← 422 `backdateReason`.
- نفس الفاتورة مع سبب ← تُحفظ، `backdate_reason` مخزّن، `created_at` = اليوم؛ عند الترحيل مع دفع: قيد الفاتورة + قيد الدفعة + `stock_movements.occurred_at` + `purchase_receipts.receipt_date` كلها = 2026-09-20.
- فاتورة بيع يدوية بتاريخ سابق مع سبب ← قيد البيع وحركات `sale_consumption` بتاريخ الفاتورة.
- فاتورة بتاريخ اليوم ← لا يُطلب سبب.
- مسودة قديمة بتاريخ سابق بلا سبب ← الترحيل يرفض.
- يوم مغلق ← ترحيل ناجح + `warnings[0].code = DAY_ALREADY_CLOSED` + تظهر في `lateActivityAfterClose` لذلك اليوم.
- طلب POS عادي ← حركة المخزون بتاريخ الآن (لم يتأثر).

**ملاحظة للمنفّذ:** تكلفة المواد في البيع بتاريخ سابق تُحسب بمتوسط التكلفة الحالي (سلوك النظام الحالي) — لا تحاول إعادة حساب متوسط تاريخي.

### T8 — تبويبات تفاصيل المادة (الحركات / الوصفات / الشراء)

**ملفات:**
- `backend/app/Http/Controllers/Api/InventoryItemController.php` (`purchaseHistory` ~سطر 379، `recipeUsage` ~سطر 294)
- `windows_application/lib/features/inventory/views/item_details_screen.dart`
- `windows_application/lib/features/inventory/controllers/inventory_cubit.dart` + state
- اختبار: `backend/tests/Feature/InventoryItemTabsTest.php`

1. **أولاً** نفّذ نتيجة T0-1: إذا النسخة قديمة، انشر وأعد الفحص مع العميل — قد تُحل المشكلة بالكامل.
2. `purchaseHistory()` لمواد الكافيه: وحّدها مع منطق المصنع — مصدرها `supplier_invoice_lines` + `supplier_invoices` (حالة ليست `draft`/`cancelled`، و`deleted_at IS NULL`) مع `received_quantity` وحالة «مستلم / مستلم جزئياً / غير مستلم»، مع احترام `InventoryAccess::scopeWarehouseBranches` للكافيه و`owner_branch_id` للمصنع. أبقِ نفس مفاتيح JSON وأضف `receivedQuantity`, `receiptStatus`, `invoiceId`.
3. `recipeUsage()`: إذا `material.owner_branch_id !== null` أعد المنطق كما هو؛ وإلا بعد جمع `variantLines` و`modifierLines`، إذا كانت النتيجة فارغة ابحث عن مواد بنفس `sku` (أو نفس `name_ar`) لها وصفات وأرجع `meta.hint = 'هذه المادة غير مستخدمة بوصفات، يوجد مادة مشابهة (#id) مستخدمة في N وصفة'` — لكشف ازدواجية المواد بعد فصل المصنع.
4. Flutter `item_details_screen.dart`:
   - أضف `didUpdateWidget`: إذا `oldWidget.itemId != widget.itemId` صفّر الأعلام الثلاثة وأعد `loadItemDetails` وارجع للتبويب 0.
   - في الـ cubit: عند `loadItemDetails` صفّر `itemRecipeUsage`, `itemRecipeUsageLoaded`, `itemMovementHistory`, `itemPurchaseHistory` (حتى لا تظهر بيانات مادة سابقة).
   - في `_recipeUsage` و`_purchaseHistory` و`_movementHistory`: إذا `state.error != null` اعرض `ManagementMessage(error: true, onRetry: ...)` بدل «لا توجد…».
   - اعرض `meta.hint` إن وُجد.
5. سجل الحركات: اعرض رقم المرجع (فاتورة/استلام/وردية/إنتاج) كرابط حسب `reference_type`.

**اختبارات:** مادة كافيه عليها فاتورة مرحّلة غير مستلمة تظهر في سجل الشراء بحالة «غير مستلم»؛ مادة مستخدمة بوصفة منتج تظهر في استخدام الوصفات.

---

### T9 — مراجعة التسميات المالية (قاموس موحّد)

**ملف جديد:** `docs/FINANCE_GLOSSARY_AR.md` بالجدول أدناه، ثم طبّقه.

| الحالي | المعتمد |
|---|---|
| `2000 الحسابات الدائنة` | `الذمم الدائنة – الموردون` |
| `1010 درج النقدية` | `صندوق نقطة البيع` |
| موقع `Main Safe` | `الخزنة الرئيسية` |
| موقع `Cash Drawer` / `{branch} Cash Drawer` | `صندوق نقطة البيع` / `صندوق {اسم الفرع}` |
| موقع `Bank` | `البنك` |
| طريقة دفع `Cash` | `نقدي` |
| `Supplier Payment — {x}` | `دفعة مورد — {x}` |
| `Supplier Invoice {ref} — {x}` | `فاتورة شراء {ref} — {x}` |
| `Customer Payment — {x}` | `تحصيل من عميل — {x}` |
| `Customer Refund — {x}` | `رد مبلغ لعميل — {x}` |
| `POS Sale — Order #{n}` | `بيع نقطة البيع — طلب رقم {n}` |
| `Refund — {reason}` | `مرتجع — {reason}` |
| `Sales Credit Note {n}` | `إشعار دائن مبيعات {n}` |
| `Cash transfer {id}` | `تحويل نقدي {id}` |
| `User/System shift close {id}` | `تحويل إغلاق الوردية {رقم الوردية}` |
| `Close transfer for …` / `Continuation of …` | `تحويل إغلاق الوردية …` / `استمرار الوردية …` |
| `Reversal of {n}` | `عكس القيد {n}` |
| `Opening float` | `العهدة الافتتاحية` |
| `Supplier payment {id}` (حركة وردية) | `دفعة مورد {رقم الدفعة}` |
| «إجمالي المبيعات» بمعنى المبلغ قبل الخصم | «مجموع المبيعات» |
| «صافي المبيعات» بمعنى بعد الخصم والمرتجع | «الإجمالي» |

**الخطوات:**
1. عدّل النصوص في: `SupplierPaymentService.php` (157, 169)، `SupplierInvoiceService.php` (193)، `CustomerPaymentService.php` (118–121)، `CustomerRefundService.php` (88–91)، `PaymentController.php` (303)، `RefundController.php` (104, 130)، `SalesCreditNotePostingService.php` (162)، `CashTransferService.php` (44)، `ShiftCloseTransferService.php` (74)، `HistoricalShiftCloseService.php` (~124, ~145)، `JournalEntryService.php` (151)، `ShiftSnapshotService.php` (75)، `ReportsOverviewController.php` (193).
   - لكشف الباقي: `grep -rn "'description' => \"[A-Z]\|'description' => '[A-Z]" backend/app` و`grep -rn "ValidationException::withMessages(\[.*=> '[A-Z]" backend/app/Services backend/app/Http` — عرّب رسائل التحقق الظاهرة للمستخدم (ابدأ بـ `PurchasePostingOrchestrator`, `SupplierPaymentService`, `DailyClosingService`, `FinancialAccountService`, `FinancialAccountBalanceQuery`).
2. `FinancialSetupService`: حدّث الأسماء الافتراضية (2000، 1010، المواقع، طريقة الدفع) للمستأجرين الجدد.
3. migration للبيانات الموجودة `2026_10_08_000002_arabize_default_finance_names.php`: حدّث **فقط** الصفوف التي ما زالت بالاسم الافتراضي الإنجليزي بالضبط (مثلاً `WHERE code='MAIN-SAFE' AND name='Main Safe'`) حتى لا نكتب فوق اسم غيّره العميل. لا تغيّر `code` أبداً.
4. **لا تعدّل أوصاف القيود القديمة المرحّلة** (سجل تاريخي). التغيير للقيود الجديدة فقط.
5. Flutter: ابحث عن نصوص مالية إنجليزية ظاهرة `grep -rn "Text('[A-Z]" windows_application/lib/features/finance_inventory_setup windows_application/lib/features/purchasing windows_application/lib/features/shift` وعرّبها حسب القاموس.

**القبول:** تفاصيل «دفعة مورد» تعرض الوصف عربياً بالكامل، و2000 باسم «الذمم الدائنة – الموردون».

---

## 4. ترتيب التنفيذ والاعتماديات

```
T0 (تشخيص + تأكيد النسخة)
 └─ T1 (حساب الفروقات)  ─┬─ T2 (إغلاق الوردية) ── T3 (الإغلاق التاريخي)
                          └─ T4 (الإغلاق اليومي)
T5 (تعريفات المبيعات)   — مستقل، بعد T2 لتفادي تعارض ShiftSnapshotService
T6 (رصيد البطاقة)       — مستقل
T7 (الفواتير بتاريخ سابق) — مستقل
T8 (تبويبات المادة)     — بعد نتيجة T0
T9 (التسميات)           — آخر شي (يلمس ملفات كثيرة)
```
الأولوية للعميل: **T2 → T4 → T7 → T6 → T5 → T3 → T8 → T9**. إذا الوقت ضيق، T1+T2+T7 تحل الشكاوى المانعة للعمل.

---

## 5. اختبار القبول اليدوي مع العميل (بعد النشر)

1. فتح وردية بعهدة 50,000 ← بيع نقدي 30,000 ← دفعة مورد من الصندوق 5,000 ← عدّ 74,000 (عجز 1,000) ← اختيار سبب ← **يغلق**. التقرير يعرض: الفرق −1,000 مرحّل إلى 6180، وتحويل (74,000 − العهدة) إلى الخزنة الرئيسية.
2. فتح بطاقة `1020 الخزنة الرئيسية` ← الرصيد زاد بمبلغ التحويل بنفس التاريخ. فتح `6180` ← رصيده 1,000 مدين.
3. الإغلاق اليومي لنفس اليوم ← الفرق 0 (لأن فرق الوردية مرحّل) ← يغلق.
4. تقرير الوردية/اليوم يعرض: مجموع المبيعات، الإجمالي، صافي المبيعات بالأرقام المتوقعة.
5. فاتورة شراء بتاريخ الأمس بدون سبب ← يرفض ويطلب السبب. مع السبب ← تفاصيلها: تاريخ الفاتورة = الأمس، تاريخ الإنشاء = اليوم، شارة «بتاريخ سابق» + السبب، والدفعة والاستلام وحركة المواد = الأمس. نفس الاختبار لفاتورة بيع يدوية (خصم المواد بتاريخ الأمس). إذا الأمس مغلق ← تحذير برتقالي ويظهر بتقرير الأمس كحركة بعد الإغلاق.
6. تفاصيل مادة مستخدمة بوصفة ← تبويب استخدام الوصفات فيه المنتجات، وسجل الشراء فيه الفاتورة.
7. إغلاق وردية بتاريخ سابق ← التحويل للخزنة بتاريخ ذلك اليوم.
