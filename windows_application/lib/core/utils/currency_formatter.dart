import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

abstract final class CurrencyFormatter {
  /// Formats a two-decimal amount represented as integer minor units without
  /// converting it through binary floating point.
  static String formatMinorUnits(
    int minorUnits, {
    String currencyCode = AppConstants.defaultCurrencyCode,
  }) {
    final bool negative = minorUnits < 0;
    final int absolute = minorUnits.abs();
    final String whole = (absolute ~/ 100).toString();
    final String fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$currencyCode $whole.$fraction';
  }

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

  static String formatForContext(
    BuildContext context,
    num amount, {
    String currencyCode = AppConstants.defaultCurrencyCode,
  }) => format(
    amount,
    locale: Localizations.localeOf(context).toLanguageTag(),
    currencyCode: currencyCode,
  );
}
