import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Finance has a real Arabic navigation label', () async {
    final AppLocalizations arabic = await AppLocalizations.delegate.load(
      const Locale('ar'),
    );
    final AppLocalizations english = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    expect(arabic.navigationFinance, 'المالية');
    expect(english.navigationFinance, 'Finance');
  });

  testWidgets(
    'Finance is a first-class RTL sidebar destination, localized in Arabic',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 320,
              height: 900,
              child: AppSidebar(activeLabel: 'finance'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المالية'), findsOneWidget);
      expect(find.text('Finance'), findsNothing);
      expect(
        find.byIcon(Icons.account_balance_wallet_outlined),
        findsOneWidget,
      );
    },
  );
}
