/// Single client-side boundary for Menu Pricing V1.  The server remains the
/// authority; this only avoids exposing a destination/actions to known roles.
abstract final class MenuPricingAccess {
  static bool canManageRole(String? role) {
    final String normalized = role?.trim().toLowerCase() ?? '';
    return normalized == 'owner' || normalized == 'manager';
  }
}
