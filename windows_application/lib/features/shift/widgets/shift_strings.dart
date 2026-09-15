/// Every Arabic string the shift module renders, in one place.
///
/// The module follows the Finance/Inventory convention of shipping its copy
/// with the feature rather than through `app_*.arb`. Centralizing it here
/// keeps a future migration to `AppLocalizations` a mechanical move: no
/// screen or widget in `lib/features/shift` holds a literal of its own.
abstract final class ShiftStrings {
  // Module navigation
  static const String module = 'الوردية';
  static const String tabCurrent = 'الوردية الحالية';
  static const String tabHistory = 'سجل الورديات';

  // Current shift
  static const String currentTitle = 'إدارة الوردية';
  static const String currentSubtitle =
      'تابع تفاصيل ورديتك وأكمل إجراءات الإغلاق عند نهاية العمل';
  static const String shiftNumber = 'رقم الوردية';
  static const String branch = 'الفرع';
  static const String cashier = 'الكاشير';
  static const String employeeCode = 'الرقم الوظيفي';
  static const String openedAt = 'وقت الفتح';
  static const String closedAt = 'وقت الإغلاق';
  static const String date = 'التاريخ';
  static const String duration = 'مدة الوردية';
  static const String status = 'الحالة';
  static const String statusOpen = 'مفتوحة';
  static const String statusClosed = 'مغلقة';

  // KPIs
  static const String kpiSectionTitle = 'مؤشرات الوردية';
  static const String grossSales = 'إجمالي المبيعات';
  static const String netSales = 'صافي المبيعات';
  static const String orderCount = 'عدد الطلبات';
  static const String averageOrder = 'متوسط قيمة الطلب';
  static const String cashSales = 'المبيعات النقدية';
  static const String cardSales = 'مبيعات البطاقة';
  static const String transferSales = 'تحويل / دفع آخر';
  static const String totalDiscounts = 'إجمالي الخصومات';
  static const String totalRefunds = 'إجمالي المرتجعات';
  static const String refundCount = 'عدد المرتجعات';
  static const String cancelledOrders = 'عدد الطلبات الملغاة';
  static const String afterDiscountsAndRefunds = 'بعد الخصومات والمرتجعات';
  static const String perOrderAverage = 'لكل طلب مكتمل';
  static const String ofGrossSales = 'من إجمالي المبيعات';
  static const String ordersPaidInCash = 'طلب مدفوع نقدًا';
  static const String ordersPaidByCard = 'طلب مدفوع بالبطاقة';
  static const String ordersPaidOther = 'عملية دفع أخرى';
  static const String refundedOperations = 'عملية مرتجعة';
  static const String cancelledBeforePayment = 'ألغيت قبل الدفع';
  static const String discountPoliciesApplied = 'سياسة خصم مطبقة';

  // Payments
  static const String paymentBreakdown = 'تفصيل طرق الدفع';
  static const String paymentCash = 'نقدي';
  static const String paymentCard = 'بطاقة';
  static const String paymentTransfer = 'تحويل';
  static const String paymentCustomerCredit = 'رصيد عميل';
  static const String paymentOther = 'طرق أخرى';
  static const String paymentMethod = 'طريقة الدفع';
  static const String transactions = 'عدد العمليات';
  static const String amount = 'القيمة';
  static const String percentage = 'النسبة';
  static const String total = 'الإجمالي';
  static const String operationsUnit = 'عملية';

  // Orders
  static const String ordersStatus = 'حالة الطلبات';
  static const String ordersCompleted = 'مكتملة';
  static const String ordersPaid = 'مدفوعة';
  static const String ordersPreparing = 'قيد التحضير';
  static const String ordersOpen = 'مفتوحة';
  static const String ordersCancelled = 'ملغاة';
  static const String ordersPartiallyRefunded = 'مرتجعة جزئيًا';
  static const String ordersFullyRefunded = 'مرتجعة بالكامل';
  static const String viewOrder = 'عرض الطلب';
  static const String viewOpenOrders = 'عرض الطلبات المفتوحة';
  static const String allOrdersSettled =
      'جميع طلبات الوردية مكتملة ولا يوجد طلب مفتوح';

  static String unfinishedOrdersWarning(int count) => count == 1
      ? 'يوجد طلب واحد غير مكتمل'
      : 'يوجد $count طلبات غير مكتملة';

  // Cash drawer
  static const String cashDrawer = 'الصندوق';
  static const String openingFloat = 'الرصيد الافتتاحي';
  static const String cashRefunds = 'المرتجعات النقدية';
  static const String cashWithdrawals = 'سحوبات نقدية';
  static const String cashDeposits = 'إيداعات نقدية';
  static const String cashExpenses = 'مصروفات من الصندوق';
  static const String expectedNow = 'المبلغ المتوقع الحالي';
  static const String expectedCash = 'المبلغ المتوقع';
  static const String actualCash = 'المبلغ الفعلي';
  static const String cashDifference = 'فرق الصندوق';
  static const String cashNotCountedYet =
      'يُحتسب المبلغ الفعلي أثناء جرد الصندوق في خطوة الإغلاق';
  static const String cashMatched = 'الصندوق متطابق';
  static const String cashShortage = 'عجز في الصندوق';
  static const String cashSurplus = 'زيادة في الصندوق';

  // Bar count
  static const String barCount = 'جرد البار';
  static const String barCountStatus = 'حالة جرد البار';
  static const String warehouse = 'المخزن';
  static const String itemsToCount = 'المواد المطلوب جردها';
  static const String itemsCounted = 'تم جرد';
  static const String lastCount = 'آخر جرد';
  static const String currentDifferences = 'عدد الفروقات الحالية';
  static const String barCountNotStarted = 'لم يبدأ الجرد بعد';
  static const String barCountInProgress = 'الجرد قيد التنفيذ';
  static const String barCountComplete = 'اكتمل الجرد';
  static const String item = 'المادة';
  static const String itemCode = 'الرمز';
  static const String category = 'الفئة';
  static const String unit = 'الوحدة';
  static const String theoreticalQty = 'الكمية النظرية';
  static const String actualQty = 'الكمية الفعلية';
  static const String difference = 'الفرق';
  static const String differenceStatus = 'حالة الفرق';
  static const String estimatedDifferenceValue = 'قيمة الفرق التقديرية';
  static const String differenceNote = 'ملاحظة الفرق';
  static const String noteHint = 'اكتب سبب الفرق لهذه المادة...';
  static const String statusUncounted = 'غير مجرود';
  static const String statusMatch = 'متطابق';
  static const String statusShortage = 'نقص';
  static const String statusSurplus = 'زيادة';
  static const String negativeTheoretical = 'الرصيد النظري سالب';
  static const String negativeTheoreticalDetail =
      'الرصيد النظري لهذه المادة سالب — يمكن متابعة الجرد وتسجيل الكمية '
      'الفعلية بشكل طبيعي.';
  static const String searchItem = 'بحث عن مادة';
  static const String filterAll = 'الكل';
  static const String filterUncounted = 'غير مجرود';
  static const String filterMatched = 'متطابق';
  static const String filterShortage = 'نقص';
  static const String filterSurplus = 'زيادة';
  static const String filterDifferencesOnly = 'فروقات فقط';
  static const String sortBy = 'ترتيب حسب';
  static const String sortByName = 'اسم المادة';
  static const String sortByCategory = 'الفئة';
  static const String sortByLargestDifference = 'الأكبر فرقًا';
  static const String fillWithTheoretical = 'تعبئة بالقيمة النظرية';
  static const String clearValue = 'مسح';
  static const String nextItem = 'التالي';
  static const String acceptAllMatching = 'اعتماد كل المواد المتطابقة';
  static const String acceptAllMatchingConfirmTitle =
      'اعتماد المواد غير المجرودة';
  static const String confirm = 'اعتماد';
  static const String saveCountAndContinue = 'حفظ الجرد والمتابعة';

  static String acceptAllMatchingConfirmBody(int count) =>
      'سيتم تعبئة $count مادة غير مجرودة بالكمية النظرية واعتبارها متطابقة. '
      'يمكنك تعديل أي مادة بعد ذلك.';

  static String countedOf(int counted, int total) =>
      '$counted من $total مادة تم جردها';

  static String uncountedRemaining(int count) => count == 1
      ? 'لم يتم جرد مادة واحدة بعد'
      : 'لم يتم جرد $count مواد بعد';

  // Alerts and readiness
  static const String shiftAlerts = 'تنبيهات الوردية';
  static const String noBlockingIssues = 'لا توجد مشاكل تمنع الإغلاق';
  static const String cannotCloseNow = 'لا يمكن إغلاق الوردية حاليًا';
  static const String closingReadiness = 'جاهزية الإغلاق';
  static const String readyToClose = 'جاهز لإغلاق الوردية';
  static const String needsReview = 'توجد فروقات تحتاج إلى مراجعة';

  // Progress
  static const String shiftProgress = 'مراحل الوردية';
  static const String stageOpened = 'فتح الوردية';
  static const String stageSelling = 'بيع';
  static const String stageOperations = 'مراجعة العمليات';
  static const String stageCashCount = 'جرد الصندوق';
  static const String stageBarCount = 'جرد البار';
  static const String stageFinalReview = 'المراجعة النهائية';
  static const String stageClosed = 'الإغلاق';

  // Actions
  static const String backToPos = 'العودة إلى نقطة البيع';
  static const String startClosing = 'بدء إغلاق الوردية';
  static const String finishOrdersFirst =
      'تأكد من إنهاء جميع الطلبات قبل الإغلاق';
  static const String back = 'رجوع';
  static const String previous = 'السابق';
  static const String next = 'التالي';
  static const String cancelAndReturn = 'إلغاء والعودة';
  static const String autoSaved = 'تم الحفظ تلقائيًا';
  static const String print = 'طباعة';
  static const String printShiftReport = 'طباعة تقرير الوردية';
  static const String exportPdf = 'تصدير PDF';
  static const String viewReport = 'عرض التقرير';
  static const String details = 'تفاصيل';
  static const String retry = 'إعادة المحاولة';
  static const String close = 'إغلاق';

  // No open shift and opening
  static const String noOpenShift = 'لا توجد وردية مفتوحة';
  static const String noOpenShiftBody =
      'لم يتم فتح وردية على هذا الجهاز بعد. افتح وردية جديدة لبدء تسجيل '
      'الطلبات على نقطة البيع.';
  static const String openShiftTitle = 'فتح وردية جديدة';
  static const String systemTime = 'وقت النظام';
  static const String openingFloatLabel =
      'المبلغ الموجود في درج الكاشير عند بداية الوردية';
  static const String openingFloatHint = 'مثال: 5,000';
  static const String openingNotes = 'ملاحظات فتح الوردية';
  static const String openingNotesHint =
      'أي ملاحظة عن حالة الدرج أو تسليم النقدية (اختياري)';
  static const String openShift = 'فتح الوردية';
  static const String confirmOpenShift = 'تأكيد فتح الوردية';
  static const String lastShift = 'آخر وردية';
  static const String openingFloatRequired =
      'أدخل الرصيد الافتتاحي قبل فتح الوردية';
  static const String amountMustBeNumeric = 'أدخل مبلغًا رقميًا صحيحًا';
  static const String amountCannotBeNegative = 'لا يمكن أن يكون المبلغ سالبًا';

  // Closing wizard
  static const String closingTitle = 'إغلاق الوردية';
  static const String step1 = 'ملخص ومراجعة العمليات';
  static const String step2 = 'جرد الصندوق';
  static const String step3 = 'جرد البار';
  static const String step4 = 'المراجعة النهائية';
  static const String step5 = 'الإغلاق';

  static const String operationsReview = 'مراجعة عمليات الوردية';
  static const String shiftInformation = 'معلومات الوردية';
  static const String salesSummary = 'ملخص المبيعات';
  static const String ordersValidation = 'التحقق من الطلبات';
  static const String pendingOperations = 'عمليات معلقة';
  static const String noPendingOperations =
      'لا توجد عمليات معلقة على هذه الوردية';
  static const String blockedByOpenOrders =
      'لا يمكن الإغلاق قبل معالجة الطلبات المفتوحة';
  static const String pendingRefund = 'مرتجع بانتظار الاعتماد';
  static const String pendingExpense = 'مصروف بانتظار الموافقة';
  static const String pendingCustomerPayment = 'دفعة عميل غير مكتملة';
  static const String pendingCashTransfer = 'تحويل نقدي مفتوح';
  static const String pendingBarCount = 'جرد بار غير مكتمل';

  static const String cashCountTitle = 'العد الفعلي للصندوق';
  static const String cashCountSubtitle =
      'أدخل المبلغ الفعلي الموجود في درج الكاشير الآن قبل احتساب الفرق';
  static const String actualCashLabel = 'المبلغ الفعلي الموجود في الدرج';
  static const String enterAmountDirectly = 'إدخال المبلغ مباشرة';
  static const String countByDenomination = 'عد حسب الفئات';
  static const String denomination = 'الفئة';
  static const String pieces = 'العدد';
  static const String lineTotal = 'المجموع';
  static const String countedTotal = 'الإجمالي المعدود';
  static const String applyCountedAmount = 'اعتماد المبلغ';
  static const String cashReconciliation = 'مطابقة الصندوق';
  static const String cashDifferenceReason = 'سبب فرق الصندوق';
  static const String cashDifferenceReasonRequired =
      'اختر سبب فرق الصندوق قبل المتابعة';
  static const String reasonChangeError = 'خطأ في الباقي';
  static const String reasonUnrecordedTransaction = 'عملية غير مسجلة';
  static const String reasonUnrecordedWithdrawal = 'سحب نقدي غير مسجل';
  static const String reasonUnrecordedExpense = 'مصروف غير مسجل';
  static const String reasonUnknownSurplus = 'زيادة غير معروفة';
  static const String reasonUnknownShortage = 'عجز غير معروف';
  static const String reasonOther = 'سبب آخر';
  static const String additionalDetails = 'تفاصيل إضافية';
  static const String additionalDetailsHint =
      'اشرح ما حدث بإيجاز ليظهر في تقرير الوردية';
  static const String additionalDetailsRequired =
      'اكتب تفاصيل السبب عند اختيار سبب آخر';
  static const String actualCashRequired =
      'أدخل المبلغ الفعلي في الدرج قبل المتابعة';

  static const String finalReviewTitle = 'المراجعة النهائية لإغلاق الوردية';
  static const String differencesSection = 'الفروقات';
  static const String noDifferences = 'لا توجد فروقات في هذه الوردية';
  static const String closingNotes = 'ملاحظات إغلاق الوردية';
  static const String closingNotesHint =
      'أي ملاحظة عن سير الوردية أو أسباب الفروقات (اختياري)';
  static const String closingNotesSaved =
      'سيتم حفظ هذه الملاحظات ضمن تقرير الوردية.';
  static const String confirmCloseShift = 'تأكيد إغلاق الوردية';
  static const String closeShiftIrreversible =
      'بعد إغلاق الوردية لن يمكن تسجيل طلبات أو مدفوعات جديدة عليها.';
  static const String confirmReviewedAcknowledgement =
      'أؤكد أنني راجعت المبلغ النقدي والجرد';
  static const String closeShift = 'إغلاق الوردية';
  static const String backToReview = 'العودة للمراجعة';
  static const String barDifferenceCount = 'عدد فروقات البار';

  static const String closedSuccessfully = 'تم إغلاق الوردية بنجاح';
  static const String closedSuccessfullyBody =
      'تم حفظ ملخص الوردية وجرد الصندوق وجرد البار ضمن تقرير الإغلاق.';
  static const String backToHistory = 'العودة إلى سجل الورديات';

  // History
  static const String historyTitle = 'سجل الورديات';
  static const String historySubtitle =
      'راجع الورديات المغلقة وفروقات الصندوق والجرد لكل وردية';
  static const String searchHistoryHint = 'بحث برقم الوردية أو اسم الكاشير';
  static const String period = 'الفترة';
  static const String periodToday = 'اليوم';
  static const String periodYesterday = 'أمس';
  static const String periodThisWeek = 'هذا الأسبوع';
  static const String periodThisMonth = 'هذا الشهر';
  static const String periodCustom = 'مخصص';
  static const String allCashiers = 'كل الكاشيرين';
  static const String allBranches = 'كل الفروع';
  static const String allStatuses = 'كل الحالات';
  static const String differenceFilter = 'فرق الصندوق';
  static const String differenceAll = 'الكل';
  static const String differenceMatched = 'متطابق';
  static const String differenceShort = 'عجز';
  static const String differenceOver = 'زيادة';
  static const String clearFilters = 'مسح عوامل التصفية';
  static const String shiftsCount = 'عدد الورديات';
  static const String totalNetSales = 'إجمالي صافي المبيعات';
  static const String totalCashDifferences = 'إجمالي فروقات الصندوق';
  static const String averageShiftDuration = 'متوسط مدة الوردية';
  static const String barDifferences = 'فروقات البار';
  static const String historyEmpty = 'لا توجد ورديات مطابقة لعوامل التصفية';
  static const String historyEmptyHint =
      'جرّب توسيع الفترة الزمنية أو مسح عوامل التصفية.';

  static String pageOf(int page, int pages) => 'صفحة $page من $pages';

  // Report
  static const String reportTitle = 'تقرير إغلاق الوردية';
  static const String reportNumber = 'رقم التقرير';
  static const String reportDate = 'تاريخ التقرير';
  static const String reportSectionShift = 'معلومات الوردية';
  static const String reportSectionSales = 'ملخص المبيعات';
  static const String reportSectionOrders = 'حالة الطلبات';
  static const String reportSectionPayments = 'تفاصيل طرق الدفع';
  static const String reportSectionCash = 'الصندوق';
  static const String reportSectionCashMovements = 'حركات الصندوق';
  static const String reportSectionCashDifference = 'فرق الصندوق';
  static const String reportSectionBarCount = 'جرد البار';
  static const String reportSectionBarDifferences = 'فروقات المواد';
  static const String reportSectionRefunds = 'المرتجعات';
  static const String reportSectionDiscounts = 'الخصومات';
  static const String reportSectionNotes = 'الملاحظات';
  static const String reportSectionClosing = 'معلومات الإغلاق';
  static const String movementType = 'النوع';
  static const String movementTime = 'الوقت';
  static const String movementDescription = 'الوصف';
  static const String movementValue = 'القيمة';
  static const String movementOpeningFloat = 'رصيد افتتاحي';
  static const String movementCashSale = 'بيع نقدي';
  static const String movementCashRefund = 'مرتجع نقدي';
  static const String movementWithdrawal = 'سحب نقدي';
  static const String movementDeposit = 'إيداع نقدي';
  static const String movementExpense = 'مصروف نقدي';
  static const String openedBy = 'تم الفتح بواسطة';
  static const String closedBy = 'تم الإغلاق بواسطة';
  static const String noNotes = 'لا توجد ملاحظات.';
  static const String noReasonRecorded = 'لم يتم تسجيل سبب للفرق.';
  static const String noCashDifference = 'لا يوجد فرق في الصندوق.';
  static const String noBarDifferences = 'لا توجد فروقات في جرد البار.';
  static const String noRefunds = 'لا توجد مرتجعات في هذه الوردية.';
  static const String noDiscounts = 'لا توجد خصومات في هذه الوردية.';
  static const String printLayoutA4 = 'تقرير A4';
  static const String printLayoutReceipt = 'إيصال حراري';
  static const String printPreview = 'معاينة الطباعة';
  static const String closePreview = 'إغلاق المعاينة';
  static const String reportNotFound = 'تعذر العثور على تقرير هذه الوردية';
  static const String discountPolicy = 'سياسة الخصم';
  static const String refundReason = 'السبب';
  static const String orderNumber = 'رقم الطلب';

  // Async states
  static const String loadingShift = 'جاري تحميل بيانات الوردية...';
  static const String loadingHistory = 'جاري تحميل سجل الورديات...';
  static const String errorLoadingShift = 'تعذر تحميل بيانات الوردية';
  static const String errorLoadingHistory = 'تعذر تحميل سجل الورديات';
  static const String errorHint =
      'تحقق من اتصال الجهاز بالخادم ثم أعد المحاولة.';

  // Demo scenario switcher
  static const String demoScenario = 'سيناريو العرض';
  static const String scenarioBalanced = 'إغلاق مطابق';
  static const String scenarioCashShortage = 'عجز في الصندوق';
  static const String scenarioCashSurplus = 'زيادة في الصندوق';
  static const String scenarioStockVariance = 'فروقات في البار';
  static const String scenarioNegativeStock = 'رصيد نظري سالب';
  static const String scenarioOpenOrder = 'طلب مفتوح يمنع الإغلاق';
  static const String scenarioIncompleteCount = 'جرد غير مكتمل';
  static const String scenarioNoShift = 'بدون وردية مفتوحة';
  static const String scenarioLoading = 'حالة التحميل';
  static const String scenarioError = 'حالة الخطأ';
}
