import 'package:equatable/equatable.dart';

import 'json_helpers.dart';
import 'modifier_group.dart';

class BackendProductDetail extends Equatable {
  const BackendProductDetail({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.isAvailable,
    required this.modifierGroups,
  });

  factory BackendProductDetail.fromJson(Map<String, dynamic> json) {
    return BackendProductDetail(
      id: readInt(json['id']) ?? 0,
      categoryId: readInt(json['categoryId']),
      name: readString(json['name']),
      description: readString(json['description']),
      basePrice: readDouble(json['basePrice']),
      isAvailable: readBool(json['isAvailable'], fallback: true),
      modifierGroups: readMapList(
        json['modifierGroups'],
      ).map(ModifierGroup.fromJson).toList(growable: false),
    );
  }

  final int id;
  final int? categoryId;
  final String name;
  final String description;
  final double basePrice;
  final bool isAvailable;
  final List<ModifierGroup> modifierGroups;

  @override
  List<Object?> get props => <Object?>[
    id,
    categoryId,
    name,
    description,
    basePrice,
    isAvailable,
    modifierGroups,
  ];
}
