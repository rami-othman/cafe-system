import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/bar_check_session.dart';
import '../repositories/shift_close_repository.dart';
import 'bar_check_state.dart';

/// Drives the cashier's own shift bar check: start, count each line, submit,
/// and finish. All variance/tolerance/approval rules are enforced by the
/// backend (StockCountService) — this cubit never duplicates that logic, it
/// only reacts to what the backend reports.
class BarCheckCubit extends Cubit<BarCheckState> {
  BarCheckCubit({required this.repository}) : super(const BarCheckState());

  final ShiftCloseRepository repository;

  Future<void> start({required int shiftId, required int warehouseId}) async {
    emit(const BarCheckState());
    try {
      final BarCheckSession session = await repository.startBarCheck(
        shiftId: shiftId,
        warehouseId: warehouseId,
      );
      emit(BarCheckState(status: BarCheckStatus.ready, session: session));
    } on ApiException catch (error) {
      emit(
        BarCheckState(status: BarCheckStatus.error, errorMessage: error.message),
      );
    }
  }

  Future<void> countLine({
    required int itemId,
    required String countedQuantity,
    required String unit,
    String? reason,
  }) async {
    final BarCheckSession? session = state.session;
    if (session == null) return;
    emit(
      state.copyWith(status: BarCheckStatus.submitting, clearErrorMessage: true),
    );
    try {
      final BarCheckSession updated = await repository.upsertLine(
        countId: session.id,
        itemId: itemId,
        countedQuantity: countedQuantity,
        unit: unit,
        reason: reason,
      );
      emit(state.copyWith(status: BarCheckStatus.ready, session: updated));
    } on ApiException catch (error) {
      emit(
        state.copyWith(status: BarCheckStatus.ready, errorMessage: error.message),
      );
    }
  }

  /// Submits the count and, when nothing requires a manager's review,
  /// carries it straight through approve + post so the cashier never has to
  /// enter the Inventory Center to finish their own shift's check.
  Future<bool> submitAndFinish() async {
    final BarCheckSession? session = state.session;
    if (session == null) return false;
    emit(
      state.copyWith(status: BarCheckStatus.submitting, clearErrorMessage: true),
    );
    try {
      BarCheckSession updated = await repository.transition(
        session.id,
        'submit',
      );
      if (updated.hasPendingManagerReview) {
        emit(
          state.copyWith(
            status: BarCheckStatus.ready,
            session: updated,
            blockedOnManagerReview: true,
          ),
        );
        return false;
      }
      updated = await repository.transition(session.id, 'approve');
      updated = await repository.transition(session.id, 'post');
      emit(state.copyWith(status: BarCheckStatus.posted, session: updated));
      return true;
    } on ApiException catch (error) {
      final bool managerReviewPending =
          error.statusCode == 422 &&
          error.message.toLowerCase().contains('manager review');
      emit(
        state.copyWith(
          status: BarCheckStatus.ready,
          blockedOnManagerReview: managerReviewPending,
          errorMessage: managerReviewPending ? null : error.message,
        ),
      );
      return false;
    }
  }
}
