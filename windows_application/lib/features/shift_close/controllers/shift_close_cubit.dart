import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../repositories/shift_close_repository.dart';
import 'shift_close_state.dart';

class ShiftCloseCubit extends Cubit<ShiftCloseState> {
  ShiftCloseCubit({required this.repository}) : super(const ShiftCloseState());

  final ShiftCloseRepository repository;

  /// Attempts to close the shift. When the backend reports a required bar
  /// check is still pending, resolves the branch's required warehouse and
  /// surfaces it via state instead of failing outright — the screen then
  /// routes to the dedicated Bar Check flow for it.
  Future<bool> closeShift({
    required int shiftId,
    required int branchId,
    required double closingCash,
    String? note,
  }) async {
    emit(
      state.copyWith(
        status: ShiftCloseStatus.submitting,
        clearErrorMessage: true,
        clearRequiredBarCheck: true,
      ),
    );
    try {
      await repository.closeShift(
        shiftId: shiftId,
        closingCash: closingCash,
        note: note,
      );
      emit(state.copyWith(status: ShiftCloseStatus.closed));
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 422 && _mentionsBarCheck(error.message)) {
        final int? warehouseId = await repository
            .requiredTemplateWarehouseForBranch(branchId);
        if (warehouseId != null) {
          emit(
            state.copyWith(
              status: ShiftCloseStatus.idle,
              requiredBarCheckWarehouseId: warehouseId,
            ),
          );
          return false;
        }
      }
      emit(
        state.copyWith(
          status: ShiftCloseStatus.error,
          errorMessage: error.message,
        ),
      );
      return false;
    }
  }

  void acknowledgeBarCheckRoute() =>
      emit(state.copyWith(clearRequiredBarCheck: true));

  bool _mentionsBarCheck(String message) =>
      message.toLowerCase().contains('bar check');
}
