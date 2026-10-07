import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/shift/widgets/shift_primitives.dart';

void main() {
  Future<TestGesture> mouse(WidgetTester tester) async {
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: const Offset(700, 500));
    addTearDown(gesture.removePointer);
    return gesture;
  }

  Future<void> pumpRows(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            ShiftKeyValueRow(label: 'first', value: '1', hint: 'hint one'),
            ShiftKeyValueRow(label: 'second', value: '2', hint: 'hint two'),
          ],
        ),
      ),
    ),
  );

  testWidgets('hint appears only after the full delay', (tester) async {
    await pumpRows(tester);
    final TestGesture gesture = await mouse(tester);
    await gesture.moveTo(tester.getCenter(find.text('first')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('hint one'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('hint one'), findsOneWidget);
  });

  testWidgets('moving to another row restarts the delay', (tester) async {
    await pumpRows(tester);
    final TestGesture gesture = await mouse(tester);
    await gesture.moveTo(tester.getCenter(find.text('first')));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('hint one'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('second')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('hint one'), findsNothing);
    expect(find.text('hint two'), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('hint two'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('hint two'), findsOneWidget);
  });

  testWidgets('leaving before the delay cancels the hint', (tester) async {
    await pumpRows(tester);
    final TestGesture gesture = await mouse(tester);
    await gesture.moveTo(tester.getCenter(find.text('first')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(const Offset(700, 500));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('hint one'), findsNothing);
  });
}
