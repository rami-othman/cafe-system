import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/widgets/coupon_code_input.dart';

void main() {
  testWidgets('keeps apply button label on one line', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 404,
              child: CouponCodeInput(controller: controller, onApply: () {}),
            ),
          ),
        ),
      ),
    );

    final Text applyText = tester.widget<Text>(find.text('Apply'));

    expect(applyText.maxLines, 1);
    expect(applyText.softWrap, isFalse);
  });

  testWidgets('stacks input and apply button in narrow layouts', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              child: CouponCodeInput(controller: controller, onApply: () {}),
            ),
          ),
        ),
      ),
    );

    final Offset inputTopLeft = tester.getTopLeft(find.byType(TextField));
    final Offset applyTopLeft = tester.getTopLeft(find.text('Apply'));

    expect(applyTopLeft.dy, greaterThan(inputTopLeft.dy));
  });
}
