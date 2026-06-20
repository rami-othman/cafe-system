import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/core/services/service_locator.dart';

void main() {
  testWidgets('opens Orders from sidebar and hides POS cart panel', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
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

  testWidgets('opens and closes order details panel from an order card', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DETAILS').first);
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Order Items'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsWidgets);

    await tester.tap(find.byTooltip('Close order details'));
    await tester.pumpAndSettle();

    expect(find.text('Order Items'), findsNothing);
  });

  testWidgets('opens refund dialog and validates partial amount', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DETAILS').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refund'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Refund Order #ORD-1042'), findsOneWidget);
    expect(find.text('Full Refund'), findsOneWidget);
    expect(find.text('Partial Refund'), findsOneWidget);
    expect(find.text('Confirm Refund'), findsOneWidget);

    await tester.tap(find.text('Partial Refund'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('refundAmountInput')),
      '999',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Refund amount cannot exceed order total.'),
      findsOneWidget,
    );
    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirm Refund'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('confirming full refund updates order details panel', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DETAILS').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refund'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Refund'));
    await tester.pumpAndSettle();

    expect(find.text('REFUNDED'), findsOneWidget);
    expect(find.text('Refunded'), findsWidgets);
    expect(find.text('Refund recorded locally.'), findsOneWidget);
  });
}

Future<void> _setupTestLocator() async {
  await serviceLocator.reset();
  setupServiceLocator(useBackend: false);
}
