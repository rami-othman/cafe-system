/// Parses timestamps returned by the API for display on the device.
///
/// The backend stores timestamps in UTC. PostgreSQL `timestamp` values can be
/// returned without a UTC suffix, which [DateTime.tryParse] would otherwise
/// interpret as device-local time and display with an incorrect hour.
DateTime? parseBackendDateTime(String? value) {
  final String source = value?.trim() ?? '';
  if (source.isEmpty) return null;

  final DateTime? parsed = DateTime.tryParse(source);
  if (parsed == null) return null;

  // Calendar-only values, such as countDate, are not instants in time.
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(source)) return parsed;

  // A timestamp with Z or an explicit offset already identifies its zone.
  if (RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
      .hasMatch(source)) {
    return parsed.toLocal();
  }

  // Treat legacy, timezone-less API timestamps as UTC before displaying them.
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toLocal();
}
