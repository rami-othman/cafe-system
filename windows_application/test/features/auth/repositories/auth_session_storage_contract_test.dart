import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';

void main() {
  final AuthSession session = AuthSession(
    accessToken: 'test-token',
    user: AuthUser(id: 3, name: 'Cashier', role: 'employee'),
    tenant: AuthTenant(id: 4, name: 'Staging Cafe'),
    mustChangePassword: false,
    lastValidatedAt: DateTime.utc(2026, 9, 1, 10),
    offlineSessionMaxAgeSeconds: 43200,
  );

  test(
    'browser-compatible session contract persists reads and clears',
    () async {
      final MemoryAuthSessionStorage storage = MemoryAuthSessionStorage();

      await storage.write(session);
      expect((await storage.read())?.accessToken, session.accessToken);
      expect((await storage.read())?.tenant.id, 4);

      await storage.clear();
      expect(await storage.read(), isNull);
    },
  );

  test('stored metadata preserves the twelve-hour offline window', () {
    final AuthSession restored = AuthSession.fromStorage(
      session.accessToken,
      session.toStorageJson(),
    );

    expect(
      restored.canRestoreOffline(DateTime.utc(2026, 9, 1, 21, 59)),
      isTrue,
    );
    expect(
      restored.canRestoreOffline(DateTime.utc(2026, 9, 1, 22, 1)),
      isFalse,
    );
  });
}
