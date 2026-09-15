import 'package:equatable/equatable.dart';

import '../../../core/config/tax_config.dart';
import 'order_payment_summary.dart';
import 'order_refund.dart';
import 'order_status.dart';
import 'order_timeline_event.dart';

class OrderDetail extends Equatable {
  const OrderDetail({
    required this.id,
    required this.displayNumber,
    required this.status,
    required this.orderType,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.items,
    required this.subtotal,
    required this.tax,
    this.taxRate = TaxConfig.defaultTaxRate,
    required this.tip,
    required this.total,
    required this.payment,
    required this.timeline,
    this.paymentStatus = 'unpaid',
    this.payments = const <OrderPaymentSummary>[],
    this.isRefunded = false,
    this.refundedAmount = 0,
    this.refundedAt,
    this.refundableAmount = 0,
    this.refunds = const <OrderRefund>[],
    this.branchId,
    this.publishedMenuVersionId,
    this.serverCanResume,
    this.resumeBlockerCode,
    this.resumeBlockedReason,
  });

  final String id;
  final String displayNumber;
  final OrderStatus status;
  final String orderType;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final List<OrderDetailItem> items;
  final double subtotal;
  final double tax;
  final double taxRate;
  final double tip;
  final double total;
  final OrderPaymentSummary payment;
  final List<OrderTimelineEvent> timeline;
  final String paymentStatus;
  final List<OrderPaymentSummary> payments;
  final bool isRefunded;
  final double refundedAmount;
  final DateTime? refundedAt;
  final double refundableAmount;
  final List<OrderRefund> refunds;
  final int? branchId;
  final int? publishedMenuVersionId;
  final bool? serverCanResume;
  final String? resumeBlockerCode;
  final String? resumeBlockedReason;

  bool get hasCustomer => customerName.trim().isNotEmpty;

  bool get hasRefund => refundedAmount > 0;

  // The backend only exposes a positive balance for a completed settlement.
  // Payment labels are translated presentation data, not refund authority.
  bool get canRefund => refundableAmount > 0;

  bool get canPay {
    return paymentStatus.toLowerCase() == 'unpaid' &&
        (status == OrderStatus.preparing || status == OrderStatus.held) &&
        total > 0;
  }

  bool get hasCompletedPayment {
    final List<OrderPaymentSummary> recordedPayments = payments.isEmpty
        ? <OrderPaymentSummary>[payment]
        : payments;
    return recordedPayments.any(
      (OrderPaymentSummary item) => item.hasPayment && item.isCompleted,
    );
  }

  bool get canResume {
    if (serverCanResume != null) {
      return serverCanResume!;
    }
    return status == OrderStatus.held &&
        paymentStatus.toLowerCase() == 'unpaid' &&
        !hasCompletedPayment;
  }

  bool get canCancel {
    return (status == OrderStatus.preparing || status == OrderStatus.held) &&
        paymentStatus.toLowerCase() == 'unpaid' &&
        !hasCompletedPayment;
  }

  OrderDetail copyWith({
    OrderStatus? status,
    bool? isRefunded,
    double? refundedAmount,
    DateTime? refundedAt,
    double? refundableAmount,
    List<OrderRefund>? refunds,
    String? paymentStatus,
    List<OrderPaymentSummary>? payments,
    int? branchId,
    int? publishedMenuVersionId,
    bool? serverCanResume,
    String? resumeBlockerCode,
    String? resumeBlockedReason,
  }) {
    return OrderDetail(
      id: id,
      displayNumber: displayNumber,
      status: status ?? this.status,
      orderType: orderType,
      createdAt: createdAt,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      items: items,
      subtotal: subtotal,
      tax: tax,
      taxRate: taxRate,
      tip: tip,
      total: total,
      payment: payment,
      timeline: timeline,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      payments: payments ?? this.payments,
      isRefunded: isRefunded ?? this.isRefunded,
      refundedAmount: refundedAmount ?? this.refundedAmount,
      refundedAt: refundedAt ?? this.refundedAt,
      refundableAmount: refundableAmount ?? this.refundableAmount,
      refunds: refunds ?? this.refunds,
      branchId: branchId ?? this.branchId,
      publishedMenuVersionId:
          publishedMenuVersionId ?? this.publishedMenuVersionId,
      serverCanResume: serverCanResume ?? this.serverCanResume,
      resumeBlockerCode: resumeBlockerCode ?? this.resumeBlockerCode,
      resumeBlockedReason: resumeBlockedReason ?? this.resumeBlockedReason,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    displayNumber,
    status,
    orderType,
    createdAt,
    customerName,
    customerPhone,
    customerEmail,
    items,
    subtotal,
    tax,
    taxRate,
    tip,
    total,
    payment,
    timeline,
    paymentStatus,
    payments,
    isRefunded,
    refundedAmount,
    refundedAt,
    refundableAmount,
    refunds,
    branchId,
    publishedMenuVersionId,
    serverCanResume,
    resumeBlockerCode,
    resumeBlockedReason,
  ];
}

class OrderDetailItem extends Equatable {
  const OrderDetailItem({
    required this.quantity,
    required this.name,
    required this.modifiers,
    required this.total,
  });

  final int quantity;
  final String name;
  final List<String> modifiers;
  final double total;

  @override
  List<Object?> get props => <Object?>[quantity, name, modifiers, total];
}
