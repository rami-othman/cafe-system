import 'package:flutter/foundation.dart';

/// Debug-only timings for route/report loads. No query values or financial
/// payload data are ever logged.
class ReportDebugTiming {
  ReportDebugTiming(this.reportType) : _watch = Stopwatch()..start();

  final String reportType;
  final Stopwatch _watch;

  void complete() {
    _watch.stop();
    if (kDebugMode) {
      debugPrint('reports.$reportType load ${_watch.elapsedMilliseconds}ms');
    }
  }
}
