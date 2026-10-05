import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../repositories/manufacturing_repository.dart';
import 'manufacturing_state.dart';

class ManufacturingCubit extends Cubit<ManufacturingState> {
  ManufacturingCubit({required this.repository})
    : super(const ManufacturingState());
  final ManufacturingRepository repository;

  int _requestGeneration = 0;

  /// Loads the Overview screen's data. Guarded by a request generation
  /// counter so a fast `refresh()` call fired while a prior `loadOverview()`
  /// is still in flight cannot have the stale response overwrite the newer
  /// one (or spam duplicate loading flips).
  Future<void> loadOverview({int? warehouseId}) async {
    final int generation = ++_requestGeneration;
    bool isCurrent() => generation == _requestGeneration;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final overview = await repository.getOverview(warehouseId: warehouseId);
      if (!isCurrent()) return;
      emit(state.copyWith(overview: overview, clearError: true));
    } catch (error) {
      if (!isCurrent()) return;
      final ApiException? apiError = error is ApiException ? error : null;
      emit(state.copyWith(error: apiError?.message ?? error.toString()));
    } finally {
      if (isCurrent()) emit(state.copyWith(loading: false));
    }
  }

  /// Re-runs the overview load. Sharing `loadOverview`'s request-generation
  /// guard means a `refresh()` tap while a load is already in flight simply
  /// supersedes it instead of racing it.
  Future<void> refresh({int? warehouseId}) =>
      loadOverview(warehouseId: warehouseId);
}
