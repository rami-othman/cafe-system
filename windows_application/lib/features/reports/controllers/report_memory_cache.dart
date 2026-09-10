/// A deliberately small, session-only LRU cache for report payloads.
///
/// Financial report data must not be persisted locally.  Keeping a few recent
/// immutable payloads in memory makes route re-entry immediate while each
/// cubit still refreshes the result in the background.
class ReportMemoryCache<T> {
  ReportMemoryCache({this.capacity = 8});

  final int capacity;
  final Map<String, T> _entries = <String, T>{};

  T? read(String key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  void put(String key, T value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}

String reportQueryKey(
  String reportType, {
  required DateTime from,
  required DateTime to,
  required List<Object?> filters,
}) => '$reportType|${from.toIso8601String()}|${to.toIso8601String()}|'
    '${filters.join('|')}';
