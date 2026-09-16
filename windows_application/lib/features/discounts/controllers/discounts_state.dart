import 'package:equatable/equatable.dart';

import '../models/discount_list_item.dart';
import '../models/discount_form_references.dart';
import '../../pos/models/branch.dart';

class DiscountsState extends Equatable {
  const DiscountsState({
    this.discounts = const <DiscountListItem>[],
    this.searchQuery = '',
    this.selectedStatus,
    this.currentPage = 1,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.branches = const <Branch>[],
    this.isLoadingBranches = false,
    this.branchErrorMessage,
    this.validationErrors = const <String, List<String>>{},
    this.formReferences = const DiscountFormReferences(),
    this.isLoadingFormReferences = false,
    this.formReferencesErrorMessage,
  });

  final List<DiscountListItem> discounts;
  final String searchQuery;
  final DiscountStatus? selectedStatus;
  final int currentPage;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final List<Branch> branches;
  final bool isLoadingBranches;
  final String? branchErrorMessage;
  final Map<String, List<String>> validationErrors;
  final DiscountFormReferences formReferences;
  final bool isLoadingFormReferences;
  final String? formReferencesErrorMessage;

  DiscountsState copyWith({
    List<DiscountListItem>? discounts,
    String? searchQuery,
    DiscountStatus? selectedStatus,
    int? currentPage,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearSelectedStatus = false,
    bool clearError = false,
    List<Branch>? branches,
    bool? isLoadingBranches,
    String? branchErrorMessage,
    bool clearBranchError = false,
    Map<String, List<String>>? validationErrors,
    bool clearValidationErrors = false,
    DiscountFormReferences? formReferences,
    bool? isLoadingFormReferences,
    String? formReferencesErrorMessage,
    bool clearFormReferencesError = false,
  }) => DiscountsState(
    discounts: discounts ?? this.discounts,
    searchQuery: searchQuery ?? this.searchQuery,
    selectedStatus: clearSelectedStatus
        ? null
        : selectedStatus ?? this.selectedStatus,
    currentPage: currentPage ?? this.currentPage,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    branches: branches ?? this.branches,
    isLoadingBranches: isLoadingBranches ?? this.isLoadingBranches,
    branchErrorMessage: clearBranchError
        ? null
        : branchErrorMessage ?? this.branchErrorMessage,
    validationErrors: clearValidationErrors
        ? const <String, List<String>>{}
        : validationErrors ?? this.validationErrors,
    formReferences: formReferences ?? this.formReferences,
    isLoadingFormReferences:
        isLoadingFormReferences ?? this.isLoadingFormReferences,
    formReferencesErrorMessage: clearFormReferencesError
        ? null
        : formReferencesErrorMessage ?? this.formReferencesErrorMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    discounts,
    searchQuery,
    selectedStatus,
    currentPage,
    isLoading,
    isSaving,
    errorMessage,
    branches,
    isLoadingBranches,
    branchErrorMessage,
    validationErrors,
    formReferences,
    isLoadingFormReferences,
    formReferencesErrorMessage,
  ];
}
