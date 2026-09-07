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

  testWidgets('Owner sees Cafe Configuration', (WidgetTester tester) async {
    await _pumpSidebar(tester, 'owner');

    expect(find.text('Cafe Configuration'), findsOneWidget);
  });

  testWidgets('Manager does not see Cafe Configuration', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'manager');

    expect(find.text('Cafe Configuration'), findsNothing);
  });

  testWidgets('Employee does not see Cafe Configuration', (
    WidgetTester tester,
  ) async {
    await _pumpSidebar(tester, 'employee');

    expect(find.text('Cafe Configuration'), findsNothing);
  });
}

Future<void> _pumpSidebar(WidgetTester tester, String role) async {
  // Explicit, tall-enough surface: the default test surface is too short to
  // mount every sidebar item's Element (ListView/Sliver virtualization only
  // builds what's within the viewport + cache extent) now that the owner
  // role's item count grew with Cafe Configuration — without this, `find`
  // can miss items pushed past the cache extent, not because they're absent.
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppSidebar(activeLabel: 'POS', actorRole: role),
      ),
    ),
  );
  await tester.pump();
}
