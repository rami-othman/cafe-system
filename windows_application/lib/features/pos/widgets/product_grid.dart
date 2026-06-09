import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../models/pos_product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  static const List<PosProduct> _products = <PosProduct>[
    PosProduct(
      name: 'Espresso',
      size: '1.5 oz',
      price: r'$3.50',
      available: true,
      icon: Icons.local_cafe_outlined,
    ),
    PosProduct(
      name: 'Cold Brew Reserve',
      size: '16 oz',
      price: r'$5.50',
      available: false,
      icon: Icons.local_drink_outlined,
    ),
    PosProduct(
      name: 'Cappuccino',
      size: '8 oz',
      price: r'$4.50',
      available: true,
      icon: Icons.coffee_outlined,
    ),
    PosProduct(
      name: 'Pour Over V60',
      size: '10 oz',
      price: r'$6.00',
      available: true,
      icon: Icons.coffee_maker_outlined,
    ),
    PosProduct(
      name: 'Americano',
      size: '12 oz',
      price: r'$3.75',
      available: true,
      icon: Icons.coffee_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int crossAxisCount = _columnCount(constraints.maxWidth);

        return GridView.builder(
          itemCount: _products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: AppSizes.productCardHeight,
            crossAxisSpacing: AppSizes.productGridGap,
            mainAxisSpacing: AppSizes.productGridGap,
          ),
          itemBuilder: (BuildContext context, int index) {
            return ProductCard(product: _products[index]);
          },
        );
      },
    );
  }

  int _columnCount(double width) {
    if (width >= AppSizes.productGridFiveColumnWidth) {
      return 5;
    }

    if (width >= AppSizes.productGridFourColumnWidth) {
      return 4;
    }

    if (width >= AppSizes.productGridThreeColumnWidth) {
      return 3;
    }

    if (width >= AppSizes.productGridTwoColumnWidth) {
      return 2;
    }

    return 1;
  }
}
