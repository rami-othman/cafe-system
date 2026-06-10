import 'package:equatable/equatable.dart';

import 'pos_product.dart';

class CartItem extends Equatable {
  const CartItem({
    required this.product,
    required this.quantity,
    this.modifiers = const <String>[],
  });

  final PosProduct product;
  final int quantity;
  final List<String> modifiers;

  double get lineTotal => product.price * quantity;

  CartItem copyWith({
    PosProduct? product,
    int? quantity,
    List<String>? modifiers,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
    );
  }

  @override
  List<Object?> get props => <Object?>[product, quantity, modifiers];
}
