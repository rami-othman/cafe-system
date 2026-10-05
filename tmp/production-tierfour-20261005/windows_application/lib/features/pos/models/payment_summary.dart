import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

class PaymentSummary extends Equatable {
  const PaymentSummary({
    required this.orderId,
    required this.orderNumber,
    required this.totalDue,
    required this.itemCount,
    required this.amountReceived,
    required this.changeDue,
    required this.methods,
    required this.quickAmounts,
    this.outstandingAmount,
    this.orderStatus = 'draft',
    this.paymentStatus = 'unpaid',
    this.canPay = true,
    this.blockerCode,
    this.blockedReason,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      orderId: readInt(json['orderId']) ?? 0,
      orderNumber: readString(json['orderNumber']),
      totalDue: readDouble(json['totalDue']),
      itemCount: readDouble(json['itemCount']).round(),
      amountReceived: readDouble(json['amountReceived']),
      changeDue: readDouble(json['changeDue']),
      methods: (json['methods'] as List? ?? const <Object?>[])
          .map((dynamic value) => value.toString())
          .toList(growable: false),
      quickAmounts: (json['quickAmounts'] as List? ?? const <Object?>[])
          .map(readDouble)
          .toList(growable: false),
      outstandingAmount: readDouble(
        json['outstandingAmount'],
        fallback: readDouble(json['totalDue']),
      ),
      orderStatus: readString(json['orderStatus'], fallback: 'draft'),
      paymentStatus: readString(json['paymentStatus'], fallback: 'unpaid'),
      canPay: readBool(json['canPay'], fallback: true),
      blockerCode: readString(json['blockerCode']).trim().isEmpty
          ? null
          : readString(json['blockerCode']).trim(),
      blockedReason: readString(json['blockedReason']).trim().isEmpty
          ? null
          : readString(json['blockedReason']).trim(),
    );
  }

  final int orderId;
  final String orderNumber;
  final double totalDue;
  final int itemCount;
  final double amountReceived;
  final double changeDue;
  final List<String> methods;
  final List<double> quickAmounts;
  final double? outstandingAmount;
  final String orderStatus;
  final String paymentStatus;
  final bool canPay;
  final String? blockerCode;
  final String? blockedReason;

  double get amountDue => outstandingAmount ?? totalDue;

  @override
  List<Object?> get props => <Object?>[
    orderId,
    orderNumber,
    totalDue,
    itemCount,
    amountReceived,
    changeDue,
    methods,
    quickAmounts,
    outstandingAmount,
    orderStatus,
    paymentStatus,
    canPay,
    blockerCode,
    blockedReason,
  ];
}
