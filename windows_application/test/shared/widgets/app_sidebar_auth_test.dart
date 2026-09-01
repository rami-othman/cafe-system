import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

void main() {
  testWidgets('Employee does not see Menu Management but retains Reports', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'employee');

    expect(find.text('Menu Management'), findsNothing);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('Cashier does not see Menu Management but retains Reports', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'cashier');

    expect(find.text('Menu Management'), findsNothing);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('Owner sees Menu Management and retains Reports', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'owner');

    expect(find.text('Menu Management'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('Manager sees Menu Management and retains Reports', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'manager');

    expect(find.text('Menu Management'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
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
