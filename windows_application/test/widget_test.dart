import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/core/services/service_locator.dart';

void main() {
  testWidgets('shows the initial POS route', (WidgetTester tester) async {
    setupServiceLocator();
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
    expect(find.text('Cappuccino'), findsNWidgets(2));
    expect(find.text('PAY \$15.66'), findsOneWidget);
  });

  testWidgets('adapts the POS shell across desktop breakpoints', (
    WidgetTester tester,
  ) async {
    setupServiceLocator();

    await _pumpAtSize(tester, const Size(1280, 800));
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('PAY \$15.66'), findsOneWidget);

    await _pumpAtSize(tester, const Size(1000, 800));
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('PAY \$15.66'), findsOneWidget);

    await _pumpAtSize(tester, const Size(820, 760));
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('PAY \$15.66'), findsNothing);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);

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
