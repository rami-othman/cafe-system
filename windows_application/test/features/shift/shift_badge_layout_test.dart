import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/shift/widgets/shift_primitives.dart';
import 'package:windows_application/features/shift/widgets/shift_strings.dart';

void main() {
  testWidgets('Arabic status badge wraps inside a narrow table cell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 102.5,
                child: Center(
                  child: ShiftBadge(
                    label: ShiftStrings.statusUncounted,
                    tone: ShiftTone.neutral,
                    dense: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(ShiftStrings.statusUncounted), findsOneWidget);
    expect(
      tester.getSize(find.text(ShiftStrings.statusUncounted)).height,
      greaterThan(14),
    );
  });
}
