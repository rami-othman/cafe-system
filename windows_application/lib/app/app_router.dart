import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_sizes.dart';
import '../core/services/service_locator.dart';
import '../features/discounts/views/create_discount_policy_screen.dart';
import '../features/discounts/controllers/discounts_cubit.dart';
import '../features/discounts/models/discount_list_item.dart';
import '../features/discounts/views/discounts_list_screen.dart';
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
import '../features/reports/controllers/reports_overview_cubit.dart';
import '../features/reports/views/reports_overview_screen.dart';
import '../features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import '../features/finance_inventory_setup/views/finance_setup_dashboard_screen.dart';
import '../features/finance_inventory_setup/views/financial_accounts_screen.dart';
import '../features/finance_inventory_setup/views/journal_entries_screen.dart';
import '../features/finance_inventory_setup/views/warehouses_setup_screen.dart';
import '../features/inventory/controllers/inventory_cubit.dart';
import '../features/inventory/views/inventory_items_screen.dart';
import '../features/inventory/views/item_details_screen.dart';
import '../features/inventory/views/item_form_screen.dart';
import '../features/inventory/views/inventory_screens.dart'
    hide InventoryItemDetailsScreen, InventoryItemsScreen;
import '../features/inventory/views/inventory_workflow_screens.dart';
import '../features/operational_context/controllers/operational_branch_cubit.dart';
import '../features/operational_context/models/operational_branch_state.dart';
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
          showDefaultTopBar: state.matchedLocation.startsWith(
            AppRoutes.inventory,
          ),
          onRefresh: _refreshActionFor(state),
          textDirection: state.matchedLocation.startsWith(AppRoutes.inventory)
              ? TextDirection.rtl
              : TextDirection.ltr,
          sidebarWidth: state.matchedLocation.startsWith(AppRoutes.inventory)
              ? AppSizes.inventorySidebarWidth
              : null,
          topBarHeight: state.matchedLocation.startsWith(AppRoutes.inventory)
              ? AppSizes.inventoryTopBarHeight
              : null,
          sidebarLogoSize: state.matchedLocation.startsWith(AppRoutes.inventory)
              ? AppSizes.inventoryLogoMarkSize
              : null,
          sidebarPadding: state.matchedLocation.startsWith(AppRoutes.inventory)
              ? const EdgeInsetsDirectional.fromSTEB(
                  AppSizes.inventorySidebarHorizontalPadding,
                  AppSizes.inventorySidebarVerticalPadding,
                  AppSizes.inventorySidebarHorizontalPadding,
                  AppSizes.inventorySidebarVerticalPadding,
                )
              : null,
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
            BlocProvider<DiscountsCubit>(
              create: (_) => serviceLocator<DiscountsCubit>()..loadDiscounts(),
            ),
            BlocProvider<ReportsOverviewCubit>(
              create: (_) => serviceLocator<ReportsOverviewCubit>()..load(),
            ),
            BlocProvider<FinanceSetupCubit>(
              create: (_) => serviceLocator<FinanceSetupCubit>(),
            ),
            BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
            ),
            BlocProvider<OperationalBranchCubit>(
              create: (_) =>
                  serviceLocator<OperationalBranchCubit>()..loadBranches(),
            ),
          ],
          child: BlocListener<OperationalBranchCubit, OperationalBranchState>(
            listener: (BuildContext context, OperationalBranchState state) {
              final int? branchId = state.selectedBranchId;
              if (branchId == null) return;

              final OrdersCubit ordersCubit = context.read<OrdersCubit>();
              if (ordersCubit.state.selectedBranchId != branchId) {
                ordersCubit.loadOrders(branchId: branchId);
              }

              final PosCubit posCubit = context.read<PosCubit>();
              if (posCubit.state.branchId != branchId) {
                posCubit.loadInitialData(preferredBranchId: branchId);
              }

              context.read<InventoryCubit>().loadDashboard(branchId: branchId);
            },
            child: shell,
          ),
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.inventory,
          name: AppRouteNames.inventory,
          builder: (context, state) => const InventoryDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryItems,
          name: AppRouteNames.inventoryItems,
          builder: (context, state) => const InventoryItemsScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryItemCreate,
          name: AppRouteNames.inventoryItemCreate,
          builder: (context, state) => const ItemFormScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryItemEdit,
          name: AppRouteNames.inventoryItemEdit,
          builder: (context, state) =>
              ItemFormScreen(itemId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: AppRoutes.inventoryUnitConversions,
          name: AppRouteNames.inventoryUnitConversions,
          builder: (context, state) => const InventoryUnitConversionsScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryItemDetails,
          name: AppRouteNames.inventoryItemDetails,
          builder: (context, state) => InventoryItemDetailsScreen(
            itemId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryBalances,
          name: AppRouteNames.inventoryBalances,
          builder: (context, state) => const InventoryBalancesScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryMovements,
          name: AppRouteNames.inventoryMovements,
          builder: (context, state) => const InventoryMovementsScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryMovementCreate,
          name: AppRouteNames.inventoryMovementCreate,
          builder: (context, state) => const InventoryMovementCreateScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryMovementLegacyCreate,
          redirect: (context, state) => AppRoutes.inventoryMovementCreate,
        ),
        GoRoute(
          path: AppRoutes.inventoryCounts,
          name: AppRouteNames.inventoryCounts,
          builder: (context, state) => const InventoryCountsScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryTransfers,
          name: AppRouteNames.inventoryTransfers,
          builder: (context, state) => const InventoryTransfersWorkspaceScreen(),
        ),
        GoRoute(
          path: AppRoutes.inventoryTransferDetails,
          name: AppRouteNames.inventoryTransferDetails,
          builder: (context, state) => InventoryTransfersWorkspaceScreen(
            transferId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: AppRoutes.barCheckTemplates,
          name: AppRouteNames.barCheckTemplates,
          builder: (context, state) => const BarCheckTemplatesScreen(),
        ),
        GoRoute(
          path: AppRoutes.barCheckTemplateDetails,
          name: AppRouteNames.barCheckTemplateDetails,
          builder: (context, state) => BarCheckTemplateEditorScreen(
            templateId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryCountDetails,
          name: AppRouteNames.inventoryCountDetails,
          builder: (context, state) => InventoryCountDetailsScreen(
            countId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeSetup,
          name: AppRouteNames.financeSetup,
          builder: (context, state) => const FinanceSetupDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.financeWarehouses,
          name: AppRouteNames.financeWarehouses,
          builder: (context, state) => const WarehousesSetupScreen(),
        ),
        GoRoute(
          path: AppRoutes.financeAccounts,
          name: AppRouteNames.financeAccounts,
          builder: (context, state) => const FinancialAccountsScreen(),
        ),
        GoRoute(
          path: AppRoutes.financeJournalEntries,
          name: AppRouteNames.financeJournalEntries,
          builder: (context, state) => const JournalEntriesScreen(),
        ),
        GoRoute(
          path: AppRoutes.reports,
          name: AppRouteNames.reports,
          builder: (context, state) => const ReportsOverviewScreen(),
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
  if (state.matchedLocation.startsWith(AppRoutes.inventory)) {
    return const InventorySubNavigation();
  }

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

Future<void> Function(BuildContext context)? _refreshActionFor(
  GoRouterState state,
) {
  if (state.matchedLocation.startsWith(AppRoutes.menu)) {
    return (BuildContext context) => context.read<MenuCubit>().loadMenuData();
  }

  return switch (state.matchedLocation) {
    AppRoutes.pos =>
      (BuildContext context) => context.read<PosCubit>().loadInitialData(),
    AppRoutes.orders =>
      (BuildContext context) => context.read<OrdersCubit>().refreshOrders(),
    AppRoutes.reports =>
      (BuildContext context) => context.read<ReportsOverviewCubit>().load(),
    AppRoutes.discounts =>
      (BuildContext context) => context.read<DiscountsCubit>().loadDiscounts(),
    AppRoutes.financeSetup =>
      (BuildContext context) =>
          context.read<FinanceSetupCubit>().loadDashboard(),
    AppRoutes.financeWarehouses =>
      (BuildContext context) =>
          context.read<FinanceSetupCubit>().loadWarehouses(),
    AppRoutes.financeAccounts =>
      (BuildContext context) =>
          context.read<FinanceSetupCubit>().loadAccounts(),
    AppRoutes.financeJournalEntries =>
      (BuildContext context) => context.read<FinanceSetupCubit>().loadEntries(),
    AppRoutes.inventory =>
      (BuildContext context) => context.read<InventoryCubit>().loadDashboard(),
    AppRoutes.inventoryItems =>
      (BuildContext context) => context.read<InventoryCubit>().loadItems(),
    AppRoutes.inventoryUnitConversions =>
      (BuildContext context) =>
          context.read<InventoryCubit>().loadUnitConversions(),
    AppRoutes.inventoryBalances =>
      (BuildContext context) => context.read<InventoryCubit>().loadBalances(),
    AppRoutes.inventoryMovements =>
      (BuildContext context) => context.read<InventoryCubit>().loadMovements(),
    AppRoutes.inventoryCounts =>
      (BuildContext context) => context.read<InventoryCubit>().loadCounts(),
    _ => null,
  };
}

String _activeLabelFor(GoRouterState state) {
  if (state.matchedLocation.startsWith(AppRoutes.menu)) {
    return 'Menu';
  }
  if (state.matchedLocation.startsWith(AppRoutes.inventory)) {
    return 'Inventory Management';
  }

  return switch (state.matchedLocation) {
    AppRoutes.financeSetup ||
    AppRoutes.financeWarehouses ||
    AppRoutes.financeAccounts ||
    AppRoutes.financeJournalEntries => 'تهيئة المالية والمخازن',
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
  static const String menu = '/menu';
  static const String menuProducts = '/menu/products';
  static const String menuProductCreate = '/menu/products/create';
  static const String menuCategories = '/menu/categories';
  static const String menuModifiers = '/menu/modifiers';
  static const String menuCombos = '/menu/combos';
  static const String menuProductVariants = '/menu/products/:id/variants';
  static const String menuProductAvailability =
      '/menu/products/:id/availability';
  static const String financeSetup = '/finance-inventory-setup';
  static const String financeWarehouses = '/finance-inventory-setup/warehouses';
  static const String financeAccounts = '/finance-inventory-setup/accounts';
  static const String financeJournalEntries =
      '/finance-inventory-setup/journal-entries';
  static const String inventory = '/inventory';
  static const String inventoryItems = '/inventory/items';
  static const String inventoryItemCreate = '/inventory/items/new';
  static const String inventoryItemEdit = '/inventory/items/:id/edit';
  static const String inventoryUnitConversions = '/inventory/units-conversions';
  static const String inventoryItemDetails = '/inventory/items/:id';
  static String inventoryItemDetailPath(int id) => '/inventory/items/$id';
  static String inventoryItemEditPath(int id) => '/inventory/items/$id/edit';
  static const String inventoryBalances = '/inventory/balances';
  static const String inventoryMovements = '/inventory/movements';
  static const String inventoryMovementCreate = '/inventory/movements/new';
  static const String inventoryMovementLegacyCreate =
      '/inventory/movements/create';
  static const String inventoryCounts = '/inventory/counts';
  static const String inventoryTransfers = '/inventory/transfers';
  static const String inventoryTransferDetails = '/inventory/transfers/:id';
  static String inventoryTransferPath(int id) => '/inventory/transfers/$id';
  static const String barCheckTemplates = '/inventory/bar-check-templates';
  static const String barCheckTemplateDetails = '/inventory/bar-check-templates/:id';
  static String barCheckTemplatePath(int id) => '/inventory/bar-check-templates/$id';
  static const String inventoryCountDetails = '/inventory/counts/:id';
  static String inventoryCountDetailPath(int id) => '/inventory/counts/$id';
}

abstract final class AppRouteNames {
  static const String pos = 'pos';
  static const String orders = 'orders';
  static const String reports = 'reports';
  static const String discounts = 'discounts';
  static const String discountCreate = 'discount-create';
  static const String menu = 'menu';
  static const String menuProducts = 'menu-products';
  static const String menuProductCreate = 'menu-product-create';
  static const String menuCategories = 'menu-categories';
  static const String menuModifiers = 'menu-modifiers';
  static const String menuCombos = 'menu-combos';
  static const String menuProductVariants = 'menu-product-variants';
  static const String menuProductAvailability = 'menu-product-availability';
  static const String financeSetup = 'finance-setup';
  static const String financeWarehouses = 'finance-warehouses';
  static const String financeAccounts = 'finance-accounts';
  static const String financeJournalEntries = 'finance-journal-entries';
  static const String inventory = 'inventory';
  static const String inventoryItems = 'inventory-items';
  static const String inventoryItemCreate = 'inventory-item-create';
  static const String inventoryItemEdit = 'inventory-item-edit';
  static const String inventoryUnitConversions = 'inventory-unit-conversions';
  static const String inventoryItemDetails = 'inventory-item-details';
  static const String inventoryBalances = 'inventory-balances';
  static const String inventoryMovements = 'inventory-movements';
  static const String inventoryMovementCreate = 'inventory-movement-create';
  static const String inventoryCounts = 'inventory-counts';
  static const String inventoryTransfers = 'inventory-transfers';
  static const String inventoryTransferDetails = 'inventory-transfer-details';
  static const String barCheckTemplates = 'bar-check-templates';
  static const String barCheckTemplateDetails = 'bar-check-template-details';
  static const String inventoryCountDetails = 'inventory-count-details';
}
