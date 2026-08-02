import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:windows_application/core/utils/localized_formatters.dart';

void main() {
  test(
    'formatters use their supplied display locale without changing values',
    () async {
      await initializeDateFormatting('en');
      await initializeDateFormatting('ar');
      final DateTime date = DateTime(2026, 8, 1, 18, 30);
      expect(LocalizedFormatters.date(date, locale: 'en'), isNotEmpty);
      expect(LocalizedFormatters.date(date, locale: 'ar'), isNotEmpty);
      expect(LocalizedFormatters.number(12345.67, locale: 'en'), isNotEmpty);
      expect(LocalizedFormatters.number(12345.67, locale: 'ar'), isNotEmpty);
      expect(
        LocalizedFormatters.currency(42.5, locale: 'ar', currencyCode: 'SYP'),
        isNotEmpty,
      );
    },
  );
}
