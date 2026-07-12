import 'package:equatable/equatable.dart';

import 'payment_method.dart';

class PaymentResult extends Equatable {
  const PaymentResult({
    required this.method,
    required this.totalDue,
    required this.amountReceived,
    required this.changeDue,
    this.status,
    this.paymentId,
  });

  final PaymentMethod method;
  final double totalDue;
  final double amountReceived;
  final double changeDue;
  final String? status;
  final int? paymentId;

  @override
  List<Object?> get props => <Object?>[
    method,
    totalDue,
    amountReceived,
    changeDue,
    status,
    paymentId,
  ];
}
