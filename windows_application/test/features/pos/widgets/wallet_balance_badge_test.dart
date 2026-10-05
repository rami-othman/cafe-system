import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/widgets/wallet_balance_badge.dart';
import 'package:windows_application/l10n/app_localizations.dart';

Widget _host(double? balance) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: WalletBalanceBadge(balance: balance)),
);

void main() {
  testWidgets('shows the credit a customer holds', (WidgetTester tester) async {
    await tester.pumpWidget(_host(75.5));
    expect(find.text('Balance 75.5 SYP'), findsOneWidget);
  });

  testWidgets('shows what a customer owes', (WidgetTester tester) async {
    await tester.pumpWidget(_host(-20));
    expect(find.text('Owes 20 SYP'), findsOneWidget);
  });

  testWidgets('renders nothing for zero or unknown balances', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(0));
    expect(find.byType(Text), findsNothing);
    await tester.pumpWidget(_host(null));
    expect(find.byType(Text), findsNothing);
  });
}
