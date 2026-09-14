import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/reports/models/expenses_report.dart';
import 'package:windows_application/features/reports/repositories/expenses_report_repository.dart';
import 'package:windows_application/features/reports/views/expenses_report_screen.dart';
import 'package:windows_application/features/reports/views/reports_overview_screen.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });
  tearDown(() => appRouter.go(AppRoutes.pos));

  testWidgets(
    'Expenses report renders read-only analysis and company-wide rows',
    (tester) async {
      serviceLocator.unregister<ExpensesReportRepository>();
      serviceLocator.registerLazySingleton<ExpensesReportRepository>(
        () => _ReportRepository(),
      );
      appRouter.go(AppRoutes.reportsExpenses);
      await _pump(tester);

      expect(find.byType(ExpensesReportScreen), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Total expenses'), findsOneWidget);
      expect(find.text('Expenses trend'), findsOneWidget);
      expect(find.text('Expenses by category'), findsOneWidget);
      expect(find.text('Branch expense comparison'), findsOneWidget);
      expect(find.text('Largest expenses'), findsOneWidget);
      expect(find.text('Expense table'), findsOneWidget);
      expect(find.text('Company-wide'), findsWidgets);
      expect(find.text('Create expense'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Expenses filters and comparison control are present and route returns to Overview',
    (tester) async {
      appRouter.go(AppRoutes.reportsExpenses);
      await _pump(tester);
      expect(find.byKey(const Key('expenses-date-filter')), findsOneWidget);
      expect(find.byKey(const Key('expenses-branch-filter')), findsOneWidget);
      expect(find.byKey(const Key('expenses-category-filter')), findsOneWidget);
      expect(find.byKey(const Key('expenses-status-filter')), findsOneWidget);
      expect(
        find.byKey(const Key('expenses-comparison-toggle')),
        findsOneWidget,
      );
      await tester.tap(find.text('Reports Overview'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportsOverviewScreen), findsOneWidget);
    },
  );

  testWidgets('Expenses overview card is active and opens the real route', (
    tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pump(tester);
    final card = find.byKey(const Key('report-category-3'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(ExpensesReportScreen), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

class _ReportRepository extends ExpensesReportRepository {
  @override
  Future<ExpensesReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required int? categoryId,
    required ExpenseReportStatus? status,
    required bool comparePrevious,
  }) async => ExpensesReport(
    currency: 'SYP',
    branches: const [ExpenseReportFilterOption(id: 1, name: 'Downtown')],
    categories: const [ExpenseReportFilterOption(id: 1, name: 'Rent')],
    statuses: ExpenseReportStatus.values,
    kpis: const ExpensesReportKpis(
      total: ExpenseMetric(value: 600000, previousValue: 550000),
      posted: ExpenseMetric(value: 450000, previousValue: 400000),
      pending: ExpenseMetric(value: 150000, previousValue: 100000),
      averageDaily: ExpenseMetric(value: 20000, previousValue: 18000),
      expenseToSalesRatio: ExpenseMetric(value: 12.5, previousValue: 10),
      largestCategory: ExpenseMetric(textValue: 'Rent'),
    ),
    trend: [
      ExpenseTrendPoint(date: DateTime(2026, 1, 1), value: 100000),
      ExpenseTrendPoint(date: DateTime(2026, 1, 2), value: 150000),
    ],
    categoryBreakdown: const [
      ExpenseCategoryBreakdownRow(name: 'Rent', amount: 400000),
      ExpenseCategoryBreakdownRow(name: 'Utilities', amount: 200000),
    ],
    branchComparison: const [
      BranchExpenseComparisonRow(
        branch: 'Downtown',
        totalExpenses: 400000,
        expenseToSalesRatio: 10,
      ),
    ],
    largestExpenses: [
      LargestExpenseRow(
        description: 'Monthly rent',
        category: 'Rent',
        amount: 400000,
        date: DateTime(2026, 1, 1),
      ),
    ],
    rows: [
      ExpenseReportRow(
        date: DateTime(2026, 1, 1),
        description: 'Monthly rent',
        category: 'Rent',
        amount: 400000,
        status: ExpenseReportStatus.paid,
      ),
    ],
    periodComparison: const ExpensePeriodComparison(
      currentLabel: 'Current period',
      previousLabel: 'Previous period',
      currentAmount: 600000,
      previousAmount: 550000,
    ),
  );
}
