import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/pos_product.dart';
import '../models/pos_menu_runtime_models.dart';
import 'pos_menu_navigation.dart';
import 'pos_search_bar.dart';
import 'product_grid.dart';

class PosProductArea extends StatelessWidget {
  const PosProductArea({
    super.key,
    required this.products,
    required this.menus,
    required this.selectedMenuId,
    required this.sections,
    required this.selectedSectionId,
    required this.searchQuery,
    required this.isLoading,
    this.emptyMessage,
    required this.onSearchChanged,
    required this.onMenuSelected,
    required this.onSectionSelected,
    required this.onProductTap,
    this.legacyCategories = const <String>[],
    this.selectedLegacyCategory = '',
    this.onLegacyCategorySelected,
  });

  final List<PosProduct> products;
  final List<PosStaticMenu> menus;
  final int? selectedMenuId;
  final List<PosStaticSection> sections;
  final int? selectedSectionId;
  final String searchQuery;
  final bool isLoading;
  final String? emptyMessage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onMenuSelected;
  final ValueChanged<int> onSectionSelected;
  final ValueChanged<PosProduct> onProductTap;
  final List<String> legacyCategories;
  final String selectedLegacyCategory;
  final ValueChanged<String>? onLegacyCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ProductAreaHeader(
          menus: menus,
          selectedMenuId: selectedMenuId,
          sections: sections,
          selectedSectionId: selectedSectionId,
          searchQuery: searchQuery,
          onSearchChanged: onSearchChanged,
          onMenuSelected: onMenuSelected,
          onSectionSelected: onSectionSelected,
          legacyCategories: legacyCategories,
          selectedLegacyCategory: selectedLegacyCategory,
          onLegacyCategorySelected: onLegacyCategorySelected,
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
              ? _ProductAreaEmpty(message: emptyMessage)
              : ProductGrid(products: products, onProductTap: onProductTap),
        ),
      ],
    );
  }
}

class _ProductAreaHeader extends StatelessWidget {
  const _ProductAreaHeader({
    required this.menus,
    required this.selectedMenuId,
    required this.sections,
    required this.selectedSectionId,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onMenuSelected,
    required this.onSectionSelected,
    required this.legacyCategories,
    required this.selectedLegacyCategory,
    required this.onLegacyCategorySelected,
  });

  final List<PosStaticMenu> menus;
  final int? selectedMenuId;
  final List<PosStaticSection> sections;
  final int? selectedSectionId;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onMenuSelected;
  final ValueChanged<int> onSectionSelected;
  final List<String> legacyCategories;
  final String selectedLegacyCategory;
  final ValueChanged<String>? onLegacyCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.posSearchWidth),
          child: PosSearchBar(query: searchQuery, onChanged: onSearchChanged),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (menus.isNotEmpty)
          PosMenuNavigation(
            menus: menus,
            selectedMenuId: selectedMenuId,
            sections: sections,
            selectedSectionId: selectedSectionId,
            languageCode: Localizations.localeOf(context).languageCode,
            onMenuSelected: onMenuSelected,
            onSectionSelected: onSectionSelected,
          )
        else if (legacyCategories.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: legacyCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final String category = legacyCategories[index];
                return ChoiceChip(
                  label: Text(category, overflow: TextOverflow.ellipsis),
                  selected: category == selectedLegacyCategory,
                  onSelected: (_) => onLegacyCategorySelected?.call(category),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ProductAreaEmpty extends StatelessWidget {
  const _ProductAreaEmpty({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(message ?? 'No items available.', textAlign: TextAlign.center),
  );
}
