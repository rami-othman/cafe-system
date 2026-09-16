import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/localization/app_locale_repository.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/auth/views/auth_recovery_screen.dart';
import 'package:windows_application/features/auth/views/auth_splash_screen.dart';
import 'package:windows_application/features/auth/views/login_screen.dart';

void main() {
  tearDown(() async => serviceLocator.reset());

  testWidgets('initial restoration remains on AuthSplashScreen', (
    WidgetTester tester,
  ) async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    await _configure(
      storage: _Storage(_session()),
      repository: _Repository(onMe: (_) => pending.future),
    );

    await _pump(tester);

    expect(find.byType(AuthSplashScreen), findsOneWidget);
    pending.complete(_session());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'temporary verification failure mounts recovery with live error',
    (WidgetTester tester) async {
      await _configure(
        storage: _Storage(_expiredOfflineSession()),
        repository: _Repository(
          onMe: (_) => Future<AuthSession>.error(_offline()),
        ),
      );

      await _pumpAndSettle(tester);

      expect(find.byType(AuthRecoveryScreen), findsOneWidget);
      expect(
        find.byKey(const Key('auth-retry-verification-button')),
        findsOneWidget,
      );
      final node = tester.getSemantics(
        find.byKey(const Key('auth-error-banner')),
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
    },
  );

  testWidgets(
    'verified-session save failure offers retry and logout without shell access',
    (WidgetTester tester) async {
      final _Storage storage = _Storage(_session())
        ..writeError = StateError('secure storage unavailable');
      final _Repository repository = _Repository(
        onMe: (AuthSession session) => Future<AuthSession>.value(session),
      );
      await _configure(storage: storage, repository: repository);

      await _pumpAndSettle(tester);

      expect(find.byType(AuthRecoveryScreen), findsOneWidget);
      expect(
        find.text(
          'Your verified session could not be saved securely. Retry verification or log out.',
        ),
        findsOneWidget,
      );
      expect(find.text('Log Out'), findsOneWidget);
      expect(
        find.byKey(const Key('auth-retry-verification-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('auth-return-to-login-button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(repository.logoutCalls, 1);
      expect(storage.session, isNull);
    },
  );

  testWidgets('recovery retry remains mounted and blocks duplicate taps', (
    WidgetTester tester,
  ) async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    int calls = 0;
    await _configure(
      storage: _Storage(_expiredOfflineSession()),
      repository: _Repository(
        onMe: (AuthSession session) {
          calls++;
          return calls == 1
              ? Future<AuthSession>.error(_offline())
              : pending.future;
        },
      ),
    );
    await _pumpAndSettle(tester);

    await tester.tap(find.byKey(const Key('auth-retry-verification-button')));
    await tester.tap(find.byKey(const Key('auth-retry-verification-button')));
    await tester.pump();

    expect(calls, 2);
    expect(find.byType(AuthRecoveryScreen), findsOneWidget);
    expect(find.text('Verifying session…'), findsOneWidget);
    pending.complete(_session());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'successful recovery retry enters the authenticated composition',
    (WidgetTester tester) async {
      int calls = 0;
      await _configure(
        storage: _Storage(_expiredOfflineSession()),
        repository: _Repository(
          onMe: (AuthSession session) {
            calls++;
            return calls == 1
                ? Future<AuthSession>.error(_offline())
                : Future.value(session);
          },
        ),
      );
      await _pumpAndSettle(tester);

      await tester.tap(find.byKey(const Key('auth-retry-verification-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AuthRecoveryScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets('Return to Login wins over a late recovery success', (
    WidgetTester tester,
  ) async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    int calls = 0;
    await _configure(
      storage: _Storage(_expiredOfflineSession()),
      repository: _Repository(
        onMe: (AuthSession session) {
          calls++;
          return calls == 1
              ? Future<AuthSession>.error(_offline())
              : pending.future;
        },
      ),
    );
    await _pumpAndSettle(tester);

    await tester.tap(find.byKey(const Key('auth-retry-verification-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth-return-to-login-button')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    pending.complete(_session());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('tenant-not-operational mounts the blocking Auth screen', (
    WidgetTester tester,
  ) async {
    await _configure(
      storage: _Storage(_session()),
      repository: _Repository(
        onMe: (_) => Future<AuthSession>.error(_tenant()),
      ),
    );

    await _pumpAndSettle(tester);

    expect(find.byType(AuthRecoveryScreen), findsOneWidget);
    expect(find.text('Workspace temporarily unavailable'), findsOneWidget);
    expect(
      find.text('Please contact administration for assistance.'),
      findsOneWidget,
    );
  });

  testWidgets('tenant retry and logout actions work', (
    WidgetTester tester,
  ) async {
    int attempts = 0;
    final _Repository repository = _Repository(
      onMe: (AuthSession session) {
        attempts++;
        return attempts == 1
            ? Future<AuthSession>.error(_tenant())
            : Future.value(session);
      },
    );
    await _configure(storage: _Storage(_session()), repository: repository);
    await _pumpAndSettle(tester);

    await tester.tap(find.byKey(const Key('auth-retry-verification-button')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthRecoveryScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);

    await serviceLocator<AuthSessionCubit>().handleAuthenticatedFailure(
      _tenant(),
      'opaque-token',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-return-to-login-button')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(repository.logoutCalls, 1);
  });

  testWidgets('Arabic recovery is RTL and has no render overflow', (
    WidgetTester tester,
  ) async {
    await _configure(
      storage: _Storage(_expiredOfflineSession()),
      repository: _Repository(
        onMe: (_) => Future<AuthSession>.error(_offline()),
      ),
      localeCode: 'ar',
    );
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpAndSettle(tester);

    expect(
      Directionality.of(tester.element(find.byType(AuthRecoveryScreen))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _configure({
  required _Storage storage,
  required _Repository repository,
  String? localeCode,
}) async {
  await serviceLocator.reset();
  serviceLocator.registerLazySingleton<AuthSessionStorage>(() => storage);
  serviceLocator.registerLazySingleton<AuthRepository>(() => repository);
  serviceLocator.registerLazySingleton<AppLocaleRepository>(
    () => _LocaleRepository(localeCode),
  );
  setupServiceLocator(useBackend: false);
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pump();
}

Future<void> _pumpAndSettle(WidgetTester tester) async {
  await _pump(tester);
  await tester.pumpAndSettle();
}

AuthSession _session() => AuthSession(
  accessToken: 'opaque-token',
  user: const AuthUser(id: 7, name: 'Rami', role: 'manager'),
  tenant: const AuthTenant(id: 4, name: 'Cafe'),
  mustChangePassword: false,
  lastValidatedAt: DateTime.utc(2026, 9, 16, 12),
  offlineSessionMaxAgeSeconds: 43200,
);

AuthSession _expiredOfflineSession() => AuthSession(
  accessToken: 'opaque-token',
  user: const AuthUser(id: 7, name: 'Rami', role: 'manager'),
  tenant: const AuthTenant(id: 4, name: 'Cafe'),
  mustChangePassword: false,
  lastValidatedAt: DateTime.utc(2026, 9, 15),
  offlineSessionMaxAgeSeconds: 43200,
);

ApiException _offline() => const ApiException(
  message: 'unsafe',
  type: ApiErrorType.networkUnavailable,
);

ApiException _tenant() => const ApiException(
  message: 'unsafe',
  statusCode: 403,
  code: 'TENANT_NOT_OPERATIONAL',
  type: ApiErrorType.forbidden,
);

class _Storage implements AuthSessionStorage {
  _Storage(this.session);
  AuthSession? session;
  Object? writeError;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<bool> isAuthoritativelyInvalidated() async => false;

  @override
  Future<void> markAuthoritativelyInvalidated() async {}

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession next) async {
    if (writeError != null) throw writeError!;
    session = next;
  }
}

class _Repository implements AuthRepository {
  _Repository({required this.onMe});
  final Future<AuthSession> Function(AuthSession) onMe;
  int logoutCalls = 0;

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
  Future<void> logout() async => logoutCalls++;

  @override
  Future<AuthSession> me(AuthSession cachedSession) => onMe(cachedSession);
}

class _LocaleRepository implements AppLocaleRepository {
  _LocaleRepository(this.localeCode);
  final String? localeCode;

  @override
  Future<String?> loadLocaleCode() async => localeCode;

  @override
  Future<bool> saveLocaleCode(String localeCode) async => true;
}
