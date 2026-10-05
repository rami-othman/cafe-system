import 'package:intl/intl.dart';

/// Number, currency, quantity and time formatting for the shift module.
///
/// Every screen formats through this class so the module never mixes Arabic
/// and Western digit shapes: amounts, counts and clock values all render with
/// Western digits (the shape used on POS receipts and by the cash drawer),
/// while the surrounding copy stays Arabic.
abstract final class ShiftFormat {
  static const String currencySuffix = 'ل.س';
  static const String _digitLocale = 'en_US';

  static final NumberFormat _amount = NumberFormat.decimalPattern(_digitLocale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 0;

  static final NumberFormat _count = NumberFormat.decimalPattern(_digitLocale);

  /// Whole-currency amount without a suffix, e.g. `18,250`.
  static String amount(num value) => _amount.format(value.round());

  /// Whole-currency amount with the Syrian pound suffix, e.g. `18,250 ل.س`.
  static String money(num value) => '${amount(value)} $currencySuffix';

  /// Signed amount used for cash and value differences, e.g. `-100` / `+250`.
  static String signedAmount(num value) {
    final int rounded = value.round();
    if (rounded == 0) return '0';
    return rounded > 0 ? '+${amount(rounded)}' : '-${amount(rounded.abs())}';
  }

  static String signedMoney(num value) =>
      '${signedAmount(value)} $currencySuffix';

  static String count(int value) => _count.format(value);

  static String percent(double ratio) =>
      '${(ratio * 100).round()}%';

  /// Quantity honoring the unit's decimal precision: `4.2 kg`, `12 حبة`.
  /// Trailing zeros are trimmed so a whole count never reads `12.00`.
  static String quantity(double value, int decimals) {
    if (decimals <= 0) return _count.format(value.round());
    final String fixed = value.toStringAsFixed(decimals);
    final String trimmed = fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : fixed;
    return trimmed.isEmpty ? '0' : trimmed;
  }

  static String signedQuantity(double value, int decimals) {
    if (value.abs() < _epsilon) return '0';
    final String magnitude = quantity(value.abs(), decimals);
    return value > 0 ? '+$magnitude' : '-$magnitude';
  }

  /// 24-hour clock, e.g. `08:15`.
  static String time(DateTime value) =>
      '${_two(value.hour)}:${_two(value.minute)}';

  /// 12-hour clock with an Arabic meridiem, e.g. `08:15 صباحًا`.
  static String timeOfDay(DateTime value) {
    final int hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final String meridiem = value.hour < 12 ? 'صباحًا' : 'مساءً';
    return '${_two(hour12)}:${_two(value.minute)} $meridiem';
  }

  /// Long Arabic date, e.g. `15 سبتمبر 2026`.
  static String longDate(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  /// Numeric date, e.g. `2026-09-15`.
  static String isoDate(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)}';

  static String dateTime(DateTime value) =>
      '${isoDate(value)} ${time(value)}';

  /// Running clock for an open shift, e.g. `07:42:18`.
  static String stopwatch(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
  }

  /// Compact duration, e.g. `07:52`.
  static String shortDuration(Duration value) =>
      '${_two(value.inHours)}:${_two(value.inMinutes.remainder(60))}';

  /// Readable duration used in summaries, e.g. `7 ساعات و52 دقيقة`.
  static String humanDuration(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final String hoursPart = switch (hours) {
      0 => '',
      1 => 'ساعة واحدة',
      2 => 'ساعتان',
      >= 3 && <= 10 => '$hours ساعات',
      _ => '$hours ساعة',
    };
    final String minutesPart = switch (minutes) {
      0 => '',
      1 => 'دقيقة واحدة',
      2 => 'دقيقتان',
      >= 3 && <= 10 => '$minutes دقائق',
      _ => '$minutes دقيقة',
    };
    if (hoursPart.isEmpty && minutesPart.isEmpty) return 'أقل من دقيقة';
    if (hoursPart.isEmpty) return minutesPart;
    if (minutesPart.isEmpty) return hoursPart;
    return '$hoursPart و$minutesPart';
  }

  /// Relative day label used by "last count": `اليوم 16:05` / `أمس 16:05`.
  static String relativeDayTime(DateTime value, DateTime now) {
    final DateTime day = DateTime(value.year, value.month, value.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int deltaDays = today.difference(day).inDays;
    return switch (deltaDays) {
      0 => 'اليوم ${time(value)}',
      1 => 'أمس ${time(value)}',
      _ => '${isoDate(value)} ${time(value)}',
    };
  }

  static const double _epsilon = 1e-9;

  static String _two(int value) => value.toString().padLeft(2, '0');

  static const List<String> _months = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
}
