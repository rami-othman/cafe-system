/// Digits-only international number for a WhatsApp link, or null when [raw]
/// cannot be one. Mirrors the backend's WhatsAppCloudService::normalizePhone.
String? normalizeWhatsAppPhone(
  String raw, {
  String defaultCountryCode = '963',
}) {
  const Map<String, String> digitMap = <String, String>{
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  };
  String text = raw.trim();
  digitMap.forEach((String from, String to) => text = text.replaceAll(from, to));
  final bool hasPlus = text.startsWith('+');
  String digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (!hasPlus && digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (!hasPlus && digits.startsWith('0')) {
    digits = '$defaultCountryCode${digits.replaceFirst(RegExp(r'^0+'), '')}';
  }
  return digits.length >= 8 && digits.length <= 15 ? digits : null;
}
