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
  String get errorConnectionUnavailable => 'Connection unavailable.';

  @override
  String get errorAuthenticationRequired => 'Authentication required.';

  @override
  String get errorPermissionDenied =>
      'You do not have permission to perform this action.';

  @override
  String get errorConflict => 'This action conflicts with the current state.';

  @override
  String get errorServer => 'Something went wrong. Please try again.';

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
  String get posNoPublishedMenu =>
      'No menu has been published for this branch yet.';

  @override
  String get posNoAvailableMenu => 'No published menu is currently available.';

  @override
  String get posNoAvailableItems => 'No available items in this section.';

  @override
  String get posUnableToLoadMenu => 'Unable to load the published menu.';

  @override
  String get posMenuRefreshRequired =>
      'Menu data needs refresh before this order can continue.';

  @override
  String get posOfflineUsingSavedMenu => 'Offline — using saved menu';

  @override
  String get posSyncErrorUsingSavedMenu =>
      'Unable to sync menu — using saved menu';

  @override
  String posLastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String get posMenuUpdateReady =>
      'Menu update ready — will apply after current order';

  @override
  String get posNoSavedMenu =>
      'No saved menu available. Reconnect to load menu.';

  @override
  String get posConnectionRequiredToCompleteOrder =>
      'Connection required to complete this order.';

  @override
  String get posMenuChangedReviewOrder => 'Menu changed — review order.';

  @override
  String get posBranchSwitchBlockedWithCart =>
      'Finish, hold, or cancel the current order before switching branches.';

  @override
  String get posTemporarilyUnavailable => 'Temporarily unavailable';

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
  String get versionView => 'View';

  @override
  String versionSelectForCompare(int version) {
    return 'Select Version $version for comparison';
  }

  @override
  String versionCompareSelected(int count) {
    return 'Compare selected ($count)';
  }

  @override
  String get versionHistoryEmptyTitle => 'No version history';

  @override
  String versionHistoryEmptyDescription(Object branch, Object channel) {
    return 'No Menu version has been published for $branch · $channel yet.';
  }

  @override
  String get versionHistoryLoadError => 'Could not load version history.';

  @override
  String get versionDetailLoadError => 'Could not load this version.';

  @override
  String get versionCompareError => 'Could not compare these versions.';

  @override
  String get versionRestoreError => 'Could not restore this version.';

  @override
  String get versionPreviousPage => 'Previous';

  @override
  String get versionNextPage => 'Next';

  @override
  String versionPage(int page) {
    return 'Page $page';
  }

  @override
  String versionChangeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0';
  }

  @override
  String versionChangesSince(num count, int version) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0 since Version $version';
  }

  @override
  String versionPublishedAt(Object date) {
    return 'Published $date';
  }

  @override
  String get versionMenus => 'Menus';

  @override
  String get versionSections => 'Sections';

  @override
  String get versionProducts => 'Products';

  @override
  String get versionPricing => 'Pricing';

  @override
  String get versionModifiers => 'Modifiers';

  @override
  String get versionRecipes => 'Recipes';

  @override
  String get versionSchedules => 'Schedules';

  @override
  String get versionChanges => 'changes';

  @override
  String get versionChangeSummary => 'Change summary';

  @override
  String get versionChangeSummaryAvailable =>
      'This version includes a recorded change summary.';

  @override
  String get versionChangeSummaryUnavailable =>
      'No change summary is available for this version.';

  @override
  String get versionRestoreThisVersion => 'Restore this Version';

  @override
  String versionRestoreTitle(int version) {
    return 'Restore Version $version?';
  }

  @override
  String versionRestoreExplanation(int version) {
    return 'A new published version will be created using the contents of Version $version. Versions published after Version $version will remain in history.';
  }

  @override
  String get versionRestoreReason => 'Reason for restore (optional)';

  @override
  String get versionRestoreReasonHint =>
      'For example, restore after an unintended pricing change';

  @override
  String get versionRestoreAsNewVersion => 'Restore as New Version';

  @override
  String get versionRestoring => 'Restoring…';

  @override
  String get versionRestoreResultTitle => 'Version restored';

  @override
  String versionRestoreSuccess(int newVersion, int sourceVersion) {
    return 'Version $newVersion was created from Version $sourceVersion. Version $newVersion is now Current.';
  }

  @override
  String versionRestoreNoChanges(int version) {
    return 'Version $version already matches the current published content. No new version was created.';
  }

  @override
  String versionComparisonDirection(int fromVersion, int toVersion) {
    return 'Version $fromVersion → Version $toVersion';
  }

  @override
  String get versionNoContentDifferences => 'No content differences found.';

  @override
  String get versionComparisonTruncated => 'Additional changes are not shown.';

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
  String get menuManagementAssignments => 'Assignments & Schedules';

  @override
  String get menuManagementReview => 'Review & preview';

  @override
  String get menuManagementCatalogSetup => 'Catalog Setup';

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

  @override
  String get scheduledUnsavedChanges => 'Unsaved selling hours';

  @override
  String get scheduledUnsavedChangesHelp =>
      'You have unsaved selling-hours changes. Leave without saving?';

  @override
  String get scheduledStay => 'Stay';

  @override
  String get scheduledLeave => 'Leave';

  @override
  String get scheduledLoadError =>
      'Scheduled availability could not be loaded.';

  @override
  String get scheduledSaveError =>
      'Selling hours could not be saved. Please review the entered values and try again.';

  @override
  String get scheduledSaved => 'Selling hours saved.';

  @override
  String get scheduledArchived =>
      'This Product or Variant is archived. Selling hours are shown for reference and cannot be changed.';

  @override
  String get scheduledRegularForProduct => 'Product · Regular availability';

  @override
  String scheduledRegularForVariant(String variant) {
    return '$variant · Regular availability';
  }

  @override
  String get scheduledProduct => 'Product';

  @override
  String get scheduledAllBranches => 'All branches';

  @override
  String get scheduledAllChannels => 'All channels';

  @override
  String get scheduledUsingProduct => 'Using Product schedule';

  @override
  String get scheduledProductSchedule => 'Product schedule';

  @override
  String scheduledCustomizedFor(String variant) {
    return 'Customized for $variant';
  }

  @override
  String scheduledCustomizeFor(String variant) {
    return 'Customize for $variant';
  }

  @override
  String get scheduledUseProductAgain => 'Use Product schedule again';

  @override
  String get scheduledWeeklyInAdvanced =>
      'Weekly hours are shown in Advanced Schedule Rules.';

  @override
  String get scheduledNoSpecificRestriction => 'No specific restriction';

  @override
  String get scheduledAvailableAllDay => 'Available all day';

  @override
  String get scheduledEditSellingHours => 'Edit Selling Hours';

  @override
  String get scheduledAdvancedRules => 'Advanced Schedule Rules';

  @override
  String get scheduledNoAdvancedRules => 'No advanced schedule rules';

  @override
  String get scheduledViewRules => 'View Rules';

  @override
  String get scheduledInactiveRule => 'Inactive schedule rule';

  @override
  String get scheduledPriorityRule => 'Priority schedule rule';

  @override
  String get scheduledDateBoundRule => 'Date-limited schedule rule';

  @override
  String get scheduledCheckAvailability => 'Check Availability';

  @override
  String get scheduledCheckHelp =>
      'Check a date and time in the selected selling context.';

  @override
  String get scheduledDate => 'Date';

  @override
  String get scheduledTime => 'Time';

  @override
  String get scheduledCheck => 'Check';

  @override
  String get scheduledCheckError =>
      'Availability could not be checked. Please try again.';

  @override
  String get scheduledAvailableUsingProduct =>
      'Available according to the Product schedule.';

  @override
  String get scheduledDay => 'Day';

  @override
  String get scheduledEveryDay => 'Every day';

  @override
  String get scheduledAvailability => 'Availability';

  @override
  String get scheduledAvailableAllDayHelp =>
      'No time restriction for this day.';

  @override
  String get scheduledCustomHours => 'Custom hours';

  @override
  String get scheduledCustomHoursHelp => 'Set the normal start and end time.';

  @override
  String get scheduledStartTime => 'Start time';

  @override
  String get scheduledEndTime => 'End time';

  @override
  String scheduledOvernightUntil(String time) {
    return 'Available overnight until $time the next day.';
  }

  @override
  String get scheduledDateLimits => 'Date Limits';

  @override
  String get scheduledOptional => 'Optional';

  @override
  String get scheduledStartDate => 'Start date';

  @override
  String get scheduledEndDate => 'End date';

  @override
  String get scheduledSelectDate => 'Select date';

  @override
  String get scheduledAdvanced => 'Advanced';

  @override
  String get scheduledPriority => 'Priority';

  @override
  String get scheduledActive => 'Active';

  @override
  String get scheduledSaveSellingHours => 'Save Selling Hours';

  @override
  String get scheduledFrom => 'From';

  @override
  String get scheduledUntil => 'Until';

  @override
  String get scheduledSunday => 'Sunday';

  @override
  String get scheduledMonday => 'Monday';

  @override
  String get scheduledTuesday => 'Tuesday';

  @override
  String get scheduledWednesday => 'Wednesday';

  @override
  String get scheduledThursday => 'Thursday';

  @override
  String get scheduledFriday => 'Friday';

  @override
  String get scheduledSaturday => 'Saturday';

  @override
  String get operationalAvailabilityTitle => 'Operational availability';

  @override
  String get operationalAvailabilityPurpose =>
      'Can customers order this item right now? Temporary operational exceptions only.';

  @override
  String get operationalAvailabilityContext => 'Current context';

  @override
  String get operationalAvailabilityProductVariant => 'Product / Variant';

  @override
  String get operationalAvailabilityProductOnly => 'Product';

  @override
  String get operationalAvailabilityBranch => 'Branch';

  @override
  String get operationalAvailabilityChannel => 'Sales channel';

  @override
  String get operationalAvailabilitySelectBranch => 'Select an active branch';

  @override
  String get operationalAvailabilitySelectChannel => 'Select a sales channel';

  @override
  String get operationalAvailabilityAvailableNow => 'AVAILABLE NOW';

  @override
  String get operationalAvailabilitySoldOut => 'SOLD OUT';

  @override
  String get operationalAvailabilityTemporarilyUnavailable =>
      'TEMPORARILY UNAVAILABLE';

  @override
  String get operationalAvailabilityNoRestriction =>
      'No temporary restriction is active.';

  @override
  String get operationalAvailabilityActiveRestriction =>
      'A temporary operational restriction is active.';

  @override
  String operationalAvailabilityUntil(String time) {
    return 'Until: $time';
  }

  @override
  String get operationalAvailabilityReason => 'Reason';

  @override
  String get operationalAvailabilityMarkUnavailable =>
      'Mark temporarily unavailable';

  @override
  String get operationalAvailabilityMakeAvailable => 'Make available now';

  @override
  String get operationalAvailabilityEditStatus => 'Edit status';

  @override
  String get operationalAvailabilityEditTemporary =>
      'Edit temporary restriction';

  @override
  String get operationalAvailabilityUseDefault => 'Use default status';

  @override
  String get operationalAvailabilityUseDefaultTitle => 'Use default status?';

  @override
  String get operationalAvailabilityUseDefaultMessage =>
      'This removes only the status set for this exact product context. The resulting availability will be checked again.';

  @override
  String get operationalAvailabilityDefaultAction => 'Use default';

  @override
  String get operationalAvailabilityAllVariants =>
      'This status applies to all variants of this product.';

  @override
  String operationalAvailabilityOnlyVariant(String variant) {
    return 'This status affects only $variant.';
  }

  @override
  String get operationalAvailabilityLoadingCurrent =>
      'Updating current availability…';

  @override
  String get operationalAvailabilityNoContext =>
      'Choose an active branch and sales channel to view current availability.';

  @override
  String get operationalAvailabilityLoadError =>
      'We couldn’t load current availability. Try again.';

  @override
  String get operationalAvailabilityArchived =>
      'This item is archived. Current availability is shown for reference and cannot be changed.';

  @override
  String get operationalAvailabilitySetStatus => 'Set availability status';

  @override
  String get operationalAvailabilityEditStatusTitle =>
      'Edit availability status';

  @override
  String get operationalAvailabilityStatus => 'Status';

  @override
  String get operationalAvailabilityDuration => 'Duration';

  @override
  String get operationalAvailabilitySpecificTime => 'Until a specific time';

  @override
  String get operationalAvailabilityEndTimeRequired =>
      'Select when this temporary restriction should end.';

  @override
  String get operationalAvailabilitySelectEndTime => 'Select end date and time';

  @override
  String get operationalAvailabilityBranchTime =>
      'The time is shown in the selected branch’s local time.';

  @override
  String get operationalAvailabilitySave => 'Save status';

  @override
  String get operationalAvailabilitySaving => 'Saving…';

  @override
  String get operationalAvailabilityCancel => 'Cancel';

  @override
  String get operationalAvailabilityExplicitAvailable =>
      'Available for this selling context.';

  @override
  String get operationalAvailabilitySaveError =>
      'We couldn’t save this availability status. Review the details and try again.';

  @override
  String get catalogSetupWorkspaceHelp =>
      'Configure the classifications and preparation destinations used by Products.';

  @override
  String get catalogSetupCategoriesPurpose =>
      'Organize Products into clear catalog and menu groups.';

  @override
  String get catalogSetupReportingPurpose =>
      'Group Products for sales and performance reporting.';

  @override
  String get catalogSetupReportingNote =>
      'Reporting Categories do not control where Products appear in the menu.';

  @override
  String get catalogSetupStationsPurpose =>
      'Define where Products and items are prepared.';

  @override
  String get catalogSetupSearchCategories => 'Search categories...';

  @override
  String get catalogSetupSearchReporting => 'Search reporting categories...';

  @override
  String get catalogSetupSearchStations => 'Search kitchen stations...';

  @override
  String catalogSetupAdd(String type) {
    return 'Add $type';
  }

  @override
  String catalogSetupSave(String type) {
    return 'Save $type';
  }

  @override
  String get catalogSetupNoCategories => 'No categories yet';

  @override
  String get catalogSetupNoReportingCategories => 'No reporting categories yet';

  @override
  String get catalogSetupNoKitchenStations => 'No kitchen stations yet';

  @override
  String get catalogSetupEmptyCategoriesHelp =>
      'Categories help organize Products into clear groups.';

  @override
  String get catalogSetupEmptyReportingHelp =>
      'Reporting Categories help group Products for useful sales reporting.';

  @override
  String get catalogSetupEmptyStationsHelp =>
      'Kitchen Stations help define where each Product is prepared.';

  @override
  String get catalogSetupCouldNotLoad => 'Couldn’t load data';

  @override
  String get catalogSetupLoadHelp =>
      'Please check your connection and try again.';

  @override
  String catalogSetupShowing(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String get catalogSetupActive => 'Active';

  @override
  String get catalogSetupArchived => 'Archived';

  @override
  String get catalogSetupInactive => 'Inactive';

  @override
  String get catalogSetupEditorHelp =>
      'Use the names that staff and customers should recognize.';

  @override
  String get catalogSetupPrimaryName => 'Name';

  @override
  String catalogSetupArchiveTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String get catalogSetupArchiveHelp =>
      'Archived records can be restored later. Existing Product assignments follow the system’s current rules.';

  @override
  String get catalogSetupValidationRequired => 'Enter a name to continue.';

  @override
  String get catalogSetupRefreshInProgress => 'Refreshing catalog setup';

  @override
  String get menuListTitle => 'Menus';

  @override
  String get menuListSubtitle =>
      'Create and organize the menus customers can order from.';

  @override
  String get menuListAdd => 'Add Menu';

  @override
  String get menuListSearch => 'Search menus...';

  @override
  String get menuListStatus => 'Status';

  @override
  String get menuListSort => 'Sort';

  @override
  String get menuListDirection => 'Direction';

  @override
  String get menuListRefresh => 'Refresh menus';

  @override
  String get menuListMenu => 'Menu';

  @override
  String get menuListSections => 'Sections';

  @override
  String get menuListVisibleProducts => 'Visible Products';

  @override
  String get menuListLastUpdated => 'Last Updated';

  @override
  String get menuListActions => 'Actions';

  @override
  String get menuListOpen => 'Open';

  @override
  String get menuListClearFilters => 'Clear filters';

  @override
  String get menuListNoMenusYet => 'No menus yet';

  @override
  String get menuListNoMenusHelp =>
      'Create your first Menu and start organizing Products into Sections.';

  @override
  String get menuListNoMatches => 'No menus match these filters.';

  @override
  String get menuListNoMatchesHelp =>
      'Try changing the search or status filter.';

  @override
  String get menuListCouldNotLoad => 'Couldn’t load menus';

  @override
  String get menuListCouldNotLoadHelp => 'Check your connection and try again.';

  @override
  String get menuListLoadMore => 'Load more';

  @override
  String get menuListArchiveTitle => 'Archive menu?';

  @override
  String get menuListArchiveHelp =>
      'The menu can be restored later. Existing orders and published versions are unchanged.';

  @override
  String get menuListRestoreTitle => 'Restore menu?';

  @override
  String get menuListRestoreHelp =>
      'Restoring makes the menu editable again. It does not publish the menu.';

  @override
  String menuListActionsFor(String name) {
    return 'Actions for $name';
  }

  @override
  String get menuListPaused => 'Paused';

  @override
  String get menuListPriority => 'Priority';

  @override
  String get menuListName => 'Name';

  @override
  String get menuListCreated => 'Created';

  @override
  String get menuListUpdated => 'Last updated';

  @override
  String get menuListAscending => 'Ascending';

  @override
  String get menuListDescending => 'Descending';

  @override
  String get menuListAll => 'All';

  @override
  String get menuListDraft => 'Draft';

  @override
  String get menuListActive => 'Active';

  @override
  String get menuListArchived => 'Archived';

  @override
  String get menuListEdit => 'Edit';

  @override
  String get menuListArchive => 'Archive';

  @override
  String get menuListRestore => 'Restore';

  @override
  String get menuListCancel => 'Cancel';

  @override
  String get menuListRetry => 'Retry';

  @override
  String get menuEditorAddTitle => 'Add Menu';

  @override
  String get menuEditorEditTitle => 'Edit Menu';

  @override
  String get menuEditorAddHelp =>
      'Start with the names your staff and customers recognize.';

  @override
  String get menuEditorEditHelp =>
      'Update the menu identity without leaving this workspace.';

  @override
  String get menuEditorClose => 'Close menu editor';

  @override
  String get menuEditorEnglishName => 'English Name';

  @override
  String get menuEditorArabicName => 'Arabic Name';

  @override
  String get menuEditorMoreDetails => 'More details';

  @override
  String get menuEditorHideDetails => 'Hide details';

  @override
  String get menuEditorEnglishDescription => 'English Description';

  @override
  String get menuEditorArabicDescription => 'Arabic Description';

  @override
  String get menuEditorCoverImageUrl => 'Cover image URL';

  @override
  String get menuEditorPriority => 'Priority';

  @override
  String get menuEditorPriorityHelp =>
      'Controls the ordering when menus are shown together.';

  @override
  String get menuEditorStatus => 'Menu status';

  @override
  String get menuEditorCreate => 'Create Menu';

  @override
  String get menuEditorSaveChanges => 'Save Changes';

  @override
  String get menuEditorDraftHelp =>
      'New menus start as Draft. You can activate them later.';

  @override
  String get menuEditorNameRequired =>
      'Enter an English or Arabic name to continue.';

  @override
  String get menuEditorPriorityInvalid => 'Enter a whole number for priority.';

  @override
  String get menuEditorSaveFailed =>
      'We couldn’t save this menu. Please try again.';

  @override
  String get menuEditorArchivedReadOnly =>
      'Archived menus are read-only. Restore this menu before editing it.';

  @override
  String get menuEditorStatusDraft => 'Draft';

  @override
  String get menuEditorStatusActive => 'Active';

  @override
  String get menuEditorStatusPaused => 'Paused';

  @override
  String get menuEditorStatusArchived => 'Archived';

  @override
  String get menuOverviewEditMenu => 'Edit Menu';

  @override
  String get menuOverviewActions => 'Menu actions';

  @override
  String get menuOverviewTab => 'Overview';

  @override
  String get menuOverviewSectionsTab => 'Sections';

  @override
  String get menuOverviewProductsTab => 'Products';

  @override
  String get menuOverviewWorkspaceTabs => 'Menu workspace tabs';

  @override
  String get menuOverviewDetails => 'Menu details';

  @override
  String get menuOverviewName => 'Name';

  @override
  String get menuOverviewStatus => 'Status';

  @override
  String get menuOverviewComposition => 'Composition';

  @override
  String get menuOverviewManageSections => 'Manage Sections';

  @override
  String get menuOverviewManageProducts => 'Manage Products';

  @override
  String menuOverviewCompositionValue(
    int sectionCount,
    int visibleProductCount,
  ) {
    return '$sectionCount Sections · $visibleProductCount visible Products';
  }

  @override
  String get menuOverviewDraft => 'Draft';

  @override
  String get menuOverviewActive => 'Active';

  @override
  String get menuOverviewPaused => 'Paused';

  @override
  String get menuOverviewArchived => 'Archived';

  @override
  String get menuOverviewArchivedReadOnly =>
      'This menu is archived and read-only. Restore it before changing its composition.';

  @override
  String get menuOverviewLoading => 'Loading menu workspace';

  @override
  String get menuOverviewCouldNotLoad => 'Couldn’t load this menu';

  @override
  String get menuOverviewArchive => 'Archive';

  @override
  String get menuOverviewRestore => 'Restore';

  @override
  String get menuSectionsTitle => 'Sections';

  @override
  String get menuSectionsHelp =>
      'Organize this menu into customer-friendly groups.';

  @override
  String get menuSectionsAdd => 'Add Section';

  @override
  String get menuSectionsReorder => 'Reorder Sections';

  @override
  String get menuSectionsDone => 'Done';

  @override
  String get menuSectionsReorderHelp =>
      'Use the arrows to change the order customers see.';

  @override
  String menuSectionsProducts(int count) {
    return '$count Products';
  }

  @override
  String get menuSectionsArchived => 'Archived';

  @override
  String get menuSectionsInactive => 'Inactive';

  @override
  String menuSectionsActions(String name) {
    return 'Actions for $name';
  }

  @override
  String get menuSectionsEdit => 'Edit';

  @override
  String get menuSectionsArchive => 'Archive';

  @override
  String get menuSectionsRestore => 'Restore';

  @override
  String get menuSectionsMoveUp => 'Move Up';

  @override
  String get menuSectionsMoveDown => 'Move Down';

  @override
  String get menuSectionsNoSections => 'No Sections yet';

  @override
  String get menuSectionsEmptyHelp =>
      'Create a Section before adding Products.';

  @override
  String get menuSectionsLoadError => 'Couldn’t load Sections';

  @override
  String get menuSectionEditorAddTitle => 'Add Section';

  @override
  String get menuSectionEditorEditTitle => 'Edit Section';

  @override
  String get menuSectionEditorAddHelp =>
      'Create a clear group customers can browse.';

  @override
  String get menuSectionEditorEditHelp =>
      'Update this group without leaving the menu workspace.';

  @override
  String get menuSectionEditorClose => 'Close Section editor';

  @override
  String get menuSectionEditorEnglishName => 'English Name';

  @override
  String get menuSectionEditorArabicName => 'Arabic Name';

  @override
  String get menuSectionEditorMoreDetails => 'More details';

  @override
  String get menuSectionEditorHideDetails => 'Hide details';

  @override
  String get menuSectionEditorDescription => 'Description';

  @override
  String get menuSectionEditorImageUrl => 'Image URL';

  @override
  String get menuSectionEditorActive => 'Active Section';

  @override
  String get menuSectionEditorNameRequired =>
      'Enter an English or Arabic name to continue.';

  @override
  String get menuSectionEditorSaveFailed =>
      'Couldn’t save this Section. Check the fields and try again.';

  @override
  String get menuSectionEditorSave => 'Save Changes';

  @override
  String get menuProductsTitle => 'Products';

  @override
  String get menuProductsHelp =>
      'Organize the Products customers see inside each Section.';

  @override
  String get menuProductsAdd => 'Add Products';

  @override
  String get menuProductsReorder => 'Reorder Products';

  @override
  String get menuProductsDone => 'Done';

  @override
  String get menuProductsReorderHelp =>
      'Use the arrows to set the order customers see within each Section.';

  @override
  String get menuProductsSearchHint => 'Search Products in this Menu';

  @override
  String menuProductsCount(int count) {
    return '$count Products';
  }

  @override
  String get menuProductsPickerTitle => 'Add Products';

  @override
  String get menuProductsPickerTargetSection => 'Add to Section';

  @override
  String get menuProductsPickerSearchHint => 'Search Products...';

  @override
  String menuProductsPickerAlreadyInSection(String section) {
    return 'Already in $section';
  }

  @override
  String menuProductsPickerSelected(int count) {
    return 'Selected: $count';
  }

  @override
  String get menuProductsPickerNoMatches => 'No Products match your search.';

  @override
  String get menuProductsPickerNoEligible =>
      'All available Products are already in this Section.';

  @override
  String get menuProductsPickerLoadError => 'Could not load Products.';

  @override
  String menuProductsPickerPartialAdded(int added, int failed) {
    return '$added Products were added. $failed could not be added.';
  }

  @override
  String menuProductsPickerConflict(String section) {
    return 'This Product is already in $section.';
  }

  @override
  String menuProductsBasePrice(String price) {
    return 'Base $price';
  }

  @override
  String get menuProductsFeatured => 'Featured';

  @override
  String get menuProductsHidden => 'Hidden';

  @override
  String get menuProductsArchivedPlacement => 'Removed from Menu';

  @override
  String get menuProductsArchivedProduct => 'Archived Product';

  @override
  String get menuProductsInactive => 'Inactive';

  @override
  String get menuProductsActions => 'Product actions';

  @override
  String get menuProductsMarkFeatured => 'Mark Featured';

  @override
  String get menuProductsRemoveFeatured => 'Remove Featured';

  @override
  String get menuProductsHide => 'Hide from Menu';

  @override
  String get menuProductsShow => 'Show on Menu';

  @override
  String get menuProductsMove => 'Move to Section';

  @override
  String get menuProductsRemove => 'Remove from Menu';

  @override
  String get menuProductsRestore => 'Restore Placement';

  @override
  String get menuProductsMoveUp => 'Move Up';

  @override
  String get menuProductsMoveDown => 'Move Down';

  @override
  String get menuProductsEmpty => 'No Products in this Section yet.';

  @override
  String get menuProductsNoMatches => 'No matching Products in this Section.';

  @override
  String get menuProductsNoSections => 'No Sections yet';

  @override
  String get menuProductsNoSectionsHelp =>
      'Create a Section before adding Products.';

  @override
  String get menuProductsArchivedMenuReadOnly =>
      'This menu is archived and read-only. Its composition remains available to review.';

  @override
  String get menuProductsLoadError => 'Couldn’t load Products';

  @override
  String get menuProductsRemoveHelp =>
      'This removes the Product from this Section and Menu only. The Product remains in the Catalog.';

  @override
  String get menuProductsRestoreHelp =>
      'This restores this Placement only. It does not restore or reactivate the Product.';

  @override
  String get assignmentsWorkspaceTitle => 'Assignments & Schedules';

  @override
  String get assignmentsWorkspaceHelp =>
      'Choose a Branch and sales channel, then control which Menus are available in that selling context.';

  @override
  String get assignmentsBranch => 'Branch';

  @override
  String get assignmentsSalesChannel => 'Sales Channel';

  @override
  String get assignmentsTimezone => 'Timezone';

  @override
  String get assignmentsChooseBranch => 'Choose a Branch';

  @override
  String get assignmentsChooseChannel => 'Choose a sales channel';

  @override
  String get assignmentsTimezonePending => 'Select a Branch';

  @override
  String get assignmentsNoContextTitle => 'Choose a selling context';

  @override
  String get assignmentsNoContextHelp =>
      'Select a Branch and sales channel to manage its Menus.';

  @override
  String get assignmentsAssignedMenus => 'Assigned Menus';

  @override
  String assignmentsMenuCount(int count) {
    return '$count Menus assigned';
  }

  @override
  String get assignmentsReorderMenus => 'Reorder Menus';

  @override
  String get assignmentsReorderHelp =>
      'Use the arrows to change the order Menus appear in this selling context. Ordering does not decide which Menu wins.';

  @override
  String get assignmentsReorderDone => 'Done';

  @override
  String get assignmentsMoveUp => 'Move up';

  @override
  String get assignmentsMoveDown => 'Move down';

  @override
  String get assignmentsReorderSaveFailed =>
      'We couldn\'t save this Menu order. Try again.';

  @override
  String get assignmentsReorderArchivedUnavailable =>
      'Reordering is unavailable while this selling context contains an archived Menu. Remove the archived assignment first.';

  @override
  String get assignmentsAddMenus => 'Add Menus';

  @override
  String get assignmentsNoMenusTitle => 'No Menus assigned';

  @override
  String assignmentsNoMenusHelp(String branch, String channel) {
    return 'Add a Menu to $branch · $channel.';
  }

  @override
  String get assignmentsLoadErrorTitle => 'Couldn\'t load assignments';

  @override
  String assignmentsLifecycle(String status) {
    return 'Menu: $status';
  }

  @override
  String get assignmentsPaused => 'Paused';

  @override
  String get assignmentsActive => 'Assignment Active';

  @override
  String get assignmentsInactive => 'Assignment Inactive';

  @override
  String get assignmentsAvailableNow => 'Available now';

  @override
  String get assignmentsOutsideHours => 'Outside scheduled hours';

  @override
  String get assignmentsNoScheduleRestriction => 'No schedule restriction';

  @override
  String get assignmentsScheduleUnknown => 'Schedule status unavailable';

  @override
  String get assignmentsManageSchedule => 'Manage Schedule';

  @override
  String get assignmentsRemove => 'Remove from this selling context';

  @override
  String get assignmentsArchivedDiagnostic =>
      'Archived Menu — actions unavailable';

  @override
  String get assignmentsChannelWaiterApp => 'Waiter App';

  @override
  String get assignmentsChannelKiosk => 'Kiosk';

  @override
  String get assignmentsChannelQrOrdering => 'QR Ordering';

  @override
  String get assignmentsChannelDelivery => 'Delivery';

  @override
  String get assignmentsChannelOnlineOrdering => 'Online Ordering';

  @override
  String get assignmentsMenuFallback => 'Menu';

  @override
  String get assignmentsAddSearch => 'Search Menus';

  @override
  String get assignmentsAddEmpty =>
      'All available Menus are already assigned to this selling context.';

  @override
  String assignmentsAddSelected(int count) {
    return 'Selected: $count';
  }

  @override
  String assignmentsAddSelectedAction(int count) {
    return 'Add $count Menus';
  }

  @override
  String get assignmentsAddAlreadyAssigned => 'Already assigned';

  @override
  String get assignmentsAddArchivedUnavailable =>
      'Archived Menus can’t be assigned.';

  @override
  String get assignmentsAddNoMatches => 'No Menus match your search.';

  @override
  String get assignmentsAddLoadError => 'Couldn’t load Menus';

  @override
  String get assignmentsAddSaveError => 'Couldn’t add Menus. Try again.';

  @override
  String get assignmentsAddDuplicateError =>
      'One or more Menus are already assigned to this selling context.';

  @override
  String get assignmentsAddArchivedScopeError =>
      'Adding Menus is unavailable while this selling context contains an archived Menu. Remove the archived assignment first.';

  @override
  String get menuScheduleTitle => 'Menu Schedule';

  @override
  String menuScheduleTimesShownIn(String timezone) {
    return 'Times shown in $timezone';
  }

  @override
  String get menuScheduleUsingBroader => 'Using broader Menu schedule';

  @override
  String menuScheduleCustomizedFor(String context) {
    return 'Customized for $context';
  }

  @override
  String get menuScheduleCustomize => 'Customize for this context';

  @override
  String get menuScheduleUseBroader => 'Use broader schedule';

  @override
  String get menuScheduleAvailableAllDay => 'Available all day';

  @override
  String get menuScheduleUnavailable => 'Unavailable';

  @override
  String get menuScheduleCustomHours => 'Custom hours';

  @override
  String get menuScheduleStartTime => 'Start time';

  @override
  String get menuScheduleEndTime => 'End time';

  @override
  String menuScheduleEditDay(String day) {
    return 'Edit $day';
  }

  @override
  String get menuScheduleSaveDay => 'Apply';

  @override
  String get menuScheduleSave => 'Save Schedule';

  @override
  String get menuScheduleLoadError => 'Couldn\'t load Menu schedule';

  @override
  String get menuScheduleSaveError =>
      'Couldn\'t save Menu schedule. Try again.';

  @override
  String menuScheduleMultipleWindows(int count) {
    return '$count time windows';
  }

  @override
  String get menuScheduleMultipleWindowsReadOnly =>
      'This day has multiple time windows. They are preserved and can be edited in the advanced schedule later.';

  @override
  String get menuScheduleUnavailableNotSupported =>
      'This day uses an Every Day rule. Keep it unchanged until advanced scheduling is available.';

  @override
  String get menuScheduleInvalidTimes =>
      'Enter two different times in HH:mm format.';

  @override
  String get menuScheduleMonday => 'Monday';

  @override
  String get menuScheduleTuesday => 'Tuesday';

  @override
  String get menuScheduleWednesday => 'Wednesday';

  @override
  String get menuScheduleThursday => 'Thursday';

  @override
  String get menuScheduleFriday => 'Friday';

  @override
  String get menuScheduleSaturday => 'Saturday';

  @override
  String get menuScheduleSunday => 'Sunday';

  @override
  String get menuScheduleMoreOptions => 'More schedule options';

  @override
  String get menuScheduleDateLimits => 'Date limits';

  @override
  String get menuScheduleStartDate => 'Start date (optional)';

  @override
  String get menuScheduleEndDate => 'End date (optional)';

  @override
  String get menuScheduleAddTimeWindow => 'Add time window';

  @override
  String menuScheduleOvernightUntil(String time) {
    return 'Overnight — available until $time the next day';
  }

  @override
  String get menuScheduleEveryDayReadOnly =>
      'This rule applies every day. It is kept as-is so its schedule meaning is preserved.';

  @override
  String get menuScheduleCheckTitle => 'Check Schedule';

  @override
  String get menuScheduleDate => 'Date';

  @override
  String get menuScheduleTime => 'Time';

  @override
  String menuScheduleCheckTimezone(String timezone) {
    return 'Times evaluated in $timezone';
  }

  @override
  String get menuScheduleCheckSaveFirst =>
      'Save schedule changes before checking the saved schedule.';

  @override
  String get menuScheduleCheckFailed =>
      'Could not check the schedule. Try again.';

  @override
  String get menuScheduleInvalidDateRange =>
      'End date must be on or after the start date.';

  @override
  String get menuScheduleDiscardTitle => 'Discard schedule changes?';

  @override
  String get menuScheduleDiscardMessage =>
      'Your schedule changes have not been saved.';

  @override
  String get menuScheduleDiscard => 'Discard changes';

  @override
  String menuScheduleCustomizeDayTitle(String day) {
    return 'Customize $day';
  }

  @override
  String get menuScheduleCustomizeDayMessage =>
      'This schedule currently applies to every day. Customizing one day will keep the same schedule for the other days and let you change that day separately.';

  @override
  String menuScheduleCustomizeDayAction(String day) {
    return 'Customize $day';
  }

  @override
  String get menuScheduleDateLimitsMixed =>
      'These rules have different date limits. Date limits are left unchanged here so this editor does not overwrite them.';

  @override
  String get menuListNotAvailable => '—';

  @override
  String get reviewPublishPageHelp =>
      'Review Menu readiness, preview the selling experience, and publish a version for this selling context.';

  @override
  String get reviewSellingContext => 'Selling Context';

  @override
  String get reviewSellingContextHelp =>
      'This review covers the Menus assigned to the selected selling context.';

  @override
  String get reviewBranch => 'Branch';

  @override
  String get reviewSalesChannel => 'Sales Channel';

  @override
  String get reviewTimezone => 'Timezone';

  @override
  String get reviewScope => 'Scope';

  @override
  String get reviewScopeAssignedMenus => 'Menus assigned to this context';

  @override
  String get reviewReadinessTab => 'Readiness';

  @override
  String get reviewPreviewTab => 'Preview';

  @override
  String get reviewPublishTab => 'Publish';

  @override
  String get reviewVersionsTab => 'Versions';

  @override
  String get reviewCurrentlyPublished => 'Currently Published';

  @override
  String get reviewNotPublishedYet => 'Not published yet';

  @override
  String get reviewNoCurrentVersion =>
      'No Menu version has been published for this selling context.';

  @override
  String get reviewCurrentVersionLoadError =>
      'Could not load the current published version.';

  @override
  String reviewVersionNumber(int version) {
    return 'Version $version';
  }

  @override
  String reviewPublishedAt(String date) {
    return 'Published $date';
  }

  @override
  String get reviewViewVersions => 'View Versions';

  @override
  String get reviewReadiness => 'Readiness';

  @override
  String get reviewReadinessHelp =>
      'Review the authoritative validation for this selling context.';

  @override
  String get reviewCheckAgain => 'Check Again';

  @override
  String get reviewNeedsAttention => 'Needs Attention';

  @override
  String get reviewReadyToPublish => 'Ready to Publish';

  @override
  String get reviewFixBlockingErrors =>
      'Fix the blocking errors before publishing.';

  @override
  String get reviewErrors => 'Errors';

  @override
  String get reviewWarnings => 'Warnings';

  @override
  String reviewWarningsToReview(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings to review.',
      one: '1 warning to review.',
    );
    return '$_temp0';
  }

  @override
  String reviewNoIssuesForScope(String branch, String channel) {
    return 'No issues found for $branch · $channel.';
  }

  @override
  String get reviewNoMenusAssigned => 'No Menus assigned';

  @override
  String reviewNoMenusAssignedHelp(String branch, String channel) {
    return 'Assign at least one active Menu to $branch · $channel before publishing.';
  }

  @override
  String get reviewGoToAssignments => 'Go to Assignments';

  @override
  String get reviewReadinessLoadError => 'Could not load readiness results.';

  @override
  String get reviewTryAgain => 'Try again.';

  @override
  String get reviewIssuesAll => 'All';

  @override
  String get reviewSearchIssues => 'Search issues...';

  @override
  String get reviewNoMatchingIssues => 'No matching issues';

  @override
  String get reviewTryDifferentSearch => 'Try a different search or filter.';

  @override
  String reviewIssueCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count issues',
      one: '1 issue',
    );
    return '$_temp0';
  }

  @override
  String get reviewIssueGroupMenus => 'Menus';

  @override
  String get reviewIssueGroupSections => 'Sections';

  @override
  String get reviewIssueGroupProducts => 'Products';

  @override
  String get reviewIssueGroupVariants => 'Variants';

  @override
  String get reviewIssueGroupRecipesMaterials => 'Recipes & Materials';

  @override
  String get reviewIssueGroupModifiers => 'Modifiers';

  @override
  String get reviewIssueGroupPricing => 'Pricing';

  @override
  String get reviewIssueGroupAvailability => 'Availability';

  @override
  String get reviewIssueGroupAssignmentsScope => 'Assignments / Scope';

  @override
  String get reviewIssueGroupOther => 'Other / General';

  @override
  String get reviewIssueGeneral => 'General';

  @override
  String get reviewOpenMenu => 'Open Menu';

  @override
  String get reviewOpenProduct => 'Open Product';

  @override
  String get reviewOpenSections => 'Open Sections';

  @override
  String get reviewReviewMenu => 'Review Menu';

  @override
  String get reviewIssueContextMenu => 'Menu issue';

  @override
  String get reviewIssueContextSection => 'Section issue';

  @override
  String get reviewIssueContextProduct => 'Product issue';

  @override
  String get reviewIssueContextVariant => 'Variant issue';

  @override
  String get reviewIssueContextPlacement => 'Menu placement issue';

  @override
  String get reviewIssueContextModifier => 'Modifier issue';

  @override
  String get reviewIssueContextRecipe => 'Recipe or material issue';

  @override
  String get reviewIssueContextScope => 'Selling context issue';

  @override
  String get reviewIssueContextGeneral => 'General issue';

  @override
  String get reviewPreviewContext =>
      'Inspect the assigned Menu collection for this selling context.';

  @override
  String get reviewPreviewLanguage => 'Preview language';

  @override
  String get reviewPreviewLanguageDefault => 'Default';

  @override
  String get reviewPreviewLanguageArabic => 'Arabic';

  @override
  String get reviewPreviewLanguageEnglish => 'English';

  @override
  String get reviewPreviewShowHidden => 'Show hidden items';

  @override
  String get reviewPreviewShowUnavailable => 'Show unavailable items';

  @override
  String get reviewPreviewRefresh => 'Refresh Preview';

  @override
  String get reviewPreviewLoading => 'Loading Preview';

  @override
  String get reviewPreviewBlockingBanner =>
      'This preview contains issues that must be fixed before publishing.';

  @override
  String get reviewPreviewReviewReadiness => 'Review Readiness';

  @override
  String get reviewPreviewAvailableNow => 'Available now';

  @override
  String get reviewPreviewOutsideScheduledHours => 'Outside scheduled hours';

  @override
  String get reviewPreviewHidden => 'Hidden';

  @override
  String get reviewPreviewUnavailable => 'Unavailable';

  @override
  String get reviewPreviewSoldOut => 'Sold out';

  @override
  String get reviewPreviewTemporarilyUnavailable => 'Temporarily unavailable';

  @override
  String get reviewPreviewAvailable => 'Available';

  @override
  String get reviewPreviewFeatured => 'Featured';

  @override
  String get reviewPreviewDefault => 'Default';

  @override
  String get reviewPreviewVariants => 'Variants';

  @override
  String get reviewPreviewModifiers => 'Modifiers';

  @override
  String get reviewPreviewRecipeConfigured => 'Recipe configured';

  @override
  String reviewPreviewRecipeComponents(int count) {
    return '$count components';
  }

  @override
  String get reviewPreviewNoMenus => 'No Menus to preview';

  @override
  String get reviewPreviewNoMenusHelp =>
      'Assign at least one active Menu to this selling context.';

  @override
  String get reviewPreviewEmptySection =>
      'No products are included in this section.';

  @override
  String get reviewPreviewError => 'Could not load Preview.';

  @override
  String get reviewPreviewRetry => 'Retry';

  @override
  String get reviewPreviewBasePrice => 'Base price';

  @override
  String get reviewPreviewRequired => 'Required';

  @override
  String get reviewPreviewOptional => 'Optional';

  @override
  String get reviewPreviewOptionUnavailable => 'Unavailable option';

  @override
  String reviewPublishQuestion(String branch, String channel) {
    return 'Publish $branch · $channel?';
  }

  @override
  String get reviewPublishScopeHelp =>
      'This creates a published Menu version for this exact selling context.';

  @override
  String get reviewPublishCurrentVersion => 'Current version';

  @override
  String get reviewPublishCheckingReadiness => 'Checking readiness…';

  @override
  String get reviewPublishWaitForReadiness =>
      'Wait for the current readiness check before publishing.';

  @override
  String get reviewPublishNoAssignedMenu =>
      'Assign at least one active Menu to this selling context before publishing.';

  @override
  String get reviewPublishCannotPublish => 'Cannot publish yet';

  @override
  String get reviewPublishReviewErrors => 'Review Errors';

  @override
  String get reviewPublishReviewIssues => 'Review Issues';

  @override
  String reviewPublishWarningsCanProceed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings remain. You can still publish this version.',
      one: '1 warning remains. You can still publish this version.',
    );
    return '$_temp0';
  }

  @override
  String get reviewPublishCleanReady =>
      'No blocking issues were found. You can publish this version.';

  @override
  String get reviewPublishAction => 'Publish Menu Version';

  @override
  String get reviewPublishPublishing => 'Publishing…';

  @override
  String reviewPublishConfirmTitle(String branch, String channel) {
    return 'Publish $branch · $channel?';
  }

  @override
  String get reviewPublishImmutableExplanation =>
      'A new immutable Menu version will be created if the configuration changed.';

  @override
  String get reviewPublishAlreadyUpToDate => 'Already up to date';

  @override
  String reviewPublishNoChanges(int version) {
    return 'No Menu changes were found since Version $version. No new version was created.';
  }

  @override
  String get reviewPublishSuccess => 'Published successfully';

  @override
  String reviewPublishCurrentForScope(String branch, String channel) {
    return 'This is now the current published Menu version for $branch · $channel.';
  }

  @override
  String get reviewPublishRevalidationFailedTitle =>
      'Menu changed and is no longer ready to publish.';

  @override
  String get reviewPublishRevalidationFailedMessage =>
      'New issues were found during the final check.';

  @override
  String get reviewPublishRequestFailed =>
      'Could not publish the Menu version.';

  @override
  String get reviewPublishTryAgain => 'Try Again';

  @override
  String get menuUiUnsavedChangesTitle => 'Unsaved changes';

  @override
  String get menuUiUnsavedChangesMessage =>
      'You have unsaved changes. If you leave now, they will be discarded.';

  @override
  String get menuUiStay => 'Stay';

  @override
  String get menuUiLeaveWithoutSaving => 'Leave without saving';

  @override
  String get productEditorCreated => 'Product created successfully.';

  @override
  String get productEditorUpdated => 'Product updated successfully.';

  @override
  String get productEditorCreateHelp =>
      'Define what this product is, where it belongs, and how it is sold.';

  @override
  String get productEditorEditHelp =>
      'Update the product information managers use every day.';

  @override
  String get productEditorArchivedReadOnly =>
      'Archived products are available for reference only. Restore this product to edit it.';

  @override
  String get productEditorViewWorkspace => 'View Product Workspace';

  @override
  String get productEditorDefaultName => 'Default Product Name';

  @override
  String get productEditorDefaultDescription => 'Default Description';

  @override
  String get productEditorImage => 'Product Image';

  @override
  String get productEditorUploadingImage => 'Uploading image…';

  @override
  String get productEditorChooseImage => 'Choose Image';

  @override
  String get productEditorChangeImage => 'Change Image';

  @override
  String get productEditorRemoveImage => 'Remove Image';

  @override
  String get productEditorImageFormats => 'PNG, JPG, WEBP, or GIF up to 5 MB';

  @override
  String get productEditorTranslationsClose => 'Close translations';

  @override
  String get productEditorDefaultContent => 'Default content';

  @override
  String get productEditorLocalizedName => 'Localized Name';

  @override
  String get productEditorLocalizedDescription => 'Localized Description';

  @override
  String get productEditorStockTracking => 'Stock Tracking';

  @override
  String get productEditorStockTrackingHelp =>
      'Track the materials consumed when this Product is prepared.';

  @override
  String get productEditorNoDefaultVariant => 'No default variant returned.';

  @override
  String get productEditorManageVariants => 'Manage Variants';

  @override
  String get productDetailNotFound => 'Product not found.';

  @override
  String get productDetailEdit => 'Edit Product';

  @override
  String get productDetailArchiveTitle => 'Archive Product?';

  @override
  String get productDetailRestoreTitle => 'Restore Product?';

  @override
  String get productDetailArchiveAction => 'Archive Product';

  @override
  String get productDetailRestoreAction => 'Restore Product';

  @override
  String get productDetailUsageEmpty =>
      'This Product is not currently used in any menus.';

  @override
  String get variantTitle => 'Variants';

  @override
  String get variantHelp =>
      'Manage the selling options available for this Product.';

  @override
  String get variantAdd => 'Add Variant';

  @override
  String get variantEdit => 'Edit Variant';

  @override
  String get variantReorder => 'Reorder';

  @override
  String get variantDone => 'Done';

  @override
  String get variantRefresh => 'Refresh Variants';

  @override
  String get variantReadOnly =>
      'This product is archived and variants are read-only.';

  @override
  String get variantCannotArchiveDefaultTitle =>
      'Cannot archive Default Variant';

  @override
  String get variantCannotArchiveDefaultMessage =>
      'The only active Variant cannot be archived.';

  @override
  String get variantArchiveMessage =>
      'This Variant will be archived and can be restored later.';

  @override
  String get variantSelectReplacement =>
      'Select an active replacement Default Variant.';

  @override
  String get variantOrder => 'Order';

  @override
  String get variantName => 'Variant name';

  @override
  String get variantBasePrice => 'Base Price';

  @override
  String get variantCostPrice => 'Cost Price';

  @override
  String get variantDefault => 'Default';

  @override
  String get variantActions => 'Actions';

  @override
  String get variantActiveStatus => 'Active status';

  @override
  String get variantMakeDefault => 'Make this the Default Variant';

  @override
  String get variantDefaultMustBeActive => 'A Default Variant must be active.';

  @override
  String get variantSaving => 'Saving…';

  @override
  String get variantNoArchived => 'No archived Variants.';

  @override
  String get variantEmpty => 'No Variants returned for this product.';

  @override
  String get modifierAssignmentTitle => 'Modifiers';

  @override
  String get modifierAssignmentSaveChanges => 'Save Changes';

  @override
  String get modifierAssignmentAddGroup => 'Add Modifier Group';

  @override
  String get modifierAssignmentNoAssigned =>
      'No Modifier Groups are assigned to this Product.';

  @override
  String get modifierAssignmentNoAvailable =>
      'No available Modifier Groups found.';

  @override
  String get modifierAssignmentSearch => 'Search Modifier Groups';

  @override
  String get modifierAssignmentRemoveTitle => 'Remove modifier group?';

  @override
  String get modifierAssignmentRemoveMessage =>
      'Remove this Modifier Group from the Product? The Group and its Options will remain available in the Modifier Library.';

  @override
  String get modifierAssignmentUseLibrarySettings => 'Use library settings';

  @override
  String get modifierAssignmentApply => 'Apply';

  @override
  String get modifierAssignmentCurrentBehavior => 'Current behavior';

  @override
  String get modifierAssignmentNonNegative => 'Use non-negative whole numbers.';

  @override
  String get modifierAssignmentInvalidConstraints =>
      'The effective selection constraints are invalid.';

  @override
  String get productDetailUncategorized => 'Uncategorized product';

  @override
  String get productDetailArchiveMenuAction => 'Archive Product';

  @override
  String get productDetailRestoreMenuAction => 'Restore Product';

  @override
  String get productDetailBasePrice => 'Base Price';

  @override
  String get productDetailKitchenStation => 'Kitchen Station';

  @override
  String get productDetailWorkspaceNavigation => 'Product workspace navigation';

  @override
  String get productDetailSetupHelp =>
      'The catalog and preparation details for this product.';

  @override
  String get productDetailDescription => 'Description';

  @override
  String get productDetailAdvancedTechnical => 'Advanced & Technical';

  @override
  String get productDetailUsageHelp =>
      'Menus where this Product is currently used.';

  @override
  String productDetailUsageCount(int count) {
    return '$count active menu placements.';
  }

  @override
  String get productDetailArchivedVariantsMessage =>
      'This product is archived and variants are read-only.';

  @override
  String get productDetailArchivedModifiersMessage =>
      'This product is archived and modifier assignments are read-only.';

  @override
  String get productDetailViewAction => 'View Product Detail';

  @override
  String get variantActive => 'Active';

  @override
  String get variantInactive => 'Inactive';

  @override
  String get variantArchived => 'Archived';

  @override
  String get variantAll => 'All';

  @override
  String variantSetDefaultTitle(String name) {
    return 'Set “$name” as the Default Variant?';
  }

  @override
  String get variantSetDefaultMessage =>
      'The Product’s displayed base price, SKU, barcode, and legacy POS compatibility will use this Variant. Existing Orders are not changed.';

  @override
  String variantArchiveTitle(String name) {
    return 'Archive “$name”?';
  }

  @override
  String variantRestoreDefaultTitle(String name) {
    return 'Restore “$name” as Default?';
  }

  @override
  String get variantRestoreDefaultMessage =>
      'This Product has no active Default Variant, so this restored Variant must become the Default Variant.';

  @override
  String get variantSetDefaultAction => 'Set Default';

  @override
  String get variantRestoreDefaultAction => 'Restore as Default';

  @override
  String get variantMoveUp => 'Move up';

  @override
  String get variantMoveDown => 'Move down';

  @override
  String variantActionsFor(String name) {
    return 'Actions for $name';
  }

  @override
  String get variantReorderSemantic => 'Reorder';

  @override
  String variantSku(String sku) {
    return 'SKU: $sku';
  }

  @override
  String get variantRecipeConfigured => 'Recipe configured';

  @override
  String get variantRecipeMissing => 'Recipe missing';

  @override
  String get variantRecipeNotConfigured => 'Recipe not configured';

  @override
  String get variantManageRecipe => 'Manage Recipe';

  @override
  String get variantPricing => 'Pricing';

  @override
  String get variantSellingHours => 'Selling Hours';

  @override
  String get variantCurrentAvailability => 'Current Availability';

  @override
  String get variantArabicName => 'Arabic name';

  @override
  String get variantEnglishName => 'English name';

  @override
  String get variantSortOrder => 'Sort Order';

  @override
  String get modifierAssignmentArchivedReadOnly =>
      'This product is archived and modifier assignments are read-only.';

  @override
  String get modifierAssignmentViewProduct => 'View Product Detail';

  @override
  String get modifierAssignmentProduct => 'Product';

  @override
  String modifierAssignmentAssignedGroups(int count) {
    return 'Assigned Groups ($count)';
  }

  @override
  String get modifierAssignmentAvailableGroups => 'Available Groups';

  @override
  String get modifierAssignmentReorder => 'Reorder';

  @override
  String get modifierAssignmentDone => 'Done';

  @override
  String get modifierAssignmentMoveUp => 'Move up';

  @override
  String get modifierAssignmentMoveDown => 'Move down';

  @override
  String modifierAssignmentActionsFor(String name) {
    return 'Actions for $name';
  }

  @override
  String get modifierAssignmentChooseGroupHelp =>
      'Choose a group to make its customer choices available for this Product.';

  @override
  String modifierAssignmentCustomizeFor(String name) {
    return 'Customize for $name';
  }

  @override
  String modifierAssignmentCustomizedFor(String name) {
    return 'Customized for $name';
  }

  @override
  String get modifierAssignmentUsingLibrarySettings => 'Using library settings';

  @override
  String get modifierAssignmentHowChoose => 'How should customers choose?';

  @override
  String get modifierAssignmentChooseOne => 'Choose one';

  @override
  String get modifierAssignmentChooseMultiple => 'Choose multiple';

  @override
  String get modifierAssignmentMultipleHelp =>
      'This group uses multiple choices from the Modifier Library.';

  @override
  String get modifierAssignmentSingleHelp =>
      'This group uses one choice from the Modifier Library.';

  @override
  String get modifierAssignmentMinimumChoices => 'Minimum choices';

  @override
  String get modifierAssignmentMaximumChoices => 'Maximum choices';

  @override
  String get modifierAssignmentAllowDuplicate =>
      'Can the same option be added more than once?';

  @override
  String modifierAssignmentConfigure(String name) {
    return 'Configure $name';
  }

  @override
  String modifierAssignmentOverride(String label) {
    return '$label override';
  }

  @override
  String modifierAssignmentLibraryDefaultBoolean(String value) {
    return 'Library Default: $value';
  }

  @override
  String modifierAssignmentLibraryDefaultNumber(int value) {
    return 'Library Default: $value';
  }

  @override
  String modifierAssignmentEffectiveSetting(String value) {
    return 'Effective Setting: $value';
  }

  @override
  String get modifierAssignmentHelp =>
      'Choose which Modifier Groups customers can use with this Product.';

  @override
  String get modifierAssignmentMaterialImpact => 'Material impact configured';

  @override
  String get modifierAssignmentViewGroup => 'View Modifier Group';

  @override
  String get modifierAssignmentCustomizeForProduct => 'Customize for Product';

  @override
  String get modifierAssignmentRemoveFromProduct => 'Remove from Product';

  @override
  String get menuDetailArchiveTitle => 'Archive menu?';

  @override
  String get menuDetailRestoreTitle => 'Restore menu?';

  @override
  String get menuDetailArchiveMessage =>
      'This archives the menu without deleting it. Its composition remains available to review.';

  @override
  String get menuDetailRestoreMessage =>
      'Restoring this menu returns it to Draft. It does not restore archived sections.';

  @override
  String get productEditorProductType => 'Product Type';

  @override
  String get productEditorStandard => 'Standard';

  @override
  String get productEditorOpenPrice => 'Open price';

  @override
  String get productEditorPreparationTime => 'Preparation Time';

  @override
  String get productEditorMinutes => 'minutes';

  @override
  String get productEditorInitialOptionHelp =>
      'Every product starts with one selling option. You can add more variants later.';

  @override
  String get productEditorVariantName => 'Variant Name';

  @override
  String get productEditorDefaultVariant => 'Default Variant';

  @override
  String get productEditorDefaultVariantHelp =>
      'Selling options are managed separately so product details stay focused.';

  @override
  String get productEditorTranslationsHelp =>
      'Add localized content without crowding the main product form.';

  @override
  String get productEditorTranslationsPanelHelp =>
      'Use the translation panel to provide Arabic and English names and descriptions.';

  @override
  String get productEditorSortOrder => 'Sort Order';

  @override
  String get productEditorVariantCost => 'Variant Cost';

  @override
  String get productEditorNone => 'None';

  @override
  String get productEditorPreviewUnavailable => 'Preview unavailable';

  @override
  String get productEditorDropImage => 'Drop an image here or click to browse';

  @override
  String get productEditorImageLoadFailed => 'Image could not be loaded';

  @override
  String get productEditorWhatIsProduct => 'What is this product?';

  @override
  String get productEditorClassificationHelp =>
      'Choose where this product belongs in the catalog and preparation flow.';

  @override
  String get productEditorKitchenStationHelp =>
      'Where this product is generally prepared.';

  @override
  String get productEditorReportingCategoryHelp =>
      'Used for sales and performance reports.';

  @override
  String get productEditorSellingPreparationHelp =>
      'Set how this product is sold and what preparation information the team needs.';

  @override
  String get productEditorArabicConfigured => 'Arabic configured';

  @override
  String get productEditorEnglishConfigured => 'English configured';

  @override
  String productEditorBasePriceValue(String price) {
    return 'Base price $price';
  }

  @override
  String get productDetailArchiveMessage =>
      'This Product will no longer be available for new Menu configuration or normal Catalog use. Existing Orders and published historical Versions will not be changed.';

  @override
  String get productDetailRestoreMessage =>
      'This restores the Product to the editable Catalog. Availability still depends on Menu assignments, schedules, operational status, validation, and publishing.';

  @override
  String get productCatalogArchiveMessage =>
      'This Product will no longer be available for new Menu configuration or normal Catalog use. Existing Orders and published historical Versions will not be changed.\n\nThe Product is not permanently deleted. Central Modifier Groups are not deleted, and Variants remain stored according to Backend behavior.';

  @override
  String get productCatalogRestoreMessage =>
      'This restores the Product to the editable Catalog. Its availability in Menus still depends on Menu assignments, schedules, operational status, validation, and publishing.';

  @override
  String productCatalogUsageMessage(int count, String names) {
    return 'This Product is currently used in $count Menu placements$names.';
  }

  @override
  String get operationalOverrideClearTitle => 'Clear operational override?';

  @override
  String operationalOverrideClearMessage(String level, String scope) {
    return 'Clear the $level override for $scope?\n\nScheduled Availability, Product configuration, and historical Published Versions will not be changed.';
  }

  @override
  String get operationalOverrideClearAction => 'Clear override';

  @override
  String get productDetailProductId => 'Product ID';

  @override
  String get productDetailUpdated => 'Updated';

  @override
  String get productDetailImageUrl => 'Image URL';

  @override
  String get authLoginTitle => 'Log in to your workspace';

  @override
  String get authLoginSubtitle => 'Operational Hub Login';

  @override
  String get authEmailOrUsername => 'Email or Username';

  @override
  String get authIdentifierRequired => 'Enter your email or username.';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordRequired => 'Enter your password.';

  @override
  String get authLogIn => 'Log In';

  @override
  String get authLoggingIn => 'Logging in…';

  @override
  String get authLoginHelp =>
      'Use your work email or employee username to continue.';

  @override
  String get authLoginFailed =>
      'We could not log you in. Check your details and try again.';

  @override
  String get authChangePassword => 'Change Password';

  @override
  String get authChangePasswordExplanation =>
      'Your first login or an administrator reset requires you to set a new password.';

  @override
  String get authCurrentPassword => 'Current Password';

  @override
  String get authNewPassword => 'New Password';

  @override
  String get authConfirmNewPassword => 'Confirm New Password';

  @override
  String authMinimumPassword(int count) {
    return 'Use at least $count characters.';
  }

  @override
  String get authManagerPasswordRule =>
      'Owners and managers need at least 10 characters.';

  @override
  String get authEmployeePasswordRule =>
      'Employees need at least 8 characters.';

  @override
  String get authPasswordsDoNotMatch => 'The passwords do not match.';

  @override
  String get authSavePassword => 'Save Password';

  @override
  String get authSavingPassword => 'Saving password…';

  @override
  String get authPasswordChangeFailed =>
      'We could not change your password. Please check the current password and try again.';

  @override
  String get authRestoringSession => 'Restoring your secure session…';

  @override
  String get authSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String get authOfflineSessionExpired =>
      'Your offline session has expired. Connect to the internet and log in again.';

  @override
  String get authSettingsSubtitle => 'Account and session controls';

  @override
  String get authAccount => 'Account';

  @override
  String get authSignedInTenant => 'Signed in to';

  @override
  String get authLogout => 'Log Out';

  @override
  String get authLogoutConfirmation =>
      'Are you sure you want to log out from this device?';
}
