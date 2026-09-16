import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/models/available_discount.dart';
import 'package:windows_application/features/pos/widgets/discount_dialog.dart';

void main() {
  testWidgets('discount dialog does not overflow in compact layouts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(280, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DiscountDialog(subtotal: 12))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Apply Discount'), findsOneWidget);
    expect(find.text('Available Discounts'), findsOneWidget);
    expect(find.byKey(const Key('pos-discount-search-field')), findsOneWidget);
    expect(find.text('Morning Rush'), findsNothing);
    expect(
      find.text('No discounts are available for this order.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('search filters only server-provided available discounts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DiscountDialog(
            subtotal: 100,
            availableDiscounts: <AvailableDiscount>[
              AvailableDiscount(
                id: '101',
                backendId: 101,
                title: 'Morning Coffee',
                subtitle: 'Manual policy',
                badgeLabel: '10% OFF',
                type: AvailableDiscountType.percentage,
                value: 10,
              ),
              AvailableDiscount(
                id: '102',
                backendId: 102,
                title: 'Member Saving',
                subtitle: 'Branch policy',
                badgeLabel: '500 SYP',
                type: AvailableDiscountType.fixedAmount,
                value: 500,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('pos-discount-search-field')),
        matching: find.byType(TextField),
      ),
      'member',
    );
    await tester.pump();

    expect(find.text('Member Saving'), findsOneWidget);
    expect(find.text('Morning Coffee'), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('pos-discount-search-field')),
        matching: find.byType(TextField),
      ),
      'missing',
    );
    await tester.pump();
    expect(find.text('No discounts match your search.'), findsOneWidget);
  });
}
