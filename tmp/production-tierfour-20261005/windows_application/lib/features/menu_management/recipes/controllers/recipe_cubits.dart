// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../modifiers/models/modifier_models.dart';
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
    this.productId,
    this.draft = const <RecipeComponent>[],
    this.profiles = const <int, ModifierRecipeProfile>{},
    this.error,
  });
  final bool loading;
  final bool saving;
  final VariantRecipe? recipe;
  final List<RecipeMaterial> materials;
  final ProductDetail? product;
  final int? productId;
  final List<RecipeComponent> draft;
  final Map<int, ModifierRecipeProfile> profiles;
  final String? error;
  VariantRecipeState copyWith({
    bool? loading,
    bool? saving,
    VariantRecipe? recipe,
    List<RecipeMaterial>? materials,
    ProductDetail? product,
    int? productId,
    List<RecipeComponent>? draft,
    Map<int, ModifierRecipeProfile>? profiles,
    String? error,
    bool clearError = false,
    bool clearProductContext = false,
  }) => VariantRecipeState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    recipe: recipe ?? this.recipe,
    materials: materials ?? this.materials,
    product: clearProductContext ? null : product ?? this.product,
    productId: clearProductContext ? null : productId ?? this.productId,
    draft: draft ?? this.draft,
    profiles: profiles ?? this.profiles,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => <Object?>[
    loading,
    saving,
    recipe,
    materials,
    product,
    productId,
    draft,
    profiles,
    error,
  ];
}

class VariantRecipeCubit extends Cubit<VariantRecipeState> {
  VariantRecipeCubit(this._repository) : super(const VariantRecipeState());
  final MenuCatalogRepository _repository;
  int _request = 0;
  Future<bool> load(int variantId, {int? productId}) async {
    final int request = ++_request;
    if (isClosed) return false;
    emit(
      state.copyWith(
        loading: true,
        profiles: const <int, ModifierRecipeProfile>{},
        clearProductContext: productId == null,
        clearError: true,
      ),
    );
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getVariantRecipe(variantId),
        _repository.listRecipeMaterials(includeUnavailable: true),
        if (productId != null)
          _repository.getProduct(productId, includeArchived: true),
        if (productId != null)
          _repository.getVariantRecipeMaterialEffects(variantId),
      ]);
      final recipe = result[0] as VariantRecipe;
      final ProductDetail? product = productId == null
          ? null
          : result[2] as ProductDetail;
      final Map<int, ModifierRecipeProfile> profiles = product == null
          ? <int, ModifierRecipeProfile>{}
          : <int, ModifierRecipeProfile>{
              for (final profile in result[3] as List<ModifierRecipeProfile>)
                profile.optionId: profile,
            };
      if (request != _request || isClosed) return false;
      emit(
        state.copyWith(
          loading: false,
          recipe: recipe,
          materials: result[1] as List<RecipeMaterial>,
          product: product,
          productId: productId,
          profiles: profiles,
          // The server's legacy `components` alias is explicitly override-only.
          // Effective inherited rows are display data and must never become a save draft.
          draft: List<RecipeComponent>.from(_editableComponents(recipe)),
          clearError: true,
        ),
      );
      return true;
    } catch (_) {
      if (request == _request && !isClosed)
        emit(
          state.copyWith(
            loading: false,
            saving: false,
            error: 'Unable to load recipe configuration. Please retry.',
          ),
        );
      return false;
    }
  }

  void updateDraft(List<RecipeComponent> components) => emit(
    state.copyWith(draft: List<RecipeComponent>.unmodifiable(components)),
  );
  Future<List<RecipeMaterial>> searchMaterials(String query) =>
      _repository.listRecipeMaterials(search: query);
  Future<bool> save(int variantId) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final recipe = await _repository.saveVariantRecipe(
        variantId,
        state.draft,
      );
      if (isClosed) return false;
      emit(
        state.copyWith(
          saving: false,
          recipe: recipe,
          draft: List<RecipeComponent>.from(_editableComponents(recipe)),
          clearError: true,
        ),
      );
      return true;
    } catch (_) {
      if (!isClosed)
        emit(
          state.copyWith(
            saving: false,
            error: 'Recipe was not saved. Your draft is still available.',
          ),
        );
      return false;
    }
  }

  Future<bool> removeOverride(int variantId) async {
    if (state.saving) return false;
    final int? activeProductId = state.productId ?? state.product?.id;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.deleteVariantRecipe(variantId);
      if (isClosed) return false;
      final loaded = await load(variantId, productId: activeProductId);
      if (!loaded || isClosed) return false;
      emit(state.copyWith(saving: false, clearError: true));
      return true;
    } catch (_) {
      if (!isClosed)
        emit(
          state.copyWith(
            saving: false,
            error: 'Recipe override was not removed. Please retry.',
          ),
        );
      return false;
    }
  }
}

class ProductRecipeState extends Equatable {
  const ProductRecipeState({
    this.loading = false,
    this.saving = false,
    this.recipe,
    this.materials = const <RecipeMaterial>[],
    this.draft = const <RecipeComponent>[],
    this.error,
  });
  final bool loading;
  final bool saving;
  final ProductRecipe? recipe;
  final List<RecipeMaterial> materials;
  final List<RecipeComponent> draft;
  final String? error;
  ProductRecipeState copyWith({
    bool? loading,
    bool? saving,
    ProductRecipe? recipe,
    List<RecipeMaterial>? materials,
    List<RecipeComponent>? draft,
    String? error,
    bool clearError = false,
  }) => ProductRecipeState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    recipe: recipe ?? this.recipe,
    materials: materials ?? this.materials,
    draft: draft ?? this.draft,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => <Object?>[
    loading,
    saving,
    recipe,
    materials,
    draft,
    error,
  ];
}

class ProductRecipeCubit extends Cubit<ProductRecipeState> {
  ProductRecipeCubit(this._repository) : super(const ProductRecipeState());
  final MenuCatalogRepository _repository;
  int _request = 0;
  Future<void> load(int productId) async {
    final request = ++_request;
    if (isClosed) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final values = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getProductRecipe(productId),
        _repository.listRecipeMaterials(includeUnavailable: true),
      ]);
      if (request != _request || isClosed) return;
      final recipe = values[0] as ProductRecipe;
      emit(
        state.copyWith(
          loading: false,
          recipe: recipe,
          materials: values[1] as List<RecipeMaterial>,
          draft: List<RecipeComponent>.from(recipe.components),
          clearError: true,
        ),
      );
    } catch (_) {
      if (request == _request && !isClosed)
        emit(
          state.copyWith(
            loading: false,
            error: 'Unable to load recipe configuration. Please retry.',
          ),
        );
    }
  }

  void updateDraft(List<RecipeComponent> value) =>
      emit(state.copyWith(draft: List<RecipeComponent>.unmodifiable(value)));
  Future<List<RecipeMaterial>> searchMaterials(String query) =>
      _repository.listRecipeMaterials(search: query);
  Future<bool> save(int productId) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final recipe = await _repository.saveProductRecipe(
        productId,
        state.draft,
      );
      if (isClosed) return false;
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
      if (!isClosed)
        emit(
          state.copyWith(
            saving: false,
            error: 'Recipe was not saved. Your draft is still available.',
          ),
        );
      return false;
    }
  }

  Future<bool> clear(int productId) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.deleteProductRecipe(productId);
      if (isClosed) return false;
      if (!isClosed)
        emit(
          state.copyWith(
            saving: false,
            draft: const <RecipeComponent>[],
            clearError: true,
          ),
        );
      return true;
    } catch (_) {
      if (!isClosed)
        emit(
          state.copyWith(
            saving: false,
            error: 'Recipe was not cleared. Please retry.',
          ),
        );
      return false;
    }
  }
}

List<RecipeComponent> _editableComponents(VariantRecipe recipe) =>
    recipe.hasOverride || recipe.overrideComponents.isNotEmpty
    ? recipe.overrideComponents
    // Existing repository fakes and old application objects carry only the
    // legacy editable alias. Explicit inherited responses always have an empty
    // alias, so this does not copy effective components into a draft.
    : recipe.components;

class ModifierAdjustmentState extends Equatable {
  const ModifierAdjustmentState({
    this.loading = false,
    this.saving = false,
    this.deleting = false,
    this.profile,
    this.materials = const <RecipeMaterial>[],
    this.draft = const <RecipeComponent>[],
    this.product,
    this.variant,
    this.productGroup,
    this.productOption,
    this.globalGroup,
    this.globalOption,
    this.contextUnavailable = false,
    this.error,
  });
  final bool loading;
  final bool saving;
  final bool deleting;
  final ModifierRecipeProfile? profile;
  final List<RecipeMaterial> materials;
  final List<RecipeComponent> draft;
  final ProductDetail? product;
  final ProductVariant? variant;
  final ModifierGroup? productGroup;
  final ModifierOption? productOption;
  final ModifierGroupRecord? globalGroup;
  final ModifierOptionRecord? globalOption;
  final bool contextUnavailable;
  final String? error;
  ModifierAdjustmentState copyWith({
    bool? loading,
    bool? saving,
    bool? deleting,
    ModifierRecipeProfile? profile,
    List<RecipeMaterial>? materials,
    List<RecipeComponent>? draft,
    ProductDetail? product,
    ProductVariant? variant,
    ModifierGroup? productGroup,
    ModifierOption? productOption,
    ModifierGroupRecord? globalGroup,
    ModifierOptionRecord? globalOption,
    bool? contextUnavailable,
    String? error,
    bool clearError = false,
  }) => ModifierAdjustmentState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    deleting: deleting ?? this.deleting,
    profile: profile ?? this.profile,
    materials: materials ?? this.materials,
    draft: draft ?? this.draft,
    product: product ?? this.product,
    variant: variant ?? this.variant,
    productGroup: productGroup ?? this.productGroup,
    productOption: productOption ?? this.productOption,
    globalGroup: globalGroup ?? this.globalGroup,
    globalOption: globalOption ?? this.globalOption,
    contextUnavailable: contextUnavailable ?? this.contextUnavailable,
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
    product,
    variant,
    productGroup,
    productOption,
    globalGroup,
    globalOption,
    contextUnavailable,
    error,
  ];
}

class ModifierAdjustmentCubit extends Cubit<ModifierAdjustmentState> {
  ModifierAdjustmentCubit(this._repository)
    : super(const ModifierAdjustmentState());
  final MenuCatalogRepository _repository;
  int _request = 0;
  Future<void> load(
    int optionId, {
    int? productId,
    int? variantId,
    int? groupId,
  }) async {
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
        _loadModifierAdjustmentContext(
          _repository,
          optionId,
          productId: productId,
          variantId: variantId,
          groupId: groupId,
        ),
      ]);
      final profile = values[0] as ModifierRecipeProfile;
      final context = values[2] as _ModifierAdjustmentContextResult;
      if (request == _request)
        emit(
          state.copyWith(
            loading: false,
            profile: profile,
            materials: values[1] as List<RecipeMaterial>,
            draft: List<RecipeComponent>.from(profile.components),
            product: context.product,
            variant: context.variant,
            productGroup: context.productGroup,
            productOption: context.productOption,
            globalGroup: context.globalGroup,
            globalOption: context.globalOption,
            contextUnavailable: context.error,
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
  Future<List<RecipeMaterial>> searchMaterials(String query) =>
      _repository.listRecipeMaterials(search: query);
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

Future<_ModifierAdjustmentContextResult> _loadModifierAdjustmentContext(
  MenuCatalogRepository repository,
  int optionId, {
  int? productId,
  int? variantId,
  int? groupId,
}) async {
  try {
    if (productId != null) {
      final product = await repository.getProduct(
        productId,
        includeArchived: true,
      );
      final group = product.modifierGroups
          .where((item) => item.options.any((option) => option.id == optionId))
          .firstOrNull;
      final option = group?.options
          .where((item) => item.id == optionId)
          .firstOrNull;
      final variant = variantId == null
          ? null
          : product.variants.where((item) => item.id == variantId).firstOrNull;
      if (group == null ||
          option == null ||
          (variantId != null && variant == null)) {
        return const _ModifierAdjustmentContextResult.error();
      }
      return _ModifierAdjustmentContextResult.product(
        product: product,
        variant: variant,
        group: group,
        option: option,
      );
    }

    if (groupId != null) {
      final group = await repository.getModifierGroup(
        groupId,
        includeArchived: true,
      );
      final option = <ModifierOptionRecord>[
        ...group.options,
        ...group.optionPreview,
      ].where((item) => item.id == optionId).firstOrNull;
      if (option == null) {
        return const _ModifierAdjustmentContextResult.error();
      }
      return _ModifierAdjustmentContextResult.global(
        group: group,
        option: option,
      );
    }
  } catch (_) {
    return const _ModifierAdjustmentContextResult.error();
  }
  return const _ModifierAdjustmentContextResult.error();
}

class _ModifierAdjustmentContextResult {
  const _ModifierAdjustmentContextResult({
    this.product,
    this.variant,
    this.productGroup,
    this.productOption,
    this.globalGroup,
    this.globalOption,
  }) : error = false;

  const _ModifierAdjustmentContextResult.error()
    : product = null,
      variant = null,
      productGroup = null,
      productOption = null,
      globalGroup = null,
      globalOption = null,
      error = true;

  _ModifierAdjustmentContextResult.product({
    required ProductDetail product,
    required ProductVariant? variant,
    required ModifierGroup group,
    required ModifierOption option,
  }) : this(
         product: product,
         variant: variant,
         productGroup: group,
         productOption: option,
       );

  _ModifierAdjustmentContextResult.global({
    required ModifierGroupRecord group,
    required ModifierOptionRecord option,
  }) : this(globalGroup: group, globalOption: option);

  final ProductDetail? product;
  final ProductVariant? variant;
  final ModifierGroup? productGroup;
  final ModifierOption? productOption;
  final ModifierGroupRecord? globalGroup;
  final ModifierOptionRecord? globalOption;
  final bool error;
}

class RecipeSimulationState extends Equatable {
  const RecipeSimulationState({
    this.loading = false,
    this.resolving = false,
    this.product,
    this.result,
    this.resultStale = false,
    this.error,
  });
  final bool loading;
  final bool resolving;
  final ProductDetail? product;
  final ResolvedRecipe? result;
  final bool resultStale;
  final String? error;
  RecipeSimulationState copyWith({
    bool? loading,
    bool? resolving,
    ProductDetail? product,
    ResolvedRecipe? result,
    String? error,
    bool clearError = false,
    bool clearResult = false,
    bool? resultStale,
  }) => RecipeSimulationState(
    loading: loading ?? this.loading,
    resolving: resolving ?? this.resolving,
    product: product ?? this.product,
    result: clearResult ? null : result ?? this.result,
    resultStale: resultStale ?? this.resultStale,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => <Object?>[
    loading,
    resolving,
    product,
    result,
    resultStale,
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
          state.copyWith(
            loading: false,
            product: product,
            clearError: true,
            clearResult: true,
            resultStale: false,
          ),
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
    if (!_validSelections(selections)) {
      invalidateResult();
      emit(
        state.copyWith(
          error: 'Modifier quantities must be positive whole numbers.',
        ),
      );
      return;
    }
    final int request = ++_request;
    emit(
      state.copyWith(
        resolving: true,
        clearError: true,
        clearResult: true,
        resultStale: false,
      ),
    );
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

  void invalidateResult() {
    _request++;
    emit(
      state.copyWith(
        clearResult: true,
        clearError: true,
        resultStale: state.result != null || state.resultStale,
      ),
    );
  }

  bool _validSelections(List<Map<String, dynamic>> selections) =>
      selections.every((selection) {
        final quantity = selection['quantity'];
        return quantity == null || (quantity is int && quantity > 0);
      });
}
