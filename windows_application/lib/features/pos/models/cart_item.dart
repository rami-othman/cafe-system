import 'package:equatable/equatable.dart';

import 'pos_product.dart';
import 'cart_configuration.dart';
import 'selected_modifier.dart';

class CartItem extends Equatable {
  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.backendItemId,
    this.backendProductId,
    this.modifiers = const <String>[],
    this.selectedModifiers = const <SelectedModifier>[],
    this.specialInstructions = '',
  });

  final String id;
  final int? backendItemId;
  final int? backendProductId;
  final PosProduct product;
  final int quantity;
  final double unitPrice;
  final List<String> modifiers;
  final List<SelectedModifier> selectedModifiers;
  final String specialInstructions;

  double get lineTotal => unitPrice * quantity;

  bool get hasCompleteBackendConfiguration {
    return backendProductId != null &&
        CartConfiguration.hasCompleteModifierIdentity(selectedModifiers);
  }

  String? get backendConfigurationKey {
    if (!hasCompleteBackendConfiguration) {
      return null;
    }
    return CartConfiguration.build(
      productId: backendProductId!,
      modifiers: selectedModifiers,
      specialInstructions: specialInstructions,
    );
  }

  String get configurationKey => backendConfigurationKey ?? id;

  CartItem copyWith({
    String? id,
    PosProduct? product,
    int? quantity,
    double? unitPrice,
    int? backendItemId,
    int? backendProductId,
    List<String>? modifiers,
    List<SelectedModifier>? selectedModifiers,
    String? specialInstructions,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      backendItemId: backendItemId ?? this.backendItemId,
      backendProductId: backendProductId ?? this.backendProductId,
      modifiers: modifiers ?? this.modifiers,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    backendItemId,
    backendProductId,
    product,
    quantity,
    unitPrice,
    modifiers,
    selectedModifiers,
    specialInstructions,
  ];
}
