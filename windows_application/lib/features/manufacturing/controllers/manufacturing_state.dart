import 'package:equatable/equatable.dart';

import '../models/manufacturing_models.dart';

class ManufacturingState extends Equatable {
  const ManufacturingState({this.loading = false, this.overview, this.error});

  final bool loading;
  final ManufacturingOverview? overview;
  final String? error;

  ManufacturingState copyWith({
    bool? loading,
    ManufacturingOverview? overview,
    String? error,
    bool clearError = false,
  }) => ManufacturingState(
    loading: loading ?? this.loading,
    overview: overview ?? this.overview,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => <Object?>[loading, overview, error];
}
