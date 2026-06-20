import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/core/services/service_locator.dart';

void main() {
  testWidgets('opens Orders from sidebar and hides POS cart panel', (
    WidgetTester tester,
  ) async {
    setupServiceLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('PAY \$0.00'), findsOneWidget);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Order Management'), findsOneWidget);
    expect(
      find.text('View and manage all active, held, and recent orders.'),
      findsOneWidget,
    );
    expect(find.text('PAY \$0.00'), findsNothing);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
    expect(find.text('Walk-in 4'), findsNothing);

    await tester.tap(find.text('HELD ORDERS'));
    await tester.pumpAndSettle();

    expect(find.text('Sarah Jenkins'), findsNothing);
    expect(find.text('Walk-in 4'), findsOneWidget);

    await tester.tap(find.text('RESUME'));
    await tester.pump();

    expect(
      find.text('Resume held order will be connected to POS later.'),
      findsOneWidget,
    );

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();

    expect(find.text('Search products...'), findsOneWidget);
    expect(find.text('PAY \$0.00'), findsOneWidget);
  });
}
