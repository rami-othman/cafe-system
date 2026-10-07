import 'package:flutter/foundation.dart';

/// Silences a known Flutter framework debug assertion on Windows.
///
/// Pressing Alt (Alt+Tab, Alt+Shift to switch the keyboard language, ...)
/// can deliver a key-down whose modifier flags are already cleared, which
/// trips `'event is! RawKeyDownEvent || _keysPressed.isNotEmpty'` in
/// `raw_keyboard.dart`. It is debug-only (asserts are stripped from release
/// builds) and the app code never uses the raw keyboard, so it is dropped
/// here; every other error still reaches the previous handler.
void installFrameworkErrorFilter() {
  if (!kDebugMode) return;
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isRawKeyboardModifierAssertion(details)) return;
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  };
}

bool _isRawKeyboardModifierAssertion(FlutterErrorDetails details) =>
    details.exception is AssertionError &&
    details.exception.toString().contains('_keysPressed.isNotEmpty') &&
    (details.stack?.toString().contains('raw_keyboard.dart') ?? false);
