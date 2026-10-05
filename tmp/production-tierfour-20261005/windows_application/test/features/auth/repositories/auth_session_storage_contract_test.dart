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
    expiresAt: DateTime.utc(2026, 10, 1),
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

  test('authoritative invalidation blocks reuse until a new login writes', () async {
    final MemoryAuthSessionStorage storage = MemoryAuthSessionStorage(session);

    await storage.markAuthoritativelyInvalidated();
    expect(await storage.isAuthoritativelyInvalidated(), isTrue);
    expect((await storage.read())?.accessToken, session.accessToken);

    await storage.write(session);
    expect(await storage.isAuthoritativelyInvalidated(), isFalse);
  });

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

  test('stored sessions require a real boolean mustChangePassword', () {
    for (final dynamic value in <dynamic>[null, 'false', 0]) {
      final Map<String, dynamic> metadata = session.toStorageJson()
        ..['mustChangePassword'] = value;

      expect(
        () => AuthSession.fromStorage(session.accessToken, metadata),
        throwsA(isA<AuthSessionStorageCorruptException>()),
      );
    }

    final Map<String, dynamic> missing = session.toStorageJson()
      ..remove('mustChangePassword');
    expect(
      () => AuthSession.fromStorage(session.accessToken, missing),
      throwsA(isA<AuthSessionStorageCorruptException>()),
    );
  });

  test('stored sessions require a valid absolute future expiry', () {
    for (final dynamic value in <dynamic>[
      null,
      'not-a-timestamp',
      '2026-10-01T00:00:00',
      123,
    ]) {
      final Map<String, dynamic> metadata = session.toStorageJson()
        ..['expiresAt'] = value;

      expect(
        () => AuthSession.fromStorage(session.accessToken, metadata),
        throwsA(isA<AuthSessionStorageCorruptException>()),
      );
    }

    final Map<String, dynamic> missing = session.toStorageJson()
      ..remove('expiresAt');
    expect(
      () => AuthSession.fromStorage(session.accessToken, missing),
      throwsA(isA<AuthSessionStorageCorruptException>()),
    );
  });

  test('stored expiry must be later than the last validation instant', () {
    for (final DateTime expiry in <DateTime>[
      session.lastValidatedAt,
      session.lastValidatedAt.subtract(const Duration(seconds: 1)),
    ]) {
      final Map<String, dynamic> metadata = session.toStorageJson()
        ..['expiresAt'] = expiry.toIso8601String();

      expect(
        () => AuthSession.fromStorage(session.accessToken, metadata),
        throwsA(isA<AuthSessionStorageCorruptException>()),
      );
    }
  });
}
