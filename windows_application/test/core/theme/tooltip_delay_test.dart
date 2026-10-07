import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';

void main() {
  testWidgets('stock tooltips wait the full delay, even when sweeping', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Column(
            children: <Widget>[
              Tooltip(message: 'tip one', child: Text('one')),
              Tooltip(message: 'tip two', child: Text('two')),
            ],
          ),
        ),
      ),
    );
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(700, 500));
    addTearDown(mouse.removePointer);

    await mouse.moveTo(tester.getCenter(find.text('one')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('tip one'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('tip one'), findsOneWidget);

    await mouse.moveTo(tester.getCenter(find.text('two')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('tip two'), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('tip two'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('tip two'), findsOneWidget);
  });
}
