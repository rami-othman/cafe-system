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

  int ingredientPage = 1;
  int ingredientLastPage = 1;
  String ingredientSearch = '';
  int _ingredientRequest = 0;

  Future<void> loadIngredientCandidates({String? search, bool nextPage = false}) async {
    final request = ++_ingredientRequest;
    ingredientSearch = search ?? ingredientSearch;
    final page = nextPage ? ingredientPage + 1 : 1;
    try {
      final response = await repository.ingredients(search: ingredientSearch, page: page);
      if (request != _ingredientRequest || isClosed) return;
      ingredientPage = page;
      ingredientLastPage = (response['meta'] as Map)['lastPage'] as int;
      final candidates = (response['data'] as List).map((dynamic row) => InventoryItem.fromJson(Map<String, dynamic>.from(row as Map)));
      final byId = <int, InventoryItem>{for (final item in state.ingredientCandidates) item.id: item};
      for (final item in candidates) { byId[item.id] = item; }
      emit(state.copyWith(ingredientCandidates: byId.values.toList(), clearError: true));
    } catch (error) {
      if (request == _ingredientRequest && !isClosed) emit(state.copyWith(error: _messageFor(error)));
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
    } catch (error) {
      emit(state.copyWith(error: _messageFor(error)));
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
