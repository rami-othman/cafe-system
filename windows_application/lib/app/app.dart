import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/app_localizations.dart';
import 'localization/app_locale_cubit.dart';
import 'localization/app_locale_state.dart';
import '../core/theme/app_theme.dart';
import '../core/services/service_locator.dart';
import '../core/navigation/unsaved_navigation_guard.dart';
import 'app_router.dart';
import '../features/auth/controllers/auth_session_cubit.dart';
import '../features/auth/controllers/auth_session_state.dart';
import '../features/auth/views/auth_splash_screen.dart';
import '../features/auth/views/change_password_screen.dart';
import '../features/auth/views/login_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final UnsavedNavigationController _unsavedNavigation =
      UnsavedNavigationController();

  @override
  void dispose() {
    _unsavedNavigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AppLocaleCubit>(
          create: (_) => serviceLocator<AppLocaleCubit>()..loadInitialLocale(),
        ),
        BlocProvider<AuthSessionCubit>(
          create: (_) => serviceLocator<AuthSessionCubit>()..restore(),
        ),
      ],
      child: BlocBuilder<AppLocaleCubit, AppLocaleState>(
        builder: (BuildContext context, AppLocaleState state) {
          return UnsavedNavigationScope(
            controller: _unsavedNavigation,
            child: BlocBuilder<AuthSessionCubit, AuthSessionState>(
              builder: (BuildContext context, AuthSessionState auth) =>
                  _buildApp(state, auth),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApp(AppLocaleState locale, AuthSessionState auth) {
    final Widget home = switch (auth.status) {
      AuthSessionStatus.restoring ||
      AuthSessionStatus.submitting => const AuthSplashScreen(),
      AuthSessionStatus.unauthenticated => LoginScreen(message: auth.message),
      AuthSessionStatus.mustChangePassword => const ChangePasswordScreen(),
      AuthSessionStatus.authenticated => const SizedBox.shrink(),
    };
    if (auth.status == AuthSessionStatus.authenticated) {
      return MaterialApp.router(
        title: 'Cafe System 618',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: locale.locale,
        supportedLocales: AppLocaleCubit.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: appRouter,
      );
    }
    return MaterialApp(
      title: 'Cafe System 618',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: locale.locale,
      supportedLocales: AppLocaleCubit.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );
  }
}
