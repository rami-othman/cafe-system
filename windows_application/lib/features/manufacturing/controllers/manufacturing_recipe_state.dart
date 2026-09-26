import 'package:equatable/equatable.dart';

import '../../inventory/models/inventory_models.dart';
import '../models/manufacturing_recipe_models.dart';

class ManufacturingRecipeState extends Equatable {
  const ManufacturingRecipeState({
    this.loading = false,
    this.saving = false,
    this.recipes = const <ManufacturingRecipeSummary>[],
    this.ingredientCandidates = const <InventoryItem>[],
    this.outputItemCandidates = const <InventoryItem>[],
    this.selected,
    this.error,
  });

  final bool loading;
  final bool saving;
  final List<ManufacturingRecipeSummary> recipes;

  /// Raw material / semi-finished / packaging items available as recipe
  /// ingredients, loaded via `InventoryRepository.items()` - the recipe
  /// screens never call a separate Manufacturing "ingredient search" endpoint.
  final List<InventoryItem> ingredientCandidates;

  /// finished_good / semi_finished_good items eligible as a recipe's output
  /// product, mirroring the backend's own `loadOutputItem()` restriction.
  final List<InventoryItem> outputItemCandidates;
  final ManufacturingRecipeDetail? selected;
  final String? error;

  ManufacturingRecipeState copyWith({
    bool? loading,
    bool? saving,
    List<ManufacturingRecipeSummary>? recipes,
    List<InventoryItem>? ingredientCandidates,
    List<InventoryItem>? outputItemCandidates,
    ManufacturingRecipeDetail? selected,
    String? error,
    bool clearError = false,
    bool clearSelected = false,
  }) => ManufacturingRecipeState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    recipes: recipes ?? this.recipes,
    ingredientCandidates: ingredientCandidates ?? this.ingredientCandidates,
    outputItemCandidates: outputItemCandidates ?? this.outputItemCandidates,
    selected: clearSelected ? null : selected ?? this.selected,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => <Object?>[
    loading,
    saving,
    recipes,
    ingredientCandidates,
    outputItemCandidates,
    selected,
    error,
  ];
}
