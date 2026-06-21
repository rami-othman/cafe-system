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
    String? displayNumber,
  }) : displayNumber = displayNumber ?? '#$id';

  final String id;
  final int? backendId;
  final String displayNumber;
  final OrderSummaryType type;
  final String customerName;
  final OrderStatus status;
  final int itemCount;
  final String timeAgo;
  final List<OrderSummaryItem> items;
  final double total;

  OrderSummary copyWith({OrderStatus? status}) {
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
  ];
}
