import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/utils/backend_datetime.dart';

void main() {
  test('treats a timezone-less backend timestamp as UTC', () {
    final DateTime? result = parseBackendDateTime('2026-08-27 07:30:00');

    expect(result?.toUtc(), DateTime.utc(2026, 8, 27, 7, 30));
  });

  test('preserves a calendar-only API date', () {
    final DateTime? result = parseBackendDateTime('2026-08-27');

    expect(result, DateTime(2026, 8, 27));
  });

  test('supports ISO timestamps that already specify UTC', () {
    final DateTime? result = parseBackendDateTime('2026-08-27T07:30:00Z');

    expect(result?.toUtc(), DateTime.utc(2026, 8, 27, 7, 30));
  });
}
