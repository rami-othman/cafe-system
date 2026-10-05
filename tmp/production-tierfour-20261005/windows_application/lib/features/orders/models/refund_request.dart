import 'package:equatable/equatable.dart';

import 'refund_type.dart';

class RefundRequest extends Equatable {
  const RefundRequest({
    required this.orderId,
    required this.type,
    required this.amount,
    required this.reason,
    this.managerNotes = '',
  });

  final String orderId;
  final RefundType type;
  final double amount;
  final String reason;
  final String managerNotes;

  @override
  List<Object?> get props => <Object?>[
    orderId,
    type,
    amount,
    reason,
    managerNotes,
  ];
}
