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

  /// No description provided for @commonDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get commonDeactivate;

  /// No description provided for @commonActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get commonActivate;

  /// No description provided for @commonArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get commonArchive;

  /// No description provided for @commonRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get commonRestore;

  /// No description provided for @commonArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get commonArchived;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

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

  /// No description provided for @menuManagementWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Menu management workflow'**
  String get menuManagementWorkflow;

  /// No description provided for @menuManagementBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get menuManagementBuild;

  /// No description provided for @menuManagementConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get menuManagementConfigure;

  /// No description provided for @menuManagementRelease.
  ///
  /// In en, this message translates to:
  /// **'Review & release'**
  String get menuManagementRelease;

  /// No description provided for @menuManagementProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get menuManagementProducts;

  /// No description provided for @menuManagementModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get menuManagementModifiers;

  /// No description provided for @menuManagementMenus.
  ///
  /// In en, this message translates to:
  /// **'Menus'**
  String get menuManagementMenus;

  /// No description provided for @menuManagementAssignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments & schedules'**
  String get menuManagementAssignments;

  /// No description provided for @menuManagementReview.
  ///
  /// In en, this message translates to:
  /// **'Review & preview'**
  String get menuManagementReview;

  /// No description provided for @menuManagementCatalogSetup.
  ///
  /// In en, this message translates to:
  /// **'Catalog setup'**
  String get menuManagementCatalogSetup;

  /// No description provided for @recipeConsumptionHelp.
  ///
  /// In en, this message translates to:
  /// **'Define the materials consumed when one unit of this Variant is prepared.'**
  String get recipeConsumptionHelp;

  /// No description provided for @recipeNoComponentsHelp.
  ///
  /// In en, this message translates to:
  /// **'No materials are configured yet. Add each material used to prepare one unit of this Variant.'**
  String get recipeNoComponentsHelp;

  /// No description provided for @recipeOverrideGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global default'**
  String get recipeOverrideGlobal;

  /// No description provided for @recipeOverrideProduct.
  ///
  /// In en, this message translates to:
  /// **'Override for this Product'**
  String get recipeOverrideProduct;

  /// No description provided for @recipeOverrideVariant.
  ///
  /// In en, this message translates to:
  /// **'Override for this Variant'**
  String get recipeOverrideVariant;

  /// No description provided for @recipeInheritedFromGlobal.
  ///
  /// In en, this message translates to:
  /// **'Inherited from Global'**
  String get recipeInheritedFromGlobal;

  /// No description provided for @recipeInheritedFromProduct.
  ///
  /// In en, this message translates to:
  /// **'Inherited from this Product'**
  String get recipeInheritedFromProduct;

  /// No description provided for @recipeSimulationHelp.
  ///
  /// In en, this message translates to:
  /// **'Select modifiers, resolve the recipe, then review the materials consumed.'**
  String get recipeSimulationHelp;

  /// No description provided for @recipeSimulationResultHelp.
  ///
  /// In en, this message translates to:
  /// **'Consumed materials'**
  String get recipeSimulationResultHelp;

  /// No description provided for @recipeSimulationStartHelp.
  ///
  /// In en, this message translates to:
  /// **'Select modifiers, then resolve the recipe to see the consumed materials.'**
  String get recipeSimulationStartHelp;

  /// No description provided for @reviewWorkflowHelp.
  ///
  /// In en, this message translates to:
  /// **'Check the selected Menu, preview what the Branch and Channel receive, then publish and review its Version history.'**
  String get reviewWorkflowHelp;

  /// No description provided for @reviewCheckMenu.
  ///
  /// In en, this message translates to:
  /// **'1. Check Menu'**
  String get reviewCheckMenu;

  /// No description provided for @reviewPreviewStep.
  ///
  /// In en, this message translates to:
  /// **'2. Preview'**
  String get reviewPreviewStep;

  /// No description provided for @reviewPublishStep.
  ///
  /// In en, this message translates to:
  /// **'3. Publish'**
  String get reviewPublishStep;

  /// No description provided for @reviewVersionsStep.
  ///
  /// In en, this message translates to:
  /// **'4. Version History'**
  String get reviewVersionsStep;

  /// No description provided for @validationNoBlockingErrors.
  ///
  /// In en, this message translates to:
  /// **'No blocking validation errors were found.'**
  String get validationNoBlockingErrors;

  /// No description provided for @validationResolveErrors.
  ///
  /// In en, this message translates to:
  /// **'Resolve the errors below before this Menu can be published.'**
  String get validationResolveErrors;

  /// No description provided for @validationIssueCode.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String validationIssueCode(String code);

  /// No description provided for @modifierSelectionExactly.
  ///
  /// In en, this message translates to:
  /// **'Customer must choose exactly {count, plural, =1 {1 option} other {{count} options}}.'**
  String modifierSelectionExactly(num count);

  /// No description provided for @modifierSelectionRange.
  ///
  /// In en, this message translates to:
  /// **'Customer may choose from {min} to {max} options.'**
  String modifierSelectionRange(num min, num max);

  /// No description provided for @reviewAdvancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced preview options'**
  String get reviewAdvancedOptions;

  /// No description provided for @technicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get technicalDetails;

  /// No description provided for @managerAvailabilityScheduledHelp.
  ///
  /// In en, this message translates to:
  /// **'When should this item normally be available?'**
  String get managerAvailabilityScheduledHelp;

  /// No description provided for @managerAvailabilityOperationalHelp.
  ///
  /// In en, this message translates to:
  /// **'Is it temporarily unavailable right now?'**
  String get managerAvailabilityOperationalHelp;

  /// No description provided for @menuManagementNavigation.
  ///
  /// In en, this message translates to:
  /// **'Menu Management navigation'**
  String get menuManagementNavigation;

  /// No description provided for @menuManagementCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get menuManagementCatalog;

  /// No description provided for @menuManagementMenusGroup.
  ///
  /// In en, this message translates to:
  /// **'Menus'**
  String get menuManagementMenusGroup;

  /// No description provided for @menuManagementReleaseGroup.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get menuManagementReleaseGroup;

  /// No description provided for @menuManagementReviewPublish.
  ///
  /// In en, this message translates to:
  /// **'Review & Publish'**
  String get menuManagementReviewPublish;

  /// No description provided for @menuBreadcrumbProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get menuBreadcrumbProduct;

  /// No description provided for @menuBreadcrumbVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get menuBreadcrumbVariant;

  /// No description provided for @menuBreadcrumbCreateProduct.
  ///
  /// In en, this message translates to:
  /// **'Create product'**
  String get menuBreadcrumbCreateProduct;

  /// No description provided for @menuBreadcrumbEditProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get menuBreadcrumbEditProduct;

  /// No description provided for @menuBreadcrumbVariants.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get menuBreadcrumbVariants;

  /// No description provided for @menuBreadcrumbModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get menuBreadcrumbModifiers;

  /// No description provided for @menuBreadcrumbPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get menuBreadcrumbPricing;

  /// No description provided for @menuBreadcrumbRecipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get menuBreadcrumbRecipe;

  /// No description provided for @menuBreadcrumbRecipeSimulation.
  ///
  /// In en, this message translates to:
  /// **'Recipe simulation'**
  String get menuBreadcrumbRecipeSimulation;

  /// No description provided for @menuBreadcrumbAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get menuBreadcrumbAvailability;

  /// No description provided for @menuBreadcrumbOperationalAvailability.
  ///
  /// In en, this message translates to:
  /// **'Operational availability'**
  String get menuBreadcrumbOperationalAvailability;

  /// No description provided for @menuBreadcrumbMaterialAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Material adjustments'**
  String get menuBreadcrumbMaterialAdjustments;

  /// No description provided for @menuBreadcrumbModifierGroup.
  ///
  /// In en, this message translates to:
  /// **'Modifier group'**
  String get menuBreadcrumbModifierGroup;

  /// No description provided for @menuBreadcrumbCreateModifierGroup.
  ///
  /// In en, this message translates to:
  /// **'Create modifier group'**
  String get menuBreadcrumbCreateModifierGroup;

  /// No description provided for @menuBreadcrumbEditModifierGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit modifier group'**
  String get menuBreadcrumbEditModifierGroup;

  /// No description provided for @menuBreadcrumbMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuBreadcrumbMenu;

  /// No description provided for @menuBreadcrumbCreateMenu.
  ///
  /// In en, this message translates to:
  /// **'Create menu'**
  String get menuBreadcrumbCreateMenu;

  /// No description provided for @menuBreadcrumbEditMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit menu'**
  String get menuBreadcrumbEditMenu;

  /// No description provided for @menuBreadcrumbComposition.
  ///
  /// In en, this message translates to:
  /// **'Composition'**
  String get menuBreadcrumbComposition;

  /// No description provided for @menuBreadcrumbVersionHistory.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get menuBreadcrumbVersionHistory;

  /// No description provided for @productCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productCatalogTitle;

  /// No description provided for @productCatalogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage the products available across your menus.'**
  String get productCatalogSubtitle;

  /// No description provided for @productCatalogCreateProduct.
  ///
  /// In en, this message translates to:
  /// **'Create Product'**
  String get productCatalogCreateProduct;

  /// No description provided for @productCatalogRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh products'**
  String get productCatalogRefresh;

  /// No description provided for @productCatalogSearch.
  ///
  /// In en, this message translates to:
  /// **'Search products, SKU, or barcode'**
  String get productCatalogSearch;

  /// No description provided for @productCatalogLifecycle.
  ///
  /// In en, this message translates to:
  /// **'Lifecycle'**
  String get productCatalogLifecycle;

  /// No description provided for @productCatalogAllProducts.
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get productCatalogAllProducts;

  /// No description provided for @productCatalogMoreFilters.
  ///
  /// In en, this message translates to:
  /// **'More Filters'**
  String get productCatalogMoreFilters;

  /// No description provided for @productCatalogMoreFiltersSemantic.
  ///
  /// In en, this message translates to:
  /// **'More Filters, {count} active'**
  String productCatalogMoreFiltersSemantic(int count);

  /// No description provided for @productCatalogClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get productCatalogClearAll;

  /// No description provided for @productCatalogClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get productCatalogClear;

  /// No description provided for @productCatalogApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get productCatalogApply;

  /// No description provided for @productCatalogSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get productCatalogSort;

  /// No description provided for @productCatalogSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get productCatalogSortOrder;

  /// No description provided for @productCatalogNameAscending.
  ///
  /// In en, this message translates to:
  /// **'Name A–Z'**
  String get productCatalogNameAscending;

  /// No description provided for @productCatalogNameDescending.
  ///
  /// In en, this message translates to:
  /// **'Name Z–A'**
  String get productCatalogNameDescending;

  /// No description provided for @productCatalogNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get productCatalogNewest;

  /// No description provided for @productCatalogProductType.
  ///
  /// In en, this message translates to:
  /// **'Product type'**
  String get productCatalogProductType;

  /// No description provided for @productCatalogHasVariants.
  ///
  /// In en, this message translates to:
  /// **'Has variants'**
  String get productCatalogHasVariants;

  /// No description provided for @productCatalogNoVariants.
  ///
  /// In en, this message translates to:
  /// **'No variants'**
  String get productCatalogNoVariants;

  /// No description provided for @productCatalogHasModifiers.
  ///
  /// In en, this message translates to:
  /// **'Has modifiers'**
  String get productCatalogHasModifiers;

  /// No description provided for @productCatalogNoModifiers.
  ///
  /// In en, this message translates to:
  /// **'No modifiers'**
  String get productCatalogNoModifiers;

  /// No description provided for @productCatalogStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get productCatalogStandard;

  /// No description provided for @productCatalogOpenPrice.
  ///
  /// In en, this message translates to:
  /// **'Open price'**
  String get productCatalogOpenPrice;

  /// No description provided for @productCatalogCombo.
  ///
  /// In en, this message translates to:
  /// **'Combo'**
  String get productCatalogCombo;

  /// No description provided for @productCatalogSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get productCatalogSetup;

  /// No description provided for @productCatalogDefaultVariant.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get productCatalogDefaultVariant;

  /// No description provided for @productCatalogStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get productCatalogStatus;

  /// No description provided for @productCatalogOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get productCatalogOpen;

  /// No description provided for @productCatalogManageVariants.
  ///
  /// In en, this message translates to:
  /// **'Manage Variants'**
  String get productCatalogManageVariants;

  /// No description provided for @productCatalogManageModifiers.
  ///
  /// In en, this message translates to:
  /// **'Manage Modifiers'**
  String get productCatalogManageModifiers;

  /// No description provided for @productCatalogArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get productCatalogArchive;

  /// No description provided for @productCatalogRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get productCatalogRestore;

  /// No description provided for @productCatalogActionsFor.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String productCatalogActionsFor(String name);

  /// No description provided for @productCatalogSetupSummary.
  ///
  /// In en, this message translates to:
  /// **'{variants} variants · {modifiers} modifiers'**
  String productCatalogSetupSummary(int variants, int modifiers);

  /// No description provided for @productCatalogLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more products'**
  String get productCatalogLoadMore;

  /// No description provided for @productCatalogUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load products.'**
  String get productCatalogUnableToLoad;

  /// No description provided for @productCatalogNoArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived products are available.'**
  String get productCatalogNoArchived;

  /// No description provided for @productCatalogNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active products are available.'**
  String get productCatalogNoActive;

  /// No description provided for @productCatalogNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No products match these filters.'**
  String get productCatalogNoMatches;

  /// No description provided for @productCatalogNoProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products have been created yet.'**
  String get productCatalogNoProductsYet;

  /// No description provided for @productCatalogMoreFiltersHelper.
  ///
  /// In en, this message translates to:
  /// **'Refine the product list with additional criteria.'**
  String get productCatalogMoreFiltersHelper;

  /// No description provided for @productCatalogFilterClassification.
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get productCatalogFilterClassification;

  /// No description provided for @productCatalogFilterPreparation.
  ///
  /// In en, this message translates to:
  /// **'Preparation'**
  String get productCatalogFilterPreparation;

  /// No description provided for @productCatalogFilterProductSetup.
  ///
  /// In en, this message translates to:
  /// **'Product setup'**
  String get productCatalogFilterProductSetup;

  /// No description provided for @productCatalogClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get productCatalogClearFilters;

  /// No description provided for @productCatalogApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get productCatalogApplyFilters;

  /// No description provided for @productUxGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get productUxGeneral;

  /// No description provided for @productUxClassification.
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get productUxClassification;

  /// No description provided for @productUxSellingPreparation.
  ///
  /// In en, this message translates to:
  /// **'Selling & Preparation'**
  String get productUxSellingPreparation;

  /// No description provided for @productUxInitialSellingOption.
  ///
  /// In en, this message translates to:
  /// **'Initial selling option'**
  String get productUxInitialSellingOption;

  /// No description provided for @productUxTranslations.
  ///
  /// In en, this message translates to:
  /// **'Translations'**
  String get productUxTranslations;

  /// No description provided for @productUxAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get productUxAdvanced;

  /// No description provided for @productUxOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get productUxOverview;

  /// No description provided for @productUxUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get productUxUsage;

  /// No description provided for @productUxVariants.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get productUxVariants;

  /// No description provided for @productUxModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get productUxModifiers;

  /// No description provided for @productUxRecipeMaterials.
  ///
  /// In en, this message translates to:
  /// **'Recipe & Materials'**
  String get productUxRecipeMaterials;

  /// No description provided for @productUxAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get productUxAvailability;

  /// No description provided for @productUxCreateProduct.
  ///
  /// In en, this message translates to:
  /// **'Create Product'**
  String get productUxCreateProduct;

  /// No description provided for @productUxSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get productUxSaveChanges;

  /// No description provided for @productUxCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get productUxCancel;

  /// No description provided for @productUxManageCatalogSetup.
  ///
  /// In en, this message translates to:
  /// **'Manage catalog setup'**
  String get productUxManageCatalogSetup;

  /// No description provided for @productUxEditProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get productUxEditProduct;

  /// No description provided for @productUxArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get productUxArchived;

  /// No description provided for @productOverviewBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base Price'**
  String get productOverviewBasePrice;

  /// No description provided for @productOverviewVariants.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get productOverviewVariants;

  /// No description provided for @productOverviewModifierGroups.
  ///
  /// In en, this message translates to:
  /// **'Modifier Groups'**
  String get productOverviewModifierGroups;

  /// No description provided for @productOverviewStockTracking.
  ///
  /// In en, this message translates to:
  /// **'Stock Tracking'**
  String get productOverviewStockTracking;

  /// No description provided for @productOverviewEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get productOverviewEnabled;

  /// No description provided for @productOverviewDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get productOverviewDisabled;

  /// No description provided for @productOverviewNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get productOverviewNotConfigured;

  /// No description provided for @productOverviewProductSetup.
  ///
  /// In en, this message translates to:
  /// **'Product Setup'**
  String get productOverviewProductSetup;

  /// No description provided for @productOverviewCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get productOverviewCategory;

  /// No description provided for @productOverviewDefaultVariant.
  ///
  /// In en, this message translates to:
  /// **'Default Variant'**
  String get productOverviewDefaultVariant;

  /// No description provided for @productOverviewKitchenStation.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Station'**
  String get productOverviewKitchenStation;

  /// No description provided for @productOverviewProductType.
  ///
  /// In en, this message translates to:
  /// **'Product Type'**
  String get productOverviewProductType;

  /// No description provided for @productOverviewReportingCategory.
  ///
  /// In en, this message translates to:
  /// **'Reporting Category'**
  String get productOverviewReportingCategory;

  /// No description provided for @productOverviewPreparationTime.
  ///
  /// In en, this message translates to:
  /// **'Preparation Time'**
  String get productOverviewPreparationTime;

  /// No description provided for @productOverviewMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get productOverviewMinutes;

  /// No description provided for @modifierLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Modifier Library'**
  String get modifierLibraryTitle;

  /// No description provided for @modifierLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create reusable customer choices that can be assigned to Products.'**
  String get modifierLibrarySubtitle;

  /// No description provided for @modifierCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Modifier Group'**
  String get modifierCreateGroup;

  /// No description provided for @modifierSearch.
  ///
  /// In en, this message translates to:
  /// **'Search modifiers'**
  String get modifierSearch;

  /// No description provided for @modifierActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get modifierActive;

  /// No description provided for @modifierArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get modifierArchived;

  /// No description provided for @modifierAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get modifierAll;

  /// No description provided for @modifierReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get modifierReorder;

  /// No description provided for @modifierDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get modifierDone;

  /// No description provided for @modifierClearFiltersBeforeReorder.
  ///
  /// In en, this message translates to:
  /// **'Clear search and filters before reordering Modifier Groups.'**
  String get modifierClearFiltersBeforeReorder;

  /// No description provided for @modifierOptionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {0 options} =1 {1 option} other {{count} options}}'**
  String modifierOptionsCount(int count);

  /// No description provided for @modifierOptionPreviewMore.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String modifierOptionPreviewMore(int count);

  /// No description provided for @modifierRuleExactly.
  ///
  /// In en, this message translates to:
  /// **'Customer must choose exactly {count, plural, =1 {1 option} other {{count} options}}.'**
  String modifierRuleExactly(int count);

  /// No description provided for @modifierRuleOptionalExactly.
  ///
  /// In en, this message translates to:
  /// **'Optional — customer may choose {count, plural, =1 {1 option} other {{count} options}}.'**
  String modifierRuleOptionalExactly(int count);

  /// No description provided for @modifierRuleAtLeastUpTo.
  ///
  /// In en, this message translates to:
  /// **'Customer must choose at least {min} and up to {max, plural, =1 {1 option} other {{max} options}}.'**
  String modifierRuleAtLeastUpTo(int min, int max);

  /// No description provided for @modifierRuleOptionalUpTo.
  ///
  /// In en, this message translates to:
  /// **'Optional — customer may choose up to {max, plural, =1 {1 option} other {{max} options}}.'**
  String modifierRuleOptionalUpTo(int max);

  /// No description provided for @modifierRuleQuantity.
  ///
  /// In en, this message translates to:
  /// **'The same option may be added more than once.'**
  String get modifierRuleQuantity;

  /// No description provided for @modifierViewGroup.
  ///
  /// In en, this message translates to:
  /// **'View Group'**
  String get modifierViewGroup;

  /// No description provided for @modifierEditGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get modifierEditGroup;

  /// No description provided for @modifierSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get modifierSetDefault;

  /// No description provided for @modifierMaterialAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Material Adjustments'**
  String get modifierMaterialAdjustments;

  /// No description provided for @modifierArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get modifierArchive;

  /// No description provided for @modifierRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get modifierRestore;

  /// No description provided for @modifierNoGroups.
  ///
  /// In en, this message translates to:
  /// **'No modifier groups have been created yet.'**
  String get modifierNoGroups;

  /// No description provided for @modifierNoGroupMatches.
  ///
  /// In en, this message translates to:
  /// **'No modifier groups match the current filters.'**
  String get modifierNoGroupMatches;

  /// No description provided for @modifierUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load modifier groups.'**
  String get modifierUnableToLoad;

  /// No description provided for @modifierRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get modifierRetry;

  /// No description provided for @modifierLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get modifierLoadMore;

  /// No description provided for @modifierRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh modifier groups'**
  String get modifierRefresh;

  /// No description provided for @modifierGroupDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Modifier group not found.'**
  String get modifierGroupDetailNotFound;

  /// No description provided for @modifierOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get modifierOptions;

  /// No description provided for @modifierAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get modifierAddOption;

  /// No description provided for @modifierOptionFilter.
  ///
  /// In en, this message translates to:
  /// **'Option status'**
  String get modifierOptionFilter;

  /// No description provided for @modifierNoArchivedOptions.
  ///
  /// In en, this message translates to:
  /// **'No archived modifier options.'**
  String get modifierNoArchivedOptions;

  /// No description provided for @modifierNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No modifier options have been created yet.'**
  String get modifierNoOptions;

  /// No description provided for @modifierReorderOptions.
  ///
  /// In en, this message translates to:
  /// **'Reorder Options'**
  String get modifierReorderOptions;

  /// No description provided for @modifierMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get modifierMoveUp;

  /// No description provided for @modifierMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get modifierMoveDown;

  /// No description provided for @modifierDefault.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get modifierDefault;

  /// No description provided for @modifierNoExtraCharge.
  ///
  /// In en, this message translates to:
  /// **'No extra charge'**
  String get modifierNoExtraCharge;

  /// No description provided for @modifierPriceAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Price adjustment'**
  String get modifierPriceAdjustment;

  /// No description provided for @modifierMaterialUsageConfigured.
  ///
  /// In en, this message translates to:
  /// **'Material usage configured'**
  String get modifierMaterialUsageConfigured;

  /// No description provided for @modifierStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get modifierStatusActive;

  /// No description provided for @modifierStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get modifierStatusArchived;

  /// No description provided for @modifierStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get modifierStatusInactive;

  /// No description provided for @modifierAdvancedDetails.
  ///
  /// In en, this message translates to:
  /// **'Advanced Details'**
  String get modifierAdvancedDetails;

  /// No description provided for @modifierSelectionMode.
  ///
  /// In en, this message translates to:
  /// **'Selection mode'**
  String get modifierSelectionMode;

  /// No description provided for @modifierMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get modifierMinimum;

  /// No description provided for @modifierMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get modifierMaximum;

  /// No description provided for @modifierAllowQuantity.
  ///
  /// In en, this message translates to:
  /// **'Allow quantity'**
  String get modifierAllowQuantity;

  /// No description provided for @modifierGroupType.
  ///
  /// In en, this message translates to:
  /// **'Group type'**
  String get modifierGroupType;

  /// No description provided for @modifierSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get modifierSortOrder;

  /// No description provided for @modifierCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Modifier Group'**
  String get modifierCreateTitle;

  /// No description provided for @modifierEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Modifier Group'**
  String get modifierEditTitle;

  /// No description provided for @modifierBasicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get modifierBasicInformation;

  /// No description provided for @modifierBasicInformationHelper.
  ///
  /// In en, this message translates to:
  /// **'Name this reusable customer-choice group.'**
  String get modifierBasicInformationHelper;

  /// No description provided for @modifierGroupName.
  ///
  /// In en, this message translates to:
  /// **'Modifier Group Name'**
  String get modifierGroupName;

  /// No description provided for @modifierGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Milk Type'**
  String get modifierGroupNameHint;

  /// No description provided for @modifierInternalCode.
  ///
  /// In en, this message translates to:
  /// **'Internal code'**
  String get modifierInternalCode;

  /// No description provided for @modifierGroupTypeChoice.
  ///
  /// In en, this message translates to:
  /// **'Choice'**
  String get modifierGroupTypeChoice;

  /// No description provided for @modifierGroupTypeAddOn.
  ///
  /// In en, this message translates to:
  /// **'Add-on'**
  String get modifierGroupTypeAddOn;

  /// No description provided for @modifierGroupTypePreparation.
  ///
  /// In en, this message translates to:
  /// **'Preparation instruction'**
  String get modifierGroupTypePreparation;

  /// No description provided for @modifierYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get modifierYes;

  /// No description provided for @modifierNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get modifierNo;

  /// No description provided for @modifierTranslations.
  ///
  /// In en, this message translates to:
  /// **'Translations'**
  String get modifierTranslations;

  /// No description provided for @modifierArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get modifierArabic;

  /// No description provided for @modifierEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get modifierEnglish;

  /// No description provided for @modifierClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get modifierClose;

  /// No description provided for @modifierSelectionRules.
  ///
  /// In en, this message translates to:
  /// **'Selection Rules'**
  String get modifierSelectionRules;

  /// No description provided for @modifierSelectionRulesHelper.
  ///
  /// In en, this message translates to:
  /// **'Determine how customers interact with these options.'**
  String get modifierSelectionRulesHelper;

  /// No description provided for @modifierHowChoose.
  ///
  /// In en, this message translates to:
  /// **'How should customers choose?'**
  String get modifierHowChoose;

  /// No description provided for @modifierChooseOne.
  ///
  /// In en, this message translates to:
  /// **'Choose one'**
  String get modifierChooseOne;

  /// No description provided for @modifierChooseMultiple.
  ///
  /// In en, this message translates to:
  /// **'Choose multiple'**
  String get modifierChooseMultiple;

  /// No description provided for @modifierChoiceRequired.
  ///
  /// In en, this message translates to:
  /// **'Is a choice required?'**
  String get modifierChoiceRequired;

  /// No description provided for @modifierOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get modifierOptional;

  /// No description provided for @modifierRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get modifierRequired;

  /// No description provided for @modifierMinimumChoices.
  ///
  /// In en, this message translates to:
  /// **'Minimum choices'**
  String get modifierMinimumChoices;

  /// No description provided for @modifierMaximumChoices.
  ///
  /// In en, this message translates to:
  /// **'Maximum choices'**
  String get modifierMaximumChoices;

  /// No description provided for @modifierSameOptionQuantity.
  ///
  /// In en, this message translates to:
  /// **'Can the same Option be added more than once?'**
  String get modifierSameOptionQuantity;

  /// No description provided for @modifierQuantityHelper.
  ///
  /// In en, this message translates to:
  /// **'For example: 2 Extra Shots.'**
  String get modifierQuantityHelper;

  /// No description provided for @modifierCurrentRuleSummary.
  ///
  /// In en, this message translates to:
  /// **'Current Rule Summary'**
  String get modifierCurrentRuleSummary;

  /// No description provided for @modifierInitialOption.
  ///
  /// In en, this message translates to:
  /// **'Initial Option'**
  String get modifierInitialOption;

  /// No description provided for @modifierInitialOptions.
  ///
  /// In en, this message translates to:
  /// **'Initial Options'**
  String get modifierInitialOptions;

  /// No description provided for @modifierInitialOptionHelper.
  ///
  /// In en, this message translates to:
  /// **'Add enough active Options for the Maximum choices before creating the Modifier Group.'**
  String get modifierInitialOptionHelper;

  /// No description provided for @modifierAddAnotherOption.
  ///
  /// In en, this message translates to:
  /// **'Add another Option'**
  String get modifierAddAnotherOption;

  /// No description provided for @modifierRemoveOption.
  ///
  /// In en, this message translates to:
  /// **'Remove Option'**
  String get modifierRemoveOption;

  /// No description provided for @modifierAtLeastActiveOptions.
  ///
  /// In en, this message translates to:
  /// **'Add at least {count} active Options or reduce Maximum choices.'**
  String modifierAtLeastActiveOptions(int count);

  /// No description provided for @modifierOptionName.
  ///
  /// In en, this message translates to:
  /// **'Option name'**
  String get modifierOptionName;

  /// No description provided for @modifierOptionNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Whole Milk'**
  String get modifierOptionNameHint;

  /// No description provided for @modifierAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get modifierAdvanced;

  /// No description provided for @modifierActiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Active status'**
  String get modifierActiveStatus;

  /// No description provided for @modifierAvailableForUse.
  ///
  /// In en, this message translates to:
  /// **'Available for use in menus.'**
  String get modifierAvailableForUse;

  /// No description provided for @modifierCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get modifierCancel;

  /// No description provided for @modifierSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get modifierSaveChanges;

  /// No description provided for @modifierCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create Modifier Group'**
  String get modifierCreateAction;

  /// No description provided for @modifierSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get modifierSaving;

  /// No description provided for @modifierUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Leave without saving?'**
  String get modifierUnsavedChanges;

  /// No description provided for @modifierStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get modifierStay;

  /// No description provided for @modifierLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get modifierLeave;

  /// No description provided for @modifierOptionCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get modifierOptionCreateTitle;

  /// No description provided for @modifierOptionEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Option'**
  String get modifierOptionEditTitle;

  /// No description provided for @modifierOptionBasicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get modifierOptionBasicInformation;

  /// No description provided for @modifierOptionDefault.
  ///
  /// In en, this message translates to:
  /// **'Default option'**
  String get modifierOptionDefault;

  /// No description provided for @modifierOptionActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get modifierOptionActive;

  /// No description provided for @modifierOptionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get modifierOptionAvailable;

  /// No description provided for @modifierOptionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get modifierOptionAdvanced;

  /// No description provided for @modifierOptionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get modifierOptionSave;

  /// No description provided for @modifierOptionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get modifierOptionSaving;

  /// No description provided for @modifierOptionNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Option name is required.'**
  String get modifierOptionNameRequired;

  /// No description provided for @modifierOptionPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price adjustment.'**
  String get modifierOptionPriceInvalid;

  /// No description provided for @modifierOptionSortInvalid.
  ///
  /// In en, this message translates to:
  /// **'Sort order must be a whole number.'**
  String get modifierOptionSortInvalid;

  /// No description provided for @modifierArchiveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive modifier group?'**
  String get modifierArchiveGroupTitle;

  /// No description provided for @modifierArchiveOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive modifier option?'**
  String get modifierArchiveOptionTitle;

  /// No description provided for @modifierArchiveMessage.
  ///
  /// In en, this message translates to:
  /// **'The item remains stored and can be restored later.'**
  String get modifierArchiveMessage;

  /// No description provided for @modifierConfirmArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get modifierConfirmArchive;

  /// No description provided for @modifierOptionSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save this modifier option. Check the option rules and try again.'**
  String get modifierOptionSaveError;

  /// No description provided for @modifierOptionGroupInvalid.
  ///
  /// In en, this message translates to:
  /// **'This Option cannot be changed because it would make the Modifier Group invalid.'**
  String get modifierOptionGroupInvalid;

  /// No description provided for @modifierGroupSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save this modifier group.'**
  String get modifierGroupSaveError;

  /// No description provided for @modifierGroupRequired.
  ///
  /// In en, this message translates to:
  /// **'Modifier group name is required.'**
  String get modifierGroupRequired;

  /// No description provided for @modifierNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter zero or a positive whole number.'**
  String get modifierNumberInvalid;

  /// No description provided for @modifierMaximumMinimumError.
  ///
  /// In en, this message translates to:
  /// **'Maximum must be at least the minimum.'**
  String get modifierMaximumMinimumError;

  /// No description provided for @modifierSingleMaximumError.
  ///
  /// In en, this message translates to:
  /// **'Single selection groups cannot have a maximum above 1.'**
  String get modifierSingleMaximumError;

  /// No description provided for @modifierRequiredMinimumError.
  ///
  /// In en, this message translates to:
  /// **'Required groups need a minimum of at least 1.'**
  String get modifierRequiredMinimumError;

  /// No description provided for @modifierInitialOptionRequired.
  ///
  /// In en, this message translates to:
  /// **'An initial active option is required.'**
  String get modifierInitialOptionRequired;

  /// No description provided for @modifierPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter zero or a positive price.'**
  String get modifierPriceInvalid;

  /// No description provided for @modifierInitialMaximumError.
  ///
  /// In en, this message translates to:
  /// **'A new group has one initial option; maximum cannot exceed 1.'**
  String get modifierInitialMaximumError;

  /// No description provided for @configuredSellPriceMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Selling price must be greater than zero.'**
  String get configuredSellPriceMustBePositive;

  /// No description provided for @recipeVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get recipeVariant;

  /// No description provided for @recipeConfigured.
  ///
  /// In en, this message translates to:
  /// **'Recipe configured · {count} materials'**
  String recipeConfigured(int count);

  /// No description provided for @recipeMissing.
  ///
  /// In en, this message translates to:
  /// **'Recipe missing'**
  String get recipeMissing;

  /// No description provided for @recipeNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Recipe not configured'**
  String get recipeNotConfigured;

  /// No description provided for @recipeModifierMaterialEffects.
  ///
  /// In en, this message translates to:
  /// **'Modifier Material Effects'**
  String get recipeModifierMaterialEffects;

  /// No description provided for @recipeModifierMaterialEffectsHelp.
  ///
  /// In en, this message translates to:
  /// **'See how customer choices change the materials consumed.'**
  String get recipeModifierMaterialEffectsHelp;

  /// No description provided for @recipeNoMaterialChange.
  ///
  /// In en, this message translates to:
  /// **'No material change'**
  String get recipeNoMaterialChange;

  /// No description provided for @recipeUsingGlobalSettings.
  ///
  /// In en, this message translates to:
  /// **'Using Global settings'**
  String get recipeUsingGlobalSettings;

  /// No description provided for @recipeCustomizedForProduct.
  ///
  /// In en, this message translates to:
  /// **'Customized for Product'**
  String get recipeCustomizedForProduct;

  /// No description provided for @recipeCustomizedForVariant.
  ///
  /// In en, this message translates to:
  /// **'Customized for Variant'**
  String get recipeCustomizedForVariant;

  /// No description provided for @recipeTest.
  ///
  /// In en, this message translates to:
  /// **'Test Recipe'**
  String get recipeTest;

  /// No description provided for @recipeBackToWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Back to Recipe & Materials'**
  String get recipeBackToWorkspace;

  /// No description provided for @recipeSave.
  ///
  /// In en, this message translates to:
  /// **'Save recipe'**
  String get recipeSave;

  /// No description provided for @recipeSaved.
  ///
  /// In en, this message translates to:
  /// **'Recipe saved.'**
  String get recipeSaved;

  /// No description provided for @recipeCurrentBehavior.
  ///
  /// In en, this message translates to:
  /// **'Current Behavior'**
  String get recipeCurrentBehavior;

  /// No description provided for @recipeUseInherited.
  ///
  /// In en, this message translates to:
  /// **'Use inherited settings'**
  String get recipeUseInherited;

  /// No description provided for @recipeUseInheritedAgain.
  ///
  /// In en, this message translates to:
  /// **'Use inherited settings again'**
  String get recipeUseInheritedAgain;

  /// No description provided for @recipeCustomizeFor.
  ///
  /// In en, this message translates to:
  /// **'Customize for {context}'**
  String recipeCustomizeFor(String context);

  /// No description provided for @recipeNoMaterialEffectFor.
  ///
  /// In en, this message translates to:
  /// **'No material effect for {context}'**
  String recipeNoMaterialEffectFor(String context);

  /// No description provided for @recipeRemoves.
  ///
  /// In en, this message translates to:
  /// **'Removes'**
  String get recipeRemoves;

  /// No description provided for @recipeAdds.
  ///
  /// In en, this message translates to:
  /// **'Adds'**
  String get recipeAdds;

  /// No description provided for @recipeAddMaterialToRemove.
  ///
  /// In en, this message translates to:
  /// **'Add Material to Remove'**
  String get recipeAddMaterialToRemove;

  /// No description provided for @recipeAddMaterialToAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Material to Add'**
  String get recipeAddMaterialToAdd;

  /// No description provided for @recipeSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get recipeSaveChanges;

  /// No description provided for @recipeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get recipeCancel;

  /// No description provided for @recipeQuantityRequired.
  ///
  /// In en, this message translates to:
  /// **'Quantity is required.'**
  String get recipeQuantityRequired;

  /// No description provided for @recipeQuantityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number with up to 6 decimal places.'**
  String get recipeQuantityInvalid;

  /// No description provided for @recipeDuplicateMaterial.
  ///
  /// In en, this message translates to:
  /// **'This material is already used.'**
  String get recipeDuplicateMaterial;

  /// No description provided for @recipeMaterialSearch.
  ///
  /// In en, this message translates to:
  /// **'Search materials'**
  String get recipeMaterialSearch;

  /// No description provided for @recipeNoMaterialResults.
  ///
  /// In en, this message translates to:
  /// **'No materials found.'**
  String get recipeNoMaterialResults;

  /// No description provided for @recipeFinalMaterials.
  ///
  /// In en, this message translates to:
  /// **'Final Materials'**
  String get recipeFinalMaterials;

  /// No description provided for @recipePreviewMaterials.
  ///
  /// In en, this message translates to:
  /// **'Preview Materials'**
  String get recipePreviewMaterials;

  /// No description provided for @recipeHowCalculated.
  ///
  /// In en, this message translates to:
  /// **'How this was calculated'**
  String get recipeHowCalculated;

  /// No description provided for @recipeChoicesChanged.
  ///
  /// In en, this message translates to:
  /// **'Choices changed'**
  String get recipeChoicesChanged;

  /// No description provided for @recipeStaleResult.
  ///
  /// In en, this message translates to:
  /// **'Preview the materials again to update this result.'**
  String get recipeStaleResult;

  /// No description provided for @recipeDecreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get recipeDecreaseQuantity;

  /// No description provided for @recipeIncreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get recipeIncreaseQuantity;

  /// No description provided for @batch8AvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Selling availability'**
  String get batch8AvailabilityTitle;

  /// No description provided for @batch8AvailabilityHelp.
  ///
  /// In en, this message translates to:
  /// **'Review the price, regular selling hours, and current operational status for this selling context.'**
  String get batch8AvailabilityHelp;

  /// No description provided for @batch8Variant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get batch8Variant;

  /// No description provided for @batch8Branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get batch8Branch;

  /// No description provided for @batch8Channel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get batch8Channel;

  /// No description provided for @batch8AvailabilityLoadError.
  ///
  /// In en, this message translates to:
  /// **'Availability could not be loaded.'**
  String get batch8AvailabilityLoadError;

  /// No description provided for @batch8Retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get batch8Retry;

  /// No description provided for @batch8Loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get batch8Loading;

  /// No description provided for @batch8Checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get batch8Checking;

  /// No description provided for @batch8SellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get batch8SellingPrice;

  /// No description provided for @batch8BasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base price'**
  String get batch8BasePrice;

  /// No description provided for @batch8EffectiveSellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Effective selling price'**
  String get batch8EffectiveSellingPrice;

  /// No description provided for @batch8Using.
  ///
  /// In en, this message translates to:
  /// **'Using'**
  String get batch8Using;

  /// No description provided for @batch8ManagePricing.
  ///
  /// In en, this message translates to:
  /// **'Manage pricing'**
  String get batch8ManagePricing;

  /// No description provided for @batch8PriceLoadingHelp.
  ///
  /// In en, this message translates to:
  /// **'Resolving the selling price for this context.'**
  String get batch8PriceLoadingHelp;

  /// No description provided for @batch8PriceFromBase.
  ///
  /// In en, this message translates to:
  /// **'Variant base price'**
  String get batch8PriceFromBase;

  /// No description provided for @batch8PriceFromBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch price'**
  String get batch8PriceFromBranch;

  /// No description provided for @batch8PriceFromChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel price'**
  String get batch8PriceFromChannel;

  /// No description provided for @batch8PriceFromBranchAndChannel.
  ///
  /// In en, this message translates to:
  /// **'Branch and channel price'**
  String get batch8PriceFromBranchAndChannel;

  /// No description provided for @batch8RegularAvailability.
  ///
  /// In en, this message translates to:
  /// **'Regular availability'**
  String get batch8RegularAvailability;

  /// No description provided for @batch8NoScheduleRestrictions.
  ///
  /// In en, this message translates to:
  /// **'No schedule restrictions'**
  String get batch8NoScheduleRestrictions;

  /// No description provided for @batch8NoScheduleRestrictionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Normally available whenever this selling context is open.'**
  String get batch8NoScheduleRestrictionsHelp;

  /// No description provided for @batch8ScheduleLoadingHelp.
  ///
  /// In en, this message translates to:
  /// **'Checking regular selling hours for this context.'**
  String get batch8ScheduleLoadingHelp;

  /// No description provided for @batch8AvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get batch8AvailableNow;

  /// No description provided for @batch8UnavailableNow.
  ///
  /// In en, this message translates to:
  /// **'Unavailable now'**
  String get batch8UnavailableNow;

  /// No description provided for @batch8Unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get batch8Unavailable;

  /// No description provided for @batch8AvailableAccordingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Available according to regular selling hours.'**
  String get batch8AvailableAccordingSchedule;

  /// No description provided for @batch8UnavailableAccordingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Outside the regular selling hours.'**
  String get batch8UnavailableAccordingSchedule;

  /// No description provided for @batch8ScheduleRules.
  ///
  /// In en, this message translates to:
  /// **'Configured selling hours'**
  String get batch8ScheduleRules;

  /// No description provided for @batch8ManageSchedule.
  ///
  /// In en, this message translates to:
  /// **'Manage schedule'**
  String get batch8ManageSchedule;

  /// No description provided for @batch8CurrentAvailability.
  ///
  /// In en, this message translates to:
  /// **'Current availability'**
  String get batch8CurrentAvailability;

  /// No description provided for @batch8CurrentLoadingHelp.
  ///
  /// In en, this message translates to:
  /// **'Checking temporary operational status for this context.'**
  String get batch8CurrentLoadingHelp;

  /// No description provided for @batch8SoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get batch8SoldOut;

  /// No description provided for @batch8TemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Temporarily unavailable'**
  String get batch8TemporarilyUnavailable;

  /// No description provided for @batch8NoTemporaryRestriction.
  ///
  /// In en, this message translates to:
  /// **'No temporary restriction is active.'**
  String get batch8NoTemporaryRestriction;

  /// No description provided for @batch8TemporaryRestrictionActive.
  ///
  /// In en, this message translates to:
  /// **'A temporary operational restriction is active.'**
  String get batch8TemporaryRestrictionActive;

  /// No description provided for @batch8TemporaryUntil.
  ///
  /// In en, this message translates to:
  /// **'Temporary restriction active until {time}.'**
  String batch8TemporaryUntil(String time);

  /// No description provided for @batch8ManageAvailability.
  ///
  /// In en, this message translates to:
  /// **'Manage availability'**
  String get batch8ManageAvailability;

  /// No description provided for @batch8EffectiveSellingResult.
  ///
  /// In en, this message translates to:
  /// **'Effective selling result'**
  String get batch8EffectiveSellingResult;

  /// No description provided for @batch8Availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get batch8Availability;
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
