import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/reports_repository.dart';
import 'reports_overview_state.dart';

class ReportsOverviewCubit extends Cubit<ReportsOverviewState> {
  ReportsOverviewCubit({required this.repository})
    : super(const ReportsOverviewState());

  final ReportsRepository repository;

  Future<void> load() async {
    final DateTime now = DateTime.now();
    final DateTimeRange range =
        state.range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 13),
          end: now,
        );
    emit(
      state.copyWith(
        status: ReportsOverviewStatus.loading,
        range: range,
        clearError: true,
      ),
    );
    try {
      final data = await repository.getOverview(
        from: range.start,
        to: range.end,
        branchId: state.branchId,
        comparePrevious: state.comparePrevious,
      );
      emit(state.copyWith(status: ReportsOverviewStatus.loaded, data: data));
    } catch (error) {
      emit(
        state.copyWith(
          status: ReportsOverviewStatus.error,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> selectRange(DateTimeRange range) {
    emit(state.copyWith(range: range));
    return load();
  }

  Future<void> selectBranch(int? branchId) {
    emit(state.copyWith(branchId: branchId, clearBranch: branchId == null));
    return load();
  }

  Future<void> toggleComparison(bool value) {
    emit(state.copyWith(comparePrevious: value));
    return load();
  }
}
