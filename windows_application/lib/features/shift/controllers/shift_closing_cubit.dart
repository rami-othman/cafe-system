import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/shift_models.dart';
import '../repositories/shift_mock_repository.dart';
import '../widgets/shift_strings.dart';
import 'shift_closing_state.dart';

/// Drives the five-step closing wizard.
///
/// Validation lives here rather than in the views so the "next" button, the
/// inline field errors and the final confirmation dialog can never disagree
/// about whether a step is complete.
class ShiftClosingCubit extends Cubit<ShiftClosingState> {
  ShiftClosingCubit({required this.repository})
    : super(const ShiftClosingState());

  final ShiftMockRepository repository;

  Future<void> load() async {
    emit(state.copyWith(status: ShiftClosingStatus.loading));
    try {
      final ShiftSnapshot? snapshot = await repository.loadOpenShift();
      if (isClosed) return;
      if (snapshot == null) {
        emit(
          state.copyWith(
            status: ShiftClosingStatus.error,
            errorMessage: ShiftStrings.noOpenShift,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: ShiftClosingStatus.ready,
          snapshot: snapshot,
          barLines: List<BarCountLine>.of(snapshot.barCount.lines),
          clearErrorMessage: true,
        ),
      );
    } on ShiftDataException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ShiftClosingStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────

  /// Advances one step when the current step validates. Returns false (and
  /// emits field errors) when it does not.
  bool goNext() {
    switch (state.step) {
      case ShiftClosingStep.operations:
        _goTo(ShiftClosingStep.cashCount);
        return true;
      case ShiftClosingStep.cashCount:
        if (!validateCashStep()) return false;
        _goTo(ShiftClosingStep.barCount);
        return true;
      case ShiftClosingStep.barCount:
        emit(state.copyWith(barCountSubmitted: true));
        _goTo(ShiftClosingStep.finalReview);
        return true;
      case ShiftClosingStep.finalReview:
      case ShiftClosingStep.done:
        return false;
    }
  }

  void goBack() {
    switch (state.step) {
      case ShiftClosingStep.cashCount:
        _goTo(ShiftClosingStep.operations);
      case ShiftClosingStep.barCount:
        _goTo(ShiftClosingStep.cashCount);
      case ShiftClosingStep.finalReview:
        _goTo(ShiftClosingStep.barCount);
      case ShiftClosingStep.operations:
      case ShiftClosingStep.done:
        break;
    }
  }

  /// Jumping backwards from the stepper is allowed; jumping ahead is not,
  /// because later steps depend on the current one validating.
  void jumpTo(ShiftClosingStep step) {
    if (state.step.isDone) return;
    if (step.index < state.step.index) _goTo(step);
  }

  void _goTo(ShiftClosingStep step) =>
      emit(state.copyWith(step: step, savedAt: repository.now));

  // ── Step 2: cash ────────────────────────────────────────────────────

  void setCashMode(CashCountMode mode) => emit(state.copyWith(cashMode: mode));

  void updateActualCash(String value) => emit(
    state.copyWith(cashActualInput: value, clearCashActualError: true),
  );

  void updateDenomination(int denomination, String quantity) {
    final Map<int, String> next = Map<int, String>.of(state.denominationCounts)
      ..[denomination] = quantity;
    emit(state.copyWith(denominationCounts: next));
  }

  /// Copies the denomination panel total into the amount field.
  void applyDenominationTotal() => emit(
    state.copyWith(
      cashActualInput: state.denominationTotal.round().toString(),
      cashMode: CashCountMode.direct,
      clearCashActualError: true,
      savedAt: repository.now,
    ),
  );

  void selectCashReason(CashDifferenceReason reason) => emit(
    state.copyWith(
      cashReason: reason,
      clearCashReasonError: true,
      clearCashReasonDetailError: true,
    ),
  );

  void updateCashReasonDetail(String value) => emit(
    state.copyWith(
      cashReasonDetail: value,
      clearCashReasonDetailError: true,
    ),
  );

  /// Cash rules: an amount is required, must parse, must not be negative; and
  /// any non-zero difference needs a reason (with free text when "other").
  bool validateCashStep() {
    final String raw = state.cashActualInput.trim().replaceAll(',', '');
    if (raw.isEmpty) {
      emit(state.copyWith(cashActualError: ShiftStrings.actualCashRequired));
      return false;
    }
    final double? parsed = double.tryParse(raw);
    if (parsed == null) {
      emit(state.copyWith(cashActualError: ShiftStrings.amountMustBeNumeric));
      return false;
    }
    if (parsed < 0) {
      emit(
        state.copyWith(cashActualError: ShiftStrings.amountCannotBeNegative),
      );
      return false;
    }

    if (state.requiresCashReason) {
      if (state.cashReason == null) {
        emit(
          state.copyWith(
            clearCashActualError: true,
            cashReasonError: ShiftStrings.cashDifferenceReasonRequired,
          ),
        );
        return false;
      }
      if (state.cashReason == CashDifferenceReason.other &&
          state.cashReasonDetail.trim().isEmpty) {
        emit(
          state.copyWith(
            clearCashActualError: true,
            clearCashReasonError: true,
            cashReasonDetailError: ShiftStrings.additionalDetailsRequired,
          ),
        );
        return false;
      }
    }

    emit(
      state.copyWith(
        clearCashActualError: true,
        clearCashReasonError: true,
        clearCashReasonDetailError: true,
        savedAt: repository.now,
      ),
    );
    return true;
  }

  // ── Step 3: bar count ───────────────────────────────────────────────

  void updateBarSearch(String value) => emit(state.copyWith(barSearch: value));

  void setBarFilter(BarCountFilter filter) =>
      emit(state.copyWith(barFilter: filter));

  void setBarSort(BarCountSort sort) => emit(state.copyWith(barSort: sort));

  /// Records a counted quantity. An empty or unparsable string clears the
  /// count back to "not counted" rather than storing zero.
  void updateCountedQuantity(String lineId, String value) {
    final String raw = value.trim().replaceAll(',', '');
    final double? parsed = raw.isEmpty ? null : double.tryParse(raw);
    _replaceLine(
      lineId,
      (BarCountLine line) => parsed == null
          ? line.copyWith(clearCounted: true)
          : line.copyWith(counted: parsed),
    );
  }

  void updateLineNote(String lineId, String note) =>
      _replaceLine(lineId, (BarCountLine line) => line.copyWith(note: note));

  void fillWithTheoretical(String lineId) => _replaceLine(
    lineId,
    (BarCountLine line) => line.copyWith(counted: line.theoretical),
  );

  void clearCount(String lineId) =>
      _replaceLine(lineId, (BarCountLine line) => line.copyWith(clearCounted: true));

  /// Bulk affordance for the long tail of untouched items. Confirmed in the
  /// UI first — it writes the theoretical quantity into every uncounted line.
  void acceptAllUncountedAsMatching() {
    final List<BarCountLine> next = state.barLines
        .map(
          (BarCountLine line) => line.isCounted
              ? line
              : line.copyWith(counted: line.theoretical),
        )
        .toList();
    emit(state.copyWith(barLines: next, savedAt: repository.now));
  }

  /// The next line still awaiting a count, for keyboard "next" navigation.
  String? nextUncountedAfter(String lineId) {
    final List<BarCountLine> visible = state.visibleBarLines;
    final int index = visible.indexWhere((BarCountLine l) => l.id == lineId);
    if (index < 0) return null;
    for (int i = index + 1; i < visible.length; i++) {
      if (!visible[i].isCounted) return visible[i].id;
    }
    for (int i = 0; i < index; i++) {
      if (!visible[i].isCounted) return visible[i].id;
    }
    return null;
  }

  void _replaceLine(String lineId, BarCountLine Function(BarCountLine) update) {
    final List<BarCountLine> next = state.barLines
        .map((BarCountLine line) => line.id == lineId ? update(line) : line)
        .toList();
    emit(state.copyWith(barLines: next, savedAt: repository.now));
  }

  // ── Step 4/5: review and close ──────────────────────────────────────

  void updateClosingNotes(String value) =>
      emit(state.copyWith(closingNotes: value, savedAt: repository.now));

  void setAcknowledged(bool value) =>
      emit(state.copyWith(acknowledged: value));

  /// Seals the shift. Guarded by [ShiftClosingState.assessment] having no
  /// blockers and by the acknowledgement checkbox in the dialog.
  Future<ShiftClosingResult?> closeShift() async {
    final ShiftSnapshot? snapshot = state.snapshot;
    final CashCountResult? cash = state.cashCount;
    if (snapshot == null || cash == null) return null;
    if (state.assessment?.canClose != true) return null;

    emit(state.copyWith(status: ShiftClosingStatus.submitting));
    final DateTime closedAt = repository.now;
    final ShiftSnapshot sealed = snapshot.copyWith(
      identity: snapshot.identity.copyWith(
        lifecycle: ShiftLifecycle.closed,
        closedAt: closedAt,
        closedBy: snapshot.identity.cashierName,
      ),
      barCount: state.barTemplate,
    );
    final ShiftClosingResult result = ShiftClosingResult(
      snapshot: sealed,
      cash: cash,
      closingNotes: state.closingNotes.trim(),
      closedAt: closedAt,
      closedBy: snapshot.identity.cashierName,
      reportNumber:
          'RPT-${snapshot.identity.shiftNumber.replaceFirst('SH-', '')}',
    );
    await repository.closeShift(result);
    if (isClosed) return result;
    emit(
      state.copyWith(
        status: ShiftClosingStatus.closed,
        step: ShiftClosingStep.done,
        snapshot: sealed,
        result: result,
      ),
    );
    return result;
  }
}
