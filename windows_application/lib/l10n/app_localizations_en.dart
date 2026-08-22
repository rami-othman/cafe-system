// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Cafe System 618';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageSelection => 'Select language';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonError => 'Something went wrong. Please try again.';

  @override
  String get commonNoData => 'No data available.';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonActive => 'Active';

  @override
  String get commonDeactivate => 'Deactivate';

  @override
  String get commonActivate => 'Activate';

  @override
  String get commonArchive => 'Archive';

  @override
  String get commonRestore => 'Restore';

  @override
  String get commonArchived => 'Archived';

  @override
  String get commonAll => 'All';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get commonAvailable => 'Available';

  @override
  String get commonSoldOut => 'Sold out';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonBack => 'Back';

  @override
  String get navigationDashboard => 'Dashboard';

  @override
  String get navigationPos => 'POS';

  @override
  String get navigationOrders => 'Orders';

  @override
  String get navigationCustomers => 'Customers';

  @override
  String get navigationDiscounts => 'Discounts';

  @override
  String get navigationMenuManagement => 'Menu Management';

  @override
  String get navigationInventory => 'Inventory';

  @override
  String get navigationReports => 'Reports';

  @override
  String get navigationSettings => 'Settings';

  @override
  String get operationalHub => 'OPERATIONAL HUB';

  @override
  String get tooltipCart => 'Cart';

  @override
  String get tooltipRefreshScreenData => 'Refresh screen data';

  @override
  String get tooltipNotifications => 'Notifications';

  @override
  String get tooltipProfile => 'Profile';

  @override
  String get invalidCatalogRoute => 'The requested catalog route is invalid.';

  @override
  String get productsEmptyMessage => 'No products found.';

  @override
  String get ordersEmptyMessage => 'No orders found.';

  @override
  String get menusEmptyMessage => 'No menus found.';

  @override
  String productCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
      zero: 'No products',
    );
    return '$_temp0';
  }

  @override
  String orderCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
      zero: 'No orders',
    );
    return '$_temp0';
  }

  @override
  String variantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variants',
      one: '1 variant',
      zero: 'No variants',
    );
    return '$_temp0';
  }

  @override
  String validationIssueCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count validation issues',
      one: '1 validation issue',
      zero: 'No validation issues',
    );
    return '$_temp0';
  }

  @override
  String get statusPending => 'Pending';

  @override
  String get statusOpen => 'Open';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusUnpaid => 'Unpaid';

  @override
  String get statusArchived => 'Archived';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusPublished => 'Published';

  @override
  String get statusScheduled => 'Scheduled';

  @override
  String get statusTemporarilyUnavailable => 'Temporarily unavailable';

  @override
  String get statusAssigned => 'Assigned';

  @override
  String get statusUnassigned => 'Unassigned';

  @override
  String get priceSourceBase => 'Base price';

  @override
  String get priceSourceOverride => 'Override price';

  @override
  String get validationSeverityError => 'Error';

  @override
  String get validationSeverityWarning => 'Warning';

  @override
  String get validationSeverityInfo => 'Information';

  @override
  String get salesChannelPos => 'POS';

  @override
  String get salesChannelOnline => 'Online';

  @override
  String get productTypeSimple => 'Simple product';

  @override
  String get productTypeVariant => 'Variant product';

  @override
  String get genericFormError =>
      'We could not save your changes. Review the highlighted fields and try again.';

  @override
  String get menuPublishTab => 'Publish';

  @override
  String get menuPublishAction => 'Publish Menu';

  @override
  String get menuPublishPublishing => 'Publishing…';

  @override
  String get menuPublishBranch => 'Branch';

  @override
  String get menuPublishChannel => 'Sales channel';

  @override
  String get menuPublishScope => 'Scope';

  @override
  String get menuPublishCollectionScope => 'Complete assigned Menu collection';

  @override
  String get menuPublishOneMenu => 'One Menu';

  @override
  String get menuPublishValidation => 'Last validation';

  @override
  String get menuPublishValidationRequired => 'Validation required';

  @override
  String get menuPublishCanPublish => 'Can Publish';

  @override
  String get menuPublishCannotPublish => 'Cannot Publish';

  @override
  String get menuPublishErrors => 'Errors';

  @override
  String get menuPublishWarnings => 'Warnings';

  @override
  String get menuPublishRunValidationFirst =>
      'Run Validation for this selected scope before publishing.';

  @override
  String get menuPublishBlockedByValidation =>
      'Publishing is disabled because the loaded validation contains errors.';

  @override
  String get menuPublishWarningsAllowed =>
      'Warnings do not block publishing. Review them and confirm explicitly.';

  @override
  String get menuPublishConfirmTitle => 'Confirm Menu publication';

  @override
  String get menuPublishCurrentVersion => 'Current Published Version';

  @override
  String get menuPublishConfirmationExplanation =>
      'Publishing creates a new immutable Menu Version for the selected Branch and Channel when the resolved Menu content has changed. Existing Orders are not modified.';

  @override
  String get menuPublishLoadingCurrentVersion =>
      'Loading current published Version…';

  @override
  String get menuPublishNoCurrentVersion =>
      'No Menu Version has been published for this Branch and Sales Channel.';

  @override
  String get menuPublishVersionNumber => 'Version';

  @override
  String get menuPublishStatus => 'Status';

  @override
  String get menuPublishPublishedAt => 'Published at';

  @override
  String get menuPublishChecksum => 'Checksum';

  @override
  String get menuPublishPublicationId => 'Publication ID';

  @override
  String get menuPublishSuccess => 'Menu publication successful.';

  @override
  String get menuPublishNoChanges => 'No Menu changes were detected.';

  @override
  String get menuPublishNoChangesExplanation =>
      'The current published Version remains unchanged.';

  @override
  String get menuPublishBackendBlocked =>
      'Backend validation blocked publication. No Version was created.';

  @override
  String get versionHistory => 'Version History';

  @override
  String get versionDetail => 'Version Detail';

  @override
  String get compareVersions => 'Compare Versions';

  @override
  String get identicalContent => 'Identical content';

  @override
  String get versionsAdded => 'Added';

  @override
  String get versionsRemoved => 'Removed';

  @override
  String get versionsChanged => 'Changed';

  @override
  String get versionPriceChanges => 'Price changes';

  @override
  String get versionModifierChanges => 'Modifier changes';

  @override
  String get versionScheduleChanges => 'Schedule changes';

  @override
  String get versionRollback => 'Rollback';

  @override
  String get versionRollbackReason => 'Rollback reason';

  @override
  String get versionNewRollback => 'New rollback Version';

  @override
  String get versionNoChangeRollback => 'No-change rollback';

  @override
  String get versionTruncatedComparison =>
      'Only a bounded subset of differences is displayed.';

  @override
  String get versionImmutableSnapshot =>
      'This is an immutable historical Snapshot.';

  @override
  String get versionStatusCurrent => 'Current';

  @override
  String get versionStatusSuperseded => 'Superseded';

  @override
  String get versionStatusRolledBack => 'Rolled back';

  @override
  String get catalogSetupTitle => 'Catalog Setup';

  @override
  String get catalogSetupCategoriesTitle => 'Catalog Categories';

  @override
  String get catalogSetupReportingCategoriesTitle => 'Reporting Categories';

  @override
  String get catalogSetupKitchenStationsTitle => 'Kitchen Stations';

  @override
  String get catalogSetupCategory => 'Category';

  @override
  String get catalogSetupReportingCategory => 'Reporting Category';

  @override
  String get catalogSetupKitchenStation => 'Kitchen Station';

  @override
  String get catalogSetupCategoriesExplanation =>
      'Categories classify Products for the Catalog.';

  @override
  String get catalogSetupReportingCategoriesExplanation =>
      'Reporting Categories group Products for sales and performance reports. They do not control where Products appear in the customer Menu.';

  @override
  String get catalogSetupKitchenStationsExplanation =>
      'Kitchen Stations identify the preparation area for Products; this does not configure printer communication.';

  @override
  String get catalogSetupAll => 'All';

  @override
  String get catalogSetupProducts => 'Products';

  @override
  String get catalogSetupOrder => 'Order';

  @override
  String get catalogSetupActions => 'Actions';

  @override
  String get catalogSetupCodePrinter => 'Code / Printer';

  @override
  String get catalogSetupNoMatchingRecords => 'No matching records.';

  @override
  String get catalogSetupUnableToLoad => 'Unable to load Catalog Setup.';

  @override
  String catalogSetupCreate(String type) {
    return 'Create $type';
  }

  @override
  String catalogSetupEdit(String type) {
    return 'Edit $type';
  }

  @override
  String catalogSetupArchive(String type) {
    return 'Archive $type';
  }

  @override
  String get catalogSetupRestore => 'Restore';

  @override
  String get catalogSetupMoveUp => 'Move up';

  @override
  String get catalogSetupMoveDown => 'Move down';

  @override
  String get catalogSetupName => 'Name';

  @override
  String get catalogSetupNameArabic => 'Arabic name';

  @override
  String get catalogSetupNameEnglish => 'English name';

  @override
  String get catalogSetupCode => 'Code';

  @override
  String get catalogSetupDescription => 'Description';

  @override
  String get catalogSetupPrinterName => 'Printer name';

  @override
  String catalogSetupPage(int page) {
    return 'Page $page';
  }

  @override
  String get catalogSetupPrevious => 'Previous';

  @override
  String get catalogSetupNext => 'Next';

  @override
  String catalogSetupArchiveConfirmation(String name, int count) {
    return '$name is used by $count Products. Existing Product assignments remain governed by Backend rules.';
  }

  @override
  String get recipeMaterials => 'Recipe / Materials';

  @override
  String get manageRecipe => 'Manage Recipe';

  @override
  String get baseRecipe => 'Base Recipe';

  @override
  String get material => 'Material';

  @override
  String get quantity => 'Quantity';

  @override
  String get unit => 'Unit';

  @override
  String get addMaterial => 'Add Material';

  @override
  String get removeMaterial => 'Remove';

  @override
  String get materialAdjustments => 'Material Adjustments';

  @override
  String get effectiveFrom => 'Effective from';

  @override
  String get global => 'Global';

  @override
  String get productOverride => 'Product Override';

  @override
  String get variantOverride => 'Variant Override';

  @override
  String get inherited => 'Inherited';

  @override
  String get createOverride => 'Create Override';

  @override
  String get suppressInheritedEffects => 'Suppress Inherited Effects';

  @override
  String get restoreInheritance => 'Restore Inheritance';

  @override
  String get recipeSimulation => 'Recipe Simulation';

  @override
  String get selectedModifiers => 'Selected Modifiers';

  @override
  String get resolvedRecipe => 'Resolved Recipe';

  @override
  String get recipeUnavailableMaterial =>
      'Materials with an unmapped unit are disabled and cannot be saved.';

  @override
  String get recipeReadOnly =>
      'This Variant is archived. Recipe configuration is read-only.';

  @override
  String get recipeEmpty => 'No recipe components are configured.';

  @override
  String get recipeInheritedDraft =>
      'This draft is cloned from the inherited profile. Saving creates a full replacement override.';

  @override
  String get recipeEmptyOverride =>
      'This override deliberately has no material effects.';

  @override
  String get recipeSuppressConfirmationTitle =>
      'Suppress inherited material effects?';

  @override
  String get recipeSuppressConfirmationBody =>
      'Saving an empty scoped profile removes every inherited ADD and REMOVE effect for this scope.';

  @override
  String get recipeRemoveOverrideTitle => 'Remove this override?';

  @override
  String get recipeRemoveOverrideBody =>
      'Removing it restores the nearest inherited material effects.';

  @override
  String get menuManagementWorkflow => 'Menu management workflow';

  @override
  String get menuManagementBuild => 'Build';

  @override
  String get menuManagementConfigure => 'Configure';

  @override
  String get menuManagementRelease => 'Review & release';

  @override
  String get menuManagementProducts => 'Products';

  @override
  String get menuManagementModifiers => 'Modifiers';

  @override
  String get menuManagementMenus => 'Menus';

  @override
  String get menuManagementAssignments => 'Assignments & schedules';

  @override
  String get menuManagementReview => 'Review & preview';

  @override
  String get menuManagementCatalogSetup => 'Catalog setup';

  @override
  String get recipeConsumptionHelp =>
      'Define the materials consumed when one unit of this Variant is prepared.';

  @override
  String get recipeNoComponentsHelp =>
      'No materials are configured yet. Add each material used to prepare one unit of this Variant.';

  @override
  String get recipeOverrideGlobal => 'Global default';

  @override
  String get recipeOverrideProduct => 'Override for this Product';

  @override
  String get recipeOverrideVariant => 'Override for this Variant';

  @override
  String get recipeInheritedFromGlobal => 'Inherited from Global';

  @override
  String get recipeInheritedFromProduct => 'Inherited from this Product';

  @override
  String get recipeSimulationHelp =>
      'Select modifiers, resolve the recipe, then review the materials consumed.';

  @override
  String get recipeSimulationResultHelp => 'Consumed materials';

  @override
  String get recipeSimulationStartHelp =>
      'Select modifiers, then resolve the recipe to see the consumed materials.';

  @override
  String get reviewWorkflowHelp =>
      'Check the selected Menu, preview what the Branch and Channel receive, then publish and review its Version history.';

  @override
  String get reviewCheckMenu => '1. Check Menu';

  @override
  String get reviewPreviewStep => '2. Preview';

  @override
  String get reviewPublishStep => '3. Publish';

  @override
  String get reviewVersionsStep => '4. Version History';

  @override
  String get validationNoBlockingErrors =>
      'No blocking validation errors were found.';

  @override
  String get validationResolveErrors =>
      'Resolve the errors below before this Menu can be published.';

  @override
  String validationIssueCode(String code) {
    return 'Code: $code';
  }

  @override
  String modifierSelectionExactly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return 'Customer must choose exactly $_temp0.';
  }

  @override
  String modifierSelectionRange(num min, num max) {
    return 'Customer may choose from $min to $max options.';
  }

  @override
  String get reviewAdvancedOptions => 'Advanced preview options';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String get managerAvailabilityScheduledHelp =>
      'When should this item normally be available?';

  @override
  String get managerAvailabilityOperationalHelp =>
      'Is it temporarily unavailable right now?';

  @override
  String get menuManagementNavigation => 'Menu Management navigation';

  @override
  String get menuManagementCatalog => 'Catalog';

  @override
  String get menuManagementMenusGroup => 'Menus';

  @override
  String get menuManagementReleaseGroup => 'Release';

  @override
  String get menuManagementReviewPublish => 'Review & Publish';

  @override
  String get menuBreadcrumbProduct => 'Product';

  @override
  String get menuBreadcrumbVariant => 'Variant';

  @override
  String get menuBreadcrumbCreateProduct => 'Create product';

  @override
  String get menuBreadcrumbEditProduct => 'Edit product';

  @override
  String get menuBreadcrumbVariants => 'Variants';

  @override
  String get menuBreadcrumbModifiers => 'Modifiers';

  @override
  String get menuBreadcrumbPricing => 'Pricing';

  @override
  String get menuBreadcrumbRecipe => 'Recipe';

  @override
  String get menuBreadcrumbRecipeSimulation => 'Recipe simulation';

  @override
  String get menuBreadcrumbAvailability => 'Availability';

  @override
  String get menuBreadcrumbOperationalAvailability =>
      'Operational availability';

  @override
  String get menuBreadcrumbMaterialAdjustments => 'Material adjustments';

  @override
  String get menuBreadcrumbModifierGroup => 'Modifier group';

  @override
  String get menuBreadcrumbCreateModifierGroup => 'Create modifier group';

  @override
  String get menuBreadcrumbEditModifierGroup => 'Edit modifier group';

  @override
  String get menuBreadcrumbMenu => 'Menu';

  @override
  String get menuBreadcrumbCreateMenu => 'Create menu';

  @override
  String get menuBreadcrumbEditMenu => 'Edit menu';

  @override
  String get menuBreadcrumbComposition => 'Composition';

  @override
  String get menuBreadcrumbVersionHistory => 'Version history';

  @override
  String get productCatalogTitle => 'Products';

  @override
  String get productCatalogSubtitle =>
      'Manage the products available across your menus.';

  @override
  String get productCatalogCreateProduct => 'Create Product';

  @override
  String get productCatalogRefresh => 'Refresh products';

  @override
  String get productCatalogSearch => 'Search products, SKU, or barcode';

  @override
  String get productCatalogLifecycle => 'Lifecycle';

  @override
  String get productCatalogAllProducts => 'All products';

  @override
  String get productCatalogMoreFilters => 'More Filters';

  @override
  String productCatalogMoreFiltersSemantic(int count) {
    return 'More Filters, $count active';
  }

  @override
  String get productCatalogClearAll => 'Clear All';

  @override
  String get productCatalogClear => 'Clear';

  @override
  String get productCatalogApply => 'Apply';

  @override
  String get productCatalogSort => 'Sort';

  @override
  String get productCatalogSortOrder => 'Sort order';

  @override
  String get productCatalogNameAscending => 'Name A–Z';

  @override
  String get productCatalogNameDescending => 'Name Z–A';

  @override
  String get productCatalogNewest => 'Newest first';

  @override
  String get productCatalogProductType => 'Product type';

  @override
  String get productCatalogHasVariants => 'Has variants';

  @override
  String get productCatalogNoVariants => 'No variants';

  @override
  String get productCatalogHasModifiers => 'Has modifiers';

  @override
  String get productCatalogNoModifiers => 'No modifiers';

  @override
  String get productCatalogStandard => 'Standard';

  @override
  String get productCatalogOpenPrice => 'Open price';

  @override
  String get productCatalogCombo => 'Combo';

  @override
  String get productCatalogSetup => 'Setup';

  @override
  String get productCatalogDefaultVariant => 'Default';

  @override
  String get productCatalogStatus => 'Status';

  @override
  String get productCatalogOpen => 'Open';

  @override
  String get productCatalogManageVariants => 'Manage Variants';

  @override
  String get productCatalogManageModifiers => 'Manage Modifiers';

  @override
  String get productCatalogArchive => 'Archive';

  @override
  String get productCatalogRestore => 'Restore';

  @override
  String productCatalogActionsFor(String name) {
    return 'Actions for $name';
  }

  @override
  String productCatalogSetupSummary(int variants, int modifiers) {
    return '$variants variants · $modifiers modifiers';
  }

  @override
  String get productCatalogLoadMore => 'Load more products';

  @override
  String get productCatalogUnableToLoad => 'Unable to load products.';

  @override
  String get productCatalogNoArchived => 'No archived products are available.';

  @override
  String get productCatalogNoActive => 'No active products are available.';

  @override
  String get productCatalogNoMatches => 'No products match these filters.';

  @override
  String get productCatalogNoProductsYet =>
      'No products have been created yet.';

  @override
  String get productCatalogMoreFiltersHelper =>
      'Refine the product list with additional criteria.';

  @override
  String get productCatalogFilterClassification => 'Classification';

  @override
  String get productCatalogFilterPreparation => 'Preparation';

  @override
  String get productCatalogFilterProductSetup => 'Product setup';

  @override
  String get productCatalogClearFilters => 'Clear filters';

  @override
  String get productCatalogApplyFilters => 'Apply filters';

  @override
  String get productUxGeneral => 'General';

  @override
  String get productUxClassification => 'Classification';

  @override
  String get productUxSellingPreparation => 'Selling & Preparation';

  @override
  String get productUxInitialSellingOption => 'Initial selling option';

  @override
  String get productUxTranslations => 'Translations';

  @override
  String get productUxAdvanced => 'Advanced';

  @override
  String get productUxOverview => 'Overview';

  @override
  String get productUxUsage => 'Usage';

  @override
  String get productUxVariants => 'Variants';

  @override
  String get productUxModifiers => 'Modifiers';

  @override
  String get productUxRecipeMaterials => 'Recipe & Materials';

  @override
  String get productUxAvailability => 'Availability';

  @override
  String get productUxCreateProduct => 'Create Product';

  @override
  String get productUxSaveChanges => 'Save Changes';

  @override
  String get productUxCancel => 'Cancel';

  @override
  String get productUxManageCatalogSetup => 'Manage catalog setup';

  @override
  String get productUxEditProduct => 'Edit Product';

  @override
  String get productUxArchived => 'Archived';

  @override
  String get productOverviewBasePrice => 'Base Price';

  @override
  String get productOverviewVariants => 'Variants';

  @override
  String get productOverviewModifierGroups => 'Modifier Groups';

  @override
  String get productOverviewStockTracking => 'Stock Tracking';

  @override
  String get productOverviewEnabled => 'Enabled';

  @override
  String get productOverviewDisabled => 'Disabled';

  @override
  String get productOverviewNotConfigured => 'Not configured';

  @override
  String get productOverviewProductSetup => 'Product Setup';

  @override
  String get productOverviewCategory => 'Category';

  @override
  String get productOverviewDefaultVariant => 'Default Variant';

  @override
  String get productOverviewKitchenStation => 'Kitchen Station';

  @override
  String get productOverviewProductType => 'Product Type';

  @override
  String get productOverviewReportingCategory => 'Reporting Category';

  @override
  String get productOverviewPreparationTime => 'Preparation Time';

  @override
  String get productOverviewMinutes => 'minutes';

  @override
  String get modifierLibraryTitle => 'Modifier Library';

  @override
  String get modifierLibrarySubtitle =>
      'Create reusable customer choices that can be assigned to Products.';

  @override
  String get modifierCreateGroup => 'Create Modifier Group';

  @override
  String get modifierSearch => 'Search modifiers';

  @override
  String get modifierActive => 'Active';

  @override
  String get modifierArchived => 'Archived';

  @override
  String get modifierAll => 'All';

  @override
  String get modifierReorder => 'Reorder';

  @override
  String get modifierDone => 'Done';

  @override
  String get modifierClearFiltersBeforeReorder =>
      'Clear search and filters before reordering Modifier Groups.';

  @override
  String modifierOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
      zero: '0 options',
    );
    return '$_temp0';
  }

  @override
  String modifierOptionPreviewMore(int count) {
    return '+ $count more';
  }

  @override
  String modifierRuleExactly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return 'Customer must choose exactly $_temp0.';
  }

  @override
  String modifierRuleOptionalExactly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return 'Optional — customer may choose $_temp0.';
  }

  @override
  String modifierRuleAtLeastUpTo(int min, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max options',
      one: '1 option',
    );
    return 'Customer must choose at least $min and up to $_temp0.';
  }

  @override
  String modifierRuleOptionalUpTo(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max options',
      one: '1 option',
    );
    return 'Optional — customer may choose up to $_temp0.';
  }

  @override
  String get modifierRuleQuantity =>
      'The same option may be added more than once.';

  @override
  String get modifierViewGroup => 'View Group';

  @override
  String get modifierEditGroup => 'Edit Group';

  @override
  String get modifierSetDefault => 'Set as Default';

  @override
  String get modifierMaterialAdjustments => 'Material Adjustments';

  @override
  String get modifierArchive => 'Archive';

  @override
  String get modifierRestore => 'Restore';

  @override
  String get modifierNoGroups => 'No modifier groups have been created yet.';

  @override
  String get modifierNoGroupMatches =>
      'No modifier groups match the current filters.';

  @override
  String get modifierUnableToLoad => 'Unable to load modifier groups.';

  @override
  String get modifierRetry => 'Retry';

  @override
  String get modifierLoadMore => 'Load more';

  @override
  String get modifierRefresh => 'Refresh modifier groups';

  @override
  String get modifierGroupDetailNotFound => 'Modifier group not found.';

  @override
  String get modifierOptions => 'Options';

  @override
  String get modifierAddOption => 'Add Option';

  @override
  String get modifierOptionFilter => 'Option status';

  @override
  String get modifierNoArchivedOptions => 'No archived modifier options.';

  @override
  String get modifierNoOptions => 'No modifier options have been created yet.';

  @override
  String get modifierReorderOptions => 'Reorder Options';

  @override
  String get modifierMoveUp => 'Move Up';

  @override
  String get modifierMoveDown => 'Move Down';

  @override
  String get modifierDefault => 'DEFAULT';

  @override
  String get modifierNoExtraCharge => 'No extra charge';

  @override
  String get modifierPriceAdjustment => 'Price adjustment';

  @override
  String get modifierMaterialUsageConfigured => 'Material usage configured';

  @override
  String get modifierStatusActive => 'Active';

  @override
  String get modifierStatusArchived => 'Archived';

  @override
  String get modifierStatusInactive => 'Inactive';

  @override
  String get modifierAdvancedDetails => 'Advanced Details';

  @override
  String get modifierSelectionMode => 'Selection mode';

  @override
  String get modifierMinimum => 'Minimum';

  @override
  String get modifierMaximum => 'Maximum';

  @override
  String get modifierAllowQuantity => 'Allow quantity';

  @override
  String get modifierGroupType => 'Group type';

  @override
  String get modifierSortOrder => 'Sort order';

  @override
  String get modifierCreateTitle => 'Create Modifier Group';

  @override
  String get modifierEditTitle => 'Edit Modifier Group';

  @override
  String get modifierBasicInformation => 'Basic Information';

  @override
  String get modifierBasicInformationHelper =>
      'Name this reusable customer-choice group.';

  @override
  String get modifierGroupName => 'Modifier Group Name';

  @override
  String get modifierGroupNameHint => 'e.g. Milk Type';

  @override
  String get modifierInternalCode => 'Internal code';

  @override
  String get modifierGroupTypeChoice => 'Choice';

  @override
  String get modifierGroupTypeAddOn => 'Add-on';

  @override
  String get modifierGroupTypePreparation => 'Preparation instruction';

  @override
  String get modifierYes => 'Yes';

  @override
  String get modifierNo => 'No';

  @override
  String get modifierTranslations => 'Translations';

  @override
  String get modifierArabic => 'Arabic';

  @override
  String get modifierEnglish => 'English';

  @override
  String get modifierClose => 'Close';

  @override
  String get modifierSelectionRules => 'Selection Rules';

  @override
  String get modifierSelectionRulesHelper =>
      'Determine how customers interact with these options.';

  @override
  String get modifierHowChoose => 'How should customers choose?';

  @override
  String get modifierChooseOne => 'Choose one';

  @override
  String get modifierChooseMultiple => 'Choose multiple';

  @override
  String get modifierChoiceRequired => 'Is a choice required?';

  @override
  String get modifierOptional => 'Optional';

  @override
  String get modifierRequired => 'Required';

  @override
  String get modifierMinimumChoices => 'Minimum choices';

  @override
  String get modifierMaximumChoices => 'Maximum choices';

  @override
  String get modifierSameOptionQuantity =>
      'Can the same Option be added more than once?';

  @override
  String get modifierQuantityHelper => 'For example: 2 Extra Shots.';

  @override
  String get modifierCurrentRuleSummary => 'Current Rule Summary';

  @override
  String get modifierInitialOption => 'Initial Option';

  @override
  String get modifierInitialOptions => 'Initial Options';

  @override
  String get modifierInitialOptionHelper =>
      'Add enough active Options for the Maximum choices before creating the Modifier Group.';

  @override
  String get modifierAddAnotherOption => 'Add another Option';

  @override
  String get modifierRemoveOption => 'Remove Option';

  @override
  String modifierAtLeastActiveOptions(int count) {
    return 'Add at least $count active Options or reduce Maximum choices.';
  }

  @override
  String get modifierOptionName => 'Option name';

  @override
  String get modifierOptionNameHint => 'e.g. Whole Milk';

  @override
  String get modifierAdvanced => 'Advanced';

  @override
  String get modifierActiveStatus => 'Active status';

  @override
  String get modifierAvailableForUse => 'Available for use in menus.';

  @override
  String get modifierCancel => 'Cancel';

  @override
  String get modifierSaveChanges => 'Save Changes';

  @override
  String get modifierCreateAction => 'Create Modifier Group';

  @override
  String get modifierSaving => 'Saving...';

  @override
  String get modifierUnsavedChanges =>
      'You have unsaved changes. Leave without saving?';

  @override
  String get modifierStay => 'Stay';

  @override
  String get modifierLeave => 'Leave';

  @override
  String get modifierOptionCreateTitle => 'Add Option';

  @override
  String get modifierOptionEditTitle => 'Edit Option';

  @override
  String get modifierOptionBasicInformation => 'Basic Information';

  @override
  String get modifierOptionDefault => 'Default option';

  @override
  String get modifierOptionActive => 'Active';

  @override
  String get modifierOptionAvailable => 'Available';

  @override
  String get modifierOptionAdvanced => 'Advanced';

  @override
  String get modifierOptionSave => 'Save';

  @override
  String get modifierOptionSaving => 'Saving...';

  @override
  String get modifierOptionNameRequired => 'Option name is required.';

  @override
  String get modifierOptionPriceInvalid => 'Enter a valid price adjustment.';

  @override
  String get modifierOptionSortInvalid => 'Sort order must be a whole number.';

  @override
  String get modifierArchiveGroupTitle => 'Archive modifier group?';

  @override
  String get modifierArchiveOptionTitle => 'Archive modifier option?';

  @override
  String get modifierArchiveMessage =>
      'The item remains stored and can be restored later.';

  @override
  String get modifierConfirmArchive => 'Archive';

  @override
  String get modifierOptionSaveError =>
      'Unable to save this modifier option. Check the option rules and try again.';

  @override
  String get modifierOptionGroupInvalid =>
      'This Option cannot be changed because it would make the Modifier Group invalid.';

  @override
  String get modifierGroupSaveError => 'Unable to save this modifier group.';

  @override
  String get modifierGroupRequired => 'Modifier group name is required.';

  @override
  String get modifierNumberInvalid => 'Enter zero or a positive whole number.';

  @override
  String get modifierMaximumMinimumError =>
      'Maximum must be at least the minimum.';

  @override
  String get modifierSingleMaximumError =>
      'Single selection groups cannot have a maximum above 1.';

  @override
  String get modifierRequiredMinimumError =>
      'Required groups need a minimum of at least 1.';

  @override
  String get modifierInitialOptionRequired =>
      'An initial active option is required.';

  @override
  String get modifierPriceInvalid => 'Enter zero or a positive price.';

  @override
  String get modifierInitialMaximumError =>
      'A new group has one initial option; maximum cannot exceed 1.';

  @override
  String get configuredSellPriceMustBePositive =>
      'Selling price must be greater than zero.';

  @override
  String get recipeVariant => 'Variant';

  @override
  String recipeConfigured(int count) {
    return 'Recipe configured · $count materials';
  }

  @override
  String get recipeMissing => 'Recipe missing';

  @override
  String get recipeNotConfigured => 'Recipe not configured';

  @override
  String get recipeModifierMaterialEffects => 'Modifier Material Effects';

  @override
  String get recipeModifierMaterialEffectsHelp =>
      'See how customer choices change the materials consumed.';

  @override
  String get recipeNoMaterialChange => 'No material change';

  @override
  String get recipeUsingGlobalSettings => 'Using Global settings';

  @override
  String get recipeCustomizedForProduct => 'Customized for Product';

  @override
  String get recipeCustomizedForVariant => 'Customized for Variant';

  @override
  String get recipeTest => 'Test Recipe';

  @override
  String get recipeBackToWorkspace => 'Back to Recipe & Materials';

  @override
  String get recipeSave => 'Save recipe';

  @override
  String get recipeSaved => 'Recipe saved.';

  @override
  String get recipeCurrentBehavior => 'Current Behavior';

  @override
  String get recipeUseInherited => 'Use inherited settings';

  @override
  String get recipeUseInheritedAgain => 'Use inherited settings again';

  @override
  String recipeCustomizeFor(String context) {
    return 'Customize for $context';
  }

  @override
  String recipeNoMaterialEffectFor(String context) {
    return 'No material effect for $context';
  }

  @override
  String get recipeRemoves => 'Removes';

  @override
  String get recipeAdds => 'Adds';

  @override
  String get recipeAddMaterialToRemove => 'Add Material to Remove';

  @override
  String get recipeAddMaterialToAdd => 'Add Material to Add';

  @override
  String get recipeSaveChanges => 'Save Changes';

  @override
  String get recipeCancel => 'Cancel';

  @override
  String get recipeQuantityRequired => 'Quantity is required.';

  @override
  String get recipeQuantityInvalid =>
      'Enter a positive number with up to 6 decimal places.';

  @override
  String get recipeDuplicateMaterial => 'This material is already used.';

  @override
  String get recipeMaterialSearch => 'Search materials';

  @override
  String get recipeNoMaterialResults => 'No materials found.';

  @override
  String get recipeFinalMaterials => 'Final Materials';

  @override
  String get recipePreviewMaterials => 'Preview Materials';

  @override
  String get recipeHowCalculated => 'How this was calculated';

  @override
  String get recipeChoicesChanged => 'Choices changed';

  @override
  String get recipeStaleResult =>
      'Preview the materials again to update this result.';

  @override
  String get recipeDecreaseQuantity => 'Decrease quantity';

  @override
  String get recipeIncreaseQuantity => 'Increase quantity';

  @override
  String get batch8AvailabilityTitle => 'Selling availability';

  @override
  String get batch8AvailabilityHelp =>
      'Review the price, regular selling hours, and current operational status for this selling context.';

  @override
  String get batch8Variant => 'Variant';

  @override
  String get batch8Branch => 'Branch';

  @override
  String get batch8Channel => 'Channel';

  @override
  String get batch8AvailabilityLoadError => 'Availability could not be loaded.';

  @override
  String get batch8Retry => 'Retry';

  @override
  String get batch8Loading => 'Loading…';

  @override
  String get batch8Checking => 'Checking…';

  @override
  String get batch8SellingPrice => 'Selling price';

  @override
  String get batch8BasePrice => 'Base price';

  @override
  String get batch8EffectiveSellingPrice => 'Effective selling price';

  @override
  String get batch8Using => 'Using';

  @override
  String get batch8ManagePricing => 'Manage pricing';

  @override
  String get batch8PriceLoadingHelp =>
      'Resolving the selling price for this context.';

  @override
  String get batch8PriceFromBase => 'Variant base price';

  @override
  String get batch8PriceFromBranch => 'Branch price';

  @override
  String get batch8PriceFromChannel => 'Channel price';

  @override
  String get batch8PriceFromBranchAndChannel => 'Branch and channel price';

  @override
  String get batch8RegularAvailability => 'Regular availability';

  @override
  String get batch8NoScheduleRestrictions => 'No schedule restrictions';

  @override
  String get batch8NoScheduleRestrictionsHelp =>
      'Normally available whenever this selling context is open.';

  @override
  String get batch8ScheduleLoadingHelp =>
      'Checking regular selling hours for this context.';

  @override
  String get batch8AvailableNow => 'Available now';

  @override
  String get batch8UnavailableNow => 'Unavailable now';

  @override
  String get batch8Unavailable => 'Unavailable';

  @override
  String get batch8AvailableAccordingSchedule =>
      'Available according to regular selling hours.';

  @override
  String get batch8UnavailableAccordingSchedule =>
      'Outside the regular selling hours.';

  @override
  String get batch8ScheduleRules => 'Configured selling hours';

  @override
  String get batch8ManageSchedule => 'Manage schedule';

  @override
  String get batch8CurrentAvailability => 'Current availability';

  @override
  String get batch8CurrentLoadingHelp =>
      'Checking temporary operational status for this context.';

  @override
  String get batch8SoldOut => 'Sold out';

  @override
  String get batch8TemporarilyUnavailable => 'Temporarily unavailable';

  @override
  String get batch8NoTemporaryRestriction =>
      'No temporary restriction is active.';

  @override
  String get batch8TemporaryRestrictionActive =>
      'A temporary operational restriction is active.';

  @override
  String batch8TemporaryUntil(String time) {
    return 'Temporary restriction active until $time.';
  }

  @override
  String get batch8ManageAvailability => 'Manage availability';

  @override
  String get batch8EffectiveSellingResult => 'Effective selling result';

  @override
  String get batch8Availability => 'Availability';

  @override
  String get batch8PricingBack => 'Back';

  @override
  String get batch8PricingRefresh => 'Refresh';

  @override
  String get batch8PricingLoadError => 'Pricing could not be loaded.';

  @override
  String get batch8PricingArchived =>
      'This Product or Variant is archived. Prices are shown for reference and cannot be changed.';

  @override
  String batch8PricingContext(String variant) {
    return '$variant · Selling price';
  }

  @override
  String get batch8PricingHelp =>
      'The selling price for the selected Variant, Branch, and sales channel.';

  @override
  String get batch8SalesChannel => 'Sales channel';

  @override
  String get batch8NoBranch => 'No Branch';

  @override
  String get batch8NoChannel => 'No Channel';

  @override
  String get batch8ChangePrice => 'Change Price';

  @override
  String get batch8MorePriceRules => 'More Price Rules';

  @override
  String batch8RulesConfigured(int count) {
    return '$count configured';
  }

  @override
  String get batch8Show => 'Show';

  @override
  String get batch8Hide => 'Hide';

  @override
  String get batch8NoPriceAdjustments => 'No price adjustments.';

  @override
  String get batch8BasePriceEverywhere => 'Base Price applies everywhere.';

  @override
  String get batch8Difference => 'Difference';

  @override
  String get batch8AddPrice => 'Add Price';

  @override
  String get batch8SetSellingPrice => 'Set Selling Price';

  @override
  String get batch8Product => 'Product';

  @override
  String get batch8AppliesTo => 'Applies to';

  @override
  String get batch8ScopeBranch => 'Branch';

  @override
  String get batch8ScopeChannel => 'Channel';

  @override
  String get batch8ScopeBranchChannel => 'Branch + Channel';

  @override
  String get batch8Price => 'Price';

  @override
  String batch8PriceAboveBase(String difference) {
    return '$difference above Base Price';
  }

  @override
  String batch8PriceBelowBase(String difference) {
    return '$difference below Base Price';
  }

  @override
  String get batch8PriceSameAsBase => 'Same as Base Price';

  @override
  String get batch8Cancel => 'Cancel';

  @override
  String get batch8SavePrice => 'Save Price';

  @override
  String get batch8Edit => 'Edit';

  @override
  String get batch8Remove => 'Remove';

  @override
  String get batch8RemovePriceTitle => 'Remove price rule?';

  @override
  String get batch8RemovePriceMessage =>
      'This price adjustment will be removed for this Variant.';

  @override
  String get batch8Keep => 'Keep';

  @override
  String batch8BranchPriceFor(String branch) {
    return '$branch Branch price';
  }

  @override
  String batch8ChannelPriceFor(String channel) {
    return '$channel channel price';
  }

  @override
  String batch8BranchChannelPriceFor(String branch, String channel) {
    return '$branch · $channel price';
  }

  @override
  String get batch8RuleBranchPrice => 'Branch price';

  @override
  String get batch8RuleChannelPrice => 'Channel price';

  @override
  String get batch8RuleBranchChannelPrice => 'Branch + Channel price';

  @override
  String get batch8ChannelPos => 'POS';

  @override
  String get batch8ChannelWaiterApp => 'Waiter App';

  @override
  String get batch8ChannelKiosk => 'Kiosk';

  @override
  String get batch8ChannelQrOrdering => 'QR Ordering';

  @override
  String get batch8ChannelDelivery => 'Delivery';

  @override
  String get batch8ChannelOnlineOrdering => 'Online Ordering';

  @override
  String get batch8UnsavedPriceChanges => 'Unsaved price changes';

  @override
  String get batch8UnsavedPriceChangesMessage =>
      'You have unsaved price changes. Leave without saving?';

  @override
  String get batch8Leave => 'Leave';
}
