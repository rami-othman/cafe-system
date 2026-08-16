// ignore_for_file: curly_braces_in_flow_control_structures, use_null_aware_elements

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../modifiers/models/modifier_models.dart';
import '../../recipes/models/recipe_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/product_modifier_assignment.dart';
import 'product_modifier_assignments_state.dart';

class ProductModifierAssignmentsCubit
    extends Cubit<ProductModifierAssignmentsState> {
  ProductModifierAssignmentsCubit({required this.repository})
    : super(const ProductModifierAssignmentsState());
  final MenuCatalogRepository repository;

  Future<void> load(int productId, {bool refresh = false}) async {
    if (isClosed || state.isSaving) return;
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
      if (isClosed) return;
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
      final Set<int> materialImpactConfiguredGroupIds =
          await _materialImpactGroups(product.id, assignments);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProductModifierAssignmentsStatus.loaded,
          product: product,
          assignments: List.unmodifiable(assignments),
          loadedAssignments: List.unmodifiable(assignments),
          availableGroups: (results[2] as dynamic).items,
          materialImpactConfiguredGroupIds: materialImpactConfiguredGroupIds,
          clearErrors: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ProductModifierAssignmentsStatus.failure,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<Set<int>> _materialImpactGroups(
    int productId,
    List<ProductModifierAssignment> assignments,
  ) async {
    final Set<int> groups = <int>{};
    for (final ProductModifierAssignment assignment in assignments) {
      final ModifierGroupRecord group;
      try {
        group = await repository.getModifierGroup(assignment.modifierGroupId);
      } catch (_) {
        continue;
      }
      final Iterable<ModifierOptionRecord> options = group.options;
      for (final ModifierOptionRecord option in options) {
        try {
          final ModifierRecipeProfile profile = await repository
              .getModifierRecipeProfile(option.id, productId: productId);
          if (profile.components.isNotEmpty) {
            groups.add(assignment.modifierGroupId);
            break;
          }
        } catch (_) {
          // This is purely an informational indicator. Do not fail the
          // assignment screen if an optional recipe profile cannot be read.
        }
      }
    }
    return groups;
  }

  Future<void> refresh() {
    if (isClosed || state.product == null) return Future<void>.value();
    return load(state.product!.id, refresh: true);
  }

  void add(ModifierGroupRecord group) {
    if (isClosed ||
        state.isSaving ||
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
    if (isClosed || state.product?.isArchived == true) return;
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
    if (isClosed || state.product?.isArchived == true) return;
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
    if (isClosed) return;
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
    if (isClosed ||
        state.isSaving ||
        state.product == null ||
        state.product!.isArchived) {
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
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false));
      await load(state.product!.id, refresh: true);
      if (isClosed) return false;
      emit(
        state.copyWith(
          successMessage: 'Product modifiers updated successfully.',
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
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
