import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/daily_report_data.dart';
import 'daily_report_state.dart';

class DailyReportCubit extends Cubit<DailyReportState> {
  DailyReportCubit() : super(const DailyReportState());
  Future<void> loadReport() async => emit(
    state.copyWith(
      status: DailyReportStatus.loaded,
      data: DailyReportData.mock(),
      clearErrorMessage: true,
    ),
  );
  void selectDate(String label) => emit(state.copyWith(dateLabel: label));
  void showEmpty() => emit(state.copyWith(status: DailyReportStatus.empty));
  void showError() => emit(
    state.copyWith(
      status: DailyReportStatus.error,
      errorMessage: 'The report could not be loaded.',
    ),
  );
}
