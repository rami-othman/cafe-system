import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../pos/models/branch.dart';
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
      final branches = state.branches.isEmpty
          ? await repository.getBranches()
          : state.branches;
      final selectedBranchId = _selectedBranchId(branches);
      if (selectedBranchId == null) {
        emit(
          state.copyWith(
            branches: branches,
            orders: const <OrderSummary>[],
            isLoading: false,
            errorMessage: 'No active branches are available.',
          ),
        );
        return;
      }

      _debugLog(
        'Loading orders for branch $selectedBranchId and filter '
        '${state.selectedFilter}',
      );
      emit(
        state.copyWith(
          branches: branches,
          selectedBranchId: selectedBranchId,
          orders: await repository.getOrders(
            branchId: selectedBranchId,
            filter: state.selectedFilter,
          ),
          isLoading: false,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not load orders. Check backend connection.',
        ),
      );
    }
  }

  Future<void> selectFilter(OrdersFilter filter) async {
    _debugLog('Selected filter $filter');
    emit(state.copyWith(selectedFilter: filter));
    await loadOrders();
  }

  Future<void> selectBranch(int branchId) async {
    if (state.selectedBranchId == branchId ||
        !state.branches.any((Branch branch) => branch.id == branchId)) {
      return;
    }

    _debugLog('Selected branch $branchId');
    emit(state.copyWith(selectedBranchId: branchId));
    await loadOrders();
  }

  Future<void> openOrderDetails(String orderId) async {
    emit(
      state.copyWith(isDetailsLoading: true, clearDetailsErrorMessage: true),
    );

    try {
      final int? backendId = int.tryParse(orderId);
      if (backendId == null) {
        throw StateError('Order id is not a backend id.');
      }
      _debugLog('Opening details for order $backendId');
      final detail = await repository.getOrderDetail(backendId);

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
          detailsErrorMessage:
              'Could not load order details. Check backend connection.',
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

  Future<void> refreshOrders() async {
    await loadOrders();
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

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[OrdersCubit] $message');
    }
  }

  int? _selectedBranchId(List<Branch> branches) {
    if (state.selectedBranchId != null &&
        branches.any((Branch branch) => branch.id == state.selectedBranchId)) {
      return state.selectedBranchId;
    }

    for (final Branch branch in branches) {
      if (branch.isActive) {
        return branch.id;
      }
    }

    return branches.isEmpty ? null : branches.first.id;
  }
}
