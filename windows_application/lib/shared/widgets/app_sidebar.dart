import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/navigation/unsaved_navigation_guard.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import 'app_sidebar_item.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.activeLabel,
    this.isCollapsed = false,
  });

  final String activeLabel;
  final bool isCollapsed;

  static const List<_SidebarDestination> _destinations = <_SidebarDestination>[
    _SidebarDestination('dashboard', Icons.dashboard_outlined),
    _SidebarDestination('pos', Icons.point_of_sale_outlined, '/'),
    _SidebarDestination('orders', Icons.receipt_long_outlined, '/orders'),
    _SidebarDestination('customers', Icons.groups_outlined),
    _SidebarDestination('discounts', Icons.local_offer_outlined, '/discounts'),
    _SidebarDestination(
      'menuManagement',
      Icons.restaurant_menu_outlined,
      '/menu-management/products',
    ),
    _SidebarDestination('inventory', Icons.inventory_2_outlined),
    _SidebarDestination('reports', Icons.bar_chart_outlined, '/reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCollapsed ? AppSizes.sidebarRailWidth : AppSizes.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
        border: BorderDirectional(
          end: BorderSide(color: AppColors.shellBorder),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          isCollapsed ? AppSpacing.sm : AppSpacing.lg,
          AppSpacing.xxl,
          isCollapsed ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.xxl,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool pinSettings =
                constraints.maxHeight >=
                AppSizes.sidebarPinnedSettingsMinHeight;

            return Column(
              crossAxisAlignment: isCollapsed
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: <Widget>[
                _LogoBlock(isCollapsed: isCollapsed),
                const SizedBox(height: AppSpacing.xxxl),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      for (final _SidebarDestination destination
                          in _destinations)
                        AppSidebarItem(
                          icon: destination.icon,
                          label: _labelFor(context, destination.id),
                          isActive:
                              destination.id == activeLabel ||
                              _englishLabel(destination.id) == activeLabel,
                          isCollapsed: isCollapsed,
                          onTap: destination.routePath == null
                              ? null
                              : () => context.guardedGo(destination.routePath!),
                        ),
                      if (!pinSettings)
                        AppSidebarItem(
                          icon: Icons.settings_outlined,
                          label: _settingsLabel(context),
                          isCollapsed: isCollapsed,
                        ),
                    ],
                  ),
                ),
                if (pinSettings)
                  AppSidebarItem(
                    icon: Icons.settings_outlined,
                    label: _settingsLabel(context),
                    isCollapsed: isCollapsed,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock({required this.isCollapsed});

  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final Widget mark = Container(
      width: AppSizes.logoMarkSize,
      height: AppSizes.logoMarkSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.tertiary,
        borderRadius: AppRadius.control,
      ),
      child: Text(
        'C',
        style: AppTextStyles.titleMedium.copyWith(color: AppColors.textInverse),
      ),
    );

    if (isCollapsed) {
      return Center(child: mark);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        mark,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _appName(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _operationalHub(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _labelFor(BuildContext context, String id) {
  final AppLocalizations? l10n = Localizations.of<AppLocalizations>(
    context,
    AppLocalizations,
  );
  if (l10n == null) return _englishLabel(id);
  return switch (id) {
    'dashboard' => l10n.navigationDashboard,
    'pos' => l10n.navigationPos,
    'orders' => l10n.navigationOrders,
    'customers' => l10n.navigationCustomers,
    'discounts' => l10n.navigationDiscounts,
    'menuManagement' => l10n.navigationMenuManagement,
    'inventory' => l10n.navigationInventory,
    'reports' => l10n.navigationReports,
    _ => l10n.commonUnknown,
  };
}

String _settingsLabel(BuildContext context) =>
    Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    )?.navigationSettings ??
    'Settings';

String _appName(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations)?.appName ??
    AppConstants.appName;

String _operationalHub(BuildContext context) =>
    Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    )?.operationalHub ??
    'OPERATIONAL HUB';

String _englishLabel(String id) => switch (id) {
  'dashboard' => 'Dashboard',
  'pos' => 'POS',
  'orders' => 'Orders',
  'customers' => 'Customers',
  'discounts' => 'Discounts',
  'menuManagement' => 'Menu Management',
  'inventory' => 'Inventory',
  'reports' => 'Reports',
  _ => '',
};

class _SidebarDestination {
  const _SidebarDestination(this.id, this.icon, [this.routePath]);

  final String id;
  final IconData icon;
  final String? routePath;
}
