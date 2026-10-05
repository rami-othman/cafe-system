import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/auth/views/login_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('login uses auth-only identifier, password, and controls', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(tester, _cubit(_AuthTestRepository()));

    expect(find.text('Email or Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.textContaining('Shift'), findsNothing);
    expect(find.byKey(const Key('auth-identifier-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-password-field')), findsOneWidget);
  });

  testWidgets('login stays mounted while loading and prevents duplicates', (
    WidgetTester tester,
  ) async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    final _AuthTestRepository repository = _AuthTestRepository(
      pendingLogin: pending,
    );
    await _pumpLogin(tester, _cubit(repository));
    await _enterCredentials(tester);

    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Logging in…'), findsOneWidget);
    expect(repository.loginCalls, 1);
    expect(_field(tester, 'auth-identifier-field').enabled, isFalse);

    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pump();
    expect(repository.loginCalls, 1);

    pending.complete(_session());
    await tester.pumpAndSettle();
  });

  testWidgets('invalid credentials retain identifier and clear password', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(
      tester,
      _cubit(
        _AuthTestRepository(
          loginError: const ApiException(
            message: 'unsafe server detail',
            statusCode: 401,
            type: ApiErrorType.unauthenticated,
          ),
        ),
      ),
    );
    await _enterCredentials(tester);

    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('The email, username, or password is incorrect.'),
      findsOneWidget,
    );
    expect(_field(tester, 'auth-identifier-field').controller?.text, 'cashier');
    expect(_field(tester, 'auth-password-field').controller?.text, isEmpty);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).last)
          .focusNode
          .hasFocus,
      isTrue,
    );
  });

  for (final ({ApiException error, String message}) item
      in <({ApiException error, String message})>[
        (
          error: const ApiException(
            message: 'unsafe',
            statusCode: 429,
            type: ApiErrorType.unknown,
          ),
          message:
              'Too many login attempts. Please wait a moment and try again.',
        ),
        (
          error: const ApiException(
            message: 'unsafe',
            type: ApiErrorType.networkUnavailable,
          ),
          message:
              'We cannot connect to the server. Check your network connection and try again.',
        ),
        (
          error: const ApiException(
            message: 'unsafe',
            type: ApiErrorType.connectionTimeout,
          ),
          message:
              'The connection timed out. Check your connection and try again.',
        ),
        (
          error: const ApiException(
            message: 'unsafe',
            statusCode: 503,
            type: ApiErrorType.server,
          ),
          message:
              'The service is temporarily unavailable. Please try again shortly.',
        ),
      ]) {
    testWidgets('login displays the safe localized failure: ${item.message}', (
      WidgetTester tester,
    ) async {
      await _pumpLogin(
        tester,
        _cubit(_AuthTestRepository(loginError: item.error)),
      );
      await _enterCredentials(tester);

      await tester.tap(find.byKey(const Key('auth-login-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(item.message), findsOneWidget);
      expect(find.text('unsafe'), findsNothing);
    });
  }

  testWidgets('editing a field clears its safe server error', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(
      tester,
      _cubit(
        _AuthTestRepository(
          loginError: const ApiException(
            message: 'unsafe',
            statusCode: 422,
            type: ApiErrorType.validation,
            validationErrors: <String, List<String>>{
              'identifier': <String>['unsafe'],
            },
          ),
        ),
      ),
    );
    await _enterCredentials(tester);

    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Check this value and try again.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth-identifier-field')),
      'cashier2',
    );
    await tester.pump();
    expect(find.text('Check this value and try again.'), findsNothing);
  });

  testWidgets(
    'password-only backend validation stays field-scoped and clears',
    (WidgetTester tester) async {
      await _pumpLogin(
        tester,
        _cubit(
          _AuthTestRepository(
            loginError: const ApiException(
              message: 'raw password backend detail',
              statusCode: 422,
              type: ApiErrorType.validation,
              validationErrors: <String, List<String>>{
                'password': <String>['raw password backend detail'],
              },
            ),
          ),
        ),
      );
      await _enterCredentials(tester);

      await tester.tap(find.byKey(const Key('auth-login-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Check this value and try again.'), findsOneWidget);
      expect(find.text('raw password backend detail'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'changed-password',
      );
      await tester.pump();
      expect(find.text('Check this value and try again.'), findsNothing);
    },
  );

  testWidgets('editing one login field retains the other field error', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(
      tester,
      _cubit(
        _AuthTestRepository(
          loginError: const ApiException(
            message: 'raw backend detail',
            statusCode: 422,
            type: ApiErrorType.validation,
            validationErrors: <String, List<String>>{
              'identifier': <String>['raw identifier detail'],
              'password': <String>['raw password detail'],
            },
          ),
        ),
      ),
    );
    await _enterCredentials(tester);

    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Check this value and try again.'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'changed-password',
    );
    await tester.pump();
    expect(find.text('Check this value and try again.'), findsOneWidget);
  });

  testWidgets('the login failure banner is an accessible live region', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpLogin(
      tester,
      _cubit(
        _AuthTestRepository(
          loginError: const ApiException(
            message: 'unsafe',
            statusCode: 401,
            type: ApiErrorType.unauthenticated,
          ),
        ),
      ),
    );
    await _enterCredentials(tester);

    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pumpAndSettle();

    final SemanticsNode node = tester.getSemantics(
      find.byKey(const Key('auth-error-banner')),
    );
    expect(node.label, contains('incorrect'));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('Enter from password submits once', (WidgetTester tester) async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    final _AuthTestRepository repository = _AuthTestRepository(
      pendingLogin: pending,
    );
    await _pumpLogin(tester, _cubit(repository));
    await _enterCredentials(tester);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repository.loginCalls, 1);

    pending.complete(_session());
    await tester.pumpAndSettle();
  });

  testWidgets('Arabic failure text renders RTL without overflow', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(
      tester,
      _cubit(
        _AuthTestRepository(
          loginError: const ApiException(
            message: 'unsafe',
            statusCode: 503,
            type: ApiErrorType.server,
          ),
        ),
      ),
      locale: const Locale('ar'),
    );
    await _enterCredentials(tester);

    await tester.tap(find.byKey(const Key('auth-login-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('الخدمة غير متاحة مؤقتًا. يرجى المحاولة بعد قليل.'),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.byType(LoginScreen))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLogin(
  WidgetTester tester,
  AuthSessionCubit cubit, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      home: BlocProvider<AuthSessionCubit>.value(
        value: cubit,
        child: const LoginScreen(),
      ),
    ),
  );
}

Future<void> _enterCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('auth-identifier-field')),
    'cashier',
  );
  await tester.enterText(
    find.byKey(const Key('auth-password-field')),
    'password',
  );
}

TextFormField _field(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key)));

AuthSessionCubit _cubit(AuthRepository repository) => AuthSessionCubit(
  repository: repository,
  storage: _Storage(),
  apiClient: DioApiClient(),
);

AuthSession _session() => AuthSession(
  accessToken: 'opaque-token',
  user: const AuthUser(id: 7, name: 'Rami', role: 'manager'),
  tenant: const AuthTenant(id: 4, name: 'Cafe 618'),
  mustChangePassword: false,
  lastValidatedAt: DateTime.utc(2026, 9, 1, 10),
  offlineSessionMaxAgeSeconds: 43200,
);

class _AuthTestRepository implements AuthRepository {
  _AuthTestRepository({this.loginError, this.pendingLogin});

  final Object? loginError;
  final Completer<AuthSession>? pendingLogin;
  int loginCalls = 0;

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
    if (loginError != null) throw loginError!;
    return _session();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> me(AuthSession cachedSession) async => cachedSession;
}

class _Storage implements AuthSessionStorage {
  @override
  Future<void> clear() async {}
  @override
  Future<bool> isAuthoritativelyInvalidated() async => false;
  @override
  Future<void> markAuthoritativelyInvalidated() async {}
  @override
  Stream<void> get changes => const Stream<void>.empty();
  @override
  Future<AuthSession?> read() async => null;
  @override
  Future<void> write(AuthSession session) async {}
}
