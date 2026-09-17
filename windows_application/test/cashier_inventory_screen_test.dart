import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/cashier_dashboard/models/cashier_dashboard.dart';
import 'package:windows_application/features/cashier_dashboard/views/cashier_inventory_screen.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

import 'support/cashier_test_harness.dart';

void main() {
  tearDown(() async {
    appRouter.go(AppRoutes.pos);
    await serviceLocator.reset();
  });

  testWidgets('the operational stock view lists quantities and states', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.cashierInventory);
    await pumpApp(tester);

    expect(find.byType(CashierInventoryScreen), findsOneWidget);
    expect(find.text('POS stock'), findsWidgets);
    expect(find.text('618TierFour — Main Store'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('-5.000 L'), findsOneWidget);
    expect(find.text('1.500 kg'), findsOneWidget);
    expect(find.text('Negative'), findsWidgets);
    expect(find.text('Low'), findsWidgets);
  });

  testWidgets('no cost, valuation or supplier pricing column exists', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.cashierInventory);
    await pumpApp(tester);

    for (final String term in <String>[
      'Cost',
      'Value',
      'Valuation',
      'Average',
      'WAC',
      'Supplier',
      'Purchase price',
      'Total value',
    ]) {
      expect(
        find.textContaining(term, skipOffstage: false),
        findsNothing,
        reason: '"$term" must never appear on the Cashier stock view',
      );
    }
  });

  testWidgets('an unconfigured POS warehouse is explained, not left blank', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(
      repository: FakeCashierDashboardRepository(
        inventoryFuture: () =>
            Future<CashierStockPage>.value(CashierStockPage.empty),
      ),
    );
    appRouter.go(AppRoutes.cashierInventory);
    await pumpApp(tester);

    expect(
      find.text('No POS warehouse is configured for this branch.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed stock load offers a retry without internals', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(
      repository: FakeCashierDashboardRepository(
        inventoryFuture: () => Future<CashierStockPage>.error(
          Exception('sql details must stay hidden'),
        ),
      ),
    );
    appRouter.go(AppRoutes.cashierInventory);
    await pumpApp(tester);

    expect(find.text('Unable to load POS stock.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('sql details'), findsNothing);
  });

  testWidgets('the stock view is overflow-free from phone to desktop', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    for (final double width in <double>[420, 1024, 1366, 1920]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      appRouter.go(AppRoutes.cashierInventory);
      await pumpApp(tester);
      expect(tester.takeException(), isNull, reason: 'overflow at ${width}px');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  group('sidebar', () {
    testWidgets('a Cashier sees only the operational destinations', (
      WidgetTester tester,
    ) async {
      await setupCashierLocator();
      await _pumpSidebar(tester, 'cashier');

      for (final String label in <String>[
        'Home',
        'POS',
        'Orders',
        'Discounts',
        'Finance',
        'Inventory',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final String hidden in <String>[
        'Dashboard',
        'Reports',
        'Menu Management',
        'Cafe Configuration',
        'Customers',
      ]) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
    });

    testWidgets('an Owner sidebar is unchanged', (WidgetTester tester) async {
      await setupCashierLocator(role: 'owner');
      await _pumpSidebar(tester, 'owner');

      for (final String label in <String>[
        'Dashboard',
        'POS',
        'Orders',
        'Customers',
        'Discounts',
        'Menu Management',
        'Cafe Configuration',
        'Inventory',
        'Finance',
        'Reports',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Home'), findsNothing);
    });
  });
}

Future<void> _pumpSidebar(WidgetTester tester, String role) async {
  // Tall enough that the destination ListView builds every item; a shorter
  // viewport would leave later entries unbuilt and make the assertions lie.
  await tester.binding.setSurfaceSize(const Size(1000, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AuthSessionCubit>.value(
        value: serviceLocator<AuthSessionCubit>(),
        child: Scaffold(body: AppSidebar(activeLabel: 'pos', actorRole: role)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
