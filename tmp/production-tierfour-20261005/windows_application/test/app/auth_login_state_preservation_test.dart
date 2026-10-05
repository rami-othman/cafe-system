import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/auth/views/auth_splash_screen.dart';
import 'package:windows_application/features/auth/views/change_password_screen.dart';
import 'package:windows_application/features/auth/views/login_screen.dart';

void main() {
  tearDown(() async => serviceLocator.reset());

  testWidgets('App preserves the Login form through a pending invalid login', (
    WidgetTester tester,
  ) async {
    final Completer<AuthSession> pendingLogin = Completer<AuthSession>();
    final _Repository repository = _Repository(pendingLogin: pendingLogin);
    await _configureApp(repository: repository, storage: _Storage());
    await _pumpApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('auth-identifier-field')),
      'cashier',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'password',
    );
    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AuthSplashScreen), findsNothing);
    expect(_field(tester, 'auth-identifier-field').controller?.text, 'cashier');
    expect(repository.loginCalls, 1);

    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pump();
    expect(repository.loginCalls, 1);

    pendingLogin.completeError(
      const ApiException(
        message: 'unsafe invalid credential detail',
        statusCode: 401,
        type: ApiErrorType.unauthenticated,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AuthSplashScreen), findsNothing);
    expect(_field(tester, 'auth-identifier-field').controller?.text, 'cashier');
    expect(_field(tester, 'auth-password-field').controller?.text, isEmpty);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('auth-password-field')),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(
      find.text('The email, username, or password is incorrect.'),
      findsOneWidget,
    );
    expect(find.text('unsafe invalid credential detail'), findsNothing);
  });

  testWidgets('App returns to Login after password change session-save failure', (
    WidgetTester tester,
  ) async {
    final _Storage storage = _Storage(failWritesAfter: 1);
    final _Repository repository = _Repository(mustChangePassword: true);
    await _configureApp(repository: repository, storage: storage);
    await _pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('auth-identifier-field')),
      'cashier',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'password',
    );
    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsOneWidget);

    await tester.enterText(
      _passwordField('auth-current-password-field'),
      'old',
    );
    await tester.enterText(
      _passwordField('auth-new-password-field'),
      'new-password',
    );
    await tester.enterText(
      _passwordField('auth-confirm-password-field'),
      'new-password',
    );
    await tester.tap(
      find.byKey(const Key('auth-change-password-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(
      find.text(
        'Your password was changed, but we could not save this session. Please log in again using your new password.',
      ),
      findsOneWidget,
    );
    expect(find.text('The current password is incorrect.'), findsNothing);
    expect(repository.logoutCalls, 1);
  });
}

Future<void> _configureApp({
  required _Repository repository,
  required _Storage storage,
}) async {
  await serviceLocator.reset();
  serviceLocator.registerLazySingleton<AuthRepository>(() => repository);
  serviceLocator.registerLazySingleton<AuthSessionStorage>(() => storage);
  setupServiceLocator(useBackend: false);
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

TextFormField _field(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key)));

Finder _passwordField(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

class _Repository implements AuthRepository {
  _Repository({this.pendingLogin, this.mustChangePassword = false});

  final Completer<AuthSession>? pendingLogin;
  final bool mustChangePassword;
  int loginCalls = 0;
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
  }) async {
    loginCalls++;
    if (pendingLogin != null) return pendingLogin!.future;
    return _session(mustChangePassword: mustChangePassword);
  }

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<AuthSession> me(AuthSession cachedSession) async => cachedSession;
}

class _Storage implements AuthSessionStorage {
  _Storage({this.failWritesAfter});

  final int? failWritesAfter;
  int writeCalls = 0;
  AuthSession? session;

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
    if (failWritesAfter != null && writeCalls >= failWritesAfter!) {
      throw StateError('unsafe storage exception');
    }
    writeCalls++;
    session = next;
  }
}

AuthSession _session({required bool mustChangePassword}) => AuthSession(
  accessToken: 'opaque-token',
  user: const AuthUser(id: 7, name: 'Rami', role: 'manager'),
  tenant: const AuthTenant(id: 4, name: 'Cafe 618'),
  mustChangePassword: mustChangePassword,
  lastValidatedAt: DateTime.utc(2026, 9, 1, 10),
  offlineSessionMaxAgeSeconds: 43200,
);
