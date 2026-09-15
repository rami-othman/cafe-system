/// Centralized cashier restriction boundary. This is a UX projection only —
/// every backend request remains the real authorization gate (see
/// InventoryAccess/BarCheckAccess on the API). Both legacy role spellings
/// ('employee' and 'cashier') resolve to the same canonical cashier role.
class CashierAccess {
  const CashierAccess._();

  static bool isCashier(String? role) =>
      role == 'employee' || role == 'cashier';

  /// Sidebar module ids the cashier role may see. Every other role keeps its
  /// existing (unrestricted-by-this-check) behavior.
  static bool allowsModule(String moduleId, String? role) {
    if (!isCashier(role)) return true;
    return _allowedModuleIds.contains(moduleId);
  }

  /// Route-level guard used by the router's top-level redirect. Paths outside
  /// the cashier's allowed surface (POS, Orders, Customers, Discounts, their
  /// own shift-close/bar-check flow, and personal Settings) are rejected.
  static bool allowsPath(String path, String? role) {
    if (!isCashier(role)) return true;
    if (_allowedExactPaths.contains(path)) return true;
    return _allowedPathPrefixes.any(
      (String prefix) => path == prefix || path.startsWith('$prefix/'),
    );
  }

  static const Set<String> _allowedModuleIds = <String>{
    'pos',
    'orders',
    'customers',
    'discounts',
  };

  static const Set<String> _allowedExactPaths = <String>{'/', '/settings'};

  static const List<String> _allowedPathPrefixes = <String>[
    '/orders',
    '/discounts',
    '/customers',
    '/shift-close',
  ];
}
