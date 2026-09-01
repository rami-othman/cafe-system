import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/features/auth/views/login_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'login uses auth-only identifier, password, and Log In controls',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en')],
          home: BlocProvider<AuthSessionCubit>(
            create: (_) => AuthSessionCubit(
              repository: _NoopRepository(),
              storage: _NoopStorage(),
              apiClient: DioApiClient(),
            ),
            child: const LoginScreen(),
          ),
        ),
      );

      expect(find.text('Email or Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.textContaining('Shift'), findsNothing);
      expect(find.byKey(const Key('auth-identifier-field')), findsOneWidget);
      expect(find.byKey(const Key('auth-password-field')), findsOneWidget);
    },
  );
}

class _NoopRepository implements AuthRepository {
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<AuthSession> me(AuthSession cachedSession) =>
      throw UnimplementedError();
}

class _NoopStorage implements AuthSessionStorage {
  @override
  Future<void> clear() async {}
  @override
  Future<AuthSession?> read() async => null;
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Stream<void> get changes => const Stream<void>.empty();
}
