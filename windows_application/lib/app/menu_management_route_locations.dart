enum ProductWorkspaceTab {
  overview,
  variants,
  modifiers,
  recipe,
  availability,
  usage;

  String get queryValue => name;

  static ProductWorkspaceTab fromQuery(String? value) =>
      ProductWorkspaceTab.values.firstWhere(
        (tab) => tab.queryValue == value,
        orElse: () => ProductWorkspaceTab.overview,
      );
}

enum MenuWorkspaceTab {
  overview,
  sections,
  products;

  String get queryValue => name;

  static MenuWorkspaceTab fromQuery(String? value) =>
      MenuWorkspaceTab.values.firstWhere(
        (tab) => tab.queryValue == value,
        orElse: () => MenuWorkspaceTab.overview,
      );
}

/// Canonical Menu Management locations shared by route callers.
///
/// Product Workspace state lives in the URL so it survives navigation history
/// and a browser refresh. Child routes carry only domain identities.
abstract final class MenuManagementRouteLocations {
  static String menuWorkspace(
    int menuId, {
    MenuWorkspaceTab tab = MenuWorkspaceTab.overview,
  }) => Uri(
    path: '/menu-management/menus/$menuId',
    queryParameters: <String, String>{'tab': tab.queryValue},
  ).toString();
  static String productWorkspace(
    int productId, {
    ProductWorkspaceTab tab = ProductWorkspaceTab.overview,
    int? variantId,
  }) {
    final Map<String, String> query = <String, String>{'tab': tab.queryValue};
    if (tab == ProductWorkspaceTab.recipe &&
        variantId != null &&
        variantId > 0) {
      query['variantId'] = '$variantId';
    }
    return Uri(
      path: '/menu-management/products/$productId',
      queryParameters: query,
    ).toString();
  }

  static String recipeEditor(int productId, int variantId) =>
      '/menu-management/products/$productId/variants/$variantId/recipe/edit';

  static String recipeTest(int productId, int variantId) =>
      '/menu-management/products/$productId/variants/$variantId/recipe/test';

  static String productMaterialEffect(int productId, int optionId) =>
      '/menu-management/products/$productId/modifier-options/$optionId/material-effect';

  static String variantMaterialEffect(
    int productId,
    int variantId,
    int optionId,
  ) =>
      '/menu-management/products/$productId/variants/$variantId/modifier-options/$optionId/material-effect';

  static String globalMaterialEffect(int groupId, int optionId) =>
      '/menu-management/modifiers/$groupId/options/$optionId/material-effect';

  static String variantPricing(int productId, int variantId) =>
      '/menu-management/products/$productId/variants/$variantId/pricing';

  static String scheduledAvailability(int productId, {int? variantId}) => Uri(
    path: '/menu-management/products/$productId/availability',
    queryParameters: <String, String>{
      if (variantId != null && variantId > 0) 'variantId': '$variantId',
    },
  ).toString();

  static String operationalAvailability(int productId, {int? variantId}) => Uri(
    path: '/menu-management/products/$productId/operational-availability',
    queryParameters: <String, String>{
      if (variantId != null && variantId > 0) 'variantId': '$variantId',
    },
  ).toString();
}
