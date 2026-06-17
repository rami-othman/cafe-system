import 'package:equatable/equatable.dart';

import 'payment_result.dart';
import 'receipt_line_item.dart';

class OrderReceipt extends Equatable {
  const OrderReceipt({
    required this.orderNumber,
    required this.branchName,
    required this.cashierName,
    required this.completedAt,
    required this.items,
    required this.subtotal,
    required this.discountTotal,
    required this.discountLabel,
    required this.tax,
    required this.total,
    required this.payment,
    this.customerName,
  });

  final String orderNumber;
  final String branchName;
  final String cashierName;
  final DateTime completedAt;
  final List<ReceiptLineItem> items;
  final double subtotal;
  final double discountTotal;
  final String? discountLabel;
  final double tax;
  final double total;
  final PaymentResult payment;
  final String? customerName;

  int get itemCount {
    return items.fold<int>(
      0,
      (int total, ReceiptLineItem item) => total + item.quantity,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    orderNumber,
    branchName,
    cashierName,
    completedAt,
    items,
    subtotal,
    discountTotal,
    discountLabel,
    tax,
    total,
    payment,
    customerName,
  ];
}
