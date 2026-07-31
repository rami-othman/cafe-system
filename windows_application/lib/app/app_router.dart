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
import '../features/menu_management/views/product_catalog_screen.dart';
import '../features/menu_management/views/product_detail_screen.dart';
import '../features/menu_management/products/controllers/product_editor_cubit.dart';
import '../features/menu_management/products/views/product_editor_screen.dart';
import '../features/menu_management/variants/controllers/variants_cubit.dart';
import '../features/menu_management/variants/views/variants_screen.dart';
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
  static const String menuManagementProductDetail =
      '/menu-management/products/:productId';
  static const String menuManagementProductCreate =
      '/menu-management/products/create';
  static const String menuManagementProductEdit =
      '/menu-management/products/:productId/edit';
  static const String menuManagementProductVariants =
      '/menu-management/products/:productId/variants';
}

abstract final class AppRouteNames {
  static const String pos = 'pos';
  static const String orders = 'orders';
  static const String reports = 'reports';
  static const String discounts = 'discounts';
  static const String discountCreate = 'discount-create';
  static const String menuManagementProducts = 'menu-management-products';
  static const String menuManagementProductDetail =
      'menu-management-product-detail';
  static const String menuManagementProductCreate =
      'menu-management-product-create';
  static const String menuManagementProductEdit =
      'menu-management-product-edit';
  static const String menuManagementProductVariants =
      'menu-management-product-variants';
}
