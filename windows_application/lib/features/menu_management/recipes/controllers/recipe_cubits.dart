// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/menu_catalog_repository.dart';
import '../../models/catalog_models.dart';
import '../models/recipe_models.dart';

class VariantRecipeState extends Equatable {
  const VariantRecipeState({
    this.loading = false,
    this.saving = false,
    this.recipe,
    this.materials = const <RecipeMaterial>[],
    this.product,
    this.draft = const <RecipeComponent>[],
    this.error,
  });
  final bool loading;
  final bool saving;
  final VariantRecipe? recipe;
  final List<RecipeMaterial> materials;
  final ProductDetail? product;
  final List<RecipeComponent> draft;
  final String? error;
  VariantRecipeState copyWith({
    bool? loading,
    bool? saving,
    VariantRecipe? recipe,
    List<RecipeMaterial>? materials,
    ProductDetail? product,
    List<RecipeComponent>? draft,
    String? error,
    bool clearError = false,
  }) => VariantRecipeState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    recipe: recipe ?? this.recipe,
    materials: materials ?? this.materials,
    product: product ?? this.product,
    draft: draft ?? this.draft,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => <Object?>[
    loading,
    saving,
    recipe,
    materials,
    product,
    draft,
    error,
  ];
}

class VariantRecipeCubit extends Cubit<VariantRecipeState> {
  VariantRecipeCubit(this._repository) : super(const VariantRecipeState());
  final MenuCatalogRepository _repository;
  int _request = 0;
  Future<void> load(int variantId, {int? productId}) async {
    final int request = ++_request;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getVariantRecipe(variantId),
        _repository.listRecipeMaterials(),
        if (productId != null)
          _repository.getProduct(productId, includeArchived: true),
      ]);
      if (request != _request) return;
      final recipe = result[0] as VariantRecipe;
      emit(
        state.copyWith(
          loading: false,
          recipe: recipe,
          materials: result[1] as List<RecipeMaterial>,
          product: productId == null ? null : result[2] as ProductDetail,
          draft: List<RecipeComponent>.from(recipe.components),
          clearError: true,
        ),
      );
    } catch (_) {
      if (request == _request)
        emit(
          state.copyWith(
            loading: false,
            error: 'Unable to load recipe configuration. Please retry.',
          ),
        );
    }
  }

  void updateDraft(List<RecipeComponent> components) => emit(
    state.copyWith(draft: List<RecipeComponent>.unmodifiable(components)),
  );
  Future<bool> save(int variantId) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final recipe = await _repository.saveVariantRecipe(
        variantId,
        state.draft,
      );
      emit(
        state.copyWith(
          saving: false,
          recipe: recipe,
          draft: List<RecipeComponent>.from(recipe.components),
          clearError: true,
        ),
      );
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          saving: false,
          error: 'Recipe was not saved. Your draft is still available.',
        ),
      );
      return false;
    }
  }
}

class ModifierAdjustmentState extends Equatable {
  const ModifierAdjustmentState({
    this.loading = false,
    this.saving = false,
    this.deleting = false,
    this.profile,
    this.materials = const <RecipeMaterial>[],
    this.draft = const <RecipeComponent>[],
    this.error,
  });
  final bool loading;
  final bool saving;
  final bool deleting;
  final ModifierRecipeProfile? profile;
  final List<RecipeMaterial> materials;
  final List<RecipeComponent> draft;
  final String? error;
  ModifierAdjustmentState copyWith({
    bool? loading,
    bool? saving,
    bool? deleting,
    ModifierRecipeProfile? profile,
    List<RecipeMaterial>? materials,
    List<RecipeComponent>? draft,
    String? error,
    bool clearError = false,
  }) => ModifierAdjustmentState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    deleting: deleting ?? this.deleting,
    profile: profile ?? this.profile,
    materials: materials ?? this.materials,
    draft: draft ?? this.draft,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => <Object?>[
    loading,
    saving,
    deleting,
    profile,
    materials,
    draft,
    error,
  ];
}

class ModifierAdjustmentCubit extends Cubit<ModifierAdjustmentState> {
  ModifierAdjustmentCubit(this._repository)
    : super(const ModifierAdjustmentState());
  final MenuCatalogRepository _repository;
  int _request = 0;
  Future<void> load(int optionId, {int? productId, int? variantId}) async {
    final int request = ++_request;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final values = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getModifierRecipeProfile(
          optionId,
          productId: productId,
          variantId: variantId,
        ),
        _repository.listRecipeMaterials(),
      ]);
      final profile = values[0] as ModifierRecipeProfile;
      if (request == _request)
        emit(
          state.copyWith(
            loading: false,
            profile: profile,
            materials: values[1] as List<RecipeMaterial>,
            draft: List<RecipeComponent>.from(profile.components),
            clearError: true,
          ),
        );
    } catch (_) {
      if (request == _request)
        emit(
          state.copyWith(
            loading: false,
            error: 'Unable to load material adjustments. Please retry.',
          ),
        );
    }
  }

  void updateDraft(List<RecipeComponent> components) => emit(
    state.copyWith(draft: List<RecipeComponent>.unmodifiable(components)),
  );
  Future<bool> save(int optionId, {int? productId, int? variantId}) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final profile = await _repository.saveModifierRecipeProfile(
        optionId,
        state.draft,
        productId: productId,
        variantId: variantId,
      );
      emit(
        state.copyWith(
          saving: false,
          profile: profile,
          draft: List<RecipeComponent>.from(profile.components),
          clearError: true,
        ),
      );
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          saving: false,
          error: 'Adjustments were not saved. Your draft is still available.',
        ),
      );
      return false;
    }
  }

  Future<bool> suppressInherited(
    int optionId, {
    int? productId,
    int? variantId,
  }) {
    updateDraft(const <RecipeComponent>[]);
    return save(optionId, productId: productId, variantId: variantId);
  }

  Future<bool> deleteOverride(
    int optionId, {
    required int productId,
    int? variantId,
  }) async {
    if (state.deleting) return false;
    emit(state.copyWith(deleting: true, clearError: true));
    try {
      await _repository.deleteModifierRecipeProfile(
        optionId,
        productId: productId,
        variantId: variantId,
      );
      await load(optionId, productId: productId, variantId: variantId);
      emit(state.copyWith(deleting: false));
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          deleting: false,
          error: 'Override could not be removed.',
        ),
      );
      return false;
    }
  }
}

class RecipeSimulationState extends Equatable {
  const RecipeSimulationState({
    this.loading = false,
    this.resolving = false,
    this.product,
    this.result,
    this.error,
  });
  final bool loading;
  final bool resolving;
  final ProductDetail? product;
  final ResolvedRecipe? result;
  final String? error;
  RecipeSimulationState copyWith({
    bool? loading,
    bool? resolving,
    ProductDetail? product,
    ResolvedRecipe? result,
    String? error,
    bool clearError = false,
  }) => RecipeSimulationState(
    loading: loading ?? this.loading,
    resolving: resolving ?? this.resolving,
    product: product ?? this.product,
    result: result ?? this.result,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => <Object?>[
    loading,
    resolving,
    product,
    result,
    error,
  ];
}

class RecipeSimulationCubit extends Cubit<RecipeSimulationState> {
  RecipeSimulationCubit(this._repository)
    : super(const RecipeSimulationState());
  final MenuCatalogRepository _repository;
  int _request = 0;
  Future<void> loadContext(int productId) async {
    final int request = ++_request;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final product = await _repository.getProduct(
        productId,
        includeArchived: true,
      );
      if (request == _request) {
        emit(
          state.copyWith(loading: false, product: product, clearError: true),
        );
      }
    } catch (_) {
      if (request == _request) {
        emit(
          state.copyWith(
            loading: false,
            error: 'Unable to load assigned modifiers. Please retry.',
          ),
        );
      }
    }
  }

  Future<void> resolve(
    int variantId,
    List<Map<String, dynamic>> selections,
  ) async {
    if (state.resolving) return;
    final int request = ++_request;
    emit(state.copyWith(resolving: true, clearError: true));
    try {
      final result = await _repository.resolveVariantRecipe(
        variantId,
        selections,
      );
      if (request == _request)
        emit(
          state.copyWith(resolving: false, result: result, clearError: true),
        );
    } catch (_) {
      if (request == _request)
        emit(
          state.copyWith(
            resolving: false,
            error:
                'Recipe could not be resolved. Review the selections and retry.',
          ),
        );
    }
  }
}
