import 'package:equatable/equatable.dart';

import 'pos_product.dart';

class CartItem extends Equatable {
  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.modifiers = const <String>[],
    this.specialInstructions = '',
  });

  final String id;
  final PosProduct product;
  final int quantity;
  final double unitPrice;
  final List<String> modifiers;
  final String specialInstructions;

  double get lineTotal => unitPrice * quantity;

  CartItem copyWith({
    String? id,
    PosProduct? product,
    int? quantity,
    double? unitPrice,
    List<String>? modifiers,
    String? specialInstructions,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      modifiers: modifiers ?? this.modifiers,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    product,
    quantity,
    unitPrice,
    modifiers,
    specialInstructions,
  ];
}
