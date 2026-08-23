import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/operational_branch_state.dart';
import '../repositories/operational_branch_repository.dart';

class OperationalBranchCubit extends Cubit<OperationalBranchState> {
  OperationalBranchCubit({required this.repository})
    : super(const OperationalBranchState());

  final OperationalBranchRepository repository;

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
}
