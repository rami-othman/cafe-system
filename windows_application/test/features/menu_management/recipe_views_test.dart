import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/recipes/controllers/recipe_cubits.dart';
import 'package:windows_application/features/menu_management/recipes/models/recipe_models.dart';
import 'package:windows_application/features/menu_management/recipes/views/modifier_adjustment_screen.dart';
import 'package:windows_application/features/menu_management/recipes/views/recipe_simulation_screen.dart';
import 'package:windows_application/features/menu_management/recipes/views/variant_recipe_screen.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('base recipe renders material names and keeps exact draft text', (
    tester,
  ) async {
    final repository = _RecipeViewRepository();
    await tester.pumpWidget(
      _app(
        BlocProvider<VariantRecipeCubit>(
          create: (_) => VariantRecipeCubit(repository),
          child: const VariantRecipeScreen(variantId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beans'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('recipe-quantity-0')),
      '18.125',
    );
    expect(
      find.text(
        'Use a unique material and a positive decimal quantity (up to 6 places).',
      ),
      findsNothing,
    );
    expect(find.text('Add Material'), findsOneWidget);
  });

  testWidgets(
    'base recipe can remove every component and save an empty recipe',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _RecipeViewRepository();
      await tester.pumpWidget(
        _app(
          BlocProvider<VariantRecipeCubit>(
            create: (_) => VariantRecipeCubit(repository),
            child: const VariantRecipeScreen(variantId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove material'));
      await tester.pump();
      expect(find.text('Beans'), findsNothing);
      await tester.tap(find.text('Save recipe'));
      await tester.pumpAndSettle();
      expect(repository.lastSavedComponents, isEmpty);
    },
  );

  testWidgets(
    'modifier editor exposes editable component controls and inheritance',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _RecipeViewRepository();
      final probe = RecipeSimulationCubit(repository);
      await probe.loadContext(1);
      expect(probe.state.product?.modifierGroups.single.name, 'Extras');
      await probe.close();
      await tester.pumpWidget(
        _app(
          BlocProvider<ModifierAdjustmentCubit>(
            create: (_) => ModifierAdjustmentCubit(repository),
            child: const ModifierAdjustmentScreen(optionId: 3, productId: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Use inherited settings'), findsOneWidget);
      expect(find.text('From Global settings'), findsOneWidget);
      expect(
        find.byKey(const Key('adjustment-quantity-add-0')),
        findsOneWidget,
      );
      expect(find.text('Add Material to Add'), findsOneWidget);
      await tester.ensureVisible(find.text('Add Material to Add'));
      await tester.tap(find.text('Add Material to Add'));
      await tester.pump();
      expect(
        find.byKey(const Key('adjustment-quantity-add-1')),
        findsOneWidget,
      );
    },
  );

  test(
    'resolved recipe retains the backend material display name and decimal',
    () {
      final recipe = ResolvedRecipe.fromJson(<String, dynamic>{
        'variantId': 7,
        'components': <Object>[
          <String, dynamic>{
            'materialId': 1,
            'name': 'Resolved beans',
            'quantity': '18.125',
            'unitCode': 'g',
          },
        ],
      });
      expect(recipe.components.single.materialName, 'Resolved beans');
      expect(recipe.components.single.quantity, '18.125');
    },
  );

  testWidgets(
    'simulation submits selections and presents backend material names',
    (tester) async {
      final repository = _RecipeViewRepository();
      final cubit = RecipeSimulationCubit(repository);
      await cubit.loadContext(1);
      await tester.pumpWidget(
        _app(
          BlocProvider<RecipeSimulationCubit>.value(
            value: cubit,
            child: const RecipeSimulationScreen(productId: 1, variantId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Extras'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Preview Materials'));
      await tester.tap(find.text('Preview Materials'));
      await tester.pumpAndSettle();
      expect(find.text('Resolved beans'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(find.text('Resolved beans'), findsNothing);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Preview Materials'));
      await tester.tap(find.text('Preview Materials'));
      await tester.pumpAndSettle();
      expect(find.text('Resolved beans'), findsOneWidget);
      final dropdown = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(dropdown.items, hasLength(1));
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pump();
      expect(find.text('Resolved beans'), findsNothing);
      await cubit.close();
    },
  );

  testWidgets(
    'recipe workspace renders configured materials and grouped effects',
    (tester) async {
      final repository = _RecipeViewRepository();
      final product = await repository.getProduct(1);
      await tester.pumpWidget(
        _app(
          BlocProvider<VariantRecipeCubit>(
            create: (_) => VariantRecipeCubit(repository),
            child: RecipeMaterialsWorkspace(product: product),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Recipe configured'), findsOneWidget);
      expect(find.text('Beans'), findsOneWidget);
      expect(find.text('Modifier Material Effects'), findsOneWidget);
      expect(find.text('Using Global settings'), findsOneWidget);
      expect(find.text('Test Recipe'), findsNWidgets(2));
    },
  );

  testWidgets(
    'simulation marks a resolved result stale after a choice changes',
    (tester) async {
      final repository = _RecipeViewRepository();
      final cubit = RecipeSimulationCubit(repository);
      await cubit.loadContext(1);
      await tester.pumpWidget(
        _app(
          BlocProvider<RecipeSimulationCubit>.value(
            value: cubit,
            child: const RecipeSimulationScreen(productId: 1, variantId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(find.text('Preview Materials'));
      await tester.tap(find.text('Preview Materials'));
      await tester.pumpAndSettle();
      expect(find.text('Resolved beans'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(find.text('Choices changed'), findsOneWidget);
      expect(
        find.text('Preview the materials again to update this result.'),
        findsOneWidget,
      );
      expect(find.text('Resolved beans'), findsNothing);
      await cubit.close();
    },
  );

  testWidgets('simulation stays overflow-free at desktop widths', (
    tester,
  ) async {
    for (final size in <Size>[
      const Size(1280, 900),
      const Size(1440, 900),
      const Size(1920, 1080),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final repository = _RecipeViewRepository();
      await tester.pumpWidget(
        _app(
          BlocProvider<RecipeSimulationCubit>(
            create: (_) => RecipeSimulationCubit(repository),
            child: const RecipeSimulationScreen(productId: 1, variantId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('Arabic recipe screens remain RTL and keep technical values LTR', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _RecipeViewRepository(
      materialName:
          'Ã˜Â­Ã˜Â¨Ã™Ë†Ã˜Â¨ Ã™â€šÃ™â€¡Ã™Ë†Ã˜Â© Ã˜Â¹Ã˜Â±Ã˜Â¨Ã™Å Ã˜Â© Ã˜Â·Ã™Ë†Ã™Å Ã™â€žÃ˜Â© Ã˜Â¬Ã˜Â¯Ã˜Â§Ã™â€¹ Ã™â€žÃ˜Â§ Ã™Å Ã™â€ Ã˜Â¨Ã˜ÂºÃ™Å  Ã˜Â£Ã™â€  Ã˜ÂªÃ˜Â³Ã˜Â¨Ã˜Â¨ Ã˜ÂªÃ˜Â¬Ã˜Â§Ã™Ë†Ã˜Â²Ã˜Â§Ã™â€¹ Ã™ÂÃ™Å  Ã˜ÂªÃ˜Â®Ã˜Â·Ã™Å Ã˜Â· Ã˜Â¬Ã˜Â¯Ã™Ë†Ã™â€ž Ã˜Â§Ã™â€žÃ™Ë†Ã˜ÂµÃ™ÂÃ˜Â©',
    );
    final cubit = RecipeSimulationCubit(repository);
    await cubit.loadContext(1);
    await tester.pumpWidget(
      _app(
        BlocProvider<RecipeSimulationCubit>.value(
          value: cubit,
          child: const RecipeSimulationScreen(productId: 1, variantId: 7),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Preview Materials'));
    await tester.tap(find.text('Preview Materials'));
    await tester.pumpAndSettle();

    expect(find.text('Test Recipe'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Test Recipe'))),
      TextDirection.rtl,
    );
    expect(find.text(repository.materialName), findsOneWidget);
    final quantityDirection = tester.widget<Directionality>(
      find
          .ancestor(
            of: find.text('18.125 g'),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(quantityDirection.textDirection, TextDirection.ltr);
    await cubit.close();
  });

  testWidgets(
    'Arabic adjustment editor keeps RTL layout and manager-facing behavior',
    (tester) async {
      final repository = _RecipeViewRepository();
      await tester.pumpWidget(
        _app(
          BlocProvider<ModifierAdjustmentCubit>(
            create: (_) => ModifierAdjustmentCubit(repository),
            child: const ModifierAdjustmentScreen(optionId: 3, productId: 1),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Use inherited settings'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Current Behavior'))),
        TextDirection.rtl,
      );
    },
  );
}

Widget _app(Widget child, {Locale? locale}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

class _RecipeViewRepository extends MenuCatalogRepository {
  _RecipeViewRepository({this.materialName = 'Beans'});
  final String materialName;
  List<RecipeComponent>? lastSavedComponents;
  final VariantRecipe _recipe = const VariantRecipe(
    variantId: 7,
    components: <RecipeComponent>[
      RecipeComponent(materialId: 1, quantity: '18', unitCode: 'g'),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<RecipeMaterial>> listRecipeMaterials({
    String search = '',
  }) async => <RecipeMaterial>[
    RecipeMaterial(
      id: 1,
      name: materialName,
      unitCode: 'g',
      configurationAvailable: true,
    ),
    RecipeMaterial(
      id: 2,
      name: 'Milk',
      unitCode: 'ml',
      configurationAvailable: true,
    ),
    RecipeMaterial(
      id: 3,
      name: 'Unknown',
      configurationAvailable: false,
      unavailabilityReason: 'unit_unmapped',
    ),
  ];

  @override
  Future<VariantRecipe> getVariantRecipe(int variantId) async => _recipe;

  @override
  Future<VariantRecipe> saveVariantRecipe(
    int variantId,
    List<RecipeComponent> components,
  ) async {
    lastSavedComponents = components;
    return VariantRecipe(variantId: variantId, components: components);
  }

  @override
  Future<ModifierRecipeProfile> getModifierRecipeProfile(
    int optionId, {
    int? productId,
    int? variantId,
  }) async => const ModifierRecipeProfile(
    optionId: 3,
    scope: 'product',
    hasOverride: false,
    inheritedFrom: 'global',
    components: <RecipeComponent>[
      RecipeComponent(
        materialId: 1,
        operation: 'add',
        quantity: '18',
        unitCode: 'g',
      ),
    ],
  );

  @override
  Future<ModifierRecipeProfile> saveModifierRecipeProfile(
    int optionId,
    List<RecipeComponent> components, {
    int? productId,
    int? variantId,
  }) async => ModifierRecipeProfile(
    optionId: optionId,
    scope: variantId == null ? 'product' : 'variant',
    hasOverride: true,
    components: components,
  );

  @override
  Future<void> deleteModifierRecipeProfile(
    int optionId, {
    required int productId,
    int? variantId,
  }) async {}

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => ProductDetail.fromJson(<String, dynamic>{
    'id': 1,
    'name': 'Latte',
    'nameAr': null,
    'nameEn': 'Latte',
    'description': null,
    'imageUrl': null,
    'productType': 'standard',
    'isActive': true,
    'category': null,
    'reportingCategory': null,
    'kitchenStation': null,
    'defaultVariant': <String, dynamic>{
      'id': 7,
      'name': 'Regular',
      'nameAr': null,
      'nameEn': 'Regular',
      'sku': null,
      'barcode': null,
      'basePrice': 5,
      'costPrice': null,
      'isDefault': true,
      'isActive': true,
      'sortOrder': 0,
    },
    'variantCount': 1,
    'modifierGroupCount': 1,
    'createdAt': null,
    'updatedAt': null,
    'descriptionAr': null,
    'descriptionEn': null,
    'preparationTimeMinutes': null,
    'sortOrder': 0,
    'isStockTracked': true,
    'variants': <Object>[
      <String, dynamic>{
        'id': 7,
        'name': 'Regular',
        'nameAr': null,
        'nameEn': 'Regular',
        'sku': null,
        'barcode': null,
        'basePrice': 5,
        'costPrice': null,
        'isDefault': true,
        'isActive': true,
        'sortOrder': 0,
      },
    ],
    'modifierGroups': <Object>[
      <String, dynamic>{
        'id': 11,
        'name': 'Extras',
        'groupType': 'choice',
        'selectionType': 'multiple',
        'isRequired': false,
        'minSelections': 0,
        'maxSelections': 2,
        'allowQuantity': true,
        'options': <Object>[
          <String, dynamic>{
            'id': 3,
            'name': 'Shot',
            'priceDelta': 0,
            'isActive': true,
            'isAvailable': true,
          },
        ],
      },
    ],
  });

  @override
  Future<ResolvedRecipe> resolveVariantRecipe(
    int variantId,
    List<Map<String, dynamic>> selectedOptions,
  ) async => ResolvedRecipe(
    variantId: 7,
    components: <RecipeComponent>[
      RecipeComponent(
        materialId: 1,
        materialName: materialName == 'Beans' ? 'Resolved beans' : materialName,
        quantity: '18.125',
        unitCode: 'g',
      ),
    ],
  );
}
