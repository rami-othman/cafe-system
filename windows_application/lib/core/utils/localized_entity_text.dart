import 'package:flutter/widgets.dart';

/// Chooses a backend-provided localized field without changing the model.
abstract final class LocalizedEntityText {
  static String resolve({
    required Locale locale,
    String? defaultValue,
    String? arabicValue,
    String? englishValue,
    String fallback = '',
  }) {
    final List<String?> values = locale.languageCode == 'ar'
        ? <String?>[arabicValue, defaultValue, englishValue]
        : <String?>[englishValue, defaultValue, arabicValue];
    for (final String? value in values) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return fallback;
  }
}
