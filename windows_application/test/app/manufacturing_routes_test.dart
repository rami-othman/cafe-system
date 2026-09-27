import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_router.dart';

/// Guards the Manufacturing route contract (Phases 2-7) against a typo or an
/// accidental rename - each of these paths is wired to a real GoRoute in
/// `app_router.dart` and referenced by `ManufacturingNavigationBar` and the
/// feature's own screens via `context.go(...)`.
void main() {
  group('Manufacturing route constants', () {
    test('static paths', () {
      expect(AppRoutes.manufacturing, '/manufacturing');
      expect(AppRoutes.manufacturingMaterials, '/manufacturing/materials');
      expect(
        AppRoutes.manufacturingMaterialCreate,
        '/manufacturing/materials/new',
      );
      expect(
        AppRoutes.manufacturingMaterialDetail,
        '/manufacturing/materials/:itemId',
      );
      expect(
        AppRoutes.manufacturingMaterialEdit,
        '/manufacturing/materials/:itemId/edit',
      );
      expect(
        AppRoutes.manufacturingStockReceiptCreate,
        '/manufacturing/stock-receipts/new',
      );
      expect(AppRoutes.manufacturingRecipes, '/manufacturing/recipes');
      expect(
        AppRoutes.manufacturingRecipeCreate,
        '/manufacturing/recipes/new',
      );
      expect(
        AppRoutes.manufacturingRecipeDetail,
        '/manufacturing/recipes/:recipeId',
      );
      expect(
        AppRoutes.manufacturingRecipeEdit,
        '/manufacturing/recipes/:recipeId/edit',
      );
      expect(AppRoutes.manufacturingProduction, '/manufacturing/production');
      expect(
        AppRoutes.manufacturingProductionNew,
        '/manufacturing/production/new',
      );
      expect(
        AppRoutes.manufacturingProductionNewForRecipe,
        '/manufacturing/production/new/:recipeId',
      );
      expect(
        AppRoutes.manufacturingProductionComplete,
        '/manufacturing/production/complete/:draftId',
      );
      expect(
        AppRoutes.manufacturingProductionResult,
        '/manufacturing/production/result/:id',
      );
      expect(
        AppRoutes.manufacturingProductionDetail,
        '/manufacturing/production/:id',
      );
      expect(
        AppRoutes.manufacturingConversionCreate,
        '/manufacturing/conversions/new',
      );
      expect(
        AppRoutes.manufacturingConversionDetail,
        '/manufacturing/conversions/:id',
      );
      expect(AppRoutes.manufacturingReports, '/manufacturing/reports');
    });

    test('path builders interpolate real ids', () {
      expect(
        AppRoutes.manufacturingMaterialDetailPath(7),
        '/manufacturing/materials/7',
      );
      expect(
        AppRoutes.manufacturingMaterialEditPath(7),
        '/manufacturing/materials/7/edit',
      );
      expect(
        AppRoutes.manufacturingRecipeDetailPath(3),
        '/manufacturing/recipes/3',
      );
      expect(
        AppRoutes.manufacturingRecipeEditPath(3),
        '/manufacturing/recipes/3/edit',
      );
      expect(
        AppRoutes.manufacturingProductionNewForRecipePath(3),
        '/manufacturing/production/new/3',
      );
      expect(
        AppRoutes.manufacturingProductionCompletePath(501),
        '/manufacturing/production/complete/501',
      );
      expect(
        AppRoutes.manufacturingProductionResultPath('PR-1'),
        '/manufacturing/production/result/PR-1',
      );
      expect(
        AppRoutes.manufacturingProductionDetailPath('PR-1'),
        '/manufacturing/production/PR-1',
      );
      expect(
        AppRoutes.manufacturingConversionDetailPath('CV-1'),
        '/manufacturing/conversions/CV-1',
      );
    });
  });
}
