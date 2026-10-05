/// Normalizes user-typed decimal input into a plain ASCII form `double.parse`
/// understands: Arabic-Indic/Persian digits, the Arabic decimal separator
/// (٫), a bare leading `.`, and `,` used as a decimal separator (this app's
/// numeric-entry convention — never a thousands grouping the user typed).
///
/// This is the one place that does this translation; number-entry fields
/// across the app should route through it instead of calling
/// `double.tryParse`/`num.tryParse` directly on raw controller text.
abstract final class NumericInput {
  static const Map<String, String> _digits = <String, String>{
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  };

  /// Returns an ASCII decimal string (`.` separator), or null when [raw]
  /// has no parseable numeric content.
  static String? normalize(String raw) {
    String text = raw.trim();
    if (text.isEmpty) return null;
    _digits.forEach((String from, String to) => text = text.replaceAll(from, to));
    text = text.replaceAll('٬', ''); // Arabic thousands separator — discard.
    text = text.replaceAll('٫', '.'); // Arabic decimal separator.
    if (text.contains(',')) {
      // A single comma with no `.` present is a decimal separator here;
      // otherwise it's noise (e.g. copied from a formatted "1,234.56").
      text = text.contains('.') ? text.replaceAll(',', '') : text.replaceAll(',', '.');
    }
    if (text.startsWith('.')) text = '0$text';
    if (text.startsWith('-.')) text = '-0${text.substring(1)}';
    if (text.isEmpty || text == '-') return null;
    return text;
  }

  /// Parses [raw] through [normalize], returning null instead of 0 when
  /// nothing parseable was entered — callers that want a numeric default
  /// should do `NumericInput.parse(x) ?? 0` explicitly.
  static double? parse(String raw) {
    final String? normalized = normalize(raw);
    if (normalized == null) return null;
    return double.tryParse(normalized);
  }
}
