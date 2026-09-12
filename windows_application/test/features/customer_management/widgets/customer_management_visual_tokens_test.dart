import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:windows_application/features/customer_management/widgets/customer_management_visual_tokens.dart';

void main() {
  test(
    'keeps the module tokens scoped and the collection breakpoint exact',
    () {
      expect(CustomerManagementVisualTokens.collectionBreakpoint, 760);
      expect(CustomerManagementVisualTokens.usesCollectionCards(759), isTrue);
      expect(CustomerManagementVisualTokens.usesCollectionCards(760), isFalse);
      expect(CustomerManagementVisualTokens.pageBackground, isA<Color>());
      expect(
        CustomerManagementVisualTokens.surfaceRadius,
        isNot(BorderRadius.zero),
      );
      expect(
        CustomerManagementVisualTokens.minimumInteractiveSize,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets('renders a visible focus treatment within the minimum target', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusableActionDetector(
            autofocus: true,
            child: SizedBox(
              width: CustomerManagementVisualTokens.minimumInteractiveSize,
              height: CustomerManagementVisualTokens.minimumInteractiveSize,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(FocusableActionDetector)).width,
      CustomerManagementVisualTokens.minimumInteractiveSize,
    );
  });
}
