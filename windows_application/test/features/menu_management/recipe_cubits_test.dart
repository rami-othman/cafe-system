import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
      await cubit.load(7);
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
  int resolveCalls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<RecipeMaterial>> listRecipeMaterials({
    String search = '',
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
  Future<VariantRecipe> getVariantRecipe(int variantId) async => recipe;
  @override
  Future<VariantRecipe> saveVariantRecipe(
    int variantId,
    List<RecipeComponent> components,
  ) async {
    if (saveError) throw StateError('no');
    return VariantRecipe(variantId: variantId, components: components);
  }

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
