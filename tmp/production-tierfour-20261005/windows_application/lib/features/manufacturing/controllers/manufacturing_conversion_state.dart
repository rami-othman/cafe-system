import 'package:equatable/equatable.dart';

import '../models/manufacturing_conversion_models.dart';

class ManufacturingConversionState extends Equatable {
  const ManufacturingConversionState({
    this.submitting = false,
    this.loading = false,
    this.result,
    this.error,
  });

  final bool submitting;
  final bool loading;
  final ManufacturingConversionResult? result;
  final String? error;

  ManufacturingConversionState copyWith({
    bool? submitting,
    bool? loading,
    ManufacturingConversionResult? result,
    String? error,
    bool clearError = false,
  }) => ManufacturingConversionState(
    submitting: submitting ?? this.submitting,
    loading: loading ?? this.loading,
    result: result ?? this.result,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => <Object?>[submitting, loading, result, error];
}
