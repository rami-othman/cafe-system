import '../../features/auth/models/auth_session.dart';

/// The one place that answers "what may a Cashier reach?".
///
/// Every Cashier-sensitive decision in the client — the landing route, the
/// sidebar, the dashboard's quick-access tiles, and the router's deep-link
/// guard — reads this projection, so a widget never grows its own
/// `role == 'cashier'` check that can drift from the rest.
///
/// This is a usability boundary, not a security one. The backend enforces the
/// real one: `cashier.permission` middleware plus the existing branch, tenant,
/// finance, and inventory policies. Hiding a tile here never grants anything.
class CashierAccess {
  const CashierAccess._(
    this.role,
    this.financePermissions,
    this.customerManagementAllowed,
  );

  /// [financePermissions] mirrors the `finance.capabilities` the dashboard
  /// endpoint reports for this actor; empty until the first load, which keeps
  /// finance tiles hidden rather than optimistically shown.
  ///
  /// [customerManagementAllowed] mirrors the session's manager-granted
  /// `customerManagementAllowed` capability: a Cashier who additionally holds
  /// it keeps `/customers` reachable, same as an ungranted Owner/Manager.
  factory CashierAccess.of(
    AuthUser? user, {
    Set<String> financePermissions = const <String>{},
    bool customerManagementAllowed = false,
  }) => CashierAccess._(
    user?.role,
    financePermissions.isEmpty
        ? user?.financeCapabilities ?? const <String>{}
        : financePermissions,
    customerManagementAllowed,
  );

  final String? role;
  final Set<String> financePermissions;
  final bool customerManagementAllowed;

  /// The tenant role code the authentication API actually returns for a
  /// till operator (`User::effectiveRoleCode()`).
  static const String employeeRole = 'employee';

  /// The legacy code the same role is mapped to by
  /// DefaultTenantRoleService::canonicalLegacyRole, which parts of the client
  /// and older stored sessions still carry. Both mean the same person, so both
  /// resolve here rather than in each call site.
  static const String cashierRole = 'cashier';

  static const Set<String> cashierRoles = <String>{employeeRole, cashierRole};

  static bool isCashierRole(String? role) => cashierRoles.contains(role);

  bool get isCashier => isCashierRole(role);

  CashierAccess withFinancePermissions(Set<String> permissions) =>
      CashierAccess._(role, permissions, customerManagementAllowed);

  /// Routes a Cashier may open, including by typing a deep link. Anything
  /// outside this set resolves to [homeRoute].
  ///
  /// Deliberately absent: the Finance and Inventory module landing pages and
  /// every administrative screen under them (accounts, journals, reports,
  /// reconciliation, daily closing, periods, settings, warehouses, transfers,
  /// counts, movements, item editing), plus Reports, Menu Management, and Cafe
  /// Configuration. The Shift module (`/shift/*`) is a Cashier route — see
  /// [allowsPath] — since it is the Cashier's own till.
  static const Set<String> _cashierExactRoutes = <String>{
    CashierRoutes.dashboard,
    CashierRoutes.pos,
    CashierRoutes.orders,
    CashierRoutes.discounts,
    CashierRoutes.cashierInventory,
    CashierRoutes.settings,
  };

  /// Finance workspaces a Cashier may use, each still gated by the matching
  /// backend finance permission before its tile is rendered.
  static const Map<String, String> financeRoutePermissions = <String, String>{
    CashierRoutes.financeVouchers: 'finance.vouchers.view',
    CashierRoutes.financePurchases: 'finance.purchases.view',
    CashierRoutes.financeSales: 'finance.sales.view',
  };

  static const Set<String> financeWorkspacePermissions = <String>{
    'finance.vouchers.view',
    'finance.purchases.view',
    'finance.sales.view',
  };

  bool allowsPath(String path) {
    if (!isCashier) return true;
    if (_cashierExactRoutes.contains(path)) return true;

    // The Shift module is the Cashier's own till: opening/closing their
    // shift, its history, and its closing report are all in-scope, so the
    // whole `/shift/*` subtree is reachable rather than one exact route.
    if (_isWithin(path, CashierRoutes.shift)) return true;

    // Customer management is manager-granted, same as for an Owner/Manager
    // who lacks the capability — see `CustomerManagementAccess`.
    if (customerManagementAllowed && _isWithin(path, CashierRoutes.customers)) {
      return true;
    }

    // Finance is a capability-driven surface. A Cashier cannot use an
    // ungranted workspace by pasting its path, even though the backend remains
    // the final enforcement boundary.
    return financeRoutePermissions.entries.any(
      (MapEntry<String, String> entry) =>
          _isWithin(path, entry.key) && allowsFinancePermission(entry.value),
    );
  }

  /// A Cashier's home is the operational dashboard; every other role keeps the
  /// application's existing POS landing, unchanged.
  String get homeRoute =>
      isCashier ? CashierRoutes.dashboard : CashierRoutes.pos;

  /// `null` means "no redirect needed", matching GoRouter's redirect contract.
  String? redirectFor(String path) => allowsPath(path) ? null : homeRoute;

  bool allowsFinanceCapability(String capability) =>
      financePermissions.contains(capability);

  bool allowsFinancePermission(String permission) =>
      financePermissions.contains(permission);

  bool get hasFinanceWorkspace =>
      financePermissions.any(financeWorkspacePermissions.contains);

  static bool _isWithin(String path, String root) =>
      path == root || path.startsWith('$root/');
}

/// Route paths the Cashier surface refers to. These mirror `AppRoutes` but live
/// here so this projection stays importable by widgets and tests without
/// pulling in the whole router graph.
abstract final class CashierRoutes {
  static const String pos = '/';
  static const String dashboard = '/dashboard';
  static const String orders = '/orders';
  static const String discounts = '/discounts';
  static const String settings = '/settings';
  static const String cashierInventory = '/cashier-inventory';
  static const String shift = '/shift';
  static const String customers = '/customers';
  static const String financeVouchers = '/finance/vouchers';
  static const String financePurchases = '/finance/purchases';
  static const String financeSales = '/finance/sales';
}
