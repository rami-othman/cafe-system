import 'json_helpers.dart';
import 'order_receipt.dart';
import 'payment_method.dart';
import 'payment_result.dart';
import 'receipt_line_item.dart';

OrderReceipt orderReceiptFromJson(Map<String, dynamic> json) {
  final Map<String, dynamic> payment = Map<String, dynamic>.from(
    json['payment'] as Map? ?? <String, dynamic>{},
  );
  final double total = readDouble(json['total']);
  final double amount = readDouble(
    payment['amountReceived'],
    fallback: readDouble(payment['amount'], fallback: total),
  );

  return OrderReceipt(
    orderNumber: readString(json['orderNumber']),
    branchName: readString(json['branchName'], fallback: 'Cafe System 618'),
    cashierName: readString(json['cashierName'], fallback: 'POS Register'),
    completedAt:
        DateTime.tryParse(readString(json['date']))?.toLocal() ??
        DateTime.now(),
    items: readMapList(
      json['items'],
    ).map(_receiptLineFromJson).toList(growable: false),
    subtotal: readDouble(json['subtotal']),
    discountTotal: readDouble(json['discountTotal']),
    discountLabel: readDouble(json['discountTotal']) > 0 ? 'Discount' : null,
    tax: readDouble(json['taxTotal']),
    total: total,
    payment: PaymentResult(
      method: paymentMethodFromApi(readString(payment['method'])),
      totalDue: total,
      amountReceived: amount,
      changeDue: (amount - total).clamp(0, double.infinity).toDouble(),
      status:
          readString(
            payment['status'],
            fallback: readString(json['paymentStatus']),
          ).trim().isEmpty
          ? null
          : readString(
              payment['status'],
              fallback: readString(json['paymentStatus']),
            ).trim(),
      paymentId: readInt(payment['id']) ?? readInt(json['paymentId']),
    ),
  );
}

ReceiptLineItem _receiptLineFromJson(Map<String, dynamic> json) {
  final List<String> modifiers = readMapList(json['modifiers'])
      .map((Map<String, dynamic> modifier) => readString(modifier['name']))
      .where((String label) => label.trim().isNotEmpty)
      .toList(growable: false);

  return ReceiptLineItem(
    name: readString(json['name']),
    quantity: readDouble(json['quantity']).round(),
    unitPrice: readDouble(json['unitPrice']),
    lineTotal: readDouble(json['lineTotal']),
    modifiers: modifiers,
    specialInstructions: readString(json['note']).trim().isEmpty
        ? null
        : readString(json['note']).trim(),
  );
}
