// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../../../pos/models/branch.dart';
import '../models/availability_models.dart';
import 'availability_state.dart';

class AvailabilityCubit extends Cubit<AvailabilityState> {
  AvailabilityCubit({required this.repository})
    : super(const AvailabilityState());
  final MenuCatalogRepository repository;
  int _loadRequest = 0;
  int _previewRequest = 0;

  Future<void> load(
    int productId, {
    int? variantId,
    bool refresh = false,
  }) async {
    if (state.isSaving && !refresh) return;
    final int request = ++_loadRequest;
    emit(
      state.copyWith(
        status: refresh
            ? AvailabilityStatus.refreshing
            : AvailabilityStatus.loading,
        clearError: true,
        clearSuccess: true,
        clearFields: true,
      ),
    );
    try {
      final ProductDetail product = await repository.getProduct(
        productId,
        includeArchived: true,
      );
      final Future<ProductAvailabilityRulesSnapshot> rules = repository
          .listProductAvailabilityRules(productId);
      final Future<List<Branch>> branches = repository.listAssignmentBranches();
      final ProductAvailabilityRulesSnapshot snapshot;
      try {
        snapshot = await rules;
      } catch (error) {
        if (request != _loadRequest || isClosed) return;
        emit(
          state.copyWith(
            status: AvailabilityStatus.failure,
            product: product,
            isAuthoritative: false,
            isSaving: false,
            errorMessage: _message(error),
          ),
        );
        return;
      }
      List<Branch> branchItems = const <Branch>[];
      try {
        branchItems = await branches;
      } catch (_) {}
      if (request != _loadRequest || isClosed) return;
      final bool validVariant =
          variantId != null &&
          product.variants.any((item) => item.id == variantId);
      emit(
        state.copyWith(
          status: AvailabilityStatus.loaded,
          product: product,
          branches: branchItems,
          saved: snapshot.rules,
          draft: snapshot.rules
              .map((item) => item.toDraft())
              .toList(growable: false),
          selectedVariantId: validVariant ? variantId : null,
          clearVariant: !validVariant,
          isAuthoritative: true,
          isSaving: false,
          clearError: true,
          clearFields: true,
        ),
      );
    } catch (error) {
      if (request != _loadRequest || isClosed) return;
      emit(
        state.copyWith(
          status: AvailabilityStatus.failure,
          isAuthoritative: false,
          isSaving: false,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> refresh() {
    final p = state.product;
    return p == null
        ? Future.value()
        : load(p.id, variantId: state.selectedVariantId, refresh: true);
  }

  void selectContext({
    int? variantId,
    int? branchId,
    String? channel,
    bool clearVariant = false,
    bool clearBranch = false,
    bool clearChannel = false,
  }) {
    _previewRequest++;
    emit(
      state.copyWith(
        selectedVariantId: variantId,
        selectedBranchId: branchId,
        selectedChannel: channel,
        clearVariant: clearVariant,
        clearBranch: clearBranch,
        clearChannel: clearChannel,
        clearPreview: true,
        clearPreviewError: true,
      ),
    );
  }

  bool addOrUpdate(AvailabilityRuleDraft rule, {String? replacingIdentity}) {
    if (!state.canEdit) return false;
    final String? error = _validate(rule);
    if (error != null) {
      emit(
        state.copyWith(
          fieldErrors: <String, String>{'editor': error},
          clearError: true,
        ),
      );
      return false;
    }
    if (state.draft.any(
      (item) =>
          item.identity == rule.identity && item.identity != replacingIdentity,
    )) {
      emit(
        state.copyWith(
          fieldErrors: const <String, String>{
            'editor': 'Duplicate availability rules are not allowed.',
          },
          clearError: true,
        ),
      );
      return false;
    }
    emit(
      state.copyWith(
        draft: List.unmodifiable(<AvailabilityRuleDraft>[
          for (final item in state.draft)
            if (item.identity != replacingIdentity) item,
          rule,
        ]),
        clearFields: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
    return true;
  }

  void remove(String identity) {
    if (!state.canEdit) return;
    emit(
      state.copyWith(
        draft: List.unmodifiable(
          state.draft.where((item) => item.identity != identity),
        ),
        clearFields: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  Future<bool> save() async {
    final p = state.product;
    if (!state.canEdit || !state.isDirty || p == null) return false;
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccess: true,
        clearFields: true,
      ),
    );
    try {
      await repository.syncProductAvailabilityRules(p.id, state.draft);
      await load(p.id, variantId: state.selectedVariantId, refresh: true);
      if (!state.isAuthoritative) {
        return false;
      }
      emit(state.copyWith(successMessage: 'Scheduled availability saved.'));
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          fieldErrors: _validation(error),
          errorMessage: _message(error),
          clearSuccess: true,
        ),
      );
      return false;
    }
  }

  Future<void> preview(DateTime dateTime) async {
    final p = state.product;
    if (p == null) return;
    final int request = ++_previewRequest;
    emit(
      state.copyWith(
        previewAt: dateTime,
        isPreviewLoading: true,
        clearPreviewError: true,
      ),
    );
    try {
      final result = await repository.previewProductAvailability(
        p.id,
        variantId: state.selectedVariantId,
        branchId: state.selectedBranchId,
        channel: state.selectedChannel,
        dateTime: _wireDateTime(dateTime),
      );
      if (request != _previewRequest || isClosed) return;
      emit(state.copyWith(preview: result, isPreviewLoading: false));
    } catch (error) {
      if (request != _previewRequest || isClosed) return;
      emit(
        state.copyWith(
          isPreviewLoading: false,
          previewError: _message(error),
          clearPreview: true,
        ),
      );
    }
  }

  String? _validate(AvailabilityRuleDraft item) {
    final bool scopeValid = switch (item.scope) {
      AvailabilityScope.global => item.branchId == null && item.channel == null,
      AvailabilityScope.branch => item.branchId != null && item.channel == null,
      AvailabilityScope.channel =>
        item.branchId == null && item.channel != null,
      AvailabilityScope.branchChannel =>
        item.branchId != null && item.channel != null,
    };
    if (!scopeValid) return 'Complete the required scope fields.';
    if ((item.startTime == null) != (item.endTime == null) ||
        !_time(item.startTime) ||
        !_time(item.endTime))
      return 'Start and end time must use HH:mm and be supplied together.';
    if (item.startTime != null && item.startTime == item.endTime)
      return 'Start and end time must differ.';
    if (!_date(item.startDate) ||
        !_date(item.endDate) ||
        (item.startDate != null &&
            item.endDate != null &&
            item.endDate!.compareTo(item.startDate!) < 0))
      return 'Enter a valid date range.';
    if (item.dayOfWeek != null && (item.dayOfWeek! < 0 || item.dayOfWeek! > 6))
      return 'Weekday must be between Sunday and Saturday.';
    return null;
  }

  bool _time(String? value) =>
      value == null || RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
  bool _date(String? value) =>
      value == null ||
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
          DateTime.tryParse(value) != null;
  Map<String, String> _validation(Object error) =>
      error is ApiException && error.validationErrors != null
      ? error.validationErrors!.map(
          (key, value) => MapEntry(
            key.replaceFirst(RegExp(r'^rules\.\d+\.'), ''),
            value.first,
          ),
        )
      : const <String, String>{};
  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to load or save scheduled availability. Please try again.';
  String _wireDateTime(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}
