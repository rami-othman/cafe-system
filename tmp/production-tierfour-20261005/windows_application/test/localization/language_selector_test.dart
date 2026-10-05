import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/localization/app_locale_cubit.dart';
import 'package:windows_application/app/localization/app_locale_repository.dart';
import 'package:windows_application/app/localization/app_locale_state.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/orders/controllers/orders_cubit.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/shared/widgets/app_top_bar.dart';

void main() {
  testWidgets(
    'language selector changes the UI locale and requests persistence',
    (WidgetTester tester) async {
      final _RecordingLocaleRepository repository =
          _RecordingLocaleRepository();
      final AppLocaleCubit localeCubit = AppLocaleCubit(
        repository: repository,
        systemLocale: () => const Locale('en'),
      );

      await tester.pumpWidget(
        BlocProvider<AppLocaleCubit>.value(
          value: localeCubit,
          child: BlocBuilder<AppLocaleCubit, AppLocaleState>(
            builder: (BuildContext context, AppLocaleState state) =>
                MaterialApp(
                  locale: state.locale,
                  supportedLocales: AppLocaleCubit.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  theme: AppTheme.lightTheme,
                  home: BlocProvider<OrdersCubit>(
                    create: (_) =>
                        OrdersCubit(repository: const OrdersRepository()),
                    child: const Scaffold(body: AppTopBar()),
                  ),
                ),
          ),
        ),
      );

      expect(find.byKey(const Key('app-language-selector')), findsOneWidget);
      await tester.tap(find.byKey(const Key('app-language-selector')));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsAtLeastNWidgets(1));
      expect(find.text('العربية'), findsOneWidget);

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(localeCubit.state.locale, AppLocaleCubit.arabic);
      expect(repository.savedCode, 'ar');
      expect(
        Directionality.of(tester.element(find.byType(AppTopBar))),
        TextDirection.rtl,
      );
    },
  );
}

class _RecordingLocaleRepository implements AppLocaleRepository {
  String? savedCode;

  @override
  Future<String?> loadLocaleCode() async => null;

  @override
  Future<bool> saveLocaleCode(String localeCode) async {
    savedCode = localeCode;
    return true;
  }
}
