import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/utils/localized_entity_text.dart';

void main() {
  test(
    'localized entity text consistently follows locale-specific fallback order',
    () {
      expect(
        LocalizedEntityText.resolve(
          locale: const Locale('ar'),
          defaultValue: 'Default',
          arabicValue: 'العربية',
          englishValue: 'English',
        ),
        'العربية',
      );
      expect(
        LocalizedEntityText.resolve(
          locale: const Locale('en'),
          defaultValue: 'Default',
          arabicValue: 'العربية',
          englishValue: 'English',
        ),
        'English',
      );
      expect(
        LocalizedEntityText.resolve(
          locale: const Locale('ar'),
          defaultValue: 'Default',
          englishValue: 'English',
        ),
        'Default',
      );
      expect(
        LocalizedEntityText.resolve(
          locale: const Locale('en'),
          arabicValue: 'العربية',
        ),
        'العربية',
      );
      expect(
        LocalizedEntityText.resolve(locale: const Locale('en'), fallback: '—'),
        '—',
      );
    },
  );
}
