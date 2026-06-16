import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Cancel'), findsOneWidget);
  });
}
