import '../../features/auth/models/auth_session.dart';
import '../../shared/access/cashier_access.dart';
import '../../features/pos/models/branch.dart';

class BrandIdentity {
  const BrandIdentity({
    required this.displayName,
    required this.subtitle,
    required this.windowTitle,
    required this.isCashier,
  });

  final String displayName;
  final String subtitle;
  final String windowTitle;
  final bool isCashier;
}

abstract final class AppBrand {
  static const String productName = 'Cafe 618';
  static const String systemNameAr = 'نظام كافيه 618';
  static const String systemNameEn = 'Cafe System 618';
  static const String logoFullLight =
      'assets/branding/cafe618_logo_full_light.png';
  static const String logoFullDark =
      'assets/branding/cafe618_logo_full_dark.png';
  static const String logoMarkLight =
      'assets/branding/cafe618_logo_mark_light.png';
  static const String logoMarkDark =
      'assets/branding/cafe618_logo_mark_dark.png';

  /// Delegates to the one Cashier projection. Comparing against a single
  /// literal here missed the `employee` role code the authentication API
  /// actually returns, so the branding never switched for a real till login.
  static bool isCashier(AuthUser? user) =>
      CashierAccess.isCashierRole(user?.role);

  static BrandIdentity resolve({
    required AuthUser? user,
    required List<Branch> branches,
    required int? activeBranchId,
    required String localizedSystemName,
    required String localizedOperationalHub,
    required String localizedPos,
  }) {
    final bool cashier = isCashier(user);
    final String? branchName = cashier
        ? _activeBranchName(branches, activeBranchId)
        : null;
    final String displayName = branchName ?? localizedSystemName;

    return BrandIdentity(
      displayName: displayName,
      subtitle: cashier ? localizedPos : localizedOperationalHub,
      windowTitle: branchName == null
          ? localizedSystemName
          : '$branchName - $productName',
      isCashier: cashier,
    );
  }

  static String? _activeBranchName(List<Branch> branches, int? activeBranchId) {
    if (activeBranchId == null) return null;
    for (final Branch branch in branches) {
      if (branch.id == activeBranchId && branch.isActive) {
        final String name = branch.name.trim();
        return name.isEmpty ? null : name;
      }
    }
    return null;
  }
}
