import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/models/auth_session.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage.dart';

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
    expect(find.text('Downtown'), findsOneWidget);
    expect(find.text('SHIFT OPEN'), findsOneWidget);
    expect(find.text('Search products...'), findsOneWidget);
    expect(find.text('COFFEE'), findsOneWidget);
    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text('Dine-in'), findsOneWidget);
    expect(find.text('Cappuccino'), findsOneWidget);
    expect(find.text('Complete order'), findsOneWidget);

    await tester.tap(find.text('Espresso'));
    await tester.pumpAndSettle();

    expect(find.text('Customize item'), findsOneWidget);
    await tester.tap(find.text('Add to Order'));
    await tester.pumpAndSettle();

    expect(find.text('Espresso'), findsNWidgets(2));
    expect(find.text('Pay 3.78 SYP'), findsOneWidget);
  });

  testWidgets('adapts the POS shell across desktop breakpoints', (
    WidgetTester tester,
  ) async {
    await _setupTestLocator();

    await _pumpAtSize(tester, const Size(1280, 800));
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Complete order'), findsOneWidget);

    await _pumpAtSize(tester, const Size(1000, 800));
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Complete order'), findsOneWidget);

    await _pumpAtSize(tester, const Size(820, 760));
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Complete order'), findsNothing);
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
    expect(find.text('Complete order'), findsNothing);

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

    expect(find.text('Customize item'), findsOneWidget);
    expect(find.text('Add to Order'), findsOneWidget);

    await tester.tap(find.text('Add to Order'));
    await tester.pumpAndSettle();

    expect(find.text('Customize item'), findsNothing);
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

    expect(find.text('Pay 3.78 SYP'), findsOneWidget);

    await tester.tap(find.text('Pay 3.78 SYP'));
    await tester.pumpAndSettle();

    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Order #618-42'), findsOneWidget);

    await tester.tap(find.text('Card'));
    await tester.pump();
    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Payment'), findsNothing);
    expect(find.text('Receipt preview'), findsOneWidget);
    expect(find.text('CAFE SYSTEM 618'), findsOneWidget);
    expect(find.text('ESPRESSO'), findsOneWidget);
    expect(find.text('Paid via:'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Complete order'), findsOneWidget);

    await tester.tap(find.text('Send via WhatsApp'));
    await tester.pump();
    expect(find.text('WhatsApp sending will be added later.'), findsOneWidget);

    await tester.tap(find.text('Print receipt'));
    await tester.pumpAndSettle();

    expect(find.text('Receipt preview'), findsOneWidget);
    expect(
      find.text('No saved backend order is available to print.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Complete order'), findsOneWidget);

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

    await tester.tap(find.text('Walk-in customer'));
    await tester.pumpAndSettle();

    expect(find.text('Select Customer'), findsNWidgets(2));
    expect(find.text('Jane Doe'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('customer-search')),
      'Janet',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Pay 3.78 SYP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card'));
    await tester.pump();
    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Customer:'), findsOneWidget);
    expect(find.text('JANET SMITH'), findsOneWidget);

    await tester.tap(find.text('Print receipt'));
    await tester.pumpAndSettle();

    expect(find.text('Walk-in customer'), findsOneWidget);
    expect(
      find.text('No saved backend order is available to print.'),
      findsOneWidget,
    );

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
  final now = DateTime.now();
  serviceLocator.registerLazySingleton<AuthSessionStorage>(
    () => MemoryAuthSessionStorage(
      AuthSession(
        accessToken: 'widget-test-session-token',
        user: const AuthUser(
          id: 1,
          name: 'Test Operator',
          role: 'manager',
          email: 'test@example.local',
        ),
        tenant: const AuthTenant(id: 1, name: 'Test Cafe'),
        mustChangePassword: false,
        lastValidatedAt: now,
        offlineSessionMaxAgeSeconds: 43200,
        expiresAt: now.add(const Duration(hours: 12)),
      ),
    ),
  );
  setupServiceLocator(useBackend: false);
}
