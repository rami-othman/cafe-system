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
  String get commonDeactivate => 'إلغاء التنشيط';

  @override
  String get commonActivate => 'تنشيط';

  @override
  String get commonArchive => 'أرشفة';

  @override
  String get commonRestore => 'استعادة';

  @override
  String get commonArchived => 'مؤرشف';

  @override
  String get commonAll => 'الكل';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# خيار',
      many: '# خيارًا',
      few: '# خيارات',
      two: 'خيارين',
      one: 'خيار واحد',
    );
    return 'يجب أن يختار العميل $_temp0 بالضبط.';
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

  @override
  String get menuManagementNavigation => 'التنقل في إدارة القوائم';

  @override
  String get menuManagementCatalog => 'الكتالوج';

  @override
  String get menuManagementMenusGroup => 'القوائم';

  @override
  String get menuManagementReleaseGroup => 'الإصدار';

  @override
  String get menuManagementReviewPublish => 'مراجعة ونشر';

  @override
  String get menuBreadcrumbProduct => 'المنتج';

  @override
  String get menuBreadcrumbVariant => 'الخيار';

  @override
  String get menuBreadcrumbCreateProduct => 'إنشاء منتج';

  @override
  String get menuBreadcrumbEditProduct => 'تعديل المنتج';

  @override
  String get menuBreadcrumbVariants => 'الخيارات';

  @override
  String get menuBreadcrumbModifiers => 'المعدلات';

  @override
  String get menuBreadcrumbPricing => 'التسعير';

  @override
  String get menuBreadcrumbRecipe => 'الوصفة';

  @override
  String get menuBreadcrumbRecipeSimulation => 'محاكاة الوصفة';

  @override
  String get menuBreadcrumbAvailability => 'التوفر';

  @override
  String get menuBreadcrumbOperationalAvailability => 'التوفر التشغيلي';

  @override
  String get menuBreadcrumbMaterialAdjustments => 'تعديلات المواد';

  @override
  String get menuBreadcrumbModifierGroup => 'مجموعة المعدلات';

  @override
  String get menuBreadcrumbCreateModifierGroup => 'إنشاء مجموعة معدلات';

  @override
  String get menuBreadcrumbEditModifierGroup => 'تعديل مجموعة المعدلات';

  @override
  String get menuBreadcrumbMenu => 'القائمة';

  @override
  String get menuBreadcrumbCreateMenu => 'إنشاء قائمة';

  @override
  String get menuBreadcrumbEditMenu => 'تعديل القائمة';

  @override
  String get menuBreadcrumbComposition => 'التكوين';

  @override
  String get menuBreadcrumbVersionHistory => 'سجل الإصدارات';

  @override
  String get productCatalogTitle => 'المنتجات';

  @override
  String get productCatalogSubtitle => 'أدر المنتجات المتاحة عبر قوائمك.';

  @override
  String get productCatalogCreateProduct => 'إنشاء منتج';

  @override
  String get productCatalogRefresh => 'تحديث المنتجات';

  @override
  String get productCatalogSearch => 'ابحث عن المنتجات أو SKU أو الباركود';

  @override
  String get productCatalogLifecycle => 'الحالة';

  @override
  String get productCatalogAllProducts => 'كل المنتجات';

  @override
  String get productCatalogMoreFilters => 'مزيد من الفلاتر';

  @override
  String productCatalogMoreFiltersSemantic(int count) {
    return 'مزيد من الفلاتر، $count نشط';
  }

  @override
  String get productCatalogClearAll => 'مسح الكل';

  @override
  String get productCatalogClear => 'مسح';

  @override
  String get productCatalogApply => 'تطبيق';

  @override
  String get productCatalogSort => 'فرز';

  @override
  String get productCatalogSortOrder => 'ترتيب العرض';

  @override
  String get productCatalogNameAscending => 'الاسم أ–ي';

  @override
  String get productCatalogNameDescending => 'الاسم ي–أ';

  @override
  String get productCatalogNewest => 'الأحدث أولاً';

  @override
  String get productCatalogProductType => 'نوع المنتج';

  @override
  String get productCatalogHasVariants => 'لديه خيارات';

  @override
  String get productCatalogNoVariants => 'بدون خيارات';

  @override
  String get productCatalogHasModifiers => 'لديه معدلات';

  @override
  String get productCatalogNoModifiers => 'بدون معدلات';

  @override
  String get productCatalogStandard => 'عادي';

  @override
  String get productCatalogOpenPrice => 'سعر مفتوح';

  @override
  String get productCatalogCombo => 'وجبة مجمعة';

  @override
  String get productCatalogSetup => 'الإعداد';

  @override
  String get productCatalogDefaultVariant => 'الافتراضي';

  @override
  String get productCatalogStatus => 'الحالة';

  @override
  String get productCatalogOpen => 'فتح';

  @override
  String get productCatalogManageVariants => 'إدارة الخيارات';

  @override
  String get productCatalogManageModifiers => 'إدارة المعدلات';

  @override
  String get productCatalogArchive => 'أرشفة';

  @override
  String get productCatalogRestore => 'استعادة';

  @override
  String productCatalogActionsFor(String name) {
    return 'إجراءات المنتج $name';
  }

  @override
  String productCatalogSetupSummary(int variants, int modifiers) {
    return '$variants خيارات · $modifiers معدلات';
  }

  @override
  String get productCatalogLoadMore => 'تحميل مزيد من المنتجات';

  @override
  String get productCatalogUnableToLoad => 'تعذر تحميل المنتجات.';

  @override
  String get productCatalogNoArchived => 'لا توجد منتجات مؤرشفة.';

  @override
  String get productCatalogNoActive => 'لا توجد منتجات نشطة.';

  @override
  String get productCatalogNoMatches => 'لا تطابق أي منتجات هذه الفلاتر.';

  @override
  String get productCatalogNoProductsYet => 'لم يتم إنشاء أي منتجات بعد.';

  @override
  String get productCatalogMoreFiltersHelper =>
      'ضيّق قائمة المنتجات بمعايير إضافية.';

  @override
  String get productCatalogFilterClassification => 'التصنيف';

  @override
  String get productCatalogFilterPreparation => 'التحضير';

  @override
  String get productCatalogFilterProductSetup => 'إعداد المنتج';

  @override
  String get productCatalogClearFilters => 'مسح الفلاتر';

  @override
  String get productCatalogApplyFilters => 'تطبيق الفلاتر';

  @override
  String get productUxGeneral => 'عام';

  @override
  String get productUxClassification => 'التصنيف';

  @override
  String get productUxSellingPreparation => 'البيع والتحضير';

  @override
  String get productUxInitialSellingOption => 'خيار البيع الأولي';

  @override
  String get productUxTranslations => 'الترجمات';

  @override
  String get productUxAdvanced => 'متقدم';

  @override
  String get productUxOverview => 'نظرة عامة';

  @override
  String get productUxUsage => 'الاستخدام';

  @override
  String get productUxVariants => 'الأنواع';

  @override
  String get productUxModifiers => 'الإضافات';

  @override
  String get productUxRecipeMaterials => 'الوصفة والمواد';

  @override
  String get productUxAvailability => 'التوفر';

  @override
  String get productUxCreateProduct => 'إنشاء منتج';

  @override
  String get productUxSaveChanges => 'حفظ التغييرات';

  @override
  String get productUxCancel => 'إلغاء';

  @override
  String get productUxManageCatalogSetup => 'إدارة إعدادات الكتالوج';

  @override
  String get productUxEditProduct => 'تعديل المنتج';

  @override
  String get productUxArchived => 'مؤرشف';

  @override
  String get productOverviewBasePrice => 'السعر الأساسي';

  @override
  String get productOverviewVariants => 'الأنواع';

  @override
  String get productOverviewModifierGroups => 'مجموعات الإضافات';

  @override
  String get productOverviewStockTracking => 'تتبع المخزون';

  @override
  String get productOverviewEnabled => 'مفعّل';

  @override
  String get productOverviewDisabled => 'غير مفعّل';

  @override
  String get productOverviewNotConfigured => 'غير مهيأ';

  @override
  String get productOverviewProductSetup => 'إعداد المنتج';

  @override
  String get productOverviewCategory => 'الفئة';

  @override
  String get productOverviewDefaultVariant => 'النوع الافتراضي';

  @override
  String get productOverviewKitchenStation => 'محطة التحضير';

  @override
  String get productOverviewProductType => 'نوع المنتج';

  @override
  String get productOverviewReportingCategory => 'فئة التقارير';

  @override
  String get productOverviewPreparationTime => 'وقت التحضير';

  @override
  String get productOverviewMinutes => 'دقائق';

  @override
  String get modifierLibraryTitle => 'مكتبة المعدلات';

  @override
  String get modifierLibrarySubtitle =>
      'أنشئ خيارات عميل قابلة لإعادة الاستخدام ويمكن إسنادها إلى المنتجات.';

  @override
  String get modifierCreateGroup => 'إنشاء مجموعة معدلات';

  @override
  String get modifierSearch => 'البحث في المعدلات';

  @override
  String get modifierActive => 'نشط';

  @override
  String get modifierArchived => 'مؤرشف';

  @override
  String get modifierAll => 'الكل';

  @override
  String get modifierReorder => 'إعادة الترتيب';

  @override
  String get modifierDone => 'تم';

  @override
  String get modifierClearFiltersBeforeReorder =>
      'امسح البحث وعوامل التصفية قبل إعادة ترتيب مجموعات المعدلات.';

  @override
  String modifierOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# خيار',
      many: '# خيارًا',
      few: '# خيارات',
      two: 'خياران',
      one: 'خيار واحد',
      zero: '0 خيارات',
    );
    return '$_temp0';
  }

  @override
  String modifierOptionPreviewMore(int count) {
    return '+ $count المزيد';
  }

  @override
  String modifierRuleExactly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# خيار',
      many: '# خيارًا',
      few: '# خيارات',
      two: 'خيارين',
      one: 'خيار واحد',
    );
    return 'يجب على العميل اختيار $_temp0 بالضبط.';
  }

  @override
  String modifierRuleOptionalExactly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# خيار',
      many: '# خيارًا',
      few: '# خيارات',
      two: 'خيارين',
      one: 'خيار واحد',
    );
    return 'اختياري — يمكن للعميل اختيار $_temp0.';
  }

  @override
  String modifierRuleAtLeastUpTo(int min, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '# خيار',
      many: '# خيارًا',
      few: '# خيارات',
      two: 'خيارين',
      one: 'خيار واحد',
    );
    return 'يجب على العميل اختيار $min على الأقل وحتى $_temp0.';
  }

  @override
  String modifierRuleOptionalUpTo(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '# خيار',
      many: '# خيارًا',
      few: '# خيارات',
      two: 'خيارين',
      one: 'خيار واحد',
    );
    return 'اختياري — يمكن للعميل اختيار ما يصل إلى $_temp0.';
  }

  @override
  String get modifierRuleQuantity => 'يمكن إضافة الخيار نفسه أكثر من مرة.';

  @override
  String get modifierViewGroup => 'عرض المجموعة';

  @override
  String get modifierEditGroup => 'تعديل المجموعة';

  @override
  String get modifierSetDefault => 'تعيين كافتراضي';

  @override
  String get modifierMaterialAdjustments => 'تعديلات المواد';

  @override
  String get modifierArchive => 'أرشفة';

  @override
  String get modifierRestore => 'استعادة';

  @override
  String get modifierNoGroups => 'لم يتم إنشاء مجموعات معدلات بعد.';

  @override
  String get modifierNoGroupMatches =>
      'لا توجد مجموعات معدلات تطابق عوامل التصفية الحالية.';

  @override
  String get modifierUnableToLoad => 'تعذر تحميل مجموعات المعدلات.';

  @override
  String get modifierRetry => 'إعادة المحاولة';

  @override
  String get modifierLoadMore => 'تحميل المزيد';

  @override
  String get modifierRefresh => 'تحديث مجموعات المعدلات';

  @override
  String get modifierGroupDetailNotFound =>
      'لم يتم العثور على مجموعة المعدلات.';

  @override
  String get modifierOptions => 'الخيارات';

  @override
  String get modifierAddOption => 'إضافة خيار';

  @override
  String get modifierOptionFilter => 'حالة الخيار';

  @override
  String get modifierNoArchivedOptions => 'لا توجد خيارات معدلات مؤرشفة.';

  @override
  String get modifierNoOptions => 'لم يتم إنشاء خيارات معدلات بعد.';

  @override
  String get modifierReorderOptions => 'إعادة ترتيب الخيارات';

  @override
  String get modifierMoveUp => 'نقل لأعلى';

  @override
  String get modifierMoveDown => 'نقل لأسفل';

  @override
  String get modifierDefault => 'افتراضي';

  @override
  String get modifierNoExtraCharge => 'بدون تكلفة إضافية';

  @override
  String get modifierPriceAdjustment => 'تعديل السعر';

  @override
  String get modifierMaterialUsageConfigured => 'تم إعداد استخدام المواد';

  @override
  String get modifierStatusActive => 'نشط';

  @override
  String get modifierStatusArchived => 'مؤرشف';

  @override
  String get modifierStatusInactive => 'غير نشط';

  @override
  String get modifierAdvancedDetails => 'التفاصيل المتقدمة';

  @override
  String get modifierSelectionMode => 'طريقة الاختيار';

  @override
  String get modifierMinimum => 'الحد الأدنى';

  @override
  String get modifierMaximum => 'الحد الأقصى';

  @override
  String get modifierAllowQuantity => 'السماح بالكمية';

  @override
  String get modifierGroupType => 'نوع المجموعة';

  @override
  String get modifierSortOrder => 'ترتيب العرض';

  @override
  String get modifierCreateTitle => 'إنشاء مجموعة معدلات';

  @override
  String get modifierEditTitle => 'تعديل مجموعة معدلات';

  @override
  String get modifierBasicInformation => 'المعلومات الأساسية';

  @override
  String get modifierBasicInformationHelper =>
      'سمِّ مجموعة خيارات العميل القابلة لإعادة الاستخدام.';

  @override
  String get modifierGroupName => 'اسم مجموعة المعدلات';

  @override
  String get modifierGroupNameHint => 'مثال: نوع الحليب';

  @override
  String get modifierInternalCode => 'الرمز الداخلي';

  @override
  String get modifierGroupTypeChoice => 'اختيار';

  @override
  String get modifierGroupTypeAddOn => 'إضافة';

  @override
  String get modifierGroupTypePreparation => 'تعليمات التحضير';

  @override
  String get modifierYes => 'نعم';

  @override
  String get modifierNo => 'لا';

  @override
  String get modifierTranslations => 'الترجمات';

  @override
  String get modifierArabic => 'العربية';

  @override
  String get modifierEnglish => 'الإنجليزية';

  @override
  String get modifierClose => 'إغلاق';

  @override
  String get modifierSelectionRules => 'قواعد الاختيار';

  @override
  String get modifierSelectionRulesHelper =>
      'حدد طريقة تفاعل العملاء مع هذه الخيارات.';

  @override
  String get modifierHowChoose => 'كيف ينبغي للعملاء الاختيار؟';

  @override
  String get modifierChooseOne => 'اختيار واحد';

  @override
  String get modifierChooseMultiple => 'اختيارات متعددة';

  @override
  String get modifierChoiceRequired => 'هل الاختيار مطلوب؟';

  @override
  String get modifierOptional => 'اختياري';

  @override
  String get modifierRequired => 'مطلوب';

  @override
  String get modifierMinimumChoices => 'الحد الأدنى للاختيارات';

  @override
  String get modifierMaximumChoices => 'الحد الأقصى للاختيارات';

  @override
  String get modifierSameOptionQuantity =>
      'هل يمكن إضافة الخيار نفسه أكثر من مرة؟';

  @override
  String get modifierQuantityHelper => 'مثال: 2 من الإضافات.';

  @override
  String get modifierCurrentRuleSummary => 'ملخص القاعدة الحالية';

  @override
  String get modifierInitialOption => 'الخيار الأولي';

  @override
  String get modifierInitialOptions => 'الخيارات الأولية';

  @override
  String get modifierInitialOptionHelper =>
      'أضف ما يكفي من الخيارات النشطة ليتوافق مع الحد الأقصى قبل إنشاء مجموعة المعدلات.';

  @override
  String get modifierAddAnotherOption => 'إضافة خيار آخر';

  @override
  String get modifierRemoveOption => 'إزالة الخيار';

  @override
  String modifierAtLeastActiveOptions(int count) {
    return 'أضف $count خيارات نشطة على الأقل أو خفّض الحد الأقصى للاختيارات.';
  }

  @override
  String get modifierOptionName => 'اسم الخيار';

  @override
  String get modifierOptionNameHint => 'مثال: حليب كامل الدسم';

  @override
  String get modifierAdvanced => 'متقدم';

  @override
  String get modifierActiveStatus => 'الحالة النشطة';

  @override
  String get modifierAvailableForUse => 'متاح للاستخدام في القوائم.';

  @override
  String get modifierCancel => 'إلغاء';

  @override
  String get modifierSaveChanges => 'حفظ التغييرات';

  @override
  String get modifierCreateAction => 'إنشاء مجموعة معدلات';

  @override
  String get modifierSaving => 'جارٍ الحفظ...';

  @override
  String get modifierUnsavedChanges =>
      'لديك تغييرات غير محفوظة. هل تريد المغادرة دون حفظ؟';

  @override
  String get modifierStay => 'البقاء';

  @override
  String get modifierLeave => 'مغادرة';

  @override
  String get modifierOptionCreateTitle => 'إضافة خيار';

  @override
  String get modifierOptionEditTitle => 'تعديل الخيار';

  @override
  String get modifierOptionBasicInformation => 'المعلومات الأساسية';

  @override
  String get modifierOptionDefault => 'خيار افتراضي';

  @override
  String get modifierOptionActive => 'نشط';

  @override
  String get modifierOptionAvailable => 'متاح';

  @override
  String get modifierOptionAdvanced => 'متقدم';

  @override
  String get modifierOptionSave => 'حفظ';

  @override
  String get modifierOptionSaving => 'جارٍ الحفظ...';

  @override
  String get modifierOptionNameRequired => 'اسم الخيار مطلوب.';

  @override
  String get modifierOptionPriceInvalid => 'أدخل تعديلاً صالحاً للسعر.';

  @override
  String get modifierOptionSortInvalid => 'أدخل رقماً صحيحاً لترتيب العرض.';

  @override
  String get modifierArchiveGroupTitle => 'أرشفة مجموعة المعدلات؟';

  @override
  String get modifierArchiveOptionTitle => 'أرشفة خيار المعدلات؟';

  @override
  String get modifierArchiveMessage =>
      'يبقى العنصر محفوظاً ويمكن استعادته لاحقاً.';

  @override
  String get modifierConfirmArchive => 'أرشفة';

  @override
  String get modifierOptionSaveError =>
      'تعذر حفظ خيار المعدلات. تحقق من قواعد الخيار وحاول مرة أخرى.';

  @override
  String get modifierOptionGroupInvalid =>
      'لا يمكن تغيير هذا الخيار لأنه سيجعل مجموعة المعدلات غير صالحة.';

  @override
  String get modifierGroupSaveError => 'تعذر حفظ مجموعة المعدلات.';

  @override
  String get modifierGroupRequired => 'اسم مجموعة المعدلات مطلوب.';

  @override
  String get modifierNumberInvalid => 'أدخل صفراً أو رقماً صحيحاً موجباً.';

  @override
  String get modifierMaximumMinimumError =>
      'يجب أن يكون الحد الأقصى أكبر من أو مساوياً للحد الأدنى.';

  @override
  String get modifierSingleMaximumError =>
      'لا يمكن أن يتجاوز الحد الأقصى لمجموعة الاختيار الواحد 1.';

  @override
  String get modifierRequiredMinimumError =>
      'تحتاج المجموعات المطلوبة إلى حد أدنى لا يقل عن 1.';

  @override
  String get modifierInitialOptionRequired => 'الخيار النشط الأولي مطلوب.';

  @override
  String get modifierPriceInvalid => 'أدخل صفراً أو سعراً موجباً.';

  @override
  String get modifierInitialMaximumError =>
      'تحتوي المجموعة الجديدة على خيار أولي واحد؛ لا يمكن أن يتجاوز الحد الأقصى 1.';

  @override
  String get configuredSellPriceMustBePositive =>
      'يجب أن يكون سعر البيع أكبر من صفر.';

  @override
  String get recipeVariant => 'النوع';

  @override
  String recipeConfigured(int count) {
    return 'تم إعداد الوصفة · $count مواد';
  }

  @override
  String get recipeMissing => 'الوصفة مفقودة';

  @override
  String get recipeNotConfigured => 'الوصفة غير معدّة';

  @override
  String get recipeModifierMaterialEffects => 'تأثيرات مواد المعدلات';

  @override
  String get recipeModifierMaterialEffectsHelp =>
      'اطلع على كيفية تغيير اختيارات العميل للمواد المستهلكة.';

  @override
  String get recipeNoMaterialChange => 'لا تغيير في المواد';

  @override
  String get recipeUsingGlobalSettings => 'باستخدام الإعدادات العامة';

  @override
  String get recipeCustomizedForProduct => 'مخصص للمنتج';

  @override
  String get recipeCustomizedForVariant => 'مخصص للنوع';

  @override
  String get recipeTest => 'اختبار الوصفة';

  @override
  String get recipeBackToWorkspace => 'العودة إلى الوصفة والمواد';

  @override
  String get recipeSave => 'حفظ الوصفة';

  @override
  String get recipeSaved => 'تم حفظ الوصفة.';

  @override
  String get recipeCurrentBehavior => 'السلوك الحالي';

  @override
  String get recipeUseInherited => 'استخدام الإعدادات الموروثة';

  @override
  String get recipeUseInheritedAgain => 'استخدم الإعدادات الموروثة مجدداً';

  @override
  String recipeCustomizeFor(String context) {
    return 'تخصيص لـ $context';
  }

  @override
  String recipeNoMaterialEffectFor(String context) {
    return 'لا تأثير مادي لـ $context';
  }

  @override
  String get recipeRemoves => 'يزيل';

  @override
  String get recipeAdds => 'يضيف';

  @override
  String get recipeAddMaterialToRemove => 'إضافة مادة لإزالتها';

  @override
  String get recipeAddMaterialToAdd => 'إضافة مادة لإضافتها';

  @override
  String get recipeSaveChanges => 'حفظ التغييرات';

  @override
  String get recipeCancel => 'إلغاء';

  @override
  String get recipeQuantityRequired => 'الكمية مطلوبة.';

  @override
  String get recipeQuantityInvalid =>
      'أدخل رقماً موجباً بحد أقصى 6 منازل عشرية.';

  @override
  String get recipeDuplicateMaterial => 'هذه المادة مستخدمة بالفعل.';

  @override
  String get recipeMaterialSearch => 'ابحث عن المواد';

  @override
  String get recipeNoMaterialResults => 'لا توجد مواد مطابقة.';

  @override
  String get recipeFinalMaterials => 'المواد النهائية';

  @override
  String get recipePreviewMaterials => 'معاينة المواد';

  @override
  String get recipeHowCalculated => 'كيف تم احتساب هذا';

  @override
  String get recipeChoicesChanged => 'تغيرت الاختيارات';

  @override
  String get recipeStaleResult => 'عاين المواد مجدداً لتحديث النتيجة.';

  @override
  String get recipeDecreaseQuantity => 'تقليل الكمية';

  @override
  String get recipeIncreaseQuantity => 'زيادة الكمية';

  @override
  String get batch8AvailabilityTitle => 'إتاحة البيع';

  @override
  String get batch8AvailabilityHelp =>
      'راجع السعر وساعات البيع المعتادة والحالة التشغيلية الحالية لهذا السياق.';

  @override
  String get batch8Variant => 'النوع';

  @override
  String get batch8Branch => 'الفرع';

  @override
  String get batch8Channel => 'قناة البيع';

  @override
  String get batch8AvailabilityLoadError => 'تعذر تحميل بيانات الإتاحة.';

  @override
  String get batch8Retry => 'إعادة المحاولة';

  @override
  String get batch8Loading => 'جارٍ التحميل…';

  @override
  String get batch8Checking => 'جارٍ التحقق…';

  @override
  String get batch8SellingPrice => 'سعر البيع';

  @override
  String get batch8BasePrice => 'السعر الأساسي';

  @override
  String get batch8EffectiveSellingPrice => 'سعر البيع الفعلي';

  @override
  String get batch8Using => 'المصدر';

  @override
  String get batch8ManagePricing => 'إدارة الأسعار';

  @override
  String get batch8PriceLoadingHelp => 'جارٍ تحديد سعر البيع لهذا السياق.';

  @override
  String get batch8PriceFromBase => 'السعر الأساسي للنوع';

  @override
  String get batch8PriceFromBranch => 'سعر الفرع';

  @override
  String get batch8PriceFromChannel => 'سعر قناة البيع';

  @override
  String get batch8PriceFromBranchAndChannel => 'سعر الفرع وقناة البيع';

  @override
  String get batch8RegularAvailability => 'الإتاحة المعتادة';

  @override
  String get batch8NoScheduleRestrictions => 'لا توجد قيود على الجدول';

  @override
  String get batch8NoScheduleRestrictionsHelp =>
      'متاح عادةً ما دامت نقطة البيع مفتوحة في هذا السياق.';

  @override
  String get batch8ScheduleLoadingHelp =>
      'جارٍ التحقق من ساعات البيع المعتادة لهذا السياق.';

  @override
  String get batch8AvailableNow => 'متاح الآن';

  @override
  String get batch8UnavailableNow => 'غير متاح الآن';

  @override
  String get batch8Unavailable => 'غير متاح';

  @override
  String get batch8AvailableAccordingSchedule =>
      'متاح وفق ساعات البيع المعتادة.';

  @override
  String get batch8UnavailableAccordingSchedule => 'خارج ساعات البيع المعتادة.';

  @override
  String get batch8ScheduleRules => 'ساعات البيع المُعدّة';

  @override
  String get batch8ManageSchedule => 'إدارة الجدول';

  @override
  String get batch8CurrentAvailability => 'الإتاحة الحالية';

  @override
  String get batch8CurrentLoadingHelp =>
      'جارٍ التحقق من الحالة التشغيلية المؤقتة لهذا السياق.';

  @override
  String get batch8SoldOut => 'نفدت الكمية';

  @override
  String get batch8TemporarilyUnavailable => 'غير متاح مؤقتًا';

  @override
  String get batch8NoTemporaryRestriction => 'لا يوجد قيد تشغيلي مؤقت نشط.';

  @override
  String get batch8TemporaryRestrictionActive => 'يوجد قيد تشغيلي مؤقت نشط.';

  @override
  String batch8TemporaryUntil(String time) {
    return 'القيد المؤقت ساري حتى $time.';
  }

  @override
  String get batch8ManageAvailability => 'إدارة الإتاحة';

  @override
  String get batch8EffectiveSellingResult => 'نتيجة البيع الفعلية';

  @override
  String get batch8Availability => 'الإتاحة';

  @override
  String get batch8PricingBack => 'رجوع';

  @override
  String get batch8PricingRefresh => 'تحديث';

  @override
  String get batch8PricingLoadError => 'تعذر تحميل بيانات التسعير.';

  @override
  String get batch8PricingArchived =>
      'هذا المنتج أو النوع مؤرشف. الأسعار معروضة للمرجعية ولا يمكن تعديلها.';

  @override
  String batch8PricingContext(String variant) {
    return '$variant · سعر البيع';
  }

  @override
  String get batch8PricingHelp => 'سعر البيع للنوع والفرع وقناة البيع المحددة.';

  @override
  String get batch8SalesChannel => 'قناة البيع';

  @override
  String get batch8NoBranch => 'بدون فرع';

  @override
  String get batch8NoChannel => 'بدون قناة';

  @override
  String get batch8ChangePrice => 'تغيير السعر';

  @override
  String get batch8MorePriceRules => 'قواعد أسعار إضافية';

  @override
  String batch8RulesConfigured(int count) {
    return '$count قاعدة مُعدّة';
  }

  @override
  String get batch8Show => 'عرض';

  @override
  String get batch8Hide => 'إخفاء';

  @override
  String get batch8NoPriceAdjustments => 'لا توجد تعديلات على السعر.';

  @override
  String get batch8BasePriceEverywhere => 'السعر الأساسي مطبق في كل مكان.';

  @override
  String get batch8Difference => 'الفرق';

  @override
  String get batch8AddPrice => 'إضافة سعر';

  @override
  String get batch8SetSellingPrice => 'تعيين سعر البيع';

  @override
  String get batch8Product => 'المنتج';

  @override
  String get batch8AppliesTo => 'يُطبّق على';

  @override
  String get batch8ScopeBranch => 'الفرع';

  @override
  String get batch8ScopeChannel => 'القناة';

  @override
  String get batch8ScopeBranchChannel => 'الفرع + القناة';

  @override
  String get batch8Price => 'السعر';

  @override
  String batch8PriceAboveBase(String difference) {
    return 'أعلى من السعر الأساسي بمقدار $difference';
  }

  @override
  String batch8PriceBelowBase(String difference) {
    return 'أقل من السعر الأساسي بمقدار $difference';
  }

  @override
  String get batch8PriceSameAsBase => 'مطابق للسعر الأساسي';

  @override
  String get batch8Cancel => 'إلغاء';

  @override
  String get batch8SavePrice => 'حفظ السعر';

  @override
  String get batch8Edit => 'تعديل';

  @override
  String get batch8Remove => 'إزالة';

  @override
  String get batch8RemovePriceTitle => 'إزالة قاعدة السعر؟';

  @override
  String get batch8RemovePriceMessage => 'سيُزال تعديل السعر لهذا النوع.';

  @override
  String get batch8Keep => 'إبقاء';

  @override
  String batch8BranchPriceFor(String branch) {
    return 'سعر فرع $branch';
  }

  @override
  String batch8ChannelPriceFor(String channel) {
    return 'سعر قناة $channel';
  }

  @override
  String batch8BranchChannelPriceFor(String branch, String channel) {
    return 'سعر $branch · $channel';
  }

  @override
  String get batch8RuleBranchPrice => 'سعر الفرع';

  @override
  String get batch8RuleChannelPrice => 'سعر القناة';

  @override
  String get batch8RuleBranchChannelPrice => 'سعر الفرع + القناة';

  @override
  String get batch8ChannelPos => 'نقطة البيع';

  @override
  String get batch8ChannelWaiterApp => 'تطبيق النادل';

  @override
  String get batch8ChannelKiosk => 'الكشك';

  @override
  String get batch8ChannelQrOrdering => 'الطلب عبر رمز QR';

  @override
  String get batch8ChannelDelivery => 'التوصيل';

  @override
  String get batch8ChannelOnlineOrdering => 'الطلب عبر الإنترنت';

  @override
  String get batch8UnsavedPriceChanges => 'تغييرات سعر غير محفوظة';

  @override
  String get batch8UnsavedPriceChangesMessage =>
      'لديك تغييرات سعر غير محفوظة. هل تريد المغادرة بدون حفظ؟';

  @override
  String get batch8Leave => 'مغادرة';

  @override
  String get scheduledUnsavedChanges => 'ساعات بيع غير محفوظة';

  @override
  String get scheduledUnsavedChangesHelp =>
      'لديك تغييرات غير محفوظة على ساعات البيع. هل تريد المغادرة دون حفظ؟';

  @override
  String get scheduledStay => 'البقاء';

  @override
  String get scheduledLeave => 'مغادرة';

  @override
  String get scheduledLoadError => 'تعذر تحميل إتاحة البيع المعتادة.';

  @override
  String get scheduledSaveError =>
      'تعذر حفظ ساعات البيع. راجع القيم المدخلة وحاول مرة أخرى.';

  @override
  String get scheduledSaved => 'تم حفظ ساعات البيع.';

  @override
  String get scheduledArchived =>
      'هذا المنتج أو النوع مؤرشف. تُعرض ساعات البيع للمرجعية ولا يمكن تعديلها.';

  @override
  String get scheduledRegularForProduct => 'المنتج · الإتاحة المعتادة';

  @override
  String scheduledRegularForVariant(String variant) {
    return '$variant · الإتاحة المعتادة';
  }

  @override
  String get scheduledProduct => 'المنتج';

  @override
  String get scheduledAllBranches => 'كل الفروع';

  @override
  String get scheduledAllChannels => 'كل القنوات';

  @override
  String get scheduledUsingProduct => 'باستخدام جدول المنتج';

  @override
  String get scheduledProductSchedule => 'جدول المنتج';

  @override
  String scheduledCustomizedFor(String variant) {
    return 'مخصص لـ $variant';
  }

  @override
  String scheduledCustomizeFor(String variant) {
    return 'تخصيص لـ $variant';
  }

  @override
  String get scheduledUseProductAgain => 'استخدام جدول المنتج مجددًا';

  @override
  String get scheduledWeeklyInAdvanced =>
      'تظهر ساعات الأسبوع ضمن قواعد الجدول المتقدمة.';

  @override
  String get scheduledNoSpecificRestriction => 'لا يوجد قيد محدد';

  @override
  String get scheduledAvailableAllDay => 'متاح طوال اليوم';

  @override
  String get scheduledEditSellingHours => 'تعديل ساعات البيع';

  @override
  String get scheduledAdvancedRules => 'قواعد الجدول المتقدمة';

  @override
  String get scheduledNoAdvancedRules => 'لا توجد قواعد جدول متقدمة';

  @override
  String get scheduledViewRules => 'عرض القواعد';

  @override
  String get scheduledInactiveRule => 'قاعدة جدول غير نشطة';

  @override
  String get scheduledPriorityRule => 'قاعدة جدول ذات أولوية';

  @override
  String get scheduledDateBoundRule => 'قاعدة جدول محددة بالتاريخ';

  @override
  String get scheduledCheckAvailability => 'فحص الإتاحة';

  @override
  String get scheduledCheckHelp => 'افحص التاريخ والوقت ضمن سياق البيع المحدد.';

  @override
  String get scheduledDate => 'التاريخ';

  @override
  String get scheduledTime => 'الوقت';

  @override
  String get scheduledCheck => 'فحص';

  @override
  String get scheduledCheckError => 'تعذر فحص الإتاحة. حاول مرة أخرى.';

  @override
  String get scheduledAvailableUsingProduct => 'متاح وفق جدول المنتج.';

  @override
  String get scheduledDay => 'اليوم';

  @override
  String get scheduledEveryDay => 'كل يوم';

  @override
  String get scheduledAvailability => 'الإتاحة';

  @override
  String get scheduledAvailableAllDayHelp => 'لا يوجد قيد زمني لهذا اليوم.';

  @override
  String get scheduledCustomHours => 'ساعات مخصصة';

  @override
  String get scheduledCustomHoursHelp => 'حدد وقت البدء والانتهاء المعتادين.';

  @override
  String get scheduledStartTime => 'وقت البدء';

  @override
  String get scheduledEndTime => 'وقت الانتهاء';

  @override
  String scheduledOvernightUntil(String time) {
    return 'متاح ليلًا حتى $time في اليوم التالي.';
  }

  @override
  String get scheduledDateLimits => 'حدود التاريخ';

  @override
  String get scheduledOptional => 'اختياري';

  @override
  String get scheduledStartDate => 'تاريخ البدء';

  @override
  String get scheduledEndDate => 'تاريخ الانتهاء';

  @override
  String get scheduledSelectDate => 'اختر التاريخ';

  @override
  String get scheduledAdvanced => 'متقدم';

  @override
  String get scheduledPriority => 'الأولوية';

  @override
  String get scheduledActive => 'نشط';

  @override
  String get scheduledSaveSellingHours => 'حفظ ساعات البيع';

  @override
  String get scheduledFrom => 'من';

  @override
  String get scheduledUntil => 'حتى';

  @override
  String get scheduledSunday => 'الأحد';

  @override
  String get scheduledMonday => 'الإثنين';

  @override
  String get scheduledTuesday => 'الثلاثاء';

  @override
  String get scheduledWednesday => 'الأربعاء';

  @override
  String get scheduledThursday => 'الخميس';

  @override
  String get scheduledFriday => 'الجمعة';

  @override
  String get scheduledSaturday => 'السبت';

  @override
  String get operationalAvailabilityTitle => 'الإتاحة التشغيلية';

  @override
  String get operationalAvailabilityPurpose =>
      'هل يمكن للعملاء طلب هذا الصنف الآن؟ للاستثناءات التشغيلية المؤقتة فقط.';

  @override
  String get operationalAvailabilityContext => 'السياق الحالي';

  @override
  String get operationalAvailabilityProductVariant => 'المنتج / النوع';

  @override
  String get operationalAvailabilityProductOnly => 'المنتج';

  @override
  String get operationalAvailabilityBranch => 'الفرع';

  @override
  String get operationalAvailabilityChannel => 'قناة البيع';

  @override
  String get operationalAvailabilitySelectBranch => 'اختر فرعًا نشطًا';

  @override
  String get operationalAvailabilitySelectChannel => 'اختر قناة بيع';

  @override
  String get operationalAvailabilityAvailableNow => 'متوفر الآن';

  @override
  String get operationalAvailabilitySoldOut => 'نفدت الكمية';

  @override
  String get operationalAvailabilityTemporarilyUnavailable =>
      'غير متوفر مؤقتًا';

  @override
  String get operationalAvailabilityNoRestriction =>
      'لا يوجد قيد تشغيلي مؤقت نشط.';

  @override
  String get operationalAvailabilityActiveRestriction =>
      'يوجد قيد تشغيلي مؤقت نشط.';

  @override
  String operationalAvailabilityUntil(String time) {
    return 'حتى: $time';
  }

  @override
  String get operationalAvailabilityReason => 'السبب';

  @override
  String get operationalAvailabilityMarkUnavailable => 'جعله غير متوفر مؤقتًا';

  @override
  String get operationalAvailabilityMakeAvailable => 'إعادة التوفر الآن';

  @override
  String get operationalAvailabilityEditStatus => 'تعديل الحالة';

  @override
  String get operationalAvailabilityEditTemporary => 'تعديل القيد المؤقت';

  @override
  String get operationalAvailabilityUseDefault => 'استخدام الحالة الافتراضية';

  @override
  String get operationalAvailabilityUseDefaultTitle =>
      'استخدام الحالة الافتراضية؟';

  @override
  String get operationalAvailabilityUseDefaultMessage =>
      'سيؤدي ذلك إلى إزالة الحالة المضبوطة لهذا السياق المحدد فقط، ثم التحقق من الإتاحة الناتجة مرة أخرى.';

  @override
  String get operationalAvailabilityDefaultAction => 'استخدام الافتراضي';

  @override
  String get operationalAvailabilityAllVariants =>
      'تنطبق هذه الحالة على جميع أنواع هذا المنتج.';

  @override
  String operationalAvailabilityOnlyVariant(String variant) {
    return 'تؤثر هذه الحالة في $variant فقط.';
  }

  @override
  String get operationalAvailabilityLoadingCurrent =>
      'جارٍ تحديث الإتاحة الحالية…';

  @override
  String get operationalAvailabilityNoContext =>
      'اختر فرعًا نشطًا وقناة بيع لعرض الإتاحة الحالية.';

  @override
  String get operationalAvailabilityLoadError =>
      'تعذر تحميل الإتاحة الحالية. حاول مرة أخرى.';

  @override
  String get operationalAvailabilityArchived =>
      'هذا الصنف مؤرشف. تُعرض الإتاحة الحالية للرجوع إليها ولا يمكن تعديلها.';

  @override
  String get operationalAvailabilitySetStatus => 'تعيين حالة الإتاحة';

  @override
  String get operationalAvailabilityEditStatusTitle => 'تعديل حالة الإتاحة';

  @override
  String get operationalAvailabilityStatus => 'الحالة';

  @override
  String get operationalAvailabilityDuration => 'المدة';

  @override
  String get operationalAvailabilitySpecificTime => 'حتى وقت محدد';

  @override
  String get operationalAvailabilityEndTimeRequired =>
      'اختر وقت انتهاء هذا القيد المؤقت.';

  @override
  String get operationalAvailabilitySelectEndTime => 'اختر تاريخ ووقت الانتهاء';

  @override
  String get operationalAvailabilityBranchTime =>
      'يُعرض الوقت بالتوقيت المحلي للفرع المحدد.';

  @override
  String get operationalAvailabilitySave => 'حفظ الحالة';

  @override
  String get operationalAvailabilitySaving => 'جارٍ الحفظ…';

  @override
  String get operationalAvailabilityCancel => 'إلغاء';

  @override
  String get operationalAvailabilityExplicitAvailable =>
      'متوفر في سياق البيع هذا.';

  @override
  String get operationalAvailabilitySaveError =>
      'تعذر حفظ حالة الإتاحة. راجع التفاصيل وحاول مرة أخرى.';
}
