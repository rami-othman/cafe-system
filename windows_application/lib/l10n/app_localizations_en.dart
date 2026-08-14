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
}
