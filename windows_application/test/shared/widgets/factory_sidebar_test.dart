import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

void main() {
  testWidgets(
    'factory shows existing purchasing and sales and hides cafe operations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSidebar(
              activeLabel: 'manufacturing',
              actorRole: 'owner',
              isFactory: true,
              financeCapabilities: <String>{
                'finance.purchases.view',
                'finance.sales.view',
              },
              manufacturingCapabilities: <String>{'manufacturing.view'},
            ),
          ),
        ),
      );
      expect(find.text('المشتريات'), findsOneWidget);
      expect(find.text('المبيعات'), findsOneWidget);
      expect(find.text('التصنيع'), findsOneWidget);
      expect(find.text('POS'), findsNothing);
      expect(find.text('Orders'), findsNothing);
      expect(find.text('Menu Management'), findsNothing);
    },
  );

  testWidgets('factory financial links require server permissions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppSidebar(
            activeLabel: 'manufacturing',
            actorRole: 'manager',
            isFactory: true,
          ),
        ),
      ),
    );
    expect(find.text('المشتريات'), findsNothing);
    expect(find.text('المبيعات'), findsNothing);
  });
}
