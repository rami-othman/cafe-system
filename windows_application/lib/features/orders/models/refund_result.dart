import 'package:equatable/equatable.dart';

import 'refund_type.dart';

class RefundResult extends Equatable {
  const RefundResult({
    required this.orderId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.managerNotes,
    required this.refundedAt,
  });

  final String orderId;
  final RefundType type;
  final double amount;
  final String reason;
  final String managerNotes;
  final DateTime refundedAt;

  @override
  List<Object?> get props => <Object?>[
    orderId,
    type,
    amount,
    reason,
    managerNotes,
    refundedAt,
  ];
}
