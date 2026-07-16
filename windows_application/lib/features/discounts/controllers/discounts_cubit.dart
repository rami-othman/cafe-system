import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/discount_list_item.dart';
import '../models/discount_upsert_request.dart';
import '../repositories/discounts_repository.dart';
import 'discounts_state.dart';

class DiscountsCubit extends Cubit<DiscountsState> {
  DiscountsCubit({required DiscountsRepository repository})
    : _repository = repository,
      super(const DiscountsState());

  static const int pageSize = 4;
  final DiscountsRepository _repository;

  Future<void> loadDiscounts() async {
    emit(state.copyWith(isLoading: true, clearError: true, clearValidationErrors: true));
    try {
      final List<DiscountListItem> discounts = await _repository.getDiscounts();
      emit(state.copyWith(
        discounts: discounts,
        isLoading: false,
        currentPage: 1,
        clearError: true, clearValidationErrors: true,
      ));
    } catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: _message(error), validationErrors: _validationErrors(error)));
    }
  }

  Future<void> loadBranches() async {
    emit(state.copyWith(isLoadingBranches: true, clearBranchError: true));
    try {
      final branches = await _repository.getBranches();
      emit(state.copyWith(
        branches: branches.where((branch) => branch.id > 0).toList(growable: false),
        isLoadingBranches: false,
        clearBranchError: true,
      ));
    } catch (error) {
      emit(state.copyWith(
        isLoadingBranches: false,
        branchErrorMessage: _message(error),
      ));
    }
  }

  Future<bool> createDiscount(DiscountUpsertRequest request) async {
    return _save(() => _repository.createDiscount(request));
  }

  Future<bool> updateDiscount(
    String discountId,
    DiscountUpsertRequest request,
  ) => _save(() => _repository.updateDiscount(discountId, request));

  Future<bool> setStatus(String discountId, bool isActive) async {
    return _save(() => _repository.setStatus(discountId, isActive));
  }

  Future<bool> deleteDiscount(String discountId) async {
    emit(state.copyWith(isSaving: true, clearError: true, clearValidationErrors: true));
    try {
      await _repository.deleteDiscount(discountId);
      emit(state.copyWith(
        discounts: state.discounts
            .where((DiscountListItem discount) => discount.id != discountId)
            .toList(growable: false),
        isSaving: false,
        currentPage: 1,
        clearError: true, clearValidationErrors: true,
      ));
      return true;
    } catch (error) {
      emit(state.copyWith(isSaving: false, errorMessage: _message(error), validationErrors: _validationErrors(error)));
      return false;
    }
  }

  Future<bool> _save(Future<DiscountListItem> Function() action) async {
    emit(state.copyWith(isSaving: true, clearError: true, clearValidationErrors: true));
    try {
      final DiscountListItem saved = await action();
      final List<DiscountListItem> updated = <DiscountListItem>[...state.discounts];
      final int existing = updated.indexWhere((DiscountListItem item) => item.id == saved.id);
      if (existing >= 0) {
        updated[existing] = saved;
      } else {
        updated.insert(0, saved);
      }
      emit(state.copyWith(discounts: updated, isSaving: false, clearError: true, clearValidationErrors: true));
      return true;
    } catch (error) {
      emit(state.copyWith(isSaving: false, errorMessage: _message(error), validationErrors: _validationErrors(error)));
      return false;
    }
  }

  List<DiscountListItem> get filteredDiscounts {
    final String query = state.searchQuery.trim().toLowerCase();
    return state.discounts.where((DiscountListItem discount) {
      final bool matchesStatus = state.selectedStatus == null || discount.status == state.selectedStatus;
      final bool matchesSearch = query.isEmpty ||
          discount.name.toLowerCase().contains(query) ||
          discount.secondaryLabel.toLowerCase().contains(query) ||
          discount.type.toLowerCase().contains(query) ||
          discount.conditions.toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList(growable: false);
  }

  int get totalPages => (filteredDiscounts.length / pageSize).ceil().clamp(1, 1 << 31);
  List<DiscountListItem> get currentPageDiscounts {
    final List<DiscountListItem> discounts = filteredDiscounts;
    final int start = (state.currentPage - 1) * pageSize;
    if (start >= discounts.length) return const <DiscountListItem>[];
    return discounts.sublist(start, (start + pageSize).clamp(0, discounts.length));
  }

  void updateSearchQuery(String query) => emit(state.copyWith(searchQuery: query, currentPage: 1));
  void updateStatus(DiscountStatus? status) => emit(state.copyWith(selectedStatus: status, clearSelectedStatus: status == null, currentPage: 1));
  void changePage(int page) { if (page >= 1 && page <= totalPages && page != state.currentPage) emit(state.copyWith(currentPage: page)); }
  void clearError() => emit(state.copyWith(clearError: true));
  String _message(Object error) => error is ApiException ? error.message : 'Unable to complete the discount request. Please try again.';
  Map<String, List<String>> _validationErrors(Object error) =>
      error is ApiException ? error.validationErrors ?? const <String, List<String>>{} : const <String, List<String>>{};
}
