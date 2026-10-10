import 'item_route_scope.dart';
import 'purchase_route_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'menu_management_route_locations.dart';
import 'customer_management_route_locations.dart';
import 'shift_route_locations.dart';

import '../core/services/service_locator.dart';
import '../features/cafe_configuration/controllers/discount_settings_cubit.dart';
import '../features/cafe_configuration/views/discount_settings_screen.dart';
import '../features/discounts/views/create_discount_policy_screen.dart';
import '../features/discounts/controllers/discounts_cubit.dart';
import '../features/discounts/models/discount_list_item.dart';
import '../features/discounts/views/discounts_list_screen.dart';
import '../features/discounts/widgets/discounts_area_tabs.dart';
import '../features/shift/controllers/shift_closing_cubit.dart';
import '../features/shift/controllers/shift_history_cubit.dart';
import '../features/shift/controllers/shift_overview_cubit.dart';
import '../features/shift/controllers/shift_report_cubit.dart';
import '../features/shift/views/shift_closing_screen.dart';
import '../features/shift/views/shift_history_screen.dart';
import '../features/shift/views/shift_overview_screen.dart';
import '../features/shift/views/shift_report_screen.dart';
import '../features/shift/widgets/shift_module_shell.dart';
import '../features/orders/controllers/orders_cubit.dart';
import '../features/orders/views/orders_screen.dart';
import '../features/pos/controllers/pos_cubit.dart';
import '../features/pos/controllers/pos_print_cubit.dart';
import '../features/pos/controllers/pos_state.dart';
import '../features/pos/controllers/pos_menu_sync_cubit.dart';
import '../features/pos/views/pos_screen.dart';
import '../features/pos/widgets/pos_cart_panel.dart';
import '../features/reports/controllers/daily_report_cubit.dart';
import '../features/reports/controllers/reports_overview_cubit.dart';
import '../features/reports/controllers/sales_profitability_cubit.dart';
import '../features/reports/controllers/cash_shifts_cubit.dart';
import '../features/reports/controllers/inventory_report_cubit.dart';
import '../features/reports/controllers/expenses_report_cubit.dart';
import '../features/reports/widgets/deferred_report_loader.dart';
import '../features/reports/views/reports_overview_screen.dart';
import '../features/reports/views/sales_profitability_screen.dart';
import '../features/reports/views/cash_shifts_screen.dart';
import '../features/reports/views/inventory_report_screen.dart';
import '../features/reports/views/expenses_report_screen.dart';
import '../shared/access/cashier_access.dart';
import '../features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import '../features/finance_inventory_setup/views/cash_banks_screen.dart';
import '../features/finance_inventory_setup/views/daily_closing_screen.dart';
import '../features/finance_inventory_setup/views/daily_closing_workspace_screen.dart';
import '../features/finance_inventory_setup/views/expense_categories_screen.dart';
import '../features/finance_inventory_setup/views/expenses_screen.dart';
import '../features/finance_inventory_setup/views/finance_setup_dashboard_screen.dart';
import '../features/finance_inventory_setup/views/invoice_type_catalog_screen.dart';
import '../features/finance_inventory_setup/views/financial_accounts_screen.dart';
import '../features/finance_inventory_setup/views/finance_operations_screen.dart';
import '../features/finance_inventory_setup/views/finance_overview.dart';
import '../features/finance_inventory_setup/views/finance_transactions.dart';
import '../features/finance_inventory_setup/views/financial_reports_screen.dart';
import '../features/finance_inventory_setup/views/journal_entries_screen.dart';
import '../features/finance_inventory_setup/views/vouchers_screen.dart';
import '../features/finance_inventory_setup/widgets/finance_module_shell.dart';
import '../features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import '../features/finance_inventory_setup/views/payment_methods_screen.dart';
import '../features/finance_inventory_setup/views/reconciliation_screen.dart';
import '../features/finance_inventory_setup/views/reconciliation_workspace_screen.dart';
import '../features/finance_inventory_setup/views/supplier_profile_screen.dart';
import '../features/finance_inventory_setup/views/suppliers_screen.dart';
import '../features/purchasing/controllers/purchasing_cubit.dart';
import '../features/purchasing/views/goods_receipt_detail_screen.dart';
import '../features/purchasing/views/goods_receipt_form_screen.dart';
import '../features/purchasing/views/purchase_invoice_detail_screen.dart';
import '../features/purchasing/views/purchase_invoice_form_screen.dart';
import '../features/purchasing/views/purchasing_center_screen.dart';
import '../features/sales/controllers/sales_cubit.dart';
import '../features/sales/views/sales_credit_note_screens.dart';
import '../features/sales/views/sales_screens.dart';
import '../features/finance_inventory_setup/views/warehouses_setup_screen.dart';
import '../features/inventory/controllers/inventory_cubit.dart';
import '../features/inventory/widgets/inventory_module_shell.dart';
import '../features/inventory/views/inventory_items_screen.dart';
import '../features/inventory/views/inventory_screens.dart'
    hide
        InventoryItemsScreen,
        InventoryItemDetailsScreen,
        InventoryTransfersScreen;
import '../features/inventory/views/inventory_workflow_screens.dart';
import '../features/inventory/views/item_details_screen.dart';
import '../features/inventory/views/item_form_screen.dart';
import '../features/manufacturing/controllers/manufacturing_conversion_cubit.dart';
import '../features/manufacturing/controllers/manufacturing_cubit.dart';
import '../features/manufacturing/controllers/manufacturing_production_cubit.dart';
import '../features/manufacturing/controllers/manufacturing_recipe_cubit.dart';
import '../features/manufacturing/controllers/manufacturing_reports_cubit.dart';
import '../features/manufacturing/views/manufacturing_conversion_details_screen.dart';
import '../features/manufacturing/views/manufacturing_conversion_form_screen.dart';
import '../features/manufacturing/views/manufacturing_materials_screen.dart';
import '../features/manufacturing/views/manufacturing_overview_screen.dart';
import '../features/manufacturing/views/manufacturing_production_complete_screen.dart';
import '../features/manufacturing/views/manufacturing_production_details_screen.dart';
import '../features/manufacturing/views/manufacturing_production_history_screen.dart';
import '../features/manufacturing/views/manufacturing_production_new_screen.dart';
import '../features/manufacturing/views/manufacturing_production_result_screen.dart';
import '../features/manufacturing/views/manufacturing_recipe_details_screen.dart';
import '../features/manufacturing/views/manufacturing_recipe_form_screen.dart';
import '../features/manufacturing/views/manufacturing_recipes_screen.dart';
import '../features/manufacturing/views/manufacturing_reports_screen.dart';
import '../features/manufacturing/views/manufacturing_stock_receipt_screen.dart';
import '../features/manufacturing/widgets/manufacturing_module_shell.dart';
import '../features/operational_context/controllers/operational_branch_cubit.dart';
import '../features/menu_management/controllers/product_catalog_cubit.dart';
import '../features/menu_management/controllers/product_detail_cubit.dart';
import '../features/menu_management/controllers/product_lifecycle_cubit.dart';
import '../features/menu_management/views/product_catalog_screen.dart';
import '../features/menu_management/views/product_detail_screen.dart';
import '../features/menu_management/products/controllers/product_editor_cubit.dart';
import '../features/menu_management/products/views/product_editor_screen.dart';
import '../features/menu_management/recipes/views/variant_recipe_screen.dart';
import '../features/menu_management/recipes/views/modifier_adjustment_screen.dart';
import '../features/menu_management/recipes/views/recipe_simulation_screen.dart';
import '../features/menu_management/recipes/controllers/recipe_cubits.dart';
import '../features/menu_management/repositories/menu_catalog_repository.dart';
import '../features/menu_management/pricing/controllers/variant_price_overrides_cubit.dart';
import '../features/menu_management/pricing/controllers/menu_pricing_cubit.dart';
import '../features/menu_management/pricing/views/variant_price_overrides_screen.dart';
import '../features/menu_management/pricing/views/menu_pricing_screen.dart';
import '../features/menu_management/pricing/menu_pricing_access.dart';
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
import '../features/menu_management/catalog_setup/controllers/catalog_setup_cubit.dart';
import '../features/menu_management/catalog_setup/models/catalog_setup_models.dart';
import '../features/menu_management/catalog_setup/views/catalog_setup_screen.dart';
import '../features/menu_management/menus/controllers/menu_list_cubit.dart';
import '../features/menu_management/menus/controllers/menu_detail_cubit.dart';
import '../features/menu_management/menus/controllers/product_placements_cubit.dart';
import '../features/menu_management/menus/views/menu_list_screen.dart';
import '../features/menu_management/menus/views/menu_detail_screen.dart';
import '../features/menu_management/assignments/controllers/menu_assignments_cubit.dart';
import '../features/menu_management/assignments/views/menu_assignments_screen.dart';
import '../features/menu_management/review/controllers/menu_review_cubit.dart';
import '../features/menu_management/review/views/menu_review_screen.dart';
import '../features/menu_management/versions/controllers/published_version_cubit.dart';
import '../features/menu_management/widgets/menu_module_navigation.dart';
import '../features/menu_management/widgets/menu_module_scaffold.dart';
import '../features/cashier_dashboard/controllers/cashier_dashboard_cubit.dart';
import '../features/cashier_dashboard/controllers/cashier_inventory_cubit.dart';
import '../features/cashier_dashboard/views/cashier_dashboard_screen.dart';
import '../features/cashier_dashboard/views/cashier_inventory_screen.dart';
import '../features/auth/views/settings_screen.dart';
import '../features/auth/controllers/auth_session_cubit.dart';
import '../features/auth/models/auth_session.dart';
import '../features/cafe_configuration/controllers/cafe_configuration_cubits.dart';
import '../features/cafe_configuration/controllers/printing_cubit.dart';
import '../features/cafe_configuration/controllers/cafe_configuration_overview_cubit.dart';
import '../features/cafe_configuration/controllers/tax_cubit.dart';
import '../features/cafe_configuration/controllers/team_cubit.dart';
import '../features/cafe_configuration/repositories/cafe_configuration_repository.dart';
import '../features/cafe_configuration/views/cafe_configuration_screens.dart';
import '../features/cafe_configuration/views/printing_screen.dart';
import '../features/cafe_configuration/views/team_tax_screens.dart';
import '../features/cafe_configuration/widgets/cafe_configuration_navigation.dart';
import '../features/cafe_configuration/widgets/cafe_configuration_scaffold.dart';
import '../features/customer_management/controllers/customer_detail_cubit.dart';
import '../features/customer_management/controllers/customer_order_history_cubit.dart';
import '../features/customer_management/controllers/customer_form_cubit.dart';
import '../features/customer_management/controllers/customer_list_cubit.dart';
import '../features/customer_management/models/customer_management_access.dart';
import '../features/customer_management/repositories/customer_management_repository.dart';
import '../features/customer_management/repositories/customer_import_repository.dart';
import '../features/customer_management/controllers/customer_group_list_cubit.dart';
import '../features/customer_management/controllers/customer_group_detail_cubit.dart';
import '../features/customer_management/controllers/customer_group_form_cubit.dart';
import '../features/customer_management/views/customer_group_list_screen.dart';
import '../features/customer_management/views/customer_group_detail_screen.dart';
import '../features/customer_management/views/customer_group_form_screen.dart';
import '../features/customer_management/views/customer_detail_screen.dart';
import '../features/customer_management/views/customer_order_history_screen.dart';
import '../features/customer_management/views/customer_form_screen.dart';
import '../features/customer_management/views/customer_list_screen.dart';
import '../features/customer_management/widgets/customer_management_scaffold.dart';
import '../features/customer_management/widgets/customer_create_dialog.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../shared/widgets/app_top_bar.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

Page<void> _customerGroupCreateModalPage(
  BuildContext context,
  GoRouterState state,
) => CustomTransitionPage<void>(
  key: state.pageKey,
  name: state.name,
  opaque: false,
  barrierDismissible: true,
  barrierColor: AppColors.materialEffectBackdrop,
  barrierLabel: AppLocalizations.of(context).customerManagementCreateGroup,
  transitionDuration: const Duration(milliseconds: 180),
  reverseTransitionDuration: const Duration(milliseconds: 140),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child),
  child: BlocProvider<CustomerGroupFormCubit>(
    create: (_) =>
        CustomerGroupFormCubit(serviceLocator<CustomerManagementRepository>()),
    child: const CustomerGroupFormScreen(),
  ),
);

Page<void> _customerCreateModalPage(
  BuildContext context,
  GoRouterState state,
) => CustomTransitionPage<void>(
  key: state.pageKey,
  name: state.name,
  opaque: false,
  barrierDismissible: true,
  barrierColor: AppColors.materialEffectBackdrop,
  barrierLabel: AppLocalizations.of(context).customerManagementCreateCustomer,
  transitionDuration: const Duration(milliseconds: 180),
  reverseTransitionDuration: const Duration(milliseconds: 140),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child),
  child: BlocProvider<CustomerFormCubit>(
    create: (_) =>
        CustomerFormCubit(serviceLocator<CustomerManagementRepository>()),
    child: CustomerCreateDialog(
      mode: CustomerCreateMode.administrative,
      child: CustomerFormScreen(
        dialogMode: true,
        lifecycleRepository: serviceLocator<CustomerManagementRepository>(),
      ),
    ),
  ),
);

Page<void> _materialEffectPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage<void>(
  child: child,
  key: state.pageKey,
  name: state.name,
  opaque: false,
  barrierDismissible: true,
  barrierColor: AppColors.materialEffectBackdrop,
  barrierLabel: AppLocalizations.of(context).recipeModifierMaterialEffects,
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
        child: child,
      ),
);

/// The live Cashier access projection. Read from the session each time rather
/// than cached, so a re-login as a different role is reflected immediately.
CashierAccess _cashierAccess() {
  final AuthSession? session = serviceLocator<AuthSessionCubit>().state.session;
  return CashierAccess.of(
    session?.user,
    customerManagementAllowed: session?.customerManagementAllowed ?? false,
  );
}

/// Central deep-link guard. A no-op for every non-Cashier role, so Owner,
/// Admin and Manager routing is untouched; a Cashier who types a Finance or
/// Inventory administration path is returned to their operational home.
String? _cashierRouteGuard(BuildContext _, GoRouterState state) =>
    _cashierAccess().redirectFor(state.uri.path);

/// The cafe's operational surface (POS, orders, shift, discounts, menu
/// management, the cafe dashboard, cashier inventory, and cafe
/// configuration) is unreachable for a factory user — the backend blocks all
/// of it (`EnsureCafeOperationalAccess`, plus the owner/manager-only cafe
/// configuration and menu management policies), so this guard sends a
/// factory user straight to Manufacturing instead of letting a deep link
/// resolve into a 403. A no-op for every non-factory role.
const List<String> _cafeOnlyPathsForFactoryUser = <String>[
  AppRoutes.pos,
  AppRoutes.orders,
  AppRoutes.discounts,
  AppRoutes.menuManagement,
  AppRoutes.dashboard,
  AppRoutes.cafeConfiguration,
  AppRoutes.cashierInventory,
];

String? _factoryRouteGuard(GoRouterState state) {
  final AuthUser? user = serviceLocator<AuthSessionCubit>().state.session?.user;
  if (user?.isFactoryUser != true) return null;

  final String path = state.uri.path;
  if (path == AppRoutes.manufacturing ||
      path.startsWith('${AppRoutes.manufacturing}/')) {
    return null;
  }
  if (ShiftRouteLocations.isShiftLocation(path)) return AppRoutes.manufacturing;

  final bool isCafeOnly = _cafeOnlyPathsForFactoryUser.any(
    (String cafePath) => path == cafePath || path.startsWith('$cafePath/'),
  );

  return isCafeOnly ? AppRoutes.manufacturing : null;
}

String? _topLevelRouteGuard(BuildContext context, GoRouterState state) =>
    _cashierRouteGuard(context, state) ?? _factoryRouteGuard(state);

/// Evaluated lazily on first router use, which is after the session restores.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation:
      serviceLocator<AuthSessionCubit>().state.session?.user.isFactoryUser ==
          true
      ? AppRoutes.manufacturing
      : _cashierAccess().homeRoute,
  redirect: _topLevelRouteGuard,
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        final bool isMenuManagement = state.uri.path.startsWith(
          AppRoutes.menuManagement,
        );
        final bool isCafeConfiguration = state.uri.path.startsWith(
          AppRoutes.cafeConfiguration,
        );
        final bool isReports = state.uri.path.startsWith(AppRoutes.reports);
        final bool isFinance = state.uri.path.startsWith(AppRoutes.finance);
        final bool isInventory = state.uri.path.startsWith(AppRoutes.inventory);
        final bool isManufacturing = state.uri.path.startsWith(
          AppRoutes.manufacturing,
        );
        final bool isCustomerManagement = state.uri.path.startsWith(
          CustomerManagementRouteLocations.customers,
        );
        final bool isShift = ShiftRouteLocations.isShiftLocation(
          state.uri.path,
        );
        // The Cashier surface renders inside the plain shell: it must not be
        // wrapped in the Inventory or Finance module shells, whose tabs lead
        // to screens a Cashier may not open.
        final bool isCashierSurface =
            state.uri.path == AppRoutes.dashboard ||
            state.uri.path.startsWith(AppRoutes.cashierInventory);
        final AppShell shell = AppShell(
          activeLabel: _activeDestinationFor(state),
          rightPanel: _rightPanelFor(state),
          topBar: _topBarFor(context, state),
          isManufacturingRoute: isManufacturing,
          onRefresh:
              state.uri.path == AppRoutes.pos || isReports || isCashierSurface
              ? _refreshActionFor(state)
              : null,
          prioritizeContentWidth: isMenuManagement || isCafeConfiguration,
          child: isMenuManagement
              ? MenuModuleScaffold(
                  navigationSlot: MenuModuleNavigation(
                    selected: MenuModuleDestination.forPath(state.uri.path),
                  ),
                  breadcrumbs: menuModuleBreadcrumbsFor(context, state.uri),
                  padding: EdgeInsets.zero,
                  breadcrumbPadding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    0,
                  ),
                  child: child,
                )
              : isFinance
              ? FinanceModuleShell(
                  selectedTab: _financeActiveTabFor(state.uri.path),
                  access: _cashierAccess(),
                  child: child,
                )
              : isInventory
              ? InventoryModuleShell(
                  selectedTab: _inventoryActiveTabFor(state.uri.path),
                  child: child,
                )
              : isManufacturing
              ? ManufacturingModuleShell(
                  selectedTab: _manufacturingActiveTabFor(state.uri.path),
                  child: child,
                )
              : isShift
              ? ShiftModuleShell(location: state.uri.path, child: child)
              : isCafeConfiguration
              ? CafeConfigurationScaffold(
                  selected: CafeConfigurationDestination.forPath(
                    state.uri.path,
                  ),
                  child: child,
                )
              : isCustomerManagement
              ? CustomerManagementScaffold(
                  groupsSelected: state.uri.path.startsWith(
                    CustomerManagementRouteLocations.groups,
                  ),
                  child: child,
                )
              : child,
        );

        // The shell keeps only session-wide POS transaction state alive. Every
        // mutable administrative feature is provided by its route below, so an
        // unvisited module cannot issue a background request. This list must
        // stay a fixed length: a conditional entry here previously caused the
        // MultiBlocProvider's nested element chain to reshape on navigation,
        // which could leave a BlocBuilder below querying its provider before
        // the new chain finished mounting (ProviderNotFoundException).
        return MultiBlocProvider(
          key: ValueKey((
            serviceLocator<AuthSessionCubit>().state.session?.accessToken,
            serviceLocator<AuthSessionCubit>().state.session?.tenant.id,
            serviceLocator<AuthSessionCubit>().state.session?.user.id,
            serviceLocator<AuthSessionCubit>().state.session?.user.role,
          )),
          providers: <BlocProvider<dynamic>>[
            BlocProvider<PosCubit>(
              create: (_) => serviceLocator<PosCubit>()..loadInitialData(),
            ),
            BlocProvider<PosPrintCubit>(
              create: (_) => serviceLocator<PosPrintCubit>(),
            ),
            BlocProvider<PosMenuSyncCubit>(
              create: (_) => serviceLocator<PosMenuSyncCubit>(),
            ),
            BlocProvider<DailyReportCubit>(
              create: (_) => serviceLocator<DailyReportCubit>(),
            ),
            // One lazy operational-branch context owns every Inventory route.
            // Route-local copies previously left InventoryModuleShell outside
            // the provider and also allowed shell/page branch state to diverge.
            BlocProvider<OperationalBranchCubit>(
              create: (_) => serviceLocator<OperationalBranchCubit>(),
            ),
          ],
          child: shell,
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: CustomerManagementRouteLocations.customerOrders,
          redirect: _customerManagementAccessRedirect,
          builder: (BuildContext context, GoRouterState state) {
            final int? id = CustomerManagementRouteLocations.parseId(
              state.pathParameters['customerId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<CustomerOrderHistoryCubit>(
              create: (_) => CustomerOrderHistoryCubit(
                serviceLocator<CustomerManagementRepository>(),
              ),
              child: CustomerOrderHistoryScreen(
                customerId: id,
                repository: serviceLocator<CustomerManagementRepository>(),
              ),
            );
          },
        ),
        GoRoute(
          path: CustomerManagementRouteLocations.customers,
          redirect: _customerManagementAccessRedirect,
          builder: (BuildContext context, GoRouterState state) =>
              BlocProvider<CustomerListCubit>(
                create: (_) => CustomerListCubit(
                  serviceLocator<CustomerManagementRepository>(),
                ),
                child: CustomerListScreen(
                  lifecycleRepository:
                      serviceLocator<CustomerManagementRepository>(),
                  importRepository:
                      serviceLocator<CustomerManagementRepository>()
                          as CustomerImportRepository,
                ),
              ),
          routes: <RouteBase>[
            GoRoute(
              path: 'new',
              parentNavigatorKey: _rootNavigatorKey,
              redirect: _customerManagementAccessRedirect,
              pageBuilder: _customerCreateModalPage,
            ),
          ],
        ),
        GoRoute(
          path: CustomerManagementRouteLocations.groups,
          redirect: _customerManagementAccessRedirect,
          builder: (BuildContext context, GoRouterState state) =>
              BlocProvider<CustomerGroupListCubit>(
                create: (_) => CustomerGroupListCubit(
                  serviceLocator<CustomerManagementRepository>(),
                ),
                child: CustomerGroupListScreen(
                  repository: serviceLocator<CustomerManagementRepository>(),
                ),
              ),
          routes: <RouteBase>[
            GoRoute(
              path: 'new',
              parentNavigatorKey: _rootNavigatorKey,
              redirect: _customerManagementAccessRedirect,
              pageBuilder: _customerGroupCreateModalPage,
            ),
          ],
        ),
        GoRoute(
          path: CustomerManagementRouteLocations.groupEdit,
          redirect: _customerManagementAccessRedirect,
          builder: (BuildContext context, GoRouterState state) {
            final int? id = CustomerManagementRouteLocations.parseId(
              state.pathParameters['groupId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<CustomerGroupFormCubit>(
              create: (_) => CustomerGroupFormCubit(
                serviceLocator<CustomerManagementRepository>(),
              ),
              child: CustomerGroupFormScreen(groupId: id),
            );
          },
        ),
        GoRoute(
          path: CustomerManagementRouteLocations.groupDetail,
          redirect: _customerManagementAccessRedirect,
          builder: (BuildContext context, GoRouterState state) {
            final int? id = CustomerManagementRouteLocations.parseId(
              state.pathParameters['groupId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<CustomerGroupDetailCubit>(
              create: (_) => CustomerGroupDetailCubit(
                serviceLocator<CustomerManagementRepository>(),
              ),
              child: CustomerGroupDetailScreen(
                groupId: id,
                repository: serviceLocator<CustomerManagementRepository>(),
              ),
            );
          },
        ),
        GoRoute(
          path: CustomerManagementRouteLocations.customerEdit,
          redirect: _customerManagementAccessRedirect,
          builder: (BuildContext context, GoRouterState state) {
            final int? id = CustomerManagementRouteLocations.parseId(
              state.pathParameters['customerId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<CustomerFormCubit>(
              create: (_) => CustomerFormCubit(
                serviceLocator<CustomerManagementRepository>(),
              ),
              child: CustomerFormScreen(
                customerId: id,
                lifecycleRepository:
                    serviceLocator<CustomerManagementRepository>(),
              ),
            );
          },
        ),
        GoRoute(
          path: CustomerManagementRouteLocations.customerDetail,
          redirect: _customerManagementAccessRedirect,
          builder: (BuildContext context, GoRouterState state) {
            final int? id = CustomerManagementRouteLocations.parseId(
              state.pathParameters['customerId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<CustomerDetailCubit>(
              create: (_) => CustomerDetailCubit(
                serviceLocator<CustomerManagementRepository>(),
              ),
              child: CustomerDetailScreen(
                customerId: id,
                lifecycleRepository:
                    serviceLocator<CustomerManagementRepository>(),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementModifierRecipeAdjustments,
          name: AppRouteNames.menuManagementModifierRecipeAdjustments,
          pageBuilder: (context, state) {
            final optionId = int.tryParse(
              state.pathParameters['optionId'] ?? '',
            );
            if (optionId == null || optionId < 1) {
              return const NoTransitionPage<void>(
                child: _InvalidCatalogRouteScreen(),
              );
            }
            return _materialEffectPage(
              context,
              state,
              BlocProvider<ModifierAdjustmentCubit>(
                create: (_) => ModifierAdjustmentCubit(
                  serviceLocator<MenuCatalogRepository>(),
                ),
                child: ModifierAdjustmentScreen(optionId: optionId),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementVariantRecipe,
          name: AppRouteNames.menuManagementVariantRecipe,
          builder: (context, state) {
            final variantId = int.tryParse(
              state.pathParameters['variantId'] ?? '',
            );
            final productId = int.tryParse(
              state.uri.queryParameters['productId'] ?? '',
            );
            if (variantId == null ||
                variantId < 1 ||
                (state.uri.queryParameters.containsKey('productId') &&
                    (productId == null || productId < 1))) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<VariantRecipeCubit>(
              create: (_) =>
                  VariantRecipeCubit(serviceLocator<MenuCatalogRepository>()),
              child: VariantRecipeScreen(
                variantId: variantId,
                productId: productId,
                editMode: state.uri.queryParameters['edit'] == '1',
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductModifierRecipeAdjustments,
          name: AppRouteNames.menuManagementProductModifierRecipeAdjustments,
          redirect: (context, state) {
            final productId = parsePositiveRouteId(
              state.pathParameters['productId'],
            );
            final optionId = parsePositiveRouteId(
              state.pathParameters['optionId'],
            );
            if (productId == null || optionId == null) return null;
            return MenuManagementRouteLocations.productMaterialEffect(
              productId,
              optionId,
            );
          },
          builder: (context, state) {
            final optionId = int.tryParse(
              state.pathParameters['optionId'] ?? '',
            );
            final productId = int.tryParse(
              state.pathParameters['productId'] ?? '',
            );
            if (optionId == null ||
                optionId < 1 ||
                productId == null ||
                productId < 1) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<ModifierAdjustmentCubit>(
              create: (_) => ModifierAdjustmentCubit(
                serviceLocator<MenuCatalogRepository>(),
              ),
              child: ModifierAdjustmentScreen(
                optionId: optionId,
                productId: productId,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementVariantModifierRecipeAdjustments,
          name: AppRouteNames.menuManagementVariantModifierRecipeAdjustments,
          redirect: (context, state) {
            final productId = parsePositiveRouteId(
              state.uri.queryParameters['productId'],
            );
            final variantId = parsePositiveRouteId(
              state.pathParameters['variantId'],
            );
            final optionId = parsePositiveRouteId(
              state.pathParameters['optionId'],
            );
            if (productId == null || variantId == null || optionId == null) {
              return null;
            }
            return MenuManagementRouteLocations.variantMaterialEffect(
              productId,
              variantId,
              optionId,
            );
          },
          builder: (context, state) {
            final optionId = int.tryParse(
              state.pathParameters['optionId'] ?? '',
            );
            final variantId = int.tryParse(
              state.pathParameters['variantId'] ?? '',
            );
            final productId = int.tryParse(
              state.uri.queryParameters['productId'] ?? '',
            );
            if (optionId == null ||
                optionId < 1 ||
                variantId == null ||
                variantId < 1) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<ModifierAdjustmentCubit>(
              create: (_) => ModifierAdjustmentCubit(
                serviceLocator<MenuCatalogRepository>(),
              ),
              child: ModifierAdjustmentScreen(
                optionId: optionId,
                productId: productId,
                variantId: variantId,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementRecipeSimulation,
          name: AppRouteNames.menuManagementRecipeSimulation,
          redirect: (context, state) {
            final productId = parsePositiveRouteId(
              state.pathParameters['productId'],
            );
            final variantId = parsePositiveRouteId(
              state.pathParameters['variantId'],
            );
            if (productId == null || variantId == null) return null;
            return MenuManagementRouteLocations.recipeTest(
              productId,
              variantId,
            );
          },
          builder: (context, state) {
            final productId = int.tryParse(
              state.pathParameters['productId'] ?? '',
            );
            final variantId = int.tryParse(
              state.pathParameters['variantId'] ?? '',
            );
            if (productId == null ||
                productId < 1 ||
                variantId == null ||
                variantId < 1) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<RecipeSimulationCubit>(
              create: (_) => RecipeSimulationCubit(
                serviceLocator<MenuCatalogRepository>(),
              ),
              child: RecipeSimulationScreen(
                productId: productId,
                variantId: variantId,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductRecipeEditor,
          name: AppRouteNames.menuManagementProductRecipeEditor,
          builder: (context, state) {
            final productId = parsePositiveRouteId(
              state.pathParameters['productId'],
            );
            final variantId = parsePositiveRouteId(
              state.pathParameters['variantId'],
            );
            if (productId == null || variantId == null) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<VariantRecipeCubit>(
              create: (_) =>
                  VariantRecipeCubit(serviceLocator<MenuCatalogRepository>()),
              child: VariantRecipeScreen(
                productId: productId,
                variantId: variantId,
                editMode: true,
                returnToRecipeWorkspace: true,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductRecipeTest,
          name: AppRouteNames.menuManagementProductRecipeTest,
          builder: (context, state) {
            final productId = parsePositiveRouteId(
              state.pathParameters['productId'],
            );
            final variantId = parsePositiveRouteId(
              state.pathParameters['variantId'],
            );
            if (productId == null || variantId == null) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<RecipeSimulationCubit>(
              create: (_) => RecipeSimulationCubit(
                serviceLocator<MenuCatalogRepository>(),
              ),
              child: RecipeSimulationScreen(
                productId: productId,
                variantId: variantId,
                onClose: () =>
                    _returnToRecipeWorkspace(context, productId, variantId),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductMaterialEffect,
          name: AppRouteNames.menuManagementProductMaterialEffect,
          pageBuilder: (context, state) {
            final productId = parsePositiveRouteId(
              state.pathParameters['productId'],
            );
            final optionId = parsePositiveRouteId(
              state.pathParameters['optionId'],
            );
            if (productId == null || optionId == null) {
              return const NoTransitionPage<void>(
                child: _InvalidCatalogRouteScreen(),
              );
            }
            return _materialEffectPage(
              context,
              state,
              BlocProvider<ModifierAdjustmentCubit>(
                create: (_) => ModifierAdjustmentCubit(
                  serviceLocator<MenuCatalogRepository>(),
                ),
                child: ModifierAdjustmentScreen(
                  optionId: optionId,
                  productId: productId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementVariantMaterialEffect,
          name: AppRouteNames.menuManagementVariantMaterialEffect,
          pageBuilder: (context, state) {
            final productId = parsePositiveRouteId(
              state.pathParameters['productId'],
            );
            final variantId = parsePositiveRouteId(
              state.pathParameters['variantId'],
            );
            final optionId = parsePositiveRouteId(
              state.pathParameters['optionId'],
            );
            if (productId == null || variantId == null || optionId == null) {
              return const NoTransitionPage<void>(
                child: _InvalidCatalogRouteScreen(),
              );
            }
            return _materialEffectPage(
              context,
              state,
              BlocProvider<ModifierAdjustmentCubit>(
                create: (_) => ModifierAdjustmentCubit(
                  serviceLocator<MenuCatalogRepository>(),
                ),
                child: ModifierAdjustmentScreen(
                  optionId: optionId,
                  productId: productId,
                  variantId: variantId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementGlobalMaterialEffect,
          name: AppRouteNames.menuManagementGlobalMaterialEffect,
          pageBuilder: (context, state) {
            final groupId = parsePositiveRouteId(
              state.pathParameters['modifierGroupId'],
            );
            final optionId = parsePositiveRouteId(
              state.pathParameters['optionId'],
            );
            if (groupId == null || optionId == null) {
              return const NoTransitionPage<void>(
                child: _InvalidCatalogRouteScreen(),
              );
            }
            return _materialEffectPage(
              context,
              state,
              BlocProvider<ModifierAdjustmentCubit>(
                create: (_) => ModifierAdjustmentCubit(
                  serviceLocator<MenuCatalogRepository>(),
                ),
                child: ModifierAdjustmentScreen(
                  optionId: optionId,
                  groupId: groupId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementCatalogSetup,
          name: AppRouteNames.menuManagementCatalogSetup,
          builder: (context, state) => BlocProvider<CatalogSetupCubit>(
            create: (_) => serviceLocator<CatalogSetupCubit>(),
            child: CatalogSetupScreen(
              initialKind: CatalogSetupKindPath.fromQuery(
                state.uri.queryParameters['tab'],
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagement,
          redirect: (_, _) => AppRoutes.menuManagementProducts,
        ),
        GoRoute(
          path: AppRoutes.menuManagementProducts,
          name: AppRouteNames.menuManagementProducts,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ProductCatalogCubit>(
                create: (_) => serviceLocator<ProductCatalogCubit>(),
              ),
              BlocProvider<ProductLifecycleCubit>(
                create: (_) => serviceLocator<ProductLifecycleCubit>(),
              ),
            ],
            child: const ProductCatalogScreen(),
          ),
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
          // The primary interaction is a right-side sheet from the list.
          // Preserve legacy bookmarks without reviving the old full-page form.
          redirect: (_, _) => AppRoutes.menuManagementMenus,
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuDetail,
          name: AppRouteNames.menuManagementMenuDetail,
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['menuId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<MenuDetailCubit>(
                  create: (_) => serviceLocator<MenuDetailCubit>(),
                ),
                BlocProvider<ProductPlacementsCubit>(
                  create: (_) => serviceLocator<ProductPlacementsCubit>(),
                ),
              ],
              child: MenuDetailScreen(
                menuId: id,
                initialTab: MenuWorkspaceTab.fromQuery(
                  state.uri.queryParameters['tab'],
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuPlacements,
          name: AppRouteNames.menuManagementMenuPlacements,
          redirect: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['menuId']);
            if (id == null) return AppRoutes.menuManagementMenus;
            return MenuManagementRouteLocations.menuWorkspace(
              id,
              tab: MenuWorkspaceTab.products,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuEdit,
          name: AppRouteNames.menuManagementMenuEdit,
          redirect: (_, state) {
            final id = parsePositiveRouteId(state.pathParameters['menuId']);
            return id == null
                ? AppRoutes.menuManagementMenus
                : MenuManagementRouteLocations.menuWorkspace(id);
          },
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
          builder: (context, state) {
            final id = parsePositiveRouteId(
              state.pathParameters['modifierGroupId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<ModifierGroupDetailCubit>(
              create: (_) => serviceLocator<ModifierGroupDetailCubit>(),
              child: ModifierGroupDetailScreen(groupId: id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementModifierEdit,
          name: AppRouteNames.menuManagementModifierEdit,
          builder: (context, state) {
            final id = parsePositiveRouteId(
              state.pathParameters['modifierGroupId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<ModifierGroupEditorCubit>(
              create: (_) => serviceLocator<ModifierGroupEditorCubit>(),
              child: ModifierGroupEditorScreen(groupId: id),
            );
          },
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
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['productId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<ProductEditorCubit>(
              create: (_) => serviceLocator<ProductEditorCubit>(),
              child: ProductEditorScreen(productId: id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductModifiers,
          name: AppRouteNames.menuManagementProductModifiers,
          redirect: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['productId']);
            return id == null
                ? null
                : MenuManagementRouteLocations.productWorkspace(
                    id,
                    tab: ProductWorkspaceTab.modifiers,
                  );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementReview,
          name: AppRouteNames.menuManagementReview,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<MenuReviewCubit>(
                create: (_) => serviceLocator<MenuReviewCubit>(),
              ),
              BlocProvider<PublishedVersionCubit>(
                create: (_) => serviceLocator<PublishedVersionCubit>(),
              ),
            ],
            child: MenuReviewScreen(
              branchId: int.tryParse(
                state.uri.queryParameters['branchId'] ?? '',
              ),
              channel: state.uri.queryParameters['channel'],
              menuId: int.tryParse(state.uri.queryParameters['menuId'] ?? ''),
              evaluationAt: DateTime.tryParse(
                state.uri.queryParameters['at'] ?? '',
              ),
              showVersions: state.uri.queryParameters['tab'] == 'versions',
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementPricing,
          name: AppRouteNames.menuManagementPricing,
          redirect: (_, _) {
            final session = serviceLocator<AuthSessionCubit>().state.session;
            return MenuPricingAccess.canManageRole(session?.user.role)
                ? null
                : AppRoutes.menuManagementProducts;
          },
          builder: (_, _) => BlocProvider<MenuPricingCubit>(
            create: (_) => serviceLocator<MenuPricingCubit>(),
            child: const MenuPricingScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.menuManagementProductVariants,
          name: AppRouteNames.menuManagementProductVariants,
          redirect: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['productId']);
            return id == null
                ? null
                : MenuManagementRouteLocations.productWorkspace(
                    id,
                    tab: ProductWorkspaceTab.variants,
                  );
          },
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
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['productId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ProductDetailCubit>(
                  create: (_) => serviceLocator<ProductDetailCubit>(),
                ),
                BlocProvider<ProductLifecycleCubit>(
                  create: (_) => serviceLocator<ProductLifecycleCubit>(),
                ),
              ],
              child: ProductDetailScreen(
                productId: id,
                tab: ProductWorkspaceTab.fromQuery(
                  state.uri.queryParameters['tab'],
                ),
                variantId: parsePositiveRouteId(
                  state.uri.queryParameters['variantId'],
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.inventory,
          name: AppRouteNames.inventory,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const InventoryDashboardScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryItemCreate,
          builder: (context, state) => BlocProvider<InventoryCubit>(
            create: (_) => serviceLocator<InventoryCubit>(),
            child: const ItemFormScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryItems,
          builder: (context, state) => BlocProvider<InventoryCubit>(
            create: (_) => serviceLocator<InventoryCubit>(),
            child: const InventoryItemsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryItemEdit,
          builder: (context, state) {
            final int? itemId = parsePositiveRouteId(
              state.pathParameters['itemId'],
            );
            if (itemId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
              child: ItemFormScreen(itemId: itemId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.inventoryItemDetail,
          builder: (context, state) {
            final int? itemId = parsePositiveRouteId(
              state.pathParameters['itemId'],
            );
            if (itemId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
              child: InventoryItemDetailsScreen(itemId: itemId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.inventoryBalances,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const InventoryBalancesScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryMovementCreate,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const InventoryMovementCreateScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryMovements,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const InventoryMovementsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryCountDetail,
          builder: (context, state) {
            final int? countId = parsePositiveRouteId(
              state.pathParameters['countId'],
            );
            if (countId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
              child: InventoryCountDetailsScreen(countId: countId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.inventoryCounts,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const InventoryCountsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.inventoryTransferDetail,
          builder: (context, state) {
            final int? transferId = parsePositiveRouteId(
              state.pathParameters['transferId'],
            );
            return BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
              child: InventoryTransfersWorkspaceScreen(transferId: transferId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.inventoryTransfers,
          builder: (context, state) => BlocProvider<InventoryCubit>(
            create: (_) => serviceLocator<InventoryCubit>(),
            child: const InventoryTransfersWorkspaceScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.barCheckTemplateDetail,
          builder: (context, state) {
            final int? templateId = parsePositiveRouteId(
              state.pathParameters['templateId'],
            );
            if (templateId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
              child: BarCheckTemplateEditorScreen(templateId: templateId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.barCheckTemplates,
          builder: (context, state) => BlocProvider<InventoryCubit>(
            create: (_) => serviceLocator<InventoryCubit>(),
            child: const BarCheckTemplatesScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturing,
          name: AppRouteNames.manufacturing,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => BlocProvider<ManufacturingCubit>(
            create: (_) => serviceLocator<ManufacturingCubit>(),
            child: const ManufacturingOverviewScreen(),
          ),
        ),
        GoRoute(
          path: '${AppRoutes.manufacturingPurchases}/new',
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<PurchasingCubit>(
                create: (_) => serviceLocator<PurchasingCubit>(),
              ),
              BlocProvider<FinanceSetupCubit>(
                create: (_) => serviceLocator<FinanceSetupCubit>(),
              ),
            ],
            child: const PurchaseInvoiceFormScreen(
              routeScope: PurchaseRouteScope.manufacturing,
            ),
          ),
        ),
        GoRoute(
          path: '${AppRoutes.manufacturingPurchases}/:purchaseId/edit',
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['purchaseId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: [
                BlocProvider<PurchasingCubit>(
                  create: (_) => serviceLocator<PurchasingCubit>(),
                ),
                BlocProvider<FinanceSetupCubit>(
                  create: (_) => serviceLocator<FinanceSetupCubit>(),
                ),
              ],
              child: PurchaseInvoiceFormScreen(
                editId: id,
                routeScope: PurchaseRouteScope.manufacturing,
              ),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.manufacturingPurchases}/:purchaseId/receive',
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['purchaseId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<PurchasingCubit>(
              create: (_) => serviceLocator<PurchasingCubit>(),
              child: GoodsReceiptFormScreen(purchaseId: id),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.manufacturingPurchaseReceipts}/:receiptId',
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['receiptId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<PurchasingCubit>(
              create: (_) => serviceLocator<PurchasingCubit>(),
              child: GoodsReceiptDetailScreen(receiptId: id),
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.manufacturingPurchases}/:purchaseId',
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['purchaseId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<PurchasingCubit>(
              create: (_) => serviceLocator<PurchasingCubit>(),
              child: PurchaseInvoiceDetailScreen(purchaseId: id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.manufacturingPurchases,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<PurchasingCubit>(
                create: (_) => serviceLocator<PurchasingCubit>(),
              ),
              BlocProvider<FinanceSetupCubit>(
                create: (_) => serviceLocator<FinanceSetupCubit>(),
              ),
            ],
            child: const PurchasingCenterScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingMaterials,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => BlocProvider<InventoryCubit>(
            create: (_) => serviceLocator<InventoryCubit>(),
            child: const ManufacturingMaterialsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingMaterialCreate,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => BlocProvider<InventoryCubit>(
            create: (_) => serviceLocator<InventoryCubit>(),
            child: const ItemFormScreen(scope: ItemRouteScope.manufacturing),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingMaterialEdit,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final int? itemId = parsePositiveRouteId(
              state.pathParameters['itemId'],
            );
            if (itemId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
              child: ItemFormScreen(
                itemId: itemId,
                scope: ItemRouteScope.manufacturing,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.manufacturingMaterialDetail,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final int? itemId = parsePositiveRouteId(
              state.pathParameters['itemId'],
            );
            if (itemId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
              child: InventoryItemDetailsScreen(
                itemId: itemId,
                scope: ItemRouteScope.manufacturing,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.manufacturingStockReceiptCreate,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => BlocProvider<InventoryCubit>(
            create: (_) => serviceLocator<InventoryCubit>(),
            child: const ManufacturingStockReceiptScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingRecipes,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => BlocProvider<ManufacturingRecipeCubit>(
            create: (_) => serviceLocator<ManufacturingRecipeCubit>(),
            child: const ManufacturingRecipesScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingRecipeCreate,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => BlocProvider<ManufacturingRecipeCubit>(
            create: (_) => serviceLocator<ManufacturingRecipeCubit>(),
            child: const ManufacturingRecipeFormScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingRecipeEdit,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final int? recipeId = parsePositiveRouteId(
              state.pathParameters['recipeId'],
            );
            if (recipeId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<ManufacturingRecipeCubit>(
              create: (_) => serviceLocator<ManufacturingRecipeCubit>(),
              child: ManufacturingRecipeFormScreen(recipeId: recipeId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.manufacturingRecipeDetail,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final int? recipeId = parsePositiveRouteId(
              state.pathParameters['recipeId'],
            );
            if (recipeId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<ManufacturingRecipeCubit>(
              create: (_) => serviceLocator<ManufacturingRecipeCubit>(),
              child: ManufacturingRecipeDetailsScreen(recipeId: recipeId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.manufacturingProduction,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ManufacturingProductionCubit>(
                create: (_) => serviceLocator<ManufacturingProductionCubit>(),
              ),
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const ManufacturingProductionHistoryScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingProductionNew,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ManufacturingProductionCubit>(
                create: (_) => serviceLocator<ManufacturingProductionCubit>(),
              ),
              BlocProvider<ManufacturingRecipeCubit>(
                create: (_) => serviceLocator<ManufacturingRecipeCubit>(),
              ),
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const ManufacturingProductionNewScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingProductionNewForRecipe,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final int? recipeId = parsePositiveRouteId(
              state.pathParameters['recipeId'],
            );
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ManufacturingProductionCubit>(
                  create: (_) => serviceLocator<ManufacturingProductionCubit>(),
                ),
                BlocProvider<ManufacturingRecipeCubit>(
                  create: (_) => serviceLocator<ManufacturingRecipeCubit>(),
                ),
                BlocProvider<InventoryCubit>(
                  create: (_) => serviceLocator<InventoryCubit>(),
                ),
              ],
              child: ManufacturingProductionNewScreen(recipeId: recipeId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.manufacturingProductionComplete,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final int? draftId = parsePositiveRouteId(
              state.pathParameters['draftId'],
            );
            if (draftId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<ManufacturingProductionCubit>(
              create: (_) => serviceLocator<ManufacturingProductionCubit>(),
              child: ManufacturingProductionCompleteScreen(draftId: draftId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.manufacturingProductionResult,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) =>
              BlocProvider<ManufacturingProductionCubit>(
                create: (_) => serviceLocator<ManufacturingProductionCubit>(),
                child: ManufacturingProductionResultScreen(
                  idOrReference: state.pathParameters['id'] ?? '',
                ),
              ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingProductionDetail,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) =>
              BlocProvider<ManufacturingProductionCubit>(
                create: (_) => serviceLocator<ManufacturingProductionCubit>(),
                child: ManufacturingProductionDetailsScreen(
                  idOrReference: state.pathParameters['id'] ?? '',
                ),
              ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingConversionCreate,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ManufacturingConversionCubit>(
                create: (_) => serviceLocator<ManufacturingConversionCubit>(),
              ),
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const ManufacturingConversionFormScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingConversionDetail,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) =>
              BlocProvider<ManufacturingConversionCubit>(
                create: (_) => serviceLocator<ManufacturingConversionCubit>(),
                child: ManufacturingConversionDetailsScreen(
                  idOrReference: state.pathParameters['id'] ?? '',
                ),
              ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingReports,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ManufacturingReportsCubit>(
                create: (_) => serviceLocator<ManufacturingReportsCubit>(),
              ),
              BlocProvider<InventoryCubit>(
                create: (_) => serviceLocator<InventoryCubit>(),
              ),
            ],
            child: const ManufacturingReportsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingStockCounts,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) => BlocProvider<InventoryCubit>(
            create: (_) => serviceLocator<InventoryCubit>(),
            child: const InventoryCountsScreen(
              scope: StockCountRouteScope.manufacturing,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.manufacturingStockCountDetail,
          redirect: _manufacturingAccessRedirect,
          builder: (context, state) {
            final int? countId = parsePositiveRouteId(
              state.pathParameters['countId'],
            );
            if (countId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<InventoryCubit>(
              create: (_) => serviceLocator<InventoryCubit>(),
              child: InventoryCountDetailsScreen(
                countId: countId,
                scope: StockCountRouteScope.manufacturing,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.finance,
          name: AppRouteNames.finance,
          redirect: (_, _) => _cashierAccess().isCashier
              ? AppRoutes.financeReceiptVouchers
              : null,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: FinanceOverview.fromRepository(
              serviceLocator<FinanceSetupRepository>(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeReceiptVouchers,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const VouchersScreen(initialType: 'receipt'),
          ),
        ),
        GoRoute(
          path: AppRoutes.financePaymentVouchers,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const VouchersScreen(initialType: 'payment'),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeTransactions,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: FinanceTransactionsView.fromRepository(
              serviceLocator<FinanceSetupRepository>(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeAccountDetail,
          builder: (context, state) {
            final int? accountId = parsePositiveRouteId(
              state.pathParameters['accountId'],
            );
            if (accountId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<FinanceSetupCubit>(
              create: (_) => serviceLocator<FinanceSetupCubit>(),
              child: FinancialAccountsScreen(accountId: accountId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeAccountsCanonical,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const FinancialAccountsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeVouchers,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const VouchersScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeJournalEntryDetail,
          builder: (context, state) {
            final int? entryId = parsePositiveRouteId(
              state.pathParameters['entryId'],
            );
            if (entryId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<FinanceSetupCubit>(
              create: (_) => serviceLocator<FinanceSetupCubit>(),
              child: JournalEntriesScreen(initialEntryId: entryId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeJournalEntriesCanonical,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const JournalEntriesScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeAccountingPeriodDetail,
          builder: (context, state) {
            final int? periodId = parsePositiveRouteId(
              state.pathParameters['periodId'],
            );
            if (periodId == null) return const _InvalidCatalogRouteScreen();
            return FinanceOperationScreen(
              kind: FinanceOperationKind.period,
              id: periodId,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeAccountingPeriods,
          builder: (context, state) =>
              const FinanceOperationScreen(kind: FinanceOperationKind.period),
        ),
        GoRoute(
          path: AppRoutes.financeCashBanks,
          builder: (context, state) => const CashBanksScreen(),
        ),
        GoRoute(
          path: AppRoutes.financePaymentMethods,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const PaymentMethodsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeExpenseCategories,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const ExpenseCategoriesScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeExpenses,
          builder: (context, state) => const ExpensesScreen(),
        ),
        GoRoute(
          path: AppRoutes.financePurchases,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<PurchasingCubit>(
                create: (_) => serviceLocator<PurchasingCubit>(),
              ),
              BlocProvider<FinanceSetupCubit>(
                create: (_) => serviceLocator<FinanceSetupCubit>(),
              ),
            ],
            child: const PurchasingCenterScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeSales,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<SalesCubit>(
                create: (_) => serviceLocator<SalesCubit>(),
              ),
              BlocProvider<FinanceSetupCubit>(
                create: (_) => serviceLocator<FinanceSetupCubit>(),
              ),
            ],
            child: const SalesCenterScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeCustomersReceivables,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<SalesCubit>(
                create: (_) => serviceLocator<SalesCubit>(),
              ),
              BlocProvider<FinanceSetupCubit>(
                create: (_) => serviceLocator<FinanceSetupCubit>(),
              ),
            ],
            child: const CustomerReceivablesScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeSalesNew,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<SalesCubit>(
                create: (_) => serviceLocator<SalesCubit>(),
              ),
              BlocProvider<FinanceSetupCubit>(
                create: (_) => serviceLocator<FinanceSetupCubit>(),
              ),
            ],
            child: const SalesInvoiceFormScreen(),
          ),
        ),
        GoRoute(
          path: '/finance/sales/:salesId/edit',
          builder: (context, state) {
            final int? id = parsePositiveRouteId(
              state.pathParameters['salesId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<SalesCubit>(
                  create: (_) => serviceLocator<SalesCubit>(),
                ),
                BlocProvider<FinanceSetupCubit>(
                  create: (_) => serviceLocator<FinanceSetupCubit>(),
                ),
              ],
              child: SalesInvoiceFormScreen(id: id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeSalesDetail,
          builder: (context, state) {
            final int? id = parsePositiveRouteId(
              state.pathParameters['salesId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<SalesCubit>(
                  create: (_) => serviceLocator<SalesCubit>(),
                ),
                BlocProvider<FinanceSetupCubit>(
                  create: (_) => serviceLocator<FinanceSetupCubit>(),
                ),
              ],
              child: SalesInvoiceDetailScreen(id: id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeSalesCreditNotes,
          builder: (context, state) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<SalesCubit>(
                create: (_) => serviceLocator<SalesCubit>(),
              ),
              BlocProvider<FinanceSetupCubit>(
                create: (_) => serviceLocator<FinanceSetupCubit>(),
              ),
            ],
            child: const SalesCreditNotesScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeSalesCreditNoteNew,
          builder: (context, state) {
            final int? invoiceId = parsePositiveRouteId(
              state.uri.queryParameters['invoiceId'],
            );
            final String customerName =
                state.uri.queryParameters['customerName'] ?? '';
            if (invoiceId == null) return const _InvalidCatalogRouteScreen();
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<SalesCubit>(
                  create: (_) => serviceLocator<SalesCubit>(),
                ),
                BlocProvider<FinanceSetupCubit>(
                  create: (_) => serviceLocator<FinanceSetupCubit>(),
                ),
              ],
              child: CreateCreditNoteScreen(
                invoiceId: invoiceId,
                customerName: customerName,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeSalesCreditNoteDetail,
          builder: (context, state) {
            final int? id = parsePositiveRouteId(
              state.pathParameters['creditNoteId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<SalesCubit>(
                  create: (_) => serviceLocator<SalesCubit>(),
                ),
                BlocProvider<FinanceSetupCubit>(
                  create: (_) => serviceLocator<FinanceSetupCubit>(),
                ),
              ],
              child: SalesCreditNoteDetailScreen(id: id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financePurchasesNew,
          builder: (context, state) {
            final int? supplierId = parsePositiveRouteId(
              state.uri.queryParameters['supplierId'],
            );
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<PurchasingCubit>(
                  create: (_) => serviceLocator<PurchasingCubit>(),
                ),
                BlocProvider<FinanceSetupCubit>(
                  create: (_) => serviceLocator<FinanceSetupCubit>(),
                ),
              ],
              child: PurchaseInvoiceFormScreen(
                preselectedSupplierId: supplierId,
              ),
            );
          },
        ),
        GoRoute(
          path: '/finance/purchases/:purchaseId/edit',
          builder: (context, state) {
            final int? purchaseId = parsePositiveRouteId(
              state.pathParameters['purchaseId'],
            );
            if (purchaseId == null) return const _InvalidCatalogRouteScreen();
            return MultiBlocProvider(
              key: ValueKey(
                serviceLocator<AuthSessionCubit>().state.session?.accessToken,
              ),
              providers: <BlocProvider<dynamic>>[
                BlocProvider<PurchasingCubit>(
                  create: (_) => serviceLocator<PurchasingCubit>(),
                ),
                BlocProvider<FinanceSetupCubit>(
                  create: (_) => serviceLocator<FinanceSetupCubit>(),
                ),
              ],
              child: PurchaseInvoiceFormScreen(editId: purchaseId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financePurchasesDetail,
          builder: (context, state) {
            final int? purchaseId = parsePositiveRouteId(
              state.pathParameters['purchaseId'],
            );
            if (purchaseId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<PurchasingCubit>(
              create: (_) => serviceLocator<PurchasingCubit>(),
              child: PurchaseInvoiceDetailScreen(purchaseId: purchaseId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financePurchasesReceive,
          builder: (context, state) {
            final int? purchaseId = parsePositiveRouteId(
              state.pathParameters['purchaseId'],
            );
            if (purchaseId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<PurchasingCubit>(
              create: (_) => serviceLocator<PurchasingCubit>(),
              child: GoodsReceiptFormScreen(purchaseId: purchaseId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financePurchaseReceiptsDetail,
          builder: (context, state) {
            final int? receiptId = parsePositiveRouteId(
              state.pathParameters['receiptId'],
            );
            if (receiptId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<PurchasingCubit>(
              create: (_) => serviceLocator<PurchasingCubit>(),
              child: GoodsReceiptDetailScreen(receiptId: receiptId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeSuppliersDetail,
          builder: (context, state) {
            final int? supplierId = parsePositiveRouteId(
              state.pathParameters['supplierId'],
            );
            if (supplierId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<FinanceSetupCubit>(
              create: (_) => serviceLocator<FinanceSetupCubit>(),
              child: SupplierProfileScreen(
                supplierId: supplierId,
                openInvoiceId: parsePositiveRouteId(
                  state.uri.queryParameters['openInvoice'],
                ),
                openPaymentId: parsePositiveRouteId(
                  state.uri.queryParameters['openPayment'],
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeSuppliers,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const SuppliersScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeWarehouses,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const WarehousesSetupScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeInvoiceTypes,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const InvoiceTypeCatalogScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeSettings,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const FinanceSetupDashboardScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeReportsCanonical,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: FinancialReportsScreen(
              accountId: parsePositiveRouteId(
                state.uri.queryParameters['accountId'],
              ),
              supplierId: parsePositiveRouteId(
                state.uri.queryParameters['supplierId'],
              ),
              reportType: state.uri.queryParameters['type'],
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeReconciliationDetail,
          builder: (context, state) {
            final int? reconciliationId = parsePositiveRouteId(
              state.pathParameters['reconciliationId'],
            );
            if (reconciliationId == null) {
              return const _InvalidCatalogRouteScreen();
            }
            return BlocProvider<FinanceSetupCubit>(
              create: (_) => serviceLocator<FinanceSetupCubit>(),
              child: ReconciliationWorkspaceScreen(
                reconciliationId: reconciliationId,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeReconciliationCanonical,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const ReconciliationScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.financeDailyClosingDetail,
          builder: (context, state) {
            final int? closingId = parsePositiveRouteId(
              state.pathParameters['closingId'],
            );
            if (closingId == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<FinanceSetupCubit>(
              create: (_) => serviceLocator<FinanceSetupCubit>(),
              child: DailyClosingWorkspaceScreen(closingId: closingId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.financeDailyClosingCanonical,
          builder: (context, state) => BlocProvider<FinanceSetupCubit>(
            create: (_) => serviceLocator<FinanceSetupCubit>(),
            child: const DailyClosingScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.reports,
          name: AppRouteNames.reports,
          builder: (context, state) => BlocProvider<ReportsOverviewCubit>(
            create: (_) => serviceLocator<ReportsOverviewCubit>(),
            child: Builder(
              builder: (context) => DeferredReportLoader(
                load: () {
                  final cubit = context.read<ReportsOverviewCubit>();
                  final branchId = context.read<PosCubit>().state.branchId;
                  return cubit.selectBranch(branchId);
                },
                child: const _BranchFollowingReport(),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.reportsSalesProfitability,
          builder: (context, state) => BlocProvider<SalesProfitabilityCubit>(
            create: (_) => serviceLocator<SalesProfitabilityCubit>(),
            child: Builder(
              builder: (context) => DeferredReportLoader(
                load: () => context.read<SalesProfitabilityCubit>().load(),
                child: SalesProfitabilityScreen(
                  onBack: () => context.go(AppRoutes.reports),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.reportsCashShifts,
          builder: (context, state) => BlocProvider<CashShiftsCubit>(
            create: (_) => serviceLocator<CashShiftsCubit>(),
            child: Builder(
              builder: (context) => DeferredReportLoader(
                load: () => context.read<CashShiftsCubit>().load(),
                child: CashShiftsScreen(
                  onBack: () => context.go(AppRoutes.reports),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.reportsInventory,
          builder: (context, state) => BlocProvider<InventoryReportCubit>(
            create: (_) => serviceLocator<InventoryReportCubit>(),
            child: Builder(
              builder: (context) => DeferredReportLoader(
                load: () => context.read<InventoryReportCubit>().load(),
                child: InventoryReportScreen(
                  onBack: () => context.go(AppRoutes.reports),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.reportsExpenses,
          builder: (context, state) => BlocProvider<ExpensesReportCubit>(
            create: (_) => serviceLocator<ExpensesReportCubit>(),
            child: Builder(
              builder: (context) => DeferredReportLoader(
                load: () => context.read<ExpensesReportCubit>().load(),
                child: ExpensesReportScreen(
                  onBack: () => context.go(AppRoutes.reports),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.discounts,
          name: AppRouteNames.discounts,
          redirect: _discountAdministrationAccessRedirect,
          builder: (context, state) => BlocProvider<DiscountsCubit>(
            create: (_) => serviceLocator<DiscountsCubit>()..loadDiscounts(),
            child: DiscountsListScreen(
              canManageSettings: _canManageDiscountSettings(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.discountSettings,
          name: AppRouteNames.discountSettings,
          redirect: _discountSettingsAccessRedirect,
          builder: (context, state) => BlocProvider(
            create: (_) => serviceLocator<DiscountSettingsCubit>()..load(),
            child: DiscountSettingsScreen(
              header: DiscountsAreaTabs(
                selected: DiscountsArea.settings,
                onSelected: (_) => context.go(AppRoutes.discounts),
              ),
            ),
          ),
        ),
        GoRoute(
          path: ShiftRouteLocations.root,
          redirect: (_, _) => ShiftRouteLocations.current,
        ),
        GoRoute(
          path: ShiftRouteLocations.current,
          name: AppRouteNames.shiftCurrent,
          builder: (context, state) => BlocProvider<ShiftOverviewCubit>(
            create: (_) => serviceLocator<ShiftOverviewCubit>(),
            child: const ShiftOverviewScreen(),
          ),
        ),
        GoRoute(
          path: ShiftRouteLocations.history,
          name: AppRouteNames.shiftHistory,
          builder: (context, state) => BlocProvider<ShiftHistoryCubit>(
            create: (_) => serviceLocator<ShiftHistoryCubit>(),
            child: const ShiftHistoryScreen(),
          ),
        ),
        GoRoute(
          path: ShiftRouteLocations.closing,
          name: AppRouteNames.shiftClosing,
          builder: (context, state) => BlocProvider<ShiftClosingCubit>(
            create: (_) => serviceLocator<ShiftClosingCubit>(),
            child: const ShiftClosingScreen(),
          ),
        ),
        GoRoute(
          path: ShiftRouteLocations.reportPattern,
          name: AppRouteNames.shiftReport,
          builder: (context, state) => BlocProvider<ShiftReportCubit>(
            create: (_) => serviceLocator<ShiftReportCubit>(),
            child: ShiftReportScreen(
              shiftNumber: state.pathParameters['shiftNumber']!,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: AppRouteNames.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.cafeConfiguration,
          redirect: (_, _) => AppRoutes.cafeConfigurationOverview,
        ),
        GoRoute(
          path: AppRoutes.cafeConfigurationOverview,
          name: AppRouteNames.cafeConfigurationOverview,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) =>
              BlocProvider<CafeConfigurationOverviewCubit>(
                create: (_) =>
                    serviceLocator<CafeConfigurationOverviewCubit>()..load(),
                child: const CafeConfigurationOverviewScreen(),
              ),
        ),
        GoRoute(
          path: AppRoutes.cafeConfigurationProfile,
          name: AppRouteNames.cafeConfigurationProfile,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) => BlocProvider<CafeProfileCubit>(
            create: (_) => serviceLocator<CafeProfileCubit>()..load(),
            child: const CafeProfileScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.cafeConfigurationBranches,
          name: AppRouteNames.cafeConfigurationBranches,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) => BlocProvider<CafeBranchesCubit>(
            create: (_) => serviceLocator<CafeBranchesCubit>()..load(),
            child: const BranchesScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.cafeConfigurationPrinting,
          name: AppRouteNames.cafeConfigurationPrinting,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) => BlocProvider<PrintingCubit>(
            create: (context) => serviceLocator<PrintingCubit>()
              ..load(
                preferredBranchId: context
                    .read<OperationalBranchCubit>()
                    .state
                    .selectedBranchId,
              ),
            child: const PrintingScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.cafeConfigurationTeam,
          name: AppRouteNames.cafeConfigurationTeam,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) => BlocProvider<TeamCubit>(
            create: (_) => serviceLocator<TeamCubit>()..load(),
            child: const TeamAccessScreen(),
          ),
        ),
        // Same Cafe Discount Policy screen as Discounts → Settings, kept inside
        // Cafe Configuration so its navigation does not switch modules.
        GoRoute(
          path: AppRoutes.cafeConfigurationDiscountSettings,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) => BlocProvider(
            create: (_) => serviceLocator<DiscountSettingsCubit>()..load(),
            child: const DiscountSettingsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.cafeConfigurationTax,
          name: AppRouteNames.cafeConfigurationTax,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) => BlocProvider<TaxCubit>(
            create: (_) => serviceLocator<TaxCubit>()..load(),
            child: const TaxScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.cafeConfigurationBranchCreate,
          name: AppRouteNames.cafeConfigurationBranchCreate,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) => BlocProvider<BranchEditorCubit>(
            create: (_) => serviceLocator<BranchEditorCubit>()..initialize(),
            child: const BranchEditorScreen(isEdit: false),
          ),
        ),
        GoRoute(
          path: AppRoutes.cafeConfigurationBranchEdit,
          name: AppRouteNames.cafeConfigurationBranchEdit,
          redirect: _cafeConfigurationAccessRedirect,
          builder: (context, state) {
            final int? id = parsePositiveRouteId(
              state.pathParameters['branchId'],
            );
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<BranchEditorCubit>(
              create: (_) => BranchEditorCubit(
                serviceLocator<CafeConfigurationRepository>(),
                branchId: id,
              )..initialize(),
              child: const BranchEditorScreen(isEdit: true),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.pos,
          name: AppRouteNames.pos,
          builder: (context, state) => const PosScreen(),
        ),
        GoRoute(
          path: AppRoutes.dashboard,
          name: AppRouteNames.dashboard,
          builder: (context, state) => BlocProvider<CashierDashboardCubit>(
            create: (_) => serviceLocator<CashierDashboardCubit>(),
            child: const CashierDashboardScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.cashierInventory,
          name: AppRouteNames.cashierInventory,
          builder: (context, state) => BlocProvider<CashierInventoryCubit>(
            create: (_) => serviceLocator<CashierInventoryCubit>(),
            child: CashierInventoryScreen(
              initialState: state.uri.queryParameters['state'],
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.orders,
          name: AppRouteNames.orders,
          builder: (context, state) => BlocProvider<OrdersCubit>(
            create: (_) => serviceLocator<OrdersCubit>()
              ..loadOrders(branchId: context.read<PosCubit>().state.branchId),
            child: const _BranchFollowingOrders(),
          ),
        ),
        GoRoute(
          path: AppRoutes.discountCreate,
          name: AppRouteNames.discountCreate,
          redirect: _discountAdministrationAccessRedirect,
          builder: (context, state) => BlocProvider<DiscountsCubit>(
            create: (_) => serviceLocator<DiscountsCubit>()..loadDiscounts(),
            child: CreateDiscountPolicyScreen(
              initialDiscount: state.extra as DiscountListItem?,
            ),
          ),
        ),
      ],
    ),
  ],
);

/// Orders exist only while their route is visible, but they must immediately
/// follow the session POS branch if the cashier changes it from the shell.
class _BranchFollowingOrders extends StatelessWidget {
  const _BranchFollowingOrders();

  @override
  Widget build(BuildContext context) => BlocListener<PosCubit, PosState>(
    listenWhen: (PosState previous, PosState current) =>
        previous.branchId != current.branchId,
    listener: (BuildContext context, PosState state) {
      context.read<OrdersCubit>().applyBranchContext(state.branchId);
    },
    child: const OrdersScreen(),
  );
}

/// Reports begin in the shared POS branch context and stay synchronized when
/// that global context changes; the overview retains its own branch filter.
class _BranchFollowingReport extends StatefulWidget {
  const _BranchFollowingReport();

  @override
  State<_BranchFollowingReport> createState() => _BranchFollowingReportState();
}

class _BranchFollowingReportState extends State<_BranchFollowingReport> {
  @override
  void initState() {
    super.initState();
    final PosCubit pos = context.read<PosCubit>();
    context.read<DailyReportCubit>().loadReport(branchId: pos.state.branchId);
  }

  @override
  Widget build(BuildContext context) => BlocListener<PosCubit, PosState>(
    listenWhen: (PosState previous, PosState current) =>
        previous.branchId != current.branchId,
    listener: (BuildContext context, PosState state) {
      context.read<ReportsOverviewCubit>().selectBranch(state.branchId);
    },
    child: ReportsOverviewScreen(
      onOpenSalesProfitability: () =>
          context.go(AppRoutes.reportsSalesProfitability),
      onOpenCashShifts: () => context.go(AppRoutes.reportsCashShifts),
      onOpenInventory: () => context.go(AppRoutes.reportsInventory),
      onOpenExpenses: () => context.go(AppRoutes.reportsExpenses),
      onOpenFinancialReports: () =>
          context.go(AppRoutes.financeReportsCanonical),
    ),
  );
}

Widget? _rightPanelFor(GoRouterState state) {
  return switch (state.matchedLocation) {
    AppRoutes.pos => const PosCartPanel(),
    _ => null,
  };
}

String _financeActiveTabFor(String path) {
  if (path == AppRoutes.finance) return 'overview';
  if (path == AppRoutes.financeReceiptVouchers) return 'receipt-vouchers';
  if (path == AppRoutes.financePaymentVouchers) return 'payment-vouchers';
  if (path.startsWith(AppRoutes.financeTransactions)) return 'transactions';
  if (path.startsWith(AppRoutes.financeCashBanks)) return 'cashbanks';
  if (path.startsWith(AppRoutes.financeExpenseCategories)) return 'settings';
  if (path.startsWith(AppRoutes.financeExpenses)) return 'expenses';
  if (path.startsWith(AppRoutes.financePurchases)) return 'purchases';
  if (path.startsWith(AppRoutes.financeSales) ||
      path.startsWith(AppRoutes.financeCustomersReceivables)) {
    return 'sales';
  }
  if (path.startsWith(AppRoutes.financePurchaseReceipts)) return 'purchases';
  if (path.startsWith(AppRoutes.financeSuppliers)) return 'suppliers';
  if (path.startsWith(AppRoutes.financeReconciliationCanonical)) {
    return 'reconciliation';
  }
  if (path.startsWith(AppRoutes.financeJournalEntriesCanonical)) {
    return 'journals';
  }
  if (path.startsWith(AppRoutes.financeVouchers)) return 'vouchers';
  if (path.startsWith(AppRoutes.financeDailyClosingCanonical)) {
    return 'closing';
  }
  if (path.startsWith(AppRoutes.financeReportsCanonical)) return 'reports';
  if (path.startsWith(AppRoutes.financeAccountsCanonical)) return 'accounts';
  if (path.startsWith(AppRoutes.financeAccountingPeriods)) return 'periods';
  if (path.startsWith(AppRoutes.financePaymentMethods)) return 'settings';
  if (path.startsWith(AppRoutes.financeWarehouses)) return 'settings';
  if (path.startsWith(AppRoutes.financeSettings)) return 'settings';
  return 'overview';
}

String _inventoryActiveTabFor(String path) {
  if (path.startsWith(AppRoutes.inventoryItems)) return 'items';
  if (path.startsWith(AppRoutes.inventoryBalances)) return 'balances';
  if (path.startsWith(AppRoutes.inventoryMovements)) return 'movements';
  if (path.startsWith(AppRoutes.inventoryCounts)) return 'counts';
  if (path.startsWith(AppRoutes.inventoryTransfers)) return 'transfers';
  if (path.startsWith(AppRoutes.barCheckTemplates)) return 'barChecks';
  return 'overview';
}

String _manufacturingActiveTabFor(String path) {
  if (path.startsWith(AppRoutes.manufacturingMaterials) ||
      path.startsWith('/manufacturing/stock-receipts')) {
    return 'materials';
  }
  if (path.startsWith(AppRoutes.manufacturingRecipes)) return 'recipes';
  if (path.startsWith(AppRoutes.manufacturingProduction) ||
      path.startsWith('/manufacturing/conversions')) {
    return 'production';
  }
  if (path.startsWith(AppRoutes.manufacturingReports)) return 'reports';
  if (path.startsWith(AppRoutes.manufacturingStockCounts)) return 'stockCounts';
  return 'overview';
}

// The default AppTopBar (branch tabs, ShiftStatusBadge, language,
// notifications, profile) is the one shell chrome shared by every module —
// Inventory, Finance, Reports, and Menu Management all render the exact
// same bar via AppShell's own `topBar ?? AppTopBar(...)` default. Only Cafe
// Configuration (branch-independent, its own settings context) opts out.
Widget? _topBarFor(BuildContext context, GoRouterState state) {
  if (state.uri.path.startsWith(AppRoutes.cafeConfiguration)) {
    return AppTopBar(
      showOperationalBranchTabs: false,
      contextTitle: AppLocalizations.of(context).cafeConfigurationTitle,
    );
  }
  // The Manufacturing context (Phase 2): no shift badge (the factory has no
  // shift concept), and branch tabs are sourced from the operational
  // (factory) branch, never from PosCubit. This applies to every route while
  // isFactoryUser — not only /manufacturing/* — since a factory_manager can
  // still reach shared Finance screens.
  final bool isFactoryUser =
      serviceLocator<AuthSessionCubit>().state.session?.user.isFactoryUser ??
      false;
  if (state.uri.path.startsWith(AppRoutes.manufacturing) || isFactoryUser) {
    return const AppTopBar(
      showShiftStatus: false,
      branchSource: AppTopBarBranchSource.operationalFactory,
      contextTitle: 'المعمل',
    );
  }
  return null;
}

Future<void> Function(BuildContext context)? _refreshActionFor(
  GoRouterState state,
) => refreshActionForMatchedLocation(state.matchedLocation);

@visibleForTesting
Future<void> Function(BuildContext context)? refreshActionForMatchedLocation(
  String matchedLocation,
) {
  return switch (matchedLocation) {
    AppRoutes.pos => (BuildContext context) {
      final PosState pos = context.read<PosCubit>().state;
      return context.read<PosMenuSyncCubit>().sync(
        pos.branchId,
        hasActiveCart: pos.hasCartItems || pos.currentOrderId != null,
      );
    },
    AppRoutes.dashboard =>
      (BuildContext context) => context.read<CashierDashboardCubit>().refresh(),
    AppRoutes.cashierInventory =>
      (BuildContext context) => context.read<CashierInventoryCubit>().load(),
    AppRoutes.orders =>
      (BuildContext context) => context.read<OrdersCubit>().refreshOrders(),
    AppRoutes.reports =>
      (BuildContext context) =>
          context.read<ReportsOverviewCubit>().load(force: true),
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

String _activeDestinationFor(GoRouterState state) {
  if (state.uri.path.startsWith(CustomerManagementRouteLocations.customers)) {
    return 'customers';
  }
  if (state.uri.path.startsWith(AppRoutes.cafeConfiguration)) {
    return 'cafeConfiguration';
  }
  if (state.uri.path.startsWith(AppRoutes.inventory)) {
    return 'inventory';
  }
  if (state.uri.path.startsWith(AppRoutes.manufacturing)) {
    return state.uri.path.startsWith(AppRoutes.manufacturingPurchases)
        ? 'purchases'
        : 'manufacturing';
  }
  if (state.uri.path.startsWith(AppRoutes.finance)) {
    final branchState = serviceLocator.isRegistered<OperationalBranchCubit>()
        ? serviceLocator<OperationalBranchCubit>().state
        : null;
    final factoryUser =
        serviceLocator.isRegistered<AuthSessionCubit>() &&
        (serviceLocator<AuthSessionCubit>().state.session?.user.isFactoryUser ??
            false);
    final factoryBranch =
        branchState?.branches.any(
          (branch) =>
              branch.id == branchState.selectedBranchId && branch.isFactory,
        ) ??
        false;
    if (factoryUser || factoryBranch) {
      if (state.uri.path.startsWith(AppRoutes.financeSales)) {
        return 'sales';
      }
      if (state.uri.path.startsWith(AppRoutes.financePurchases)) {
        return 'purchases';
      }
      if (state.uri.path.startsWith(AppRoutes.financeSuppliers)) {
        return 'suppliers';
      }
    }
    return 'finance';
  }
  if (state.uri.path.startsWith(AppRoutes.menuManagement)) {
    return 'menuManagement';
  }
  if (state.uri.path.startsWith(AppRoutes.cashierInventory)) {
    return 'inventory';
  }
  if (ShiftRouteLocations.isShiftLocation(state.uri.path)) {
    return 'shift';
  }
  return switch (state.matchedLocation) {
    AppRoutes.dashboard => 'dashboard',
    AppRoutes.discounts ||
    AppRoutes.discountCreate ||
    AppRoutes.discountSettings => 'discounts',
    AppRoutes.orders => 'orders',
    _ when state.uri.path.startsWith(AppRoutes.reports) => 'reports',
    AppRoutes.settings => 'settings',
    _ => 'pos',
  };
}

abstract final class AppRoutes {
  static const String pos = '/';

  /// The Cashier's operational home. Every other role keeps its existing
  /// landing, so this adds a surface rather than replacing one.
  static const String dashboard = '/dashboard';

  /// Cashier-safe operational stock. Deliberately outside `/inventory`, which
  /// remains the full Inventory Center for Owner/Admin/Inventory Manager.
  static const String cashierInventory = '/cashier-inventory';
  static const String orders = '/orders';
  static const String reports = '/reports';
  static const String reportsSalesProfitability =
      '/reports/sales-profitability';
  static const String reportsCashShifts = '/reports/cash-shifts';
  static const String reportsInventory = '/reports/inventory';
  static const String reportsExpenses = '/reports/expenses';
  static const String discounts = '/discounts';
  static const String discountCreate = '/discounts/create';
  static const String discountSettings = '/discounts/settings';
  static const String shift = ShiftRouteLocations.root;
  static const String shiftCurrent = ShiftRouteLocations.current;
  static const String shiftHistory = ShiftRouteLocations.history;
  static const String shiftClosing = ShiftRouteLocations.closing;
  static const String settings = '/settings';
  static const String cafeConfiguration = '/cafe-configuration';
  static const String cafeConfigurationOverview =
      '/cafe-configuration/overview';
  static const String cafeConfigurationProfile = '/cafe-configuration/profile';
  static const String cafeConfigurationBranches =
      '/cafe-configuration/branches';
  static const String cafeConfigurationPrinting =
      '/cafe-configuration/printing';
  static const String cafeConfigurationTeam = '/cafe-configuration/team';
  static const String cafeConfigurationTax = '/cafe-configuration/tax';
  static const String cafeConfigurationDiscountSettings =
      '/cafe-configuration/discount-settings';
  static const String cafeConfigurationBranchCreate =
      '/cafe-configuration/branches/new';
  static const String cafeConfigurationBranchEdit =
      '/cafe-configuration/branches/:branchId/edit';
  static const String inventory = '/inventory';

  static const String manufacturing = '/manufacturing';
  static const String manufacturingPurchases = '/manufacturing/purchases';
  static const String manufacturingPurchaseReceipts =
      '/manufacturing/purchase-receipts';
  static const String manufacturingMaterials = '/manufacturing/materials';
  static const String manufacturingMaterialCreate =
      '/manufacturing/materials/new';
  static const String manufacturingMaterialDetail =
      '/manufacturing/materials/:itemId';
  static const String manufacturingMaterialEdit =
      '/manufacturing/materials/:itemId/edit';
  static const String manufacturingStockReceiptCreate =
      '/manufacturing/stock-receipts/new';
  static const String manufacturingRecipes = '/manufacturing/recipes';
  static const String manufacturingRecipeCreate = '/manufacturing/recipes/new';
  static const String manufacturingRecipeDetail =
      '/manufacturing/recipes/:recipeId';
  static const String manufacturingRecipeEdit =
      '/manufacturing/recipes/:recipeId/edit';
  static const String manufacturingProduction = '/manufacturing/production';
  static const String manufacturingProductionNew =
      '/manufacturing/production/new';
  static const String manufacturingProductionNewForRecipe =
      '/manufacturing/production/new/:recipeId';
  static const String manufacturingProductionComplete =
      '/manufacturing/production/complete/:draftId';
  static const String manufacturingProductionResult =
      '/manufacturing/production/result/:id';
  static const String manufacturingProductionDetail =
      '/manufacturing/production/:id';
  static const String manufacturingConversionCreate =
      '/manufacturing/conversions/new';
  static const String manufacturingConversionDetail =
      '/manufacturing/conversions/:id';
  static const String manufacturingReports = '/manufacturing/reports';
  static const String manufacturingStockCounts = '/manufacturing/stock-counts';
  static const String manufacturingStockCountDetail =
      '/manufacturing/stock-counts/:countId';
  static String manufacturingStockCountDetailPath(int countId) =>
      '/manufacturing/stock-counts/$countId';
  static const String finance = '/finance';
  static const String financeReceiptVouchers = '/finance/receipt-vouchers';
  static const String financePaymentVouchers = '/finance/payment-vouchers';
  static const String menuManagement = '/menu-management';
  static const String menuManagementProducts = '/menu-management/products';
  static const String menuManagementModifiers = '/menu-management/modifiers';
  static const String menuManagementMenus = '/menu-management/menus';
  static const String menuManagementAssignments =
      '/menu-management/assignments';
  static const String menuManagementReview = '/menu-management/review';
  static const String menuManagementPricing = '/menu-management/pricing';
  static const String menuManagementCatalogSetup =
      '/menu-management/catalog-setup';
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
  static const String menuManagementModifierRecipeAdjustments =
      '/menu-management/modifier-options/:optionId/recipe-adjustments';
  static const String menuManagementProductModifierRecipeAdjustments =
      '/menu-management/products/:productId/modifier-options/:optionId/recipe-adjustments';
  static const String menuManagementVariantModifierRecipeAdjustments =
      '/menu-management/product-variants/:variantId/modifier-options/:optionId/recipe-adjustments';
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
  static const String menuManagementVariantRecipe =
      '/menu-management/product-variants/:variantId/recipe';
  static const String menuManagementRecipeSimulation =
      '/menu-management/products/:productId/variants/:variantId/recipe-simulation';
  static const String menuManagementProductRecipeEditor =
      '/menu-management/products/:productId/variants/:variantId/recipe/edit';
  static const String menuManagementProductRecipeTest =
      '/menu-management/products/:productId/variants/:variantId/recipe/test';
  static const String menuManagementProductMaterialEffect =
      '/menu-management/products/:productId/modifier-options/:optionId/material-effect';
  static const String menuManagementVariantMaterialEffect =
      '/menu-management/products/:productId/variants/:variantId/modifier-options/:optionId/material-effect';
  static const String menuManagementGlobalMaterialEffect =
      '/menu-management/modifiers/:modifierGroupId/options/:optionId/material-effect';
  static const String menuManagementProductModifiers =
      '/menu-management/products/:productId/modifiers';
  static const String menuManagementProductAvailability =
      '/menu-management/products/:productId/availability';
  static const String menuManagementProductOperationalAvailability =
      '/menu-management/products/:productId/operational-availability';

  static const String inventoryItems = '/inventory/items';
  static const String inventoryItemCreate = '/inventory/items/create';
  static const String inventoryItemDetail = '/inventory/items/:itemId';
  static const String inventoryItemEdit = '/inventory/items/:itemId/edit';
  static const String inventoryBalances = '/inventory/balances';
  static const String inventoryMovements = '/inventory/movements';
  static const String inventoryMovementCreate = '/inventory/movements/create';
  static const String inventoryCounts = '/inventory/counts';
  static const String inventoryCountDetail = '/inventory/counts/:countId';
  static const String inventoryTransfers = '/inventory/transfers';
  static const String inventoryTransferDetail =
      '/inventory/transfers/:transferId';
  static const String barCheckTemplates = '/inventory/bar-check-templates';
  static const String barCheckTemplateDetail =
      '/inventory/bar-check-templates/:templateId';

  static String manufacturingMaterialDetailPath(int itemId) =>
      '/manufacturing/materials/$itemId';
  static String manufacturingMaterialEditPath(int itemId) =>
      '/manufacturing/materials/$itemId/edit';
  static String manufacturingRecipeDetailPath(int recipeId) =>
      '/manufacturing/recipes/$recipeId';
  static String manufacturingRecipeEditPath(int recipeId) =>
      '/manufacturing/recipes/$recipeId/edit';
  static String manufacturingProductionNewForRecipePath(int recipeId) =>
      '/manufacturing/production/new/$recipeId';
  static String manufacturingProductionCompletePath(int draftId) =>
      '/manufacturing/production/complete/$draftId';
  static String manufacturingProductionResultPath(String id) =>
      '/manufacturing/production/result/$id';
  static String manufacturingProductionDetailPath(String id) =>
      '/manufacturing/production/$id';
  static String manufacturingConversionDetailPath(String id) =>
      '/manufacturing/conversions/$id';

  static String inventoryItemDetailPath(int itemId) =>
      '/inventory/items/$itemId';
  static String inventoryItemEditPath(int itemId) =>
      '/inventory/items/$itemId/edit';
  static String inventoryCountDetailPath(int countId) =>
      '/inventory/counts/$countId';
  static String inventoryTransferPath(int transferId) =>
      '/inventory/transfers/$transferId';
  static String barCheckTemplatePath(int templateId) =>
      '/inventory/bar-check-templates/$templateId';
  static String financeAccountDetailPath(int accountId) =>
      '/finance/accounts/$accountId';
  static String financeJournalEntryDetailPath(int entryId) =>
      '/finance/journal-entries/$entryId';
  static String financeAccountingPeriodDetailPath(int periodId) =>
      '/finance/accounting-periods/$periodId';

  static const String financeTransactions = '/finance/transactions';
  static const String financeVouchers = '/finance/vouchers';
  static const String financeAccountsCanonical = '/finance/accounts';
  static const String financeAccountDetail = '/finance/accounts/:accountId';
  static const String financeJournalEntriesCanonical =
      '/finance/journal-entries';
  static const String financeJournalEntryDetail =
      '/finance/journal-entries/:entryId';
  static const String financeAccountingPeriods = '/finance/accounting-periods';
  static const String financeAccountingPeriodDetail =
      '/finance/accounting-periods/:periodId';
  static const String financeCashBanks = '/finance/cash-banks';
  static const String financePaymentMethods = '/finance/payment-methods';
  static const String financeExpenses = '/finance/expenses';
  static const String financeExpenseCategories = '/finance/expense-categories';
  static const String financeInvoiceTypes = '/finance/invoice-types';
  static const String financePurchases = '/finance/purchases';
  static const String financeSales = '/finance/sales';
  static const String financeSalesNew = '/finance/sales/new';
  static const String financeSalesDetail = '/finance/sales/:salesId';
  static const String financeCustomersReceivables =
      '/finance/customers-receivables';
  static const String financeSalesCreditNotes = '/finance/sales/credit-notes';
  static const String financeSalesCreditNoteNew =
      '/finance/sales/credit-notes/new';
  static const String financeSalesCreditNoteDetail =
      '/finance/sales/credit-notes/:creditNoteId';
  static const String financePurchasesNew = '/finance/purchases/new';
  static const String financePurchasesDetail = '/finance/purchases/:purchaseId';
  static const String financePurchasesReceive =
      '/finance/purchases/:purchaseId/receive';
  static const String financePurchaseReceipts = '/finance/purchase-receipts';
  static const String financePurchaseReceiptsDetail =
      '/finance/purchase-receipts/:receiptId';
  static const String financeSuppliers = '/finance/suppliers';
  static const String financeSuppliersDetail = '/finance/suppliers/:supplierId';
  static const String financeWarehouses = '/finance/warehouses';
  static const String financeSettings = '/finance/settings';
  static const String financeReportsCanonical = '/finance/reports';
  static const String financeReconciliationCanonical =
      '/finance/reconciliation';
  static const String financeReconciliationDetail =
      '/finance/reconciliation/:reconciliationId';
  static const String financeDailyClosingCanonical = '/finance/daily-closing';
  static const String financeDailyClosingDetail =
      '/finance/daily-closing/:closingId';
}

abstract final class AppRouteNames {
  static const String pos = 'pos';
  static const String dashboard = 'dashboard';
  static const String cashierInventory = 'cashier-inventory';
  static const String orders = 'orders';
  static const String reports = 'reports';
  static const String discounts = 'discounts';
  static const String discountCreate = 'discount-create';
  static const String discountSettings = 'discount-settings';
  static const String shiftCurrent = 'shift-current';
  static const String shiftHistory = 'shift-history';
  static const String shiftClosing = 'shift-closing';
  static const String shiftReport = 'shift-report';
  static const String settings = 'settings';
  static const String cafeConfigurationOverview = 'cafe-configuration-overview';
  static const String cafeConfigurationProfile = 'cafe-configuration-profile';
  static const String cafeConfigurationBranches = 'cafe-configuration-branches';
  static const String cafeConfigurationPrinting = 'cafe-configuration-printing';
  static const String cafeConfigurationTeam = 'cafe-configuration-team';
  static const String cafeConfigurationTax = 'cafe-configuration-tax';
  static const String cafeConfigurationBranchCreate =
      'cafe-configuration-branch-create';
  static const String cafeConfigurationBranchEdit =
      'cafe-configuration-branch-edit';
  static const String inventory = 'inventory';
  static const String manufacturing = 'manufacturing';
  static const String finance = 'finance';
  static const String menuManagementProducts = 'menu-management-products';
  static const String menuManagementModifiers = 'menu-management-modifiers';
  static const String menuManagementMenus = 'menu-management-menus';
  static const String menuManagementAssignments = 'menu-management-assignments';
  static const String menuManagementReview = 'menu-management-review';
  static const String menuManagementPricing = 'menu-management-pricing';
  static const String menuManagementCatalogSetup =
      'menu-management-catalog-setup';
  static const String menuManagementMenuCreate = 'menu-management-menu-create';
  static const String menuManagementMenuDetail = 'menu-management-menu-detail';
  static const String menuManagementMenuEdit = 'menu-management-menu-edit';
  static const String menuManagementMenuPlacements =
      'menu-management-menu-placements';
  static const String menuManagementModifierCreate =
      'menu-management-modifier-create';
  static const String menuManagementModifierDetail =
      'menu-management-modifier-detail';
  static const String menuManagementModifierRecipeAdjustments =
      'menu-management-modifier-recipe-adjustments';
  static const String menuManagementProductModifierRecipeAdjustments =
      'menu-management-product-modifier-recipe-adjustments';
  static const String menuManagementVariantModifierRecipeAdjustments =
      'menu-management-variant-modifier-recipe-adjustments';
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
  static const String menuManagementVariantRecipe =
      'menu-management-variant-recipe';
  static const String menuManagementRecipeSimulation =
      'menu-management-recipe-simulation';
  static const String menuManagementProductRecipeEditor =
      'menu-management-product-recipe-editor';
  static const String menuManagementProductRecipeTest =
      'menu-management-product-recipe-test';
  static const String menuManagementProductMaterialEffect =
      'menu-management-product-material-effect';
  static const String menuManagementVariantMaterialEffect =
      'menu-management-variant-material-effect';
  static const String menuManagementGlobalMaterialEffect =
      'menu-management-global-material-effect';
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
      Center(child: Text(AppLocalizations.of(context).invalidCatalogRoute));
}

int? parsePositiveRouteId(String? value) {
  final int? parsed = int.tryParse(value ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

void _returnToRecipeWorkspace(
  BuildContext context,
  int productId,
  int variantId,
) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(
    MenuManagementRouteLocations.productWorkspace(
      productId,
      tab: ProductWorkspaceTab.recipe,
      variantId: variantId,
    ),
  );
}

/// Manufacturing access is capability-driven, mirroring how Finance screens
/// key off `financeCapabilities` rather than a role check: the backend is the
/// source of truth (`ManufacturingAccess`), and grants `manufacturing.view`
/// only to Owner and to a `factory_manager` who actually has a factory branch
/// assigned. A cafe user who fails this check goes to POS; a factory user
/// (`isFactoryUser`) never does — the cafe's POS/shift/discount surface is
/// blocked for them at the backend (see `EnsureCafeOperationalAccess`), so
/// bouncing them there would just trade one 403 for another.
String? _manufacturingAccessRedirect(BuildContext _, GoRouterState _) {
  final user = serviceLocator<AuthSessionCubit>().state.session?.user;
  if (user != null &&
      user.manufacturingCapabilities.contains('manufacturing.view')) {
    return null;
  }

  return (user?.isFactoryUser ?? false) ? AppRoutes.settings : AppRoutes.pos;
}

String? _cafeConfigurationAccessRedirect(BuildContext _, GoRouterState state) {
  final role = serviceLocator<AuthSessionCubit>().state.session?.user.role;
  if (role == 'owner') return null;
  if (role == 'manager' &&
      (state.uri.path.startsWith(AppRoutes.cafeConfigurationPrinting) ||
          state.uri.path == AppRoutes.cafeConfigurationDiscountSettings)) {
    return null;
  }

  return AppRoutes.pos;
}

/// Cafe Discount Policy: Owner, or a Manager (the settings endpoint enforces
/// the `discounts.settings.manage` grant). Everyone else goes to POS.
bool _canManageDiscountSettings() => const <String>{
  'owner',
  'manager',
}.contains(serviceLocator<AuthSessionCubit>().state.session?.user.role);

String? _discountSettingsAccessRedirect(BuildContext _, GoRouterState _) =>
    _canManageDiscountSettings() ? null : AppRoutes.pos;

/// Discount administration (list, create/edit, settings) is Owner/Manager only.
/// Cashiers apply discounts inside the POS; they never see this area. This is a
/// usability boundary only: the backend rejects every administrative request
/// from an Employee regardless of this redirect.
String? _discountAdministrationAccessRedirect(
  BuildContext _,
  GoRouterState _,
) => _canManageDiscountSettings() ? null : AppRoutes.pos;

String? _customerManagementAccessRedirect(BuildContext _, GoRouterState _) =>
    CustomerManagementAccess.allows(
      serviceLocator<AuthSessionCubit>().state.session,
    )
    ? null
    : AppRoutes.pos;
