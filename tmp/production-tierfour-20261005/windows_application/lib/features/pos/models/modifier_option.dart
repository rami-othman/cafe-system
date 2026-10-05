import 'package:equatable/equatable.dart';

import 'json_helpers.dart';

class ModifierOption extends Equatable {
  const ModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.isDefault,
    required this.isAvailable,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    return ModifierOption(
      id: readInt(json['id']) ?? 0,
      name: readString(json['name']),
      priceDelta: readDouble(json['priceDelta']),
      isDefault: readBool(json['isDefault']),
      isAvailable: readBool(json['isAvailable'], fallback: true),
    );
  }

  final int id;
  final String name;
  final double priceDelta;
  final bool isDefault;
  final bool isAvailable;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    priceDelta,
    isDefault,
    isAvailable,
  ];
}
