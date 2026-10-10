import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/cafe_configuration/controllers/discount_settings_cubit.dart';
import 'package:windows_application/features/cafe_configuration/models/discount_settings.dart';
import 'package:windows_application/features/cafe_configuration/views/discount_settings_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'discount_settings_test.dart' show SettingsFake;

/// Automatic promotions in the Cafe Discount Policy screen.
void main() {
  Future<(DiscountSettingsCubit, SettingsFake, AppLocalizations)> pump(
    WidgetTester tester, {
    required bool engineReady,
    String language = 'en',
  }) async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final r = SettingsFake()
      ..current = SavedDiscountSettings(
        draft: const DiscountSettingsDraft(allowAutomaticSuppression: false),
        version: 3,
        engineReady: engineReady,
      );
    final c = DiscountSettingsCubit(r);
    await c.load();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: c),
          BlocProvider.value(value: serviceLocator<AuthSessionCubit>()),
        ],
        child: MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DiscountSettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(DiscountSettingsScreen)),
    );
    return (c, r, l);
  }

  SwitchListTile tile(WidgetTester tester, String key) =>
      tester.widget<SwitchListTile>(find.byKey(Key(key)));

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language turning promotions on saves the switch and keeps the removal rule',
      (tester) async {
        final (c, r, l) = await pump(
          tester,
          engineReady: true,
          language: language,
        );
        expect(find.text(l.ds5Automatic), findsWidgets);
        expect(tile(tester, 'ds-automatic-enabled').value, false);
        // The removal rule is kept but inactive while promotions are off.
        expect(tile(tester, 'ds-allow-suppression').onChanged, isNull);

        await tap(tester, 'ds-automatic-enabled');
        expect(c.state.draft.automaticEnabled, true);
        expect(tile(tester, 'ds-allow-suppression').onChanged, isNotNull);
        await tap(tester, 'ds-allow-suppression');
        expect(c.state.draft.allowAutomaticSuppression, true);
        await tap(tester, 'ds-save');

        final body = r.writes.single;
        expect(body['automaticEnabled'], true);
        expect(body['allowAutomaticSuppression'], true);
        expect(c.state.dirty, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await c.close();
      },
    );
  }

  testWidgets('an older backend cannot turn promotions on', (tester) async {
    final (c, _, _) = await pump(tester, engineReady: false);
    expect(tile(tester, 'ds-automatic-enabled').onChanged, isNull);
    await tester.pumpWidget(const SizedBox());
    await c.close();
  });

  testWidgets('reset turns promotions off and restores the removal default', (
    tester,
  ) async {
    final (c, _, _) = await pump(tester, engineReady: true);
    await tap(tester, 'ds-automatic-enabled');
    await tap(tester, 'ds-reset');
    expect(c.state.draft.automaticEnabled, false);
    expect(c.state.draft.allowAutomaticSuppression, true);
    await tester.pumpWidget(const SizedBox());
    await c.close();
  });
}
