import 'package:equatable/equatable.dart';

import '../models/order_status.dart';
import '../models/order_summary.dart';
import '../../pos/models/branch.dart';
import '../models/order_type.dart';
import '../models/order_detail.dart';

enum OrdersFilter { activeOrders, heldOrders, dineIn, takeaway }

extension OrdersFilterLabel on OrdersFilter {
  String get label {
    return switch (this) {
      OrdersFilter.activeOrders => 'ACTIVE ORDERS',
      OrdersFilter.heldOrders => 'HELD ORDERS',
      OrdersFilter.dineIn => 'DINE-IN',
      OrdersFilter.takeaway => 'TAKEAWAY',
    };
  }
}

class OrdersState extends Equatable {
  const OrdersState({
    this.orders = const <OrderSummary>[],
    this.branches = const <Branch>[],
    this.selectedBranchId,
    this.selectedFilter = OrdersFilter.activeOrders,
    this.isLoading = false,
    this.errorMessage,
    this.selectedOrderDetail,
    this.isDetailsLoading = false,
    this.detailsErrorMessage,
  });

  final List<OrderSummary> orders;
  final List<Branch> branches;
  final int? selectedBranchId;
  final OrdersFilter selectedFilter;
  final bool isLoading;
  final String? errorMessage;
  final OrderDetail? selectedOrderDetail;
  final bool isDetailsLoading;
  final String? detailsErrorMessage;

  List<OrderSummary> get filteredOrders {
    return orders
        .where((OrderSummary order) {
          return switch (selectedFilter) {
            OrdersFilter.activeOrders =>
              order.status == OrderStatus.preparing ||
                  order.status == OrderStatus.ready,
            OrdersFilter.heldOrders => order.status == OrderStatus.held,
            OrdersFilter.dineIn => order.type == OrderSummaryType.dineIn,
            OrdersFilter.takeaway => order.type == OrderSummaryType.takeaway,
          };
        })
        .toList(growable: false);
  }

  OrdersState copyWith({
    List<OrderSummary>? orders,
    List<Branch>? branches,
    int? selectedBranchId,
    OrdersFilter? selectedFilter,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    OrderDetail? selectedOrderDetail,
    bool clearSelectedOrderDetail = false,
    bool? isDetailsLoading,
    String? detailsErrorMessage,
    bool clearDetailsErrorMessage = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      branches: branches ?? this.branches,
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      selectedOrderDetail: clearSelectedOrderDetail
          ? null
          : selectedOrderDetail ?? this.selectedOrderDetail,
      isDetailsLoading: isDetailsLoading ?? this.isDetailsLoading,
      detailsErrorMessage: clearDetailsErrorMessage
          ? null
          : detailsErrorMessage ?? this.detailsErrorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    orders,
    branches,
    selectedBranchId,
    selectedFilter,
    isLoading,
    errorMessage,
    selectedOrderDetail,
    isDetailsLoading,
    detailsErrorMessage,
  ];
}
