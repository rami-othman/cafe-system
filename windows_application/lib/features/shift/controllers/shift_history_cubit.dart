import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/shift_models.dart';
import '../repositories/shift_repository.dart';
import 'shift_history_state.dart';

/// Owns the history list and its filters. Filtering, paging and the summary
/// KPIs are all pure projections in [ShiftHistoryState], so every filter
/// change here is a single emit and the KPI row can never drift from the
/// table below it.
class ShiftHistoryCubit extends Cubit<ShiftHistoryState> {
  ShiftHistoryCubit({required this.repository}) : super(const ShiftHistoryState());

  final ShiftRepository repository;

  DateTime get now => repository.now;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: ShiftHistoryStatusView.loading,
        clearErrorMessage: true,
      ),
    );
    try {
      final List<ShiftHistoryEntry> entries = await repository.loadHistory();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: entries.isEmpty
              ? ShiftHistoryStatusView.empty
              : ShiftHistoryStatusView.ready,
          all: entries,
          page: 1,
        ),
      );
    } on ShiftDataException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ShiftHistoryStatusView.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  void search(String value) => emit(state.copyWith(query: value, page: 1));

  void setPeriod(ShiftHistoryPeriod period) =>
      emit(state.copyWith(period: period, page: 1));

  void setCustomRange(DateTime start, DateTime end) => emit(
    state.copyWith(
      period: ShiftHistoryPeriod.custom,
      customStart: DateTime(start.year, start.month, start.day),
      customEnd: DateTime(end.year, end.month, end.day),
      page: 1,
    ),
  );

  void setCashier(String? cashier) => emit(
    state.copyWith(cashier: cashier, clearCashier: cashier == null, page: 1),
  );

  void setBranch(String? branch) => emit(
    state.copyWith(branch: branch, clearBranch: branch == null, page: 1),
  );

  void setShiftStatus(ShiftHistoryStatus? status) => emit(
    state.copyWith(
      shiftStatus: status,
      clearShiftStatus: status == null,
      page: 1,
    ),
  );

  void setDifferenceFilter(ShiftDifferenceFilter filter) =>
      emit(state.copyWith(differenceFilter: filter, page: 1));

  void clearFilters() => emit(
    state.copyWith(
      query: '',
      period: ShiftHistoryPeriod.thisMonth,
      clearCashier: true,
      clearBranch: true,
      clearShiftStatus: true,
      differenceFilter: ShiftDifferenceFilter.all,
      page: 1,
    ),
  );

  void goToPage(int page) {
    final int pages = state.pageCount(now);
    emit(state.copyWith(page: page.clamp(1, pages)));
  }
}
