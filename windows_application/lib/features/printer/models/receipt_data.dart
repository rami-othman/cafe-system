import '../../pos/models/json_helpers.dart';
import 'receipt_template.dart';

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
    this.cafeName,
    this.logoUrl,
    this.branchName,
    this.address,
    this.phone,
    this.orderType,
    this.cashierName,
    this.customerName,
    this.payment,
    this.footerText,
    this.template = const ReceiptTemplate.defaultTemplate(),
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    final paymentJson = json['payment'];
    return ReceiptData(
      orderId: readInt(json['orderId']),
      orderNumber: readString(json['orderNumber']),
      date: readString(json['date']),
      cafeName: _optional(json['cafeName']),
      logoUrl: _optional(json['logoUrl']),
      branchName: _optional(json['branchName']),
      address: _optional(json['address']),
      phone: _optional(json['phone']),
      orderType: _optional(json['orderType']),
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
      footerText: _optional(json['footerText']),
      template: ReceiptTemplate.fromJson(json['template']),
    );
  }

  final int? orderId;
  final String orderNumber;
  final String date;
  final String? cafeName;
  final String? logoUrl;
  final String? branchName;
  final String? address;
  final String? phone;
  final String? orderType;
  final String? cashierName;
  final String? customerName;
  final List<ReceiptItem> items;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double total;
  final ReceiptPayment? payment;
  final String? footerText;
  final ReceiptTemplate template;

  ReceiptData copyWith({ReceiptTemplate? template}) => ReceiptData(
    orderId: orderId,
    orderNumber: orderNumber,
    date: date,
    items: items,
    subtotal: subtotal,
    discountTotal: discountTotal,
    taxTotal: taxTotal,
    total: total,
    cafeName: cafeName,
    logoUrl: logoUrl,
    branchName: branchName,
    address: address,
    phone: phone,
    orderType: orderType,
    cashierName: cashierName,
    customerName: customerName,
    payment: payment,
    footerText: footerText,
    template: template ?? this.template,
  );
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
