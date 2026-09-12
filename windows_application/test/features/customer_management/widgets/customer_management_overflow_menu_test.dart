import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:windows_application/features/customer_management/widgets/customer_management_overflow_menu.dart';

void main() {
  testWidgets(
    'renders only caller-authorized actions and does not leak row taps',
    (WidgetTester tester) async {
      bool rowTapped = false;
      bool viewed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkWell(
              onTap: () => rowTapped = true,
              child: CustomerManagementOverflowMenu(
                tooltip: 'More actions',
                actions: <CustomerManagementMenuEntry>[
                  CustomerManagementMenuEntry(
                    label: 'View',
                    icon: Icons.visibility_outlined,
                    onPressed: () => viewed = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('View'));
      expect(viewed, isTrue);
      expect(rowTapped, isFalse);
    },
  );

  testWidgets('supports escape dismissal and restores focus to the trigger', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomerManagementOverflowMenu(
            tooltip: 'More actions',
            actions: <CustomerManagementMenuEntry>[],
          ),
        ),
      ),
    );
    final Finder trigger = find.byTooltip('More actions');
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
  });
}
