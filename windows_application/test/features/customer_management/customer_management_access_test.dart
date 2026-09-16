import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/customer_management/models/customer_management_access.dart';

void main() {
  test('access is only the server-authoritative session capability', () {
    final AuthSession employeeWithCapability = AuthSession(
      accessToken: 'token',
      user: const AuthUser(id: 1, name: 'Employee', role: 'employee'),
      tenant: const AuthTenant(id: 1, name: 'Cafe'),
      mustChangePassword: false,
      lastValidatedAt: DateTime.utc(2026),
      offlineSessionMaxAgeSeconds: 60,
      customerManagementAllowed: true,
    );
    expect(CustomerManagementAccess.allows(null), isFalse);
    expect(CustomerManagementAccess.allows(employeeWithCapability), isTrue);
  });

  test('role names cannot grant Customer Management without capability', () {
    final AuthSession ownerWithoutCapability = AuthSession(
      accessToken: 'token',
      user: const AuthUser(id: 2, name: 'Owner', role: 'owner'),
      tenant: const AuthTenant(id: 1, name: 'Cafe'),
      mustChangePassword: false,
      lastValidatedAt: DateTime.utc(2026),
      offlineSessionMaxAgeSeconds: 60,
      customerManagementAllowed: false,
    );

    expect(CustomerManagementAccess.allows(ownerWithoutCapability), isFalse);
  });
}
