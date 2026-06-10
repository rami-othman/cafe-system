import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/pos_cubit.dart';
import '../controllers/pos_state.dart';
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
            onProductTap: cubit.addProductToCart,
          ),
        );
      },
    );
  }
}
