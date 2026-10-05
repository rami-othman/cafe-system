import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/utils/backend_datetime.dart';

void main() {
  group('parseBackendDateTime', () {
    test('treats an offset-less PostgreSQL timestamp as UTC', () {
      final DateTime? value = parseBackendDateTime('2026-09-16 15:47:59');

      expect(value, isNotNull);
      expect(value!.year, 2026);
      expect(value.month, 9);
      expect(value.day, 16);
      expect(value.hour, 18);
      expect(value.minute, 47);
      expect(value.timeZoneOffset, const Duration(hours: 3));
    });

    test('converts explicit UTC timestamps to Damascus', () {
      final DateTime? value = parseBackendDateTime('2026-09-16T15:47:59Z');

      expect(value, isNotNull);
      expect(value!.hour, 18);
      expect(value.timeZoneOffset, const Duration(hours: 3));
    });

    test('keeps a calendar-only business date unchanged', () {
      final DateTime? value = parseBackendDateTime('2026-09-16');

      expect(value, isNotNull);
      expect(value!.year, 2026);
      expect(value.month, 9);
      expect(value.day, 16);
    });
  });
}
