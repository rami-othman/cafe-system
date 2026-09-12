import '../models/sales_profitability_report.dart';

/// Deliberately endpoint-free during the UI phase. Replacing this repository
/// with the future API implementation leaves the screen/controller contract
/// unchanged and never exposes sample financial figures in production.
class SalesProfitabilityRepository {
  const SalesProfitabilityRepository();

  Future<SalesProfitabilityReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required bool comparePrevious,
  }) async => SalesProfitabilityReport.empty();
}
