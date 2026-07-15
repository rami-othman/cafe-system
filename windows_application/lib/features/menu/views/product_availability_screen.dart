import 'package:flutter/material.dart';

import 'menu_placeholder_screen.dart';

class ProductAvailabilityScreen extends StatelessWidget {
  const ProductAvailabilityScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) =>
      const MenuPlaceholderScreen(title: 'Product Availability');
}
