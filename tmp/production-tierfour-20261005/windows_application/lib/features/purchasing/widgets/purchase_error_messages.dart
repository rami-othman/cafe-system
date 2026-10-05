import '../../../core/network/api_exception.dart';

/// F — the backend now returns line-specific Arabic messages directly
/// (e.g. "البند 3: تكلفة الوحدة غير صالحة"), keyed by the raw technical path
/// (e.g. "lines.2.unitCost") so API clients can still match on it. This
/// function's job is simply to join those messages for display.
///
/// The [_lineFieldLabels]/[_lineErrorKey] reconstruction below is kept only
/// as a defensive fallback for a backend response that still contains a raw
/// "lines.N.field"-shaped message (e.g. an older deployed backend) — normal
/// operation never reaches it.
const Map<String, String> _lineFieldLabels = <String, String>{
  'unitCost': 'تكلفة الوحدة',
  'lineGrossAmount': 'إجمالي البند',
  'quantity': 'الكمية',
  'description': 'البيان',
  'discountValue': 'قيمة الخصم',
  'taxAmount': 'الضريبة',
  'warehouseId': 'المخزن',
  'inventoryItemId': 'الصنف',
  'purchaseUnit': 'الوحدة',
};

final RegExp _lineErrorKey = RegExp(r'^lines\.(\d+)\.(\w+)$');
final RegExp _rawTechnicalPath = RegExp(r'lines\.\d+\.\w+');

String purchaseLineErrorMessage(Object error) {
  if (error is! ApiException) return '$error';
  final Map<String, List<String>>? validationErrors = error.validationErrors;
  if (validationErrors == null || validationErrors.isEmpty) {
    return error.message;
  }
  final List<String> lineMessages = <String>[];
  for (final MapEntry<String, List<String>> entry in validationErrors.entries) {
    final RegExpMatch? match = _lineErrorKey.firstMatch(entry.key);
    if (match == null) continue;
    final String backendMessage = entry.value.isNotEmpty
        ? entry.value.first
        : '';
    if (backendMessage.isNotEmpty &&
        !_rawTechnicalPath.hasMatch(backendMessage)) {
      // The backend already produced a clean "البند N: ..." message.
      lineMessages.add(backendMessage);
      continue;
    }
    final int oneBasedLine = int.parse(match.group(1)!) + 1;
    final String field = match.group(2)!;
    final String label = _lineFieldLabels[field] ?? field;
    lineMessages.add('البند $oneBasedLine: $label غير صالح.');
  }
  if (lineMessages.isEmpty) return error.message;
  return lineMessages.join('\n');
}
