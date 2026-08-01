import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../pos/models/branch.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/operational_availability_models.dart';
import 'operational_availability_state.dart';

class OperationalAvailabilityCubit extends Cubit<OperationalAvailabilityState> {
  OperationalAvailabilityCubit({required this.repository})
    : super(const OperationalAvailabilityState());

  final MenuCatalogRepository repository;
  int _loadRequest = 0;
  int _previewRequest = 0;

  Future<void> load(
    int productId, {
    int? variantId,
    int? branchId,
    String? channel,
    bool refresh = false,
  }) async {
    if (state.isMutating && !refresh) return;
    final int request = ++_loadRequest;
    emit(
      state.copyWith(
        status: refresh
            ? OperationalAvailabilityLoadStatus.refreshing
            : OperationalAvailabilityLoadStatus.loading,
        clearError: true,
        clearSuccess: true,
        clearFields: true,
      ),
    );
    try {
      final List<dynamic> loaded = await Future.wait<dynamic>(<Future<dynamic>>[
        repository.getProduct(productId, includeArchived: true),
        repository.listProductOperationalOverrides(productId),
        repository.listAssignmentBranches(),
      ]);
      final ProductDetail product = loaded[0] as ProductDetail;
      final List<OperationalAvailabilityOverride> productRows =
          loaded[1] as List<OperationalAvailabilityOverride>;
      final List<Branch> branches = loaded[2] as List<Branch>;
      final bool hasVariant =
          variantId != null &&
          product.variants.any((item) => item.id == variantId);
      final int? effectiveVariantId = variantId == null
          ? state.selectedVariantId
          : hasVariant
          ? variantId
          : null;
      final int? effectiveBranchId = branchId == null
          ? state.selectedBranchId ??
                branches.where((item) => item.isActive).firstOrNull?.id
          : branches.any((item) => item.id == branchId && item.isActive)
          ? branchId
          : null;
      final String? effectiveChannel = channel == null
          ? state.selectedChannel ?? 'pos'
          : channelIsRuntime(channel)
          ? channel
          : null;
      final List<OperationalAvailabilityOverride> variantRows =
          effectiveVariantId == null
          ? const <OperationalAvailabilityOverride>[]
          : await repository.listVariantOperationalOverrides(
              effectiveVariantId,
            );
      if (request != _loadRequest || isClosed) return;
      emit(
        state.copyWith(
          status: OperationalAvailabilityLoadStatus.loaded,
          product: product,
          branches: branches,
          productOverrides: productRows,
          variantOverrides: variantRows,
          selectedVariantId: effectiveVariantId,
          selectedBranchId: effectiveBranchId,
          selectedChannel: effectiveChannel,
          clearVariant: effectiveVariantId == null,
          clearBranch: branchId != null && effectiveBranchId == null,
          clearChannel: channel != null && effectiveChannel == null,
          isAuthoritative: true,
          isMutating: false,
          clearAction: true,
          clearError: true,
          clearFields: true,
        ),
      );
      await _loadPreview();
    } catch (error) {
      if (request != _loadRequest || isClosed) return;
      emit(
        state.copyWith(
          status: OperationalAvailabilityLoadStatus.failure,
          isMutating: false,
          clearAction: true,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> refresh() {
    final ProductDetail? product = state.product;
    return product == null
        ? Future<void>.value()
        : load(product.id, variantId: state.selectedVariantId, refresh: true);
  }

  Future<void> selectVariant(int? variantId) async {
    if (state.isMutating || variantId == state.selectedVariantId) return;
    _loadRequest++;
    emit(
      state.copyWith(
        selectedVariantId: variantId,
        clearVariant: variantId == null,
        variantOverrides: const <OperationalAvailabilityOverride>[],
        clearError: true,
        clearFields: true,
      ),
    );
    if (variantId == null) {
      await _loadPreview();
      return;
    }
    try {
      final List<OperationalAvailabilityOverride> rows = await repository
          .listVariantOperationalOverrides(variantId);
      if (isClosed || state.selectedVariantId != variantId) return;
      emit(state.copyWith(variantOverrides: rows));
      await _loadPreview();
    } catch (error) {
      if (isClosed || state.selectedVariantId != variantId) return;
      emit(state.copyWith(errorMessage: _message(error)));
      await _loadPreview();
    }
  }

  Future<void> selectScope({
    int? branchId,
    String? channel,
    bool clearBranch = false,
    bool clearChannel = false,
  }) async {
    if (state.isMutating) return;
    emit(
      state.copyWith(
        selectedBranchId: branchId,
        selectedChannel: channel,
        clearBranch: clearBranch,
        clearChannel: clearChannel,
      ),
    );
    await _loadPreview();
  }

  Future<void> retryPreview() => _loadPreview();

  Future<void> _loadPreview() async {
    final ProductDetail? product = state.product;
    final int? branchId = state.selectedBranchId;
    final String? channel = state.selectedChannel;
    final ProductVariant? variant = state.selectedVariant;
    final bool valid =
        product != null &&
        branchId != null &&
        state.branches.any((item) => item.id == branchId && item.isActive) &&
        channel != null &&
        channelIsRuntime(channel) &&
        (state.selectedVariantId == null || variant != null);
    final int request = ++_previewRequest;
    if (!valid) {
      emit(
        state.copyWith(
          previewStatus: OperationalAvailabilityPreviewStatus.initial,
          clearPreview: true,
          clearPreviewError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        previewStatus: OperationalAvailabilityPreviewStatus.loading,
        clearPreviewError: true,
      ),
    );
    try {
      final OperationalAvailabilityPreview preview = variant == null
          ? await repository.previewProductOperationalAvailability(
              product.id,
              branchId: branchId,
              channel: channel,
            )
          : await repository.previewVariantOperationalAvailability(
              product.id,
              variant.id,
              branchId: branchId,
              channel: channel,
            );
      if (isClosed || request != _previewRequest) return;
      emit(
        state.copyWith(
          previewStatus: OperationalAvailabilityPreviewStatus.loaded,
          preview: preview,
          clearPreviewError: true,
        ),
      );
    } catch (error) {
      if (isClosed || request != _previewRequest) return;
      emit(
        state.copyWith(
          previewStatus: OperationalAvailabilityPreviewStatus.failure,
          previewError: _previewMessage(error),
        ),
      );
    }
  }

  void setEditorError(String message) => emit(
    state.copyWith(
      fieldErrors: <String, String>{'editor': message},
      clearError: true,
    ),
  );

  Future<bool> upsertProduct(
    OperationalAvailabilityDraft draft, {
    String? replacingScopeKey,
  }) => _upsert(draft, variantId: null, replacingScopeKey: replacingScopeKey);
  Future<bool> upsertVariant(
    OperationalAvailabilityDraft draft, {
    String? replacingScopeKey,
  }) => _upsert(
    draft,
    variantId: state.selectedVariantId,
    replacingScopeKey: replacingScopeKey,
  );

  Future<bool> _upsert(
    OperationalAvailabilityDraft draft, {
    required int? variantId,
    String? replacingScopeKey,
  }) async {
    final ProductDetail? product = state.product;
    final bool permitted = variantId == null
        ? state.canMutateProduct
        : state.canMutateVariant;
    if (product == null || !permitted) return false;
    final String? validation = _validate(
      draft,
      variantId: variantId,
      replacingScopeKey: replacingScopeKey,
    );
    if (validation != null) {
      emit(
        state.copyWith(
          fieldErrors: <String, String>{'editor': validation},
          clearError: true,
        ),
      );
      return false;
    }
    final List<OperationalAvailabilityOverride> rows = variantId == null
        ? state.productOverrides
        : state.variantOverrides;
    final bool isExisting = rows.any((item) => item.scopeKey == draft.scopeKey);
    final String actionId = '${variantId ?? product.id}:${draft.scopeKey}';
    emit(
      state.copyWith(
        isMutating: true,
        currentActionId: actionId,
        clearError: true,
        clearSuccess: true,
        clearFields: true,
      ),
    );
    try {
      if (variantId == null) {
        await repository.upsertProductOperationalOverride(product.id, draft);
      } else {
        await repository.upsertVariantOperationalOverride(variantId, draft);
      }
      await load(product.id, variantId: state.selectedVariantId, refresh: true);
      final bool reloaded =
          state.status == OperationalAvailabilityLoadStatus.loaded &&
          state.isAuthoritative;
      if (!isClosed && reloaded) {
        emit(
          state.copyWith(
            successMessage: isExisting
                ? 'Operational override updated.'
                : 'Operational override added.',
          ),
        );
      }
      return reloaded;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isMutating: false,
            clearAction: true,
            fieldErrors: _validation(error),
            errorMessage: _message(error),
          ),
        );
        await _reloadLifecycleAfterArchivedResponse(error, product.id);
      }
      return false;
    }
  }

  Future<bool> clearProduct(OperationalAvailabilityOverride item) =>
      _clear(item, variantId: null);
  Future<bool> clearVariant(OperationalAvailabilityOverride item) =>
      _clear(item, variantId: state.selectedVariantId);

  Future<bool> _clear(
    OperationalAvailabilityOverride item, {
    required int? variantId,
  }) async {
    final ProductDetail? product = state.product;
    final bool permitted = variantId == null
        ? state.canMutateProduct
        : state.canMutateVariant;
    if (product == null || !permitted || state.isMutating) return false;
    emit(
      state.copyWith(
        isMutating: true,
        currentActionId: '${variantId ?? product.id}:${item.scopeKey}',
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      if (variantId == null) {
        await repository.clearProductOperationalOverride(
          product.id,
          item.branchId,
          item.channel,
        );
      } else {
        await repository.clearVariantOperationalOverride(
          variantId,
          item.branchId,
          item.channel,
        );
      }
      await load(product.id, variantId: state.selectedVariantId, refresh: true);
      final bool reloaded =
          state.status == OperationalAvailabilityLoadStatus.loaded &&
          state.isAuthoritative;
      if (!isClosed && reloaded) {
        emit(state.copyWith(successMessage: 'Operational override cleared.'));
      }
      return reloaded;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isMutating: false,
            clearAction: true,
            errorMessage: _message(error),
          ),
        );
        await _reloadLifecycleAfterArchivedResponse(error, product.id);
      }
      return false;
    }
  }

  String? _validate(
    OperationalAvailabilityDraft draft, {
    required int? variantId,
    String? replacingScopeKey,
  }) {
    if (draft.branchId == null || draft.branchId! <= 0) {
      return 'Select an active Branch.';
    }
    if (!isOperationalAvailabilityChannel(draft.channel)) {
      return 'Select a supported channel scope.';
    }
    if (draft.remainingQuantity != null && draft.remainingQuantity! < 0) {
      return 'Remaining quantity must be zero or greater.';
    }
    if ((draft.reason?.length ?? 0) > 1000) {
      return 'Reason must be 1,000 characters or fewer.';
    }
    if (draft.isTemporary &&
        (draft.unavailableUntil == null ||
            !draft.unavailableUntil!.isAfter(DateTime.now()))) {
      return 'A future unavailable-until time is required for a temporary override.';
    }
    final List<OperationalAvailabilityOverride> existing = variantId == null
        ? state.productOverrides
        : state.variantOverrides;
    if (existing.any(
      (item) =>
          item.scopeKey == draft.scopeKey && item.scopeKey != replacingScopeKey,
    )) {
      return 'An override already exists for this Branch and channel scope.';
    }
    return null;
  }

  Map<String, String> _validation(Object error) =>
      error is ApiException && error.validationErrors != null
      ? error.validationErrors!.map((key, value) => MapEntry(key, value.first))
      : const <String, String>{};
  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update operational availability. Please try again.';

  String _previewMessage(Object error) {
    if (error is FormatException) {
      return 'The operational resolution response could not be read. Please try again.';
    }
    if (error is ApiException) {
      return switch (error.statusCode) {
        404 =>
          'The selected Product or Variant is no longer available for this diagnostic.',
        422 => 'Select an active Branch and a supported sales channel.',
        _ => 'Unable to load operational resolution. Please try again.',
      };
    }
    return 'Unable to load operational resolution. Please try again.';
  }

  Future<void> _reloadLifecycleAfterArchivedResponse(
    Object error,
    int productId,
  ) async {
    if (error is! ApiException || error.statusCode != 404) return;
    await load(productId, variantId: state.selectedVariantId, refresh: true);
    if (!isClosed && state.status == OperationalAvailabilityLoadStatus.loaded) {
      emit(
        state.copyWith(
          errorMessage:
              'This Product or Variant is no longer active. The operational availability data was refreshed.',
        ),
      );
    }
  }
}
