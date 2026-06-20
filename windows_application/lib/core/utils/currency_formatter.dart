import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

abstract final class CurrencyFormatter {
  static String format(
    num amount, {
    String locale = AppConstants.defaultLocale,
    String currencyCode = AppConstants.defaultCurrencyCode,
  }) {
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: currencyCode,
    ).format(amount);
  }
}
