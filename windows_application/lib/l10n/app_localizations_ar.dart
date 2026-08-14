// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'نظام كافيه 618';

  @override
  String get language => 'اللغة';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageSelection => 'اختر اللغة';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonRefresh => 'تحديث';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String get commonError => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get commonNoData => 'لا توجد بيانات متاحة.';

  @override
  String get commonUnknown => 'غير معروف';

  @override
  String get commonActive => 'نشط';

  @override
  String get commonInactive => 'غير نشط';

  @override
  String get commonAvailable => 'متاح';

  @override
  String get commonSoldOut => 'نفد';

  @override
  String get commonYes => 'نعم';

  @override
  String get commonNo => 'لا';

  @override
  String get commonBack => 'رجوع';

  @override
  String get navigationDashboard => 'لوحة التحكم';

  @override
  String get navigationPos => 'نقطة البيع';

  @override
  String get navigationOrders => 'الطلبات';

  @override
  String get navigationCustomers => 'العملاء';

  @override
  String get navigationDiscounts => 'الخصومات';

  @override
  String get navigationMenuManagement => 'إدارة القائمة';

  @override
  String get navigationInventory => 'المخزون';

  @override
  String get navigationReports => 'التقارير';

  @override
  String get navigationSettings => 'الإعدادات';

  @override
  String get operationalHub => 'مركز العمليات';

  @override
  String get tooltipCart => 'السلة';

  @override
  String get tooltipRefreshScreenData => 'تحديث بيانات الشاشة';

  @override
  String get tooltipNotifications => 'الإشعارات';

  @override
  String get tooltipProfile => 'الملف الشخصي';

  @override
  String get invalidCatalogRoute => 'مسار الكتالوج المطلوب غير صالح.';

  @override
  String get productsEmptyMessage => 'لا توجد منتجات.';

  @override
  String get ordersEmptyMessage => 'لا توجد طلبات.';

  @override
  String get menusEmptyMessage => 'لا توجد قوائم.';

  @override
  String productCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا توجد منتجات',
    );
    return '$_temp0';
  }

  @override
  String orderCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب',
      many: '$count طلبًا',
      few: '$count طلبات',
      two: 'طلبان',
      one: 'طلب واحد',
      zero: 'لا توجد طلبات',
    );
    return '$_temp0';
  }

  @override
  String variantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خيار',
      many: '$count خيارًا',
      few: '$count خيارات',
      two: 'خياران',
      one: 'خيار واحد',
      zero: 'لا توجد خيارات',
    );
    return '$_temp0';
  }

  @override
  String validationIssueCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشكلة تحقق',
      many: '$count مشكلة تحقق',
      few: '$count مشكلات تحقق',
      two: 'مشكلتا تحقق',
      one: 'مشكلة تحقق واحدة',
      zero: 'لا توجد مشكلات تحقق',
    );
    return '$_temp0';
  }

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusOpen => 'مفتوح';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get statusPaid => 'مدفوع';

  @override
  String get statusUnpaid => 'غير مدفوع';

  @override
  String get statusArchived => 'مؤرشف';

  @override
  String get statusDraft => 'مسودة';

  @override
  String get statusPublished => 'منشور';

  @override
  String get statusScheduled => 'مجدول';

  @override
  String get statusTemporarilyUnavailable => 'غير متاح مؤقتًا';

  @override
  String get statusAssigned => 'مُعيَّن';

  @override
  String get statusUnassigned => 'غير مُعيَّن';

  @override
  String get priceSourceBase => 'السعر الأساسي';

  @override
  String get priceSourceOverride => 'سعر مخصص';

  @override
  String get validationSeverityError => 'خطأ';

  @override
  String get validationSeverityWarning => 'تحذير';

  @override
  String get validationSeverityInfo => 'معلومات';

  @override
  String get salesChannelPos => 'نقطة البيع';

  @override
  String get salesChannelOnline => 'عبر الإنترنت';

  @override
  String get productTypeSimple => 'منتج بسيط';

  @override
  String get productTypeVariant => 'منتج متعدد الخيارات';

  @override
  String get genericFormError =>
      'تعذر حفظ التغييرات. راجع الحقول المميزة وحاول مرة أخرى.';

  @override
  String get menuPublishTab => 'نشر';

  @override
  String get menuPublishAction => 'نشر القائمة';

  @override
  String get menuPublishPublishing => 'جارٍ النشر…';

  @override
  String get menuPublishBranch => 'الفرع';

  @override
  String get menuPublishChannel => 'قناة البيع';

  @override
  String get menuPublishScope => 'النطاق';

  @override
  String get menuPublishCollectionScope => 'مجموعة القوائم المعينة كاملة';

  @override
  String get menuPublishOneMenu => 'قائمة واحدة';

  @override
  String get menuPublishValidation => 'آخر تحقق';

  @override
  String get menuPublishValidationRequired => 'يلزم إجراء التحقق';

  @override
  String get menuPublishCanPublish => 'يمكن النشر';

  @override
  String get menuPublishCannotPublish => 'لا يمكن النشر';

  @override
  String get menuPublishErrors => 'الأخطاء';

  @override
  String get menuPublishWarnings => 'التحذيرات';

  @override
  String get menuPublishRunValidationFirst =>
      'أجرِ التحقق للنطاق المحدد قبل النشر.';

  @override
  String get menuPublishBlockedByValidation =>
      'النشر معطل لأن نتيجة التحقق المحملة تحتوي على أخطاء.';

  @override
  String get menuPublishWarningsAllowed =>
      'التحذيرات لا تمنع النشر. راجعها وأكد النشر صراحةً.';

  @override
  String get menuPublishConfirmTitle => 'تأكيد نشر القائمة';

  @override
  String get menuPublishCurrentVersion => 'الإصدار المنشور الحالي';

  @override
  String get menuPublishConfirmationExplanation =>
      'ينشئ النشر إصدارًا ثابتًا جديدًا للقائمة للفرع وقناة البيع المحددين عند تغير محتوى القائمة المحلول. لا يتم تعديل الطلبات الحالية.';

  @override
  String get menuPublishLoadingCurrentVersion =>
      'جارٍ تحميل الإصدار المنشور الحالي…';

  @override
  String get menuPublishNoCurrentVersion =>
      'لا يوجد إصدار قائمة منشور لهذا الفرع وقناة البيع.';

  @override
  String get menuPublishVersionNumber => 'الإصدار';

  @override
  String get menuPublishStatus => 'الحالة';

  @override
  String get menuPublishPublishedAt => 'نُشر في';

  @override
  String get menuPublishChecksum => 'البصمة';

  @override
  String get menuPublishPublicationId => 'معرف النشر';

  @override
  String get menuPublishSuccess => 'تم نشر القائمة بنجاح.';

  @override
  String get menuPublishNoChanges => 'لم يتم اكتشاف أي تغييرات في القائمة.';

  @override
  String get menuPublishNoChangesExplanation =>
      'يبقى الإصدار المنشور الحالي دون تغيير.';

  @override
  String get menuPublishBackendBlocked =>
      'حظر تحقق الخادم النشر. لم يتم إنشاء إصدار.';

  @override
  String get versionHistory => 'سجل الإصدارات';

  @override
  String get versionDetail => 'تفاصيل الإصدار';

  @override
  String get compareVersions => 'مقارنة الإصدارات';

  @override
  String get identicalContent => 'محتوى متطابق';

  @override
  String get versionsAdded => 'مضاف';

  @override
  String get versionsRemoved => 'محذوف';

  @override
  String get versionsChanged => 'متغير';

  @override
  String get versionPriceChanges => 'تغييرات الأسعار';

  @override
  String get versionModifierChanges => 'تغييرات الخيارات';

  @override
  String get versionScheduleChanges => 'تغييرات الجداول';

  @override
  String get versionRollback => 'تراجع';

  @override
  String get versionRollbackReason => 'سبب التراجع';

  @override
  String get versionNewRollback => 'إصدار تراجع جديد';

  @override
  String get versionNoChangeRollback => 'تراجع بدون تغيير';

  @override
  String get versionTruncatedComparison => 'يعرض جزء محدود من الاختلافات.';

  @override
  String get versionImmutableSnapshot => 'هذه لقطة تاريخية غير قابلة للتعديل.';

  @override
  String get versionStatusCurrent => 'حالي';

  @override
  String get versionStatusSuperseded => 'مستبدل';

  @override
  String get versionStatusRolledBack => 'تم التراجع عنه';

  @override
  String get catalogSetupTitle => 'إعداد الكتالوج';

  @override
  String get catalogSetupCategoriesTitle => 'فئات الكتالوج';

  @override
  String get catalogSetupReportingCategoriesTitle => 'فئات التقارير';

  @override
  String get catalogSetupKitchenStationsTitle => 'محطات المطبخ';

  @override
  String get catalogSetupCategory => 'فئة';

  @override
  String get catalogSetupReportingCategory => 'فئة تقارير';

  @override
  String get catalogSetupKitchenStation => 'محطة مطبخ';

  @override
  String get catalogSetupCategoriesExplanation =>
      'تصنف الفئات المنتجات في الكتالوج.';

  @override
  String get catalogSetupReportingCategoriesExplanation =>
      'تجمع فئات التقارير المنتجات للمبيعات وتقارير الأداء. لا تتحكم في موضع المنتجات في قائمة العملاء.';

  @override
  String get catalogSetupKitchenStationsExplanation =>
      'تحدد محطات المطبخ منطقة تحضير المنتجات؛ ولا تعد إعدادًا لاتصال الطابعة.';

  @override
  String get catalogSetupAll => 'الكل';

  @override
  String get catalogSetupProducts => 'المنتجات';

  @override
  String get catalogSetupOrder => 'الترتيب';

  @override
  String get catalogSetupActions => 'الإجراءات';

  @override
  String get catalogSetupCodePrinter => 'الرمز / الطابعة';

  @override
  String get catalogSetupNoMatchingRecords => 'لا توجد سجلات مطابقة.';

  @override
  String get catalogSetupUnableToLoad => 'تعذر تحميل إعداد الكتالوج.';

  @override
  String catalogSetupCreate(String type) {
    return 'إنشاء $type';
  }

  @override
  String catalogSetupEdit(String type) {
    return 'تعديل $type';
  }

  @override
  String catalogSetupArchive(String type) {
    return 'أرشفة $type';
  }

  @override
  String get catalogSetupRestore => 'استعادة';

  @override
  String get catalogSetupMoveUp => 'نقل لأعلى';

  @override
  String get catalogSetupMoveDown => 'نقل لأسفل';

  @override
  String get catalogSetupName => 'الاسم';

  @override
  String get catalogSetupNameArabic => 'الاسم بالعربية';

  @override
  String get catalogSetupNameEnglish => 'الاسم بالإنجليزية';

  @override
  String get catalogSetupCode => 'الرمز';

  @override
  String get catalogSetupDescription => 'الوصف';

  @override
  String get catalogSetupPrinterName => 'اسم الطابعة';

  @override
  String catalogSetupPage(int page) {
    return 'الصفحة $page';
  }

  @override
  String get catalogSetupPrevious => 'السابق';

  @override
  String get catalogSetupNext => 'التالي';

  @override
  String catalogSetupArchiveConfirmation(String name, int count) {
    return '$name مستخدم في $count من المنتجات. تبقى تعيينات المنتجات الحالية خاضعة لقواعد الخادم.';
  }

  @override
  String get recipeMaterials => 'الوصفة / المواد';

  @override
  String get manageRecipe => 'إدارة الوصفة';

  @override
  String get baseRecipe => 'الوصفة الأساسية';

  @override
  String get material => 'المادة';

  @override
  String get quantity => 'الكمية';

  @override
  String get unit => 'الوحدة';

  @override
  String get addMaterial => 'إضافة مادة';

  @override
  String get removeMaterial => 'إزالة';

  @override
  String get materialAdjustments => 'تعديلات المواد';

  @override
  String get effectiveFrom => 'فعال من';

  @override
  String get global => 'عام';

  @override
  String get productOverride => 'تجاوز المنتج';

  @override
  String get variantOverride => 'تجاوز الخيار';

  @override
  String get inherited => 'موروث';

  @override
  String get createOverride => 'إنشاء تجاوز';

  @override
  String get suppressInheritedEffects => 'إلغاء التأثيرات الموروثة';

  @override
  String get restoreInheritance => 'استعادة التوريث';

  @override
  String get recipeSimulation => 'محاكاة الوصفة';

  @override
  String get selectedModifiers => 'المعدلات المحددة';

  @override
  String get resolvedRecipe => 'الوصفة النهائية';

  @override
  String get recipeUnavailableMaterial =>
      'المواد ذات الوحدة غير المعرفة معطلة ولا يمكن حفظها.';

  @override
  String get recipeReadOnly => 'هذا الخيار مؤرشف. تكوين الوصفة للعرض فقط.';

  @override
  String get recipeEmpty => 'لا توجد مكونات وصفة معدة.';

  @override
  String get recipeInheritedDraft =>
      'هذه المسودة منسوخة من الملف الموروث. الحفظ ينشئ تجاوزاً كاملاً.';

  @override
  String get recipeEmptyOverride =>
      'هذا التجاوز لا يحتوي على أي تأثيرات للمواد.';

  @override
  String get recipeSuppressConfirmationTitle => 'إلغاء التأثيرات الموروثة؟';

  @override
  String get recipeSuppressConfirmationBody =>
      'حفظ ملف فارغ محدد النطاق يزيل كل تأثيرات ADD وREMOVE الموروثة من هذا النطاق.';

  @override
  String get recipeRemoveOverrideTitle => 'إزالة هذا التجاوز؟';

  @override
  String get recipeRemoveOverrideBody =>
      'إزالته تستعيد أقرب تأثيرات المواد الموروثة.';

  @override
  String get menuManagementWorkflow => 'مسار إدارة القائمة';

  @override
  String get menuManagementBuild => 'بناء';

  @override
  String get menuManagementConfigure => 'إعداد';

  @override
  String get menuManagementRelease => 'مراجعة ونشر';

  @override
  String get menuManagementProducts => 'المنتجات';

  @override
  String get menuManagementModifiers => 'المعدلات';

  @override
  String get menuManagementMenus => 'القوائم';

  @override
  String get menuManagementAssignments => 'التعيينات والجداول';

  @override
  String get menuManagementReview => 'مراجعة ومعاينة';

  @override
  String get menuManagementCatalogSetup => 'إعداد الكتالوج';

  @override
  String get recipeConsumptionHelp =>
      'حدد المواد المستهلكة عند تحضير وحدة واحدة من هذا الخيار.';

  @override
  String get recipeNoComponentsHelp =>
      'لم تُعد أي مواد بعد. أضف كل مادة تُستخدم لتحضير وحدة واحدة من هذا الخيار.';

  @override
  String get recipeOverrideGlobal => 'الإعداد العام';

  @override
  String get recipeOverrideProduct => 'تجاوز لهذا المنتج';

  @override
  String get recipeOverrideVariant => 'تجاوز لهذا الخيار';

  @override
  String get recipeInheritedFromGlobal => 'موروث من الإعداد العام';

  @override
  String get recipeInheritedFromProduct => 'موروث من هذا المنتج';

  @override
  String get recipeSimulationHelp =>
      'حدد المعدلات، ثم احسب الوصفة وراجع المواد المستهلكة.';

  @override
  String get recipeSimulationResultHelp => 'المواد المستهلكة';

  @override
  String get recipeSimulationStartHelp =>
      'حدد المعدلات، ثم احسب الوصفة لترى المواد المستهلكة.';

  @override
  String get reviewWorkflowHelp =>
      'تحقق من القائمة المحددة، وعاين ما يصل إلى الفرع وقناة البيع، ثم انرها وراجع سجل الإصدارات.';

  @override
  String get reviewCheckMenu => '1. تحقق من القائمة';

  @override
  String get reviewPreviewStep => '2. معاينة';

  @override
  String get reviewPublishStep => '3. نشر';

  @override
  String get reviewVersionsStep => '4. سجل الإصدارات';

  @override
  String get validationNoBlockingErrors => 'لم يُعثر على أخطاء تحقق مانعة.';

  @override
  String get validationResolveErrors =>
      'اعالج الأخطاء أدناه قبل أن يمكن نشر هذه القائمة.';

  @override
  String validationIssueCode(String code) {
    return 'الرمز: $code';
  }

  @override
  String modifierSelectionExactly(num count) {
    return 'يجب أن يختار العميل $count خيار(ات) بالضبط.';
  }

  @override
  String modifierSelectionRange(num min, num max) {
    return 'يمكن للعميل اختيار من $min إلى $max خيارات.';
  }

  @override
  String get reviewAdvancedOptions => 'خيارات معاينة متقدمة';

  @override
  String get technicalDetails => 'التفاصيل التقنية';

  @override
  String get managerAvailabilityScheduledHelp =>
      'متى ينبغي أن يكون هذا العنصر متاحًا بشكل عاد؟';

  @override
  String get managerAvailabilityOperationalHelp =>
      'هل العنصر غير متاح مؤقتًا الآن؟';
}
