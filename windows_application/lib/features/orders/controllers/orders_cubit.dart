import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/order_status.dart';
import '../models/order_summary.dart';
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
