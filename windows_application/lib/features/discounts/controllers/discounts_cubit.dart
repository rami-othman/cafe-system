import 'discount_targets_cubit.dart';
import '../../pos/models/discount_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/discount_list_item.dart';
import '../models/discount_detail.dart';
import '../models/discount_form_references.dart';
import '../models/discount_dashboard_metrics.dart';
import '../models/discount_upsert_request.dart';
import '../repositories/discounts_repository.dart';
import 'discounts_state.dart';

class DiscountsCubit extends Cubit<DiscountsState> {
  static const String requestFailed = 'discount_request_failed';
  DiscountsCubit({required this._repository, this.capabilityLoader})
    : super(const DiscountsState());
  final Future<DiscountCapabilities> Function()? capabilityLoader;
  int _capabilityGeneration = 0;
  Future<void> loadCapabilities() async {
    if (isClosed) return;
    final generation = ++_capabilityGeneration;
    emit(state.copyWith(capabilities: const DiscountCapabilities()));
    try {
      final caps = await capabilityLoader?.call();
      if (!isClosed && generation == _capabilityGeneration && caps != null) {
        emit(state.copyWith(capabilities: caps));
      }
    } catch (_) {
      /* Fail closed; supported Manual/Code management remains available. */
    }
  }

  static const int pageSize = 4;
  final DiscountsRepository _repository;
  DiscountTargetsCubit createTargetsController() =>
      DiscountTargetsCubit(_repository);

  Future<void> loadDiscounts() async {
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        clearActualSavedValueThisMonth: true,
        clearValidationErrors: true,
      ),
    );
    try {
      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[
          _repository.getDiscounts(),
          _repository.getDashboardMetrics(),
        ],
      );
      if (isClosed) return;
      final List<DiscountListItem> discounts =
          results[0] as List<DiscountListItem>;
      final DiscountDashboardMetrics metrics =
          results[1] as DiscountDashboardMetrics;
      emit(
        state.copyWith(
          discounts: discounts,
          actualSavedValueThisMonth: metrics.actualSavedValueThisMonth,
          isLoading: false,
          currentPage: 1,
          clearError: true,
          clearValidationErrors: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _message(error),
          validationErrors: _validationErrors(error),
        ),
      );
    }
  }

  Future<void> loadBranches() async {
    if (isClosed) return;
    emit(state.copyWith(isLoadingBranches: true, clearBranchError: true));
    try {
      final branches = await _repository.getBranches();
      if (isClosed) return;
      emit(
        state.copyWith(
          branches: branches
              .where((branch) => branch.id > 0)
              .toList(growable: false),
          isLoadingBranches: false,
          clearBranchError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingBranches: false,
          branchErrorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> loadFormReferences() async {
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoadingFormReferences: true,
        clearFormReferencesError: true,
      ),
    );
    try {
      final DiscountFormReferences references = await _repository
          .getFormReferences();
      if (isClosed) return;
      emit(
        state.copyWith(
          formReferences: references,
          isLoadingFormReferences: false,
          clearFormReferencesError: references.failures.isEmpty,
          formReferencesErrorMessage: references.failures.isEmpty
              ? null
              : requestFailed,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingFormReferences: false,
          formReferencesErrorMessage: _message(error),
        ),
      );
    }
  }

  Future<DiscountDetail> getDiscountDetail(String discountId) =>
      _repository.getDiscountDetail(discountId);

  Future<String> generateCouponCode() => _repository.generateCouponCode();

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
    if (isClosed || state.isSaving) return false;
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearValidationErrors: true,
      ),
    );
    try {
      await _repository.deleteDiscount(discountId);
      if (isClosed) return true;
      emit(
        state.copyWith(
          discounts: state.discounts
              .where((DiscountListItem discount) => discount.id != discountId)
              .toList(growable: false),
          isSaving: false,
          currentPage: 1,
          clearError: true,
          clearValidationErrors: true,
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: _message(error),
          validationErrors: _validationErrors(error),
        ),
      );
      return false;
    }
  }

  Future<bool> _save(Future<DiscountListItem> Function() action) async {
    if (isClosed || state.isSaving) return false;
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearValidationErrors: true,
      ),
    );
    try {
      final DiscountListItem saved = await action();
      if (isClosed) return true;
      final List<DiscountListItem> updated = <DiscountListItem>[
        ...state.discounts,
      ];
      final int existing = updated.indexWhere(
        (DiscountListItem item) => item.id == saved.id,
      );
      if (existing >= 0) {
        updated[existing] = saved;
      } else {
        updated.insert(0, saved);
      }
      emit(
        state.copyWith(
          discounts: updated,
          isSaving: false,
          clearError: true,
          clearValidationErrors: true,
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: _message(error),
          validationErrors: _validationErrors(error),
        ),
      );
      return false;
    }
  }

  List<DiscountListItem> filteredDiscountsMatching({
    bool Function(DiscountListItem discount)? matchesLocalizedLabel,
  }) {
    final String query = state.searchQuery.trim().toLowerCase();
    return state.discounts
        .where((DiscountListItem discount) {
          final bool matchesStatus =
              state.selectedStatus == null ||
              discount.status == state.selectedStatus;
          final bool matchesSearch =
              query.isEmpty ||
              discount.name.toLowerCase().contains(query) ||
              (discount.code?.toLowerCase() ?? '').contains(query) ||
              discount.type.toLowerCase().contains(query) ||
              (discount.conditions?.toLowerCase() ?? '').contains(query) ||
              (matchesLocalizedLabel?.call(discount) ?? false);
          return matchesStatus && matchesSearch;
        })
        .toList(growable: false);
  }

  List<DiscountListItem> get filteredDiscounts => filteredDiscountsMatching();

  int totalPagesFor(List<DiscountListItem> discounts) =>
      (discounts.length / pageSize).ceil().clamp(1, 1 << 31);

  int get totalPages => totalPagesFor(filteredDiscounts);

  List<DiscountListItem> pageFor(List<DiscountListItem> discounts) {
    final int start = (state.currentPage - 1) * pageSize;
    if (start >= discounts.length) return const <DiscountListItem>[];
    return discounts.sublist(
      start,
      (start + pageSize).clamp(0, discounts.length),
    );
  }

  List<DiscountListItem> get currentPageDiscounts {
    return pageFor(filteredDiscounts);
  }

  void updateSearchQuery(String query) =>
      emit(state.copyWith(searchQuery: query, currentPage: 1));
  void updateStatus(DiscountStatus? status) => emit(
    state.copyWith(
      selectedStatus: status,
      clearSelectedStatus: status == null,
      currentPage: 1,
    ),
  );
  void changePage(int page, {int? availablePages}) {
    if (page >= 1 &&
        page <= (availablePages ?? totalPages) &&
        page != state.currentPage) {
      emit(state.copyWith(currentPage: page));
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
  String _message(Object error) => requestFailed;

  Map<String, List<String>> _validationErrors(Object error) =>
      error is ApiException
      ? error.validationErrors ?? const <String, List<String>>{}
      : const <String, List<String>>{};
}
