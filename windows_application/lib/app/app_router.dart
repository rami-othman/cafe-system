import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/services/service_locator.dart';
import '../features/discounts/views/create_discount_policy_screen.dart';
import '../features/menu/controllers/menu_cubit.dart';
import '../features/menu/views/categories_management_screen.dart';
import '../features/menu/views/combo_builder_screen.dart';
import '../features/menu/views/create_edit_product_screen.dart';
import '../features/menu/views/menu_overview_screen.dart';
import '../features/menu/views/modifier_groups_screen.dart';
import '../features/menu/views/product_availability_screen.dart';
import '../features/menu/views/product_variants_pricing_screen.dart';
import '../features/menu/views/products_list_screen.dart';
import '../features/menu/widgets/menu_top_bar.dart';
import '../features/orders/controllers/orders_cubit.dart';
import '../features/orders/views/orders_screen.dart';
import '../features/pos/controllers/pos_cubit.dart';
import '../features/pos/views/pos_screen.dart';
import '../features/pos/widgets/pos_cart_panel.dart';
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
            BlocProvider<MenuCubit>(
              create: (_) => serviceLocator<MenuCubit>()..loadMenuData(),
            ),
          ],
          child: shell,
        );
      },
      routes: <RouteBase>[
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
          builder: (context, state) => const CreateDiscountPolicyScreen(),
        ),
        GoRoute(
          path: AppRoutes.menu,
          name: AppRouteNames.menu,
          builder: (context, state) => const MenuOverviewScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuProducts,
          name: AppRouteNames.menuProducts,
          builder: (context, state) => const ProductsListScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuProductCreate,
          name: AppRouteNames.menuProductCreate,
          builder: (context, state) => const CreateEditProductScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuCategories,
          name: AppRouteNames.menuCategories,
          builder: (context, state) => const CategoriesManagementScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuModifiers,
          name: AppRouteNames.menuModifiers,
          builder: (context, state) => const ModifierGroupsScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuCombos,
          name: AppRouteNames.menuCombos,
          builder: (context, state) => const ComboBuilderScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuProductVariants,
          name: AppRouteNames.menuProductVariants,
          builder: (context, state) => ProductVariantsPricingScreen(
            productId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.menuProductAvailability,
          name: AppRouteNames.menuProductAvailability,
          builder: (context, state) =>
              ProductAvailabilityScreen(productId: state.pathParameters['id']!),
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

Widget? _topBarFor(GoRouterState state) {
  return switch (state.matchedLocation) {
    AppRoutes.menu => const MenuTopBar(),
    AppRoutes.menuProducts => const MenuTopBar(
      title: 'Menu Management',
      showSearch: false,
    ),
    AppRoutes.menuProductCreate => const MenuTopBar(
      title: 'Menu Management',
      showSearch: false,
    ),
    AppRoutes.menuModifiers => const MenuTopBar(
      title: 'Menu Management',
      showSearch: false,
      showSearchAction: true,
    ),
    _ => null,
  };
}

String _activeLabelFor(GoRouterState state) {
  if (state.matchedLocation.startsWith(AppRoutes.menu)) {
    return 'Menu';
  }

  return switch (state.matchedLocation) {
    AppRoutes.discountCreate => 'Discounts',
    AppRoutes.orders => 'Orders',
    _ => 'POS',
  };
}

abstract final class AppRoutes {
  static const String pos = '/';
  static const String orders = '/orders';
  static const String discountCreate = '/discounts/create';
  static const String menu = '/menu';
  static const String menuProducts = '/menu/products';
  static const String menuProductCreate = '/menu/products/create';
  static const String menuCategories = '/menu/categories';
  static const String menuModifiers = '/menu/modifiers';
  static const String menuCombos = '/menu/combos';
  static const String menuProductVariants = '/menu/products/:id/variants';
  static const String menuProductAvailability =
      '/menu/products/:id/availability';
}

abstract final class AppRouteNames {
  static const String pos = 'pos';
  static const String orders = 'orders';
  static const String discountCreate = 'discount-create';
  static const String menu = 'menu';
  static const String menuProducts = 'menu-products';
  static const String menuProductCreate = 'menu-product-create';
  static const String menuCategories = 'menu-categories';
  static const String menuModifiers = 'menu-modifiers';
  static const String menuCombos = 'menu-combos';
  static const String menuProductVariants = 'menu-product-variants';
  static const String menuProductAvailability = 'menu-product-availability';
}
