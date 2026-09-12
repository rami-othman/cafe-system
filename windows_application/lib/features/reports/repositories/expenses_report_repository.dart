import '../models/expenses_report.dart';

/// Production-safe placeholder. A dedicated reporting endpoint will become the
/// single source of truth for all values, including expense-to-sales ratios.
class ExpensesReportRepository {
  const ExpensesReportRepository();
  Future<ExpensesReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required int? categoryId,
    required ExpenseReportStatus? status,
    required bool comparePrevious,
  }) async => ExpensesReport.empty();
}
