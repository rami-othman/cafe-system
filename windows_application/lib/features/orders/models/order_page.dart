import 'package:equatable/equatable.dart';

import 'order_summary.dart';

class OrderPage extends Equatable {
  const OrderPage({
    required this.orders,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory OrderPage.fromOrders(
    List<OrderSummary> orders, {
    required int page,
    required int perPage,
  }) {
    final int safePage = page > 0 ? page : 1;
    final int safePerPage = perPage > 0 ? perPage : orders.length.clamp(1, 100);
    final int total = orders.length;

    return OrderPage(
      orders: List<OrderSummary>.unmodifiable(orders),
      currentPage: safePage,
      lastPage: total == 0 ? 1 : ((total + safePerPage - 1) ~/ safePerPage),
      perPage: safePerPage,
      total: total,
    );
  }

  final List<OrderSummary> orders;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get canGoPrevious => currentPage > 1;
  bool get canGoNext => currentPage < lastPage;

  @override
  List<Object> get props => <Object>[
    orders,
    currentPage,
    lastPage,
    perPage,
    total,
  ];
}
