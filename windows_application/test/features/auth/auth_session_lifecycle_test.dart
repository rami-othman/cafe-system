import 'dart:async';

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
  final DateTime now = DateTime.utc(2026, 9, 16, 12);

  test('no cached session ends unauthenticated', () async {
    final AuthSessionCubit cubit = _cubit(now: now, storage: _Storage());

    await cubit.restore();

    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    await cubit.close();
  });

  test(
    'verified cached sessions enter authenticated and password-change states',
    () async {
      for (final bool mustChangePassword in <bool>[false, true]) {
        final AuthSessionCubit cubit = _cubit(
          now: now,
          storage: _Storage(_session(mustChangePassword: mustChangePassword)),
        );

        await cubit.restore();

        expect(
          cubit.state.status,
          mustChangePassword
              ? AuthSessionStatus.mustChangePassword
              : AuthSessionStatus.authenticated,
        );
        await cubit.close();
      }
    },
  );

  test('authoritative auth/me failures clear credentials', () async {
    for (final String? code in <String?>[
      'AUTH_REQUIRED',
      'AUTH_SESSION_INVALID',
      null,
    ]) {
      final _Storage storage = _Storage(_session());
      final DioApiClient api = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        now: now,
        storage: storage,
        api: api,
        repository: _Repository(
          onMe: (_) => Future<AuthSession>.error(
            ApiException(
              message: 'do not expose',
              statusCode: 401,
              code: code,
              type: ApiErrorType.unauthenticated,
            ),
          ),
        ),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(cubit.state.message, AuthMessage.sessionExpired);
      expect(storage.session, isNull);
      expect(api.accessToken, isNull);
      expect(api.authenticatedTenantId, isNull);
      await cubit.close();
    }
  });

  test('persisted invalidation blocks later offline restoration', () async {
    final _Storage storage = _Storage(_session())..invalidated = true;
    final AuthSessionCubit cubit = _cubit(
      now: now,
      storage: storage,
      repository: _Repository(
        onMe: (_) => Future<AuthSession>.error(
          const ApiException(
            message: 'offline',
            type: ApiErrorType.networkUnavailable,
          ),
        ),
      ),
    );

    await cubit.restore();

    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(cubit.state.message, AuthMessage.sessionExpired);
    expect(storage.readCalls, 0);
    await cubit.close();
  });

  test('temporary verification failures enter bounded offline mode', () async {
    for (final ApiException error in <ApiException>[
      const ApiException(
        message: 'offline',
        type: ApiErrorType.networkUnavailable,
      ),
      const ApiException(
        message: 'connect timeout',
        type: ApiErrorType.connectionTimeout,
      ),
      const ApiException(
        message: 'send timeout',
        type: ApiErrorType.sendTimeout,
      ),
      const ApiException(
        message: 'receive timeout',
        type: ApiErrorType.receiveTimeout,
      ),
      const ApiException(
        message: 'server',
        statusCode: 503,
        type: ApiErrorType.server,
      ),
      const ApiException(
        message: 'gateway error',
        statusCode: 502,
        type: ApiErrorType.unknown,
      ),
    ]) {
      final AuthSessionCubit cubit = _cubit(
        now: now,
        storage: _Storage(_session(lastValidatedAt: now)),
        repository: _Repository(onMe: (_) => Future<AuthSession>.error(error)),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.authenticated);
      await cubit.close();
    }
  });

  test('concrete auth/me 4xx responses never enter offline mode', () async {
    for (final ApiException error in <ApiException>[
      const ApiException(
        message: 'not found',
        statusCode: 404,
        type: ApiErrorType.unknown,
      ),
      const ApiException(
        message: 'bad request',
        statusCode: 400,
        type: ApiErrorType.unknown,
      ),
      const ApiException(
        message: 'unexpected client failure',
        statusCode: 418,
        type: ApiErrorType.unknown,
      ),
    ]) {
      final DioApiClient api = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        now: now,
        api: api,
        storage: _Storage(_session(lastValidatedAt: now)),
        repository: _Repository(onMe: (_) => Future<AuthSession>.error(error)),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.verificationRequired);
      expect(
        cubit.state.failure?.kind,
        AuthFailureKind.unableToVerifySession,
      );
      expect(api.accessToken, isNull);
      expect(api.authenticatedTenantId, isNull);
      await cubit.close();
    }
  });

  test(
    'malformed successful auth/me response is recovery-only and never persists',
    () async {
      for (final bool mustChangePassword in <bool>[false, true]) {
        final _Storage storage = _Storage(
          _session(mustChangePassword: mustChangePassword),
        );
        final DioApiClient api = DioApiClient();
        final AuthSessionCubit cubit = _cubit(
          now: now,
          api: api,
          storage: storage,
          repository: _Repository(
            onMe: (_) => Future<AuthSession>.error(
              const AuthInvalidResponseException(),
            ),
          ),
        );

        await cubit.restore();

        expect(cubit.state.status, AuthSessionStatus.verificationRequired);
        expect(cubit.state.failure?.kind, AuthFailureKind.invalidResponse);
        expect(storage.writeCalls, 0);
        expect(api.accessToken, isNull);
        expect(api.authenticatedTenantId, isNull);
        await cubit.close();
      }
    },
  );

  test(
    'verified-session persistence failure clears stale authority before later offline restoration',
    () async {
      final _Storage storage = _Storage(
        _session(customerManagementAllowed: true, lastValidatedAt: now),
      )..writeError = StateError('secure storage unavailable');
      final DioApiClient api = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        now: now,
        api: api,
        storage: storage,
        repository: _Repository(
          onMe: (_) => Future<AuthSession>.value(
            _session(customerManagementAllowed: false, lastValidatedAt: now),
          ),
        ),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.verificationRequired);
      expect(
        cubit.state.failure?.kind,
        AuthFailureKind.verifiedSessionSaveFailed,
      );
      expect(cubit.state.session?.customerManagementAllowed, isFalse);
      expect(storage.writeCalls, 1);
      expect(storage.session, isNull);
      expect(api.accessToken, isNull);
      expect(api.authenticatedTenantId, isNull);
      await cubit.close();

      final AuthSessionCubit laterOfflineRestore = _cubit(
        now: now,
        storage: storage,
        repository: _Repository(
          onMe: (_) => Future<AuthSession>.error(
            const ApiException(
              message: 'offline',
              type: ApiErrorType.networkUnavailable,
            ),
          ),
        ),
      );
      await laterOfflineRestore.restore();

      expect(
        laterOfflineRestore.state.status,
        AuthSessionStatus.unauthenticated,
      );
      expect(laterOfflineRestore.state.session, isNull);
      await laterOfflineRestore.close();
    },
  );

  test(
    'temporary failure outside the offline window retains session for retry',
    () async {
      final _Storage storage = _Storage(
        _session(lastValidatedAt: now.subtract(const Duration(hours: 13))),
      );
      final AuthSessionCubit cubit = _cubit(
        now: now,
        storage: storage,
        repository: _Repository(
          onMe: (_) => Future<AuthSession>.error(
            const ApiException(
              message: 'offline',
              type: ApiErrorType.networkUnavailable,
            ),
          ),
        ),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.verificationRequired);
      expect(
        cubit.state.failure?.kind,
        AuthFailureKind.offlineVerificationRequired,
      );
      expect(storage.session, isNotNull);
      await cubit.close();
    },
  );

  test(
    'absolute token expiry blocks offline entry without deleting credentials',
    () async {
      final Map<String, dynamic> expiredMetadata = _session(
        lastValidatedAt: now.subtract(const Duration(days: 2)),
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ).toStorageJson();
      final _Storage storage = _Storage()..rawMetadata = expiredMetadata;
      final AuthSessionCubit cubit = _cubit(
        now: now,
        storage: storage,
        repository: _Repository(
          onMe: (_) => Future<AuthSession>.error(
            const ApiException(
              message: 'offline',
              type: ApiErrorType.networkUnavailable,
            ),
          ),
        ),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.verificationRequired);
      expect(storage.clearCalls, 0);
      expect(storage.rawMetadata, same(expiredMetadata));
      await cubit.close();
    },
  );

  test(
    'a legacy no-expiry cache is cleared and cannot enter offline mode',
    () async {
      final Map<String, dynamic> legacyMetadata =
          _session(expiresAt: now.add(const Duration(days: 1))).toStorageJson()
            ..remove('expiresAt');
      final _Storage storage = _Storage()..rawMetadata = legacyMetadata;
      int verificationCalls = 0;
      final AuthSessionCubit cubit = _cubit(
        now: now,
        storage: storage,
        repository: _Repository(
          onMe: (_) {
            verificationCalls++;
            return Future<AuthSession>.error(
              const ApiException(
                message: 'offline',
                type: ApiErrorType.networkUnavailable,
              ),
            );
          },
        ),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(cubit.state.failure?.kind, AuthFailureKind.corruptSavedSession);
      expect(storage.clearCalls, 1);
      expect(verificationCalls, 0);
      await cubit.close();
    },
  );

  test(
    'tenant-not-operational is blocked and never restored offline',
    () async {
      final DioApiClient api = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        now: now,
        api: api,
        storage: _Storage(_session()),
        repository: _Repository(
          onMe: (_) => Future<AuthSession>.error(_tenantBlocked()),
        ),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.tenantNotOperational);
      expect(cubit.state.session, isNotNull);
      expect(api.accessToken, isNull);
      expect(api.authenticatedTenantId, isNull);
      await cubit.close();
    },
  );

  test('tenant retry success enters the application', () async {
    int attempts = 0;
    final AuthSessionCubit cubit = _cubit(
      now: now,
      storage: _Storage(_session()),
      repository: _Repository(
        onMe: (AuthSession session) {
          attempts++;
          return attempts == 1
              ? Future<AuthSession>.error(_tenantBlocked())
              : Future<AuthSession>.value(session);
        },
      ),
    );

    await cubit.restore();
    await cubit.retryVerification();

    expect(cubit.state.status, AuthSessionStatus.authenticated);
    expect(attempts, 2);
    await cubit.close();
  });

  test('ordinary 403 is not interpreted as tenant suspension', () async {
    final AuthSessionCubit cubit = _cubit(
      now: now,
      storage: _Storage(_session()),
      repository: _Repository(
        onMe: (_) => Future<AuthSession>.error(
          const ApiException(
            message: 'unsafe',
            statusCode: 403,
            code: 'FORBIDDEN',
            type: ApiErrorType.forbidden,
          ),
        ),
      ),
    );

    await cubit.restore();

    expect(cubit.state.status, AuthSessionStatus.verificationRequired);
    await cubit.close();
  });

  test('tenant retry temporary failure remains blocked', () async {
    final AuthSessionCubit cubit = _cubit(
      now: now,
      storage: _Storage(_session()),
      repository: _Repository(
        onMe: (_) => Future<AuthSession>.error(_tenantBlocked()),
      ),
    );

    await cubit.restore();
    await cubit.retryVerification();

    expect(cubit.state.status, AuthSessionStatus.tenantNotOperational);
    await cubit.close();
  });

  test(
    'secure-storage read failure is retryable and does not leave splash',
    () async {
      final _Storage storage = _Storage()..readError = StateError('unsafe');
      final DioApiClient api = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        now: now,
        storage: storage,
        api: api,
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.verificationRequired);
      expect(
        cubit.state.failure?.kind,
        AuthFailureKind.secureStorageReadFailure,
      );
      expect(api.accessToken, isNull);
      storage.readError = null;
      await cubit.retryVerification();
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      await cubit.close();
    },
  );

  test('corrupt cached metadata is cleared safely', () async {
    final _Storage storage = _Storage(
      AuthSession(
        accessToken: '',
        user: const AuthUser(id: 7, name: 'Rami', role: 'manager'),
        tenant: const AuthTenant(id: 4, name: 'Cafe'),
        mustChangePassword: false,
        lastValidatedAt: now,
        offlineSessionMaxAgeSeconds: 43200,
      ),
    );
    final AuthSessionCubit cubit = _cubit(now: now, storage: storage);

    await cubit.restore();

    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(cubit.state.failure?.kind, AuthFailureKind.corruptSavedSession);
    expect(storage.session, isNull);
    await cubit.close();
  });

  test(
    'storage clear failure still ends in deterministic unauthenticated state',
    () async {
      final _Storage storage = _Storage(_session())
        ..clearError = StateError('unsafe');
      final DioApiClient api = DioApiClient();
      final AuthSessionCubit cubit = _cubit(
        now: now,
        storage: storage,
        api: api,
        repository: _Repository(
          onMe: (_) => Future<AuthSession>.error(
            const ApiException(
              message: 'expired',
              statusCode: 401,
              type: ApiErrorType.unauthenticated,
            ),
          ),
        ),
      );

      await cubit.restore();

      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(api.accessToken, isNull);
      expect(storage.clearCalls, 1);
      await cubit.close();
    },
  );

  test('Return to Login settles even when local deletion fails', () async {
    final _Storage storage = _Storage(_session())
      ..clearError = StateError('unsafe');
    final DioApiClient api = DioApiClient();
    final AuthSessionCubit cubit = _cubit(
      now: now,
      storage: storage,
      api: api,
      repository: _Repository(
        onMe: (_) => Future<AuthSession>.error(
          const ApiException(
            message: 'offline',
            type: ApiErrorType.networkUnavailable,
          ),
        ),
      ),
    );

    await cubit.restore();
    await cubit.returnToLogin();

    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(api.accessToken, isNull);
    expect(storage.clearCalls, 1);
    await cubit.close();
  });

  test('repeated retry coalesces auth/me into one request', () async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    int calls = 0;
    final AuthSession session = _session(
      lastValidatedAt: now.subtract(const Duration(hours: 13)),
    );
    final AuthSessionCubit cubit = _cubit(
      now: now,
      storage: _Storage(session),
      repository: _Repository(
        onMe: (_) {
          calls++;
          if (calls == 1) {
            return Future<AuthSession>.error(
              const ApiException(
                message: 'offline',
                type: ApiErrorType.networkUnavailable,
              ),
            );
          }
          return pending.future;
        },
      ),
    );

    await cubit.restore();
    final Future<void> first = cubit.retryVerification();
    final Future<void> second = cubit.retryVerification();
    expect(calls, 2);
    pending.complete(session);
    await Future.wait(<Future<void>>[first, second]);
    expect(cubit.state.status, AuthSessionStatus.authenticated);
    await cubit.close();
  });

  test(
    'overlapping restore calls use one authoritative verification',
    () async {
      final Completer<AuthSession> pending = Completer<AuthSession>();
      int calls = 0;
      final AuthSessionCubit cubit = _cubit(
        now: now,
        storage: _Storage(_session()),
        repository: _Repository(
          onMe: (_) {
            calls++;
            return pending.future;
          },
        ),
      );

      final Future<void> first = cubit.restore();
      final Future<void> second = cubit.restore();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      pending.complete(_session());
      await Future.wait(<Future<void>>[first, second]);
      expect(cubit.state.status, AuthSessionStatus.authenticated);
      await cubit.close();
    },
  );

  test(
    'late restore success cannot overwrite Return to Login or expiration',
    () async {
      for (final bool expire in <bool>[false, true]) {
        final Completer<AuthSession> pending = Completer<AuthSession>();
        final _Storage storage = _Storage(_session());
        final AuthSessionCubit cubit = _cubit(
          now: now,
          storage: storage,
          repository: _Repository(onMe: (_) => pending.future),
        );

        final Future<void> restore = cubit.restore();
        if (expire) {
          await cubit.expire();
        } else {
          await cubit.returnToLogin();
        }
        pending.complete(_session());
        await restore;

        expect(cubit.state.status, AuthSessionStatus.unauthenticated);
        expect(storage.session, isNull);
        await cubit.close();
      }
    },
  );

  test('simultaneous protected-request expiry performs one cleanup', () async {
    final _Storage storage = _Storage(_session());
    final AuthSessionCubit cubit = _cubit(now: now, storage: storage);
    await cubit.restore();

    await Future.wait(<Future<void>>[cubit.expire(), cubit.expire()]);

    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(storage.clearCalls, 1);
    await cubit.close();
  });

  test('closing during restore prevents late emits', () async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    final AuthSessionCubit cubit = _cubit(
      now: now,
      storage: _Storage(_session()),
      repository: _Repository(onMe: (_) => pending.future),
    );

    final Future<void> restore = cubit.restore();
    await cubit.close();
    pending.complete(_session());
    await restore;

    expect(cubit.isClosed, isTrue);
  });
}

AuthSessionCubit _cubit({
  required DateTime now,
  required _Storage storage,
  _Repository? repository,
  DioApiClient? api,
}) => AuthSessionCubit(
  repository: repository ?? _Repository(),
  storage: storage,
  apiClient: api ?? DioApiClient(),
  now: () => now,
);

AuthSession _session({
  bool mustChangePassword = false,
  bool customerManagementAllowed = false,
  DateTime? lastValidatedAt,
  DateTime? expiresAt,
}) => AuthSession(
  accessToken: 'opaque-token',
  user: const AuthUser(id: 7, name: 'Rami', role: 'manager'),
  tenant: const AuthTenant(id: 4, name: 'Cafe'),
  mustChangePassword: mustChangePassword,
  lastValidatedAt: lastValidatedAt ?? DateTime.utc(2026, 9, 16, 12),
  offlineSessionMaxAgeSeconds: 43200,
  customerManagementAllowed: customerManagementAllowed,
  expiresAt: expiresAt ?? DateTime.utc(2026, 10, 1),
);

ApiException _tenantBlocked() => const ApiException(
  message: 'unsafe',
  statusCode: 403,
  code: 'TENANT_NOT_OPERATIONAL',
  type: ApiErrorType.forbidden,
);

class _Storage implements AuthSessionStorage {
  _Storage([this.session]);

  AuthSession? session;
  Object? readError;
  Object? clearError;
  Object? writeError;
  Map<String, dynamic>? rawMetadata;
  int clearCalls = 0;
  int readCalls = 0;
  int writeCalls = 0;
  bool invalidated = false;

  @override
  Future<void> clear() async {
    clearCalls++;
    if (clearError != null) throw clearError!;
    session = null;
  }

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<AuthSession?> read() async {
    readCalls++;
    if (readError != null) throw readError!;
    if (rawMetadata != null) {
      return AuthSession.fromStorage('opaque-token', rawMetadata!);
    }
    return session;
  }

  @override
  Future<void> write(AuthSession next) async {
    writeCalls++;
    if (writeError != null) throw writeError!;
    session = next;
    invalidated = false;
  }

  @override
  Future<bool> isAuthoritativelyInvalidated() async => invalidated;

  @override
  Future<void> markAuthoritativelyInvalidated() async => invalidated = true;
}

class _Repository implements AuthRepository {
  _Repository({this.onMe});

  final Future<AuthSession> Function(AuthSession session)? onMe;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async => _session();

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> me(AuthSession cachedSession) =>
      onMe?.call(cachedSession) ?? Future<AuthSession>.value(cachedSession);
}
