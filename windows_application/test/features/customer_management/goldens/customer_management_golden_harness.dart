import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'package:windows_application/app/app_shell.dart';
import 'package:windows_application/app/localization/app_locale_cubit.dart';
import 'package:windows_application/app/localization/app_locale_repository.dart';
import 'package:windows_application/app/localization/app_locale_state.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/auth/controllers/auth_session_state.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_repository.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_scaffold.dart';

/// Shared deterministic wrapper for Customer Management golden tests.
///
/// The widget-test renderer remains the authority for these baselines. The
/// harness fixes locale, direction, viewport, DPR, theme font, and animations
/// without making test fixtures reachable from production code.
abstract final class CustomerManagementGoldenHarness {
  static Future<void>? _fonts;

  static Future<void> loadFonts() {
    return _fonts ??= _loadFonts();
  }

  static Future<void> _loadFonts() async {
    final FontLoader manrope = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-SemiBold.ttf'));
    final FontLoader arabic = FontLoader('IBMPlexSansArabic')
      ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf'));
    await Future.wait<void>(<Future<void>>[manrope.load(), arabic.load()]);
  }

  static Widget wrap(
    Widget child, {
    required Size size,
    required Locale locale,
    required TextDirection direction,
    bool groupsSelected = false,
  }) => MediaQuery(
    data: MediaQueryData(size: size, devicePixelRatio: 1),
    child: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AppLocaleCubit>(create: (_) => _GoldenLocaleCubit(locale)),
        BlocProvider<AuthSessionCubit>(
          create: (_) => _GoldenAuthSessionCubit(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: locale.languageCode == 'ar'
              ? 'IBMPlexSansArabic'
              : 'Manrope',
        ),
        home: Directionality(
          textDirection: direction,
          child: AppShell(
            activeLabel: 'customers',
            child: CustomerManagementScaffold(
              groupsSelected: groupsSelected,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class _GoldenLocaleCubit extends AppLocaleCubit {
  _GoldenLocaleCubit(Locale locale)
    : super(repository: const _GoldenLocaleRepository()) {
    emit(AppLocaleState(locale: locale, isLoaded: true));
  }
}

class _GoldenLocaleRepository implements AppLocaleRepository {
  const _GoldenLocaleRepository();

  @override
  Future<String?> loadLocaleCode() async => null;

  @override
  Future<bool> saveLocaleCode(String localeCode) async => true;
}

class _GoldenAuthSessionCubit extends AuthSessionCubit {
  _GoldenAuthSessionCubit()
    : super(
        repository: const _GoldenAuthRepository(),
        storage: MemoryAuthSessionStorage(),
        apiClient: DioApiClient(),
      ) {
    emit(
      AuthSessionState(
        status: AuthSessionStatus.authenticated,
        session: AuthSession(
          accessToken: 'golden-test-token',
          user: const AuthUser(
            id: 7,
            name: 'Golden Reviewer',
            role: 'owner',
            email: 'golden@example.test',
          ),
          tenant: const AuthTenant(id: 4, name: 'Cafe 618'),
          mustChangePassword: false,
          lastValidatedAt: DateTime.utc(2026, 9, 12),
          offlineSessionMaxAgeSeconds: 43200,
          customerManagementAllowed: true,
        ),
      ),
    );
  }
}

class _GoldenAuthRepository implements AuthRepository {
  const _GoldenAuthRepository();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async => throw UnsupportedError('Golden auth does not login.');

  @override
  Future<AuthSession> me(AuthSession cachedSession) async => cachedSession;

  @override
  Future<void> logout() async {}
}
