import 'package:equatable/equatable.dart';

import '../../../core/config/tax_config.dart';
import 'json_helpers.dart';

class Branch extends Equatable {
  const Branch({
    required this.id,
    required this.name,
    required this.currency,
    required this.timezone,
    required this.isActive,
    this.taxRate = TaxConfig.defaultTaxRate,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: readInt(json['id']) ?? 0,
      name: readString(json['name']),
      currency: readString(json['currency'], fallback: 'SYP'),
      timezone: readString(json['timezone']),
      isActive: readBool(json['isActive'], fallback: true),
      taxRate: readDouble(json['taxRate'], fallback: TaxConfig.defaultTaxRate),
    );
  }

  final int id;
  final String name;
  final String currency;
  final String timezone;
  final bool isActive;
  final double taxRate;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    currency,
    timezone,
    isActive,
    taxRate,
  ];
}
