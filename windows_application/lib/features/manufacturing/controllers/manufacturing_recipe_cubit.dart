import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../inventory/models/inventory_models.dart';
import '../../inventory/repositories/inventory_repository.dart';
import '../repositories/manufacturing_repository.dart';
import 'manufacturing_recipe_state.dart';

/// Recipes screen-cluster (list/detail/create/edit/status/duplicate). Kept
/// separate from [ManufacturingCubit] (Overview) and the Production/Reports
/// cubits per the module's "one Cubit per screen-cluster" rule.
class ManufacturingRecipeCubit extends Cubit<ManufacturingRecipeState> {
  ManufacturingRecipeCubit({
    required this.repository,
    required this.inventoryRepository,
  }) : super(const ManufacturingRecipeState());

  final ManufacturingRepository repository;
  final InventoryRepository inventoryRepository;

  int _requestGeneration = 0;

  Future<void> loadRecipes({
    String? search,
    String? type,
    String? status,
  }) async {
    final int generation = ++_requestGeneration;
    bool isCurrent() => generation == _requestGeneration;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final recipes = await repository.recipes(
        search: search,
        type: type,
        status: status,
      );
      if (!isCurrent()) return;
      emit(state.copyWith(recipes: recipes, clearError: true));
    } catch (error) {
      if (!isCurrent()) return;
      emit(state.copyWith(error: _messageFor(error)));
    } finally {
      if (isCurrent()) emit(state.copyWith(loading: false));
    }
  }

  /// Loads the raw_material/semi_finished_good/packaging items usable as
  /// recipe ingredients, via `InventoryRepository` - never a parallel
  /// Manufacturing ingredient-search endpoint.
  Future<void> loadIngredientCandidates() async {
    try {
      final List<InventoryItem> rawMaterials = await inventoryRepository.items(
        type: 'raw_material',
        activeOnly: true,
      );
      final List<InventoryItem> semiFinished = await inventoryRepository.items(
        type: 'semi_finished_good',
        activeOnly: true,
      );
      final List<InventoryItem> packaging = await inventoryRepository.items(
        type: 'packaging',
        activeOnly: true,
      );
      emit(
        state.copyWith(
          ingredientCandidates: <InventoryItem>[
            ...rawMaterials,
            ...semiFinished,
            ...packaging,
          ],
        ),
      );
    } catch (_) {
      // Non-fatal: the ingredient picker degrades to an empty list rather
      // than blocking the whole recipe form.
    }
  }

  /// finished_good / semi_finished_good items eligible as a recipe's output
  /// product - loaded the same way as ingredients, via `InventoryRepository`.
  Future<void> loadOutputItemCandidates() async {
    try {
      final List<InventoryItem> finished = await inventoryRepository.items(
        type: 'finished_good',
        activeOnly: true,
      );
      final List<InventoryItem> semiFinished = await inventoryRepository.items(
        type: 'semi_finished_good',
        activeOnly: true,
      );
      emit(
        state.copyWith(
          outputItemCandidates: <InventoryItem>[...finished, ...semiFinished],
        ),
      );
    } catch (_) {
      // Non-fatal, same rationale as loadIngredientCandidates.
    }
  }

  Future<void> loadRecipe(int id) async {
    emit(state.copyWith(loading: true, clearError: true, clearSelected: true));
    try {
      final recipe = await repository.recipe(id);
      emit(state.copyWith(selected: recipe, clearError: true));
    } catch (error) {
      emit(state.copyWith(error: _messageFor(error)));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  Future<bool> saveRecipe(Map<String, dynamic> payload, {int? id}) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final detail = id == null
          ? await repository.createRecipe(payload)
          : await repository.updateRecipe(id, payload);
      emit(state.copyWith(saving: false, selected: detail, clearError: true));
      return true;
    } catch (error) {
      emit(state.copyWith(saving: false, error: _messageFor(error)));
      return false;
    }
  }

  Future<bool> setStatus(int id, String status) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final detail = await repository.setRecipeStatus(id, status);
      emit(state.copyWith(saving: false, selected: detail, clearError: true));
      return true;
    } catch (error) {
      emit(state.copyWith(saving: false, error: _messageFor(error)));
      return false;
    }
  }

  String _messageFor(Object error) {
    final ApiException? apiError = error is ApiException ? error : null;
    return apiError?.message ?? 'تعذر إتمام العملية، حاول مرة أخرى.';
  }
}
