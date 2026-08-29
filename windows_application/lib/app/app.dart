import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/app_localizations.dart';
import 'localization/app_locale_cubit.dart';
import 'localization/app_locale_state.dart';
import '../core/theme/app_theme.dart';
import '../core/services/service_locator.dart';
import '../core/navigation/unsaved_navigation_guard.dart';
import 'app_router.dart';

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
    return BlocProvider<AppLocaleCubit>(
      create: (_) => serviceLocator<AppLocaleCubit>()..loadInitialLocale(),
      child: BlocBuilder<AppLocaleCubit, AppLocaleState>(
        builder: (BuildContext context, AppLocaleState state) {
          return UnsavedNavigationScope(
            controller: _unsavedNavigation,
            child: MaterialApp.router(
              title: 'Cafe System 618',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              locale: state.locale,
              supportedLocales: AppLocaleCubit.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              routerConfig: appRouter,
            ),
          );
        },
      ),
    );
  }
}
