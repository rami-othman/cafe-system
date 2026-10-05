import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/shared/widgets/shift_status_badge.dart';

void main() {
  Widget buildBadge(bool isOpen, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ShiftStatusBadge(isOpen: isOpen)),
      );

  testWidgets('shows closed when no authoritative current shift exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildBadge(false));

    expect(find.text('SHIFT CLOSED'), findsOneWidget);
    expect(find.text('SHIFT OPEN'), findsNothing);
  });

  testWidgets('shows open only when an authoritative current shift exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildBadge(true));

    expect(find.text('SHIFT OPEN'), findsOneWidget);
    expect(find.text('SHIFT CLOSED'), findsNothing);
  });

  testWidgets('localizes the shift status label in Arabic with no English leakage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildBadge(false, locale: const Locale('ar')));

    expect(find.text('الوردية مغلقة'), findsOneWidget);
    expect(find.text('SHIFT CLOSED'), findsNothing);

    await tester.pumpWidget(buildBadge(true, locale: const Locale('ar')));

    expect(find.text('الوردية مفتوحة'), findsOneWidget);
    expect(find.text('SHIFT OPEN'), findsNothing);
  });
}
