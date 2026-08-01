import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/services/service_locator.dart';
import '../features/discounts/views/create_discount_policy_screen.dart';
import '../features/discounts/controllers/discounts_cubit.dart';
import '../features/discounts/models/discount_list_item.dart';
import '../features/discounts/views/discounts_list_screen.dart';
import '../features/orders/controllers/orders_cubit.dart';
import '../features/orders/views/orders_screen.dart';
import '../features/pos/controllers/pos_cubit.dart';
import '../features/pos/views/pos_screen.dart';
import '../features/pos/widgets/pos_cart_panel.dart';
import '../features/reports/controllers/daily_report_cubit.dart';
import '../features/reports/views/daily_operational_report_screen.dart';
import '../features/menu_management/controllers/product_catalog_cubit.dart';
import '../features/menu_management/controllers/product_detail_cubit.dart';
import '../features/menu_management/controllers/product_lifecycle_cubit.dart';
import '../features/menu_management/views/product_catalog_screen.dart';
import '../features/menu_management/views/product_detail_screen.dart';
import '../features/menu_management/products/controllers/product_editor_cubit.dart';
import '../features/menu_management/products/views/product_editor_screen.dart';
import '../features/menu_management/variants/controllers/variants_cubit.dart';
import '../features/menu_management/variants/views/variants_screen.dart';
import '../features/menu_management/pricing/controllers/variant_price_overrides_cubit.dart';
import '../features/menu_management/pricing/views/variant_price_overrides_screen.dart';
import '../features/menu_management/availability/controllers/availability_cubit.dart';
import '../features/menu_management/availability/views/availability_screen.dart';
import '../features/menu_management/operational_availability/controllers/operational_availability_cubit.dart';
import '../features/menu_management/operational_availability/views/operational_availability_screen.dart';
import '../features/menu_management/modifiers/controllers/modifier_group_detail_cubit.dart';
import '../features/menu_management/modifiers/controllers/modifier_group_editor_cubit.dart';
import '../features/menu_management/modifiers/controllers/modifier_library_cubit.dart';
import '../features/menu_management/modifiers/views/modifier_group_detail_screen.dart';
import '../features/menu_management/modifiers/views/modifier_group_editor_screen.dart';
import '../features/menu_management/modifiers/views/modifier_library_screen.dart';
import '../features/menu_management/products/controllers/product_modifier_assignments_cubit.dart';
import '../features/menu_management/products/views/product_modifier_assignments_screen.dart';
import '../features/menu_management/menus/controllers/menu_list_cubit.dart';
import '../features/menu_management/menus/controllers/menu_detail_cubit.dart';
import '../features/menu_management/menus/controllers/menu_editor_cubit.dart';
import '../features/menu_management/menus/controllers/product_placements_cubit.dart';
import '../features/menu_management/menus/views/menu_list_screen.dart';
import '../features/menu_management/menus/views/menu_detail_screen.dart';
import '../features/menu_management/menus/views/menu_editor_screen.dart';
import '../features/menu_management/menus/views/product_placements_screen.dart';
import '../features/menu_management/assignments/controllers/menu_assignments_cubit.dart';
import '../features/menu_management/assignments/views/menu_assignments_screen.dart';
import '../features/menu_management/review/controllers/menu_review_cubit.dart';
import '../features/menu_management/review/views/menu_review_screen.dart';
import 'app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.pos,
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        final AppShell shell = AppShell(
          activeLabel: _activeLabelFor(state),
          rightPanel: _rightPanelFor(state),
          topBar: _topBarFor(state),
          onRefresh: _refreshActionFor(state),
          child: child,
        );

        return MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<PosCubit>(
              create: (_) => serviceLocator<PosCubit>()..loadInitialData(),
            ),
            BlocProvider<OrdersCubit>(
              create: (_) => serviceLocator<OrdersCubit>()..loadOrders(),
            ),
            BlocProvider<DiscountsCubit>(
              create: (_) => serviceLocator<DiscountsCubit>()..loadDiscounts(),
            ),
            BlocProvider<DailyReportCubit>(
              create: (_) => serviceLocator<DailyReportCubit>()..loadReport(),
            ),
            BlocProvider<ProductCatalogCubit>(
              create: (_) => serviceLocator<ProductCatalogCubit>(),
            ),
            BlocProvider<ProductLifecycleCubit>(
              create: (_) => serviceLocator<ProductLifecycleCubit>(),
            ),
          ],
          child: shell,
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.menuManagement,
          redirect: (_, _) => AppRoutes.menuManagementProducts,
        ),
        GoRoute(
          path: AppRoutes.menuManagementProducts,
          name: AppRouteNames.menuManagementProducts,
          builder: (context, state) => const ProductCatalogScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuManagementModifiers,
          name: AppRouteNames.menuManagementModifiers,
          builder: (context, state) => BlocProvider<ModifierLibraryCubit>(
            create: (_) => serviceLocator<ModifierLibraryCubit>(),
            child: const ModifierLibraryScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenus,
          name: AppRouteNames.menuManagementMenus,
          builder: (context, state) => BlocProvider<MenuListCubit>(
            create: (_) => serviceLocator<MenuListCubit>(),
            child: const MenuListScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementAssignments,
          name: AppRouteNames.menuManagementAssignments,
          builder: (context, state) => BlocProvider<MenuAssignmentsCubit>(
            create: (_) => serviceLocator<MenuAssignmentsCubit>(),
            child: MenuAssignmentsScreen(
              initialBranchId: int.tryParse(
                state.uri.queryParameters['branchId'] ?? '',
              ),
              initialChannel: state.uri.queryParameters['channel'],
              initialMenuId: int.tryParse(
                state.uri.queryParameters['menuId'] ?? '',
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuCreate,
          name: AppRouteNames.menuManagementMenuCreate,
          builder: (context, state) => BlocProvider<MenuEditorCubit>(
            create: (_) => serviceLocator<MenuEditorCubit>(),
            child: const MenuEditorScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuDetail,
          name: AppRouteNames.menuManagementMenuDetail,
          builder: (context, state) => BlocProvider<MenuDetailCubit>(
            create: (_) => serviceLocator<MenuDetailCubit>(),
            child: MenuDetailScreen(
              menuId: int.parse(state.pathParameters['menuId']!),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuPlacements,
          name: AppRouteNames.menuManagementMenuPlacements,
          builder: (context, state) => BlocProvider<ProductPlacementsCubit>(
            create: (_) => serviceLocator<ProductPlacementsCubit>(),
            child: ProductPlacementsScreen(
              menuId: int.parse(state.pathParameters['menuId']!),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuEdit,
          name: AppRouteNames.menuManagementMenuEdit,
          builder: (context, state) => BlocProvider<MenuEditorCubit>(
            create: (_) => serviceLocator<MenuEditorCubit>(),
            child: MenuEditorScreen(
              menuId: int.parse(state.pathParameters['menuId']!),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementModifierCreate,
          name: AppRouteNames.menuManagementModifierCreate,
          builder: (context, state) => BlocProvider<ModifierGroupEditorCubit>(
            create: (_) => serviceLocator<ModifierGroupEditorCubit>(),
            child: const ModifierGroupEditorScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementModifierDetail,
          name: AppRouteNames.menuManagementModifierDetail,
          builder: (context, state) => BlocProvider<ModifierGroupDetailCubit>(
            create: (_) => serviceLocator<ModifierGroupDetailCubit>(),
            child: ModifierGroupDetailScreen(
              groupId: int.parse(state.pathParameters['modifierGroupId']!),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementModifierEdit,
          name: AppRouteNames.menuManagementModifierEdit,
          builder: (context, state) => BlocProvider<ModifierGroupEditorCubit>(
            create: (_) => serviceLocator<ModifierGroupEditorCubit>(),
            child: ModifierGroupEditorScreen(
              groupId: int.parse(state.pathParameters['modifierGroupId']!),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductCreate,
          name: AppRouteNames.menuManagementProductCreate,
          builder: (context, state) => BlocProvider<ProductEditorCubit>(
            create: (_) => serviceLocator<ProductEditorCubit>(),
            child: const ProductEditorScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductEdit,
          name: AppRouteNames.menuManagementProductEdit,
          builder: (context, state) => BlocProvider<ProductEditorCubit>(
            create: (_) => serviceLocator<ProductEditorCubit>(),
            child: ProductEditorScreen(
              productId: int.parse(state.pathParameters['productId']!),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductModifiers,
          name: AppRouteNames.menuManagementProductModifiers,
          builder: (context, state) =>
              BlocProvider<ProductModifierAssignmentsCubit>(
                create: (_) =>
                    serviceLocator<ProductModifierAssignmentsCubit>(),
                child: ProductModifierAssignmentsScreen(
                  productId: int.parse(state.pathParameters['productId']!),
                ),
              ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementReview,
          name: AppRouteNames.menuManagementReview,
          builder: (context, state) => BlocProvider<MenuReviewCubit>(
            create: (_) => serviceLocator<MenuReviewCubit>(),
            child: MenuReviewScreen(
              branchId: int.tryParse(
                state.uri.queryParameters['branchId'] ?? '',
              ),
              channel: state.uri.queryParameters['channel'],
              menuId: int.tryParse(state.uri.queryParameters['menuId'] ?? ''),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductVariants,
          name: AppRouteNames.menuManagementProductVariants,
          builder: (context, state) => BlocProvider<VariantsCubit>(
            create: (_) => serviceLocator<VariantsCubit>(),
            child: VariantsScreen(
              productId: int.parse(state.pathParameters['productId']!),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementVariantPricing,
          name: AppRouteNames.menuManagementVariantPricing,
          builder: (context, state) {
            final int? productId = int.tryParse(
              state.pathParameters['productId'] ?? '',
            );
            final int? variantId = int.tryParse(
              state.pathParameters['variantId'] ?? '',
            );
            if (productId == null ||
                productId <= 0 ||
                variantId == null ||
                variantId <= 0) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<VariantPriceOverridesCubit>(
              create: (_) => serviceLocator<VariantPriceOverridesCubit>(),
              child: VariantPriceOverridesScreen(
                productId: productId,
                variantId: variantId,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductAvailability,
          name: AppRouteNames.menuManagementProductAvailability,
          builder: (context, state) {
            final int? productId = int.tryParse(
              state.pathParameters['productId'] ?? '',
            );
            if (productId == null || productId <= 0) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<AvailabilityCubit>(
              create: (_) => serviceLocator<AvailabilityCubit>(),
              child: AvailabilityScreen(
                productId: productId,
                variantId: int.tryParse(
                  state.uri.queryParameters['variantId'] ?? '',
                ),
                branchId: int.tryParse(
                  state.uri.queryParameters['branchId'] ?? '',
                ),
                channel: state.uri.queryParameters['channel'],
                returnToVariants:
                    state.uri.queryParameters['from'] == 'variants',
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductOperationalAvailability,
          name: AppRouteNames.menuManagementProductOperationalAvailability,
          builder: (context, state) {
            final int? productId = int.tryParse(
              state.pathParameters['productId'] ?? '',
            );
            if (productId == null || productId <= 0) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<OperationalAvailabilityCubit>(
              create: (_) => serviceLocator<OperationalAvailabilityCubit>(),
              child: OperationalAvailabilityScreen(
                productId: productId,
                variantId: int.tryParse(
                  state.uri.queryParameters['variantId'] ?? '',
                ),
                branchId: int.tryParse(
                  state.uri.queryParameters['branchId'] ?? '',
                ),
                channel: state.uri.queryParameters['channel'],
                returnToVariants:
                    state.uri.queryParameters['from'] == 'variants',
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductDetail,
          name: AppRouteNames.menuManagementProductDetail,
          builder: (context, state) => BlocProvider<ProductDetailCubit>(
            create: (_) => serviceLocator<ProductDetailCubit>(),
            child: ProductDetailScreen(
              productId: int.parse(state.pathParameters['productId']!),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.reports,
          name: AppRouteNames.reports,
          builder: (context, state) => const DailyOperationalReportScreen(),
        ),
        GoRoute(
          path: AppRoutes.discounts,
          name: AppRouteNames.discounts,
          builder: (context, state) => const DiscountsListScreen(),
        ),
        GoRoute(
          path: AppRoutes.pos,
          name: AppRouteNames.pos,
          builder: (context, state) => const PosScreen(),
        ),
        GoRoute(
          path: AppRoutes.orders,
          name: AppRouteNames.orders,
          builder: (context, state) => const OrdersScreen(),
        ),
        GoRoute(
          path: AppRoutes.discountCreate,
          name: AppRouteNames.discountCreate,
          builder: (context, state) => CreateDiscountPolicyScreen(
            initialDiscount: state.extra as DiscountListItem?,
          ),
        ),
      ],
    ),
  ],
);

Widget? _rightPanelFor(GoRouterState state) {
  return switch (state.matchedLocation) {
    AppRoutes.pos => const PosCartPanel(),
    _ => null,
  };
}

Widget? _topBarFor(GoRouterState state) => null;

Future<void> Function(BuildContext context)? _refreshActionFor(
  GoRouterState state,
) {
  return switch (state.matchedLocation) {
    AppRoutes.pos =>
      (BuildContext context) => context.read<PosCubit>().loadInitialData(),
    AppRoutes.orders =>
      (BuildContext context) => context.read<OrdersCubit>().refreshOrders(),
    AppRoutes.reports =>
      (BuildContext context) => context.read<DailyReportCubit>().loadReport(),
    AppRoutes.discounts =>
      (BuildContext context) => context.read<DiscountsCubit>().loadDiscounts(),
    AppRoutes.menuManagementProducts =>
      (BuildContext context) => context.read<ProductCatalogCubit>().refresh(),
    AppRoutes.menuManagementModifiers =>
      (BuildContext context) => context.read<ModifierLibraryCubit>().refresh(),
    AppRoutes.menuManagementMenus =>
      (BuildContext context) => context.read<MenuListCubit>().refresh(),
    _ => null,
  };
}

String _activeLabelFor(GoRouterState state) {
  if (state.uri.path.startsWith(AppRoutes.menuManagement)) {
    return 'Menu Management';
  }
  return switch (state.matchedLocation) {
    AppRoutes.discounts || AppRoutes.discountCreate => 'Discounts',
    AppRoutes.orders => 'Orders',
    AppRoutes.reports => 'Reports',
    _ => 'POS',
  };
}

abstract final class AppRoutes {
  static const String pos = '/';
  static const String orders = '/orders';
  static const String reports = '/reports';
  static const String discounts = '/discounts';
  static const String discountCreate = '/discounts/create';
  static const String menuManagement = '/menu-management';
  static const String menuManagementProducts = '/menu-management/products';
  static const String menuManagementModifiers = '/menu-management/modifiers';
  static const String menuManagementMenus = '/menu-management/menus';
  static const String menuManagementAssignments =
      '/menu-management/assignments';
  static const String menuManagementReview = '/menu-management/review';
  static const String menuManagementMenuCreate =
      '/menu-management/menus/create';
  static const String menuManagementMenuDetail =
      '/menu-management/menus/:menuId';
  static const String menuManagementMenuEdit =
      '/menu-management/menus/:menuId/edit';
  static const String menuManagementMenuPlacements =
      '/menu-management/menus/:menuId/placements';
  static const String menuManagementModifierCreate =
      '/menu-management/modifiers/create';
  static const String menuManagementModifierDetail =
      '/menu-management/modifiers/:modifierGroupId';
  static const String menuManagementModifierEdit =
      '/menu-management/modifiers/:modifierGroupId/edit';
  static const String menuManagementProductDetail =
      '/menu-management/products/:productId';
  static const String menuManagementProductCreate =
      '/menu-management/products/create';
  static const String menuManagementProductEdit =
      '/menu-management/products/:productId/edit';
  static const String menuManagementProductVariants =
      '/menu-management/products/:productId/variants';
  static const String menuManagementVariantPricing =
      '/menu-management/products/:productId/variants/:variantId/pricing';
  static const String menuManagementProductModifiers =
      '/menu-management/products/:productId/modifiers';
  static const String menuManagementProductAvailability =
      '/menu-management/products/:productId/availability';
  static const String menuManagementProductOperationalAvailability =
      '/menu-management/products/:productId/operational-availability';
}

abstract final class AppRouteNames {
  static const String pos = 'pos';
  static const String orders = 'orders';
  static const String reports = 'reports';
  static const String discounts = 'discounts';
  static const String discountCreate = 'discount-create';
  static const String menuManagementProducts = 'menu-management-products';
  static const String menuManagementModifiers = 'menu-management-modifiers';
  static const String menuManagementMenus = 'menu-management-menus';
  static const String menuManagementAssignments = 'menu-management-assignments';
  static const String menuManagementReview = 'menu-management-review';
  static const String menuManagementMenuCreate = 'menu-management-menu-create';
  static const String menuManagementMenuDetail = 'menu-management-menu-detail';
  static const String menuManagementMenuEdit = 'menu-management-menu-edit';
  static const String menuManagementMenuPlacements =
      'menu-management-menu-placements';
  static const String menuManagementModifierCreate =
      'menu-management-modifier-create';
  static const String menuManagementModifierDetail =
      'menu-management-modifier-detail';
  static const String menuManagementModifierEdit =
      'menu-management-modifier-edit';
  static const String menuManagementProductDetail =
      'menu-management-product-detail';
  static const String menuManagementProductCreate =
      'menu-management-product-create';
  static const String menuManagementProductEdit =
      'menu-management-product-edit';
  static const String menuManagementProductVariants =
      'menu-management-product-variants';
  static const String menuManagementVariantPricing =
      'menu-management-variant-pricing';
  static const String menuManagementProductModifiers =
      'menu-management-product-modifiers';
  static const String menuManagementProductAvailability =
      'menu-management-product-availability';
  static const String menuManagementProductOperationalAvailability =
      'menu-management-product-operational-availability';
}

class _InvalidCatalogRouteScreen extends StatelessWidget {
  const _InvalidCatalogRouteScreen();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('The requested catalog route is invalid.'));
}
