import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug-only diagnostics for the manager Menu schedule check workflow.
///
/// This intentionally never returns data to the UI. It is kept as a small
/// boundary utility so every hop can retain the original exception and stack.
class ScheduleCheckDebug {
  const ScheduleCheckDebug._();

  static void log(String message) {
    if (!kDebugMode) return;
    debugPrint('[menu-schedule-check] $message');
  }

  static void json(String label, Object? value) {
    if (!kDebugMode) return;
    try {
      debugPrint('[menu-schedule-check] $label: ${jsonEncode(value)}');
    } catch (_) {
      debugPrint('[menu-schedule-check] $label: $value');
    }
  }

  static void failure(String stage, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[menu-schedule-check] FAILURE at $stage: $error');
    debugPrintStack(stackTrace: stackTrace, label: '[menu-schedule-check]');
  }

  static void responseShape(Object? body) {
    if (!kDebugMode) return;
    if (body is! Map) {
      log('response raw type=${body.runtimeType}');
      return;
    }
    final Map<Object?, Object?> map = Map<Object?, Object?>.from(body);
    final Object? data = map['data'];
    log(
      'response top-level keys=${map.keys.toList()} dataType=${data.runtimeType}',
    );
    if (data is! Map) return;
    final Map<Object?, Object?> dataMap = Map<Object?, Object?>.from(data);
    final Object? menus = dataMap['menus'];
    log(
      'response data keys=${dataMap.keys.toList()} menusType=${menus.runtimeType}',
    );
    if (menus is! List) return;
    log('response menus length=${menus.length}');
    if (menus.isNotEmpty && menus.first is Map) {
      log('response first menu keys=${(menus.first as Map).keys.toList()}');
    }
  }
}
