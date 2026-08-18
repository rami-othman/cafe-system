import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/recipes/models/recipe_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  late _RecipeNavigationRepository repository;

  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
    await serviceLocator.unregister<MenuCatalogRepository>();
    repository = _RecipeNavigationRepository();
    serviceLocator.registerLazySingleton<MenuCatalogRepository>(
      () => repository,
    );
  });

  tearDown(() => appRouter.go(AppRoutes.pos));

  testWidgets('recipe routes retain their scoped context IDs', (tester) async {
    await _pump(
      tester,
      '/menu-management/modifier-options/3/recipe-adjustments',
    );
    expect(repository.profileCalls.last, const _ProfileCall(3));

    appRouter.go(
      '/menu-management/products/1/modifier-options/3/recipe-adjustments',
    );
    await tester.pumpAndSettle();
    expect(repository.profileCalls.last, const _ProfileCall(3, productId: 1));

    appRouter.go(
      '/menu-management/product-variants/7/modifier-options/3/recipe-adjustments',
    );
    await tester.pumpAndSettle();
    expect(repository.profileCalls.last, const _ProfileCall(3, variantId: 7));

    appRouter.go('/menu-management/product-variants/7/recipe?productId=1');
    await tester.pumpAndSettle();
    expect(repository.recipeCalls.last, 7);
    expect(repository.productCalls.last, 1);
    expect(find.text('Manage Recipe'), findsOneWidget);
    await tester.tap(find.text('Manage Recipe'));
    await tester.pumpAndSettle();
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.queryParameters['edit'],
      '1',
    );
    expect(find.byKey(const Key('standalone-recipe-editor')), findsOneWidget);

    appRouter.go('/menu-management/product-variants/7/recipe?productId=1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Material'));
    await tester.tap(find.text('Add Material'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('standalone-recipe-editor')), findsOneWidget);

    appRouter.go('/menu-management/products/1/variants/7/recipe-simulation');
    await tester.pumpAndSettle();
    expect(repository.productCalls.last, 1);
    expect(find.text('Test Recipe'), findsOneWidget);

    await tester.tap(find.text('Product'));
    await tester.pumpAndSettle();
    expect(find.text('Latte'), findsWidgets);
  });

  testWidgets('malformed recipe route context fails safely', (tester) async {
    await _pump(tester, '/menu-management/product-variants/not-an-id/recipe');
    expect(
      find.text('The requested catalog route is invalid.'),
      findsOneWidget,
    );
    appRouter.go('/menu-management/products/0/variants/7/recipe-simulation');
    await tester.pumpAndSettle();
    expect(
      find.text('The requested catalog route is invalid.'),
      findsOneWidget,
    );
  });
}

Future<void> _pump(WidgetTester tester, String route) async {
  appRouter.go(route);
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

class _ProfileCall {
  const _ProfileCall(this.optionId, {this.productId, this.variantId});
  final int optionId;
  final int? productId;
  final int? variantId;
  @override
  bool operator ==(Object other) =>
      other is _ProfileCall &&
      optionId == other.optionId &&
      productId == other.productId &&
      variantId == other.variantId;
  @override
  int get hashCode => Object.hash(optionId, productId, variantId);
}

class _RecipeNavigationRepository extends MenuCatalogRepository {
  final List<_ProfileCall> profileCalls = <_ProfileCall>[];
  final List<int> recipeCalls = <int>[];
  final List<int> productCalls = <int>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<RecipeMaterial>> listRecipeMaterials({
    String search = '',
  }) async => const <RecipeMaterial>[];

  @override
  Future<ModifierRecipeProfile> getModifierRecipeProfile(
    int optionId, {
    int? productId,
    int? variantId,
  }) async {
    profileCalls.add(
      _ProfileCall(optionId, productId: productId, variantId: variantId),
    );
    return const ModifierRecipeProfile(
      optionId: 3,
      scope: 'global',
      hasOverride: false,
      components: <RecipeComponent>[],
    );
  }

  @override
  Future<VariantRecipe> getVariantRecipe(int variantId) async {
    recipeCalls.add(variantId);
    return VariantRecipe(
      variantId: variantId,
      components: const <RecipeComponent>[],
    );
  }

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async {
    productCalls.add(productId);
    return ProductDetail.fromJson(<String, dynamic>{
      'id': productId,
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
      'defaultVariant': null,
      'variantCount': 1,
      'modifierGroupCount': 0,
      'createdAt': null,
      'updatedAt': null,
      'descriptionAr': null,
      'descriptionEn': null,
      'preparationTimeMinutes': null,
      'sortOrder': 0,
      'isStockTracked': true,
      'variants': <Object>[],
      'modifierGroups': <Object>[],
    });
  }
}
