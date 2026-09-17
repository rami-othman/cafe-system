import 'dart:async';

/// Shared "type to search" debounce timer. Cancels any pending call whenever
/// a new one is scheduled, so a fast typist only triggers one backend
/// request per pause instead of one per keystroke.
///
/// Standardized at 350ms per the app-wide smart search convention — reuse
/// this instead of a local `Timer?` field.
class SearchDebouncer {
  SearchDebouncer({this.duration = const Duration(milliseconds: 350)});

  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}

/// Guards against a slow, stale request overwriting a faster, newer one.
///
/// Usage: call [next] right before firing a request to obtain a token, then
/// only apply the response if [isCurrent] is still true for that token.
class LatestRequestGuard {
  int _generation = 0;

  int next() => ++_generation;

  bool isCurrent(int token) => token == _generation;
}
