import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/menu_management_route_locations.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import 'menu_module_scaffold.dart';

enum MenuModuleDestination {
  products('/menu-management/products', Icons.inventory_2_outlined),
  modifiers('/menu-management/modifiers', Icons.tune_outlined),
  catalogSetup(
    '/menu-management/catalog-setup',
    Icons.settings_suggest_outlined,
  ),
  menus('/menu-management/menus', Icons.restaurant_menu_outlined),
  assignments('/menu-management/assignments', Icons.calendar_month_outlined),
  review('/menu-management/review', Icons.verified_outlined);

  const MenuModuleDestination(this.path, this.icon);

  final String path;
  final IconData icon;

  static MenuModuleDestination forPath(String path) {
    if (path.startsWith('/menu-management/catalog-setup')) {
      return MenuModuleDestination.catalogSetup;
    }
    if (path.startsWith('/menu-management/assignments')) {
      return MenuModuleDestination.assignments;
    }
    if (path.startsWith('/menu-management/review')) {
      return MenuModuleDestination.review;
    }
    if (path.startsWith('/menu-management/menus')) {
      return MenuModuleDestination.menus;
    }
    if (path.startsWith('/menu-management/modifiers') ||
        path.startsWith('/menu-management/modifier-options')) {
      return MenuModuleDestination.modifiers;
    }
    return MenuModuleDestination.products;
  }
}

class MenuModuleNavigation extends StatelessWidget {
  const MenuModuleNavigation({
    super.key,
    required this.selected,
    this.onDestinationSelected,
  });

  final MenuModuleDestination selected;
  final ValueChanged<MenuModuleDestination>? onDestinationSelected;

  void _select(BuildContext context, MenuModuleDestination destination) {
    if (destination == selected) return;
    final ValueChanged<MenuModuleDestination>? callback = onDestinationSelected;
    if (callback != null) {
      callback(destination);
      return;
    }
    context.go(destination.path);
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 1440;
    final AppLocalizations? l10n = context.maybeL10n;
    final List<_NavigationGroup> groups = <_NavigationGroup>[
      _NavigationGroup(
        label: l10n?.menuManagementCatalog ?? 'Catalog',
        destinations: const <MenuModuleDestination>[
          MenuModuleDestination.products,
          MenuModuleDestination.modifiers,
          MenuModuleDestination.catalogSetup,
        ],
      ),
      _NavigationGroup(
        label: l10n?.menuManagementMenusGroup ?? 'Menus',
        destinations: const <MenuModuleDestination>[
          MenuModuleDestination.menus,
          MenuModuleDestination.assignments,
        ],
      ),
      _NavigationGroup(
        label: l10n?.menuManagementReleaseGroup ?? 'Release',
        destinations: const <MenuModuleDestination>[
          MenuModuleDestination.review,
        ],
      ),
    ];

    return Semantics(
      container: true,
      label: l10n?.menuManagementNavigation ?? 'Menu Management navigation',
      child: Container(
        key: const Key('menu-module-navigation'),
        width: compact
            ? AppSizes.menuModuleNavigationCompactWidth
            : AppSizes.menuModuleNavigationExpandedWidth,
        color: AppColors.surface,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: BorderDirectional(end: BorderSide(color: AppColors.border)),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (BuildContext context, int index) =>
                _NavigationGroupView(
                  group: groups[index],
                  selected: selected,
                  compact: compact,
                  labelFor: (MenuModuleDestination destination) =>
                      _destinationLabel(l10n, destination),
                  onSelected: (MenuModuleDestination destination) =>
                      _select(context, destination),
                ),
          ),
        ),
      ),
    );
  }
}

class _NavigationGroup {
  const _NavigationGroup({required this.label, required this.destinations});

  final String label;
  final List<MenuModuleDestination> destinations;
}

class _NavigationGroupView extends StatelessWidget {
  const _NavigationGroupView({
    required this.group,
    required this.selected,
    required this.compact,
    required this.labelFor,
    required this.onSelected,
  });

  final _NavigationGroup group;
  final MenuModuleDestination selected;
  final bool compact;
  final String Function(MenuModuleDestination destination) labelFor;
  final ValueChanged<MenuModuleDestination> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: group.label,
    child: Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        if (!compact) ...<Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              group.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        for (final MenuModuleDestination destination in group.destinations)
          _DestinationButton(
            key: Key('menu-module-${destination.name}'),
            destination: destination,
            label: labelFor(destination),
            compact: compact,
            selected: destination == selected,
            onPressed: () => onSelected(destination),
          ),
      ],
    ),
  );
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    super.key,
    required this.destination,
    required this.label,
    required this.compact,
    required this.selected,
    required this.onPressed,
  });

  final MenuModuleDestination destination;
  final String label;
  final bool compact;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget button = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.transparent,
        borderRadius: AppRadius.control,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.control,
          focusColor: AppColors.primarySoft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: compact ? AppSpacing.sm : AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    destination.icon,
                    size: 20,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: label, child: button) : button;
  }
}

String _destinationLabel(
  AppLocalizations? l10n,
  MenuModuleDestination destination,
) => switch (destination) {
  MenuModuleDestination.products => l10n?.menuManagementProducts ?? 'Products',
  MenuModuleDestination.modifiers =>
    l10n?.menuManagementModifiers ?? 'Modifiers',
  MenuModuleDestination.catalogSetup =>
    l10n?.menuManagementCatalogSetup ?? 'Catalog setup',
  MenuModuleDestination.menus => l10n?.menuManagementMenus ?? 'Menus',
  MenuModuleDestination.assignments =>
    l10n?.menuManagementAssignments ?? 'Assignments & schedules',
  MenuModuleDestination.review =>
    l10n?.menuManagementReviewPublish ?? 'Review & Publish',
};

List<MenuBreadcrumb> menuModuleBreadcrumbsFor(BuildContext context, Uri uri) {
  final AppLocalizations? l10n = context.maybeL10n;
  final MenuModuleDestination destination = MenuModuleDestination.forPath(
    uri.path,
  );
  final String rootLabel = _destinationLabel(l10n, destination);
  final List<MenuBreadcrumb> breadcrumbs = <MenuBreadcrumb>[
    MenuBreadcrumb(label: rootLabel, onTap: () => context.go(destination.path)),
  ];

  String? detail;
  final String path = uri.path;
  if (destination == MenuModuleDestination.products) {
    if (path.endsWith('/create')) {
      detail = l10n?.menuBreadcrumbCreateProduct ?? 'Create product';
    } else if (path.contains('/variants/') && path.endsWith('/pricing')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      breadcrumbs.add(
        _workspaceTabBreadcrumb(
          context,
          l10n?.menuBreadcrumbVariants ?? 'Variants',
          uri,
          ProductWorkspaceTab.variants,
        ),
      );
      detail = l10n?.menuBreadcrumbPricing ?? 'Pricing';
    } else if (path.endsWith('/recipe/test') ||
        path.contains('/recipe-simulation')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      breadcrumbs.add(
        _workspaceTabBreadcrumb(
          context,
          l10n?.productUxRecipeMaterials ?? 'Recipe & Materials',
          uri,
          ProductWorkspaceTab.recipe,
        ),
      );
      detail = 'Test Recipe';
    } else if (path.endsWith('/recipe/edit') || path.endsWith('/recipe')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      breadcrumbs.add(
        _workspaceTabBreadcrumb(
          context,
          l10n?.productUxRecipeMaterials ?? 'Recipe & Materials',
          uri,
          ProductWorkspaceTab.recipe,
        ),
      );
      detail = path.endsWith('/recipe/edit')
          ? l10n?.menuBreadcrumbRecipe ?? 'Base recipe'
          : l10n?.menuBreadcrumbRecipe ?? 'Recipe';
    } else if (path.endsWith('/variants')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      detail = l10n?.menuBreadcrumbVariants ?? 'Variants';
    } else if (path.endsWith('/modifiers')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      detail = l10n?.menuBreadcrumbModifiers ?? 'Modifiers';
    } else if (path.endsWith('/availability')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      detail = l10n?.menuBreadcrumbAvailability ?? 'Availability';
    } else if (path.endsWith('/operational-availability')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      detail =
          l10n?.menuBreadcrumbOperationalAvailability ??
          'Operational availability';
    } else if (path.contains('/modifier-options/')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      breadcrumbs.add(
        _workspaceTabBreadcrumb(
          context,
          l10n?.productUxRecipeMaterials ?? 'Recipe & Materials',
          uri,
          ProductWorkspaceTab.recipe,
        ),
      );
      detail = 'Material Effect';
    } else if (path.contains('/products/') && path.endsWith('/edit')) {
      breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
      detail = l10n?.menuBreadcrumbEditProduct ?? 'Edit product';
    } else if (path.startsWith('/menu-management/products/')) {
      final ProductWorkspaceTab tab = ProductWorkspaceTab.fromQuery(
        uri.queryParameters['tab'],
      );
      if (tab == ProductWorkspaceTab.overview) {
        detail = l10n?.menuBreadcrumbProduct ?? 'Product';
      } else {
        breadcrumbs.add(_productBreadcrumb(context, l10n, uri));
        detail = switch (tab) {
          ProductWorkspaceTab.variants =>
            l10n?.menuBreadcrumbVariants ?? 'Variants',
          ProductWorkspaceTab.modifiers =>
            l10n?.menuBreadcrumbModifiers ?? 'Modifiers',
          ProductWorkspaceTab.recipe =>
            l10n?.productUxRecipeMaterials ?? 'Recipe & Materials',
          ProductWorkspaceTab.availability =>
            l10n?.menuBreadcrumbAvailability ?? 'Availability',
          ProductWorkspaceTab.usage => 'Usage',
          ProductWorkspaceTab.overview =>
            l10n?.menuBreadcrumbProduct ?? 'Product',
        };
      }
    }
  } else if (destination == MenuModuleDestination.modifiers) {
    if (path.endsWith('/create')) {
      detail =
          l10n?.menuBreadcrumbCreateModifierGroup ?? 'Create modifier group';
    } else if (path.endsWith('/edit')) {
      breadcrumbs.add(_modifierGroupBreadcrumb(context, l10n, uri));
      detail = l10n?.menuBreadcrumbEditModifierGroup ?? 'Edit modifier group';
    } else if (path.contains('/recipe-adjustments')) {
      detail =
          l10n?.menuBreadcrumbMaterialAdjustments ?? 'Material adjustments';
    } else if (path.contains('/options/') &&
        path.endsWith('/material-effect')) {
      breadcrumbs.add(_modifierGroupBreadcrumb(context, l10n, uri));
      detail = 'Material Effect';
    } else if (path.startsWith('/menu-management/modifiers/')) {
      detail = l10n?.menuBreadcrumbModifierGroup ?? 'Modifier group';
    }
  } else if (destination == MenuModuleDestination.menus) {
    if (path.endsWith('/create')) {
      detail = l10n?.menuBreadcrumbCreateMenu ?? 'Create menu';
    } else if (path.endsWith('/edit')) {
      breadcrumbs.add(_menuBreadcrumb(context, l10n, uri));
      detail = l10n?.menuBreadcrumbEditMenu ?? 'Edit menu';
    } else if (path.endsWith('/placements')) {
      breadcrumbs.add(_menuBreadcrumb(context, l10n, uri));
      detail = l10n?.menuBreadcrumbComposition ?? 'Composition';
    } else if (path.startsWith('/menu-management/menus/')) {
      detail = l10n?.menuBreadcrumbMenu ?? 'Menu';
    }
  } else if (destination == MenuModuleDestination.review &&
      uri.queryParameters['tab'] == 'versions') {
    detail = l10n?.menuBreadcrumbVersionHistory ?? 'Version history';
  } else if (destination == MenuModuleDestination.catalogSetup) {
    detail = switch (uri.queryParameters['tab']) {
      'reporting-categories' => l10n?.catalogSetupReportingCategoriesTitle,
      'kitchen-stations' => l10n?.catalogSetupKitchenStationsTitle,
      _ => l10n?.catalogSetupCategoriesTitle,
    };
  }

  if (detail != null) breadcrumbs.add(MenuBreadcrumb(label: detail));
  return breadcrumbs.length == 1 ? const <MenuBreadcrumb>[] : breadcrumbs;
}

int? _routeId(Uri uri, String segment) {
  final List<String> segments = uri.pathSegments;
  final int index = segments.indexOf(segment);
  if (index < 0 || index + 1 >= segments.length) return null;
  return int.tryParse(segments[index + 1]);
}

int? _productIdFor(Uri uri) =>
    _routeId(uri, 'products') ??
    int.tryParse(uri.queryParameters['productId'] ?? '');

int? _variantIdFor(Uri uri) =>
    _routeId(uri, 'variants') ?? _routeId(uri, 'product-variants');

MenuBreadcrumb _productBreadcrumb(
  BuildContext context,
  AppLocalizations? l10n,
  Uri uri,
) {
  final int? productId = _productIdFor(uri);
  return MenuBreadcrumb(
    label: l10n?.menuBreadcrumbProduct ?? 'Product',
    onTap: () => context.go(
      productId == null
          ? MenuModuleDestination.products.path
          : '/menu-management/products/$productId',
    ),
  );
}

MenuBreadcrumb _workspaceTabBreadcrumb(
  BuildContext context,
  String label,
  Uri uri,
  ProductWorkspaceTab tab,
) {
  final int? productId = _productIdFor(uri);
  return MenuBreadcrumb(
    label: label,
    onTap: () => context.go(
      productId == null
          ? MenuModuleDestination.products.path
          : MenuManagementRouteLocations.productWorkspace(
              productId,
              tab: tab,
              variantId: _variantIdFor(uri),
            ),
    ),
  );
}

MenuBreadcrumb _modifierGroupBreadcrumb(
  BuildContext context,
  AppLocalizations? l10n,
  Uri uri,
) {
  final int? modifierGroupId = _routeId(uri, 'modifiers');
  return MenuBreadcrumb(
    label: l10n?.menuBreadcrumbModifierGroup ?? 'Modifier group',
    onTap: () => context.go(
      modifierGroupId == null
          ? MenuModuleDestination.modifiers.path
          : '/menu-management/modifiers/$modifierGroupId',
    ),
  );
}

MenuBreadcrumb _menuBreadcrumb(
  BuildContext context,
  AppLocalizations? l10n,
  Uri uri,
) {
  final int? menuId = _routeId(uri, 'menus');
  return MenuBreadcrumb(
    label: l10n?.menuBreadcrumbMenu ?? 'Menu',
    onTap: () => context.go(
      menuId == null
          ? MenuModuleDestination.menus.path
          : '/menu-management/menus/$menuId',
    ),
  );
}
