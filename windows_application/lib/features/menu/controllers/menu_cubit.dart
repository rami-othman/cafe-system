import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/menu_enums.dart';
import '../models/menu_kpis.dart';
import '../models/menu_product.dart';
import '../repositories/menu_repository.dart';
import 'menu_state.dart';

class MenuCubit extends Cubit<MenuState> {
  MenuCubit({required this.repository}) : super(const MenuState());

  final MenuRepository repository;

  Future<void> loadMenuData() async {
    emit(
      state.copyWith(
        loadingStatus: MenuLoadingStatus.loading,
        clearErrorMessage: true,
      ),
    );

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        repository.getCategories(),
        repository.getProducts(),
        repository.getModifierGroups(),
        repository.getRecentActivities(),
        repository.getMenuKpis(),
      ]);
      emit(
        state.copyWith(
          loadingStatus: MenuLoadingStatus.loaded,
          categories: results[0] as dynamic,
          products: results[1] as dynamic,
          modifierGroups: results[2] as dynamic,
          recentActivities: results[3] as dynamic,
          kpis: results[4] as MenuKpis,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loadingStatus: MenuLoadingStatus.failure,
          errorMessage: 'Could not load menu data.',
        ),
      );
    }
  }

  void changeTab(MenuTab tab) {
    emit(state.copyWith(selectedMenuTab: tab));
  }

  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void updateFilters({
    String? category,
    ProductType? type,
    ProductStatus? status,
    String? branch,
    StockStatus? availability,
    bool clearCategory = false,
    bool clearType = false,
    bool clearStatus = false,
    bool clearBranch = false,
    bool clearAvailability = false,
  }) {
    emit(
      state.copyWith(
        selectedCategoryFilter: category,
        clearCategoryFilter: clearCategory,
        selectedTypeFilter: type,
        clearTypeFilter: clearType,
        selectedStatusFilter: status,
        clearStatusFilter: clearStatus,
        selectedBranchFilter: branch,
        clearBranchFilter: clearBranch,
        selectedAvailabilityFilter: availability,
        clearAvailabilityFilter: clearAvailability,
      ),
    );
  }

  List<MenuProduct> getFilteredProducts() {
    final String query = state.searchQuery.trim().toLowerCase();
    return state.products
        .where((MenuProduct product) {
          final bool matchesSearch =
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query);
          final bool matchesCategory =
              state.selectedCategoryFilter == null ||
              product.categoryId == state.selectedCategoryFilter;
          final bool matchesType =
              state.selectedTypeFilter == null ||
              product.type == state.selectedTypeFilter;
          final bool matchesStatus =
              state.selectedStatusFilter == null ||
              product.status == state.selectedStatusFilter;
          final bool matchesBranch =
              state.selectedBranchFilter == null ||
              product.branchIds.contains(state.selectedBranchFilter);
          return matchesSearch &&
              matchesCategory &&
              matchesType &&
              matchesStatus &&
              matchesBranch;
        })
        .toList(growable: false);
  }

  Future<MenuKpis> getMenuKpis() => repository.getMenuKpis();
}
