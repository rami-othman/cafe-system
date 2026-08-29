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

  /// No description provided for @versionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get versionView;

  /// No description provided for @versionSelectForCompare.
  ///
  /// In en, this message translates to:
  /// **'Select Version {version} for comparison'**
  String versionSelectForCompare(int version);

  /// No description provided for @versionCompareSelected.
  ///
  /// In en, this message translates to:
  /// **'Compare selected ({count})'**
  String versionCompareSelected(int count);

  /// No description provided for @versionHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No version history'**
  String get versionHistoryEmptyTitle;

  /// No description provided for @versionHistoryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'No Menu version has been published for {branch} · {channel} yet.'**
  String versionHistoryEmptyDescription(Object branch, Object channel);

  /// No description provided for @versionHistoryLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load version history.'**
  String get versionHistoryLoadError;

  /// No description provided for @versionDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this version.'**
  String get versionDetailLoadError;

  /// No description provided for @versionCompareError.
  ///
  /// In en, this message translates to:
  /// **'Could not compare these versions.'**
  String get versionCompareError;

  /// No description provided for @versionRestoreError.
  ///
  /// In en, this message translates to:
  /// **'Could not restore this version.'**
  String get versionRestoreError;

  /// No description provided for @versionPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get versionPreviousPage;

  /// No description provided for @versionNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get versionNextPage;

  /// No description provided for @versionPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String versionPage(int page);

  /// No description provided for @versionChangeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change} other{{count} changes}}'**
  String versionChangeCount(num count);

  /// No description provided for @versionChangesSince.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change} other{{count} changes}} since Version {version}'**
  String versionChangesSince(num count, int version);

  /// No description provided for @versionPublishedAt.
  ///
  /// In en, this message translates to:
  /// **'Published {date}'**
  String versionPublishedAt(Object date);

  /// No description provided for @versionMenus.
  ///
  /// In en, this message translates to:
  /// **'Menus'**
  String get versionMenus;

  /// No description provided for @versionSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get versionSections;

  /// No description provided for @versionProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get versionProducts;

  /// No description provided for @versionPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get versionPricing;

  /// No description provided for @versionModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get versionModifiers;

  /// No description provided for @versionRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get versionRecipes;

  /// No description provided for @versionSchedules.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get versionSchedules;

  /// No description provided for @versionChanges.
  ///
  /// In en, this message translates to:
  /// **'changes'**
  String get versionChanges;

  /// No description provided for @versionChangeSummary.
  ///
  /// In en, this message translates to:
  /// **'Change summary'**
  String get versionChangeSummary;

  /// No description provided for @versionChangeSummaryAvailable.
  ///
  /// In en, this message translates to:
  /// **'This version includes a recorded change summary.'**
  String get versionChangeSummaryAvailable;

  /// No description provided for @versionChangeSummaryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No change summary is available for this version.'**
  String get versionChangeSummaryUnavailable;

  /// No description provided for @versionRestoreThisVersion.
  ///
  /// In en, this message translates to:
  /// **'Restore this Version'**
  String get versionRestoreThisVersion;

  /// No description provided for @versionRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Version {version}?'**
  String versionRestoreTitle(int version);

  /// No description provided for @versionRestoreExplanation.
  ///
  /// In en, this message translates to:
  /// **'A new published version will be created using the contents of Version {version}. Versions published after Version {version} will remain in history.'**
  String versionRestoreExplanation(int version);

  /// No description provided for @versionRestoreReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for restore (optional)'**
  String get versionRestoreReason;

  /// No description provided for @versionRestoreReasonHint.
  ///
  /// In en, this message translates to:
  /// **'For example, restore after an unintended pricing change'**
  String get versionRestoreReasonHint;

  /// No description provided for @versionRestoreAsNewVersion.
  ///
  /// In en, this message translates to:
  /// **'Restore as New Version'**
  String get versionRestoreAsNewVersion;

  /// No description provided for @versionRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get versionRestoring;

  /// No description provided for @versionRestoreResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Version restored'**
  String get versionRestoreResultTitle;

  /// No description provided for @versionRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Version {newVersion} was created from Version {sourceVersion}. Version {newVersion} is now Current.'**
  String versionRestoreSuccess(int newVersion, int sourceVersion);

  /// No description provided for @versionRestoreNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Version {version} already matches the current published content. No new version was created.'**
  String versionRestoreNoChanges(int version);

  /// No description provided for @versionComparisonDirection.
  ///
  /// In en, this message translates to:
  /// **'Version {fromVersion} → Version {toVersion}'**
  String versionComparisonDirection(int fromVersion, int toVersion);

  /// No description provided for @versionNoContentDifferences.
  ///
  /// In en, this message translates to:
  /// **'No content differences found.'**
  String get versionNoContentDifferences;

  /// No description provided for @versionComparisonTruncated.
  ///
  /// In en, this message translates to:
  /// **'Additional changes are not shown.'**
  String get versionComparisonTruncated;

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
  /// **'Assignments & Schedules'**
  String get menuManagementAssignments;

  /// No description provided for @menuManagementReview.
  ///
  /// In en, this message translates to:
  /// **'Review & preview'**
  String get menuManagementReview;

  /// No description provided for @menuManagementCatalogSetup.
  ///
  /// In en, this message translates to:
  /// **'Catalog Setup'**
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

  /// No description provided for @batch8PricingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get batch8PricingBack;

  /// No description provided for @batch8PricingRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get batch8PricingRefresh;

  /// No description provided for @batch8PricingLoadError.
  ///
  /// In en, this message translates to:
  /// **'Pricing could not be loaded.'**
  String get batch8PricingLoadError;

  /// No description provided for @batch8PricingArchived.
  ///
  /// In en, this message translates to:
  /// **'This Product or Variant is archived. Prices are shown for reference and cannot be changed.'**
  String get batch8PricingArchived;

  /// No description provided for @batch8PricingContext.
  ///
  /// In en, this message translates to:
  /// **'{variant} · Selling price'**
  String batch8PricingContext(String variant);

  /// No description provided for @batch8PricingHelp.
  ///
  /// In en, this message translates to:
  /// **'The selling price for the selected Variant, Branch, and sales channel.'**
  String get batch8PricingHelp;

  /// No description provided for @batch8SalesChannel.
  ///
  /// In en, this message translates to:
  /// **'Sales channel'**
  String get batch8SalesChannel;

  /// No description provided for @batch8NoBranch.
  ///
  /// In en, this message translates to:
  /// **'No Branch'**
  String get batch8NoBranch;

  /// No description provided for @batch8NoChannel.
  ///
  /// In en, this message translates to:
  /// **'No Channel'**
  String get batch8NoChannel;

  /// No description provided for @batch8ChangePrice.
  ///
  /// In en, this message translates to:
  /// **'Change Price'**
  String get batch8ChangePrice;

  /// No description provided for @batch8MorePriceRules.
  ///
  /// In en, this message translates to:
  /// **'More Price Rules'**
  String get batch8MorePriceRules;

  /// No description provided for @batch8RulesConfigured.
  ///
  /// In en, this message translates to:
  /// **'{count} configured'**
  String batch8RulesConfigured(int count);

  /// No description provided for @batch8Show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get batch8Show;

  /// No description provided for @batch8Hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get batch8Hide;

  /// No description provided for @batch8NoPriceAdjustments.
  ///
  /// In en, this message translates to:
  /// **'No price adjustments.'**
  String get batch8NoPriceAdjustments;

  /// No description provided for @batch8BasePriceEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Base Price applies everywhere.'**
  String get batch8BasePriceEverywhere;

  /// No description provided for @batch8Difference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get batch8Difference;

  /// No description provided for @batch8AddPrice.
  ///
  /// In en, this message translates to:
  /// **'Add Price'**
  String get batch8AddPrice;

  /// No description provided for @batch8SetSellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Set Selling Price'**
  String get batch8SetSellingPrice;

  /// No description provided for @batch8Product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get batch8Product;

  /// No description provided for @batch8AppliesTo.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get batch8AppliesTo;

  /// No description provided for @batch8ScopeBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get batch8ScopeBranch;

  /// No description provided for @batch8ScopeChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get batch8ScopeChannel;

  /// No description provided for @batch8ScopeBranchChannel.
  ///
  /// In en, this message translates to:
  /// **'Branch + Channel'**
  String get batch8ScopeBranchChannel;

  /// No description provided for @batch8Price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get batch8Price;

  /// No description provided for @batch8PriceAboveBase.
  ///
  /// In en, this message translates to:
  /// **'{difference} above Base Price'**
  String batch8PriceAboveBase(String difference);

  /// No description provided for @batch8PriceBelowBase.
  ///
  /// In en, this message translates to:
  /// **'{difference} below Base Price'**
  String batch8PriceBelowBase(String difference);

  /// No description provided for @batch8PriceSameAsBase.
  ///
  /// In en, this message translates to:
  /// **'Same as Base Price'**
  String get batch8PriceSameAsBase;

  /// No description provided for @batch8Cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get batch8Cancel;

  /// No description provided for @batch8SavePrice.
  ///
  /// In en, this message translates to:
  /// **'Save Price'**
  String get batch8SavePrice;

  /// No description provided for @batch8Edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get batch8Edit;

  /// No description provided for @batch8Remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get batch8Remove;

  /// No description provided for @batch8RemovePriceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove price rule?'**
  String get batch8RemovePriceTitle;

  /// No description provided for @batch8RemovePriceMessage.
  ///
  /// In en, this message translates to:
  /// **'This price adjustment will be removed for this Variant.'**
  String get batch8RemovePriceMessage;

  /// No description provided for @batch8Keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get batch8Keep;

  /// No description provided for @batch8BranchPriceFor.
  ///
  /// In en, this message translates to:
  /// **'{branch} Branch price'**
  String batch8BranchPriceFor(String branch);

  /// No description provided for @batch8ChannelPriceFor.
  ///
  /// In en, this message translates to:
  /// **'{channel} channel price'**
  String batch8ChannelPriceFor(String channel);

  /// No description provided for @batch8BranchChannelPriceFor.
  ///
  /// In en, this message translates to:
  /// **'{branch} · {channel} price'**
  String batch8BranchChannelPriceFor(String branch, String channel);

  /// No description provided for @batch8RuleBranchPrice.
  ///
  /// In en, this message translates to:
  /// **'Branch price'**
  String get batch8RuleBranchPrice;

  /// No description provided for @batch8RuleChannelPrice.
  ///
  /// In en, this message translates to:
  /// **'Channel price'**
  String get batch8RuleChannelPrice;

  /// No description provided for @batch8RuleBranchChannelPrice.
  ///
  /// In en, this message translates to:
  /// **'Branch + Channel price'**
  String get batch8RuleBranchChannelPrice;

  /// No description provided for @batch8ChannelPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get batch8ChannelPos;

  /// No description provided for @batch8ChannelWaiterApp.
  ///
  /// In en, this message translates to:
  /// **'Waiter App'**
  String get batch8ChannelWaiterApp;

  /// No description provided for @batch8ChannelKiosk.
  ///
  /// In en, this message translates to:
  /// **'Kiosk'**
  String get batch8ChannelKiosk;

  /// No description provided for @batch8ChannelQrOrdering.
  ///
  /// In en, this message translates to:
  /// **'QR Ordering'**
  String get batch8ChannelQrOrdering;

  /// No description provided for @batch8ChannelDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get batch8ChannelDelivery;

  /// No description provided for @batch8ChannelOnlineOrdering.
  ///
  /// In en, this message translates to:
  /// **'Online Ordering'**
  String get batch8ChannelOnlineOrdering;

  /// No description provided for @batch8UnsavedPriceChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved price changes'**
  String get batch8UnsavedPriceChanges;

  /// No description provided for @batch8UnsavedPriceChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved price changes. Leave without saving?'**
  String get batch8UnsavedPriceChangesMessage;

  /// No description provided for @batch8Leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get batch8Leave;

  /// No description provided for @scheduledUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved selling hours'**
  String get scheduledUnsavedChanges;

  /// No description provided for @scheduledUnsavedChangesHelp.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved selling-hours changes. Leave without saving?'**
  String get scheduledUnsavedChangesHelp;

  /// No description provided for @scheduledStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get scheduledStay;

  /// No description provided for @scheduledLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get scheduledLeave;

  /// No description provided for @scheduledLoadError.
  ///
  /// In en, this message translates to:
  /// **'Scheduled availability could not be loaded.'**
  String get scheduledLoadError;

  /// No description provided for @scheduledSaveError.
  ///
  /// In en, this message translates to:
  /// **'Selling hours could not be saved. Please review the entered values and try again.'**
  String get scheduledSaveError;

  /// No description provided for @scheduledSaved.
  ///
  /// In en, this message translates to:
  /// **'Selling hours saved.'**
  String get scheduledSaved;

  /// No description provided for @scheduledArchived.
  ///
  /// In en, this message translates to:
  /// **'This Product or Variant is archived. Selling hours are shown for reference and cannot be changed.'**
  String get scheduledArchived;

  /// No description provided for @scheduledRegularForProduct.
  ///
  /// In en, this message translates to:
  /// **'Product · Regular availability'**
  String get scheduledRegularForProduct;

  /// No description provided for @scheduledRegularForVariant.
  ///
  /// In en, this message translates to:
  /// **'{variant} · Regular availability'**
  String scheduledRegularForVariant(String variant);

  /// No description provided for @scheduledProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get scheduledProduct;

  /// No description provided for @scheduledAllBranches.
  ///
  /// In en, this message translates to:
  /// **'All branches'**
  String get scheduledAllBranches;

  /// No description provided for @scheduledAllChannels.
  ///
  /// In en, this message translates to:
  /// **'All channels'**
  String get scheduledAllChannels;

  /// No description provided for @scheduledUsingProduct.
  ///
  /// In en, this message translates to:
  /// **'Using Product schedule'**
  String get scheduledUsingProduct;

  /// No description provided for @scheduledProductSchedule.
  ///
  /// In en, this message translates to:
  /// **'Product schedule'**
  String get scheduledProductSchedule;

  /// No description provided for @scheduledCustomizedFor.
  ///
  /// In en, this message translates to:
  /// **'Customized for {variant}'**
  String scheduledCustomizedFor(String variant);

  /// No description provided for @scheduledCustomizeFor.
  ///
  /// In en, this message translates to:
  /// **'Customize for {variant}'**
  String scheduledCustomizeFor(String variant);

  /// No description provided for @scheduledUseProductAgain.
  ///
  /// In en, this message translates to:
  /// **'Use Product schedule again'**
  String get scheduledUseProductAgain;

  /// No description provided for @scheduledWeeklyInAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Weekly hours are shown in Advanced Schedule Rules.'**
  String get scheduledWeeklyInAdvanced;

  /// No description provided for @scheduledNoSpecificRestriction.
  ///
  /// In en, this message translates to:
  /// **'No specific restriction'**
  String get scheduledNoSpecificRestriction;

  /// No description provided for @scheduledAvailableAllDay.
  ///
  /// In en, this message translates to:
  /// **'Available all day'**
  String get scheduledAvailableAllDay;

  /// No description provided for @scheduledEditSellingHours.
  ///
  /// In en, this message translates to:
  /// **'Edit Selling Hours'**
  String get scheduledEditSellingHours;

  /// No description provided for @scheduledAdvancedRules.
  ///
  /// In en, this message translates to:
  /// **'Advanced Schedule Rules'**
  String get scheduledAdvancedRules;

  /// No description provided for @scheduledNoAdvancedRules.
  ///
  /// In en, this message translates to:
  /// **'No advanced schedule rules'**
  String get scheduledNoAdvancedRules;

  /// No description provided for @scheduledViewRules.
  ///
  /// In en, this message translates to:
  /// **'View Rules'**
  String get scheduledViewRules;

  /// No description provided for @scheduledInactiveRule.
  ///
  /// In en, this message translates to:
  /// **'Inactive schedule rule'**
  String get scheduledInactiveRule;

  /// No description provided for @scheduledPriorityRule.
  ///
  /// In en, this message translates to:
  /// **'Priority schedule rule'**
  String get scheduledPriorityRule;

  /// No description provided for @scheduledDateBoundRule.
  ///
  /// In en, this message translates to:
  /// **'Date-limited schedule rule'**
  String get scheduledDateBoundRule;

  /// No description provided for @scheduledCheckAvailability.
  ///
  /// In en, this message translates to:
  /// **'Check Availability'**
  String get scheduledCheckAvailability;

  /// No description provided for @scheduledCheckHelp.
  ///
  /// In en, this message translates to:
  /// **'Check a date and time in the selected selling context.'**
  String get scheduledCheckHelp;

  /// No description provided for @scheduledDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get scheduledDate;

  /// No description provided for @scheduledTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get scheduledTime;

  /// No description provided for @scheduledCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get scheduledCheck;

  /// No description provided for @scheduledCheckError.
  ///
  /// In en, this message translates to:
  /// **'Availability could not be checked. Please try again.'**
  String get scheduledCheckError;

  /// No description provided for @scheduledAvailableUsingProduct.
  ///
  /// In en, this message translates to:
  /// **'Available according to the Product schedule.'**
  String get scheduledAvailableUsingProduct;

  /// No description provided for @scheduledDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get scheduledDay;

  /// No description provided for @scheduledEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get scheduledEveryDay;

  /// No description provided for @scheduledAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get scheduledAvailability;

  /// No description provided for @scheduledAvailableAllDayHelp.
  ///
  /// In en, this message translates to:
  /// **'No time restriction for this day.'**
  String get scheduledAvailableAllDayHelp;

  /// No description provided for @scheduledCustomHours.
  ///
  /// In en, this message translates to:
  /// **'Custom hours'**
  String get scheduledCustomHours;

  /// No description provided for @scheduledCustomHoursHelp.
  ///
  /// In en, this message translates to:
  /// **'Set the normal start and end time.'**
  String get scheduledCustomHoursHelp;

  /// No description provided for @scheduledStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get scheduledStartTime;

  /// No description provided for @scheduledEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get scheduledEndTime;

  /// No description provided for @scheduledOvernightUntil.
  ///
  /// In en, this message translates to:
  /// **'Available overnight until {time} the next day.'**
  String scheduledOvernightUntil(String time);

  /// No description provided for @scheduledDateLimits.
  ///
  /// In en, this message translates to:
  /// **'Date Limits'**
  String get scheduledDateLimits;

  /// No description provided for @scheduledOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get scheduledOptional;

  /// No description provided for @scheduledStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get scheduledStartDate;

  /// No description provided for @scheduledEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get scheduledEndDate;

  /// No description provided for @scheduledSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get scheduledSelectDate;

  /// No description provided for @scheduledAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get scheduledAdvanced;

  /// No description provided for @scheduledPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get scheduledPriority;

  /// No description provided for @scheduledActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get scheduledActive;

  /// No description provided for @scheduledSaveSellingHours.
  ///
  /// In en, this message translates to:
  /// **'Save Selling Hours'**
  String get scheduledSaveSellingHours;

  /// No description provided for @scheduledFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get scheduledFrom;

  /// No description provided for @scheduledUntil.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get scheduledUntil;

  /// No description provided for @scheduledSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get scheduledSunday;

  /// No description provided for @scheduledMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get scheduledMonday;

  /// No description provided for @scheduledTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get scheduledTuesday;

  /// No description provided for @scheduledWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get scheduledWednesday;

  /// No description provided for @scheduledThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get scheduledThursday;

  /// No description provided for @scheduledFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get scheduledFriday;

  /// No description provided for @scheduledSaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get scheduledSaturday;

  /// No description provided for @operationalAvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Operational availability'**
  String get operationalAvailabilityTitle;

  /// No description provided for @operationalAvailabilityPurpose.
  ///
  /// In en, this message translates to:
  /// **'Can customers order this item right now? Temporary operational exceptions only.'**
  String get operationalAvailabilityPurpose;

  /// No description provided for @operationalAvailabilityContext.
  ///
  /// In en, this message translates to:
  /// **'Current context'**
  String get operationalAvailabilityContext;

  /// No description provided for @operationalAvailabilityProductVariant.
  ///
  /// In en, this message translates to:
  /// **'Product / Variant'**
  String get operationalAvailabilityProductVariant;

  /// No description provided for @operationalAvailabilityProductOnly.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get operationalAvailabilityProductOnly;

  /// No description provided for @operationalAvailabilityBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get operationalAvailabilityBranch;

  /// No description provided for @operationalAvailabilityChannel.
  ///
  /// In en, this message translates to:
  /// **'Sales channel'**
  String get operationalAvailabilityChannel;

  /// No description provided for @operationalAvailabilitySelectBranch.
  ///
  /// In en, this message translates to:
  /// **'Select an active branch'**
  String get operationalAvailabilitySelectBranch;

  /// No description provided for @operationalAvailabilitySelectChannel.
  ///
  /// In en, this message translates to:
  /// **'Select a sales channel'**
  String get operationalAvailabilitySelectChannel;

  /// No description provided for @operationalAvailabilityAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE NOW'**
  String get operationalAvailabilityAvailableNow;

  /// No description provided for @operationalAvailabilitySoldOut.
  ///
  /// In en, this message translates to:
  /// **'SOLD OUT'**
  String get operationalAvailabilitySoldOut;

  /// No description provided for @operationalAvailabilityTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'TEMPORARILY UNAVAILABLE'**
  String get operationalAvailabilityTemporarilyUnavailable;

  /// No description provided for @operationalAvailabilityNoRestriction.
  ///
  /// In en, this message translates to:
  /// **'No temporary restriction is active.'**
  String get operationalAvailabilityNoRestriction;

  /// No description provided for @operationalAvailabilityActiveRestriction.
  ///
  /// In en, this message translates to:
  /// **'A temporary operational restriction is active.'**
  String get operationalAvailabilityActiveRestriction;

  /// No description provided for @operationalAvailabilityUntil.
  ///
  /// In en, this message translates to:
  /// **'Until: {time}'**
  String operationalAvailabilityUntil(String time);

  /// No description provided for @operationalAvailabilityReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get operationalAvailabilityReason;

  /// No description provided for @operationalAvailabilityMarkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Mark temporarily unavailable'**
  String get operationalAvailabilityMarkUnavailable;

  /// No description provided for @operationalAvailabilityMakeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Make available now'**
  String get operationalAvailabilityMakeAvailable;

  /// No description provided for @operationalAvailabilityEditStatus.
  ///
  /// In en, this message translates to:
  /// **'Edit status'**
  String get operationalAvailabilityEditStatus;

  /// No description provided for @operationalAvailabilityEditTemporary.
  ///
  /// In en, this message translates to:
  /// **'Edit temporary restriction'**
  String get operationalAvailabilityEditTemporary;

  /// No description provided for @operationalAvailabilityUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default status'**
  String get operationalAvailabilityUseDefault;

  /// No description provided for @operationalAvailabilityUseDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Use default status?'**
  String get operationalAvailabilityUseDefaultTitle;

  /// No description provided for @operationalAvailabilityUseDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes only the status set for this exact product context. The resulting availability will be checked again.'**
  String get operationalAvailabilityUseDefaultMessage;

  /// No description provided for @operationalAvailabilityDefaultAction.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get operationalAvailabilityDefaultAction;

  /// No description provided for @operationalAvailabilityAllVariants.
  ///
  /// In en, this message translates to:
  /// **'This status applies to all variants of this product.'**
  String get operationalAvailabilityAllVariants;

  /// No description provided for @operationalAvailabilityOnlyVariant.
  ///
  /// In en, this message translates to:
  /// **'This status affects only {variant}.'**
  String operationalAvailabilityOnlyVariant(String variant);

  /// No description provided for @operationalAvailabilityLoadingCurrent.
  ///
  /// In en, this message translates to:
  /// **'Updating current availability…'**
  String get operationalAvailabilityLoadingCurrent;

  /// No description provided for @operationalAvailabilityNoContext.
  ///
  /// In en, this message translates to:
  /// **'Choose an active branch and sales channel to view current availability.'**
  String get operationalAvailabilityNoContext;

  /// No description provided for @operationalAvailabilityLoadError.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load current availability. Try again.'**
  String get operationalAvailabilityLoadError;

  /// No description provided for @operationalAvailabilityArchived.
  ///
  /// In en, this message translates to:
  /// **'This item is archived. Current availability is shown for reference and cannot be changed.'**
  String get operationalAvailabilityArchived;

  /// No description provided for @operationalAvailabilitySetStatus.
  ///
  /// In en, this message translates to:
  /// **'Set availability status'**
  String get operationalAvailabilitySetStatus;

  /// No description provided for @operationalAvailabilityEditStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit availability status'**
  String get operationalAvailabilityEditStatusTitle;

  /// No description provided for @operationalAvailabilityStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get operationalAvailabilityStatus;

  /// No description provided for @operationalAvailabilityDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get operationalAvailabilityDuration;

  /// No description provided for @operationalAvailabilitySpecificTime.
  ///
  /// In en, this message translates to:
  /// **'Until a specific time'**
  String get operationalAvailabilitySpecificTime;

  /// No description provided for @operationalAvailabilityEndTimeRequired.
  ///
  /// In en, this message translates to:
  /// **'Select when this temporary restriction should end.'**
  String get operationalAvailabilityEndTimeRequired;

  /// No description provided for @operationalAvailabilitySelectEndTime.
  ///
  /// In en, this message translates to:
  /// **'Select end date and time'**
  String get operationalAvailabilitySelectEndTime;

  /// No description provided for @operationalAvailabilityBranchTime.
  ///
  /// In en, this message translates to:
  /// **'The time is shown in the selected branch’s local time.'**
  String get operationalAvailabilityBranchTime;

  /// No description provided for @operationalAvailabilitySave.
  ///
  /// In en, this message translates to:
  /// **'Save status'**
  String get operationalAvailabilitySave;

  /// No description provided for @operationalAvailabilitySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get operationalAvailabilitySaving;

  /// No description provided for @operationalAvailabilityCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get operationalAvailabilityCancel;

  /// No description provided for @operationalAvailabilityExplicitAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available for this selling context.'**
  String get operationalAvailabilityExplicitAvailable;

  /// No description provided for @operationalAvailabilitySaveError.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t save this availability status. Review the details and try again.'**
  String get operationalAvailabilitySaveError;

  /// No description provided for @catalogSetupWorkspaceHelp.
  ///
  /// In en, this message translates to:
  /// **'Configure the classifications and preparation destinations used by Products.'**
  String get catalogSetupWorkspaceHelp;

  /// No description provided for @catalogSetupCategoriesPurpose.
  ///
  /// In en, this message translates to:
  /// **'Organize Products into clear catalog and menu groups.'**
  String get catalogSetupCategoriesPurpose;

  /// No description provided for @catalogSetupReportingPurpose.
  ///
  /// In en, this message translates to:
  /// **'Group Products for sales and performance reporting.'**
  String get catalogSetupReportingPurpose;

  /// No description provided for @catalogSetupReportingNote.
  ///
  /// In en, this message translates to:
  /// **'Reporting Categories do not control where Products appear in the menu.'**
  String get catalogSetupReportingNote;

  /// No description provided for @catalogSetupStationsPurpose.
  ///
  /// In en, this message translates to:
  /// **'Define where Products and items are prepared.'**
  String get catalogSetupStationsPurpose;

  /// No description provided for @catalogSetupSearchCategories.
  ///
  /// In en, this message translates to:
  /// **'Search categories...'**
  String get catalogSetupSearchCategories;

  /// No description provided for @catalogSetupSearchReporting.
  ///
  /// In en, this message translates to:
  /// **'Search reporting categories...'**
  String get catalogSetupSearchReporting;

  /// No description provided for @catalogSetupSearchStations.
  ///
  /// In en, this message translates to:
  /// **'Search kitchen stations...'**
  String get catalogSetupSearchStations;

  /// No description provided for @catalogSetupAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {type}'**
  String catalogSetupAdd(String type);

  /// No description provided for @catalogSetupSave.
  ///
  /// In en, this message translates to:
  /// **'Save {type}'**
  String catalogSetupSave(String type);

  /// No description provided for @catalogSetupNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get catalogSetupNoCategories;

  /// No description provided for @catalogSetupNoReportingCategories.
  ///
  /// In en, this message translates to:
  /// **'No reporting categories yet'**
  String get catalogSetupNoReportingCategories;

  /// No description provided for @catalogSetupNoKitchenStations.
  ///
  /// In en, this message translates to:
  /// **'No kitchen stations yet'**
  String get catalogSetupNoKitchenStations;

  /// No description provided for @catalogSetupEmptyCategoriesHelp.
  ///
  /// In en, this message translates to:
  /// **'Categories help organize Products into clear groups.'**
  String get catalogSetupEmptyCategoriesHelp;

  /// No description provided for @catalogSetupEmptyReportingHelp.
  ///
  /// In en, this message translates to:
  /// **'Reporting Categories help group Products for useful sales reporting.'**
  String get catalogSetupEmptyReportingHelp;

  /// No description provided for @catalogSetupEmptyStationsHelp.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Stations help define where each Product is prepared.'**
  String get catalogSetupEmptyStationsHelp;

  /// No description provided for @catalogSetupCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load data'**
  String get catalogSetupCouldNotLoad;

  /// No description provided for @catalogSetupLoadHelp.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get catalogSetupLoadHelp;

  /// No description provided for @catalogSetupShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String catalogSetupShowing(int shown, int total);

  /// No description provided for @catalogSetupActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get catalogSetupActive;

  /// No description provided for @catalogSetupArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get catalogSetupArchived;

  /// No description provided for @catalogSetupInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get catalogSetupInactive;

  /// No description provided for @catalogSetupEditorHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the names that staff and customers should recognize.'**
  String get catalogSetupEditorHelp;

  /// No description provided for @catalogSetupPrimaryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get catalogSetupPrimaryName;

  /// No description provided for @catalogSetupArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String catalogSetupArchiveTitle(String name);

  /// No description provided for @catalogSetupArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Archived records can be restored later. Existing Product assignments follow the system’s current rules.'**
  String get catalogSetupArchiveHelp;

  /// No description provided for @catalogSetupValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name to continue.'**
  String get catalogSetupValidationRequired;

  /// No description provided for @catalogSetupRefreshInProgress.
  ///
  /// In en, this message translates to:
  /// **'Refreshing catalog setup'**
  String get catalogSetupRefreshInProgress;

  /// No description provided for @menuListTitle.
  ///
  /// In en, this message translates to:
  /// **'Menus'**
  String get menuListTitle;

  /// No description provided for @menuListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create and organize the menus customers can order from.'**
  String get menuListSubtitle;

  /// No description provided for @menuListAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Menu'**
  String get menuListAdd;

  /// No description provided for @menuListSearch.
  ///
  /// In en, this message translates to:
  /// **'Search menus...'**
  String get menuListSearch;

  /// No description provided for @menuListStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get menuListStatus;

  /// No description provided for @menuListSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get menuListSort;

  /// No description provided for @menuListDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get menuListDirection;

  /// No description provided for @menuListRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh menus'**
  String get menuListRefresh;

  /// No description provided for @menuListMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuListMenu;

  /// No description provided for @menuListSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get menuListSections;

  /// No description provided for @menuListVisibleProducts.
  ///
  /// In en, this message translates to:
  /// **'Visible Products'**
  String get menuListVisibleProducts;

  /// No description provided for @menuListLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get menuListLastUpdated;

  /// No description provided for @menuListActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get menuListActions;

  /// No description provided for @menuListOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get menuListOpen;

  /// No description provided for @menuListClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get menuListClearFilters;

  /// No description provided for @menuListNoMenusYet.
  ///
  /// In en, this message translates to:
  /// **'No menus yet'**
  String get menuListNoMenusYet;

  /// No description provided for @menuListNoMenusHelp.
  ///
  /// In en, this message translates to:
  /// **'Create your first Menu and start organizing Products into Sections.'**
  String get menuListNoMenusHelp;

  /// No description provided for @menuListNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No menus match these filters.'**
  String get menuListNoMatches;

  /// No description provided for @menuListNoMatchesHelp.
  ///
  /// In en, this message translates to:
  /// **'Try changing the search or status filter.'**
  String get menuListNoMatchesHelp;

  /// No description provided for @menuListCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load menus'**
  String get menuListCouldNotLoad;

  /// No description provided for @menuListCouldNotLoadHelp.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get menuListCouldNotLoadHelp;

  /// No description provided for @menuListLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get menuListLoadMore;

  /// No description provided for @menuListArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive menu?'**
  String get menuListArchiveTitle;

  /// No description provided for @menuListArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'The menu can be restored later. Existing orders and published versions are unchanged.'**
  String get menuListArchiveHelp;

  /// No description provided for @menuListRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore menu?'**
  String get menuListRestoreTitle;

  /// No description provided for @menuListRestoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Restoring makes the menu editable again. It does not publish the menu.'**
  String get menuListRestoreHelp;

  /// No description provided for @menuListActionsFor.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String menuListActionsFor(String name);

  /// No description provided for @menuListPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get menuListPaused;

  /// No description provided for @menuListPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get menuListPriority;

  /// No description provided for @menuListName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get menuListName;

  /// No description provided for @menuListCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get menuListCreated;

  /// No description provided for @menuListUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get menuListUpdated;

  /// No description provided for @menuListAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get menuListAscending;

  /// No description provided for @menuListDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get menuListDescending;

  /// No description provided for @menuListAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get menuListAll;

  /// No description provided for @menuListDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get menuListDraft;

  /// No description provided for @menuListActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get menuListActive;

  /// No description provided for @menuListArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get menuListArchived;

  /// No description provided for @menuListEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuListEdit;

  /// No description provided for @menuListArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get menuListArchive;

  /// No description provided for @menuListRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get menuListRestore;

  /// No description provided for @menuListCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get menuListCancel;

  /// No description provided for @menuListRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get menuListRetry;

  /// No description provided for @menuEditorAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Menu'**
  String get menuEditorAddTitle;

  /// No description provided for @menuEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Menu'**
  String get menuEditorEditTitle;

  /// No description provided for @menuEditorAddHelp.
  ///
  /// In en, this message translates to:
  /// **'Start with the names your staff and customers recognize.'**
  String get menuEditorAddHelp;

  /// No description provided for @menuEditorEditHelp.
  ///
  /// In en, this message translates to:
  /// **'Update the menu identity without leaving this workspace.'**
  String get menuEditorEditHelp;

  /// No description provided for @menuEditorClose.
  ///
  /// In en, this message translates to:
  /// **'Close menu editor'**
  String get menuEditorClose;

  /// No description provided for @menuEditorEnglishName.
  ///
  /// In en, this message translates to:
  /// **'English Name'**
  String get menuEditorEnglishName;

  /// No description provided for @menuEditorArabicName.
  ///
  /// In en, this message translates to:
  /// **'Arabic Name'**
  String get menuEditorArabicName;

  /// No description provided for @menuEditorMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get menuEditorMoreDetails;

  /// No description provided for @menuEditorHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get menuEditorHideDetails;

  /// No description provided for @menuEditorEnglishDescription.
  ///
  /// In en, this message translates to:
  /// **'English Description'**
  String get menuEditorEnglishDescription;

  /// No description provided for @menuEditorArabicDescription.
  ///
  /// In en, this message translates to:
  /// **'Arabic Description'**
  String get menuEditorArabicDescription;

  /// No description provided for @menuEditorCoverImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Cover image URL'**
  String get menuEditorCoverImageUrl;

  /// No description provided for @menuEditorPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get menuEditorPriority;

  /// No description provided for @menuEditorPriorityHelp.
  ///
  /// In en, this message translates to:
  /// **'Controls the ordering when menus are shown together.'**
  String get menuEditorPriorityHelp;

  /// No description provided for @menuEditorStatus.
  ///
  /// In en, this message translates to:
  /// **'Menu status'**
  String get menuEditorStatus;

  /// No description provided for @menuEditorCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Menu'**
  String get menuEditorCreate;

  /// No description provided for @menuEditorSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get menuEditorSaveChanges;

  /// No description provided for @menuEditorDraftHelp.
  ///
  /// In en, this message translates to:
  /// **'New menus start as Draft. You can activate them later.'**
  String get menuEditorDraftHelp;

  /// No description provided for @menuEditorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an English or Arabic name to continue.'**
  String get menuEditorNameRequired;

  /// No description provided for @menuEditorPriorityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number for priority.'**
  String get menuEditorPriorityInvalid;

  /// No description provided for @menuEditorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t save this menu. Please try again.'**
  String get menuEditorSaveFailed;

  /// No description provided for @menuEditorArchivedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Archived menus are read-only. Restore this menu before editing it.'**
  String get menuEditorArchivedReadOnly;

  /// No description provided for @menuEditorStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get menuEditorStatusDraft;

  /// No description provided for @menuEditorStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get menuEditorStatusActive;

  /// No description provided for @menuEditorStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get menuEditorStatusPaused;

  /// No description provided for @menuEditorStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get menuEditorStatusArchived;

  /// No description provided for @menuOverviewEditMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit Menu'**
  String get menuOverviewEditMenu;

  /// No description provided for @menuOverviewActions.
  ///
  /// In en, this message translates to:
  /// **'Menu actions'**
  String get menuOverviewActions;

  /// No description provided for @menuOverviewTab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get menuOverviewTab;

  /// No description provided for @menuOverviewSectionsTab.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get menuOverviewSectionsTab;

  /// No description provided for @menuOverviewProductsTab.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get menuOverviewProductsTab;

  /// No description provided for @menuOverviewWorkspaceTabs.
  ///
  /// In en, this message translates to:
  /// **'Menu workspace tabs'**
  String get menuOverviewWorkspaceTabs;

  /// No description provided for @menuOverviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Menu details'**
  String get menuOverviewDetails;

  /// No description provided for @menuOverviewName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get menuOverviewName;

  /// No description provided for @menuOverviewStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get menuOverviewStatus;

  /// No description provided for @menuOverviewComposition.
  ///
  /// In en, this message translates to:
  /// **'Composition'**
  String get menuOverviewComposition;

  /// No description provided for @menuOverviewManageSections.
  ///
  /// In en, this message translates to:
  /// **'Manage Sections'**
  String get menuOverviewManageSections;

  /// No description provided for @menuOverviewManageProducts.
  ///
  /// In en, this message translates to:
  /// **'Manage Products'**
  String get menuOverviewManageProducts;

  /// No description provided for @menuOverviewCompositionValue.
  ///
  /// In en, this message translates to:
  /// **'{sectionCount} Sections · {visibleProductCount} visible Products'**
  String menuOverviewCompositionValue(
    int sectionCount,
    int visibleProductCount,
  );

  /// No description provided for @menuOverviewDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get menuOverviewDraft;

  /// No description provided for @menuOverviewActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get menuOverviewActive;

  /// No description provided for @menuOverviewPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get menuOverviewPaused;

  /// No description provided for @menuOverviewArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get menuOverviewArchived;

  /// No description provided for @menuOverviewArchivedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This menu is archived and read-only. Restore it before changing its composition.'**
  String get menuOverviewArchivedReadOnly;

  /// No description provided for @menuOverviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading menu workspace'**
  String get menuOverviewLoading;

  /// No description provided for @menuOverviewCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this menu'**
  String get menuOverviewCouldNotLoad;

  /// No description provided for @menuOverviewArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get menuOverviewArchive;

  /// No description provided for @menuOverviewRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get menuOverviewRestore;

  /// No description provided for @menuSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get menuSectionsTitle;

  /// No description provided for @menuSectionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Organize this menu into customer-friendly groups.'**
  String get menuSectionsHelp;

  /// No description provided for @menuSectionsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Section'**
  String get menuSectionsAdd;

  /// No description provided for @menuSectionsReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder Sections'**
  String get menuSectionsReorder;

  /// No description provided for @menuSectionsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get menuSectionsDone;

  /// No description provided for @menuSectionsReorderHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the arrows to change the order customers see.'**
  String get menuSectionsReorderHelp;

  /// No description provided for @menuSectionsProducts.
  ///
  /// In en, this message translates to:
  /// **'{count} Products'**
  String menuSectionsProducts(int count);

  /// No description provided for @menuSectionsArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get menuSectionsArchived;

  /// No description provided for @menuSectionsInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get menuSectionsInactive;

  /// No description provided for @menuSectionsActions.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String menuSectionsActions(String name);

  /// No description provided for @menuSectionsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuSectionsEdit;

  /// No description provided for @menuSectionsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get menuSectionsArchive;

  /// No description provided for @menuSectionsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get menuSectionsRestore;

  /// No description provided for @menuSectionsMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get menuSectionsMoveUp;

  /// No description provided for @menuSectionsMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get menuSectionsMoveDown;

  /// No description provided for @menuSectionsNoSections.
  ///
  /// In en, this message translates to:
  /// **'No Sections yet'**
  String get menuSectionsNoSections;

  /// No description provided for @menuSectionsEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'Create a Section before adding Products.'**
  String get menuSectionsEmptyHelp;

  /// No description provided for @menuSectionsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load Sections'**
  String get menuSectionsLoadError;

  /// No description provided for @menuSectionEditorAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Section'**
  String get menuSectionEditorAddTitle;

  /// No description provided for @menuSectionEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Section'**
  String get menuSectionEditorEditTitle;

  /// No description provided for @menuSectionEditorAddHelp.
  ///
  /// In en, this message translates to:
  /// **'Create a clear group customers can browse.'**
  String get menuSectionEditorAddHelp;

  /// No description provided for @menuSectionEditorEditHelp.
  ///
  /// In en, this message translates to:
  /// **'Update this group without leaving the menu workspace.'**
  String get menuSectionEditorEditHelp;

  /// No description provided for @menuSectionEditorClose.
  ///
  /// In en, this message translates to:
  /// **'Close Section editor'**
  String get menuSectionEditorClose;

  /// No description provided for @menuSectionEditorEnglishName.
  ///
  /// In en, this message translates to:
  /// **'English Name'**
  String get menuSectionEditorEnglishName;

  /// No description provided for @menuSectionEditorArabicName.
  ///
  /// In en, this message translates to:
  /// **'Arabic Name'**
  String get menuSectionEditorArabicName;

  /// No description provided for @menuSectionEditorMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get menuSectionEditorMoreDetails;

  /// No description provided for @menuSectionEditorHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get menuSectionEditorHideDetails;

  /// No description provided for @menuSectionEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get menuSectionEditorDescription;

  /// No description provided for @menuSectionEditorImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get menuSectionEditorImageUrl;

  /// No description provided for @menuSectionEditorActive.
  ///
  /// In en, this message translates to:
  /// **'Active Section'**
  String get menuSectionEditorActive;

  /// No description provided for @menuSectionEditorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an English or Arabic name to continue.'**
  String get menuSectionEditorNameRequired;

  /// No description provided for @menuSectionEditorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save this Section. Check the fields and try again.'**
  String get menuSectionEditorSaveFailed;

  /// No description provided for @menuSectionEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get menuSectionEditorSave;

  /// No description provided for @menuProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get menuProductsTitle;

  /// No description provided for @menuProductsHelp.
  ///
  /// In en, this message translates to:
  /// **'Organize the Products customers see inside each Section.'**
  String get menuProductsHelp;

  /// No description provided for @menuProductsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Products'**
  String get menuProductsAdd;

  /// No description provided for @menuProductsReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder Products'**
  String get menuProductsReorder;

  /// No description provided for @menuProductsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get menuProductsDone;

  /// No description provided for @menuProductsReorderHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the arrows to set the order customers see within each Section.'**
  String get menuProductsReorderHelp;

  /// No description provided for @menuProductsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Products in this Menu'**
  String get menuProductsSearchHint;

  /// No description provided for @menuProductsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Products'**
  String menuProductsCount(int count);

  /// No description provided for @menuProductsPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Products'**
  String get menuProductsPickerTitle;

  /// No description provided for @menuProductsPickerTargetSection.
  ///
  /// In en, this message translates to:
  /// **'Add to Section'**
  String get menuProductsPickerTargetSection;

  /// No description provided for @menuProductsPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Products...'**
  String get menuProductsPickerSearchHint;

  /// No description provided for @menuProductsPickerAlreadyInSection.
  ///
  /// In en, this message translates to:
  /// **'Already in {section}'**
  String menuProductsPickerAlreadyInSection(String section);

  /// No description provided for @menuProductsPickerSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String menuProductsPickerSelected(int count);

  /// No description provided for @menuProductsPickerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No Products match your search.'**
  String get menuProductsPickerNoMatches;

  /// No description provided for @menuProductsPickerNoEligible.
  ///
  /// In en, this message translates to:
  /// **'All available Products are already in this Section.'**
  String get menuProductsPickerNoEligible;

  /// No description provided for @menuProductsPickerLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load Products.'**
  String get menuProductsPickerLoadError;

  /// No description provided for @menuProductsPickerPartialAdded.
  ///
  /// In en, this message translates to:
  /// **'{added} Products were added. {failed} could not be added.'**
  String menuProductsPickerPartialAdded(int added, int failed);

  /// No description provided for @menuProductsPickerConflict.
  ///
  /// In en, this message translates to:
  /// **'This Product is already in {section}.'**
  String menuProductsPickerConflict(String section);

  /// No description provided for @menuProductsBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base {price}'**
  String menuProductsBasePrice(String price);

  /// No description provided for @menuProductsFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get menuProductsFeatured;

  /// No description provided for @menuProductsHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get menuProductsHidden;

  /// No description provided for @menuProductsArchivedPlacement.
  ///
  /// In en, this message translates to:
  /// **'Removed from Menu'**
  String get menuProductsArchivedPlacement;

  /// No description provided for @menuProductsArchivedProduct.
  ///
  /// In en, this message translates to:
  /// **'Archived Product'**
  String get menuProductsArchivedProduct;

  /// No description provided for @menuProductsInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get menuProductsInactive;

  /// No description provided for @menuProductsActions.
  ///
  /// In en, this message translates to:
  /// **'Product actions'**
  String get menuProductsActions;

  /// No description provided for @menuProductsMarkFeatured.
  ///
  /// In en, this message translates to:
  /// **'Mark Featured'**
  String get menuProductsMarkFeatured;

  /// No description provided for @menuProductsRemoveFeatured.
  ///
  /// In en, this message translates to:
  /// **'Remove Featured'**
  String get menuProductsRemoveFeatured;

  /// No description provided for @menuProductsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide from Menu'**
  String get menuProductsHide;

  /// No description provided for @menuProductsShow.
  ///
  /// In en, this message translates to:
  /// **'Show on Menu'**
  String get menuProductsShow;

  /// No description provided for @menuProductsMove.
  ///
  /// In en, this message translates to:
  /// **'Move to Section'**
  String get menuProductsMove;

  /// No description provided for @menuProductsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from Menu'**
  String get menuProductsRemove;

  /// No description provided for @menuProductsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Placement'**
  String get menuProductsRestore;

  /// No description provided for @menuProductsMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get menuProductsMoveUp;

  /// No description provided for @menuProductsMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get menuProductsMoveDown;

  /// No description provided for @menuProductsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Products in this Section yet.'**
  String get menuProductsEmpty;

  /// No description provided for @menuProductsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching Products in this Section.'**
  String get menuProductsNoMatches;

  /// No description provided for @menuProductsNoSections.
  ///
  /// In en, this message translates to:
  /// **'No Sections yet'**
  String get menuProductsNoSections;

  /// No description provided for @menuProductsNoSectionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Create a Section before adding Products.'**
  String get menuProductsNoSectionsHelp;

  /// No description provided for @menuProductsArchivedMenuReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This menu is archived and read-only. Its composition remains available to review.'**
  String get menuProductsArchivedMenuReadOnly;

  /// No description provided for @menuProductsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load Products'**
  String get menuProductsLoadError;

  /// No description provided for @menuProductsRemoveHelp.
  ///
  /// In en, this message translates to:
  /// **'This removes the Product from this Section and Menu only. The Product remains in the Catalog.'**
  String get menuProductsRemoveHelp;

  /// No description provided for @menuProductsRestoreHelp.
  ///
  /// In en, this message translates to:
  /// **'This restores this Placement only. It does not restore or reactivate the Product.'**
  String get menuProductsRestoreHelp;

  /// No description provided for @assignmentsWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Assignments & Schedules'**
  String get assignmentsWorkspaceTitle;

  /// No description provided for @assignmentsWorkspaceHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a Branch and sales channel, then control which Menus are available in that selling context.'**
  String get assignmentsWorkspaceHelp;

  /// No description provided for @assignmentsBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get assignmentsBranch;

  /// No description provided for @assignmentsSalesChannel.
  ///
  /// In en, this message translates to:
  /// **'Sales Channel'**
  String get assignmentsSalesChannel;

  /// No description provided for @assignmentsTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get assignmentsTimezone;

  /// No description provided for @assignmentsChooseBranch.
  ///
  /// In en, this message translates to:
  /// **'Choose a Branch'**
  String get assignmentsChooseBranch;

  /// No description provided for @assignmentsChooseChannel.
  ///
  /// In en, this message translates to:
  /// **'Choose a sales channel'**
  String get assignmentsChooseChannel;

  /// No description provided for @assignmentsTimezonePending.
  ///
  /// In en, this message translates to:
  /// **'Select a Branch'**
  String get assignmentsTimezonePending;

  /// No description provided for @assignmentsNoContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a selling context'**
  String get assignmentsNoContextTitle;

  /// No description provided for @assignmentsNoContextHelp.
  ///
  /// In en, this message translates to:
  /// **'Select a Branch and sales channel to manage its Menus.'**
  String get assignmentsNoContextHelp;

  /// No description provided for @assignmentsAssignedMenus.
  ///
  /// In en, this message translates to:
  /// **'Assigned Menus'**
  String get assignmentsAssignedMenus;

  /// No description provided for @assignmentsMenuCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Menus assigned'**
  String assignmentsMenuCount(int count);

  /// No description provided for @assignmentsReorderMenus.
  ///
  /// In en, this message translates to:
  /// **'Reorder Menus'**
  String get assignmentsReorderMenus;

  /// No description provided for @assignmentsReorderHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the arrows to change the order Menus appear in this selling context. Ordering does not decide which Menu wins.'**
  String get assignmentsReorderHelp;

  /// No description provided for @assignmentsReorderDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get assignmentsReorderDone;

  /// No description provided for @assignmentsMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get assignmentsMoveUp;

  /// No description provided for @assignmentsMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get assignmentsMoveDown;

  /// No description provided for @assignmentsReorderSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save this Menu order. Try again.'**
  String get assignmentsReorderSaveFailed;

  /// No description provided for @assignmentsReorderArchivedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reordering is unavailable while this selling context contains an archived Menu. Remove the archived assignment first.'**
  String get assignmentsReorderArchivedUnavailable;

  /// No description provided for @assignmentsAddMenus.
  ///
  /// In en, this message translates to:
  /// **'Add Menus'**
  String get assignmentsAddMenus;

  /// No description provided for @assignmentsNoMenusTitle.
  ///
  /// In en, this message translates to:
  /// **'No Menus assigned'**
  String get assignmentsNoMenusTitle;

  /// No description provided for @assignmentsNoMenusHelp.
  ///
  /// In en, this message translates to:
  /// **'Add a Menu to {branch} · {channel}.'**
  String assignmentsNoMenusHelp(String branch, String channel);

  /// No description provided for @assignmentsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load assignments'**
  String get assignmentsLoadErrorTitle;

  /// No description provided for @assignmentsLifecycle.
  ///
  /// In en, this message translates to:
  /// **'Menu: {status}'**
  String assignmentsLifecycle(String status);

  /// No description provided for @assignmentsPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get assignmentsPaused;

  /// No description provided for @assignmentsActive.
  ///
  /// In en, this message translates to:
  /// **'Assignment Active'**
  String get assignmentsActive;

  /// No description provided for @assignmentsInactive.
  ///
  /// In en, this message translates to:
  /// **'Assignment Inactive'**
  String get assignmentsInactive;

  /// No description provided for @assignmentsAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get assignmentsAvailableNow;

  /// No description provided for @assignmentsOutsideHours.
  ///
  /// In en, this message translates to:
  /// **'Outside scheduled hours'**
  String get assignmentsOutsideHours;

  /// No description provided for @assignmentsNoScheduleRestriction.
  ///
  /// In en, this message translates to:
  /// **'No schedule restriction'**
  String get assignmentsNoScheduleRestriction;

  /// No description provided for @assignmentsScheduleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Schedule status unavailable'**
  String get assignmentsScheduleUnknown;

  /// No description provided for @assignmentsManageSchedule.
  ///
  /// In en, this message translates to:
  /// **'Manage Schedule'**
  String get assignmentsManageSchedule;

  /// No description provided for @assignmentsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from this selling context'**
  String get assignmentsRemove;

  /// No description provided for @assignmentsArchivedDiagnostic.
  ///
  /// In en, this message translates to:
  /// **'Archived Menu — actions unavailable'**
  String get assignmentsArchivedDiagnostic;

  /// No description provided for @assignmentsChannelWaiterApp.
  ///
  /// In en, this message translates to:
  /// **'Waiter App'**
  String get assignmentsChannelWaiterApp;

  /// No description provided for @assignmentsChannelKiosk.
  ///
  /// In en, this message translates to:
  /// **'Kiosk'**
  String get assignmentsChannelKiosk;

  /// No description provided for @assignmentsChannelQrOrdering.
  ///
  /// In en, this message translates to:
  /// **'QR Ordering'**
  String get assignmentsChannelQrOrdering;

  /// No description provided for @assignmentsChannelDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get assignmentsChannelDelivery;

  /// No description provided for @assignmentsChannelOnlineOrdering.
  ///
  /// In en, this message translates to:
  /// **'Online Ordering'**
  String get assignmentsChannelOnlineOrdering;

  /// No description provided for @assignmentsMenuFallback.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get assignmentsMenuFallback;

  /// No description provided for @assignmentsAddSearch.
  ///
  /// In en, this message translates to:
  /// **'Search Menus'**
  String get assignmentsAddSearch;

  /// No description provided for @assignmentsAddEmpty.
  ///
  /// In en, this message translates to:
  /// **'All available Menus are already assigned to this selling context.'**
  String get assignmentsAddEmpty;

  /// No description provided for @assignmentsAddSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String assignmentsAddSelected(int count);

  /// No description provided for @assignmentsAddSelectedAction.
  ///
  /// In en, this message translates to:
  /// **'Add {count} Menus'**
  String assignmentsAddSelectedAction(int count);

  /// No description provided for @assignmentsAddAlreadyAssigned.
  ///
  /// In en, this message translates to:
  /// **'Already assigned'**
  String get assignmentsAddAlreadyAssigned;

  /// No description provided for @assignmentsAddArchivedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Archived Menus can’t be assigned.'**
  String get assignmentsAddArchivedUnavailable;

  /// No description provided for @assignmentsAddNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No Menus match your search.'**
  String get assignmentsAddNoMatches;

  /// No description provided for @assignmentsAddLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load Menus'**
  String get assignmentsAddLoadError;

  /// No description provided for @assignmentsAddSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t add Menus. Try again.'**
  String get assignmentsAddSaveError;

  /// No description provided for @assignmentsAddDuplicateError.
  ///
  /// In en, this message translates to:
  /// **'One or more Menus are already assigned to this selling context.'**
  String get assignmentsAddDuplicateError;

  /// No description provided for @assignmentsAddArchivedScopeError.
  ///
  /// In en, this message translates to:
  /// **'Adding Menus is unavailable while this selling context contains an archived Menu. Remove the archived assignment first.'**
  String get assignmentsAddArchivedScopeError;

  /// No description provided for @menuScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu Schedule'**
  String get menuScheduleTitle;

  /// No description provided for @menuScheduleTimesShownIn.
  ///
  /// In en, this message translates to:
  /// **'Times shown in {timezone}'**
  String menuScheduleTimesShownIn(String timezone);

  /// No description provided for @menuScheduleUsingBroader.
  ///
  /// In en, this message translates to:
  /// **'Using broader Menu schedule'**
  String get menuScheduleUsingBroader;

  /// No description provided for @menuScheduleCustomizedFor.
  ///
  /// In en, this message translates to:
  /// **'Customized for {context}'**
  String menuScheduleCustomizedFor(String context);

  /// No description provided for @menuScheduleCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize for this context'**
  String get menuScheduleCustomize;

  /// No description provided for @menuScheduleUseBroader.
  ///
  /// In en, this message translates to:
  /// **'Use broader schedule'**
  String get menuScheduleUseBroader;

  /// No description provided for @menuScheduleAvailableAllDay.
  ///
  /// In en, this message translates to:
  /// **'Available all day'**
  String get menuScheduleAvailableAllDay;

  /// No description provided for @menuScheduleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get menuScheduleUnavailable;

  /// No description provided for @menuScheduleCustomHours.
  ///
  /// In en, this message translates to:
  /// **'Custom hours'**
  String get menuScheduleCustomHours;

  /// No description provided for @menuScheduleStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get menuScheduleStartTime;

  /// No description provided for @menuScheduleEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get menuScheduleEndTime;

  /// No description provided for @menuScheduleEditDay.
  ///
  /// In en, this message translates to:
  /// **'Edit {day}'**
  String menuScheduleEditDay(String day);

  /// No description provided for @menuScheduleSaveDay.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get menuScheduleSaveDay;

  /// No description provided for @menuScheduleSave.
  ///
  /// In en, this message translates to:
  /// **'Save Schedule'**
  String get menuScheduleSave;

  /// No description provided for @menuScheduleLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load Menu schedule'**
  String get menuScheduleLoadError;

  /// No description provided for @menuScheduleSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save Menu schedule. Try again.'**
  String get menuScheduleSaveError;

  /// No description provided for @menuScheduleMultipleWindows.
  ///
  /// In en, this message translates to:
  /// **'{count} time windows'**
  String menuScheduleMultipleWindows(int count);

  /// No description provided for @menuScheduleMultipleWindowsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This day has multiple time windows. They are preserved and can be edited in the advanced schedule later.'**
  String get menuScheduleMultipleWindowsReadOnly;

  /// No description provided for @menuScheduleUnavailableNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This day uses an Every Day rule. Keep it unchanged until advanced scheduling is available.'**
  String get menuScheduleUnavailableNotSupported;

  /// No description provided for @menuScheduleInvalidTimes.
  ///
  /// In en, this message translates to:
  /// **'Enter two different times in HH:mm format.'**
  String get menuScheduleInvalidTimes;

  /// No description provided for @menuScheduleMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get menuScheduleMonday;

  /// No description provided for @menuScheduleTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get menuScheduleTuesday;

  /// No description provided for @menuScheduleWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get menuScheduleWednesday;

  /// No description provided for @menuScheduleThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get menuScheduleThursday;

  /// No description provided for @menuScheduleFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get menuScheduleFriday;

  /// No description provided for @menuScheduleSaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get menuScheduleSaturday;

  /// No description provided for @menuScheduleSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get menuScheduleSunday;

  /// No description provided for @menuScheduleMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More schedule options'**
  String get menuScheduleMoreOptions;

  /// No description provided for @menuScheduleDateLimits.
  ///
  /// In en, this message translates to:
  /// **'Date limits'**
  String get menuScheduleDateLimits;

  /// No description provided for @menuScheduleStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date (optional)'**
  String get menuScheduleStartDate;

  /// No description provided for @menuScheduleEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date (optional)'**
  String get menuScheduleEndDate;

  /// No description provided for @menuScheduleAddTimeWindow.
  ///
  /// In en, this message translates to:
  /// **'Add time window'**
  String get menuScheduleAddTimeWindow;

  /// No description provided for @menuScheduleOvernightUntil.
  ///
  /// In en, this message translates to:
  /// **'Overnight — available until {time} the next day'**
  String menuScheduleOvernightUntil(String time);

  /// No description provided for @menuScheduleEveryDayReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This rule applies every day. It is kept as-is so its schedule meaning is preserved.'**
  String get menuScheduleEveryDayReadOnly;

  /// No description provided for @menuScheduleCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Schedule'**
  String get menuScheduleCheckTitle;

  /// No description provided for @menuScheduleDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get menuScheduleDate;

  /// No description provided for @menuScheduleTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get menuScheduleTime;

  /// No description provided for @menuScheduleCheckTimezone.
  ///
  /// In en, this message translates to:
  /// **'Times evaluated in {timezone}'**
  String menuScheduleCheckTimezone(String timezone);

  /// No description provided for @menuScheduleCheckSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Save schedule changes before checking the saved schedule.'**
  String get menuScheduleCheckSaveFirst;

  /// No description provided for @menuScheduleCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check the schedule. Try again.'**
  String get menuScheduleCheckFailed;

  /// No description provided for @menuScheduleInvalidDateRange.
  ///
  /// In en, this message translates to:
  /// **'End date must be on or after the start date.'**
  String get menuScheduleInvalidDateRange;

  /// No description provided for @menuScheduleDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard schedule changes?'**
  String get menuScheduleDiscardTitle;

  /// No description provided for @menuScheduleDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your schedule changes have not been saved.'**
  String get menuScheduleDiscardMessage;

  /// No description provided for @menuScheduleDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get menuScheduleDiscard;

  /// No description provided for @menuScheduleCustomizeDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize {day}'**
  String menuScheduleCustomizeDayTitle(String day);

  /// No description provided for @menuScheduleCustomizeDayMessage.
  ///
  /// In en, this message translates to:
  /// **'This schedule currently applies to every day. Customizing one day will keep the same schedule for the other days and let you change that day separately.'**
  String get menuScheduleCustomizeDayMessage;

  /// No description provided for @menuScheduleCustomizeDayAction.
  ///
  /// In en, this message translates to:
  /// **'Customize {day}'**
  String menuScheduleCustomizeDayAction(String day);

  /// No description provided for @menuScheduleDateLimitsMixed.
  ///
  /// In en, this message translates to:
  /// **'These rules have different date limits. Date limits are left unchanged here so this editor does not overwrite them.'**
  String get menuScheduleDateLimitsMixed;

  /// No description provided for @menuListNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get menuListNotAvailable;

  /// No description provided for @reviewPublishPageHelp.
  ///
  /// In en, this message translates to:
  /// **'Review Menu readiness, preview the selling experience, and publish a version for this selling context.'**
  String get reviewPublishPageHelp;

  /// No description provided for @reviewSellingContext.
  ///
  /// In en, this message translates to:
  /// **'Selling Context'**
  String get reviewSellingContext;

  /// No description provided for @reviewSellingContextHelp.
  ///
  /// In en, this message translates to:
  /// **'This review covers the Menus assigned to the selected selling context.'**
  String get reviewSellingContextHelp;

  /// No description provided for @reviewBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get reviewBranch;

  /// No description provided for @reviewSalesChannel.
  ///
  /// In en, this message translates to:
  /// **'Sales Channel'**
  String get reviewSalesChannel;

  /// No description provided for @reviewTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get reviewTimezone;

  /// No description provided for @reviewScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get reviewScope;

  /// No description provided for @reviewScopeAssignedMenus.
  ///
  /// In en, this message translates to:
  /// **'Menus assigned to this context'**
  String get reviewScopeAssignedMenus;

  /// No description provided for @reviewReadinessTab.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get reviewReadinessTab;

  /// No description provided for @reviewPreviewTab.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get reviewPreviewTab;

  /// No description provided for @reviewPublishTab.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get reviewPublishTab;

  /// No description provided for @reviewVersionsTab.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get reviewVersionsTab;

  /// No description provided for @reviewCurrentlyPublished.
  ///
  /// In en, this message translates to:
  /// **'Currently Published'**
  String get reviewCurrentlyPublished;

  /// No description provided for @reviewNotPublishedYet.
  ///
  /// In en, this message translates to:
  /// **'Not published yet'**
  String get reviewNotPublishedYet;

  /// No description provided for @reviewNoCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'No Menu version has been published for this selling context.'**
  String get reviewNoCurrentVersion;

  /// No description provided for @reviewCurrentVersionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the current published version.'**
  String get reviewCurrentVersionLoadError;

  /// No description provided for @reviewVersionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String reviewVersionNumber(int version);

  /// No description provided for @reviewPublishedAt.
  ///
  /// In en, this message translates to:
  /// **'Published {date}'**
  String reviewPublishedAt(String date);

  /// No description provided for @reviewViewVersions.
  ///
  /// In en, this message translates to:
  /// **'View Versions'**
  String get reviewViewVersions;

  /// No description provided for @reviewReadiness.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get reviewReadiness;

  /// No description provided for @reviewReadinessHelp.
  ///
  /// In en, this message translates to:
  /// **'Review the authoritative validation for this selling context.'**
  String get reviewReadinessHelp;

  /// No description provided for @reviewCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check Again'**
  String get reviewCheckAgain;

  /// No description provided for @reviewNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get reviewNeedsAttention;

  /// No description provided for @reviewReadyToPublish.
  ///
  /// In en, this message translates to:
  /// **'Ready to Publish'**
  String get reviewReadyToPublish;

  /// No description provided for @reviewFixBlockingErrors.
  ///
  /// In en, this message translates to:
  /// **'Fix the blocking errors before publishing.'**
  String get reviewFixBlockingErrors;

  /// No description provided for @reviewErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get reviewErrors;

  /// No description provided for @reviewWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get reviewWarnings;

  /// No description provided for @reviewWarningsToReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning to review.} other{{count} warnings to review.}}'**
  String reviewWarningsToReview(num count);

  /// No description provided for @reviewNoIssuesForScope.
  ///
  /// In en, this message translates to:
  /// **'No issues found for {branch} · {channel}.'**
  String reviewNoIssuesForScope(String branch, String channel);

  /// No description provided for @reviewNoMenusAssigned.
  ///
  /// In en, this message translates to:
  /// **'No Menus assigned'**
  String get reviewNoMenusAssigned;

  /// No description provided for @reviewNoMenusAssignedHelp.
  ///
  /// In en, this message translates to:
  /// **'Assign at least one active Menu to {branch} · {channel} before publishing.'**
  String reviewNoMenusAssignedHelp(String branch, String channel);

  /// No description provided for @reviewGoToAssignments.
  ///
  /// In en, this message translates to:
  /// **'Go to Assignments'**
  String get reviewGoToAssignments;

  /// No description provided for @reviewReadinessLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load readiness results.'**
  String get reviewReadinessLoadError;

  /// No description provided for @reviewTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again.'**
  String get reviewTryAgain;

  /// No description provided for @reviewIssuesAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reviewIssuesAll;

  /// No description provided for @reviewSearchIssues.
  ///
  /// In en, this message translates to:
  /// **'Search issues...'**
  String get reviewSearchIssues;

  /// No description provided for @reviewNoMatchingIssues.
  ///
  /// In en, this message translates to:
  /// **'No matching issues'**
  String get reviewNoMatchingIssues;

  /// No description provided for @reviewTryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get reviewTryDifferentSearch;

  /// No description provided for @reviewIssueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 issue} other{{count} issues}}'**
  String reviewIssueCount(num count);

  /// No description provided for @reviewIssueGroupMenus.
  ///
  /// In en, this message translates to:
  /// **'Menus'**
  String get reviewIssueGroupMenus;

  /// No description provided for @reviewIssueGroupSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get reviewIssueGroupSections;

  /// No description provided for @reviewIssueGroupProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get reviewIssueGroupProducts;

  /// No description provided for @reviewIssueGroupVariants.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get reviewIssueGroupVariants;

  /// No description provided for @reviewIssueGroupRecipesMaterials.
  ///
  /// In en, this message translates to:
  /// **'Recipes & Materials'**
  String get reviewIssueGroupRecipesMaterials;

  /// No description provided for @reviewIssueGroupModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get reviewIssueGroupModifiers;

  /// No description provided for @reviewIssueGroupPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get reviewIssueGroupPricing;

  /// No description provided for @reviewIssueGroupAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get reviewIssueGroupAvailability;

  /// No description provided for @reviewIssueGroupAssignmentsScope.
  ///
  /// In en, this message translates to:
  /// **'Assignments / Scope'**
  String get reviewIssueGroupAssignmentsScope;

  /// No description provided for @reviewIssueGroupOther.
  ///
  /// In en, this message translates to:
  /// **'Other / General'**
  String get reviewIssueGroupOther;

  /// No description provided for @reviewIssueGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get reviewIssueGeneral;

  /// No description provided for @reviewOpenMenu.
  ///
  /// In en, this message translates to:
  /// **'Open Menu'**
  String get reviewOpenMenu;

  /// No description provided for @reviewOpenProduct.
  ///
  /// In en, this message translates to:
  /// **'Open Product'**
  String get reviewOpenProduct;

  /// No description provided for @reviewOpenSections.
  ///
  /// In en, this message translates to:
  /// **'Open Sections'**
  String get reviewOpenSections;

  /// No description provided for @reviewReviewMenu.
  ///
  /// In en, this message translates to:
  /// **'Review Menu'**
  String get reviewReviewMenu;

  /// No description provided for @reviewIssueContextMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu issue'**
  String get reviewIssueContextMenu;

  /// No description provided for @reviewIssueContextSection.
  ///
  /// In en, this message translates to:
  /// **'Section issue'**
  String get reviewIssueContextSection;

  /// No description provided for @reviewIssueContextProduct.
  ///
  /// In en, this message translates to:
  /// **'Product issue'**
  String get reviewIssueContextProduct;

  /// No description provided for @reviewIssueContextVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant issue'**
  String get reviewIssueContextVariant;

  /// No description provided for @reviewIssueContextPlacement.
  ///
  /// In en, this message translates to:
  /// **'Menu placement issue'**
  String get reviewIssueContextPlacement;

  /// No description provided for @reviewIssueContextModifier.
  ///
  /// In en, this message translates to:
  /// **'Modifier issue'**
  String get reviewIssueContextModifier;

  /// No description provided for @reviewIssueContextRecipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe or material issue'**
  String get reviewIssueContextRecipe;

  /// No description provided for @reviewIssueContextScope.
  ///
  /// In en, this message translates to:
  /// **'Selling context issue'**
  String get reviewIssueContextScope;

  /// No description provided for @reviewIssueContextGeneral.
  ///
  /// In en, this message translates to:
  /// **'General issue'**
  String get reviewIssueContextGeneral;

  /// No description provided for @reviewPreviewContext.
  ///
  /// In en, this message translates to:
  /// **'Inspect the assigned Menu collection for this selling context.'**
  String get reviewPreviewContext;

  /// No description provided for @reviewPreviewLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preview language'**
  String get reviewPreviewLanguage;

  /// No description provided for @reviewPreviewLanguageDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get reviewPreviewLanguageDefault;

  /// No description provided for @reviewPreviewLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get reviewPreviewLanguageArabic;

  /// No description provided for @reviewPreviewLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get reviewPreviewLanguageEnglish;

  /// No description provided for @reviewPreviewShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden items'**
  String get reviewPreviewShowHidden;

  /// No description provided for @reviewPreviewShowUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Show unavailable items'**
  String get reviewPreviewShowUnavailable;

  /// No description provided for @reviewPreviewRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh Preview'**
  String get reviewPreviewRefresh;

  /// No description provided for @reviewPreviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading Preview'**
  String get reviewPreviewLoading;

  /// No description provided for @reviewPreviewBlockingBanner.
  ///
  /// In en, this message translates to:
  /// **'This preview contains issues that must be fixed before publishing.'**
  String get reviewPreviewBlockingBanner;

  /// No description provided for @reviewPreviewReviewReadiness.
  ///
  /// In en, this message translates to:
  /// **'Review Readiness'**
  String get reviewPreviewReviewReadiness;

  /// No description provided for @reviewPreviewAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get reviewPreviewAvailableNow;

  /// No description provided for @reviewPreviewOutsideScheduledHours.
  ///
  /// In en, this message translates to:
  /// **'Outside scheduled hours'**
  String get reviewPreviewOutsideScheduledHours;

  /// No description provided for @reviewPreviewHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get reviewPreviewHidden;

  /// No description provided for @reviewPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get reviewPreviewUnavailable;

  /// No description provided for @reviewPreviewSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get reviewPreviewSoldOut;

  /// No description provided for @reviewPreviewTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Temporarily unavailable'**
  String get reviewPreviewTemporarilyUnavailable;

  /// No description provided for @reviewPreviewAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get reviewPreviewAvailable;

  /// No description provided for @reviewPreviewFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get reviewPreviewFeatured;

  /// No description provided for @reviewPreviewDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get reviewPreviewDefault;

  /// No description provided for @reviewPreviewVariants.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get reviewPreviewVariants;

  /// No description provided for @reviewPreviewModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get reviewPreviewModifiers;

  /// No description provided for @reviewPreviewRecipeConfigured.
  ///
  /// In en, this message translates to:
  /// **'Recipe configured'**
  String get reviewPreviewRecipeConfigured;

  /// No description provided for @reviewPreviewRecipeComponents.
  ///
  /// In en, this message translates to:
  /// **'{count} components'**
  String reviewPreviewRecipeComponents(int count);

  /// No description provided for @reviewPreviewNoMenus.
  ///
  /// In en, this message translates to:
  /// **'No Menus to preview'**
  String get reviewPreviewNoMenus;

  /// No description provided for @reviewPreviewNoMenusHelp.
  ///
  /// In en, this message translates to:
  /// **'Assign at least one active Menu to this selling context.'**
  String get reviewPreviewNoMenusHelp;

  /// No description provided for @reviewPreviewEmptySection.
  ///
  /// In en, this message translates to:
  /// **'No products are included in this section.'**
  String get reviewPreviewEmptySection;

  /// No description provided for @reviewPreviewError.
  ///
  /// In en, this message translates to:
  /// **'Could not load Preview.'**
  String get reviewPreviewError;

  /// No description provided for @reviewPreviewRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get reviewPreviewRetry;

  /// No description provided for @reviewPreviewBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base price'**
  String get reviewPreviewBasePrice;

  /// No description provided for @reviewPreviewRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get reviewPreviewRequired;

  /// No description provided for @reviewPreviewOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get reviewPreviewOptional;

  /// No description provided for @reviewPreviewOptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable option'**
  String get reviewPreviewOptionUnavailable;

  /// No description provided for @reviewPublishQuestion.
  ///
  /// In en, this message translates to:
  /// **'Publish {branch} · {channel}?'**
  String reviewPublishQuestion(String branch, String channel);

  /// No description provided for @reviewPublishScopeHelp.
  ///
  /// In en, this message translates to:
  /// **'This creates a published Menu version for this exact selling context.'**
  String get reviewPublishScopeHelp;

  /// No description provided for @reviewPublishCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get reviewPublishCurrentVersion;

  /// No description provided for @reviewPublishCheckingReadiness.
  ///
  /// In en, this message translates to:
  /// **'Checking readiness…'**
  String get reviewPublishCheckingReadiness;

  /// No description provided for @reviewPublishWaitForReadiness.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current readiness check before publishing.'**
  String get reviewPublishWaitForReadiness;

  /// No description provided for @reviewPublishNoAssignedMenu.
  ///
  /// In en, this message translates to:
  /// **'Assign at least one active Menu to this selling context before publishing.'**
  String get reviewPublishNoAssignedMenu;

  /// No description provided for @reviewPublishCannotPublish.
  ///
  /// In en, this message translates to:
  /// **'Cannot publish yet'**
  String get reviewPublishCannotPublish;

  /// No description provided for @reviewPublishReviewErrors.
  ///
  /// In en, this message translates to:
  /// **'Review Errors'**
  String get reviewPublishReviewErrors;

  /// No description provided for @reviewPublishReviewIssues.
  ///
  /// In en, this message translates to:
  /// **'Review Issues'**
  String get reviewPublishReviewIssues;

  /// No description provided for @reviewPublishWarningsCanProceed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning remains. You can still publish this version.} other{{count} warnings remain. You can still publish this version.}}'**
  String reviewPublishWarningsCanProceed(num count);

  /// No description provided for @reviewPublishCleanReady.
  ///
  /// In en, this message translates to:
  /// **'No blocking issues were found. You can publish this version.'**
  String get reviewPublishCleanReady;

  /// No description provided for @reviewPublishAction.
  ///
  /// In en, this message translates to:
  /// **'Publish Menu Version'**
  String get reviewPublishAction;

  /// No description provided for @reviewPublishPublishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing…'**
  String get reviewPublishPublishing;

  /// No description provided for @reviewPublishConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish {branch} · {channel}?'**
  String reviewPublishConfirmTitle(String branch, String channel);

  /// No description provided for @reviewPublishImmutableExplanation.
  ///
  /// In en, this message translates to:
  /// **'A new immutable Menu version will be created if the configuration changed.'**
  String get reviewPublishImmutableExplanation;

  /// No description provided for @reviewPublishAlreadyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get reviewPublishAlreadyUpToDate;

  /// No description provided for @reviewPublishNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No Menu changes were found since Version {version}. No new version was created.'**
  String reviewPublishNoChanges(int version);

  /// No description provided for @reviewPublishSuccess.
  ///
  /// In en, this message translates to:
  /// **'Published successfully'**
  String get reviewPublishSuccess;

  /// No description provided for @reviewPublishCurrentForScope.
  ///
  /// In en, this message translates to:
  /// **'This is now the current published Menu version for {branch} · {channel}.'**
  String reviewPublishCurrentForScope(String branch, String channel);

  /// No description provided for @reviewPublishRevalidationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu changed and is no longer ready to publish.'**
  String get reviewPublishRevalidationFailedTitle;

  /// No description provided for @reviewPublishRevalidationFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'New issues were found during the final check.'**
  String get reviewPublishRevalidationFailedMessage;

  /// No description provided for @reviewPublishRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not publish the Menu version.'**
  String get reviewPublishRequestFailed;

  /// No description provided for @reviewPublishTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get reviewPublishTryAgain;

  /// No description provided for @menuUiUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get menuUiUnsavedChangesTitle;

  /// No description provided for @menuUiUnsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. If you leave now, they will be discarded.'**
  String get menuUiUnsavedChangesMessage;

  /// No description provided for @menuUiStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get menuUiStay;

  /// No description provided for @menuUiLeaveWithoutSaving.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get menuUiLeaveWithoutSaving;

  /// No description provided for @productEditorCreated.
  ///
  /// In en, this message translates to:
  /// **'Product created successfully.'**
  String get productEditorCreated;

  /// No description provided for @productEditorUpdated.
  ///
  /// In en, this message translates to:
  /// **'Product updated successfully.'**
  String get productEditorUpdated;

  /// No description provided for @productEditorCreateHelp.
  ///
  /// In en, this message translates to:
  /// **'Define what this product is, where it belongs, and how it is sold.'**
  String get productEditorCreateHelp;

  /// No description provided for @productEditorEditHelp.
  ///
  /// In en, this message translates to:
  /// **'Update the product information managers use every day.'**
  String get productEditorEditHelp;

  /// No description provided for @productEditorArchivedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Archived products are available for reference only. Restore this product to edit it.'**
  String get productEditorArchivedReadOnly;

  /// No description provided for @productEditorViewWorkspace.
  ///
  /// In en, this message translates to:
  /// **'View Product Workspace'**
  String get productEditorViewWorkspace;

  /// No description provided for @productEditorDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Default Product Name'**
  String get productEditorDefaultName;

  /// No description provided for @productEditorDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'Default Description'**
  String get productEditorDefaultDescription;

  /// No description provided for @productEditorImage.
  ///
  /// In en, this message translates to:
  /// **'Product Image'**
  String get productEditorImage;

  /// No description provided for @productEditorUploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading image…'**
  String get productEditorUploadingImage;

  /// No description provided for @productEditorChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose Image'**
  String get productEditorChooseImage;

  /// No description provided for @productEditorChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get productEditorChangeImage;

  /// No description provided for @productEditorRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove Image'**
  String get productEditorRemoveImage;

  /// No description provided for @productEditorImageFormats.
  ///
  /// In en, this message translates to:
  /// **'PNG, JPG, WEBP, or GIF up to 5 MB'**
  String get productEditorImageFormats;

  /// No description provided for @productEditorTranslationsClose.
  ///
  /// In en, this message translates to:
  /// **'Close translations'**
  String get productEditorTranslationsClose;

  /// No description provided for @productEditorDefaultContent.
  ///
  /// In en, this message translates to:
  /// **'Default content'**
  String get productEditorDefaultContent;

  /// No description provided for @productEditorLocalizedName.
  ///
  /// In en, this message translates to:
  /// **'Localized Name'**
  String get productEditorLocalizedName;

  /// No description provided for @productEditorLocalizedDescription.
  ///
  /// In en, this message translates to:
  /// **'Localized Description'**
  String get productEditorLocalizedDescription;

  /// No description provided for @productEditorStockTracking.
  ///
  /// In en, this message translates to:
  /// **'Stock Tracking'**
  String get productEditorStockTracking;

  /// No description provided for @productEditorStockTrackingHelp.
  ///
  /// In en, this message translates to:
  /// **'Track the materials consumed when this Product is prepared.'**
  String get productEditorStockTrackingHelp;

  /// No description provided for @productEditorNoDefaultVariant.
  ///
  /// In en, this message translates to:
  /// **'No default variant returned.'**
  String get productEditorNoDefaultVariant;

  /// No description provided for @productEditorManageVariants.
  ///
  /// In en, this message translates to:
  /// **'Manage Variants'**
  String get productEditorManageVariants;

  /// No description provided for @productDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found.'**
  String get productDetailNotFound;

  /// No description provided for @productDetailEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get productDetailEdit;

  /// No description provided for @productDetailArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive Product?'**
  String get productDetailArchiveTitle;

  /// No description provided for @productDetailRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Product?'**
  String get productDetailRestoreTitle;

  /// No description provided for @productDetailArchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive Product'**
  String get productDetailArchiveAction;

  /// No description provided for @productDetailRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore Product'**
  String get productDetailRestoreAction;

  /// No description provided for @productDetailUsageEmpty.
  ///
  /// In en, this message translates to:
  /// **'This Product is not currently used in any menus.'**
  String get productDetailUsageEmpty;

  /// No description provided for @variantTitle.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get variantTitle;

  /// No description provided for @variantHelp.
  ///
  /// In en, this message translates to:
  /// **'Manage the selling options available for this Product.'**
  String get variantHelp;

  /// No description provided for @variantAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Variant'**
  String get variantAdd;

  /// No description provided for @variantEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Variant'**
  String get variantEdit;

  /// No description provided for @variantReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get variantReorder;

  /// No description provided for @variantDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get variantDone;

  /// No description provided for @variantRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh Variants'**
  String get variantRefresh;

  /// No description provided for @variantReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This product is archived and variants are read-only.'**
  String get variantReadOnly;

  /// No description provided for @variantCannotArchiveDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot archive Default Variant'**
  String get variantCannotArchiveDefaultTitle;

  /// No description provided for @variantCannotArchiveDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'The only active Variant cannot be archived.'**
  String get variantCannotArchiveDefaultMessage;

  /// No description provided for @variantArchiveMessage.
  ///
  /// In en, this message translates to:
  /// **'This Variant will be archived and can be restored later.'**
  String get variantArchiveMessage;

  /// No description provided for @variantSelectReplacement.
  ///
  /// In en, this message translates to:
  /// **'Select an active replacement Default Variant.'**
  String get variantSelectReplacement;

  /// No description provided for @variantOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get variantOrder;

  /// No description provided for @variantName.
  ///
  /// In en, this message translates to:
  /// **'Variant name'**
  String get variantName;

  /// No description provided for @variantBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base Price'**
  String get variantBasePrice;

  /// No description provided for @variantCostPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost Price'**
  String get variantCostPrice;

  /// No description provided for @variantDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get variantDefault;

  /// No description provided for @variantActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get variantActions;

  /// No description provided for @variantActiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Active status'**
  String get variantActiveStatus;

  /// No description provided for @variantMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make this the Default Variant'**
  String get variantMakeDefault;

  /// No description provided for @variantDefaultMustBeActive.
  ///
  /// In en, this message translates to:
  /// **'A Default Variant must be active.'**
  String get variantDefaultMustBeActive;

  /// No description provided for @variantSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get variantSaving;

  /// No description provided for @variantNoArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived Variants.'**
  String get variantNoArchived;

  /// No description provided for @variantEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Variants returned for this product.'**
  String get variantEmpty;

  /// No description provided for @modifierAssignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get modifierAssignmentTitle;

  /// No description provided for @modifierAssignmentSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get modifierAssignmentSaveChanges;

  /// No description provided for @modifierAssignmentAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Modifier Group'**
  String get modifierAssignmentAddGroup;

  /// No description provided for @modifierAssignmentNoAssigned.
  ///
  /// In en, this message translates to:
  /// **'No Modifier Groups are assigned to this Product.'**
  String get modifierAssignmentNoAssigned;

  /// No description provided for @modifierAssignmentNoAvailable.
  ///
  /// In en, this message translates to:
  /// **'No available Modifier Groups found.'**
  String get modifierAssignmentNoAvailable;

  /// No description provided for @modifierAssignmentSearch.
  ///
  /// In en, this message translates to:
  /// **'Search Modifier Groups'**
  String get modifierAssignmentSearch;

  /// No description provided for @modifierAssignmentRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove modifier group?'**
  String get modifierAssignmentRemoveTitle;

  /// No description provided for @modifierAssignmentRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove this Modifier Group from the Product? The Group and its Options will remain available in the Modifier Library.'**
  String get modifierAssignmentRemoveMessage;

  /// No description provided for @modifierAssignmentUseLibrarySettings.
  ///
  /// In en, this message translates to:
  /// **'Use library settings'**
  String get modifierAssignmentUseLibrarySettings;

  /// No description provided for @modifierAssignmentApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get modifierAssignmentApply;

  /// No description provided for @modifierAssignmentCurrentBehavior.
  ///
  /// In en, this message translates to:
  /// **'Current behavior'**
  String get modifierAssignmentCurrentBehavior;

  /// No description provided for @modifierAssignmentNonNegative.
  ///
  /// In en, this message translates to:
  /// **'Use non-negative whole numbers.'**
  String get modifierAssignmentNonNegative;

  /// No description provided for @modifierAssignmentInvalidConstraints.
  ///
  /// In en, this message translates to:
  /// **'The effective selection constraints are invalid.'**
  String get modifierAssignmentInvalidConstraints;

  /// No description provided for @productDetailUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized product'**
  String get productDetailUncategorized;

  /// No description provided for @productDetailArchiveMenuAction.
  ///
  /// In en, this message translates to:
  /// **'Archive Product'**
  String get productDetailArchiveMenuAction;

  /// No description provided for @productDetailRestoreMenuAction.
  ///
  /// In en, this message translates to:
  /// **'Restore Product'**
  String get productDetailRestoreMenuAction;

  /// No description provided for @productDetailBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base Price'**
  String get productDetailBasePrice;

  /// No description provided for @productDetailKitchenStation.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Station'**
  String get productDetailKitchenStation;

  /// No description provided for @productDetailWorkspaceNavigation.
  ///
  /// In en, this message translates to:
  /// **'Product workspace navigation'**
  String get productDetailWorkspaceNavigation;

  /// No description provided for @productDetailSetupHelp.
  ///
  /// In en, this message translates to:
  /// **'The catalog and preparation details for this product.'**
  String get productDetailSetupHelp;

  /// No description provided for @productDetailDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productDetailDescription;

  /// No description provided for @productDetailAdvancedTechnical.
  ///
  /// In en, this message translates to:
  /// **'Advanced & Technical'**
  String get productDetailAdvancedTechnical;

  /// No description provided for @productDetailUsageHelp.
  ///
  /// In en, this message translates to:
  /// **'Menus where this Product is currently used.'**
  String get productDetailUsageHelp;

  /// No description provided for @productDetailUsageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active menu placements.'**
  String productDetailUsageCount(int count);

  /// No description provided for @productDetailArchivedVariantsMessage.
  ///
  /// In en, this message translates to:
  /// **'This product is archived and variants are read-only.'**
  String get productDetailArchivedVariantsMessage;

  /// No description provided for @productDetailArchivedModifiersMessage.
  ///
  /// In en, this message translates to:
  /// **'This product is archived and modifier assignments are read-only.'**
  String get productDetailArchivedModifiersMessage;

  /// No description provided for @productDetailViewAction.
  ///
  /// In en, this message translates to:
  /// **'View Product Detail'**
  String get productDetailViewAction;

  /// No description provided for @variantActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get variantActive;

  /// No description provided for @variantInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get variantInactive;

  /// No description provided for @variantArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get variantArchived;

  /// No description provided for @variantAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get variantAll;

  /// No description provided for @variantSetDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Set “{name}” as the Default Variant?'**
  String variantSetDefaultTitle(String name);

  /// No description provided for @variantSetDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'The Product’s displayed base price, SKU, barcode, and legacy POS compatibility will use this Variant. Existing Orders are not changed.'**
  String get variantSetDefaultMessage;

  /// No description provided for @variantArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive “{name}”?'**
  String variantArchiveTitle(String name);

  /// No description provided for @variantRestoreDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore “{name}” as Default?'**
  String variantRestoreDefaultTitle(String name);

  /// No description provided for @variantRestoreDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'This Product has no active Default Variant, so this restored Variant must become the Default Variant.'**
  String get variantRestoreDefaultMessage;

  /// No description provided for @variantSetDefaultAction.
  ///
  /// In en, this message translates to:
  /// **'Set Default'**
  String get variantSetDefaultAction;

  /// No description provided for @variantRestoreDefaultAction.
  ///
  /// In en, this message translates to:
  /// **'Restore as Default'**
  String get variantRestoreDefaultAction;

  /// No description provided for @variantMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get variantMoveUp;

  /// No description provided for @variantMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get variantMoveDown;

  /// No description provided for @variantActionsFor.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String variantActionsFor(String name);

  /// No description provided for @variantReorderSemantic.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get variantReorderSemantic;

  /// No description provided for @variantSku.
  ///
  /// In en, this message translates to:
  /// **'SKU: {sku}'**
  String variantSku(String sku);

  /// No description provided for @variantRecipeConfigured.
  ///
  /// In en, this message translates to:
  /// **'Recipe configured'**
  String get variantRecipeConfigured;

  /// No description provided for @variantRecipeMissing.
  ///
  /// In en, this message translates to:
  /// **'Recipe missing'**
  String get variantRecipeMissing;

  /// No description provided for @variantRecipeNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Recipe not configured'**
  String get variantRecipeNotConfigured;

  /// No description provided for @variantManageRecipe.
  ///
  /// In en, this message translates to:
  /// **'Manage Recipe'**
  String get variantManageRecipe;

  /// No description provided for @variantPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get variantPricing;

  /// No description provided for @variantSellingHours.
  ///
  /// In en, this message translates to:
  /// **'Selling Hours'**
  String get variantSellingHours;

  /// No description provided for @variantCurrentAvailability.
  ///
  /// In en, this message translates to:
  /// **'Current Availability'**
  String get variantCurrentAvailability;

  /// No description provided for @variantArabicName.
  ///
  /// In en, this message translates to:
  /// **'Arabic name'**
  String get variantArabicName;

  /// No description provided for @variantEnglishName.
  ///
  /// In en, this message translates to:
  /// **'English name'**
  String get variantEnglishName;

  /// No description provided for @variantSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort Order'**
  String get variantSortOrder;

  /// No description provided for @modifierAssignmentArchivedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This product is archived and modifier assignments are read-only.'**
  String get modifierAssignmentArchivedReadOnly;

  /// No description provided for @modifierAssignmentViewProduct.
  ///
  /// In en, this message translates to:
  /// **'View Product Detail'**
  String get modifierAssignmentViewProduct;

  /// No description provided for @modifierAssignmentProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get modifierAssignmentProduct;

  /// No description provided for @modifierAssignmentAssignedGroups.
  ///
  /// In en, this message translates to:
  /// **'Assigned Groups ({count})'**
  String modifierAssignmentAssignedGroups(int count);

  /// No description provided for @modifierAssignmentAvailableGroups.
  ///
  /// In en, this message translates to:
  /// **'Available Groups'**
  String get modifierAssignmentAvailableGroups;

  /// No description provided for @modifierAssignmentReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get modifierAssignmentReorder;

  /// No description provided for @modifierAssignmentDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get modifierAssignmentDone;

  /// No description provided for @modifierAssignmentMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get modifierAssignmentMoveUp;

  /// No description provided for @modifierAssignmentMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get modifierAssignmentMoveDown;

  /// No description provided for @modifierAssignmentActionsFor.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String modifierAssignmentActionsFor(String name);

  /// No description provided for @modifierAssignmentChooseGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a group to make its customer choices available for this Product.'**
  String get modifierAssignmentChooseGroupHelp;

  /// No description provided for @modifierAssignmentCustomizeFor.
  ///
  /// In en, this message translates to:
  /// **'Customize for {name}'**
  String modifierAssignmentCustomizeFor(String name);

  /// No description provided for @modifierAssignmentCustomizedFor.
  ///
  /// In en, this message translates to:
  /// **'Customized for {name}'**
  String modifierAssignmentCustomizedFor(String name);

  /// No description provided for @modifierAssignmentUsingLibrarySettings.
  ///
  /// In en, this message translates to:
  /// **'Using library settings'**
  String get modifierAssignmentUsingLibrarySettings;

  /// No description provided for @modifierAssignmentHowChoose.
  ///
  /// In en, this message translates to:
  /// **'How should customers choose?'**
  String get modifierAssignmentHowChoose;

  /// No description provided for @modifierAssignmentChooseOne.
  ///
  /// In en, this message translates to:
  /// **'Choose one'**
  String get modifierAssignmentChooseOne;

  /// No description provided for @modifierAssignmentChooseMultiple.
  ///
  /// In en, this message translates to:
  /// **'Choose multiple'**
  String get modifierAssignmentChooseMultiple;

  /// No description provided for @modifierAssignmentMultipleHelp.
  ///
  /// In en, this message translates to:
  /// **'This group uses multiple choices from the Modifier Library.'**
  String get modifierAssignmentMultipleHelp;

  /// No description provided for @modifierAssignmentSingleHelp.
  ///
  /// In en, this message translates to:
  /// **'This group uses one choice from the Modifier Library.'**
  String get modifierAssignmentSingleHelp;

  /// No description provided for @modifierAssignmentMinimumChoices.
  ///
  /// In en, this message translates to:
  /// **'Minimum choices'**
  String get modifierAssignmentMinimumChoices;

  /// No description provided for @modifierAssignmentMaximumChoices.
  ///
  /// In en, this message translates to:
  /// **'Maximum choices'**
  String get modifierAssignmentMaximumChoices;

  /// No description provided for @modifierAssignmentAllowDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Can the same option be added more than once?'**
  String get modifierAssignmentAllowDuplicate;

  /// No description provided for @modifierAssignmentConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure {name}'**
  String modifierAssignmentConfigure(String name);

  /// No description provided for @modifierAssignmentOverride.
  ///
  /// In en, this message translates to:
  /// **'{label} override'**
  String modifierAssignmentOverride(String label);

  /// No description provided for @modifierAssignmentLibraryDefaultBoolean.
  ///
  /// In en, this message translates to:
  /// **'Library Default: {value}'**
  String modifierAssignmentLibraryDefaultBoolean(String value);

  /// No description provided for @modifierAssignmentLibraryDefaultNumber.
  ///
  /// In en, this message translates to:
  /// **'Library Default: {value}'**
  String modifierAssignmentLibraryDefaultNumber(int value);

  /// No description provided for @modifierAssignmentEffectiveSetting.
  ///
  /// In en, this message translates to:
  /// **'Effective Setting: {value}'**
  String modifierAssignmentEffectiveSetting(String value);

  /// No description provided for @modifierAssignmentHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose which Modifier Groups customers can use with this Product.'**
  String get modifierAssignmentHelp;

  /// No description provided for @modifierAssignmentMaterialImpact.
  ///
  /// In en, this message translates to:
  /// **'Material impact configured'**
  String get modifierAssignmentMaterialImpact;

  /// No description provided for @modifierAssignmentViewGroup.
  ///
  /// In en, this message translates to:
  /// **'View Modifier Group'**
  String get modifierAssignmentViewGroup;

  /// No description provided for @modifierAssignmentCustomizeForProduct.
  ///
  /// In en, this message translates to:
  /// **'Customize for Product'**
  String get modifierAssignmentCustomizeForProduct;

  /// No description provided for @modifierAssignmentRemoveFromProduct.
  ///
  /// In en, this message translates to:
  /// **'Remove from Product'**
  String get modifierAssignmentRemoveFromProduct;

  /// No description provided for @menuDetailArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive menu?'**
  String get menuDetailArchiveTitle;

  /// No description provided for @menuDetailRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore menu?'**
  String get menuDetailRestoreTitle;

  /// No description provided for @menuDetailArchiveMessage.
  ///
  /// In en, this message translates to:
  /// **'This archives the menu without deleting it. Its composition remains available to review.'**
  String get menuDetailArchiveMessage;

  /// No description provided for @menuDetailRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'Restoring this menu returns it to Draft. It does not restore archived sections.'**
  String get menuDetailRestoreMessage;

  /// No description provided for @productEditorProductType.
  ///
  /// In en, this message translates to:
  /// **'Product Type'**
  String get productEditorProductType;

  /// No description provided for @productEditorStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get productEditorStandard;

  /// No description provided for @productEditorOpenPrice.
  ///
  /// In en, this message translates to:
  /// **'Open price'**
  String get productEditorOpenPrice;

  /// No description provided for @productEditorPreparationTime.
  ///
  /// In en, this message translates to:
  /// **'Preparation Time'**
  String get productEditorPreparationTime;

  /// No description provided for @productEditorMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get productEditorMinutes;

  /// No description provided for @productEditorInitialOptionHelp.
  ///
  /// In en, this message translates to:
  /// **'Every product starts with one selling option. You can add more variants later.'**
  String get productEditorInitialOptionHelp;

  /// No description provided for @productEditorVariantName.
  ///
  /// In en, this message translates to:
  /// **'Variant Name'**
  String get productEditorVariantName;

  /// No description provided for @productEditorDefaultVariant.
  ///
  /// In en, this message translates to:
  /// **'Default Variant'**
  String get productEditorDefaultVariant;

  /// No description provided for @productEditorDefaultVariantHelp.
  ///
  /// In en, this message translates to:
  /// **'Selling options are managed separately so product details stay focused.'**
  String get productEditorDefaultVariantHelp;

  /// No description provided for @productEditorTranslationsHelp.
  ///
  /// In en, this message translates to:
  /// **'Add localized content without crowding the main product form.'**
  String get productEditorTranslationsHelp;

  /// No description provided for @productEditorTranslationsPanelHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the translation panel to provide Arabic and English names and descriptions.'**
  String get productEditorTranslationsPanelHelp;

  /// No description provided for @productEditorSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort Order'**
  String get productEditorSortOrder;

  /// No description provided for @productEditorVariantCost.
  ///
  /// In en, this message translates to:
  /// **'Variant Cost'**
  String get productEditorVariantCost;

  /// No description provided for @productEditorNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get productEditorNone;

  /// No description provided for @productEditorPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get productEditorPreviewUnavailable;

  /// No description provided for @productEditorDropImage.
  ///
  /// In en, this message translates to:
  /// **'Drop an image here or click to browse'**
  String get productEditorDropImage;

  /// No description provided for @productEditorImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image could not be loaded'**
  String get productEditorImageLoadFailed;

  /// No description provided for @productEditorWhatIsProduct.
  ///
  /// In en, this message translates to:
  /// **'What is this product?'**
  String get productEditorWhatIsProduct;

  /// No description provided for @productEditorClassificationHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose where this product belongs in the catalog and preparation flow.'**
  String get productEditorClassificationHelp;

  /// No description provided for @productEditorKitchenStationHelp.
  ///
  /// In en, this message translates to:
  /// **'Where this product is generally prepared.'**
  String get productEditorKitchenStationHelp;

  /// No description provided for @productEditorReportingCategoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Used for sales and performance reports.'**
  String get productEditorReportingCategoryHelp;

  /// No description provided for @productEditorSellingPreparationHelp.
  ///
  /// In en, this message translates to:
  /// **'Set how this product is sold and what preparation information the team needs.'**
  String get productEditorSellingPreparationHelp;

  /// No description provided for @productEditorArabicConfigured.
  ///
  /// In en, this message translates to:
  /// **'Arabic configured'**
  String get productEditorArabicConfigured;

  /// No description provided for @productEditorEnglishConfigured.
  ///
  /// In en, this message translates to:
  /// **'English configured'**
  String get productEditorEnglishConfigured;

  /// No description provided for @productEditorBasePriceValue.
  ///
  /// In en, this message translates to:
  /// **'Base price {price}'**
  String productEditorBasePriceValue(String price);

  /// No description provided for @productDetailArchiveMessage.
  ///
  /// In en, this message translates to:
  /// **'This Product will no longer be available for new Menu configuration or normal Catalog use. Existing Orders and published historical Versions will not be changed.'**
  String get productDetailArchiveMessage;

  /// No description provided for @productDetailRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'This restores the Product to the editable Catalog. Availability still depends on Menu assignments, schedules, operational status, validation, and publishing.'**
  String get productDetailRestoreMessage;

  /// No description provided for @productCatalogArchiveMessage.
  ///
  /// In en, this message translates to:
  /// **'This Product will no longer be available for new Menu configuration or normal Catalog use. Existing Orders and published historical Versions will not be changed.\n\nThe Product is not permanently deleted. Central Modifier Groups are not deleted, and Variants remain stored according to Backend behavior.'**
  String get productCatalogArchiveMessage;

  /// No description provided for @productCatalogRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'This restores the Product to the editable Catalog. Its availability in Menus still depends on Menu assignments, schedules, operational status, validation, and publishing.'**
  String get productCatalogRestoreMessage;

  /// No description provided for @productCatalogUsageMessage.
  ///
  /// In en, this message translates to:
  /// **'This Product is currently used in {count} Menu placements{names}.'**
  String productCatalogUsageMessage(int count, String names);

  /// No description provided for @operationalOverrideClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear operational override?'**
  String get operationalOverrideClearTitle;

  /// No description provided for @operationalOverrideClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear the {level} override for {scope}?\n\nScheduled Availability, Product configuration, and historical Published Versions will not be changed.'**
  String operationalOverrideClearMessage(String level, String scope);

  /// No description provided for @operationalOverrideClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear override'**
  String get operationalOverrideClearAction;

  /// No description provided for @productDetailProductId.
  ///
  /// In en, this message translates to:
  /// **'Product ID'**
  String get productDetailProductId;

  /// No description provided for @productDetailUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get productDetailUpdated;

  /// No description provided for @productDetailImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get productDetailImageUrl;
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
