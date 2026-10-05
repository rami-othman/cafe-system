import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/customer_management/models/customer_management_access.dart';

void main() {
  test(
    'preserves owner and granted-manager customer capability through storage',
    () {
      for (final String role in <String>['owner', 'manager']) {
        final AuthSession session = AuthSession.fromApi(
          _session(role: role, canManage: true),
        );
        expect(CustomerManagementAccess.allows(session), isTrue);
        expect(
          AuthSession.fromStorage(
            'opaque-token',
            session.toStorageJson(),
          ).customerManagementAllowed,
          isTrue,
        );
      }
    },
  );

  test(
    'fails closed for ungranted managers, employees, and legacy metadata',
    () {
      expect(
        CustomerManagementAccess.allows(
          AuthSession.fromApi(_session(role: 'manager', canManage: false)),
        ),
        isFalse,
      );
      expect(
        CustomerManagementAccess.allows(
          AuthSession.fromApi(_session(role: 'employee', canManage: false)),
        ),
        isFalse,
      );
      final Map<String, dynamic> legacy = AuthSession.fromApi(
        _session(role: 'manager', canManage: true),
      ).toStorageJson()..remove('capabilities');
      expect(
        AuthSession.fromStorage(
          'opaque-token',
          legacy,
        ).customerManagementAllowed,
        isFalse,
      );
    },
  );

  test('uses refreshed server capability after permission revocation', () {
    final AuthSession granted = AuthSession.fromApi(
      _session(role: 'manager', canManage: true),
    );
    final AuthSession revoked = AuthSession.fromApi(
      _session(role: 'manager', canManage: false),
    );
    expect(CustomerManagementAccess.allows(granted), isTrue);
    expect(CustomerManagementAccess.allows(revoked), isFalse);
  });
}

Map<String, dynamic> _session({
  required String role,
  required bool canManage,
}) => <String, dynamic>{
  'accessToken': 'opaque-token',
  'user': <String, dynamic>{'id': 1, 'name': role, 'role': role},
  'tenant': <String, dynamic>{'id': 1, 'name': 'Cafe'},
  'mustChangePassword': false,
  'session': <String, dynamic>{
    'lastValidatedAt': '2026-09-10T00:00:00Z',
    'offlineSessionMaxAgeSeconds': 3600,
  },
  'capabilities': <String, dynamic>{
    'customer': <String, dynamic>{'manage': canManage},
  },
};
