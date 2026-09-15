import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/shift_models.dart';
import '../repositories/shift_mock_repository.dart';
import '../widgets/shift_strings.dart';

enum ShiftReportStatus { loading, ready, missing, error }

/// Which print layout the preview renders.
enum ShiftPrintLayout { a4, receipt }

class ShiftReportState extends Equatable {
  const ShiftReportState({
    this.status = ShiftReportStatus.loading,
    this.result,
    this.printLayout = ShiftPrintLayout.a4,
    this.showPrintPreview = false,
    this.errorMessage,
  });

  final ShiftReportStatus status;
  final ShiftClosingResult? result;
  final ShiftPrintLayout printLayout;
  final bool showPrintPreview;
  final String? errorMessage;

  ShiftReportState copyWith({
    ShiftReportStatus? status,
    ShiftClosingResult? result,
    ShiftPrintLayout? printLayout,
    bool? showPrintPreview,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => ShiftReportState(
    status: status ?? this.status,
    result: result ?? this.result,
    printLayout: printLayout ?? this.printLayout,
    showPrintPreview: showPrintPreview ?? this.showPrintPreview,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    result,
    printLayout,
    showPrintPreview,
    errorMessage,
  ];
}

/// Loads one sealed shift report and owns the print-preview toggle.
class ShiftReportCubit extends Cubit<ShiftReportState> {
  ShiftReportCubit({required this.repository})
    : super(const ShiftReportState());

  final ShiftMockRepository repository;

  Future<void> load(String shiftNumber) async {
    emit(
      state.copyWith(
        status: ShiftReportStatus.loading,
        clearErrorMessage: true,
      ),
    );
    try {
      final ShiftClosingResult? result = await repository.loadClosingResult(
        shiftNumber,
      );
      if (isClosed) return;
      if (result == null) {
        emit(
          state.copyWith(
            status: ShiftReportStatus.missing,
            errorMessage: ShiftStrings.reportNotFound,
          ),
        );
        return;
      }
      emit(state.copyWith(status: ShiftReportStatus.ready, result: result));
    } on ShiftDataException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ShiftReportStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  void showPrintPreview(ShiftPrintLayout layout) =>
      emit(state.copyWith(showPrintPreview: true, printLayout: layout));

  void setPrintLayout(ShiftPrintLayout layout) =>
      emit(state.copyWith(printLayout: layout));

  void hidePrintPreview() => emit(state.copyWith(showPrintPreview: false));
}
