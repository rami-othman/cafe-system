import 'package:equatable/equatable.dart';

import '../models/menu_activity.dart';
import '../models/menu_category.dart';
import '../models/menu_enums.dart';
import '../models/menu_product.dart';
import '../models/modifier_group.dart';

enum MenuLoadingStatus { initial, loading, loaded, failure }

enum MenuTab { overview, products, categories, modifiers, combos }

class MenuState extends Equatable {
  const MenuState({
    this.loadingStatus = MenuLoadingStatus.initial,
    this.errorMessage,
    this.categories = const <MenuCategory>[],
    this.products = const <MenuProduct>[],
    this.modifierGroups = const <ModifierGroup>[],
    this.recentActivities = const <MenuActivity>[],
    this.selectedMenuTab = MenuTab.overview,
    this.searchQuery = '',
    this.selectedCategoryFilter,
    this.selectedTypeFilter,
    this.selectedStatusFilter,
    this.selectedBranchFilter,
    this.selectedAvailabilityFilter,
  });

  final MenuLoadingStatus loadingStatus;
  final String? errorMessage;
  final List<MenuCategory> categories;
  final List<MenuProduct> products;
  final List<ModifierGroup> modifierGroups;
  final List<MenuActivity> recentActivities;
  final MenuTab selectedMenuTab;
  final String searchQuery;
  final String? selectedCategoryFilter;
  final ProductType? selectedTypeFilter;
  final ProductStatus? selectedStatusFilter;
  final String? selectedBranchFilter;
  final StockStatus? selectedAvailabilityFilter;

  MenuState copyWith({
    MenuLoadingStatus? loadingStatus,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<MenuCategory>? categories,
    List<MenuProduct>? products,
    List<ModifierGroup>? modifierGroups,
    List<MenuActivity>? recentActivities,
    MenuTab? selectedMenuTab,
    String? searchQuery,
    String? selectedCategoryFilter,
    bool clearCategoryFilter = false,
    ProductType? selectedTypeFilter,
    bool clearTypeFilter = false,
    ProductStatus? selectedStatusFilter,
    bool clearStatusFilter = false,
    String? selectedBranchFilter,
    bool clearBranchFilter = false,
    StockStatus? selectedAvailabilityFilter,
    bool clearAvailabilityFilter = false,
  }) {
    return MenuState(
      loadingStatus: loadingStatus ?? this.loadingStatus,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      modifierGroups: modifierGroups ?? this.modifierGroups,
      recentActivities: recentActivities ?? this.recentActivities,
      selectedMenuTab: selectedMenuTab ?? this.selectedMenuTab,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryFilter: clearCategoryFilter
          ? null
          : selectedCategoryFilter ?? this.selectedCategoryFilter,
      selectedTypeFilter: clearTypeFilter
          ? null
          : selectedTypeFilter ?? this.selectedTypeFilter,
      selectedStatusFilter: clearStatusFilter
          ? null
          : selectedStatusFilter ?? this.selectedStatusFilter,
      selectedBranchFilter: clearBranchFilter
          ? null
          : selectedBranchFilter ?? this.selectedBranchFilter,
      selectedAvailabilityFilter: clearAvailabilityFilter
          ? null
          : selectedAvailabilityFilter ?? this.selectedAvailabilityFilter,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    loadingStatus,
    errorMessage,
    categories,
    products,
    modifierGroups,
    recentActivities,
    selectedMenuTab,
    searchQuery,
    selectedCategoryFilter,
    selectedTypeFilter,
    selectedStatusFilter,
    selectedBranchFilter,
    selectedAvailabilityFilter,
  ];
}
