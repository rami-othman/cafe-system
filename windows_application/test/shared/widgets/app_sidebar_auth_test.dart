import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

void main() {
  testWidgets('Employee and Cashier do not see Menu Management navigation', (
    WidgetTester tester,
  ) async {
    for (final String role in <String>['employee', 'cashier']) {
      await _pumpSidebar(tester, role);
      expect(find.text('Menu Management'), findsNothing);
      expect(find.text('Reports'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Owner and Manager see Menu Management navigation', (
    WidgetTester tester,
  ) async {
    for (final String role in <String>['owner', 'manager']) {
      await _pumpSidebar(tester, role);
      expect(find.text('Menu Management'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Future<void> _pumpSidebar(WidgetTester tester, String role) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppSidebar(activeLabel: 'POS', actorRole: role),
      ),
    ),
  );
  await tester.pump();
}
