import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug-only diagnostics for the production Menu Schedule save flow.
///
/// The drawer never consumes these messages. They retain enough detail to
/// trace a failed sync without exposing transport or backend internals to a
/// manager-facing error banner.
class MenuScheduleSaveDebug {
  const MenuScheduleSaveDebug._();

  static void log(String message) {
    if (!kDebugMode) return;
    debugPrint('[menu-schedule-save] $message');
  }

  static void json(String label, Object? value) {
    if (!kDebugMode) return;
    try {
      debugPrint('[menu-schedule-save] $label: ${jsonEncode(value)}');
    } catch (_) {
      debugPrint('[menu-schedule-save] $label: $value');
    }
  }

  static void failure(String stage, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[menu-schedule-save] FAILURE at $stage: $error');
    debugPrintStack(stackTrace: stackTrace, label: '[menu-schedule-save]');
  }
}
