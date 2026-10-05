import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../models/pos_product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  final List<PosProduct> products;
  final ValueChanged<PosProduct> onProductTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int crossAxisCount = _columnCount(constraints.maxWidth);

        return GridView.builder(
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: AppSizes.productCardHeight,
            crossAxisSpacing: AppSizes.productGridGap,
            mainAxisSpacing: AppSizes.productGridGap,
          ),
          itemBuilder: (BuildContext context, int index) {
            final PosProduct product = products[index];

            return ProductCard(
              product: product,
              onTap: product.isAvailable ? () => onProductTap(product) : null,
            );
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
