import 'package:equatable/equatable.dart';

import 'order_payment_summary.dart';
import 'order_status.dart';
import 'order_timeline_event.dart';

class OrderDetail extends Equatable {
  const OrderDetail({
    required this.id,
    required this.displayNumber,
    required this.status,
    required this.orderType,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tip,
    required this.total,
    required this.payment,
    required this.timeline,
    this.isRefunded = false,
    this.refundedAmount = 0,
    this.refundedAt,
  });

  final String id;
  final String displayNumber;
  final OrderStatus status;
  final String orderType;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final List<OrderDetailItem> items;
  final double subtotal;
  final double tax;
  final double tip;
  final double total;
  final OrderPaymentSummary payment;
  final List<OrderTimelineEvent> timeline;
  final bool isRefunded;
  final double refundedAmount;
  final DateTime? refundedAt;

  bool get hasCustomer => customerName.trim().isNotEmpty;

  bool get hasRefund => refundedAmount > 0;

  OrderDetail copyWith({
    OrderStatus? status,
    bool? isRefunded,
    double? refundedAmount,
    DateTime? refundedAt,
  }) {
    return OrderDetail(
      id: id,
      displayNumber: displayNumber,
      status: status ?? this.status,
      orderType: orderType,
      createdAt: createdAt,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      items: items,
      subtotal: subtotal,
      tax: tax,
      tip: tip,
      total: total,
      payment: payment,
      timeline: timeline,
      isRefunded: isRefunded ?? this.isRefunded,
      refundedAmount: refundedAmount ?? this.refundedAmount,
      refundedAt: refundedAt ?? this.refundedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    displayNumber,
    status,
    orderType,
    createdAt,
    customerName,
    customerPhone,
    customerEmail,
    items,
    subtotal,
    tax,
    tip,
    total,
    payment,
    timeline,
    isRefunded,
    refundedAmount,
    refundedAt,
  ];
}

class OrderDetailItem extends Equatable {
  const OrderDetailItem({
    required this.quantity,
    required this.name,
    required this.modifiers,
    required this.total,
  });

  final int quantity;
  final String name;
  final List<String> modifiers;
  final double total;

  @override
  List<Object?> get props => <Object?>[quantity, name, modifiers, total];
}
