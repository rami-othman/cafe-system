import 'package:equatable/equatable.dart';

import '../models/manufacturing_report_models.dart';

class ManufacturingReportsState extends Equatable {
  const ManufacturingReportsState({
    this.loading = false,
    this.data,
    this.error,
  });

  final bool loading;
  final ManufacturingReportsData? data;
  final String? error;

  ManufacturingReportsState copyWith({
    bool? loading,
    ManufacturingReportsData? data,
    String? error,
    bool clearError = false,
  }) => ManufacturingReportsState(
    loading: loading ?? this.loading,
    data: data ?? this.data,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => <Object?>[loading, data, error];
}
