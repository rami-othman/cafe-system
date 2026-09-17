import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// The operational timezone used by Cafe 6:18.
const String damascusTimezone = 'Asia/Damascus';

timezone.Location? _damascus;

timezone.Location get _damascusLocation {
  timezone_data.initializeTimeZones();
  return _damascus ??= timezone.getLocation(damascusTimezone);
}

/// Parses API timestamps for display in the cafe's operational timezone.
///
/// The backend persists instants in UTC. PostgreSQL query results are often
/// returned without an offset; those values must therefore be treated as UTC,
/// not as the workstation's local clock. Converting explicitly to Damascus
/// also keeps displays correct when a POS workstation has the wrong OS zone.
DateTime? parseBackendDateTime(String? value) {
  final String source = value?.trim() ?? '';
  if (source.isEmpty) return null;

  final DateTime? parsed = DateTime.tryParse(source);
  if (parsed == null) return null;

  // Calendar-only values, such as countDate, are business dates rather than
  // instants. Keep their calendar fields unchanged.
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(source)) return parsed;

  final bool hasOffset = RegExp(
    r'(?:Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(source);
  final DateTime utc = hasOffset
      ? parsed.toUtc()
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );

  return timezone.TZDateTime.from(utc, _damascusLocation);
}
