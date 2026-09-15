import 'package:equatable/equatable.dart';

import 'order_status.dart';
import 'order_summary_item.dart';
import 'order_type.dart';

class OrderSummary extends Equatable {
  const OrderSummary({
    required this.id,
    required this.type,
    required this.customerName,
    required this.status,
    required this.itemCount,
    required this.timeAgo,
    required this.items,
    required this.total,
    this.backendId,
    this.paymentStatus = 'unpaid',
    String? displayNumber,
  }) : displayNumber = displayNumber ?? '#$id';

  final String id;
  final int? backendId;
  final String displayNumber;
  final OrderSummaryType type;
  final String customerName;
  final OrderStatus status;

  /// Sum of quantities on non-deleted order lines, not the preview length.
  final double itemCount;
  final String timeAgo;
  final List<OrderSummaryItem> items;
  final double total;
  final String paymentStatus;

  bool get canPay {
    final String normalizedPaymentStatus = paymentStatus.toLowerCase();
    return normalizedPaymentStatus == 'unpaid' &&
        (status == OrderStatus.preparing || status == OrderStatus.held) &&
        total > 0;
  }

  bool get canResume {
    return status == OrderStatus.held &&
        paymentStatus.toLowerCase() == 'unpaid';
  }

  bool get canCancel {
    return (status == OrderStatus.preparing || status == OrderStatus.held) &&
        paymentStatus.toLowerCase() == 'unpaid';
  }

  OrderSummary copyWith({OrderStatus? status, String? paymentStatus}) {
    return OrderSummary(
      id: id,
      backendId: backendId,
      displayNumber: displayNumber,
      type: type,
      customerName: customerName,
      status: status ?? this.status,
      itemCount: itemCount,
      timeAgo: timeAgo,
      items: items,
      total: total,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    backendId,
    displayNumber,
    type,
    customerName,
    status,
    itemCount,
    timeAgo,
    items,
    total,
    paymentStatus,
  ];
}
