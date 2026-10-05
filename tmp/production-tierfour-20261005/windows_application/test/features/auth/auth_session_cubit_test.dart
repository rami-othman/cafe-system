import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/controllers/auth_session_state.dart';
import 'package:windows_application/features/auth/models/auth_failure.dart';
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

  test('login failures map to their safe presentation categories', () async {
    final List<({Object error, AuthFailureKind expected})> cases =
        <({Object error, AuthFailureKind expected})>[
          (
            error: const ApiException(
              message: 'Unauthorized',
              statusCode: 401,
              type: ApiErrorType.unauthenticated,
            ),
            expected: AuthFailureKind.invalidCredentials,
          ),
          (
            error: const ApiException(
              message: 'Slow down',
              statusCode: 429,
              code: AuthBackendCode.loginRateLimited,
              type: ApiErrorType.unknown,
            ),
            expected: AuthFailureKind.tooManyAttempts,
          ),
          (
            error: const ApiException(
              message: 'Offline',
              type: ApiErrorType.networkUnavailable,
            ),
            expected: AuthFailureKind.networkUnavailable,
          ),
          (
            error: const ApiException(
              message: 'Timed out',
              type: ApiErrorType.connectionTimeout,
            ),
            expected: AuthFailureKind.connectionTimeout,
          ),
          (
            error: const ApiException(
              message: 'Server error',
              statusCode: 503,
              type: ApiErrorType.server,
            ),
            expected: AuthFailureKind.serverUnavailable,
          ),
          (
            error: StateError('do not expose this text'),
            expected: AuthFailureKind.unexpected,
          ),
        ];

    for (final ({Object error, AuthFailureKind expected}) item in cases) {
      final AuthSessionCubit cubit = _cubit(
        storage: _MemoryStorage(),
        repository: _FakeRepository(loginError: item.error),
        now: () => now,
      );

      await cubit.login(identifier: 'cashier', password: 'password');

      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(cubit.state.failure?.kind, item.expected);
      await cubit.close();
    }
  });

  test('validation failures retain only safe login field mappings', () async {
    final _MemoryStorage storage = _MemoryStorage();
    final AuthSessionCubit cubit = _cubit(
      storage: storage,
      repository: _FakeRepository(
        loginError: const ApiException(
          message: 'Provide exactly one of email or username.',
          statusCode: 422,
          validationErrors: <String, List<String>>{
            'identifier': <String>['unsafe backend text'],
            'password': <String>['unsafe backend text'],
          },
          type: ApiErrorType.validation,
        ),
      ),
      now: () => now,
    );

    await cubit.login(identifier: 'cashier', password: 'password');

    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(cubit.state.failure?.kind, AuthFailureKind.validation);
    expect(cubit.state.failure?.fieldErrors, <AuthField, AuthFailureKind>{
      AuthField.identifier: AuthFailureKind.validation,
      AuthField.password: AuthFailureKind.validation,
    });
    expect(await storage.read(), isNull);
  });

  test('malformed successful login response does not authenticate', () async {
    final _MemoryStorage storage = _MemoryStorage();
    final AuthSession malformed = AuthSession(
      accessToken: '',
      user: _session().user,
      tenant: _session().tenant,
      mustChangePassword: false,
      lastValidatedAt: now,
      offlineSessionMaxAgeSeconds: 43200,
    );
    final AuthSessionCubit malformedCubit = _cubit(
      storage: storage,
      repository: _FakeRepository(loginSession: malformed),
      now: () => now,
    );

    await malformedCubit.login(identifier: 'cashier', password: 'password');

    expect(malformedCubit.state.status, AuthSessionStatus.unauthenticated);
    expect(malformedCubit.state.failure?.kind, AuthFailureKind.invalidResponse);
    expect(await storage.read(), isNull);
  });

  test('duplicate login submissions issue one repository request', () async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    final _FakeRepository repository = _FakeRepository(loginCompleter: pending);
    final AuthSessionCubit cubit = _cubit(
      storage: _MemoryStorage(),
      repository: repository,
      now: () => now,
    );

    final Future<void> first = cubit.login(
      identifier: 'cashier',
      password: 'password',
    );
    final Future<void> duplicate = cubit.login(
      identifier: 'cashier',
      password: 'password',
    );
    expect(repository.loginCalls, 1);

    pending.complete(_session());
    await Future.wait(<Future<void>>[first, duplicate]);
    expect(repository.loginCalls, 1);
  });

  test('secure storage write failures remain presentation-safe', () async {
    final _MemoryStorage storage = _MemoryStorage(
      null,
      StateError('storage detail'),
    );
    final _FakeRepository repository = _FakeRepository();
    final DioApiClient apiClient = DioApiClient();
    final AuthSessionCubit cubit = _cubit(
      storage: storage,
      repository: repository,
      apiClient: apiClient,
      now: () => now,
    );

    await cubit.login(identifier: 'cashier', password: 'password');

    expect(repository.logoutCalls, 1);
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(cubit.state.failure?.kind, AuthFailureKind.secureStorageFailure);
    expect(cubit.state.failure.toString(), isNot(contains('storage detail')));
    expect(apiClient.authenticatedTenantId, isNull);
    expect(await storage.read(), isNull);
  });

  test(
    'login storage failure clears local context when token revocation fails',
    () async {
      final _MemoryStorage storage = _MemoryStorage(
        null,
        StateError('unsafe storage detail'),
      );
      final _FakeRepository repository = _FakeRepository(
        logoutError: StateError('unsafe logout detail'),
      );
      final DioApiClient apiClient = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        storage: storage,
        repository: repository,
        apiClient: apiClient,
        now: () => now,
      );

      await cubit.login(identifier: 'cashier', password: 'password');

      expect(repository.logoutCalls, 1);
      expect(apiClient.authenticatedTenantId, isNull);
      expect(await storage.read(), isNull);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(cubit.state.failure?.kind, AuthFailureKind.secureStorageFailure);
      expect(cubit.state.failure.toString(), isNot(contains('unsafe')));
    },
  );

  test(
    'real Dio cleanup 401 preserves the login secure-storage failure',
    () async {
      final _MemoryStorage storage = _MemoryStorage(
        _session(),
        StateError('unsafe storage detail'),
      );
      final Dio dio = _authDioWithUnauthorizedCleanup();
      final DioApiClient apiClient = DioApiClient(dio: dio);
      final ApiAuthRepository repository = ApiAuthRepository(apiClient);
      late AuthSessionCubit cubit;
      int authenticationFailures = 0;
      cubit = _cubit(
        storage: storage,
        repository: repository,
        apiClient: apiClient,
        now: () => now,
      );
      apiClient.onAuthenticationFailure = (_) {
        authenticationFailures++;
        unawaited(cubit.expire());
      };

      await cubit.login(identifier: 'cashier', password: 'password');
      await _settleAsync();

      expect(authenticationFailures, 1);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(cubit.state.failure?.kind, AuthFailureKind.secureStorageFailure);
      expect(cubit.state.message, isNot(AuthMessage.sessionExpired));
      expect(dio.options.headers, isNot(contains('Authorization')));
      expect(apiClient.authenticatedTenantId, isNull);
      expect(await storage.read(), isNull);
      await cubit.close();
    },
  );

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

  test(
    'changed password with storage failure revokes and returns to login safely',
    () async {
      final _MemoryStorage storage = _MemoryStorage();
      final _FakeRepository repository = _FakeRepository(
        loginSession: _session(mustChangePassword: true),
      );
      final DioApiClient apiClient = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        storage: storage,
        repository: repository,
        apiClient: apiClient,
        now: () => now,
      );
      await cubit.login(identifier: 'cashier', password: 'password');
      storage.writeError = StateError('unsafe session write detail');

      await cubit.changePassword(
        currentPassword: 'old-password',
        newPassword: 'new-password',
      );

      expect(repository.changePasswordCalls, 1);
      expect(repository.logoutCalls, 1);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(
        cubit.state.failure?.kind,
        AuthFailureKind.passwordChangedSessionSaveFailed,
      );
      expect(cubit.state.failure.toString(), isNot(contains('unsafe')));
      expect(apiClient.authenticatedTenantId, isNull);
      expect(await storage.read(), isNull);
    },
  );

  test(
    'changed password storage failure clears local context when revocation fails',
    () async {
      final _MemoryStorage storage = _MemoryStorage();
      final _FakeRepository repository = _FakeRepository(
        loginSession: _session(mustChangePassword: true),
        logoutError: StateError('unsafe revoke detail'),
      );
      final DioApiClient apiClient = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        storage: storage,
        repository: repository,
        apiClient: apiClient,
        now: () => now,
      );
      await cubit.login(identifier: 'cashier', password: 'password');
      storage.writeError = StateError('unsafe session write detail');

      await cubit.changePassword(
        currentPassword: 'old-password',
        newPassword: 'new-password',
      );

      expect(repository.logoutCalls, 1);
      expect(apiClient.authenticatedTenantId, isNull);
      expect(await storage.read(), isNull);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(
        cubit.state.failure?.kind,
        AuthFailureKind.passwordChangedSessionSaveFailed,
      );
    },
  );

  test(
    'real Dio cleanup 401 preserves the password-change save failure',
    () async {
      final _MemoryStorage storage = _MemoryStorage();
      final Dio dio = _authDioWithUnauthorizedCleanup(mustChangePassword: true);
      final DioApiClient apiClient = DioApiClient(dio: dio);
      final ApiAuthRepository repository = ApiAuthRepository(apiClient);
      late AuthSessionCubit cubit;
      int authenticationFailures = 0;
      cubit = _cubit(
        storage: storage,
        repository: repository,
        apiClient: apiClient,
        now: () => now,
      );
      apiClient.onAuthenticationFailure = (_) {
        authenticationFailures++;
        unawaited(cubit.expire());
      };

      await cubit.login(identifier: 'cashier', password: 'password');
      storage.writeError = StateError('unsafe session write detail');

      await cubit.changePassword(
        currentPassword: 'old-password',
        newPassword: 'new-password',
      );
      await _settleAsync();

      expect(authenticationFailures, 1);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(
        cubit.state.failure?.kind,
        AuthFailureKind.passwordChangedSessionSaveFailed,
      );
      expect(cubit.state.message, isNot(AuthMessage.sessionExpired));
      expect(dio.options.headers, isNot(contains('Authorization')));
      expect(apiClient.authenticatedTenantId, isNull);
      expect(await storage.read(), isNull);
      await cubit.close();
    },
  );

  test(
    'change password maps safe field errors without raw backend text',
    () async {
      final _FakeRepository repository = _FakeRepository(
        loginSession: _session(mustChangePassword: true),
        changePasswordError: const ApiException(
          message: 'unsafe backend detail',
          statusCode: 422,
          type: ApiErrorType.validation,
          validationErrors: <String, List<String>>{
            'currentPassword': <String>['unsafe'],
            'newPassword': <String>['unsafe'],
            'newPassword_confirmation': <String>['unsafe'],
          },
        ),
      );
      final AuthSessionCubit cubit = _cubit(
        storage: _MemoryStorage(),
        repository: repository,
        now: () => now,
      );
      await cubit.login(identifier: 'cashier', password: 'password');

      await cubit.changePassword(
        currentPassword: 'old-password',
        newPassword: 'new-password',
      );

      expect(cubit.state.status, AuthSessionStatus.mustChangePassword);
      expect(cubit.state.failure?.fieldErrors, <AuthField, AuthFailureKind>{
        AuthField.currentPassword: AuthFailureKind.incorrectCurrentPassword,
        AuthField.newPassword: AuthFailureKind.weakNewPassword,
        AuthField.confirmation: AuthFailureKind.passwordConfirmationMismatch,
      });
    },
  );

  test(
    'change password network and server errors are not current-password errors',
    () async {
      for (final ApiException error in <ApiException>[
        const ApiException(
          message: 'offline',
          type: ApiErrorType.networkUnavailable,
        ),
        const ApiException(
          message: 'server',
          statusCode: 503,
          type: ApiErrorType.server,
        ),
      ]) {
        final AuthSessionCubit cubit = _cubit(
          storage: _MemoryStorage(),
          repository: _FakeRepository(
            loginSession: _session(mustChangePassword: true),
            changePasswordError: error,
          ),
          now: () => now,
        );
        await cubit.login(identifier: 'cashier', password: 'password');
        await cubit.changePassword(
          currentPassword: 'old-password',
          newPassword: 'new-password',
        );

        expect(
          cubit.state.failure?.kind,
          error.type == ApiErrorType.networkUnavailable
              ? AuthFailureKind.networkUnavailable
              : AuthFailureKind.serverUnavailable,
        );
        expect(cubit.state.failure?.fieldErrors, isEmpty);
        await cubit.close();
      }
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

  test(
    'successful auth/me refresh replaces and persists missing legacy capability',
    () async {
      final _MemoryStorage storage = _MemoryStorage(
        _legacySessionWithoutCapability(role: 'owner'),
      );
      final AuthSessionCubit cubit = _cubit(
        storage: storage,
        repository: _FakeRepository(
          meSession: _session(role: 'owner', customerManagementAllowed: true),
        ),
        now: () => now,
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.authenticated);
      expect(cubit.state.session?.customerManagementAllowed, isTrue);
      expect((await storage.read())?.customerManagementAllowed, isTrue);
    },
  );

  test('invalid session and protected 401 both return to login', () async {
    final _MemoryStorage storage = _MemoryStorage(_session());
    final _FakeRepository repository = _FakeRepository(
      meError: const ApiException(
        message: 'Unauthorized',
        statusCode: 401,
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

  test('an authenticated non-Auth 403 callback does not expire the session',
      () async {
    final _MemoryStorage storage = _MemoryStorage(_session());
    final DioApiClient apiClient = DioApiClient();
    final AuthSessionCubit cubit = _cubit(
      storage: storage,
      apiClient: apiClient,
      now: () => now,
    );

    await cubit.restore();
    await cubit.handleAuthenticatedFailure(
      const ApiException(
        message: 'unsafe backend detail',
        statusCode: 403,
        code: 'FORBIDDEN',
        type: ApiErrorType.forbidden,
      ),
      apiClient.accessToken,
    );

    expect(cubit.state.status, AuthSessionStatus.authenticated);
    expect(apiClient.accessToken, 'opaque-token');
    expect(await storage.read(), isNotNull);
    await cubit.close();
  });

  test(
    'real Dio ordinary authenticated 401 still expires the session',
    () async {
      final _MemoryStorage storage = _MemoryStorage();
      final Dio dio = _authDioWithUnauthorizedCleanup();
      final DioApiClient apiClient = DioApiClient(dio: dio);
      final ApiAuthRepository repository = ApiAuthRepository(apiClient);
      late AuthSessionCubit cubit;
      int authenticationFailures = 0;
      cubit = _cubit(
        storage: storage,
        repository: repository,
        apiClient: apiClient,
        now: () => now,
      );
      apiClient.onAuthenticationFailure = (_) {
        authenticationFailures++;
        unawaited(cubit.expire());
      };

      await cubit.login(identifier: 'cashier', password: 'password');
      expect(cubit.state.status, AuthSessionStatus.authenticated);

      await expectLater(
        apiClient.get('protected'),
        throwsA(isA<ApiException>()),
      );
      await _settleAsync();

      expect(authenticationFailures, 1);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(cubit.state.message, AuthMessage.sessionExpired);
      expect(dio.options.headers, isNot(contains('Authorization')));
      expect(apiClient.authenticatedTenantId, isNull);
      expect(await storage.read(), isNull);
      await cubit.close();
    },
  );

  test('offline restore honors the backend 12-hour window', () async {
    final _FakeRepository offline = _FakeRepository(
      meError: const ApiException(
        message: 'Offline',
        type: ApiErrorType.networkUnavailable,
      ),
    );
    final AuthSessionCubit valid = _cubit(
      storage: _MemoryStorage(
        _legacySessionWithoutCapability(
          lastValidatedAt: now.subtract(const Duration(hours: 11)),
        ),
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
    expect(valid.state.session?.customerManagementAllowed, isFalse);
    expect(expired.state.status, AuthSessionStatus.verificationRequired);
    expect(
      expired.state.failure?.kind,
      AuthFailureKind.offlineVerificationRequired,
    );
  });
}

AuthSessionCubit _cubit({
  required _MemoryStorage storage,
  AuthRepository? repository,
  DioApiClient? apiClient,
  required DateTime Function() now,
}) => AuthSessionCubit(
  repository: repository ?? _FakeRepository(),
  storage: storage,
  apiClient: apiClient ?? DioApiClient(),
  now: now,
);

AuthSession _session({
  bool mustChangePassword = false,
  DateTime? lastValidatedAt,
  String role = 'manager',
  bool customerManagementAllowed = false,
}) => AuthSession(
  accessToken: 'opaque-token',
  user: AuthUser(id: 7, name: 'Rami', role: role, email: 'manager@test'),
  tenant: const AuthTenant(id: 4, name: 'Cafe 618'),
  mustChangePassword: mustChangePassword,
  lastValidatedAt: lastValidatedAt ?? DateTime.utc(2026, 9, 1, 10),
  offlineSessionMaxAgeSeconds: 43200,
  customerManagementAllowed: customerManagementAllowed,
  expiresAt: DateTime.utc(2026, 10, 1),
);

AuthSession _legacySessionWithoutCapability({
  String role = 'manager',
  DateTime? lastValidatedAt,
}) {
  final Map<String, dynamic> metadata = _session(
    role: role,
    lastValidatedAt: lastValidatedAt,
    customerManagementAllowed: true,
  ).toStorageJson()..remove('capabilities');
  return AuthSession.fromStorage('opaque-token', metadata);
}

Dio _authDioWithUnauthorizedCleanup({bool mustChangePassword = false}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        if (options.path == 'auth/login') {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': _apiSession(mustChangePassword: mustChangePassword),
              },
            ),
          );
          return;
        }
        if (options.path == 'auth/change-password') {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{'data': null},
            ),
          );
          return;
        }
        if (options.path == 'auth/logout' || options.path == 'protected') {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 401,
                data: const <String, dynamic>{'code': 'AUTH_SESSION_INVALID'},
              ),
            ),
          );
          return;
        }
        throw StateError('Unexpected request: ${options.path}');
      },
    ),
  );
  return dio;
}

Map<String, dynamic> _apiSession({required bool mustChangePassword}) =>
    <String, dynamic>{
      'accessToken': 'opaque-token',
      'tokenType': 'Bearer',
      'expiresAt': '2026-10-01T00:00:00.000Z',
      'mustChangePassword': mustChangePassword,
      'user': <String, dynamic>{
        'id': 7,
        'name': 'Rami',
        'role': 'manager',
        'status': 'active',
        'email': 'manager@test',
        'username': null,
      },
      'tenant': <String, dynamic>{
        'id': 4,
        'name': 'Cafe 618',
        'status': 'active',
      },
      'capabilities': <String, dynamic>{
        'customer': <String, dynamic>{'manage': false},
      },
      'session': <String, dynamic>{
        'id': 12,
        'deviceName': 'Cafe System 618 Windows',
        'authenticatedAt': '2026-09-01T00:00:00.000Z',
        'lastValidatedAt': '2026-09-01T10:00:00.000Z',
        'expiresAt': '2026-10-01T00:00:00.000Z',
        'offlineSessionMaxAgeSeconds': 43200,
      },
      'branchAccess': <String, dynamic>{
        'allBranches': false,
        'branchIds': <int>[1],
      },
    };

Future<void> _settleAsync() => Future<void>.delayed(Duration.zero);

class _MemoryStorage implements AuthSessionStorage {
  _MemoryStorage([this.session, this.writeError]);
  AuthSession? session;
  Object? writeError;
  @override
  Future<void> clear() async => session = null;
  @override
  Future<bool> isAuthoritativelyInvalidated() async => false;
  @override
  Future<void> markAuthoritativelyInvalidated() async {}
  @override
  Future<AuthSession?> read() async => session;
  @override
  Future<void> write(AuthSession next) async {
    if (writeError != null) throw writeError!;
    session = next;
  }

  @override
  Stream<void> get changes => const Stream<void>.empty();
}

class _FakeRepository implements AuthRepository {
  _FakeRepository({
    this.loginSession,
    this.loginError,
    this.loginCompleter,
    this.changePasswordError,
    this.logoutError,
    this.meError,
    this.meSession,
  });
  final AuthSession? loginSession;
  final Object? loginError;
  final Completer<AuthSession>? loginCompleter;
  final Object? changePasswordError;
  final Object? logoutError;
  final ApiException? meError;
  final AuthSession? meSession;
  int changePasswordCalls = 0;
  int loginCalls = 0;
  int logoutCalls = 0;
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
    if (changePasswordError != null) throw changePasswordError!;
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    loginCalls++;
    if (loginCompleter != null) return loginCompleter!.future;
    if (loginError != null) throw loginError!;
    return loginSession ?? _session();
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<AuthSession> me(AuthSession cachedSession) async {
    if (meError != null) throw meError!;
    return meSession ?? cachedSession;
  }
}
