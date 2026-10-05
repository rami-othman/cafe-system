import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/cafe_configuration_models.dart';
import '../repositories/cafe_configuration_repository.dart';

enum TaxLoadStatus { loading, ready, failure, saving, success }

class TaxState extends Equatable {
  const TaxState({
    this.status = TaxLoadStatus.loading,
    this.tax,
    this.draftPercentage = '',
    this.error,
  });
  final TaxLoadStatus status;
  final CafeTax? tax;
  final String draftPercentage;
  final String? error;
  bool get isDirty =>
      tax != null &&
      _parsePercentage(draftPercentage) != null &&
      (_parsePercentage(draftPercentage)! - tax!.percentage).abs() > 0.000001;
  TaxState copyWith({
    TaxLoadStatus? status,
    CafeTax? tax,
    String? draftPercentage,
    String? error,
    bool clearError = false,
  }) => TaxState(
    status: status ?? this.status,
    tax: tax ?? this.tax,
    draftPercentage: draftPercentage ?? this.draftPercentage,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    tax?.rate,
    draftPercentage,
    error,
  ];
}

class TaxCubit extends Cubit<TaxState> {
  TaxCubit(this._repository) : super(const TaxState());
  final CafeConfigurationRepository _repository;
  Future<void> load() async {
    emit(const TaxState());
    try {
      final CafeTax tax = await _repository.getTax();
      emit(
        TaxState(
          status: TaxLoadStatus.ready,
          tax: tax,
          draftPercentage: _displayPercentage(tax.percentage),
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: TaxLoadStatus.failure, error: 'load'));
    }
  }

  void update(String value) => emit(
    state.copyWith(
      draftPercentage: value,
      status: TaxLoadStatus.ready,
      clearError: true,
    ),
  );
  void reset() {
    final CafeTax? tax = state.tax;
    if (tax != null) {
      emit(
        state.copyWith(
          status: TaxLoadStatus.ready,
          draftPercentage: _displayPercentage(tax.percentage),
          clearError: true,
        ),
      );
    }
  }

  Future<bool> save() async {
    if (state.status == TaxLoadStatus.saving || !state.isDirty) return false;
    final double? percentage = _parsePercentage(state.draftPercentage);
    if (percentage == null || percentage < 0 || percentage > 100) {
      emit(state.copyWith(status: TaxLoadStatus.failure, error: 'invalid'));
      return false;
    }
    emit(state.copyWith(status: TaxLoadStatus.saving, clearError: true));
    try {
      final CafeTax saved = await _repository.updateTax(percentage / 100);
      emit(
        TaxState(
          status: TaxLoadStatus.success,
          tax: saved,
          draftPercentage: _displayPercentage(saved.percentage),
        ),
      );
      return true;
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: TaxLoadStatus.failure,
          error: error.type == ApiErrorType.validation ? 'validation' : 'save',
        ),
      );
      return false;
    } catch (_) {
      emit(state.copyWith(status: TaxLoadStatus.failure, error: 'save'));
      return false;
    }
  }
}

double? _parsePercentage(String value) => double.tryParse(value.trim());
String _displayPercentage(double value) => value.toStringAsFixed(2);
