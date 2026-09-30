import 'package:flutter/widgets.dart';

import '../../../app/localization/localization_extensions.dart';

const String configuredSellPriceMustBePositive =
    'configured_sell_price_must_be_positive';

String? localizedConfiguredPriceError(BuildContext context, String? error) =>
    error == configuredSellPriceMustBePositive
    ? context.l10n.configuredSellPriceMustBePositive
    : error;

/// Normalizes Arabic-Indic numerals without ever parsing through `double`.
/// The returned wire value is the exact user-entered decimal string.
class PricingDecimalInput {
  static String normalize(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const eastern = '۰۱۲۳۴۵۶۷۸۹';
    var value = input
        .trim()
        .replaceAll('٫', '.')
        .replaceAll('،', '.')
        .replaceAll(',', '.');
    for (var index = 0; index < 10; index++) {
      value = value
          .replaceAll(arabic[index], '$index')
          .replaceAll(eastern[index], '$index');
    }
    return value;
  }

  static bool _positive(String value) {
    final parts = value.split('.');
    return parts.first.replaceFirst(RegExp(r'^0+'), '').isNotEmpty ||
        (parts.length == 2 && RegExp(r'[1-9]').hasMatch(parts.last));
  }

  static String? money(String input) {
    final value = normalize(input);
    return RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value) &&
            _positive(value) &&
            _atMost(value, '9999999999.99')
        ? null
        : configuredSellPriceMustBePositive;
  }

  static String? roundingStep(String input) => money(input);

  static String? amount(String input, {required bool percentageDecrease}) {
    final value = normalize(input);
    if (!RegExp(r'^\d+(?:\.\d{1,20})?$').hasMatch(value) ||
        !_positive(value) ||
        !_atMost(value, '9999999999.99')) {
      return configuredSellPriceMustBePositive;
    }
    if (percentageDecrease && _atLeast(value, '100')) {
      return 'pricingPercentageMustBeBelow100';
    }
    return null;
  }

  static bool _atLeast(String value, String limit) =>
      _compare(value, limit) >= 0;
  static bool _atMost(String value, String limit) =>
      _compare(value, limit) <= 0;

  static int _compare(String left, String right) {
    final l = left.split('.');
    final r = right.split('.');
    final li = l.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final ri = r.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (li.length != ri.length) return li.length.compareTo(ri.length);
    final whole = li.compareTo(ri);
    if (whole != 0) return whole;
    final lf = (l.length == 2 ? l.last : '').padRight(20, '0');
    final rf = (r.length == 2 ? r.last : '').padRight(20, '0');
    return lf.compareTo(rf);
  }
}
