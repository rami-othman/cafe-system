import 'package:equatable/equatable.dart';

import '../../../core/config/tax_config.dart';
import '../../printer/models/printer_config.dart';
import 'json_helpers.dart';

class Branch extends Equatable {
  const Branch({
    required this.id,
    required this.name,
    required this.currency,
    required this.timezone,
    required this.isActive,
    this.taxRate = TaxConfig.defaultTaxRate,
    this.printerConfig = const PrinterConfig(),
    this.branchType = 'cafe',
    this.defaultWarehouseId,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: readInt(json['id']) ?? 0,
      name: readString(json['name']),
      branchType: readString(json['branchType'], fallback: 'cafe'),
      defaultWarehouseId: readInt(json['defaultWarehouseId']),
      currency: readString(json['currency'], fallback: 'SYP'),
      timezone: readString(json['timezone']),
      isActive: readBool(json['isActive'], fallback: true),
      taxRate: readDouble(json['taxRate'], fallback: TaxConfig.defaultTaxRate),
      printerConfig: json['printerConfig'] is Map
          ? PrinterConfig.fromJson(
              (json['printerConfig'] as Map).cast<String, dynamic>(),
            )
          : const PrinterConfig(),
    );
  }

  final int id;
  final String name;
  final String branchType;
  final int? defaultWarehouseId;
  bool get isFactory => branchType == 'factory';
  final String currency;
  final String timezone;
  final bool isActive;
  final double taxRate;
  final PrinterConfig printerConfig;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    branchType,
    defaultWarehouseId,
    currency,
    timezone,
    isActive,
    taxRate,
    printerConfig,
  ];
}
