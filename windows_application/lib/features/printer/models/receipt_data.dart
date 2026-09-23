import '../../pos/models/json_helpers.dart';

/// Values are copied from GET orders/{id}/receipt. No totals are calculated here.
class ReceiptData {
  const ReceiptData({
    this.orderId,
    required this.orderNumber,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.total,
    this.title,
    this.branchName,
    this.addressLines = const [],
    this.cashierName,
    this.customerName,
    this.payment,
    this.footerLines = const [],
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    final paymentJson = json['payment'];
    return ReceiptData(
      orderId: readInt(json['orderId']),
      orderNumber: readString(json['orderNumber']),
      date: readString(json['date']),
      title: _optional(json['title']),
      branchName: _optional(json['branchName']),
      addressLines: _strings(json['addressLines']),
      cashierName: _optional(json['cashierName']),
      customerName: _optional(json['customerName']),
      items: readMapList(json['items']).map(ReceiptItem.fromJson).toList(),
      subtotal: readDouble(json['subtotal']),
      discountTotal: readDouble(json['discountTotal']),
      taxTotal: readDouble(json['taxTotal']),
      total: readDouble(json['total']),
      payment: paymentJson is Map
          ? ReceiptPayment.fromJson(paymentJson.cast<String, dynamic>())
          : null,
      footerLines: _strings(json['footerLines']),
    );
  }

  final int? orderId;
  final String orderNumber;
  final String date;
  final String? title;
  final String? branchName;
  final List<String> addressLines;
  final String? cashierName;
  final String? customerName;
  final List<ReceiptItem> items;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double total;
  final ReceiptPayment? payment;
  final List<String> footerLines;
}

class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.modifiers = const [],
    this.note,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
    name: readString(json['name']),
    quantity: readDouble(json['quantity']),
    unitPrice: readDouble(json['unitPrice']),
    lineTotal: readDouble(json['lineTotal']),
    modifiers: readMapList(json['modifiers'])
        .map((modifier) => _optional(modifier['name']))
        .whereType<String>()
        .toList(),
    note: _optional(json['note']),
  );

  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final List<String> modifiers;
  final String? note;
}

class ReceiptPayment {
  const ReceiptPayment({
    required this.method,
    required this.amount,
    this.reference,
    this.changeDue,
  });

  factory ReceiptPayment.fromJson(Map<String, dynamic> json) => ReceiptPayment(
    method: _optional(json['method']),
    amount: readDouble(json['amount']),
    reference: _optional(json['reference']),
    changeDue: json['changeDue'] is num ? readDouble(json['changeDue']) : null,
  );

  final String? method;
  final double amount;
  final String? reference;
  final double? changeDue;
}

String? _optional(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

List<String> _strings(Object? value) => value is List
    ? value.map(_optional).whereType<String>().toList(growable: false)
    : const <String>[];
