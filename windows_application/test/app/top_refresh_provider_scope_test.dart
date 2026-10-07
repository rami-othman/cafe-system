import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/app/shell_page_refresh.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/cashier_dashboard/models/cashier_dashboard.dart';
import 'package:windows_application/features/reports/models/reports_overview.dart';
import 'package:windows_application/features/reports/repositories/reports_repository.dart';
import 'package:windows_application/shared/widgets/app_top_bar.dart';

import '../support/cashier_test_harness.dart';

void main() {
  testWidgets(
    'shell refresh reaches the active route provider after navigation',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        appRouter.go(AppRoutes.pos);
        await serviceLocator.reset();
      });

      final cashier = _CountingCashierRepository();
      final reports = _CountingReportsRepository();
      await setupCashierLocator(role: 'owner', repository: cashier);
      await serviceLocator.unregister<ReportsRepository>();
      serviceLocator.registerSingleton<ReportsRepository>(reports);

      appRouter.go(AppRoutes.dashboard);
      await pumpApp(tester);
      expect(tester.takeException(), isNull);
      final int dashboardBefore = cashier.dashboardCalls;
      await _tapTopRefresh(tester);
      expect(cashier.dashboardCalls, dashboardBefore + 1);

      appRouter.go(AppRoutes.cashierInventory);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final int inventoryBefore = cashier.inventoryCalls;
      final int dashboardAfter = cashier.dashboardCalls;
      await _tapTopRefresh(tester);
      expect(cashier.inventoryCalls, inventoryBefore + 1);
      expect(cashier.dashboardCalls, dashboardAfter);

      appRouter.go(AppRoutes.reports);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final int reportsBefore = reports.overviewCalls;
      final int inventoryAfter = cashier.inventoryCalls;
      await _tapTopRefresh(tester);
      expect(reports.overviewCalls, reportsBefore + 1);
      expect(cashier.inventoryCalls, inventoryAfter);

      // Leaving the page must release its context and closed Cubit.
      appRouter.go(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await ShellPageRefresh.run();
      expect(reports.overviewCalls, reportsBefore + 1);
    },
  );
}

Future<void> _tapTopRefresh(WidgetTester tester) async {
  final refresh = find.descendant(
    of: find.byType(AppTopBar),
    matching: find.byIcon(Icons.refresh_outlined),
  );
  expect(refresh, findsOneWidget);
  await tester.tap(refresh);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

class _CountingCashierRepository extends FakeCashierDashboardRepository {
  int inventoryCalls = 0;

  @override
  Future<CashierStockPage> inventory({
    int? branchId,
    String? search,
    String? state,
    int page = 1,
    int perPage = 50,
  }) {
    inventoryCalls++;
    return super.inventory(
      branchId: branchId,
      search: search,
      state: state,
      page: page,
      perPage: perPage,
    );
  }
}

class _CountingReportsRepository extends ReportsRepository {
  int overviewCalls = 0;

  @override
  Future<ReportsOverview> getOverview({
    required DateTime from,
    required DateTime to,
    int? branchId,
    required bool comparePrevious,
  }) {
    overviewCalls++;
    return super.getOverview(
      from: from,
      to: to,
      branchId: branchId,
      comparePrevious: comparePrevious,
    );
  }
}
