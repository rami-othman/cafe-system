import 'package:equatable/equatable.dart';

import '../../../core/config/tax_config.dart';
import 'json_helpers.dart';

class BackendOrderTotals extends Equatable {
  const BackendOrderTotals({
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.total,
    this.taxRate = TaxConfig.defaultTaxRate,
  });

  factory BackendOrderTotals.fromJson(Map<String, dynamic> json) {
    return BackendOrderTotals(
      subtotal: readDouble(json['subtotal']),
      discountTotal: readDouble(json['discountTotal']),
      taxTotal: readDouble(json['taxTotal']),
      taxRate: readDouble(json['taxRate'], fallback: TaxConfig.defaultTaxRate),
      total: readDouble(json['total']),
    );
  }

  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double taxRate;
  final double total;

  @override
  List<Object?> get props => <Object?>[
    subtotal,
    discountTotal,
    taxTotal,
    taxRate,
    total,
  ];
}
