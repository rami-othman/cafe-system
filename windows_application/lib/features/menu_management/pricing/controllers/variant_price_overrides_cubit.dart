import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../models/catalog_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../../../pos/models/branch.dart';
import '../models/variant_price_models.dart';
import '../configured_price_validation.dart';
import 'variant_price_overrides_state.dart';

class VariantPriceOverridesCubit extends Cubit<VariantPriceOverridesState> {
  VariantPriceOverridesCubit({required this.repository})
    : super(const VariantPriceOverridesState());

  final MenuCatalogRepository repository;
  int _loadRequest = 0;
  int _effectiveRequest = 0;

  Future<void> load(
    int productId,
    int variantId, {
    int? branchId,
    String? channel,
    bool refresh = false,
  }) async {
    if (state.isSaving) return;
    final int request = ++_loadRequest;
    _effectiveRequest++;
    emit(
      state.copyWith(
        status: refresh
            ? VariantPriceOverridesStatus.refreshing
            : VariantPriceOverridesStatus.loading,
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
      if (request != _loadRequest || isClosed) return;
      final ProductVariant? variant = product.variants
          .where((item) => item.id == variantId)
          .firstOrNull;
      if (variant == null) {
        emit(
          state.copyWith(
            status: VariantPriceOverridesStatus.failure,
            product: product,
            errorMessage: 'The requested Variant was not found.',
          ),
        );
        return;
      }
      final Future<VariantPriceOverridesSnapshot> overrides = repository
          .listVariantPriceOverrides(variantId);
      final Future<List<Branch>> branches = repository.listAssignmentBranches();
      VariantPriceOverridesSnapshot snapshot;
      try {
        snapshot = await overrides;
      } catch (error) {
        if (request != _loadRequest || isClosed) return;
        emit(
          state.copyWith(
            status: VariantPriceOverridesStatus.failure,
            product: product,
            variant: variant,
            isAuthoritative: false,
            errorMessage: _message(error),
          ),
        );
        return;
      }
      List<Branch> branchResult = const <Branch>[];
      String? branchError;
      try {
        branchResult = await branches;
      } catch (_) {
        branchError =
            'Branches could not be loaded. Branch-scoped overrides are unavailable.';
      }
      if (request != _loadRequest || isClosed) return;
      emit(
        state.copyWith(
          status: VariantPriceOverridesStatus.loaded,
          product: product,
          variant: variant,
          basePrice: snapshot.basePrice,
          saved: snapshot.overrides,
          draft: snapshot.overrides
              .map(VariantPriceOverrideDraft.fromOverride)
              .toList(growable: false),
          branches: branchResult,
          branchError: branchError,
          isAuthoritative: true,
          clearError: true,
          clearFields: true,
          clearBranchError: branchError == null,
        ),
      );
      await selectEffectiveContext(branchId: branchId, channel: channel);
    } catch (error) {
      if (request != _loadRequest || isClosed) return;
      emit(
        state.copyWith(
          status: VariantPriceOverridesStatus.failure,
          isAuthoritative: false,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> refresh() {
    final ProductDetail? product = state.product;
    final ProductVariant? variant = state.variant;
    if (product == null || variant == null) return Future<void>.value();
    return load(product.id, variant.id, refresh: true);
  }

  bool addOrUpdate(
    VariantPriceOverrideDraft item, {
    String? replacingScopeKey,
  }) {
    if (!state.canEdit) return false;
    final String? error = _validate(item);
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
      (row) =>
          row.scopeKey == item.scopeKey && row.scopeKey != replacingScopeKey,
    )) {
      emit(
        state.copyWith(
          fieldErrors: const <String, String>{
            'scopeType': 'Duplicate price override scopes are not allowed.',
          },
          clearError: true,
        ),
      );
      return false;
    }
    final List<VariantPriceOverrideDraft> next = <VariantPriceOverrideDraft>[
      for (final row in state.draft)
        if (row.scopeKey != replacingScopeKey) row,
      item,
    ];
    emit(
      state.copyWith(
        draft: List.unmodifiable(next),
        clearFields: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
    return true;
  }

  void remove(String scopeKey) {
    if (!state.canEdit) return;
    emit(
      state.copyWith(
        draft: List.unmodifiable(
          state.draft.where((item) => item.scopeKey != scopeKey),
        ),
        clearFields: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void setEditorError(String message) => emit(
    state.copyWith(
      fieldErrors: <String, String>{'price': message},
      clearError: true,
    ),
  );

  Future<bool> save() async {
    if (!state.canEdit || !state.isDirty || state.variant == null) return false;
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccess: true,
        clearFields: true,
      ),
    );
    try {
      await repository.syncVariantPriceOverrides(
        state.variant!.id,
        state.draft,
      );
      await load(state.product!.id, state.variant!.id, refresh: true);
      emit(
        state.copyWith(successMessage: 'Price overrides saved successfully.'),
      );
      return true;
    } catch (error) {
      final Map<String, String> mapped =
          error is ApiException && error.validationErrors != null
          ? _mapValidation(error.validationErrors!)
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

  Future<void> selectEffectiveContext({int? branchId, String? channel}) async {
    final ProductVariant? variant = state.variant;
    if (variant == null) return;
    final int request = ++_effectiveRequest;
    emit(
      state.copyWith(
        effectiveBranchId: branchId,
        effectiveChannel: channel,
        clearEffectiveBranch: branchId == null,
        clearEffectiveChannel: channel == null,
        isEffectiveLoading: true,
        clearEffectiveError: true,
      ),
    );
    try {
      final EffectiveVariantPrice result = await repository
          .getEffectiveVariantPrice(
            variant.id,
            branchId: branchId,
            channel: channel,
          );
      if (request != _effectiveRequest || isClosed) return;
      emit(
        state.copyWith(
          effectivePrice: result,
          isEffectiveLoading: false,
          clearEffectiveError: true,
        ),
      );
    } catch (error) {
      if (request != _effectiveRequest || isClosed) return;
      emit(
        state.copyWith(
          isEffectiveLoading: false,
          effectiveError: _message(error),
          clearEffective: true,
        ),
      );
    }
  }

  String? _validate(VariantPriceOverrideDraft item) {
    final bool branch = item.branchId != null;
    final bool channel = item.channel != null && item.channel!.isNotEmpty;
    final bool valid = switch (item.scope) {
      PriceOverrideScope.branch => branch && !channel,
      PriceOverrideScope.channel => !branch && channel,
      PriceOverrideScope.branchChannel => branch && channel,
    };
    if (!valid) return 'Complete the required scope fields.';
    if (item.price.minorUnits <= 0) {
      return configuredSellPriceMustBePositive;
    }
    return null;
  }

  Map<String, String> _mapValidation(Map<String, List<String>> errors) =>
      errors.map((key, value) {
        final String mapped = key.startsWith('overrides.')
            ? key
                  .substring('overrides.'.length)
                  .replaceFirst(RegExp(r'^\d+\.'), '')
            : key;
        return MapEntry(mapped, value.first);
      });
  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to load or save price overrides. Please try again.';
}
