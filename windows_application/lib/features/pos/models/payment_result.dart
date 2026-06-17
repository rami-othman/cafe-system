import 'package:equatable/equatable.dart';

import 'payment_method.dart';

class PaymentResult extends Equatable {
  const PaymentResult({
    required this.method,
    required this.totalDue,
    required this.amountReceived,
    required this.changeDue,
  });

  final PaymentMethod method;
  final double totalDue;
  final double amountReceived;
  final double changeDue;

  @override
  List<Object?> get props => <Object?>[
    method,
    totalDue,
    amountReceived,
    changeDue,
  ];
}
