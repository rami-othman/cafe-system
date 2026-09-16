import 'package:equatable/equatable.dart';

import '../models/order_status.dart';
import '../models/order_summary.dart';
import '../../pos/models/branch.dart';
import '../models/order_type.dart';
import '../models/order_detail.dart';
import '../../pos/models/order_receipt.dart';
import '../../pos/models/payment_summary.dart';

enum OrdersPaymentStatus {
  idle,
  preparing,
  ready,
  submitting,
  confirmed,
  retryableFailure,
  uncertain,
}

enum OrdersActionStatus {
  idle,
  preparing,
  submitting,
  confirmed,
  retryableFailure,
  uncertain,
}

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
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 25,
    this.total = 0,
    this.isLoading = false,
    this.isPageLoading = false,
    this.errorMessage,
    this.selectedOrderDetail,
    this.isDetailsLoading = false,
    this.detailsErrorMessage,
    this.isRefundSubmitting = false,
    this.refundErrorMessage,
    this.uncertainRefundMessage,
    this.paymentStatus = OrdersPaymentStatus.idle,
    this.paymentOrderId,
    this.paymentSummary,
    this.isPaymentPreparing = false,
    this.isPaymentSubmitting = false,
    this.paymentErrorMessage,
    this.uncertainPaymentMessage,
    this.pendingReceiptOrderId,
    this.isReceiptLoading = false,
    this.paymentReceipt,
    this.receiptErrorMessage,
    this.actionOrderId,
    this.orderActionStatus = OrdersActionStatus.idle,
    this.orderActionErrorMessage,
    this.uncertainOrderActionMessage,
  });

  final List<OrderSummary> orders;
  final List<Branch> branches;
  final int? selectedBranchId;
  final OrdersFilter selectedFilter;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool isLoading;
  final bool isPageLoading;
  final String? errorMessage;
  final OrderDetail? selectedOrderDetail;
  final bool isDetailsLoading;
  final String? detailsErrorMessage;
  final bool isRefundSubmitting;
  final String? refundErrorMessage;
  final String? uncertainRefundMessage;
  final OrdersPaymentStatus paymentStatus;
  final String? paymentOrderId;
  final PaymentSummary? paymentSummary;
  final bool isPaymentPreparing;
  final bool isPaymentSubmitting;
  final String? paymentErrorMessage;
  final String? uncertainPaymentMessage;
  final int? pendingReceiptOrderId;
  final bool isReceiptLoading;
  final OrderReceipt? paymentReceipt;
  final String? receiptErrorMessage;
  final String? actionOrderId;
  final OrdersActionStatus orderActionStatus;
  final String? orderActionErrorMessage;
  final String? uncertainOrderActionMessage;

  bool get canGoPrevious =>
      !isPageLoading && !isOrderActionBlocked && currentPage > 1;
  bool get canGoNext =>
      !isPageLoading && !isOrderActionBlocked && currentPage < lastPage;

  bool get isPaymentBlocked {
    return isPaymentPreparing ||
        isPaymentSubmitting ||
        uncertainPaymentMessage != null;
  }

  bool get isOrderActionSubmitting {
    return orderActionStatus == OrdersActionStatus.preparing ||
        orderActionStatus == OrdersActionStatus.submitting;
  }

  bool get isOrderActionBlocked {
    return isOrderActionSubmitting || uncertainOrderActionMessage != null;
  }

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
    int? currentPage,
    int? lastPage,
    int? perPage,
    int? total,
    bool? isLoading,
    bool? isPageLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    OrderDetail? selectedOrderDetail,
    bool clearSelectedOrderDetail = false,
    bool? isDetailsLoading,
    String? detailsErrorMessage,
    bool clearDetailsErrorMessage = false,
    bool? isRefundSubmitting,
    String? refundErrorMessage,
    bool clearRefundErrorMessage = false,
    String? uncertainRefundMessage,
    bool clearUncertainRefundMessage = false,
    OrdersPaymentStatus? paymentStatus,
    String? paymentOrderId,
    bool clearPaymentOrderId = false,
    PaymentSummary? paymentSummary,
    bool clearPaymentSummary = false,
    bool? isPaymentPreparing,
    bool? isPaymentSubmitting,
    String? paymentErrorMessage,
    bool clearPaymentErrorMessage = false,
    String? uncertainPaymentMessage,
    bool clearUncertainPaymentMessage = false,
    int? pendingReceiptOrderId,
    bool clearPendingReceiptOrderId = false,
    bool? isReceiptLoading,
    OrderReceipt? paymentReceipt,
    bool clearPaymentReceipt = false,
    String? receiptErrorMessage,
    bool clearReceiptErrorMessage = false,
    String? actionOrderId,
    bool clearActionOrderId = false,
    OrdersActionStatus? orderActionStatus,
    String? orderActionErrorMessage,
    bool clearOrderActionErrorMessage = false,
    String? uncertainOrderActionMessage,
    bool clearUncertainOrderActionMessage = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      branches: branches ?? this.branches,
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isPageLoading: isPageLoading ?? this.isPageLoading,
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
      isRefundSubmitting: isRefundSubmitting ?? this.isRefundSubmitting,
      refundErrorMessage: clearRefundErrorMessage
          ? null
          : refundErrorMessage ?? this.refundErrorMessage,
      uncertainRefundMessage: clearUncertainRefundMessage
          ? null
          : uncertainRefundMessage ?? this.uncertainRefundMessage,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentOrderId: clearPaymentOrderId
          ? null
          : paymentOrderId ?? this.paymentOrderId,
      paymentSummary: clearPaymentSummary
          ? null
          : paymentSummary ?? this.paymentSummary,
      isPaymentPreparing: isPaymentPreparing ?? this.isPaymentPreparing,
      isPaymentSubmitting: isPaymentSubmitting ?? this.isPaymentSubmitting,
      paymentErrorMessage: clearPaymentErrorMessage
          ? null
          : paymentErrorMessage ?? this.paymentErrorMessage,
      uncertainPaymentMessage: clearUncertainPaymentMessage
          ? null
          : uncertainPaymentMessage ?? this.uncertainPaymentMessage,
      pendingReceiptOrderId: clearPendingReceiptOrderId
          ? null
          : pendingReceiptOrderId ?? this.pendingReceiptOrderId,
      isReceiptLoading: isReceiptLoading ?? this.isReceiptLoading,
      paymentReceipt: clearPaymentReceipt
          ? null
          : paymentReceipt ?? this.paymentReceipt,
      receiptErrorMessage: clearReceiptErrorMessage
          ? null
          : receiptErrorMessage ?? this.receiptErrorMessage,
      actionOrderId: clearActionOrderId
          ? null
          : actionOrderId ?? this.actionOrderId,
      orderActionStatus: orderActionStatus ?? this.orderActionStatus,
      orderActionErrorMessage: clearOrderActionErrorMessage
          ? null
          : orderActionErrorMessage ?? this.orderActionErrorMessage,
      uncertainOrderActionMessage: clearUncertainOrderActionMessage
          ? null
          : uncertainOrderActionMessage ?? this.uncertainOrderActionMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    orders,
    branches,
    selectedBranchId,
    selectedFilter,
    currentPage,
    lastPage,
    perPage,
    total,
    isLoading,
    isPageLoading,
    errorMessage,
    selectedOrderDetail,
    isDetailsLoading,
    detailsErrorMessage,
    isRefundSubmitting,
    refundErrorMessage,
    uncertainRefundMessage,
    paymentStatus,
    paymentOrderId,
    paymentSummary,
    isPaymentPreparing,
    isPaymentSubmitting,
    paymentErrorMessage,
    uncertainPaymentMessage,
    pendingReceiptOrderId,
    isReceiptLoading,
    paymentReceipt,
    receiptErrorMessage,
    actionOrderId,
    orderActionStatus,
    orderActionErrorMessage,
    uncertainOrderActionMessage,
  ];
}
