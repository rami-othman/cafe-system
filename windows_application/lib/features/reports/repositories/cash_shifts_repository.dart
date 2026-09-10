import '../models/cash_shifts_report.dart';

class CashShiftsRepository {
  const CashShiftsRepository();
  Future<CashShiftsReport> getReport({
    required DateTime from,
    required DateTime to,
    required int? branchId,
    required int? cashierId,
    required bool comparePrevious,
  }) async => CashShiftsReport.empty();
}
