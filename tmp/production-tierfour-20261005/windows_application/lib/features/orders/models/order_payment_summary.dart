import 'package:equatable/equatable.dart';

class OrderPaymentSummary extends Equatable {
  const OrderPaymentSummary({
    required this.methodLabel,
    required this.statusLabel,
    required this.authCode,
    required this.amount,
    this.hasPayment = true,
    this.method,
    this.status,
    this.paymentId,
    this.idempotencyKey,
  });

  final String methodLabel;
  final String statusLabel;
  final String authCode;
  final double amount;
  final bool hasPayment;
  final String? method;
  final String? status;
  final int? paymentId;
  final String? idempotencyKey;

  bool get isCompleted => status?.toLowerCase() == 'completed';

  @override
  List<Object?> get props => <Object?>[
    methodLabel,
    statusLabel,
    authCode,
    amount,
    hasPayment,
    method,
    status,
    paymentId,
    idempotencyKey,
  ];
}
