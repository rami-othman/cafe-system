import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/pos_product.dart';
import 'pos_category_tabs.dart';
import 'pos_search_bar.dart';
import 'product_grid.dart';

class PosProductArea extends StatelessWidget {
  const PosProductArea({
    super.key,
    required this.products,
    required this.categories,
    required this.selectedCategory,
    required this.searchQuery,
    required this.isLoading,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onProductTap,
  });

  final List<PosProduct> products;
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<PosProduct> onProductTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double searchWidth = math.min(
          constraints.maxWidth,
          AppSizes.posSearchWidth,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ProductAreaHeader(
              searchWidth: searchWidth,
              categories: categories,
              selectedCategory: selectedCategory,
              searchQuery: searchQuery,
              onSearchChanged: onSearchChanged,
              onCategorySelected: onCategorySelected,
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ProductGrid(products: products, onProductTap: onProductTap),
            ),
          ],
        );
      },
    );
  }
}

class _ProductAreaHeader extends StatelessWidget {
  const _ProductAreaHeader({
    required this.searchWidth,
    required this.categories,
    required this.selectedCategory,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onCategorySelected,
  });

  final double searchWidth;
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PosSearchBar(
          width: searchWidth,
          query: searchQuery,
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        PosCategoryTabs(
          categories: categories,
          selectedCategory: selectedCategory,
          onCategorySelected: onCategorySelected,
        ),
      ],
    );
  }
}
