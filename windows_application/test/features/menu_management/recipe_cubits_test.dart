import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/recipes/controllers/recipe_cubits.dart';
import 'package:windows_application/features/menu_management/recipes/models/recipe_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  const component = RecipeComponent(
    materialId: 1,
    quantity: '18',
    unitCode: 'g',
  );
  const recipe = VariantRecipe(
    variantId: 7,
    components: <RecipeComponent>[component],
  );

  test(
    'base recipe cubit loads exact decimal draft and preserves it on failure',
    () async {
      final repository = _RecipeRepository(recipe: recipe);
      final cubit = VariantRecipeCubit(repository);
      await cubit.load(7, productId: 3);
      expect(cubit.state.draft.single.quantity, '18');
      cubit.updateDraft(const <RecipeComponent>[
        RecipeComponent(materialId: 1, quantity: '18.125', unitCode: 'g'),
      ]);
      repository.saveError = true;
      expect(await cubit.save(7), isFalse);
      expect(cubit.state.draft.single.quantity, '18.125');
      expect(cubit.state.error, contains('draft'));
    },
  );

  test(
    'inherited effective rows are display-only and override removal reloads',
    () async {
      final repository = _RecipeRepository(
        recipe: const VariantRecipe(
          variantId: 7,
          components: <RecipeComponent>[],
          hasOverride: false,
          source: RecipeSource.product,
          effectiveComponents: <RecipeComponent>[component],
        ),
        profile: const ModifierRecipeProfile(
          optionId: 9,
          scope: 'variant',
          hasOverride: false,
          inheritedFrom: 'product',
          components: <RecipeComponent>[],
        ),
      );
      final cubit = VariantRecipeCubit(repository);
      await cubit.load(7, productId: 3);
      expect(cubit.state.recipe!.effectiveComponents, <RecipeComponent>[
        component,
      ]);
      expect(cubit.state.draft, isEmpty);
      expect(await cubit.removeOverride(7), isTrue);
      expect(repository.deleteCalls, 1);
      expect(repository.lastProductId, 3);
      expect(cubit.state.profiles, contains(9));
    },
  );

  test('recipe presentation aggregation combines identical materials', () {
    final aggregated = aggregateRecipeComponents(const <RecipeComponent>[
      RecipeComponent(materialId: 1, quantity: '18', unitCode: 'g'),
      RecipeComponent(materialId: 1, quantity: '18.125', unitCode: 'g'),
      RecipeComponent(materialId: 2, quantity: '30', unitCode: 'ml'),
    ]);

    expect(aggregated, hasLength(2));
    expect(aggregated.first.quantity, '36.125');
    expect(aggregated.last.quantity, '30');
  });

  test('a stale recipe load cannot overwrite the latest response', () async {
    final repository = _RecipeRepository(recipe: recipe);
    final first = Completer<VariantRecipe>();
    final second = Completer<VariantRecipe>();
    repository.recipeFutures.addAll(<Future<VariantRecipe>>[
      first.future,
      second.future,
    ]);
    final cubit = VariantRecipeCubit(repository);
    final loadingFirst = cubit.load(7);
    final loadingSecond = cubit.load(8);
    second.complete(
      const VariantRecipe(variantId: 8, components: <RecipeComponent>[]),
    );
    await loadingSecond;
    first.complete(recipe);
    await loadingFirst;
    expect(cubit.state.recipe!.variantId, 8);
  });

  test(
    'modifier adjustment cubit clones inherited components and suppresses explicitly',
    () async {
      final repository = _RecipeRepository(
        recipe: recipe,
        profile: const ModifierRecipeProfile(
          optionId: 9,
          scope: 'variant',
          hasOverride: false,
          inheritedFrom: 'product',
          components: <RecipeComponent>[
            RecipeComponent(
              materialId: 2,
              quantity: '250',
              unitCode: 'ml',
              operation: 'add',
            ),
          ],
        ),
      );
      final cubit = ModifierAdjustmentCubit(repository);
      await cubit.load(9, productId: 3, variantId: 7);
      expect(cubit.state.profile!.effectiveSource, 'Product');
      expect(cubit.state.draft.single.materialId, 2);
      expect(
        await cubit.suppressInherited(9, productId: 3, variantId: 7),
        isTrue,
      );
      expect(repository.lastProfileComponents, isEmpty);
    },
  );

  test(
    'simulation cubit prevents duplicate in-flight resolution and retains backend result',
    () async {
      final repository = _RecipeRepository(recipe: recipe);
      final pending = Completer<ResolvedRecipe>();
      repository.resolveFuture = pending.future;
      final cubit = RecipeSimulationCubit(repository);
      unawaited(cubit.resolve(7, const <Map<String, dynamic>>[]));
      unawaited(cubit.resolve(7, const <Map<String, dynamic>>[]));
      expect(repository.resolveCalls, 1);
      pending.complete(
        const ResolvedRecipe(
          variantId: 7,
          components: <RecipeComponent>[component],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.result!.components.single.quantity, '18');
    },
  );

  test(
    'simulation rejects non-positive or malformed quantities locally',
    () async {
      final repository = _RecipeRepository(recipe: recipe);
      final cubit = RecipeSimulationCubit(repository);

      await cubit.resolve(7, const <Map<String, dynamic>>[
        <String, dynamic>{'optionId': 9, 'quantity': 0},
      ]);
      expect(repository.resolveCalls, 0);
      expect(cubit.state.result, isNull);
      expect(cubit.state.error, contains('positive whole numbers'));

      await cubit.resolve(7, const <Map<String, dynamic>>[
        <String, dynamic>{'optionId': 9, 'quantity': '1'},
      ]);
      expect(repository.resolveCalls, 0);
    },
  );

  test(
    'simulation result is invalidated before a different variant resolves',
    () async {
      final repository = _RecipeRepository(recipe: recipe);
      final cubit = RecipeSimulationCubit(repository);
      await cubit.resolve(7, const <Map<String, dynamic>>[]);
      expect(cubit.state.result, isNotNull);

      final pending = Completer<ResolvedRecipe>();
      repository.resolveFuture = pending.future;
      unawaited(cubit.resolve(8, const <Map<String, dynamic>>[]));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.result, isNull);
      pending.complete(
        const ResolvedRecipe(variantId: 8, components: <RecipeComponent>[]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.result!.variantId, 8);
      expect(cubit.state.error, isNull);
    },
  );
}

class _RecipeRepository extends MenuCatalogRepository {
  _RecipeRepository({required this.recipe, this.profile});
  final VariantRecipe recipe;
  ModifierRecipeProfile? profile;
  bool saveError = false;
  List<RecipeComponent>? lastProfileComponents;
  Future<ResolvedRecipe>? resolveFuture;
  final List<Future<VariantRecipe>> recipeFutures = <Future<VariantRecipe>>[];
  int resolveCalls = 0;
  int deleteCalls = 0;
  int? lastProductId;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<RecipeMaterial>> listRecipeMaterials({
    String search = '',
    bool includeUnavailable = false,
  }) async => const <RecipeMaterial>[
    RecipeMaterial(
      id: 1,
      name: 'Beans',
      unitCode: 'g',
      configurationAvailable: true,
    ),
    RecipeMaterial(
      id: 2,
      name: 'Milk',
      unitCode: 'ml',
      configurationAvailable: true,
    ),
  ];
  @override
  Future<VariantRecipe> getVariantRecipe(int variantId) => recipeFutures.isEmpty
      ? Future<VariantRecipe>.value(recipe)
      : recipeFutures.removeAt(0);
  @override
  Future<VariantRecipe> saveVariantRecipe(
    int variantId,
    List<RecipeComponent> components,
  ) async {
    if (saveError) throw StateError('no');
    return VariantRecipe(variantId: variantId, components: components);
  }

  @override
  Future<void> deleteVariantRecipe(int variantId) async => deleteCalls++;

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async {
    lastProductId = productId;
    return ProductDetail.fromJson(<String, dynamic>{
      'id': productId,
      'name': 'Coffee',
      'productType': 'simple',
      'isActive': true,
      'variants': <Map<String, dynamic>>[],
      'modifierGroups': <Map<String, dynamic>>[],
    });
  }

  @override
  Future<List<ModifierRecipeProfile>> getVariantRecipeMaterialEffects(
    int variantId,
  ) async => profile == null
      ? const <ModifierRecipeProfile>[]
      : <ModifierRecipeProfile>[profile!];

  @override
  Future<ModifierRecipeProfile> getModifierRecipeProfile(
    int optionId, {
    int? productId,
    int? variantId,
  }) async => profile!;
  @override
  Future<ModifierRecipeProfile> saveModifierRecipeProfile(
    int optionId,
    List<RecipeComponent> components, {
    int? productId,
    int? variantId,
  }) async {
    lastProfileComponents = components;
    profile = ModifierRecipeProfile(
      optionId: optionId,
      scope: variantId == null ? 'product' : 'variant',
      hasOverride: true,
      components: components,
    );
    return profile!;
  }

  @override
  Future<void> deleteModifierRecipeProfile(
    int optionId, {
    required int productId,
    int? variantId,
  }) async {}
  @override
  Future<ResolvedRecipe> resolveVariantRecipe(
    int variantId,
    List<Map<String, dynamic>> selectedOptions,
  ) {
    resolveCalls++;
    return resolveFuture ??
        Future<ResolvedRecipe>.value(
          ResolvedRecipe(variantId: variantId, components: recipe.components),
        );
  }
}
