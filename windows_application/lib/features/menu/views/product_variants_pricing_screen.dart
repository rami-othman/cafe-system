import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/widgets/app_breadcrumbs.dart';
import 'menu_placeholder_screen.dart';

class ProductVariantsPricingScreen extends StatelessWidget {
  const ProductVariantsPricingScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) => MenuPlaceholderScreen(
    title: 'Product Variants & Pricing',
    breadcrumbs: <AppBreadcrumbItem>[
      AppBreadcrumbItem(
        label: 'Menu',
        onTap: () => context.go(AppRoutes.menu),
        key: const Key('breadcrumb-menu'),
      ),
      AppBreadcrumbItem(
        label: 'Products',
        onTap: () => context.go(AppRoutes.menuProducts),
        key: const Key('breadcrumb-products'),
      ),
    ],
  );
}
