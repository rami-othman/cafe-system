import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../repositories/manufacturing_repository.dart';
import 'manufacturing_reports_state.dart';

/// Reports screen, backed by `GET /manufacturing/reports`. Separate from
/// [ManufacturingCubit] (which only ever loads the Overview endpoint).
///
/// Follows the same request-generation-counter pattern as
/// [ManufacturingCubit] so a filter change fired while a previous load is
/// still in flight cannot let the stale response win a refresh race
/// ("latest-request-wins").
class ManufacturingReportsCubit extends Cubit<ManufacturingReportsState> {
  ManufacturingReportsCubit({required this.repository})
    : super(const ManufacturingReportsState());

  final ManufacturingRepository repository;
  int _requestGeneration = 0;

  Future<void> loadReports({
    int? warehouseId,
    String? type,
    String? dateFrom,
    String? dateTo,
  }) async {
    final int generation = ++_requestGeneration;
    bool isCurrent() => generation == _requestGeneration;

    // Refresh-retains-data: keep the previously loaded report visible while
    // the new filter's request is in flight instead of flashing an empty
    // state, per the module's "avoid a blank refresh" performance rule.
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final data = await repository.reports(
        warehouseId: warehouseId,
        type: type,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!isCurrent()) return;
      emit(state.copyWith(data: data, clearError: true));
    } catch (error) {
      if (!isCurrent()) return;
      final ApiException? apiError = error is ApiException ? error : null;
      emit(
        state.copyWith(
          error: apiError?.message ?? 'تعذر تحميل التقارير، حاول مرة أخرى.',
        ),
      );
    } finally {
      if (isCurrent()) emit(state.copyWith(loading: false));
    }
  }
}
