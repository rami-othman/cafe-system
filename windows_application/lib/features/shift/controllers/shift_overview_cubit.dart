import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/shift_assessment.dart';
import '../models/shift_models.dart';
import '../models/shift_scenario.dart';
import '../repositories/shift_mock_repository.dart';
import '../widgets/shift_strings.dart';
import 'shift_overview_state.dart';

/// Owns the current-shift screen: loading the open shift, deriving its
/// alerts/readiness, and validating the shift-opening form.
class ShiftOverviewCubit extends Cubit<ShiftOverviewState> {
  ShiftOverviewCubit({required this.repository})
    : super(ShiftOverviewState(scenario: repository.scenario));

  final ShiftMockRepository repository;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: ShiftOverviewStatus.loading,
        scenario: repository.scenario,
        clearErrorMessage: true,
      ),
    );
    try {
      final ShiftSnapshot? snapshot = await repository.loadOpenShift();
      if (isClosed) return;
      if (snapshot == null) {
        final ShiftHistoryEntry? last = await repository.loadLastShift();
        if (isClosed) return;
        emit(
          state.copyWith(
            status: ShiftOverviewStatus.empty,
            clearSnapshot: true,
            clearAssessment: true,
            lastShift: last,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: ShiftOverviewStatus.ready,
          snapshot: snapshot,
          assessment: ShiftAssessment.build(
            snapshot: snapshot,
            currentStage: ShiftStage.selling,
          ),
          clearErrorMessage: true,
        ),
      );
    } on ShiftDataException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ShiftOverviewStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  /// Switches the demo scenario and reloads. Debug-only affordance.
  Future<void> selectScenario(ShiftScenario scenario) async {
    repository.selectScenario(scenario);
    emit(
      state.copyWith(
        scenario: scenario,
        openingFloatInput: '',
        openingNoteInput: '',
        clearOpeningFloatError: true,
      ),
    );
    await load();
  }

  void updateOpeningFloat(String value) => emit(
    state.copyWith(openingFloatInput: value, clearOpeningFloatError: true),
  );

  void updateOpeningNote(String value) =>
      emit(state.copyWith(openingNoteInput: value));

  /// Validates the opening float. Returns the parsed amount, or null when the
  /// input is empty, not numeric, or negative — each surfaced as field copy.
  double? validateOpeningFloat() {
    final String raw = state.openingFloatInput.trim().replaceAll(',', '');
    if (raw.isEmpty) {
      emit(
        state.copyWith(openingFloatError: ShiftStrings.openingFloatRequired),
      );
      return null;
    }
    final double? parsed = double.tryParse(raw);
    if (parsed == null) {
      emit(state.copyWith(openingFloatError: ShiftStrings.amountMustBeNumeric));
      return null;
    }
    if (parsed < 0) {
      emit(
        state.copyWith(openingFloatError: ShiftStrings.amountCannotBeNegative),
      );
      return null;
    }
    emit(state.copyWith(clearOpeningFloatError: true));
    return parsed;
  }

  Future<bool> openShift() async {
    final double? amount = validateOpeningFloat();
    if (amount == null) return false;

    emit(state.copyWith(isOpeningShift: true));
    final ShiftSnapshot snapshot = await repository.openShift(
      openingFloat: amount,
      note: state.openingNoteInput.trim(),
    );
    if (isClosed) return false;
    emit(
      state.copyWith(
        status: ShiftOverviewStatus.ready,
        scenario: repository.scenario,
        snapshot: snapshot,
        assessment: ShiftAssessment.build(
          snapshot: snapshot,
          currentStage: ShiftStage.selling,
        ),
        isOpeningShift: false,
        openingFloatInput: '',
        openingNoteInput: '',
        clearOpeningFloatError: true,
      ),
    );
    return true;
  }
}
