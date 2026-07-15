import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../controllers/menu_cubit.dart';
import '../controllers/menu_state.dart';
import '../models/menu_kpis.dart';
import '../widgets/menu_activity_table.dart';
import '../widgets/menu_filter_bar.dart';
import '../widgets/menu_kpi_card.dart';
import '../widgets/menu_tabs.dart';

class MenuOverviewScreen extends StatelessWidget {
  const MenuOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuCubit, MenuState>(
      builder: (BuildContext context, MenuState state) {
        if (state.loadingStatus == MenuLoadingStatus.initial ||
            state.loadingStatus == MenuLoadingStatus.loading) {
          return const DesktopPageLayout(child: AppLoading());
        }

        if (state.loadingStatus == MenuLoadingStatus.failure) {
          return DesktopPageLayout(
            child: AppEmptyState(
              message: state.errorMessage ?? 'Could not load menu data.',
              icon: Icons.restaurant_menu_outlined,
            ),
          );
        }

        final MenuKpis kpis = state.kpis!;

        return DesktopPageLayout(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: AppSpacing.allXxl,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.menuContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _MenuActions(),
                  const SizedBox(height: AppSpacing.xl),
                  _KpiGrid(kpis: kpis),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _MenuToolbar(
                          selectedTab: state.selectedMenuTab,
                          onTabSelected: (MenuTab tab) =>
                              _selectTab(context, tab),
                        ),
                        MenuActivityTable(activities: state.recentActivities),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectTab(BuildContext context, MenuTab tab) {
    context.read<MenuCubit>().changeTab(tab);
    final String location = switch (tab) {
      MenuTab.overview => AppRoutes.menu,
      MenuTab.products => AppRoutes.menuProducts,
      MenuTab.categories => AppRoutes.menuCategories,
      MenuTab.modifiers => AppRoutes.menuModifiers,
      MenuTab.combos => AppRoutes.menuCombos,
    };
    context.go(location);
  }
}

class _MenuActions extends StatelessWidget {
  const _MenuActions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        AppButton(
          label: 'Add Product',
          icon: Icons.add,
          onPressed: () => context.go(AppRoutes.menuProductCreate),
        ),
        AppButton(
          label: 'Add Category',
          icon: Icons.category_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go(AppRoutes.menuCategories),
        ),
        AppButton(
          label: 'Add Modifier Group',
          icon: Icons.tune,
          variant: AppButtonVariant.outlined,
          onPressed: () => context.go(AppRoutes.menuModifiers),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final MenuKpis kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.md;
        final int columns =
            ((constraints.maxWidth + gap) / (AppSizes.menuKpiMinWidth + gap))
                .floor()
                .clamp(1, 5);
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            SizedBox(
              width: width,
              child: MenuKpiCard(
                label: 'Total Categories',
                value: kpis.totalCategories,
                icon: Icons.folder_outlined,
              ),
            ),
            SizedBox(
              width: width,
              child: MenuKpiCard(
                label: 'Total Products',
                value: kpis.totalProducts,
                icon: Icons.inventory_2_outlined,
              ),
            ),
            SizedBox(
              width: width,
              child: MenuKpiCard(
                label: 'Active Products',
                value: kpis.activeProducts,
                icon: Icons.check_circle_outline,
                iconColor: AppColors.menuAppliedText,
              ),
            ),
            SizedBox(
              width: width,
              child: MenuKpiCard(
                label: 'Inactive Products',
                value: kpis.inactiveProducts,
                icon: Icons.cancel_outlined,
                iconColor: AppColors.menuInactiveIcon,
              ),
            ),
            SizedBox(
              width: width,
              child: MenuKpiCard(
                label: 'Modifier Groups',
                value: kpis.modifierGroups,
                icon: Icons.tune,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuToolbar extends StatelessWidget {
  const _MenuToolbar({required this.selectedTab, required this.onTabSelected});

  final MenuTab selectedTab;
  final ValueChanged<MenuTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: const BoxDecoration(
        color: AppColors.menuToolbarBackground,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget tabs = MenuTabs(
            selectedTab: selectedTab,
            onSelected: onTabSelected,
          );
          const Widget filters = MenuFilterBar(
            labels: <String>['All Categories', 'All Statuses', 'All Branches'],
          );

          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            children: <Widget>[tabs, filters],
          );
        },
      ),
    );
  }
}
