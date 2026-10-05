import 'package:equatable/equatable.dart';

import 'json_helpers.dart';
import 'selected_modifier.dart';
import 'cart_configuration.dart';

class BackendOrderItemModifier extends Equatable {
  const BackendOrderItemModifier({
    required this.groupId,
    required this.optionId,
    required this.optionName,
    required this.priceDelta,
  });

  factory BackendOrderItemModifier.fromJson(Map<String, dynamic> json) {
    return BackendOrderItemModifier(
      groupId: readInt(json['groupId']) ?? 0,
      optionId: readInt(json['optionId']) ?? 0,
      optionName: readString(
        json['optionName'],
        fallback: readString(json['name']),
      ),
      priceDelta: readDouble(json['priceDelta']),
    );
  }

  final int groupId;
  final int optionId;
  final String optionName;
  final double priceDelta;

  @override
  List<Object?> get props => <Object?>[
    groupId,
    optionId,
    optionName,
    priceDelta,
  ];
}

class BackendOrderItem extends Equatable {
  const BackendOrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.modifiers,
    this.note,
    this.variantId,
    this.placementId,
  });

  factory BackendOrderItem.fromJson(Map<String, dynamic> json) {
    return BackendOrderItem(
      id: readInt(json['id']) ?? 0,
      productId: readInt(json['productId']) ?? 0,
      name: readString(json['name']),
      quantity: readDouble(json['quantity']).round(),
      unitPrice: readDouble(json['unitPrice']),
      lineTotal: readDouble(json['lineTotal']),
      modifiers: readMapList(
        json['modifiers'],
      ).map(BackendOrderItemModifier.fromJson).toList(growable: false),
      note: readString(json['note']).trim().isEmpty
          ? null
          : readString(json['note']).trim(),
      variantId: readInt(json['variantId']),
      placementId: readInt(json['placementId']),
    );
  }

  final int id;
  final int productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<BackendOrderItemModifier> modifiers;
  final String? note;
  final int? variantId;
  final int? placementId;

  List<String> get modifierLabels {
    return modifiers
        .map((BackendOrderItemModifier modifier) => modifier.optionName)
        .where((String label) => label.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<SelectedModifier> get selectedModifiers => modifiers
      .map(
        (BackendOrderItemModifier modifier) => SelectedModifier(
          groupId: modifier.groupId,
          optionId: modifier.optionId,
        ),
      )
      .toList(growable: false);

  String? get configurationKey {
    if (productId <= 0 ||
        !CartConfiguration.hasCompleteModifierIdentity(selectedModifiers)) {
      return null;
    }
    return CartConfiguration.build(
      productId: productId,
      modifiers: selectedModifiers,
      specialInstructions: note ?? '',
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    productId,
    name,
    quantity,
    unitPrice,
    lineTotal,
    modifiers,
    note,
    variantId,
    placementId,
  ];
}
