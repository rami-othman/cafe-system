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
}
