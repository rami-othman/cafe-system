import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/models/product_customization.dart';
import 'package:windows_application/features/pos/models/product_modifier.dart';

void main() {
  const PosProduct cappuccino = PosProduct(
    id: 'cappuccino',
    name: 'Cappuccino',
    category: 'COFFEE',
    size: '8 oz',
    price: 4.50,
    isAvailable: true,
    icon: Icons.coffee_outlined,
  );

  test('calculates unit and total price from selected modifiers', () {
    const ProductCustomization customization = ProductCustomization(
      product: cappuccino,
      quantity: 2,
      temperature: 'Hot',
      size: ProductModifierOption(
        id: 'large',
        label: 'Large (16oz)',
        priceDelta: 0.75,
      ),
      milkBase: ProductModifierOption(
        id: 'oat',
        label: 'Oat Milk',
        priceDelta: 0.75,
      ),
      addOns: <ProductModifierOption>[
        ProductModifierOption(
          id: 'extra-espresso',
          label: 'Extra Espresso Shot',
          priceDelta: 1,
        ),
      ],
      sweetness: '100%',
      specialInstructions: 'Extra hot',
    );

    expect(customization.unitPrice, 7);
    expect(customization.totalPrice, 14);
    expect(customization.modifierLabels, <String>[
      'Hot',
      'Large (16oz)',
      'Oat Milk',
      'Extra Espresso Shot',
      '100%',
      'Extra hot',
    ]);
  });

  test('does not allow a negative unit price', () {
    const ProductCustomization customization = ProductCustomization(
      product: cappuccino,
      quantity: 1,
      temperature: 'Hot',
      size: ProductModifierOption(id: 'promo', label: 'Promo', priceDelta: -10),
      milkBase: ProductModifierOption(id: 'whole', label: 'Whole Milk'),
      addOns: <ProductModifierOption>[],
      sweetness: '100%',
      specialInstructions: '',
    );

    expect(customization.unitPrice, 0);
    expect(customization.totalPrice, 0);
  });
}
