import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/daily_report_data.dart';
import '../repositories/reports_repository.dart';
import 'daily_report_state.dart';

class DailyReportCubit extends Cubit<DailyReportState> {
  DailyReportCubit({ReportsRepository? repository})
    : _repository = repository ?? const ReportsRepository(),
      super(const DailyReportState());

  final ReportsRepository _repository;

  Future<void> loadReport({DateTime? date, int? branchId}) async {
    final DateTime? selectedDate = date ?? state.selectedDate;
    emit(
      state.copyWith(
        status: DailyReportStatus.loading,
        clearErrorMessage: true,
      ),
    );
    try {
      final DailyReportData report = await _repository.getDailyReport(
        date: selectedDate,
        branchId: branchId,
      );
      final DateTime? reportDate = selectedDate ?? report.reportDate;
      emit(
        state.copyWith(
          status: report.isEmpty
              ? DailyReportStatus.empty
              : DailyReportStatus.loaded,
          data: report,
          selectedDate: reportDate,
          dateLabel: reportDate == null
              ? state.dateLabel
              : _dateLabel(reportDate),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: DailyReportStatus.error,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> selectDate(DateTime date, {int? branchId}) =>
      loadReport(date: date, branchId: branchId);
  void showEmpty() => emit(state.copyWith(status: DailyReportStatus.empty));
  void showError() => emit(
    state.copyWith(
      status: DailyReportStatus.error,
      errorMessage: 'The report could not be loaded.',
    ),
  );

  String _dateLabel(DateTime date) {
    final DateTime today = DateTime.now();
    final bool isToday =
        DateTime(date.year, date.month, date.day) ==
        DateTime(today.year, today.month, today.day);
    return isToday ? 'Today' : '${date.month}/${date.day}/${date.year}';
  }
}
