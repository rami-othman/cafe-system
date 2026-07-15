import 'package:equatable/equatable.dart';

import 'menu_enums.dart';

class ModifierOption extends Equatable {
  const ModifierOption({
    required this.id,
    required this.groupId,
    required this.name,
    required this.extraPrice,
    required this.isDefault,
    required this.stockStatus,
    required this.isActive,
  });

  final String id;
  final String groupId;
  final String name;
  final double extraPrice;
  final bool isDefault;
  final StockStatus stockStatus;
  final bool isActive;

  @override
  List<Object?> get props => <Object?>[
    id,
    groupId,
    name,
    extraPrice,
    isDefault,
    stockStatus,
    isActive,
  ];
}
