import 'package:flutter/material.dart';

import 'menu_placeholder_screen.dart';

class ProductVariantsPricingScreen extends StatelessWidget {
  const ProductVariantsPricingScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) =>
      const MenuPlaceholderScreen(title: 'Product Variants & Pricing');
}
