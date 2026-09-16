import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_module_tabs.dart';

void main() {
  testWidgets(
    'reflects route-derived selection and invokes the existing list target',
    (WidgetTester tester) async {
      bool? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomerManagementModuleTabs(
              groupsSelected: false,
              onSelectionChanged: (bool value) => selected = value,
            ),
          ),
        ),
      );

      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Customer Groups'), findsOneWidget);
      await tester.tap(find.text('Customer Groups'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
    },
  );

  testWidgets('mirrors cleanly in RTL without changing selected identity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CustomerManagementModuleTabs(groupsSelected: true),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Customer Groups'), findsOneWidget);
  });
}
