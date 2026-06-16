import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/pos_cubit.dart';
import '../controllers/pos_state.dart';
import '../models/pos_product.dart';
import '../models/product_customization.dart';
import '../widgets/product_customization_dialog.dart';
import '../widgets/pos_product_area.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (BuildContext context, PosState state) {
        final PosCubit cubit = context.read<PosCubit>();

        return DesktopPageLayout(
          child: PosProductArea(
            products: state.filteredProducts,
            categories: state.categories,
            selectedCategory: state.selectedCategory,
            searchQuery: state.searchQuery,
            isLoading: state.isLoading,
            onSearchChanged: cubit.updateSearchQuery,
            onCategorySelected: cubit.selectCategory,
            onProductTap: (PosProduct product) =>
                _showCustomizationDialog(context, cubit, product),
          ),
        );
      },
    );
  }

  Future<void> _showCustomizationDialog(
    BuildContext context,
    PosCubit cubit,
    PosProduct product,
  ) async {
    if (!product.isAvailable) {
      return;
    }

    final ProductCustomization? customization =
        await showGeneralDialog<ProductCustomization>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Close customization dialog',
          barrierColor: AppColors.black.withValues(alpha: 0.4),
          transitionDuration: const Duration(milliseconds: 160),
          pageBuilder:
              (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: ProductCustomizationDialog(product: product),
                );
              },
        );

    if (!context.mounted || customization == null) {
      return;
    }

    cubit.addCustomizedProductToCart(customization);
  }
}
