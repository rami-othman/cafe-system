import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/controllers/auth_session_state.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 1, 10);

  test('startup with no session becomes unauthenticated', () async {
    final _MemoryStorage storage = _MemoryStorage();
    final AuthSessionCubit cubit = _cubit(storage: storage, now: () => now);

    await cubit.restore();

    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
  });

  test('successful login persists session and enters application', () async {
    final _MemoryStorage storage = _MemoryStorage();
    final _FakeRepository repository = _FakeRepository(
      loginSession: _session(),
    );
    final AuthSessionCubit cubit = _cubit(
      storage: storage,
      repository: repository,
      now: () => now,
    );

    await cubit.login(identifier: 'manager@example.test', password: 'password');

    expect(cubit.state.status, AuthSessionStatus.authenticated);
    expect((await storage.read())?.accessToken, 'opaque-token');
  });

  test(
    'must-change-password login is retained without creating another token',
    () async {
      final _MemoryStorage storage = _MemoryStorage();
      final _FakeRepository repository = _FakeRepository(
        loginSession: _session(mustChangePassword: true),
      );
      final AuthSessionCubit cubit = _cubit(
        storage: storage,
        repository: repository,
        now: () => now,
      );

      await cubit.login(identifier: 'cashier', password: 'password');
      await cubit.changePassword(
        currentPassword: 'password',
        newPassword: 'new-password',
      );

      expect(cubit.state.status, AuthSessionStatus.authenticated);
      expect(repository.changePasswordCalls, 1);
      expect((await storage.read())?.accessToken, 'opaque-token');
    },
  );

  test('logout clears the stored session', () async {
    final _MemoryStorage storage = _MemoryStorage(_session());
    final AuthSessionCubit cubit = _cubit(storage: storage, now: () => now);

    await cubit.logout();

    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(await storage.read(), isNull);
  });

  test('valid restored session bypasses login', () async {
    final _MemoryStorage storage = _MemoryStorage(_session());
    final AuthSessionCubit cubit = _cubit(storage: storage, now: () => now);

    await cubit.restore();

    expect(cubit.state.status, AuthSessionStatus.authenticated);
  });

  test('invalid session and protected 401 both return to login', () async {
    final _MemoryStorage storage = _MemoryStorage(_session());
    final _FakeRepository repository = _FakeRepository(
      meError: const ApiException(
        message: 'Unauthorized',
        type: ApiErrorType.unauthenticated,
      ),
    );
    final AuthSessionCubit cubit = _cubit(
      storage: storage,
      repository: repository,
      now: () => now,
    );

    await cubit.restore();
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(cubit.state.message, AuthMessage.sessionExpired);
    expect(await storage.read(), isNull);

    await cubit.expire();
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
  });

  test('offline restore honors the backend 12-hour window', () async {
    final _FakeRepository offline = _FakeRepository(
      meError: const ApiException(
        message: 'Offline',
        type: ApiErrorType.networkUnavailable,
      ),
    );
    final AuthSessionCubit valid = _cubit(
      storage: _MemoryStorage(
        _session(lastValidatedAt: now.subtract(const Duration(hours: 11))),
      ),
      repository: offline,
      now: () => now,
    );
    final AuthSessionCubit expired = _cubit(
      storage: _MemoryStorage(
        _session(lastValidatedAt: now.subtract(const Duration(hours: 13))),
      ),
      repository: offline,
      now: () => now,
    );

    await valid.restore();
    await expired.restore();

    expect(valid.state.status, AuthSessionStatus.authenticated);
    expect(expired.state.status, AuthSessionStatus.unauthenticated);
    expect(expired.state.message, AuthMessage.offlineSessionExpired);
  });
}

AuthSessionCubit _cubit({
  required _MemoryStorage storage,
  AuthRepository? repository,
  required DateTime Function() now,
}) => AuthSessionCubit(
  repository: repository ?? _FakeRepository(),
  storage: storage,
  apiClient: DioApiClient(),
  now: now,
);

AuthSession _session({
  bool mustChangePassword = false,
  DateTime? lastValidatedAt,
}) => AuthSession(
  accessToken: 'opaque-token',
  user: const AuthUser(
    id: 7,
    name: 'Rami',
    role: 'manager',
    email: 'manager@test',
  ),
  tenant: const AuthTenant(id: 4, name: 'Cafe 618'),
  mustChangePassword: mustChangePassword,
  lastValidatedAt: lastValidatedAt ?? DateTime.utc(2026, 9, 1, 10),
  offlineSessionMaxAgeSeconds: 43200,
);

class _MemoryStorage implements AuthSessionStorage {
  _MemoryStorage([this.session]);
  AuthSession? session;
  @override
  Future<void> clear() async => session = null;
  @override
  Future<AuthSession?> read() async => session;
  @override
  Future<void> write(AuthSession next) async => session = next;
}

class _FakeRepository implements AuthRepository {
  _FakeRepository({this.loginSession, this.meError});
  final AuthSession? loginSession;
  final ApiException? meError;
  int changePasswordCalls = 0;
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async => loginSession ?? _session();
  @override
  Future<void> logout() async {}
  @override
  Future<AuthSession> me(AuthSession cachedSession) async {
    if (meError != null) throw meError!;
    return cachedSession;
  }
}
