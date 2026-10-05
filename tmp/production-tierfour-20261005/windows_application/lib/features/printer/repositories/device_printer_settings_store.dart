import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_config.dart';

abstract interface class DevicePrinterSettingsStore {
  Future<DevicePrinterSettings> read({required int tenantId});
  Future<void> write({
    required int tenantId,
    required DevicePrinterSettings settings,
  });
}

class SharedPreferencesDevicePrinterSettingsStore
    implements DevicePrinterSettingsStore {
  static const String _keyPrefix = 'cafe_system.device_printer.v1.';

  @override
  Future<DevicePrinterSettings> read({required int tenantId}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? value = preferences.getString('$_keyPrefix$tenantId');
    if (value == null) return const DevicePrinterSettings();
    try {
      final dynamic decoded = jsonDecode(value);
      if (decoded is! Map) return const DevicePrinterSettings();
      return DevicePrinterSettings.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const DevicePrinterSettings();
    }
  }

  @override
  Future<void> write({
    required int tenantId,
    required DevicePrinterSettings settings,
  }) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix$tenantId',
      jsonEncode(settings.toJson()),
    );
  }
}
