class CartItem {
  const CartItem({
    required this.name,
    required this.modifiers,
    required this.price,
    required this.quantity,
  });

  final String name;
  final String modifiers;
  final String price;
  final int quantity;
}
