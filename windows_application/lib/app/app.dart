import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/app_localizations.dart';
import 'localization/app_locale_cubit.dart';
import 'localization/app_locale_state.dart';
import '../core/theme/app_theme.dart';
import '../core/services/service_locator.dart';
import 'app_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppLocaleCubit>(
      create: (_) => serviceLocator<AppLocaleCubit>()..loadInitialLocale(),
      child: BlocBuilder<AppLocaleCubit, AppLocaleState>(
        builder: (BuildContext context, AppLocaleState state) {
          return MaterialApp.router(
            title: 'Cafe System 618',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: state.locale,
            supportedLocales: AppLocaleCubit.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
