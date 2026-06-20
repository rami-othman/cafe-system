import 'package:equatable/equatable.dart';

class OrderPaymentSummary extends Equatable {
  const OrderPaymentSummary({
    required this.methodLabel,
    required this.statusLabel,
    required this.authCode,
    required this.amount,
  });

  final String methodLabel;
  final String statusLabel;
  final String authCode;
  final double amount;

  @override
  List<Object?> get props => <Object?>[
    methodLabel,
    statusLabel,
    authCode,
    amount,
  ];
}
