import '../../auth/models/auth_session.dart';

/// A UX projection only. Every backend request remains the authorization gate.
class CustomerManagementAccess {
  const CustomerManagementAccess._();

  static bool allows(AuthSession? session) =>
      session?.customerManagementAllowed == true;
}
