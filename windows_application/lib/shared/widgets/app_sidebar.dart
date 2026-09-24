import 'package:flutter/material.dart';
import '../../core/branding/app_brand.dart';
import '../../core/branding/brand_header.dart';
import '../../core/navigation/unsaved_navigation_guard.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../features/shift/widgets/shift_strings.dart';
import '../access/cashier_access.dart';
import 'app_sidebar_item.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.activeLabel,
    this.isCollapsed = false,
    this.width,
    this.actorRole,
    this.canManageCustomers = false,
    this.financeCapabilities = const <String>{},
    this.brandIdentity,
  });

  final String activeLabel;
  final bool isCollapsed;
  final double? width;
  final String? actorRole;
  final bool canManageCustomers;
  final Set<String> financeCapabilities;
  final BrandIdentity? brandIdentity;

  /// The Cashier's navigation: the operational home, the till, and the
  /// Cashier-safe views of Finance and Inventory. "Inventory" here lands on the
  /// operational stock view, never the full Inventory Center, and "Finance"
  /// lands on the vouchers workspace, never the Finance overview.
  static const List<_SidebarDestination> _cashierDestinations =
      <_SidebarDestination>[
        _SidebarDestination(
          'dashboard',
          Icons.dashboard_outlined,
          CashierRoutes.dashboard,
          'cashierHome',
        ),
        _SidebarDestination(
          'pos',
          Icons.point_of_sale_outlined,
          CashierRoutes.pos,
        ),
        _SidebarDestination(
          'orders',
          Icons.receipt_long_outlined,
          CashierRoutes.orders,
        ),
        _SidebarDestination(
          'discounts',
          Icons.local_offer_outlined,
          CashierRoutes.discounts,
        ),
        _SidebarDestination(
          'finance',
          Icons.account_balance_wallet_outlined,
          CashierRoutes.financeVouchers,
        ),
        _SidebarDestination(
          'inventory',
          Icons.inventory_2_outlined,
          CashierRoutes.cashierInventory,
        ),
        _SidebarDestination('shift', Icons.schedule_outlined, '/shift/current'),
      ];

  static const List<_SidebarDestination> _destinations = <_SidebarDestination>[
    _SidebarDestination('dashboard', Icons.dashboard_outlined),
    _SidebarDestination('pos', Icons.point_of_sale_outlined, '/'),
    _SidebarDestination('orders', Icons.receipt_long_outlined, '/orders'),
    _SidebarDestination('customers', Icons.groups_outlined, '/customers'),
    _SidebarDestination('discounts', Icons.local_offer_outlined, '/discounts'),
    _SidebarDestination('shift', Icons.schedule_outlined, '/shift/current'),
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
    final bool isCashier = CashierAccess.isCashierRole(actorRole);
    final bool canOpenFinance = financeCapabilities.any(
      CashierAccess.financeWorkspacePermissions.contains,
    );
    final bool canOpenCafeConfiguration =
        actorRole == 'owner' || actorRole == 'manager';
    final Iterable<_SidebarDestination> destinations = isCashier
        ? _cashierDestinations.where(
            (_SidebarDestination destination) =>
                destination.id != 'finance' || canOpenFinance,
          )
        : _destinations
              .where(
                (destination) =>
                    (destination.id != 'menuManagement' ||
                        _canTemporarilyManageMenus(actorRole)) &&
                    (destination.id != 'customers' || canManageCustomers) &&
                    (destination.id != 'cafeConfiguration' ||
                        canOpenCafeConfiguration),
              )
              .map(
                // A Manager only has access to the Printing sub-page (see
                // _cafeConfigurationAccessRedirect), so the entry point
                // takes them there directly instead of the Owner default.
                (destination) =>
                    destination.id == 'cafeConfiguration' &&
                        actorRole == 'manager'
                    ? _SidebarDestination(
                        destination.id,
                        destination.icon,
                        '/cafe-configuration/printing',
                        destination.labelId,
                      )
                    : destination,
              );
    return Container(
      width:
          width ??
          (isCollapsed ? AppSizes.sidebarRailWidth : AppSizes.sidebarWidth),
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
                          label: _labelFor(context, destination.labelId),
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
  // The Shift module ships its own Arabic copy (see ShiftStrings) rather
  // than through AppLocalizations, matching the l10n-lite pattern already
  // used by Finance/Inventory. It renders identically regardless of app
  // locale until the module gets full bilingual support.
  if (id == 'shift') return ShiftStrings.module;
  if (l10n == null) return _englishLabel(id);
  return switch (id) {
    'cashierHome' => l10n.cashierHomeTitle,
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
  'cashierHome' => 'Home',
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
  'shift' => 'Shift',
  _ => '',
};

class _SidebarDestination {
  const _SidebarDestination(
    this.id,
    this.icon, [
    this.routePath,
    String? labelId,
  ]) : labelId = labelId ?? id;

  final String id;
  final IconData icon;
  final String? routePath;

  /// Lets a destination keep its `id` (which drives active-state matching)
  /// while showing a different label, as the Cashier's home does.
  final String labelId;
}
