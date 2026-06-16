import 'package:equatable/equatable.dart';

import 'pos_product.dart';
import 'product_modifier.dart';

class ProductCustomization extends Equatable {
  const ProductCustomization({
    required this.product,
    required this.quantity,
    required this.temperature,
    required this.size,
    required this.milkBase,
    required this.addOns,
    required this.sweetness,
    required this.specialInstructions,
  });

  final PosProduct product;
  final int quantity;
  final String temperature;
  final ProductModifierOption size;
  final ProductModifierOption milkBase;
  final List<ProductModifierOption> addOns;
  final String sweetness;
  final String specialInstructions;

  double get unitPrice {
    final double addOnsTotal = addOns.fold<double>(
      0,
      (double total, ProductModifierOption option) => total + option.priceDelta,
    );
    final double price =
        product.price + size.priceDelta + milkBase.priceDelta + addOnsTotal;

    return price < 0 ? 0 : price;
  }

  double get totalPrice => unitPrice * quantity;

  List<String> get modifierLabels {
    return <String>[
      temperature,
      size.label,
      milkBase.label,
      ...addOns.map((ProductModifierOption option) => option.label),
      sweetness,
      if (specialInstructions.trim().isNotEmpty) specialInstructions.trim(),
    ];
  }

  String get configurationKey {
    final List<String> addOnIds =
        addOns
            .map((ProductModifierOption option) => option.id)
            .toList(growable: false)
          ..sort();

    return <String>[
      product.id,
      temperature,
      size.id,
      milkBase.id,
      addOnIds.join('+'),
      sweetness,
      specialInstructions.trim(),
    ].join('|');
  }

  @override
  List<Object?> get props => <Object?>[
    product,
    quantity,
    temperature,
    size,
    milkBase,
    addOns,
    sweetness,
    specialInstructions,
  ];
}
