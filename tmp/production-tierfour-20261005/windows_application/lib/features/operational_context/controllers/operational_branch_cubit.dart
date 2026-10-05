import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/operational_branch_state.dart';
import '../repositories/operational_branch_repository.dart';

class OperationalBranchCubit extends Cubit<OperationalBranchState> {
  OperationalBranchCubit({required this.repository})
    : super(const OperationalBranchState());

  final OperationalBranchReader repository;

  Future<void> loadBranches({int? preferredBranchId}) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final branches = await repository.getActiveBranches();
      final requestedId = preferredBranchId ?? state.selectedBranchId;
      final selectedId = branches.any((branch) => branch.id == requestedId)
          ? requestedId
          : (branches.isEmpty ? null : branches.first.id);
      emit(
        state.copyWith(
          branches: branches,
          selectedBranchId: selectedId,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'تعذر تحميل الفروع التشغيلية.',
        ),
      );
    }
  }

  void selectBranch(int branchId) {
    if (!state.branches.any((branch) => branch.id == branchId) ||
        state.selectedBranchId == branchId) {
      return;
    }
    emit(state.copyWith(selectedBranchId: branchId, clearError: true));
  }

  /// The Manufacturing context's branch resolution (Phase 2): pick a
  /// `branch_type == 'factory'` branch and never a cafe one, independently
  /// of [PosCubit]. Order: the currently selected branch if it is already a
  /// factory branch, then the first of [preferredIds] (the session's
  /// `factoryBranchIds`) that is an active factory branch, then simply the
  /// first active factory branch. `selectedBranchId` is left `null` when no
  /// factory branch exists at all, so callers can render an empty state
  /// instead of silently falling back to a cafe branch.
  Future<void> ensureFactoryBranch({List<int>? preferredIds}) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final branches = await repository.getActiveBranches();
      final factoryBranches = branches.where((branch) => branch.isFactory);

      int? selectedId;
      if (factoryBranches.any((branch) => branch.id == state.selectedBranchId)) {
        selectedId = state.selectedBranchId;
      } else if (preferredIds != null) {
        for (final int candidate in preferredIds) {
          if (factoryBranches.any((branch) => branch.id == candidate)) {
            selectedId = candidate;
            break;
          }
        }
      }
      selectedId ??= factoryBranches.isEmpty
          ? null
          : factoryBranches.first.id;

      emit(
        state.copyWith(
          branches: branches,
          selectedBranchId: selectedId,
          clearSelectedBranch: selectedId == null,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'تعذر تحميل فرع المعمل.',
        ),
      );
    }
  }
}
