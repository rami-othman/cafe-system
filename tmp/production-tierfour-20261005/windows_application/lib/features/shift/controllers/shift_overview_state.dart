import 'package:equatable/equatable.dart';

import '../models/shift_assessment.dart';
import '../models/shift_models.dart';

enum ShiftOverviewStatus { initial, loading, ready, empty, error }

/// Current-shift screen state. [empty] is a first-class outcome, not an
/// error: a register with no open shift renders the shift-opening panel.
class ShiftOverviewState extends Equatable {
  const ShiftOverviewState({
    this.status = ShiftOverviewStatus.initial,
    this.snapshot,
    this.assessment,
    this.lastShift,
    this.openingFloatInput = '',
    this.openingNoteInput = '',
    this.openingFloatError,
    this.isOpeningShift = false,
    this.errorMessage,
  });

  final ShiftOverviewStatus status;
  final ShiftSnapshot? snapshot;
  final ShiftAssessment? assessment;

  /// Continuity for the empty state: the shift that closed most recently.
  final ShiftHistoryEntry? lastShift;

  final String openingFloatInput;
  final String openingNoteInput;
  final String? openingFloatError;
  final bool isOpeningShift;
  final String? errorMessage;

  bool get isLoading => status == ShiftOverviewStatus.loading;

  bool get hasOpenShift =>
      status == ShiftOverviewStatus.ready && snapshot != null;

  bool get canSubmitOpening =>
      openingFloatInput.trim().isNotEmpty && !isOpeningShift;

  ShiftOverviewState copyWith({
    ShiftOverviewStatus? status,
    ShiftSnapshot? snapshot,
    bool clearSnapshot = false,
    ShiftAssessment? assessment,
    bool clearAssessment = false,
    ShiftHistoryEntry? lastShift,
    bool clearLastShift = false,
    String? openingFloatInput,
    String? openingNoteInput,
    String? openingFloatError,
    bool clearOpeningFloatError = false,
    bool? isOpeningShift,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => ShiftOverviewState(
    status: status ?? this.status,
    snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
    assessment: clearAssessment ? null : assessment ?? this.assessment,
    lastShift: clearLastShift ? null : lastShift ?? this.lastShift,
    openingFloatInput: openingFloatInput ?? this.openingFloatInput,
    openingNoteInput: openingNoteInput ?? this.openingNoteInput,
    openingFloatError: clearOpeningFloatError
        ? null
        : openingFloatError ?? this.openingFloatError,
    isOpeningShift: isOpeningShift ?? this.isOpeningShift,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    snapshot,
    assessment,
    lastShift,
    openingFloatInput,
    openingNoteInput,
    openingFloatError,
    isOpeningShift,
    errorMessage,
  ];
}
