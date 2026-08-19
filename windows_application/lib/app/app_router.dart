import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'menu_management_route_locations.dart';

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
import '../features/menu_management/recipes/views/variant_recipe_screen.dart';
import '../features/menu_management/recipes/views/modifier_adjustment_screen.dart';
import '../features/menu_management/recipes/views/recipe_simulation_screen.dart';
import '../features/menu_management/recipes/controllers/recipe_cubits.dart';
import '../features/menu_management/repositories/menu_catalog_repository.dart';
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
import '../features/menu_management/catalog_setup/controllers/catalog_setup_cubit.dart';
import '../features/menu_management/catalog_setup/models/catalog_setup_models.dart';
import '../features/menu_management/catalog_setup/views/catalog_setup_screen.dart';
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
import '../features/menu_management/versions/controllers/published_version_cubit.dart';
import '../features/menu_management/widgets/menu_module_navigation.dart';
import '../features/menu_management/widgets/menu_module_scaffold.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../shared/widgets/app_top_bar.dart';
import 'app_shell.dart';

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

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.pos,
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        final bool isMenuManagement = state.uri.path.startsWith(
          AppRoutes.menuManagement,
        );
        final AppShell shell = AppShell(
          activeLabel: _activeDestinationFor(state),
          rightPanel: _rightPanelFor(state),
          topBar: _topBarFor(state),
          onRefresh: _refreshActionFor(state),
          prioritizeContentWidth: isMenuManagement,
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
              : child,
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
            BlocProvider<ModifierLibraryCubit>(
              create: (_) => serviceLocator<ModifierLibraryCubit>(),
            ),
            BlocProvider<MenuListCubit>(
              create: (_) => serviceLocator<MenuListCubit>(),
            ),
          ],
          child: shell,
        );
      },
      routes: <RouteBase>[
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
          builder: (context, state) => const ProductCatalogScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuManagementModifiers,
          name: AppRouteNames.menuManagementModifiers,
          builder: (context, state) => const ModifierLibraryScreen(),
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenus,
          name: AppRouteNames.menuManagementMenus,
          builder: (context, state) => const MenuListScreen(),
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
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['menuId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<MenuDetailCubit>(
              create: (_) => serviceLocator<MenuDetailCubit>(),
              child: MenuDetailScreen(menuId: id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuPlacements,
          name: AppRouteNames.menuManagementMenuPlacements,
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['menuId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<ProductPlacementsCubit>(
              create: (_) => serviceLocator<ProductPlacementsCubit>(),
              child: ProductPlacementsScreen(menuId: id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.menuManagementMenuEdit,
          name: AppRouteNames.menuManagementMenuEdit,
          builder: (context, state) {
            final id = parsePositiveRouteId(state.pathParameters['menuId']);
            if (id == null) return const _InvalidCatalogRouteScreen();
            return BlocProvider<MenuEditorCubit>(
              create: (_) => serviceLocator<MenuEditorCubit>(),
              child: MenuEditorScreen(menuId: id),
            );
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
            return BlocProvider<ProductDetailCubit>(
              create: (_) => serviceLocator<ProductDetailCubit>(),
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

Widget? _topBarFor(GoRouterState state) {
  if (!state.uri.path.startsWith(AppRoutes.menuManagement)) return null;
  return AppTopBar(
    showOperationalBranchTabs: false,
    onRefresh: _refreshActionFor(state),
  );
}

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

String _activeDestinationFor(GoRouterState state) {
  if (state.uri.path.startsWith(AppRoutes.menuManagement)) {
    return 'menuManagement';
  }
  return switch (state.matchedLocation) {
    AppRoutes.discounts || AppRoutes.discountCreate => 'discounts',
    AppRoutes.orders => 'orders',
    AppRoutes.reports => 'reports',
    _ => 'pos',
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
