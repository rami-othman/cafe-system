import 'package:intl/intl.dart';

abstract final class LocalizedFormatters {
  static String date(DateTime value, {required String locale}) =>
      DateFormat.yMMMd(locale).format(value);

  static String dateTime(DateTime value, {required String locale}) =>
      DateFormat.yMMMd(locale).add_jm().format(value);

  static String number(num value, {required String locale}) =>
      NumberFormat.decimalPattern(locale).format(value);

  static String decimal(num value, {required String locale}) =>
      NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: 2,
      ).format(value);

  static String currency(
    num value, {
    required String locale,
    required String currencyCode,
  }) => NumberFormat.simpleCurrency(
    locale: locale,
    name: currencyCode,
  ).format(value);
}
