import '../models/inventory_report.dart';

class InventoryReportRepository {
  const InventoryReportRepository();
  Future<InventoryReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required int? locationId,
    required int? categoryId,
    required bool comparePrevious,
  }) async => InventoryReport.empty();
}
