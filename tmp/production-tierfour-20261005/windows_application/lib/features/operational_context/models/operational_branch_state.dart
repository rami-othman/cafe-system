import 'package:equatable/equatable.dart';

import '../../pos/models/branch.dart';

class OperationalBranchState extends Equatable {
  const OperationalBranchState({
    this.branches = const <Branch>[],
    this.selectedBranchId,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Branch> branches;
  final int? selectedBranchId;
  final bool isLoading;
  final String? errorMessage;

  OperationalBranchState copyWith({
    List<Branch>? branches,
    int? selectedBranchId,
    bool clearSelectedBranch = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) => OperationalBranchState(
    branches: branches ?? this.branches,
    selectedBranchId: clearSelectedBranch
        ? null
        : selectedBranchId ?? this.selectedBranchId,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    branches,
    selectedBranchId,
    isLoading,
    errorMessage,
  ];
}
