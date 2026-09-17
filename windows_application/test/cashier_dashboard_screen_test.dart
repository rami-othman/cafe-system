import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/cashier_dashboard/models/cashier_dashboard.dart';
import 'package:windows_application/features/cashier_dashboard/views/cashier_dashboard_screen.dart';
import 'package:windows_application/features/cashier_dashboard/widgets/cashier_dashboard_widgets.dart';
import 'package:windows_application/features/cashier_dashboard/widgets/cashier_identity_header.dart';
import 'package:windows_application/shared/access/cashier_access.dart';

import 'support/cashier_test_harness.dart';

/// Terms that must never appear on the Cashier surface. The endpoint does not
/// send them, and these assertions keep a future card from reintroducing one.
const List<String> _forbiddenTerms = <String>[
  'Gross profit',
  'Net profit',
  'Profit',
  'Margin',
  'COGS',
  'Cost of goods',
  'Unit cost',
  'Average cost',
  'Valuation',
  'Balance sheet',
  'Trial balance',
  'General ledger',
  'Payable',
  'Receivable',
];

void main() {
  tearDown(() async {
    appRouter.go(AppRoutes.pos);
    await serviceLocator.reset();
  });

  testWidgets('a Cashier lands on the operational dashboard, not the till', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    expect(find.byType(CashierDashboardScreen), findsOneWidget);
    expect(find.byType(CashierIdentityHeader), findsOneWidget);
    expect(find.text('618TierFour'), findsWidgets);
    expect(find.text('Sara Cashier'), findsWidgets);
    expect(find.text('#42'), findsOneWidget);
    expect(find.text('04:28'), findsOneWidget);
  });

  testWidgets('the expected drawer card is shown and labelled as expected', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    expect(find.text('Expected drawer cash'), findsOneWidget);
    expect(find.text('SYP 290000.00'), findsOneWidget);
    expect(
      find.text(
        'Expected, not counted. The physical count happens at shift close.',
      ),
      findsOneWidget,
    );
    // The counted figure belongs to the shift-close flow and must not appear.
    expect(find.textContaining('Counted'), findsNothing);
    expect(find.textContaining('Actual cash'), findsNothing);
  });

  testWidgets('sales, order and inventory cards render their figures', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    expect(find.text('Shift sales'), findsOneWidget);
    expect(find.text('SYP 400000.00'), findsOneWidget);
    expect(find.text('Average order'), findsOneWidget);
    expect(find.text('Card sales'), findsOneWidget);
    expect(find.text('POS warehouse'), findsOneWidget);
    expect(find.text('618TierFour — Main Store'), findsOneWidget);
    expect(find.text('Negative stock'), findsOneWidget);
    // Every section states the scope its numbers belong to.
    expect(find.text('Current shift'), findsWidgets);
  });

  testWidgets('finance shows exactly the four permitted workspaces', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    expect(find.text('Receipt voucher'), findsOneWidget);
    expect(find.text('Payment voucher'), findsOneWidget);
    expect(find.text('Purchases'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);

    for (final String admin in <String>[
      'Chart of accounts',
      'Journal entries',
      'Reconciliation',
      'Daily closing',
      'Accounting periods',
      'Financial reports',
      'Cash and banks',
      'Payment methods',
    ]) {
      expect(find.text(admin), findsNothing, reason: '$admin must stay hidden');
    }
  });

  testWidgets('no profit, cost, valuation or ledger term reaches the screen', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    for (final String term in _forbiddenTerms) {
      expect(
        find.textContaining(term, skipOffstage: false),
        findsNothing,
        reason: '"$term" must never appear on the Cashier dashboard',
      );
    }
  });

  testWidgets('full inventory administration shortcuts are absent', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    for (final String admin in <String>[
      'Warehouses',
      'Transfers',
      'Stock counts',
      'Movements',
      'Adjustments',
    ]) {
      expect(find.text(admin), findsNothing, reason: '$admin must stay hidden');
    }
  });

  testWidgets('a pending load renders the skeleton shell', (
    WidgetTester tester,
  ) async {
    final Completer<CashierDashboard> pending = Completer<CashierDashboard>();
    await setupCashierLocator(
      repository: FakeCashierDashboardRepository(
        dashboardFuture: () => pending.future,
      ),
    );
    appRouter.go(AppRoutes.dashboard);
    // Pumped without settling so the pending request is observable while its
    // skeleton is on screen.
    await tester.pumpWidget(const App());
    await tester.pump();
    await tester.pump();

    expect(find.byType(CashierSkeletonCard), findsWidgets);
    pending.complete(openShiftDashboard());
    await tester.pumpAndSettle();
    expect(find.byType(CashierSkeletonCard), findsNothing);
  });

  testWidgets('a failed load renders a retryable error without internals', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(
      repository: FakeCashierDashboardRepository(
        dashboardFuture: () => Future<CashierDashboard>.error(
          Exception('connection string must stay hidden'),
        ),
      ),
    );
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    expect(
      find.text('Unable to load the operations dashboard.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('connection string'), findsNothing);
  });

  testWidgets('the no-open-shift state is stated rather than shown as zero', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(
      repository: FakeCashierDashboardRepository(
        dashboardFuture: () =>
            Future<CashierDashboard>.value(noShiftDashboard()),
      ),
    );
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    expect(find.text('No open shift'), findsOneWidget);
    expect(
      find.text('Shift figures appear once a shift is open at this branch.'),
      findsOneWidget,
    );
    // Drawer and sales amounts read as unavailable, not as a misleading zero.
    expect(find.text('SYP 0.00'), findsNothing);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('operational alerts render with their counts', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    expect(find.text('Operational alerts'), findsOneWidget);
    expect(find.text('3 items have negative stock.'), findsOneWidget);
    // A management target is never an alert on this surface.
    expect(find.textContaining('below target'), findsNothing);
  });

  testWidgets('negative stock is reported without blocking the till', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);

    expect(find.text('Negative stock'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    // The POS shortcut stays enabled: negative stock is allowed here.
    final CashierActionTile pos = tester.widget<CashierActionTile>(
      find.widgetWithText(CashierActionTile, 'Point of sale'),
    );
    expect(pos.onTap, isNotNull);
  });

  testWidgets('the RTL tablet layout has no overflow at 1024-1366', (
    WidgetTester tester,
  ) async {
    await setupCashierLocator(repository: FakeCashierDashboardRepository());
    for (final double width in <double>[1024, 1180, 1366, 1440, 1920, 420]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      appRouter.go(AppRoutes.dashboard);
      await pumpApp(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow or layout failure at ${width}px',
      );
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('a single mount issues exactly one aggregate request', (
    WidgetTester tester,
  ) async {
    final FakeCashierDashboardRepository repository =
        FakeCashierDashboardRepository();
    await setupCashierLocator(repository: repository);
    appRouter.go(AppRoutes.dashboard);
    await pumpApp(tester);
    await tester.pump();

    expect(repository.dashboardCalls, 1);
  });

  group('CashierAccess', () {
    test('a Cashier may reach only the operational routes', () {
      final CashierAccess access = CashierAccess.of(
        sessionForRole('cashier').user,
        financePermissions: const <String>{
          'finance.vouchers.view',
          'finance.purchases.view',
          'finance.sales.view',
        },
      );

      expect(access.isCashier, isTrue);
      expect(access.homeRoute, CashierRoutes.dashboard);
      for (final String allowed in <String>[
        CashierRoutes.dashboard,
        CashierRoutes.pos,
        CashierRoutes.orders,
        CashierRoutes.discounts,
        CashierRoutes.cashierInventory,
        CashierRoutes.settings,
        CashierRoutes.financeVouchers,
        CashierRoutes.financePurchases,
        CashierRoutes.financeSales,
      ]) {
        expect(access.redirectFor(allowed), isNull, reason: allowed);
      }
    });

    test('a Cashier may reach only granted Finance workspaces', () {
      final CashierAccess access = CashierAccess.of(
        sessionForRole('cashier').user,
        financePermissions: const <String>{'finance.vouchers.view'},
      );

      expect(access.redirectFor(CashierRoutes.financeVouchers), isNull);
      expect(
        access.redirectFor(CashierRoutes.financePurchases),
        CashierRoutes.dashboard,
      );
      expect(
        access.redirectFor(CashierRoutes.financeSales),
        CashierRoutes.dashboard,
      );
    });

    test('a Cashier deep link into a forbidden path is redirected home', () {
      final CashierAccess access = CashierAccess.of(
        sessionForRole('cashier').user,
      );

      for (final String blocked in <String>[
        '/finance',
        '/finance/accounts',
        '/finance/journal-entries',
        '/finance/reports',
        '/finance/reconciliation',
        '/finance/daily-closing',
        '/finance/accounting-periods',
        '/finance/cash-banks',
        '/finance/settings',
        '/inventory',
        '/inventory/items',
        '/inventory/balances',
        '/inventory/transfers',
        '/inventory/counts',
        '/inventory/movements',
        '/reports',
        '/reports/sales-profitability',
        '/menu-management/products',
        '/cafe-configuration/overview',
      ]) {
        expect(
          access.redirectFor(blocked),
          CashierRoutes.dashboard,
          reason: '$blocked must be blocked for a Cashier',
        );
      }
    });

    test('a non-Cashier role is never redirected and keeps the POS home', () {
      for (final String role in <String>['owner', 'manager']) {
        final CashierAccess access = CashierAccess.of(
          sessionForRole(role).user,
        );
        expect(access.isCashier, isFalse);
        expect(access.homeRoute, CashierRoutes.pos);
        for (final String path in <String>[
          '/finance',
          '/inventory/items',
          '/reports',
          '/menu-management/products',
        ]) {
          expect(access.redirectFor(path), isNull, reason: '$role -> $path');
        }
      }
    });
  });
}
