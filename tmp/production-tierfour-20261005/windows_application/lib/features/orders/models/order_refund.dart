import 'package:equatable/equatable.dart';

import 'refund_type.dart';

class OrderRefund extends Equatable {
  const OrderRefund({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.managerNotes,
    required this.status,
    required this.refundedAt,
    this.idempotencyKey,
  });

  final String id;
  final RefundType type;
  final double amount;
  final String reason;
  final String managerNotes;
  final String status;
  final DateTime refundedAt;
  final String? idempotencyKey;

  @override
  List<Object?> get props => <Object?>[
    id,
    type,
    amount,
    reason,
    managerNotes,
    status,
    refundedAt,
    idempotencyKey,
  ];
}
