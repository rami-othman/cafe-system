import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
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
  int _ordersRequestVersion = 0;
  int _detailsRequestVersion = 0;

  Future<void> loadOrders({OrdersFilter? filter, int? branchId}) async {
    final int requestVersion = ++_ordersRequestVersion;
    final OrdersFilter selectedFilter = filter ?? state.selectedFilter;
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final branches = state.branches.isEmpty
          ? await repository.getBranches()
          : state.branches;
      if (!_isCurrentOrdersRequest(requestVersion)) {
        return;
      }

      final selectedBranchId = _selectedBranchId(branches, branchId: branchId);
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
        '$selectedFilter',
      );
      final List<OrderSummary> orders = await repository.getOrders(
        branchId: selectedBranchId,
        filter: selectedFilter,
      );
      if (!_isCurrentOrdersRequest(requestVersion)) {
        return;
      }

      emit(
        state.copyWith(
          branches: branches,
          selectedBranchId: selectedBranchId,
          orders: orders,
          isLoading: false,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      if (!_isCurrentOrdersRequest(requestVersion)) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _messageFor(
            error,
            fallback: 'Could not load orders. Check backend connection.',
          ),
        ),
      );
    }
  }

  Future<void> selectFilter(OrdersFilter filter) async {
    _debugLog('Selected filter $filter');
    emit(state.copyWith(selectedFilter: filter));
    await loadOrders(filter: filter);
  }

  /// Mirrors the session POS branch context for order listing. This is never a
  /// user-selectable Orders value; the route receives the authoritative branch
  /// from the POS workspace while it is mounted.
  Future<void> applyBranchContext(int branchId) async {
    if (state.selectedBranchId == branchId ||
        !state.branches.any((Branch branch) => branch.id == branchId)) {
      return;
    }

    _debugLog('Applying POS branch context $branchId');
    emit(state.copyWith(selectedBranchId: branchId));
    await loadOrders(branchId: branchId);
  }

  Future<void> openOrderDetails(String orderId) async {
    final int requestVersion = ++_detailsRequestVersion;
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
      if (!_isCurrentDetailsRequest(requestVersion)) {
        return;
      }

      emit(
        state.copyWith(
          selectedOrderDetail: detail,
          isDetailsLoading: false,
          clearDetailsErrorMessage: true,
        ),
      );
    } catch (error) {
      if (!_isCurrentDetailsRequest(requestVersion)) {
        return;
      }
      emit(
        state.copyWith(
          isDetailsLoading: false,
          detailsErrorMessage: _messageFor(
            error,
            fallback: 'Could not load order details. Check backend connection.',
          ),
        ),
      );
    }
  }

  void closeOrderDetails() {
    _detailsRequestVersion++;
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

  Future<void> submitRefund(RefundResult request) async {
    final RefundResult result = await repository.submitRefund(
      request: request,
      idempotencyKey: _operationKey(),
    );
    confirmRefund(result);
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

  String _operationKey() =>
      'refund-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  int? _selectedBranchId(List<Branch> branches, {int? branchId}) {
    if (branchId != null &&
        branches.any((Branch branch) => branch.id == branchId)) {
      return branchId;
    }
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

  bool _isCurrentOrdersRequest(int requestVersion) {
    return !isClosed && requestVersion == _ordersRequestVersion;
  }

  bool _isCurrentDetailsRequest(int requestVersion) {
    return !isClosed && requestVersion == _detailsRequestVersion;
  }

  String _messageFor(Object error, {required String fallback}) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }

    return fallback;
  }
}
