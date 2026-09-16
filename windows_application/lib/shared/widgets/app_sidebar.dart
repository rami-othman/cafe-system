import 'package:flutter/material.dart';
import '../../core/branding/app_brand.dart';
import '../../core/branding/brand_header.dart';
import '../../core/navigation/unsaved_navigation_guard.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../access/cashier_access.dart';
import 'app_sidebar_item.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.activeLabel,
    this.isCollapsed = false,
    this.actorRole,
    this.canManageCustomers = false,
    this.brandIdentity,
  });

  final String activeLabel;
  final bool isCollapsed;
  final String? actorRole;
  final bool canManageCustomers;
  final BrandIdentity? brandIdentity;

  static const List<_SidebarDestination> _destinations = <_SidebarDestination>[
    _SidebarDestination('dashboard', Icons.dashboard_outlined),
    _SidebarDestination('pos', Icons.point_of_sale_outlined, '/'),
    _SidebarDestination('orders', Icons.receipt_long_outlined, '/orders'),
    _SidebarDestination('customers', Icons.groups_outlined, '/customers'),
    _SidebarDestination('discounts', Icons.local_offer_outlined, '/discounts'),
    _SidebarDestination(
      'menuManagement',
      Icons.restaurant_menu_outlined,
      '/menu-management/products',
    ),
    _SidebarDestination(
      'cafeConfiguration',
      Icons.tune_outlined,
      '/cafe-configuration/overview',
    ),
    _SidebarDestination('inventory', Icons.inventory_2_outlined, '/inventory'),
    _SidebarDestination(
      'finance',
      Icons.account_balance_wallet_outlined,
      '/finance',
    ),
    _SidebarDestination('reports', Icons.bar_chart_outlined, '/reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final Iterable<_SidebarDestination> destinations = _destinations.where(
      (destination) =>
          (destination.id != 'menuManagement' ||
              _canTemporarilyManageMenus(actorRole)) &&
          (destination.id != 'customers' || canManageCustomers) &&
          (destination.id != 'cafeConfiguration' || actorRole == 'owner') &&
          CashierAccess.allowsModule(destination.id, actorRole),
    );
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
                _LogoBlock(
                  isCollapsed: isCollapsed,
                  identity:
                      brandIdentity ??
                      BrandIdentity(
                        displayName: _appName(context),
                        subtitle: _operationalHub(context),
                        windowTitle: _appName(context),
                        isCashier: false,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      for (final _SidebarDestination destination
                          in destinations)
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
                          isActive: activeLabel == 'settings',
                          onTap: () => context.guardedGo('/settings'),
                        ),
                    ],
                  ),
                ),
                if (pinSettings)
                  AppSidebarItem(
                    icon: Icons.settings_outlined,
                    label: _settingsLabel(context),
                    isCollapsed: isCollapsed,
                    isActive: activeLabel == 'settings',
                    onTap: () => context.guardedGo('/settings'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Transitional visibility rule paired with the backend's
/// TemporaryMenuManagementPolicy. This is intentionally role-based until the
/// final Permission Catalog replaces it.
bool _canTemporarilyManageMenus(String? role) =>
    role == 'owner' || role == 'manager' || role == null;

class _LogoBlock extends StatelessWidget {
  const _LogoBlock({required this.isCollapsed, required this.identity});

  final bool isCollapsed;
  final BrandIdentity identity;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Center(child: BrandHeader(identity: identity, compact: true));
    }
    return BrandHeader(identity: identity);
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
    'cafeConfiguration' => l10n.navigationCafeConfiguration,
    'inventory' => l10n.navigationInventory,
    'finance' => l10n.navigationFinance,
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
    AppBrand.systemNameEn;

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
  'cafeConfiguration' => 'Cafe Configuration',
  'inventory' => 'Inventory',
  'finance' => 'Finance',
  'reports' => 'Reports',
  _ => '',
};

class _SidebarDestination {
  const _SidebarDestination(this.id, this.icon, [this.routePath]);

  final String id;
  final IconData icon;
  final String? routePath;
}
