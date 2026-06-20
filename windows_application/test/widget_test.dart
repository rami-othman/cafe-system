import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/core/services/service_locator.dart';

void main() {
  testWidgets('shows the initial POS route', (WidgetTester tester) async {
    await _setupTestLocator();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('Cafe System 618'), findsOneWidget);
    expect(find.text('DOWNTOWN'), findsOneWidget);
    expect(find.text('SHIFT OPEN'), findsOneWidget);
    expect(find.text('Search products...'), findsOneWidget);
    expect(find.text('COFFEE'), findsOneWidget);
    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text('DINE-IN'), findsOneWidget);
    expect(find.text('Cappuccino'), findsOneWidget);
    expect(find.text('PAY \$0.00'), findsOneWidget);

    await tester.tap(find.text('Espresso'));
    await tester.pumpAndSettle();

    expect(find.text('Customize Item'), findsOneWidget);
    await tester.tap(find.text('Add to Order'));
    await tester.pumpAndSettle();

    expect(find.text('Espresso'), findsNWidgets(2));
    expect(find.text('PAY \$3.78'), findsOneWidget);
  });

  testWidgets('adapts the POS shell across desktop breakpoints', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();

    await _pumpAtSize(tester, const Size(1280, 800));
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('PAY \$0.00'), findsOneWidget);

    await _pumpAtSize(tester, const Size(1000, 800));
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('PAY \$0.00'), findsOneWidget);

    await _pumpAtSize(tester, const Size(820, 760));
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('PAY \$0.00'), findsNothing);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('does not overflow in very compact windows', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();

    await _pumpAtSize(tester, const Size(360, 420));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    expect(find.text('PAY \$0.00'), findsNothing);

    await _pumpAtSize(tester, const Size(520, 320));
    await tester.pump();

    expect(tester.takeException(), isNull);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('opens customization dialog and adds item to cart', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    await _pumpAtSize(tester, const Size(1280, 800));

    await tester.tap(find.text('Cappuccino'));
    await tester.pumpAndSettle();

    expect(find.text('Customize Item'), findsOneWidget);
    expect(find.text('Add to Order'), findsOneWidget);

    await tester.tap(find.text('Add to Order'));
    await tester.pumpAndSettle();

    expect(find.text('Customize Item'), findsNothing);
    expect(find.text('Cappuccino'), findsNWidgets(2));
    expect(
      find.textContaining('Hot, Medium (12oz), Whole Milk'),
      findsOneWidget,
    );

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('opens receipt preview and clears cart after card payment', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    await _pumpAtSize(tester, const Size(1280, 800));

    await tester.tap(find.text('Espresso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Order'));
    await tester.pumpAndSettle();

    expect(find.text('PAY \$3.78'), findsOneWidget);

    await tester.tap(find.text('PAY \$3.78'));
    await tester.pumpAndSettle();

    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Order #618-42'), findsOneWidget);

    await tester.tap(find.text('Card'));
    await tester.pump();
    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Payment'), findsNothing);
    expect(find.text('Receipt Preview'), findsOneWidget);
    expect(find.text('CAFE SYSTEM 618'), findsOneWidget);
    expect(find.text('ESPRESSO'), findsOneWidget);
    expect(find.text('PAID VIA:'), findsOneWidget);
    expect(find.text('CARD'), findsOneWidget);
    expect(find.text('PAY \$0.00'), findsOneWidget);

    await tester.tap(find.text('Send via WhatsApp'));
    await tester.pump();
    expect(find.text('WhatsApp sending will be added later.'), findsOneWidget);

    await tester.tap(find.text('Print Receipt'));
    await tester.pumpAndSettle();

    expect(find.text('Receipt Preview'), findsNothing);
    expect(find.text('Payment completed'), findsOneWidget);
    expect(find.text('PAY \$0.00'), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('selects optional customer and includes it on receipt', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();
    await _pumpAtSize(tester, const Size(1280, 800));

    await tester.tap(find.text('Walk-in Customer'));
    await tester.pumpAndSettle();

    expect(find.text('Select Customer'), findsNWidgets(2));
    expect(find.text('Jane Doe'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('customer-search')),
      'Janet',
    );
    await tester.pump();

    expect(find.text('Janet Smith'), findsOneWidget);
    expect(find.text('Jane Doe'), findsNothing);

    await tester.tap(find.text('Janet Smith'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-customer-selection')));
    await tester.pumpAndSettle();

    expect(find.text('Select Customer'), findsNothing);
    expect(find.text('Janet Smith'), findsOneWidget);

    await tester.tap(find.text('Espresso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Order'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PAY \$3.78'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card'));
    await tester.pump();
    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();

    expect(find.text('CUSTOMER:'), findsOneWidget);
    expect(find.text('JANET SMITH'), findsOneWidget);

    await tester.tap(find.text('Print Receipt'));
    await tester.pumpAndSettle();

    expect(find.text('Walk-in Customer'), findsOneWidget);
    expect(find.text('Payment completed'), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

Future<void> _pumpAtSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

Future<void> _setupTestLocator() async {
  await serviceLocator.reset();
  setupServiceLocator(useBackend: false);
}
