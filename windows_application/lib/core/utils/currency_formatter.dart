import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

abstract final class CurrencyFormatter {
  /// Formats a two-decimal amount represented as integer minor units without
  /// converting it through binary floating point.
  static String formatMinorUnits(
    int minorUnits, {
    String locale = AppConstants.defaultLocale,
    String currencyCode = AppConstants.defaultCurrencyCode,
  }) {
    return _format(
      minorUnits / 100,
      locale: locale,
      currencyCode: currencyCode,
      minimumFractionDigits: minorUnits.abs() % 100 == 0 ? 0 : 2,
      maximumFractionDigits: 2,
    );
  }

  static String format(
    num amount, {
    String locale = AppConstants.defaultLocale,
    String currencyCode = AppConstants.defaultCurrencyCode,
  }) {
    return _format(
      amount,
      locale: locale,
      currencyCode: currencyCode,
      minimumFractionDigits: 0,
      maximumFractionDigits: _fractionDigits(amount),
    );
  }

  static String _format(
    num amount, {
    required String locale,
    required String currencyCode,
    required int minimumFractionDigits,
    required int maximumFractionDigits,
  }) {
    final NumberFormat number = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = minimumFractionDigits
      ..maximumFractionDigits = maximumFractionDigits;
    final String code = currencyCode.toUpperCase();
    final String suffix = code == 'SYP' && _isArabic(locale) ? 'ل.س' : code;
    return '${number.format(amount)} $suffix';
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

  static int _fractionDigits(num amount) {
    final num absolute = amount.abs();
    if (absolute == absolute.truncateToDouble()) return 0;

    // Monetary values in this domain are stored to two decimal places. Keep
    // meaningful cents while avoiding a forced `.00` for whole SYP values.
    return 2;
  }

  static bool _isArabic(String locale) => locale.toLowerCase().startsWith('ar');
}
