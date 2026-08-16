import 'package:equatable/equatable.dart';

import '../../models/catalog_models.dart';
import '../../modifiers/models/modifier_models.dart';
import '../models/product_modifier_assignment.dart';

enum ProductModifierAssignmentsStatus {
  initial,
  loading,
  loaded,
  refreshing,
  failure,
}

class ProductModifierAssignmentsState extends Equatable {
  const ProductModifierAssignmentsState({
    this.status = ProductModifierAssignmentsStatus.initial,
    this.product,
    this.assignments = const <ProductModifierAssignment>[],
    this.loadedAssignments = const <ProductModifierAssignment>[],
    this.availableGroups = const <ModifierGroupRecord>[],
    this.materialImpactConfiguredGroupIds = const <int>{},
    this.fieldErrors = const <String, String>{},
    this.errorMessage,
    this.successMessage,
    this.isSaving = false,
  });
  final ProductModifierAssignmentsStatus status;
  final ProductDetail? product;
  final List<ProductModifierAssignment> assignments;
  final List<ProductModifierAssignment> loadedAssignments;
  final List<ModifierGroupRecord> availableGroups;
  final Set<int> materialImpactConfiguredGroupIds;
  final Map<String, String> fieldErrors;
  final String? errorMessage;
  final String? successMessage;
  final bool isSaving;
  bool get isDirty => _payload(assignments) != _payload(loadedAssignments);
  List<ModifierGroupRecord> get assignableGroups => availableGroups
      .where(
        (group) =>
            group.isActive &&
            !group.isArchived &&
            !assignments.any((item) => item.modifierGroupId == group.id),
      )
      .toList(growable: false);
  ProductModifierAssignmentsState copyWith({
    ProductModifierAssignmentsStatus? status,
    ProductDetail? product,
    List<ProductModifierAssignment>? assignments,
    List<ProductModifierAssignment>? loadedAssignments,
    List<ModifierGroupRecord>? availableGroups,
    Set<int>? materialImpactConfiguredGroupIds,
    Map<String, String>? fieldErrors,
    String? errorMessage,
    String? successMessage,
    bool? isSaving,
    bool clearErrors = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) => ProductModifierAssignmentsState(
    status: status ?? this.status,
    product: product ?? this.product,
    assignments: assignments ?? this.assignments,
    loadedAssignments: loadedAssignments ?? this.loadedAssignments,
    availableGroups: availableGroups ?? this.availableGroups,
    materialImpactConfiguredGroupIds:
        materialImpactConfiguredGroupIds ??
        this.materialImpactConfiguredGroupIds,
    fieldErrors: clearErrors
        ? const <String, String>{}
        : fieldErrors ?? this.fieldErrors,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
    isSaving: isSaving ?? this.isSaving,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    product,
    assignments,
    loadedAssignments,
    availableGroups,
    materialImpactConfiguredGroupIds,
    fieldErrors,
    errorMessage,
    successMessage,
    isSaving,
  ];
}

String _payload(List<ProductModifierAssignment> items) =>
    items.map((item) => item.toSyncJson().toString()).join('|');
