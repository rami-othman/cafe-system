import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/reports/models/sales_profitability_report.dart';
import 'package:windows_application/features/reports/repositories/sales_profitability_repository.dart';
import 'package:windows_application/features/reports/views/reports_overview_screen.dart';
import 'package:windows_application/features/reports/views/sales_profitability_screen.dart';
import 'package:windows_application/features/reports/widgets/reports_overview_components.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
    serviceLocator.unregister<SalesProfitabilityRepository>();
    serviceLocator.registerLazySingleton<SalesProfitabilityRepository>(
      _FixtureRepository.new,
    );
  });
  tearDown(() => appRouter.go(AppRoutes.pos));

  testWidgets('route renders the eight KPI labels and all report sections', (
    tester,
  ) async {
    appRouter.go(AppRoutes.reportsSalesProfitability);
    await _pump(tester);
    expect(find.byType(SalesProfitabilityScreen), findsOneWidget);
    for (final label in <String>[
      'Gross Sales',
      'Net Sales',
      'Discounts',
      'Refunds',
      'Cost of Goods Sold (COGS)',
      'Gross Profit',
      'Gross Margin %',
      'Average Order Value',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Sales & Profit Trend'), findsOneWidget);
    expect(find.text('Sales by Hour'), findsOneWidget);
    expect(find.text('Sales by Category'), findsOneWidget);
    expect(find.text('Branch Performance'), findsOneWidget);
    expect(find.text('Product Performance'), findsOneWidget);
  });

  testWidgets(
    'Arabic is RTL and chronological labels stay physically ordered',
    (tester) async {
      appRouter.go(AppRoutes.reportsSalesProfitability);
      await _pump(tester);
      await _switchLanguage(tester, 'العربية');
      expect(find.text('المبيعات والربحية'), findsOneWidget);
      expect(find.text('إجمالي المبيعات'), findsWidgets);
      expect(
        Directionality.of(
          tester.element(find.byType(SalesProfitabilityScreen)),
        ),
        TextDirection.rtl,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('sales-trend-start'))).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('sales-trend-end'))).dx,
        ),
      );
    },
  );

  testWidgets(
    'grouping, comparison, product view and sorting are interactive',
    (tester) async {
      appRouter.go(AppRoutes.reportsSalesProfitability);
      await _pump(tester);
      await tester.tap(find.byKey(const Key('sales-group-weekly')));
      await tester.tap(find.text('vs. Previous Period'));
      final productView = find.byKey(const Key('product-view-mostProfitable'));
      await tester.ensureVisible(productView);
      await tester.tap(productView);
      final sort = find.byIcon(Icons.arrow_downward).last;
      await tester.ensureVisible(sort);
      await tester.tap(sort);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reports Overview category opens this route and back returns', (
    tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pump(tester);
    final category = find.byKey(const Key('report-category-0'));
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(find.byType(SalesProfitabilityScreen), findsOneWidget);
    await tester.tap(find.text('Reports Overview').first);
    await tester.pumpAndSettle();
    expect(find.byType(ReportsOverviewScreen), findsOneWidget);
  });

  testWidgets('has polished loading and retryable safe error states', (
    tester,
  ) async {
    final loading = Completer<SalesProfitabilityReport>();
    serviceLocator.unregister<SalesProfitabilityRepository>();
    serviceLocator.registerLazySingleton<SalesProfitabilityRepository>(
      () => _DeferredRepository(loading.future),
    );
    appRouter.go(AppRoutes.reportsSalesProfitability);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const App());
    await tester.pump();
    expect(find.byType(SalesProfitabilityScreen), findsOneWidget);
    expect(find.byType(ReportsOverviewSkeletonCard), findsWidgets);

    loading.completeError(Exception('internal backend detail'));
    await tester.pumpAndSettle();
    expect(find.text('This report could not be loaded.'), findsOneWidget);
    expect(find.textContaining('internal backend detail'), findsNothing);
  });

  for (final width in <double>[1280, 1366, 1440, 1600, 1920]) {
    testWidgets('is overflow-free at $width', (tester) async {
      appRouter.go(AppRoutes.reportsSalesProfitability);
      await _pump(tester, size: Size(width, 900));
      expect(tester.takeException(), isNull);
    });
  }
}

class _FixtureRepository extends SalesProfitabilityRepository {
  @override
  Future<SalesProfitabilityReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required bool comparePrevious,
  }) async => SalesProfitabilityReport(
    currency: 'SYP',
    branches: const <SalesProfitabilityBranch>[
      SalesProfitabilityBranch(id: 1, name: 'Downtown'),
    ],
    kpis: const SalesProfitabilityKpis(
      grossSales: SalesProfitabilityMetric(value: 1200, previousValue: 1000),
      netSales: SalesProfitabilityMetric(value: 1100, previousValue: 900),
      discounts: SalesProfitabilityMetric(value: 40, previousValue: 35),
      refunds: SalesProfitabilityMetric(value: 10, previousValue: 5),
      cogs: SalesProfitabilityMetric(value: 500, previousValue: 450),
      grossProfit: SalesProfitabilityMetric(value: 600, previousValue: 450),
      grossMargin: SalesProfitabilityMetric(value: 54.5, previousValue: 50),
      averageOrderValue: SalesProfitabilityMetric(value: 25, previousValue: 22),
    ),
    dailyTrend: <SalesProfitTrendPoint>[
      SalesProfitTrendPoint(
        date: DateTime(2025, 1, 1),
        netSales: 300,
        grossProfit: 160,
      ),
      SalesProfitTrendPoint(
        date: DateTime(2025, 1, 14),
        netSales: 600,
        grossProfit: 310,
      ),
    ],
    weeklyTrend: <SalesProfitTrendPoint>[
      SalesProfitTrendPoint(
        date: DateTime(2025, 1, 1),
        netSales: 700,
        grossProfit: 360,
      ),
      SalesProfitTrendPoint(
        date: DateTime(2025, 1, 8),
        netSales: 800,
        grossProfit: 420,
      ),
    ],
    monthlyTrend: <SalesProfitTrendPoint>[
      SalesProfitTrendPoint(
        date: DateTime(2025, 1, 1),
        netSales: 1500,
        grossProfit: 780,
      ),
      SalesProfitTrendPoint(
        date: DateTime(2025, 2, 1),
        netSales: 1800,
        grossProfit: 900,
      ),
    ],
    hourlySales: const <HourlySalesBucket>[
      HourlySalesBucket(label: '10:00', sales: 200),
      HourlySalesBucket(label: '12:00', sales: 400),
    ],
    categorySales: const <CategorySalesRow>[
      CategorySalesRow(name: 'Coffee', netSales: 700, percent: 60),
    ],
    branchPerformance: const <BranchPerformanceRow>[
      BranchPerformanceRow(
        name: 'Downtown',
        netSales: 1100,
        orders: 44,
        grossProfit: 600,
        margin: 54.5,
      ),
    ],
    products: const <ProductPerformanceRow>[
      ProductPerformanceRow(
        name: 'Latte',
        category: 'Coffee',
        quantity: 20,
        grossSales: 500,
        discounts: 10,
        netSales: 490,
        cogs: 200,
        grossProfit: 290,
        margin: 59,
      ),
    ],
  );
}

class _DeferredRepository extends SalesProfitabilityRepository {
  _DeferredRepository(this.future);
  final Future<SalesProfitabilityReport> future;
  @override
  Future<SalesProfitabilityReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required bool comparePrevious,
  }) => future;
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

Future<void> _switchLanguage(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('app-language-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
