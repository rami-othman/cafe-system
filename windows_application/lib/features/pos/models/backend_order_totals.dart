import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

class BackendOrderTotals extends Equatable {
  const BackendOrderTotals({
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.total,
  });

  factory BackendOrderTotals.fromJson(Map<String, dynamic> json) {
    return BackendOrderTotals(
      subtotal: readDouble(json['subtotal']),
      discountTotal: readDouble(json['discountTotal']),
      taxTotal: readDouble(json['taxTotal']),
      total: readDouble(json['total']),
    );
  }

  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double total;

  @override
  List<Object?> get props => <Object?>[
    subtotal,
    discountTotal,
    taxTotal,
    total,
  ];
}
