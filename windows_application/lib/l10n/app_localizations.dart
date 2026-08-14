import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// The application name.
  ///
  /// In en, this message translates to:
  /// **'Cafe System 618'**
  String get appName;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageSelection.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get languageSelection;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonError;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available.'**
  String get commonNoData;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// No description provided for @commonAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get commonAvailable;

  /// No description provided for @commonSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get commonSoldOut;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @navigationDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navigationDashboard;

  /// No description provided for @navigationPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get navigationPos;

  /// No description provided for @navigationOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navigationOrders;

  /// No description provided for @navigationCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navigationCustomers;

  /// No description provided for @navigationDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get navigationDiscounts;

  /// No description provided for @navigationMenuManagement.
  ///
  /// In en, this message translates to:
  /// **'Menu Management'**
  String get navigationMenuManagement;

  /// No description provided for @navigationInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navigationInventory;

  /// No description provided for @navigationReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navigationReports;

  /// No description provided for @navigationSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navigationSettings;

  /// No description provided for @operationalHub.
  ///
  /// In en, this message translates to:
  /// **'OPERATIONAL HUB'**
  String get operationalHub;

  /// No description provided for @tooltipCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get tooltipCart;

  /// No description provided for @tooltipRefreshScreenData.
  ///
  /// In en, this message translates to:
  /// **'Refresh screen data'**
  String get tooltipRefreshScreenData;

  /// No description provided for @tooltipNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tooltipNotifications;

  /// No description provided for @tooltipProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tooltipProfile;

  /// No description provided for @invalidCatalogRoute.
  ///
  /// In en, this message translates to:
  /// **'The requested catalog route is invalid.'**
  String get invalidCatalogRoute;

  /// No description provided for @productsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No products found.'**
  String get productsEmptyMessage;

  /// No description provided for @ordersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No orders found.'**
  String get ordersEmptyMessage;

  /// No description provided for @menusEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No menus found.'**
  String get menusEmptyMessage;

  /// A count of products.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No products} =1{1 product} other{{count} products}}'**
  String productCount(num count);

  /// A count of orders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No orders} =1{1 order} other{{count} orders}}'**
  String orderCount(num count);

  /// A count of variants.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No variants} =1{1 variant} other{{count} variants}}'**
  String variantCount(num count);

  /// A count of validation issues.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No validation issues} =1{1 validation issue} other{{count} validation issues}}'**
  String validationIssueCount(num count);

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get statusUnpaid;

  /// No description provided for @statusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get statusArchived;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get statusPublished;

  /// No description provided for @statusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get statusScheduled;

  /// No description provided for @statusTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Temporarily unavailable'**
  String get statusTemporarilyUnavailable;

  /// No description provided for @statusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get statusAssigned;

  /// No description provided for @statusUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get statusUnassigned;

  /// No description provided for @priceSourceBase.
  ///
  /// In en, this message translates to:
  /// **'Base price'**
  String get priceSourceBase;

  /// No description provided for @priceSourceOverride.
  ///
  /// In en, this message translates to:
  /// **'Override price'**
  String get priceSourceOverride;

  /// No description provided for @validationSeverityError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get validationSeverityError;

  /// No description provided for @validationSeverityWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get validationSeverityWarning;

  /// No description provided for @validationSeverityInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get validationSeverityInfo;

  /// No description provided for @salesChannelPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get salesChannelPos;

  /// No description provided for @salesChannelOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get salesChannelOnline;

  /// No description provided for @productTypeSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple product'**
  String get productTypeSimple;

  /// No description provided for @productTypeVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant product'**
  String get productTypeVariant;

  /// No description provided for @genericFormError.
  ///
  /// In en, this message translates to:
  /// **'We could not save your changes. Review the highlighted fields and try again.'**
  String get genericFormError;

  /// No description provided for @menuPublishTab.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get menuPublishTab;

  /// No description provided for @menuPublishAction.
  ///
  /// In en, this message translates to:
  /// **'Publish Menu'**
  String get menuPublishAction;

  /// No description provided for @menuPublishPublishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing…'**
  String get menuPublishPublishing;

  /// No description provided for @menuPublishBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get menuPublishBranch;

  /// No description provided for @menuPublishChannel.
  ///
  /// In en, this message translates to:
  /// **'Sales channel'**
  String get menuPublishChannel;

  /// No description provided for @menuPublishScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get menuPublishScope;

  /// No description provided for @menuPublishCollectionScope.
  ///
  /// In en, this message translates to:
  /// **'Complete assigned Menu collection'**
  String get menuPublishCollectionScope;

  /// No description provided for @menuPublishOneMenu.
  ///
  /// In en, this message translates to:
  /// **'One Menu'**
  String get menuPublishOneMenu;

  /// No description provided for @menuPublishValidation.
  ///
  /// In en, this message translates to:
  /// **'Last validation'**
  String get menuPublishValidation;

  /// No description provided for @menuPublishValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Validation required'**
  String get menuPublishValidationRequired;

  /// No description provided for @menuPublishCanPublish.
  ///
  /// In en, this message translates to:
  /// **'Can Publish'**
  String get menuPublishCanPublish;

  /// No description provided for @menuPublishCannotPublish.
  ///
  /// In en, this message translates to:
  /// **'Cannot Publish'**
  String get menuPublishCannotPublish;

  /// No description provided for @menuPublishErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get menuPublishErrors;

  /// No description provided for @menuPublishWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get menuPublishWarnings;

  /// No description provided for @menuPublishRunValidationFirst.
  ///
  /// In en, this message translates to:
  /// **'Run Validation for this selected scope before publishing.'**
  String get menuPublishRunValidationFirst;

  /// No description provided for @menuPublishBlockedByValidation.
  ///
  /// In en, this message translates to:
  /// **'Publishing is disabled because the loaded validation contains errors.'**
  String get menuPublishBlockedByValidation;

  /// No description provided for @menuPublishWarningsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Warnings do not block publishing. Review them and confirm explicitly.'**
  String get menuPublishWarningsAllowed;

  /// No description provided for @menuPublishConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Menu publication'**
  String get menuPublishConfirmTitle;

  /// No description provided for @menuPublishCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current Published Version'**
  String get menuPublishCurrentVersion;

  /// No description provided for @menuPublishConfirmationExplanation.
  ///
  /// In en, this message translates to:
  /// **'Publishing creates a new immutable Menu Version for the selected Branch and Channel when the resolved Menu content has changed. Existing Orders are not modified.'**
  String get menuPublishConfirmationExplanation;

  /// No description provided for @menuPublishLoadingCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Loading current published Version…'**
  String get menuPublishLoadingCurrentVersion;

  /// No description provided for @menuPublishNoCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'No Menu Version has been published for this Branch and Sales Channel.'**
  String get menuPublishNoCurrentVersion;

  /// No description provided for @menuPublishVersionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get menuPublishVersionNumber;

  /// No description provided for @menuPublishStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get menuPublishStatus;

  /// No description provided for @menuPublishPublishedAt.
  ///
  /// In en, this message translates to:
  /// **'Published at'**
  String get menuPublishPublishedAt;

  /// No description provided for @menuPublishChecksum.
  ///
  /// In en, this message translates to:
  /// **'Checksum'**
  String get menuPublishChecksum;

  /// No description provided for @menuPublishPublicationId.
  ///
  /// In en, this message translates to:
  /// **'Publication ID'**
  String get menuPublishPublicationId;

  /// No description provided for @menuPublishSuccess.
  ///
  /// In en, this message translates to:
  /// **'Menu publication successful.'**
  String get menuPublishSuccess;

  /// No description provided for @menuPublishNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No Menu changes were detected.'**
  String get menuPublishNoChanges;

  /// No description provided for @menuPublishNoChangesExplanation.
  ///
  /// In en, this message translates to:
  /// **'The current published Version remains unchanged.'**
  String get menuPublishNoChangesExplanation;

  /// No description provided for @menuPublishBackendBlocked.
  ///
  /// In en, this message translates to:
  /// **'Backend validation blocked publication. No Version was created.'**
  String get menuPublishBackendBlocked;

  /// No description provided for @versionHistory.
  ///
  /// In en, this message translates to:
  /// **'Version History'**
  String get versionHistory;

  /// No description provided for @versionDetail.
  ///
  /// In en, this message translates to:
  /// **'Version Detail'**
  String get versionDetail;

  /// No description provided for @compareVersions.
  ///
  /// In en, this message translates to:
  /// **'Compare Versions'**
  String get compareVersions;

  /// No description provided for @identicalContent.
  ///
  /// In en, this message translates to:
  /// **'Identical content'**
  String get identicalContent;

  /// No description provided for @versionsAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get versionsAdded;

  /// No description provided for @versionsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get versionsRemoved;

  /// No description provided for @versionsChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get versionsChanged;

  /// No description provided for @versionPriceChanges.
  ///
  /// In en, this message translates to:
  /// **'Price changes'**
  String get versionPriceChanges;

  /// No description provided for @versionModifierChanges.
  ///
  /// In en, this message translates to:
  /// **'Modifier changes'**
  String get versionModifierChanges;

  /// No description provided for @versionScheduleChanges.
  ///
  /// In en, this message translates to:
  /// **'Schedule changes'**
  String get versionScheduleChanges;

  /// No description provided for @versionRollback.
  ///
  /// In en, this message translates to:
  /// **'Rollback'**
  String get versionRollback;

  /// No description provided for @versionRollbackReason.
  ///
  /// In en, this message translates to:
  /// **'Rollback reason'**
  String get versionRollbackReason;

  /// No description provided for @versionNewRollback.
  ///
  /// In en, this message translates to:
  /// **'New rollback Version'**
  String get versionNewRollback;

  /// No description provided for @versionNoChangeRollback.
  ///
  /// In en, this message translates to:
  /// **'No-change rollback'**
  String get versionNoChangeRollback;

  /// No description provided for @versionTruncatedComparison.
  ///
  /// In en, this message translates to:
  /// **'Only a bounded subset of differences is displayed.'**
  String get versionTruncatedComparison;

  /// No description provided for @versionImmutableSnapshot.
  ///
  /// In en, this message translates to:
  /// **'This is an immutable historical Snapshot.'**
  String get versionImmutableSnapshot;

  /// No description provided for @versionStatusCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get versionStatusCurrent;

  /// No description provided for @versionStatusSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Superseded'**
  String get versionStatusSuperseded;

  /// No description provided for @versionStatusRolledBack.
  ///
  /// In en, this message translates to:
  /// **'Rolled back'**
  String get versionStatusRolledBack;

  /// No description provided for @catalogSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog Setup'**
  String get catalogSetupTitle;

  /// No description provided for @catalogSetupCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog Categories'**
  String get catalogSetupCategoriesTitle;

  /// No description provided for @catalogSetupReportingCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Reporting Categories'**
  String get catalogSetupReportingCategoriesTitle;

  /// No description provided for @catalogSetupKitchenStationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Stations'**
  String get catalogSetupKitchenStationsTitle;

  /// No description provided for @catalogSetupCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get catalogSetupCategory;

  /// No description provided for @catalogSetupReportingCategory.
  ///
  /// In en, this message translates to:
  /// **'Reporting Category'**
  String get catalogSetupReportingCategory;

  /// No description provided for @catalogSetupKitchenStation.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Station'**
  String get catalogSetupKitchenStation;

  /// No description provided for @catalogSetupCategoriesExplanation.
  ///
  /// In en, this message translates to:
  /// **'Categories classify Products for the Catalog.'**
  String get catalogSetupCategoriesExplanation;

  /// No description provided for @catalogSetupReportingCategoriesExplanation.
  ///
  /// In en, this message translates to:
  /// **'Reporting Categories group Products for sales and performance reports. They do not control where Products appear in the customer Menu.'**
  String get catalogSetupReportingCategoriesExplanation;

  /// No description provided for @catalogSetupKitchenStationsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Stations identify the preparation area for Products; this does not configure printer communication.'**
  String get catalogSetupKitchenStationsExplanation;

  /// No description provided for @catalogSetupAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get catalogSetupAll;

  /// No description provided for @catalogSetupProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get catalogSetupProducts;

  /// No description provided for @catalogSetupOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get catalogSetupOrder;

  /// No description provided for @catalogSetupActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get catalogSetupActions;

  /// No description provided for @catalogSetupCodePrinter.
  ///
  /// In en, this message translates to:
  /// **'Code / Printer'**
  String get catalogSetupCodePrinter;

  /// No description provided for @catalogSetupNoMatchingRecords.
  ///
  /// In en, this message translates to:
  /// **'No matching records.'**
  String get catalogSetupNoMatchingRecords;

  /// No description provided for @catalogSetupUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load Catalog Setup.'**
  String get catalogSetupUnableToLoad;

  /// No description provided for @catalogSetupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create {type}'**
  String catalogSetupCreate(String type);

  /// No description provided for @catalogSetupEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit {type}'**
  String catalogSetupEdit(String type);

  /// No description provided for @catalogSetupArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive {type}'**
  String catalogSetupArchive(String type);

  /// No description provided for @catalogSetupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get catalogSetupRestore;

  /// No description provided for @catalogSetupMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get catalogSetupMoveUp;

  /// No description provided for @catalogSetupMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get catalogSetupMoveDown;

  /// No description provided for @catalogSetupName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get catalogSetupName;

  /// No description provided for @catalogSetupNameArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic name'**
  String get catalogSetupNameArabic;

  /// No description provided for @catalogSetupNameEnglish.
  ///
  /// In en, this message translates to:
  /// **'English name'**
  String get catalogSetupNameEnglish;

  /// No description provided for @catalogSetupCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get catalogSetupCode;

  /// No description provided for @catalogSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get catalogSetupDescription;

  /// No description provided for @catalogSetupPrinterName.
  ///
  /// In en, this message translates to:
  /// **'Printer name'**
  String get catalogSetupPrinterName;

  /// No description provided for @catalogSetupPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String catalogSetupPage(int page);

  /// No description provided for @catalogSetupPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get catalogSetupPrevious;

  /// No description provided for @catalogSetupNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get catalogSetupNext;

  /// No description provided for @catalogSetupArchiveConfirmation.
  ///
  /// In en, this message translates to:
  /// **'{name} is used by {count} Products. Existing Product assignments remain governed by Backend rules.'**
  String catalogSetupArchiveConfirmation(String name, int count);

  /// No description provided for @recipeMaterials.
  ///
  /// In en, this message translates to:
  /// **'Recipe / Materials'**
  String get recipeMaterials;

  /// No description provided for @manageRecipe.
  ///
  /// In en, this message translates to:
  /// **'Manage Recipe'**
  String get manageRecipe;

  /// No description provided for @baseRecipe.
  ///
  /// In en, this message translates to:
  /// **'Base Recipe'**
  String get baseRecipe;

  /// No description provided for @material.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get material;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @addMaterial.
  ///
  /// In en, this message translates to:
  /// **'Add Material'**
  String get addMaterial;

  /// No description provided for @removeMaterial.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeMaterial;

  /// No description provided for @materialAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Material Adjustments'**
  String get materialAdjustments;

  /// No description provided for @effectiveFrom.
  ///
  /// In en, this message translates to:
  /// **'Effective from'**
  String get effectiveFrom;

  /// No description provided for @global.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get global;

  /// No description provided for @productOverride.
  ///
  /// In en, this message translates to:
  /// **'Product Override'**
  String get productOverride;

  /// No description provided for @variantOverride.
  ///
  /// In en, this message translates to:
  /// **'Variant Override'**
  String get variantOverride;

  /// No description provided for @inherited.
  ///
  /// In en, this message translates to:
  /// **'Inherited'**
  String get inherited;

  /// No description provided for @createOverride.
  ///
  /// In en, this message translates to:
  /// **'Create Override'**
  String get createOverride;

  /// No description provided for @suppressInheritedEffects.
  ///
  /// In en, this message translates to:
  /// **'Suppress Inherited Effects'**
  String get suppressInheritedEffects;

  /// No description provided for @restoreInheritance.
  ///
  /// In en, this message translates to:
  /// **'Restore Inheritance'**
  String get restoreInheritance;

  /// No description provided for @recipeSimulation.
  ///
  /// In en, this message translates to:
  /// **'Recipe Simulation'**
  String get recipeSimulation;

  /// No description provided for @selectedModifiers.
  ///
  /// In en, this message translates to:
  /// **'Selected Modifiers'**
  String get selectedModifiers;

  /// No description provided for @resolvedRecipe.
  ///
  /// In en, this message translates to:
  /// **'Resolved Recipe'**
  String get resolvedRecipe;

  /// No description provided for @recipeUnavailableMaterial.
  ///
  /// In en, this message translates to:
  /// **'Materials with an unmapped unit are disabled and cannot be saved.'**
  String get recipeUnavailableMaterial;

  /// No description provided for @recipeReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This Variant is archived. Recipe configuration is read-only.'**
  String get recipeReadOnly;

  /// No description provided for @recipeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recipe components are configured.'**
  String get recipeEmpty;

  /// No description provided for @recipeInheritedDraft.
  ///
  /// In en, this message translates to:
  /// **'This draft is cloned from the inherited profile. Saving creates a full replacement override.'**
  String get recipeInheritedDraft;

  /// No description provided for @recipeEmptyOverride.
  ///
  /// In en, this message translates to:
  /// **'This override deliberately has no material effects.'**
  String get recipeEmptyOverride;

  /// No description provided for @recipeSuppressConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Suppress inherited material effects?'**
  String get recipeSuppressConfirmationTitle;

  /// No description provided for @recipeSuppressConfirmationBody.
  ///
  /// In en, this message translates to:
  /// **'Saving an empty scoped profile removes every inherited ADD and REMOVE effect for this scope.'**
  String get recipeSuppressConfirmationBody;

  /// No description provided for @recipeRemoveOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this override?'**
  String get recipeRemoveOverrideTitle;

  /// No description provided for @recipeRemoveOverrideBody.
  ///
  /// In en, this message translates to:
  /// **'Removing it restores the nearest inherited material effects.'**
  String get recipeRemoveOverrideBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
