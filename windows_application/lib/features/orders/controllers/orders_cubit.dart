import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/order_status.dart';
import '../models/order_summary.dart';
import '../models/refund_result.dart';
import '../models/refund_type.dart';
import '../repositories/orders_repository.dart';
import 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required this.repository}) : super(const OrdersState());

  final OrdersRepository repository;

  Future<void> loadOrders() async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      emit(
        state.copyWith(
          orders: repository.getOrders(),
          isLoading: false,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }

  void selectFilter(OrdersFilter filter) {
    emit(state.copyWith(selectedFilter: filter));
  }

  Future<void> openOrderDetails(String orderId) async {
    emit(
      state.copyWith(isDetailsLoading: true, clearDetailsErrorMessage: true),
    );

    try {
      final detail = await repository.getOrderDetail(orderId);

      emit(
        state.copyWith(
          selectedOrderDetail: detail,
          isDetailsLoading: false,
          clearDetailsErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isDetailsLoading: false,
          detailsErrorMessage: error.toString(),
        ),
      );
    }
  }

  void closeOrderDetails() {
    emit(
      state.copyWith(
        clearSelectedOrderDetail: true,
        isDetailsLoading: false,
        clearDetailsErrorMessage: true,
      ),
    );
  }

  void confirmRefund(RefundResult result) {
    final selectedDetail = state.selectedOrderDetail;
    if (selectedDetail == null || selectedDetail.id != result.orderId) {
      return;
    }

    final OrderStatus status = result.type == RefundType.full
        ? OrderStatus.refunded
        : OrderStatus.partiallyRefunded;
    final updatedDetail = selectedDetail.copyWith(
      status: status,
      isRefunded: result.type == RefundType.full,
      refundedAmount: result.amount,
      refundedAt: result.refundedAt,
    );
    final List<OrderSummary> orders = state.orders
        .map((OrderSummary order) {
          if (order.id != result.orderId) {
            return order;
          }

          return order.copyWith(status: status);
        })
        .toList(growable: false);

    emit(state.copyWith(orders: orders, selectedOrderDetail: updatedDetail));
  }

  void cancelOrder(String orderId) {
    _updateStatus(orderId, OrderStatus.cancelled);
  }

  void completeOrder(String orderId) {
    _updateStatus(orderId, OrderStatus.completed);
  }

  void _updateStatus(String orderId, OrderStatus status) {
    final List<OrderSummary> orders = state.orders
        .map((OrderSummary order) {
          if (order.id != orderId) {
            return order;
          }

          return order.copyWith(status: status);
        })
        .toList(growable: false);

    emit(state.copyWith(orders: orders));
  }
}
