import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/auth/views/change_password_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('change password shows each safe validation error on its field', (
    WidgetTester tester,
  ) async {
    final _Repository repository = _Repository(
      changeError: const ApiException(
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
    final AuthSessionCubit cubit = await _mustChangeCubit(repository);
    await _pump(tester, cubit);
    await _enterPasswords(tester);

    await tester.tap(
      find.byKey(const Key('auth-change-password-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('The current password is incorrect.'), findsOneWidget);
    expect(find.text('Choose a stronger new password.'), findsOneWidget);
    expect(
      find.text('The password confirmation does not match.'),
      findsOneWidget,
    );
    expect(find.text('unsafe backend detail'), findsNothing);
  });

  testWidgets('change password network failures appear as a form error', (
    WidgetTester tester,
  ) async {
    final AuthSessionCubit cubit = await _mustChangeCubit(
      _Repository(
        changeError: const ApiException(
          message: 'unsafe',
          type: ApiErrorType.networkUnavailable,
        ),
      ),
    );
    await _pump(tester, cubit);
    await _enterPasswords(tester);

    await tester.tap(
      find.byKey(const Key('auth-change-password-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'We cannot connect to the server. Check your network connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('auth-error-banner')), findsOneWidget);
  });

  testWidgets('change password submission cannot be duplicated', (
    WidgetTester tester,
  ) async {
    final Completer<void> pending = Completer<void>();
    final _Repository repository = _Repository(pendingChange: pending);
    final AuthSessionCubit cubit = await _mustChangeCubit(repository);
    await _pump(tester, cubit);
    await _enterPasswords(tester);

    await tester.tap(
      find.byKey(const Key('auth-change-password-submit-button')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('auth-change-password-submit-button')),
    );
    await tester.pump();

    expect(repository.changeCalls, 1);
    expect(find.text('Saving password…'), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
  });
}

Future<AuthSessionCubit> _mustChangeCubit(_Repository repository) async {
  final AuthSessionCubit cubit = AuthSessionCubit(
    repository: repository,
    storage: _Storage(),
    apiClient: DioApiClient(),
  );
  await cubit.login(identifier: 'cashier', password: 'password');
  return cubit;
}

Future<void> _pump(WidgetTester tester, AuthSessionCubit cubit) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en')],
      home: BlocProvider<AuthSessionCubit>.value(
        value: cubit,
        child: const ChangePasswordScreen(),
      ),
    ),
  );
}

Finder _passwordField(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

Future<void> _enterPasswords(WidgetTester tester) async {
  await tester.enterText(
    _passwordField('auth-current-password-field'),
    'old-password',
  );
  await tester.enterText(
    _passwordField('auth-new-password-field'),
    'new-password',
  );
  await tester.enterText(
    _passwordField('auth-confirm-password-field'),
    'new-password',
  );
}

AuthSession _session() => AuthSession(
  accessToken: 'opaque-token',
  user: const AuthUser(id: 7, name: 'Rami', role: 'manager'),
  tenant: const AuthTenant(id: 4, name: 'Cafe 618'),
  mustChangePassword: true,
  lastValidatedAt: DateTime.utc(2026, 9, 1, 10),
  offlineSessionMaxAgeSeconds: 43200,
);

class _Repository implements AuthRepository {
  _Repository({this.changeError, this.pendingChange});

  final Object? changeError;
  final Completer<void>? pendingChange;
  int changeCalls = 0;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changeCalls++;
    if (pendingChange != null) await pendingChange!.future;
    if (changeError != null) throw changeError!;
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async => _session();

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
