import 'package:flutter/material.dart';

import '../models/pos_product.dart';

class PosRepository {
  const PosRepository();

  List<String> getCategories() {
    return const <String>[
      'COFFEE',
      'TEA',
      'COLD DRINKS',
      'DESSERTS',
      'SANDWICHES',
      'ADD-ONS',
    ];
  }

  List<PosProduct> getProducts() {
    return const <PosProduct>[
      PosProduct(
        id: 'espresso',
        name: 'Espresso',
        category: 'COFFEE',
        size: '1.5 oz',
        price: 3.50,
        isAvailable: true,
        icon: Icons.local_cafe_outlined,
      ),
      PosProduct(
        id: 'cold-brew-reserve',
        name: 'Cold Brew Reserve',
        category: 'COFFEE',
        size: '16 oz',
        price: 5.50,
        isAvailable: false,
        icon: Icons.local_drink_outlined,
      ),
      PosProduct(
        id: 'cappuccino',
        name: 'Cappuccino',
        category: 'COFFEE',
        size: '8 oz',
        price: 4.50,
        isAvailable: true,
        icon: Icons.coffee_outlined,
      ),
      PosProduct(
        id: 'pour-over-v60',
        name: 'Pour Over V60',
        category: 'COFFEE',
        size: '10 oz',
        price: 6.00,
        isAvailable: true,
        icon: Icons.coffee_maker_outlined,
      ),
      PosProduct(
        id: 'americano',
        name: 'Americano',
        category: 'COFFEE',
        size: '12 oz',
        price: 3.75,
        isAvailable: true,
        icon: Icons.coffee_outlined,
      ),
      PosProduct(
        id: 'green-tea',
        name: 'Green Tea',
        category: 'TEA',
        size: '10 oz',
        price: 3.25,
        isAvailable: true,
        icon: Icons.emoji_food_beverage_outlined,
      ),
      PosProduct(
        id: 'iced-tea',
        name: 'Iced Tea',
        category: 'COLD DRINKS',
        size: '16 oz',
        price: 3.75,
        isAvailable: true,
        icon: Icons.local_drink_outlined,
      ),
      PosProduct(
        id: 'almond-croissant',
        name: 'Almond Croissant',
        category: 'DESSERTS',
        size: '1 pc',
        price: 4.50,
        isAvailable: true,
        icon: Icons.bakery_dining_outlined,
      ),
    ];
  }
}
