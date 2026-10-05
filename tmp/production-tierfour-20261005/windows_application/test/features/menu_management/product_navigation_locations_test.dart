import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/menu_management_route_locations.dart';

void main() {
  test('Product Workspace tabs have one URL-addressable canonical parent', () {
    expect(
      MenuManagementRouteLocations.productWorkspace(15),
      '/menu-management/products/15?tab=overview',
    );
    for (final tab in ProductWorkspaceTab.values) {
      expect(
        MenuManagementRouteLocations.productWorkspace(15, tab: tab),
        '/menu-management/products/15?tab=${tab.queryValue}',
      );
    }
  });

  test('invalid workspace tab safely falls back to overview', () {
    expect(
      ProductWorkspaceTab.fromQuery('not-a-tab'),
      ProductWorkspaceTab.overview,
    );
    expect(ProductWorkspaceTab.fromQuery(null), ProductWorkspaceTab.overview);
  });

  test(
    'recipe and material-effect children use identities, not display names',
    () {
      expect(
        MenuManagementRouteLocations.productWorkspace(
          15,
          tab: ProductWorkspaceTab.recipe,
          variantId: 42,
        ),
        '/menu-management/products/15?tab=recipe&variantId=42',
      );
      expect(
        MenuManagementRouteLocations.recipeEditor(15, 42),
        '/menu-management/products/15/variants/42/recipe/edit',
      );
      expect(
        MenuManagementRouteLocations.variantMaterialEffect(15, 42, 9),
        '/menu-management/products/15/variants/42/modifier-options/9/material-effect',
      );
      expect(
        MenuManagementRouteLocations.globalMaterialEffect(8, 9),
        '/menu-management/modifiers/8/options/9/material-effect',
      );
    },
  );
}
