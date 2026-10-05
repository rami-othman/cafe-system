import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../pos/models/branch.dart';
import '../../pos/models/order_receipt.dart';
import '../../pos/models/payment_method.dart';
import '../../pos/models/payment_result.dart';
import '../../pos/models/payment_summary.dart';
import '../models/order_detail.dart';
import '../models/order_page.dart';
import '../models/order_payment_summary.dart';
import '../models/order_status.dart';
import '../models/order_summary.dart';
import '../models/order_refund.dart';
import '../models/refund_result.dart';
import '../models/refund_type.dart';
import '../repositories/orders_repository.dart';
import 'orders_state.dart';

enum RefundCompletionStatus { completed, retryableFailure, uncertain }

enum OrdersActionOutcome { confirmed, retryableFailure, uncertain, stale }

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    required this.repository,
    String Function(String operation)? operationKeyGenerator,
  }) : _operationKeyGenerator = operationKeyGenerator ?? _defaultOperationKey,
       super(const OrdersState());

  final OrdersRepository repository;
  final String Function(String operation) _operationKeyGenerator;
  int _ordersRequestVersion = 0;
  int _detailsRequestVersion = 0;
  String? _inFlightOrdersKey;
  int? _inFlightOrdersVersion;
  String? _pendingRefundFingerprint;
  String? _pendingRefundKey;
  String? _uncertainRefundFingerprint;
  int _paymentRequestVersion = 0;
  Future<PaymentSummary?>? _inFlightPaymentPreparation;
  String? _inFlightPaymentOrderId;
  int? _pendingPaymentOrderId;
  String? _pendingPaymentFingerprint;
  String? _pendingPaymentKey;
  PaymentResult? _pendingPaymentRequest;
  String? _uncertainPaymentFingerprint;
  int _receiptRequestGeneration = 0;
  int _orderActionRequestVersion = 0;
  String? _orderActionContextKey;
  String? _detailsOrderId;

  Future<void> loadOrders({
    OrdersFilter? filter,
    int? branchId,
    int? page,
  }) async {
    if (isClosed) {
      return;
    }

    _invalidateOrderActionForContextIfNeeded();

    final OrdersFilter selectedFilter = filter ?? state.selectedFilter;
    final int requestedPage = max(page ?? 1, 1);
    final int requestedPerPage = state.perPage > 0 ? state.perPage : 25;
    final int? knownBranchId = branchId ?? state.selectedBranchId;
    final String requestKey = knownBranchId == null
        ? _initialOrdersRequestKey(
            filter: selectedFilter,
            page: requestedPage,
            perPage: requestedPerPage,
          )
        : _ordersRequestKey(
            branchId: knownBranchId,
            filter: selectedFilter,
            page: requestedPage,
            perPage: requestedPerPage,
          );
    if (_inFlightOrdersKey == requestKey) {
      return;
    }
    final int requestVersion = ++_ordersRequestVersion;
    _inFlightOrdersKey = requestKey;
    _inFlightOrdersVersion = requestVersion;

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
            isPageLoading: false,
            errorMessage: 'No active branches are available.',
          ),
        );
        return;
      }

      _debugLog(
        'Loading orders for branch $selectedBranchId and filter '
        '$selectedFilter on page $requestedPage',
      );
      final String requestKey = _ordersRequestKey(
        branchId: selectedBranchId,
        filter: selectedFilter,
        page: requestedPage,
        perPage: requestedPerPage,
      );
      if (_inFlightOrdersVersion == requestVersion) {
        _inFlightOrdersKey = requestKey;
      }
      emit(
        state.copyWith(
          branches: branches,
          selectedBranchId: selectedBranchId,
          selectedFilter: selectedFilter,
          isLoading: requestedPage == 1,
          isPageLoading: requestedPage > 1,
          clearErrorMessage: true,
        ),
      );
      final OrderPage result = await repository.getOrders(
        branchId: selectedBranchId,
        filter: selectedFilter,
        page: requestedPage,
        perPage: requestedPerPage,
      );
      if (!_isCurrentOrdersRequest(requestVersion)) {
        return;
      }

      if (_needsPageRecovery(result, requestedPage)) {
        final int recoveryPage = max(result.lastPage, 1);
        _debugLog(
          'Requested page $requestedPage is beyond last page '
          '${result.lastPage}; recovering with page $recoveryPage',
        );
        final OrderPage recovered = await repository.getOrders(
          branchId: selectedBranchId,
          filter: selectedFilter,
          page: recoveryPage,
          perPage: requestedPerPage,
        );
        if (!_isCurrentOrdersRequest(requestVersion)) {
          return;
        }
        if (_needsPageRecovery(recovered, recoveryPage)) {
          throw StateError(
            'Order page recovery returned invalid pagination metadata.',
          );
        }
        _emitOrdersPage(
          branches: branches,
          selectedBranchId: selectedBranchId,
          result: recovered,
        );
        return;
      }

      _emitOrdersPage(
        branches: branches,
        selectedBranchId: selectedBranchId,
        result: result,
      );
    } catch (error) {
      if (!_isCurrentOrdersRequest(requestVersion)) {
        return;
      }
      emit(
        state.copyWith(
          isLoading: false,
          isPageLoading: false,
          errorMessage: _messageFor(
            error,
            fallback: 'Could not load orders. Check backend connection.',
          ),
        ),
      );
    } finally {
      if (_inFlightOrdersVersion == requestVersion) {
        _inFlightOrdersKey = null;
        _inFlightOrdersVersion = null;
      }
    }
  }

  Future<void> selectFilter(OrdersFilter filter) async {
    if (isClosed || filter == state.selectedFilter) {
      return;
    }
    _debugLog('Selected filter $filter');
    emit(
      state.copyWith(
        selectedFilter: filter,
        currentPage: 1,
        lastPage: 1,
        total: 0,
      ),
    );
    await loadOrders(filter: filter, page: 1);
  }

  /// Mirrors the session POS branch context for order listing. This is never a
  /// user-selectable Orders value; the route receives the authoritative branch
  /// from the POS workspace while it is mounted.
  Future<void> applyBranchContext(int branchId) async {
    if (isClosed) {
      return;
    }
    if (state.selectedBranchId == branchId ||
        !state.branches.any((Branch branch) => branch.id == branchId)) {
      return;
    }

    _debugLog('Applying POS branch context $branchId');
    emit(
      state.copyWith(
        selectedBranchId: branchId,
        currentPage: 1,
        lastPage: 1,
        total: 0,
      ),
    );
    await loadOrders(branchId: branchId, page: 1);
  }

  Future<void> openOrderDetails(String orderId) async {
    _invalidatePaymentPreparationForSelection(orderId);
    _detailsOrderId = orderId;
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
    _detailsOrderId = null;
    emit(
      state.copyWith(
        clearSelectedOrderDetail: true,
        isDetailsLoading: false,
        clearDetailsErrorMessage: true,
      ),
    );
  }

  Future<void> refreshOrders() async {
    await loadOrders(page: state.currentPage);
  }

  Future<OrdersActionOutcome> resumeOrder(
    String orderId, {
    required Future<bool> Function(String orderId) loadIntoPos,
  }) async {
    final int? backendId = int.tryParse(orderId);
    if (backendId == null || backendId <= 0) {
      return _setImmediateOrderActionFailure(
        orderId,
        'This order cannot be resumed because its backend id is invalid.',
      );
    }
    if (!_canStartOrderAction()) {
      return state.uncertainOrderActionMessage != null
          ? OrdersActionOutcome.uncertain
          : OrdersActionOutcome.retryableFailure;
    }

    final String contextKey = _ordersActionContextKey();
    final int requestVersion = ++_orderActionRequestVersion;
    _orderActionContextKey = contextKey;
    _emitOrderActionState(
      orderId: orderId,
      status: OrdersActionStatus.preparing,
    );

    try {
      final OrderDetail detail = await repository.getOrderDetail(backendId);
      if (!_isCurrentOrderAction(requestVersion, orderId, contextKey)) {
        return OrdersActionOutcome.stale;
      }
      if (!_isCurrentOrdersActionContext(contextKey)) {
        return OrdersActionOutcome.stale;
      }
      if (int.tryParse(detail.id) != backendId) {
        return _finishRetryableOrderAction(
          requestVersion,
          orderId,
          contextKey,
          'The backend returned a different order. Refresh and try again.',
        );
      }
      if (detail.branchId != null &&
          detail.branchId != state.selectedBranchId) {
        return _finishRetryableOrderAction(
          requestVersion,
          orderId,
          contextKey,
          'This order is not in the selected branch.',
        );
      }
      if (!detail.canResume) {
        return _finishRetryableOrderAction(
          requestVersion,
          orderId,
          contextKey,
          detail.resumeBlockedReason ??
              'Only an unpaid held order can be resumed.',
        );
      }

      emit(
        state.copyWith(
          orderActionStatus: OrdersActionStatus.submitting,
          clearOrderActionErrorMessage: true,
          clearUncertainOrderActionMessage: true,
        ),
      );
      final bool loaded = await loadIntoPos(orderId);
      if (!_isCurrentOrderAction(requestVersion, orderId, contextKey)) {
        return OrdersActionOutcome.stale;
      }
      if (!_isCurrentOrdersActionContext(contextKey)) {
        return OrdersActionOutcome.stale;
      }
      if (!loaded) {
        return _finishRetryableOrderAction(
          requestVersion,
          orderId,
          contextKey,
          'Could not resume this order in POS. Please try again.',
        );
      }

      emit(
        state.copyWith(
          orderActionStatus: OrdersActionStatus.confirmed,
          clearOrderActionErrorMessage: true,
          clearUncertainOrderActionMessage: true,
        ),
      );
      return OrdersActionOutcome.confirmed;
    } catch (error) {
      if (!_isCurrentOrderAction(requestVersion, orderId, contextKey)) {
        return OrdersActionOutcome.stale;
      }
      return _finishRetryableOrderAction(
        requestVersion,
        orderId,
        contextKey,
        _messageFor(
          error,
          fallback: 'Could not resume this order. Check backend connection.',
        ),
      );
    }
  }

  Future<OrdersActionOutcome> cancelOrder(String orderId) async {
    final int? backendId = int.tryParse(orderId);
    if (backendId == null || backendId <= 0) {
      return _setImmediateOrderActionFailure(
        orderId,
        'This order cannot be cancelled because its backend id is invalid.',
      );
    }
    if (!_canStartOrderAction()) {
      return state.uncertainOrderActionMessage != null
          ? OrdersActionOutcome.uncertain
          : OrdersActionOutcome.retryableFailure;
    }

    final String contextKey = _ordersActionContextKey();
    final int requestVersion = ++_orderActionRequestVersion;
    _orderActionContextKey = contextKey;
    _emitOrderActionState(
      orderId: orderId,
      status: OrdersActionStatus.preparing,
    );

    late final OrderDetail detail;
    try {
      detail = await repository.getOrderDetail(backendId);
    } catch (error) {
      if (!_isCurrentOrderAction(requestVersion, orderId, contextKey)) {
        return OrdersActionOutcome.stale;
      }
      return _finishRetryableOrderAction(
        requestVersion,
        orderId,
        contextKey,
        _messageFor(
          error,
          fallback: 'Could not verify this order before cancellation.',
        ),
      );
    }

    if (!_isCurrentOrderAction(requestVersion, orderId, contextKey) ||
        !_isCurrentOrdersActionContext(contextKey)) {
      return OrdersActionOutcome.stale;
    }
    if (int.tryParse(detail.id) != backendId) {
      return _finishRetryableOrderAction(
        requestVersion,
        orderId,
        contextKey,
        'The backend returned a different order. Refresh and try again.',
      );
    }
    if (detail.branchId != null && detail.branchId != state.selectedBranchId) {
      return _finishRetryableOrderAction(
        requestVersion,
        orderId,
        contextKey,
        'This order is not in the selected branch.',
      );
    }
    if (!detail.canCancel) {
      return _finishRetryableOrderAction(
        requestVersion,
        orderId,
        contextKey,
        'Only an unpaid draft or held order can be cancelled.',
      );
    }

    if (_detailsOrderId == orderId && state.selectedOrderDetail != detail) {
      emit(
        state.copyWith(
          selectedOrderDetail: detail,
          clearDetailsErrorMessage: true,
        ),
      );
    }
    emit(
      state.copyWith(
        orderActionStatus: OrdersActionStatus.submitting,
        clearOrderActionErrorMessage: true,
        clearUncertainOrderActionMessage: true,
      ),
    );

    try {
      await repository.cancelOrder(backendId);
      return _confirmCancellation(requestVersion, orderId, contextKey);
    } catch (error) {
      if (!_isCurrentOrderAction(requestVersion, orderId, contextKey)) {
        return OrdersActionOutcome.stale;
      }
      if (_isUncertainCancellationFailure(error)) {
        return _verifyUncertainCancellation(
          requestVersion: requestVersion,
          orderId: orderId,
          contextKey: contextKey,
        );
      }
      return _finishRetryableOrderAction(
        requestVersion,
        orderId,
        contextKey,
        _messageFor(
          error,
          fallback: 'Could not cancel this order. No changes were confirmed.',
        ),
      );
    }
  }

  Future<OrdersActionOutcome> checkUncertainOrderActionStatus() async {
    final String? orderId = state.actionOrderId;
    final String? contextKey = _orderActionContextKey;
    if (orderId == null ||
        contextKey == null ||
        state.orderActionStatus != OrdersActionStatus.uncertain ||
        !_isCurrentOrdersActionContext(contextKey)) {
      return OrdersActionOutcome.stale;
    }
    final int requestVersion = ++_orderActionRequestVersion;
    emit(
      state.copyWith(
        orderActionStatus: OrdersActionStatus.submitting,
        clearOrderActionErrorMessage: true,
      ),
    );
    return _verifyUncertainCancellation(
      requestVersion: requestVersion,
      orderId: orderId,
      contextKey: contextKey,
    );
  }

  Future<PaymentSummary?> preparePayment(String orderId) {
    if (isClosed ||
        state.isPaymentSubmitting ||
        state.uncertainPaymentMessage != null) {
      return Future<PaymentSummary?>.value();
    }
    if (_inFlightPaymentPreparation != null) {
      return _inFlightPaymentOrderId == orderId
          ? _inFlightPaymentPreparation!
          : Future<PaymentSummary?>.value();
    }

    final int? backendId = int.tryParse(orderId);
    if (backendId == null) {
      _emitPaymentFailure('Order id is not a backend id.');
      return Future<PaymentSummary?>.value();
    }

    final int requestVersion = ++_paymentRequestVersion;
    _inFlightPaymentOrderId = orderId;
    emit(
      state.copyWith(
        paymentStatus: OrdersPaymentStatus.preparing,
        paymentOrderId: orderId,
        clearPaymentSummary: true,
        isPaymentPreparing: true,
        clearPaymentErrorMessage: true,
        clearUncertainPaymentMessage: true,
      ),
    );

    final Future<PaymentSummary?> request = _preparePayment(
      orderId: orderId,
      backendId: backendId,
      requestVersion: requestVersion,
    );
    _inFlightPaymentPreparation = request;
    return request;
  }

  Future<PaymentSummary?> _preparePayment({
    required String orderId,
    required int backendId,
    required int requestVersion,
  }) async {
    try {
      final PaymentSummary summary = await repository.getPaymentSummary(
        orderId: backendId,
      );
      if (!_isCurrentPaymentRequest(requestVersion, orderId)) {
        return null;
      }

      final String? rejection = _paymentPreparationRejection(
        summary,
        backendId,
      );
      if (rejection != null) {
        _emitPaymentFailure(rejection);
        return null;
      }

      emit(
        state.copyWith(
          paymentStatus: OrdersPaymentStatus.ready,
          isPaymentPreparing: false,
          paymentSummary: summary,
          clearPaymentErrorMessage: true,
          clearUncertainPaymentMessage: true,
        ),
      );
      return summary;
    } catch (error) {
      if (_isCurrentPaymentRequest(requestVersion, orderId)) {
        _emitPaymentFailure(
          _messageFor(
            error,
            fallback:
                'Could not prepare payment. Check order access and try again.',
          ),
        );
      }
      return null;
    } finally {
      if (_paymentRequestVersion == requestVersion) {
        _inFlightPaymentPreparation = null;
        _inFlightPaymentOrderId = null;
      }
    }
  }

  Future<OrdersPaymentStatus> submitPayment(PaymentResult request) async {
    if (isClosed) {
      return OrdersPaymentStatus.uncertain;
    }
    if (state.isPaymentSubmitting) {
      return OrdersPaymentStatus.uncertain;
    }
    if (_uncertainPaymentFingerprint != null) {
      return OrdersPaymentStatus.uncertain;
    }

    final int? orderId = _pendingPaymentOrderIdFromState;
    final PaymentSummary? summary = state.paymentSummary;
    if (orderId == null || summary == null || state.paymentOrderId == null) {
      _emitPaymentFailure(
        'Payment is not ready. Refresh the order and try again.',
      );
      return OrdersPaymentStatus.retryableFailure;
    }
    if (_paymentPreparationRejection(summary, orderId) != null) {
      _emitPaymentFailure(
        summary.blockedReason ??
            'This order cannot be paid in its current state.',
      );
      return OrdersPaymentStatus.retryableFailure;
    }

    final String fingerprint = _paymentFingerprint(orderId, request);
    if (_pendingPaymentOrderId != orderId ||
        _pendingPaymentFingerprint != fingerprint) {
      _pendingPaymentOrderId = orderId;
      _pendingPaymentFingerprint = fingerprint;
      _pendingPaymentKey = null;
      _pendingPaymentRequest = request;
    }
    final int detailsRequestVersion = _detailsRequestVersion;
    emit(
      state.copyWith(
        paymentStatus: OrdersPaymentStatus.submitting,
        isPaymentSubmitting: true,
        clearPaymentErrorMessage: true,
        clearUncertainPaymentMessage: true,
      ),
    );

    late final String idempotencyKey;
    try {
      idempotencyKey = _pendingPaymentKey ??= _operationKeyGenerator('payment');
      if (idempotencyKey.trim().isEmpty) {
        throw StateError('Payment operation key is empty.');
      }
    } catch (error) {
      _emitPaymentFailure(
        _messageFor(
          error,
          fallback: 'Could not prepare payment. Please try again.',
        ),
      );
      return OrdersPaymentStatus.retryableFailure;
    }

    try {
      await repository.payOrder(
        orderId: orderId,
        method: request.method.apiValue,
        amount: request.amountReceived,
        idempotencyKey: idempotencyKey,
        reference: request.reference,
        totalDue: summary.amountDue,
      );
      if (isClosed) {
        return OrdersPaymentStatus.uncertain;
      }
      if (!repository.usesBackend) {
        _emitPaymentFailure(
          'Payment requires an authenticated backend connection.',
        );
        return OrdersPaymentStatus.retryableFailure;
      }
      return _reloadAndConfirmPayment(
        orderId: orderId,
        request: request,
        idempotencyKey: idempotencyKey,
        detailsRequestVersion: detailsRequestVersion,
      );
    } catch (error) {
      if (isClosed) {
        return OrdersPaymentStatus.uncertain;
      }
      if (_isPotentiallyUncertainPaymentFailure(error)) {
        return _verifyUncertainPayment(
          orderId: orderId,
          request: request,
          idempotencyKey: idempotencyKey,
          detailsRequestVersion: detailsRequestVersion,
        );
      }
      _emitPaymentFailure(
        _messageFor(
          error,
          fallback: 'Could not record payment. Please try again.',
        ),
      );
      return OrdersPaymentStatus.retryableFailure;
    }
  }

  Future<OrdersPaymentStatus> _reloadAndConfirmPayment({
    required int orderId,
    required PaymentResult request,
    required String idempotencyKey,
    required int detailsRequestVersion,
  }) async {
    try {
      final OrderDetail authoritative = await repository.getOrderDetail(
        orderId,
      );
      if (isClosed) {
        return OrdersPaymentStatus.uncertain;
      }
      if (!_matchesCompletedPayment(
        detail: authoritative,
        orderId: orderId,
        request: request,
        idempotencyKey: idempotencyKey,
      )) {
        return _markPaymentUncertain();
      }
      return _finishConfirmedPayment(
        orderId: orderId,
        authoritative: authoritative,
        detailsRequestVersion: detailsRequestVersion,
      );
    } catch (_) {
      return _markPaymentUncertain();
    }
  }

  Future<OrdersPaymentStatus> _verifyUncertainPayment({
    required int orderId,
    required PaymentResult request,
    required String idempotencyKey,
    required int detailsRequestVersion,
  }) async {
    try {
      final OrderDetail authoritative = await repository.getOrderDetail(
        orderId,
      );
      if (isClosed) {
        return OrdersPaymentStatus.uncertain;
      }
      if (_matchesCompletedPayment(
        detail: authoritative,
        orderId: orderId,
        request: request,
        idempotencyKey: idempotencyKey,
      )) {
        return _finishConfirmedPayment(
          orderId: orderId,
          authoritative: authoritative,
          detailsRequestVersion: detailsRequestVersion,
        );
      }
      if (_canConfirmPaymentAbsent(authoritative, orderId)) {
        _emitPaymentFailure(
          'Payment was not completed. You can retry safely with the same operation.',
        );
        return OrdersPaymentStatus.retryableFailure;
      }
      return _markPaymentUncertain();
    } catch (_) {
      return _markPaymentUncertain();
    }
  }

  Future<OrdersPaymentStatus> _finishConfirmedPayment({
    required int orderId,
    required OrderDetail authoritative,
    required int detailsRequestVersion,
  }) async {
    if (isClosed) {
      return OrdersPaymentStatus.uncertain;
    }

    emit(
      state.copyWith(
        paymentStatus: OrdersPaymentStatus.confirmed,
        isPaymentPreparing: false,
        isPaymentSubmitting: false,
        paymentOrderId: orderId.toString(),
        clearPaymentSummary: true,
        clearPaymentErrorMessage: true,
        clearUncertainPaymentMessage: true,
        pendingReceiptOrderId: orderId,
        clearPaymentReceipt: true,
        clearReceiptErrorMessage: true,
        selectedOrderDetail:
            _isCurrentDetailsRequest(detailsRequestVersion) &&
                state.selectedOrderDetail?.id == orderId.toString()
            ? authoritative
            : null,
      ),
    );
    _clearPendingPayment();
    await refreshOrders();
    await _loadPaymentReceipt(orderId);
    if (!isClosed && state.paymentStatus == OrdersPaymentStatus.confirmed) {
      // Keep the confirmed state explicit after list/receipt refreshes.
      emit(state.copyWith(paymentStatus: OrdersPaymentStatus.confirmed));
    }
    return OrdersPaymentStatus.confirmed;
  }

  Future<void> _loadPaymentReceipt(int orderId) async {
    if (isClosed || state.pendingReceiptOrderId != orderId) {
      return;
    }
    final int requestId = ++_receiptRequestGeneration;
    emit(
      state.copyWith(isReceiptLoading: true, clearReceiptErrorMessage: true),
    );
    try {
      final OrderReceipt receipt = await repository.getReceipt(orderId);
      if (isClosed ||
          requestId != _receiptRequestGeneration ||
          state.pendingReceiptOrderId != orderId) {
        return;
      }
      emit(
        state.copyWith(
          paymentReceipt: receipt,
          isReceiptLoading: false,
          clearPendingReceiptOrderId: true,
          clearReceiptErrorMessage: true,
        ),
      );
    } catch (_) {
      if (isClosed ||
          requestId != _receiptRequestGeneration ||
          state.pendingReceiptOrderId != orderId) {
        return;
      }
      emit(
        state.copyWith(
          isReceiptLoading: false,
          receiptErrorMessage:
              'Payment completed, but the receipt could not be loaded.',
        ),
      );
    }
  }

  Future<void> retryPaymentReceipt() async {
    final int? orderId = state.pendingReceiptOrderId;
    if (orderId == null || state.isReceiptLoading) {
      return;
    }
    await _loadPaymentReceipt(orderId);
  }

  Future<OrdersPaymentStatus> checkUncertainPaymentStatus() async {
    final int? orderId = _pendingPaymentOrderId;
    final String? fingerprint = _uncertainPaymentFingerprint;
    final PaymentResult? request = _pendingPaymentRequest;
    final String? idempotencyKey = _pendingPaymentKey;
    if (orderId == null ||
        fingerprint == null ||
        request == null ||
        idempotencyKey == null ||
        state.isPaymentSubmitting) {
      return OrdersPaymentStatus.uncertain;
    }
    emit(
      state.copyWith(
        paymentStatus: OrdersPaymentStatus.submitting,
        isPaymentSubmitting: true,
        clearPaymentErrorMessage: true,
      ),
    );
    return _verifyUncertainPayment(
      orderId: orderId,
      request: request,
      idempotencyKey: idempotencyKey,
      detailsRequestVersion: _detailsRequestVersion,
    );
  }

  void _invalidatePaymentPreparationForSelection(String orderId) {
    if (state.paymentOrderId != null &&
        state.paymentOrderId != orderId &&
        !state.isPaymentSubmitting &&
        _uncertainPaymentFingerprint == null) {
      _paymentRequestVersion++;
      _inFlightPaymentPreparation = null;
      _inFlightPaymentOrderId = null;
      _clearPendingPayment();
      if (!isClosed) {
        emit(
          state.copyWith(
            paymentStatus: OrdersPaymentStatus.idle,
            isPaymentPreparing: false,
            clearPaymentOrderId: true,
            clearPaymentSummary: true,
            clearPaymentErrorMessage: true,
          ),
        );
      }
    }
  }

  bool _isCurrentPaymentRequest(int requestVersion, String orderId) {
    return !isClosed &&
        requestVersion == _paymentRequestVersion &&
        state.paymentOrderId == orderId;
  }

  String? _paymentPreparationRejection(PaymentSummary summary, int orderId) {
    final String paymentStatus = summary.paymentStatus.toLowerCase();
    final String orderStatus = summary.orderStatus.toLowerCase();
    final bool lifecyclePayable =
        (orderStatus == 'draft' || orderStatus == 'held') &&
        paymentStatus == 'unpaid';
    if (summary.orderId != orderId) {
      return 'Payment summary did not match the selected order.';
    }
    if (!summary.canPay || !lifecyclePayable || summary.amountDue <= 0) {
      return summary.blockedReason ??
          'This order cannot be paid in its current state.';
    }
    final bool hasSupportedMethod = summary.methods.any((String method) {
      return method.toLowerCase() == 'cash' ||
          method.toLowerCase() == 'card' ||
          method.toLowerCase() == 'wallet';
    });
    if (!hasSupportedMethod) {
      return 'No supported payment method is available for this order.';
    }
    return null;
  }

  int? get _pendingPaymentOrderIdFromState {
    return int.tryParse(state.paymentOrderId ?? '');
  }

  String _paymentFingerprint(int orderId, PaymentResult request) {
    final List<String> fields = <String>[
      'orderId',
      orderId.toString(),
      'method',
      request.method.apiValue,
      'amount',
      request.amountReceived.toStringAsFixed(2),
      'totalDue',
      request.totalDue.toStringAsFixed(2),
      'reference',
      request.reference ?? '',
    ];
    return fields.map((String value) => '${value.length}:$value').join('|');
  }

  bool _matchesCompletedPayment({
    required OrderDetail detail,
    required int orderId,
    required PaymentResult request,
    required String idempotencyKey,
  }) {
    if (detail.id != orderId.toString() ||
        detail.paymentStatus.toLowerCase() != 'paid') {
      return false;
    }
    final List<OrderPaymentSummary> payments = detail.payments.isEmpty
        ? <OrderPaymentSummary>[detail.payment]
        : detail.payments;
    return payments.any((OrderPaymentSummary payment) {
      final bool methodMatches = payment.method == request.method.apiValue;
      final bool amountMatches =
          (payment.amount -
                  (state.paymentSummary?.amountDue ?? request.totalDue))
              .abs() <
          0.005;
      final bool referenceMatches =
          request.reference == null ||
          request.reference!.trim().isEmpty ||
          payment.authCode == request.reference;
      return payment.hasPayment &&
          payment.isCompleted &&
          payment.idempotencyKey == idempotencyKey &&
          methodMatches &&
          amountMatches &&
          referenceMatches;
    });
  }

  bool _canConfirmPaymentAbsent(OrderDetail detail, int orderId) {
    if (detail.id != orderId.toString() ||
        detail.paymentStatus.toLowerCase() != 'unpaid' ||
        !(detail.status == OrderStatus.preparing ||
            detail.status == OrderStatus.held)) {
      return false;
    }
    final List<OrderPaymentSummary> payments = detail.payments.isEmpty
        ? <OrderPaymentSummary>[detail.payment]
        : detail.payments;
    return payments.every(
      (OrderPaymentSummary payment) => !payment.isCompleted,
    );
  }

  void _clearPendingPayment() {
    _pendingPaymentOrderId = null;
    _pendingPaymentFingerprint = null;
    _pendingPaymentKey = null;
    _pendingPaymentRequest = null;
    _uncertainPaymentFingerprint = null;
  }

  void _emitPaymentFailure(String message) {
    _uncertainPaymentFingerprint = null;
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        paymentStatus: OrdersPaymentStatus.retryableFailure,
        isPaymentPreparing: false,
        isPaymentSubmitting: false,
        paymentErrorMessage: message,
        clearUncertainPaymentMessage: true,
      ),
    );
  }

  OrdersPaymentStatus _markPaymentUncertain() {
    _uncertainPaymentFingerprint = _pendingPaymentFingerprint;
    const String message =
        'Payment status could not be confirmed. Check the order before retrying.';
    if (!isClosed) {
      emit(
        state.copyWith(
          paymentStatus: OrdersPaymentStatus.uncertain,
          isPaymentPreparing: false,
          isPaymentSubmitting: false,
          paymentErrorMessage: message,
          uncertainPaymentMessage: message,
        ),
      );
    }
    return OrdersPaymentStatus.uncertain;
  }

  bool _isPotentiallyUncertainPaymentFailure(Object error) {
    return error is! ApiException ||
        error.statusCode == null ||
        error.statusCode! >= 500;
  }

  Future<void> nextPage() async {
    if (!state.canGoNext) {
      return;
    }
    await loadOrders(page: state.currentPage + 1);
  }

  Future<void> previousPage() async {
    if (!state.canGoPrevious) {
      return;
    }
    await loadOrders(page: state.currentPage - 1);
  }

  Future<RefundCompletionStatus> submitRefund(RefundResult request) async {
    if (isClosed || state.isRefundSubmitting) {
      return RefundCompletionStatus.uncertain;
    }
    if (_uncertainRefundFingerprint != null) {
      return RefundCompletionStatus.uncertain;
    }

    final OrderDetail? selectedDetail = state.selectedOrderDetail;
    if (selectedDetail == null ||
        selectedDetail.id != request.orderId ||
        !selectedDetail.canRefund) {
      _emitRefundFailure(
        'This order has no completed payment or refundable balance.',
      );
      return RefundCompletionStatus.retryableFailure;
    }

    final int detailsRequestVersion = _detailsRequestVersion;
    final String fingerprint = _refundFingerprint(request);
    if (_pendingRefundFingerprint != fingerprint) {
      _pendingRefundFingerprint = fingerprint;
      _pendingRefundKey = null;
    }

    emit(
      state.copyWith(
        isRefundSubmitting: true,
        clearRefundErrorMessage: true,
        clearUncertainRefundMessage: true,
      ),
    );

    late final String idempotencyKey;
    try {
      idempotencyKey = _pendingRefundKey ??= _operationKeyGenerator('refund');
      if (idempotencyKey.trim().isEmpty) {
        throw StateError('Refund operation key is empty.');
      }
    } catch (error) {
      _emitRefundFailure(
        _messageFor(
          error,
          fallback: 'Could not prepare the refund. Please try again.',
        ),
      );
      return RefundCompletionStatus.retryableFailure;
    }

    try {
      final RefundResult result = await repository.submitRefund(
        request: request,
        idempotencyKey: idempotencyKey,
      );
      if (isClosed) {
        return RefundCompletionStatus.uncertain;
      }

      if (!repository.usesBackend) {
        return _confirmFakeRefund(
          request: request,
          result: result,
          idempotencyKey: idempotencyKey,
          detailsRequestVersion: detailsRequestVersion,
        );
      }

      return _reloadAndConfirmRefund(
        request: request,
        idempotencyKey: idempotencyKey,
        detailsRequestVersion: detailsRequestVersion,
      );
    } catch (error) {
      if (isClosed) {
        return RefundCompletionStatus.uncertain;
      }
      if (_isPotentiallyUncertainRefundFailure(error)) {
        return _verifyUncertainRefund(
          request: request,
          idempotencyKey: idempotencyKey,
          detailsRequestVersion: detailsRequestVersion,
        );
      }

      _emitRefundFailure(
        _messageFor(
          error,
          fallback: 'Could not record the refund. Please try again.',
        ),
      );
      return RefundCompletionStatus.retryableFailure;
    }
  }

  void confirmRefund(RefundResult result) {
    final selectedDetail = state.selectedOrderDetail;
    if (selectedDetail == null || selectedDetail.id != result.orderId) {
      return;
    }

    final double cumulativeRefunded =
        selectedDetail.refundedAmount + result.amount;
    final double remaining = max(
      0,
      selectedDetail.refundableAmount - result.amount,
    );
    final bool fullyRefunded = result.type == RefundType.full || remaining <= 0;
    final OrderStatus status = fullyRefunded
        ? OrderStatus.refunded
        : OrderStatus.partiallyRefunded;
    final updatedDetail = selectedDetail.copyWith(
      status: status,
      isRefunded: fullyRefunded,
      refundedAmount: cumulativeRefunded,
      refundedAt: result.refundedAt,
      refundableAmount: remaining,
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

  Future<RefundCompletionStatus> _reloadAndConfirmRefund({
    required RefundResult request,
    required String idempotencyKey,
    required int detailsRequestVersion,
  }) async {
    try {
      final OrderDetail authoritative = await repository.getOrderDetail(
        int.parse(request.orderId),
      );
      if (isClosed) {
        return RefundCompletionStatus.uncertain;
      }

      if (!_matchesRefundOperation(
        detail: authoritative,
        request: request,
        idempotencyKey: idempotencyKey,
      )) {
        return _markRefundUncertain();
      }

      return _finishConfirmedRefund(
        request: request,
        authoritative: authoritative,
        detailsRequestVersion: detailsRequestVersion,
      );
    } catch (_) {
      return _markRefundUncertain();
    }
  }

  Future<RefundCompletionStatus> _verifyUncertainRefund({
    required RefundResult request,
    required String idempotencyKey,
    required int detailsRequestVersion,
  }) async {
    try {
      final OrderDetail authoritative = await repository.getOrderDetail(
        int.parse(request.orderId),
      );
      if (isClosed) {
        return RefundCompletionStatus.uncertain;
      }

      if (_matchesRefundOperation(
        detail: authoritative,
        request: request,
        idempotencyKey: idempotencyKey,
      )) {
        return _finishConfirmedRefund(
          request: request,
          authoritative: authoritative,
          detailsRequestVersion: detailsRequestVersion,
        );
      }

      if (_canConfirmRefundAbsent(authoritative)) {
        _emitRefundFailure(
          'Refund was not found on the server. Check the order, then retry with the same operation.',
        );
        return RefundCompletionStatus.retryableFailure;
      }

      return _markRefundUncertain();
    } catch (_) {
      return _markRefundUncertain();
    }
  }

  Future<RefundCompletionStatus> _confirmFakeRefund({
    required RefundResult request,
    required RefundResult result,
    required String idempotencyKey,
    required int detailsRequestVersion,
  }) async {
    final OrderDetail? selectedDetail = state.selectedOrderDetail;
    if (selectedDetail == null || selectedDetail.id != request.orderId) {
      return _markRefundUncertain();
    }

    final double cumulativeRefunded =
        selectedDetail.refundedAmount + result.amount;
    final double remaining = max(
      0,
      selectedDetail.refundableAmount - result.amount,
    );
    final bool fullyRefunded = result.type == RefundType.full || remaining <= 0;
    final OrderDetail authoritative = selectedDetail.copyWith(
      status: fullyRefunded
          ? OrderStatus.refunded
          : OrderStatus.partiallyRefunded,
      isRefunded: fullyRefunded,
      refundedAmount: cumulativeRefunded,
      refundedAt: result.refundedAt,
      refundableAmount: remaining,
      refunds: <OrderRefund>[
        ...selectedDetail.refunds,
        OrderRefund(
          id: 'fake-$idempotencyKey',
          type: result.type,
          amount: result.amount,
          reason: result.reason,
          managerNotes: result.managerNotes,
          status: 'completed',
          refundedAt: result.refundedAt,
          idempotencyKey: idempotencyKey,
        ),
      ],
    );

    return _finishConfirmedRefund(
      request: request,
      authoritative: authoritative,
      detailsRequestVersion: detailsRequestVersion,
      refreshList: false,
    );
  }

  Future<RefundCompletionStatus> _finishConfirmedRefund({
    required RefundResult request,
    required OrderDetail authoritative,
    required int detailsRequestVersion,
    bool refreshList = true,
  }) async {
    if (isClosed) {
      return RefundCompletionStatus.uncertain;
    }

    if (_isCurrentDetailsRequest(detailsRequestVersion) &&
        state.selectedOrderDetail?.id == request.orderId) {
      emit(
        state.copyWith(
          selectedOrderDetail: authoritative,
          isRefundSubmitting: false,
          clearRefundErrorMessage: true,
          clearUncertainRefundMessage: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isRefundSubmitting: false,
          clearRefundErrorMessage: true,
          clearUncertainRefundMessage: true,
        ),
      );
    }

    _clearPendingRefund();
    if (refreshList) {
      await refreshOrders();
    }
    return RefundCompletionStatus.completed;
  }

  RefundCompletionStatus _markRefundUncertain() {
    _uncertainRefundFingerprint = _pendingRefundFingerprint;
    const String message =
        'Refund status could not be confirmed. Check the order before retrying.';
    if (!isClosed) {
      emit(
        state.copyWith(
          isRefundSubmitting: false,
          refundErrorMessage: message,
          uncertainRefundMessage: message,
        ),
      );
    }
    return RefundCompletionStatus.uncertain;
  }

  bool _matchesRefundOperation({
    required OrderDetail detail,
    required RefundResult request,
    required String idempotencyKey,
  }) {
    if (detail.id != request.orderId || detail.refundableAmount < 0) {
      return false;
    }

    for (final OrderRefund refund in detail.refunds) {
      final bool amountMatches = request.type == RefundType.full
          ? refund.amount > 0 && refund.amount <= request.amount + 0.005
          : (refund.amount - request.amount).abs() < 0.005;
      if (refund.idempotencyKey == idempotencyKey &&
          refund.type == request.type &&
          refund.reason == request.reason &&
          refund.managerNotes == request.managerNotes &&
          refund.status.toLowerCase() == 'completed' &&
          amountMatches &&
          detail.refundedAmount + 0.005 >= refund.amount) {
        return true;
      }
    }

    return false;
  }

  bool _canConfirmRefundAbsent(OrderDetail detail) {
    if (detail.refunds.isEmpty) {
      return detail.refundedAmount <= 0;
    }

    return detail.refunds.every(
      (OrderRefund refund) => refund.idempotencyKey?.trim().isNotEmpty ?? false,
    );
  }

  void _clearPendingRefund() {
    _pendingRefundFingerprint = null;
    _pendingRefundKey = null;
    _uncertainRefundFingerprint = null;
  }

  bool _canStartOrderAction() {
    if (isClosed || state.isOrderActionBlocked) {
      return false;
    }
    if (state.isPaymentBlocked || state.isRefundSubmitting) {
      return false;
    }
    return state.uncertainRefundMessage == null;
  }

  String _ordersActionContextKey() {
    return '${state.selectedBranchId}|${state.selectedFilter.name}|'
        '${state.currentPage}|${state.perPage}';
  }

  bool _isCurrentOrdersActionContext(String contextKey) {
    return !isClosed && contextKey == _ordersActionContextKey();
  }

  bool _isCurrentOrderAction(
    int requestVersion,
    String orderId,
    String contextKey,
  ) {
    return !isClosed &&
        requestVersion == _orderActionRequestVersion &&
        state.actionOrderId == orderId &&
        _orderActionContextKey == contextKey;
  }

  void _emitOrderActionState({
    required String orderId,
    required OrdersActionStatus status,
    String? errorMessage,
    String? uncertainMessage,
    bool clearErrorMessage = false,
    bool clearUncertainMessage = false,
  }) {
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        actionOrderId: orderId,
        orderActionStatus: status,
        orderActionErrorMessage: errorMessage,
        clearOrderActionErrorMessage: clearErrorMessage,
        uncertainOrderActionMessage: uncertainMessage,
        clearUncertainOrderActionMessage: clearUncertainMessage,
      ),
    );
  }

  OrdersActionOutcome _setImmediateOrderActionFailure(
    String orderId,
    String message,
  ) {
    if (!isClosed) {
      _emitOrderActionState(
        orderId: orderId,
        status: OrdersActionStatus.retryableFailure,
        errorMessage: message,
        clearUncertainMessage: true,
      );
    }
    return OrdersActionOutcome.retryableFailure;
  }

  OrdersActionOutcome _finishRetryableOrderAction(
    int requestVersion,
    String orderId,
    String contextKey,
    String message,
  ) {
    if (!_isCurrentOrderAction(requestVersion, orderId, contextKey)) {
      return OrdersActionOutcome.stale;
    }
    _emitOrderActionState(
      orderId: orderId,
      status: OrdersActionStatus.retryableFailure,
      errorMessage: message,
      clearUncertainMessage: true,
    );
    return OrdersActionOutcome.retryableFailure;
  }

  OrdersActionOutcome _finishUncertainOrderAction(
    int requestVersion,
    String orderId,
    String contextKey,
    String message,
  ) {
    if (!_isCurrentOrderAction(requestVersion, orderId, contextKey)) {
      return OrdersActionOutcome.stale;
    }
    _emitOrderActionState(
      orderId: orderId,
      status: OrdersActionStatus.uncertain,
      errorMessage: message,
      uncertainMessage: message,
    );
    return OrdersActionOutcome.uncertain;
  }

  Future<OrdersActionOutcome> _verifyUncertainCancellation({
    required int requestVersion,
    required String orderId,
    required String contextKey,
  }) async {
    final int? backendId = int.tryParse(orderId);
    if (backendId == null) {
      return _finishUncertainOrderAction(
        requestVersion,
        orderId,
        contextKey,
        'Cancellation status could not be confirmed. Check status before retrying.',
      );
    }

    try {
      final OrderDetail detail = await repository.getOrderDetail(backendId);
      if (!_isCurrentOrderAction(requestVersion, orderId, contextKey) ||
          !_isCurrentOrdersActionContext(contextKey)) {
        return OrdersActionOutcome.stale;
      }
      if (int.tryParse(detail.id) != backendId ||
          (detail.branchId != null &&
              detail.branchId != state.selectedBranchId)) {
        return _finishUncertainOrderAction(
          requestVersion,
          orderId,
          contextKey,
          'Cancellation status is unresolved. Check status before retrying.',
        );
      }
      if (detail.status == OrderStatus.cancelled) {
        return _confirmCancellation(requestVersion, orderId, contextKey);
      }
      if (detail.canCancel) {
        return _finishRetryableOrderAction(
          requestVersion,
          orderId,
          contextKey,
          'Order is still active and unpaid. Check status, then retry cancellation explicitly.',
        );
      }
      return _finishUncertainOrderAction(
        requestVersion,
        orderId,
        contextKey,
        'Cancellation status is unresolved. Check status before retrying.',
      );
    } catch (error) {
      if (!_isCurrentOrderAction(requestVersion, orderId, contextKey) ||
          !_isCurrentOrdersActionContext(contextKey)) {
        return OrdersActionOutcome.stale;
      }
      if (error is ApiException && error.statusCode == 404) {
        return _confirmCancellation(requestVersion, orderId, contextKey);
      }
      return _finishUncertainOrderAction(
        requestVersion,
        orderId,
        contextKey,
        'Cancellation status could not be confirmed. Check status before retrying.',
      );
    }
  }

  bool _isUncertainCancellationFailure(Object error) {
    if (error is! ApiException) {
      return true;
    }
    return error.statusCode == null ||
        error.statusCode! >= 500 ||
        error.type == ApiErrorType.networkUnavailable ||
        error.type == ApiErrorType.connectionTimeout ||
        error.type == ApiErrorType.sendTimeout ||
        error.type == ApiErrorType.receiveTimeout;
  }

  Future<OrdersActionOutcome> _confirmCancellation(
    int requestVersion,
    String orderId,
    String contextKey,
  ) async {
    final bool canUpdateActionState =
        _isCurrentOrderAction(requestVersion, orderId, contextKey) &&
        _isCurrentOrdersActionContext(contextKey);
    if (canUpdateActionState) {
      final bool closesSelectedDetail =
          _detailsOrderId == orderId || state.selectedOrderDetail?.id == orderId;
      if (closesSelectedDetail) {
        _detailsRequestVersion++;
        _detailsOrderId = null;
      }
      emit(
        state.copyWith(
          orderActionStatus: OrdersActionStatus.confirmed,
          clearOrderActionErrorMessage: true,
          clearUncertainOrderActionMessage: true,
          clearSelectedOrderDetail: closesSelectedDetail,
          isDetailsLoading: closesSelectedDetail ? false : null,
          clearDetailsErrorMessage: closesSelectedDetail,
        ),
      );
    }

    await refreshOrders();

    // DELETE or authoritative status verification already confirmed the
    // mutation. List refresh is independent UI state and cannot downgrade the
    // confirmed cancellation to stale when its request is superseded.
    return OrdersActionOutcome.confirmed;
  }

  void _invalidateOrderActionForContextIfNeeded() {
    final String? actionContext = _orderActionContextKey;
    if (actionContext == null || actionContext == _ordersActionContextKey()) {
      return;
    }
    _orderActionRequestVersion++;
    _orderActionContextKey = null;
    if (!isClosed && state.isOrderActionBlocked) {
      emit(
        state.copyWith(
          orderActionStatus: OrdersActionStatus.retryableFailure,
          clearOrderActionErrorMessage: true,
          clearUncertainOrderActionMessage: true,
        ),
      );
    }
  }

  void _emitRefundFailure(String message) {
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        isRefundSubmitting: false,
        refundErrorMessage: message,
        clearUncertainRefundMessage: true,
      ),
    );
  }

  bool _isPotentiallyUncertainRefundFailure(Object error) {
    return error is! ApiException ||
        error.statusCode == null ||
        error.statusCode! >= 500;
  }

  String _refundFingerprint(RefundResult request) {
    final String type = switch (request.type) {
      RefundType.full => 'full',
      RefundType.partial => 'partial',
    };
    final List<String> fields = <String>[
      request.orderId,
      type,
      request.amount.toStringAsFixed(2),
      request.reason,
      request.managerNotes,
    ];
    return fields.map((String value) => '${value.length}:$value').join('|');
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[OrdersCubit] $message');
    }
  }

  static String _defaultOperationKey(String operation) {
    final int random = Random.secure().nextInt(0x100000000);
    return '$operation-${DateTime.now().microsecondsSinceEpoch}-${random.toRadixString(16)}';
  }

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

  void _emitOrdersPage({
    required List<Branch> branches,
    required int selectedBranchId,
    required OrderPage result,
  }) {
    emit(
      state.copyWith(
        branches: branches,
        selectedBranchId: selectedBranchId,
        orders: result.orders,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        perPage: result.perPage,
        total: result.total,
        isLoading: false,
        isPageLoading: false,
        clearErrorMessage: true,
      ),
    );
  }

  bool _needsPageRecovery(OrderPage result, int requestedPage) {
    return result.lastPage < 1 ||
        requestedPage > result.lastPage ||
        result.currentPage > result.lastPage;
  }

  String _initialOrdersRequestKey({
    required OrdersFilter filter,
    required int page,
    required int perPage,
  }) => 'initial|${filter.name}|$page|$perPage';

  String _ordersRequestKey({
    required int branchId,
    required OrdersFilter filter,
    required int page,
    required int perPage,
  }) => '$branchId|${filter.name}|$page|$perPage';

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
