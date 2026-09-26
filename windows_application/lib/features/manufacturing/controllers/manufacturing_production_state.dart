import 'package:equatable/equatable.dart';

import '../models/manufacturing_production_models.dart';

class ManufacturingProductionState extends Equatable {
  const ManufacturingProductionState({
    this.loading = false,
    this.submitting = false,
    this.orders = const <ManufacturingProductionListItem>[],
    this.preview,
    this.draft,
    this.result,
    this.selected,
    this.error,
  });

  final bool loading;
  final bool submitting;
  final List<ManufacturingProductionListItem> orders;
  final ManufacturingProductionPreview? preview;
  final ManufacturingProductionDraft? draft;

  /// The order returned by completion or reversal - the Success/Details
  /// screens render this directly, never a client-computed projection.
  final ManufacturingProductionOrder? result;
  final ManufacturingProductionOrder? selected;
  final String? error;

  ManufacturingProductionState copyWith({
    bool? loading,
    bool? submitting,
    List<ManufacturingProductionListItem>? orders,
    ManufacturingProductionPreview? preview,
    ManufacturingProductionDraft? draft,
    ManufacturingProductionOrder? result,
    ManufacturingProductionOrder? selected,
    String? error,
    bool clearError = false,
    bool clearPreview = false,
    bool clearDraft = false,
  }) => ManufacturingProductionState(
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    orders: orders ?? this.orders,
    preview: clearPreview ? null : preview ?? this.preview,
    draft: clearDraft ? null : draft ?? this.draft,
    result: result ?? this.result,
    selected: selected ?? this.selected,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => <Object?>[
    loading,
    submitting,
    orders,
    preview,
    draft,
    result,
    selected,
    error,
  ];
}
