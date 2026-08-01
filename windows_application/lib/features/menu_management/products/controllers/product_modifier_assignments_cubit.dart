// ignore_for_file: curly_braces_in_flow_control_structures, use_null_aware_elements

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../modifiers/models/modifier_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/product_modifier_assignment.dart';
import 'product_modifier_assignments_state.dart';

class ProductModifierAssignmentsCubit
    extends Cubit<ProductModifierAssignmentsState> {
  ProductModifierAssignmentsCubit({required this.repository})
    : super(const ProductModifierAssignmentsState());
  final MenuCatalogRepository repository;

  Future<void> load(int productId, {bool refresh = false}) async {
    if (state.isSaving) return;
    emit(
      state.copyWith(
        status: refresh
            ? ProductModifierAssignmentsStatus.refreshing
            : ProductModifierAssignmentsStatus.loading,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        repository.getProduct(productId, includeArchived: true),
        repository.getProductModifierAssignments(productId),
        repository.listModifierGroups(
          filter: const ModifierGroupFilter(status: 'active'),
          page: 1,
          perPage: 100,
        ),
      ]);
      final ProductDetail product = results[0] as ProductDetail;
      if (product.isArchived) {
        emit(
          state.copyWith(
            status: ProductModifierAssignmentsStatus.failure,
            product: product,
            errorMessage:
                'This product has been archived and modifier assignments are read-only.',
          ),
        );
        return;
      }
      final assignments = (results[1] as List<ProductModifierAssignment>)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(
        state.copyWith(
          status: ProductModifierAssignmentsStatus.loaded,
          product: product,
          assignments: List.unmodifiable(assignments),
          loadedAssignments: List.unmodifiable(assignments),
          availableGroups: (results[2] as dynamic).items,
          clearErrors: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductModifierAssignmentsStatus.failure,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> refresh() => load(state.product!.id, refresh: true);
  void add(ModifierGroupRecord group) {
    if (state.isSaving ||
        state.product?.isArchived == true ||
        !group.isActive ||
        group.isArchived ||
        state.assignments.any((item) => item.modifierGroupId == group.id))
      return;
    final next = <ProductModifierAssignment>[
      ...state.assignments,
      ProductModifierAssignment.fromLibrary(
        group,
        sortOrder: state.assignments.length,
      ),
    ];
    emit(
      state.copyWith(
        assignments: next,
        clearErrors: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void update(ProductModifierAssignment assignment) {
    if (state.product?.isArchived == true) return;
    final errors = _validate(assignment);
    final next = state.assignments
        .map(
          (item) => item.modifierGroupId == assignment.modifierGroupId
              ? assignment
              : item,
        )
        .toList(growable: false);
    final fieldErrors = <String, String>{
      if (errors != null)
        'groups.${next.indexWhere((item) => item.modifierGroupId == assignment.modifierGroupId)}':
            errors,
    };
    emit(
      state.copyWith(
        assignments: next,
        fieldErrors: fieldErrors,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void remove(int groupId) {
    if (state.product?.isArchived == true) return;
    emit(
      state.copyWith(
        assignments: _normalise(
          state.assignments
              .where((item) => item.modifierGroupId != groupId)
              .toList(),
        ),
        clearErrors: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void move(int groupId, int direction) {
    final index = state.assignments.indexWhere(
      (item) => item.modifierGroupId == groupId,
    );
    final target = index + direction;
    if (state.isSaving ||
        state.product?.isArchived == true ||
        index < 0 ||
        target < 0 ||
        target >= state.assignments.length)
      return;
    final next = [...state.assignments];
    final item = next.removeAt(index);
    next.insert(target, item);
    emit(
      state.copyWith(
        assignments: _normalise(next),
        clearErrors: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  Future<bool> save() async {
    if (state.isSaving || state.product == null || state.product!.isArchived) {
      return false;
    }
    final errors = <String, String>{};
    for (var i = 0; i < state.assignments.length; i++) {
      final error = _validate(state.assignments[i]);
      if (error != null) errors['groups.$i'] = error;
    }
    if (state.assignments.map((item) => item.modifierGroupId).toSet().length !=
        state.assignments.length)
      errors['groups'] = 'Duplicate modifier groups are not allowed.';
    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors, clearError: true));
      return false;
    }
    emit(
      state.copyWith(
        isSaving: true,
        clearErrors: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      await repository.syncProductModifierAssignments(
        state.product!.id,
        state.assignments,
      );
      emit(state.copyWith(isSaving: false));
      await load(state.product!.id, refresh: true);
      emit(
        state.copyWith(
          successMessage: 'Product modifiers updated successfully.',
        ),
      );
      return true;
    } catch (error) {
      final Map<String, String> mapped =
          error is ApiException && error.validationErrors != null
          ? error.validationErrors!.map(
              (key, value) =>
                  MapEntry(key.replaceFirst('groups.', 'groups.'), value.first),
            )
          : const <String, String>{};
      emit(
        state.copyWith(
          isSaving: false,
          fieldErrors: mapped,
          errorMessage: _message(error),
          clearSuccess: true,
        ),
      );
      return false;
    }
  }

  List<ProductModifierAssignment> _normalise(
    List<ProductModifierAssignment> items,
  ) => List.unmodifiable([
    for (var i = 0; i < items.length; i++) items[i].copyWith(sortOrder: i),
  ]);
  String? _validate(ProductModifierAssignment item) {
    if (!item.isActive || item.isArchived)
      return 'This modifier group is no longer active.';
    if (item.effectiveMinSelections < 0 ||
        item.effectiveMaxSelections < 0 ||
        item.effectiveMaxSelections < item.effectiveMinSelections)
      return 'Maximum must be at least the minimum.';
    if (item.effectiveMaxSelections > item.activeOptionCount)
      return 'Maximum cannot exceed active options.';
    if (item.selectionType == 'single' && item.effectiveMaxSelections > 1)
      return 'Single-selection groups cannot have a maximum above 1.';
    if (item.effectiveIsRequired && item.effectiveMinSelections < 1)
      return 'A required group needs a minimum of at least 1.';
    return null;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update product modifiers.';
}
