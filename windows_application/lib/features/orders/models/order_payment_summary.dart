import 'package:equatable/equatable.dart';

class OrderPaymentSummary extends Equatable {
  const OrderPaymentSummary({
    required this.methodLabel,
    required this.statusLabel,
    required this.authCode,
    required this.amount,
    this.hasPayment = true,
  });

  final String methodLabel;
  final String statusLabel;
  final String authCode;
  final double amount;
  final bool hasPayment;

  @override
  List<Object?> get props => <Object?>[
    methodLabel,
    statusLabel,
    authCode,
    amount,
    hasPayment,
  ];
}
