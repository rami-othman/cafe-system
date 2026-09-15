import 'package:equatable/equatable.dart';

import '../models/shift_assessment.dart';
import '../models/shift_models.dart';

enum ShiftClosingStatus { loading, ready, submitting, closed, error }

/// Which of the two counting affordances step 2 is showing.
enum CashCountMode { direct, denominations }

enum BarCountFilter { all, uncounted, matched, shortage, surplus, differences }

enum BarCountSort { name, category, largestDifference }

/// The five wizard steps, in order. `index + 1` is the number rendered in the
/// stepper, so the order here is the single source of that numbering.
enum ShiftClosingStep {
  operations,
  cashCount,
  barCount,
  finalReview,
  done;

  int get number => index + 1;

  bool get isFirst => this == ShiftClosingStep.operations;

  bool get isDone => this == ShiftClosingStep.done;
}

class ShiftClosingState extends Equatable {
  const ShiftClosingState({
    this.status = ShiftClosingStatus.loading,
    this.step = ShiftClosingStep.operations,
    this.snapshot,
    this.barLines = const <BarCountLine>[],
    this.cashMode = CashCountMode.direct,
    this.cashActualInput = '',
    this.denominationCounts = const <int, String>{},
    this.cashReason,
    this.cashReasonDetail = '',
    this.cashActualError,
    this.cashReasonError,
    this.cashReasonDetailError,
    this.barSearch = '',
    this.barFilter = BarCountFilter.all,
    this.barSort = BarCountSort.name,
    this.barCountSubmitted = false,
    this.closingNotes = '',
    this.acknowledged = false,
    this.result,
    this.savedAt,
    this.errorMessage,
  });

  final ShiftClosingStatus status;
  final ShiftClosingStep step;
  final ShiftSnapshot? snapshot;

  /// Working copy of the template: counting edits never mutate the snapshot.
  final List<BarCountLine> barLines;

  final CashCountMode cashMode;
  final String cashActualInput;
  final Map<int, String> denominationCounts;
  final CashDifferenceReason? cashReason;
  final String cashReasonDetail;
  final String? cashActualError;
  final String? cashReasonError;
  final String? cashReasonDetailError;

  final String barSearch;
  final BarCountFilter barFilter;
  final BarCountSort barSort;

  /// True once step 3 has been left via "save and continue".
  final bool barCountSubmitted;

  final String closingNotes;
  final bool acknowledged;
  final ShiftClosingResult? result;

  /// Drives the "تم الحفظ تلقائيًا" indicator in the wizard footer.
  final DateTime? savedAt;
  final String? errorMessage;

  bool get isLoading => status == ShiftClosingStatus.loading;

  bool get isSubmitting => status == ShiftClosingStatus.submitting;

  /// The live bar template — snapshot metadata with the working lines.
  BarCountTemplate? get barTemplate =>
      snapshot?.barCount.copyWith(lines: barLines);

  /// The sum of the denomination panel, which "apply" copies into the field.
  double get denominationTotal => denominationCounts.entries.fold(
    0,
    (double sum, MapEntry<int, String> e) =>
        sum + (int.tryParse(e.value.trim()) ?? 0) * e.key,
  );

  /// Parsed counted cash, or null while the field is empty/invalid. Null is
  /// what keeps the reconciliation panel hidden until a real count exists.
  double? get actualCash {
    final String raw = cashActualInput.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    final double? parsed = double.tryParse(raw);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  double get expectedCash => snapshot?.drawer.expected ?? 0;

  CashCountResult? get cashCount {
    final double? actual = actualCash;
    if (actual == null) return null;
    return CashCountResult(
      expected: expectedCash,
      actual: actual,
      reason: cashReason,
      reasonDetail: cashReasonDetail,
    );
  }

  bool get requiresCashReason {
    final CashCountResult? cash = cashCount;
    return cash != null && !cash.isBalanced;
  }

  /// Bar lines after search, filter and sort — what the list actually shows.
  List<BarCountLine> get visibleBarLines {
    final String query = barSearch.trim();
    Iterable<BarCountLine> lines = barLines;

    if (query.isNotEmpty) {
      lines = lines.where(
        (BarCountLine l) =>
            l.name.contains(query) ||
            l.sku.toLowerCase().contains(query.toLowerCase()) ||
            l.category.contains(query),
      );
    }

    lines = switch (barFilter) {
      BarCountFilter.all => lines,
      BarCountFilter.uncounted => lines.where((BarCountLine l) => !l.isCounted),
      BarCountFilter.matched => lines.where(
        (BarCountLine l) => l.status == BarCountStatus.match,
      ),
      BarCountFilter.shortage => lines.where(
        (BarCountLine l) => l.status == BarCountStatus.shortage,
      ),
      BarCountFilter.surplus => lines.where(
        (BarCountLine l) => l.status == BarCountStatus.surplus,
      ),
      BarCountFilter.differences => lines.where(
        (BarCountLine l) => l.hasDifference,
      ),
    };

    final List<BarCountLine> sorted = lines.toList();
    switch (barSort) {
      case BarCountSort.name:
        sorted.sort((BarCountLine a, BarCountLine b) => a.name.compareTo(b.name));
      case BarCountSort.category:
        sorted.sort((BarCountLine a, BarCountLine b) {
          final int byCategory = a.category.compareTo(b.category);
          return byCategory != 0 ? byCategory : a.name.compareTo(b.name);
        });
      case BarCountSort.largestDifference:
        sorted.sort((BarCountLine a, BarCountLine b) {
          final double aDiff = (a.differenceValue ?? 0).abs();
          final double bDiff = (b.differenceValue ?? 0).abs();
          return bDiff.compareTo(aDiff);
        });
    }
    return sorted;
  }

  ShiftAssessment? get assessment {
    final ShiftSnapshot? current = snapshot;
    if (current == null) return null;
    return ShiftAssessment.build(
      snapshot: current.copyWith(barCount: barTemplate),
      cash: cashCount,
      barCountSubmitted: barCountSubmitted,
      currentStage: _stageForStep,
      closed: status == ShiftClosingStatus.closed,
    );
  }

  ShiftStage get _stageForStep => switch (step) {
    ShiftClosingStep.operations => ShiftStage.operationsReview,
    ShiftClosingStep.cashCount => ShiftStage.cashCount,
    ShiftClosingStep.barCount => ShiftStage.barCount,
    ShiftClosingStep.finalReview => ShiftStage.finalReview,
    ShiftClosingStep.done => ShiftStage.closed,
  };

  ShiftClosingState copyWith({
    ShiftClosingStatus? status,
    ShiftClosingStep? step,
    ShiftSnapshot? snapshot,
    List<BarCountLine>? barLines,
    CashCountMode? cashMode,
    String? cashActualInput,
    Map<int, String>? denominationCounts,
    CashDifferenceReason? cashReason,
    bool clearCashReason = false,
    String? cashReasonDetail,
    String? cashActualError,
    bool clearCashActualError = false,
    String? cashReasonError,
    bool clearCashReasonError = false,
    String? cashReasonDetailError,
    bool clearCashReasonDetailError = false,
    String? barSearch,
    BarCountFilter? barFilter,
    BarCountSort? barSort,
    bool? barCountSubmitted,
    String? closingNotes,
    bool? acknowledged,
    ShiftClosingResult? result,
    DateTime? savedAt,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => ShiftClosingState(
    status: status ?? this.status,
    step: step ?? this.step,
    snapshot: snapshot ?? this.snapshot,
    barLines: barLines ?? this.barLines,
    cashMode: cashMode ?? this.cashMode,
    cashActualInput: cashActualInput ?? this.cashActualInput,
    denominationCounts: denominationCounts ?? this.denominationCounts,
    cashReason: clearCashReason ? null : cashReason ?? this.cashReason,
    cashReasonDetail: cashReasonDetail ?? this.cashReasonDetail,
    cashActualError: clearCashActualError
        ? null
        : cashActualError ?? this.cashActualError,
    cashReasonError: clearCashReasonError
        ? null
        : cashReasonError ?? this.cashReasonError,
    cashReasonDetailError: clearCashReasonDetailError
        ? null
        : cashReasonDetailError ?? this.cashReasonDetailError,
    barSearch: barSearch ?? this.barSearch,
    barFilter: barFilter ?? this.barFilter,
    barSort: barSort ?? this.barSort,
    barCountSubmitted: barCountSubmitted ?? this.barCountSubmitted,
    closingNotes: closingNotes ?? this.closingNotes,
    acknowledged: acknowledged ?? this.acknowledged,
    result: result ?? this.result,
    savedAt: savedAt ?? this.savedAt,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    step,
    snapshot,
    barLines,
    cashMode,
    cashActualInput,
    denominationCounts,
    cashReason,
    cashReasonDetail,
    cashActualError,
    cashReasonError,
    cashReasonDetailError,
    barSearch,
    barFilter,
    barSort,
    barCountSubmitted,
    closingNotes,
    acknowledged,
    result,
    savedAt,
    errorMessage,
  ];
}
