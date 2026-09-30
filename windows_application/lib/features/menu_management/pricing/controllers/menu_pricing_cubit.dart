import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/menu_price_adjustment_models.dart';
import '../models/menu_pricing_models.dart';
import 'menu_pricing_state.dart';

class MenuPricingCubit extends Cubit<MenuPricingState> {
  MenuPricingCubit({required this.repository})
    : super(const MenuPricingState());
  final MenuCatalogRepository repository;
  int _requestRevision = 0;
  int _draftRevision = 0;
  int _actionRevision = 0;

  Future<bool> load({
    required int menuId,
    required int branchId,
    required String channel,
    String search = '',
    int? categoryId,
    int page = 1,
  }) => _load(
    MenuPricingContextKey(menuId, branchId, channel),
    search,
    categoryId,
    page,
    false,
  );

  /// Call only after a visible, explicit discard confirmation.
  Future<bool> discardAndLoad({
    required int menuId,
    required int branchId,
    required String channel,
    String search = '',
    int? categoryId,
    int page = 1,
  }) => _load(
    MenuPricingContextKey(menuId, branchId, channel),
    search,
    categoryId,
    page,
    true,
  );

  Future<bool> _load(
    MenuPricingContextKey context,
    String search,
    int? categoryId,
    int page,
    bool discard,
  ) async {
    final changed = state.contextKey != null && state.contextKey != context;
    if (changed && state.blocksContextChange) return false;
    if (changed && state.hasUnsavedWork && !discard) {
      emit(state.copyWith(status: MenuPricingStatus.contextDiscardRequired));
      return false;
    }
    final ticket = ++_requestRevision;
    if (changed) {
      ++_draftRevision;
      emit(
        state.copyWith(
          status: MenuPricingStatus.loading,
          menuId: context.menuId,
          branchId: context.branchId,
          channel: context.channel,
          search: search,
          categoryId: categoryId,
          page: page,
          clearCategory: categoryId == null,
          clearOverview: true,
          clearDrafts: true,
          clearReview: true,
          clearSavedHandoff: true,
          overviewRefreshFailed: false,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: MenuPricingStatus.loading,
          menuId: context.menuId,
          branchId: context.branchId,
          channel: context.channel,
          search: search,
          categoryId: categoryId,
          page: page,
          clearCategory: categoryId == null,
          clearError: true,
        ),
      );
    }
    try {
      final overview = await repository.getMenuPricingOverview(
        menuId: context.menuId,
        branchId: context.branchId,
        channel: context.channel,
        search: search,
        categoryId: categoryId,
        page: page,
      );
      if (isClosed ||
          ticket != _requestRevision ||
          state.contextKey != context) {
        return false;
      }
      emit(
        state.copyWith(status: MenuPricingStatus.loaded, overview: overview),
      );
      return true;
    } catch (error) {
      if (!isClosed &&
          ticket == _requestRevision &&
          state.contextKey == context) {
        emit(state.copyWith(status: _status(error), error: _safe(error)));
      }
      return false;
    }
  }

  void setDraft(ManualPriceDraft draft) {
    if (state.blocksContextChange) return;
    ++_draftRevision;
    final drafts = Map<int, ManualPriceDraft>.from(state.drafts)
      ..[draft.variantId] = draft;
    emit(
      state.copyWith(
        drafts: Map<int, ManualPriceDraft>.unmodifiable(drafts),
        clearReview: true,
      ),
    );
  }

  void undoDraft(int variantId) {
    if (state.blocksContextChange) return;
    ++_draftRevision;
    final drafts = Map<int, ManualPriceDraft>.from(state.drafts)
      ..remove(variantId);
    emit(
      state.copyWith(
        drafts: Map<int, ManualPriceDraft>.unmodifiable(drafts),
        clearReview: true,
      ),
    );
  }

  void discardDrafts() {
    if (state.blocksContextChange) return;
    ++_draftRevision;
    emit(state.copyWith(clearDrafts: true, clearReview: true));
  }

  Future<bool> previewManual() => _preview(<String, dynamic>{
    'operation': 'manual_changes',
    'items': state.drafts.values
        .map((draft) => draft.toJson())
        .toList(growable: false),
  });

  Future<bool> previewBulk({
    required String operation,
    required String amount,
    required String roundingMode,
    String? roundingStep,
  }) {
    if (state.hasDrafts || state.blocksContextChange) {
      return Future<bool>.value(false);
    }
    return _preview(<String, dynamic>{
      'operation': operation,
      'amount': amount,
      'roundingMode': roundingMode,
      'roundingStep': roundingMode == 'no_rounding' ? null : roundingStep,
    });
  }

  Future<bool> _preview(Map<String, dynamic> body) async {
    final context = state.contextKey;
    if (context == null ||
        state.blocksContextChange ||
        (body['operation'] == 'manual_changes' && !state.hasDrafts)) {
      return false;
    }
    final ticket = ++_requestRevision;
    final draftRevision = _draftRevision;
    emit(state.copyWith(status: MenuPricingStatus.loading, clearError: true));
    try {
      final review = await repository.previewMenuPriceAdjustment(
        context.menuId,
        <String, dynamic>{
          'branchId': context.branchId,
          'channel': context.channel,
          ...body,
        },
      );
      if (isClosed ||
          ticket != _requestRevision ||
          draftRevision != _draftRevision ||
          state.contextKey != context) {
        return false;
      }
      emit(
        state.copyWith(
          status: MenuPricingStatus.loaded,
          review: review,
          reviewApplyRejected: false,
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      if (!isClosed &&
          ticket == _requestRevision &&
          draftRevision == _draftRevision &&
          state.contextKey == context) {
        emit(state.copyWith(status: _status(error), error: _safe(error)));
      }
      return false;
    }
  }

  /// Uses the exact adjustment/fingerprint rendered by the dialog.
  Future<bool> apply({
    required int adjustmentId,
    required String fingerprint,
    required bool acknowledgeOppositeDirection,
  }) async {
    final context = state.contextKey;
    final review = state.review;
    if (context == null ||
        review == null ||
        state.isActionInFlight ||
        !state.isReviewApplyCandidate ||
        review.id != adjustmentId ||
        review.fingerprint != fingerprint) {
      return false;
    }
    final action = ++_actionRevision;
    emit(state.copyWith(status: MenuPricingStatus.applying, clearError: true));
    try {
      final applied = await repository.applyMenuPriceAdjustment(
        context.menuId,
        adjustmentId,
        <String, dynamic>{
          'previewFingerprint': fingerprint,
          'confirmReviewedResults': true,
          if (review.oppositeDirectionCount > 0)
            'acknowledgeOppositeDirection': acknowledgeOppositeDirection,
        },
      );
      if (isClosed ||
          action != _actionRevision ||
          state.contextKey != context) {
        return false;
      }
      if (applied.status != 'applied') {
        emit(
          state.copyWith(
            status: MenuPricingStatus.stale,
            review: applied,
            reviewApplyRejected: true,
            error: 'pricingPreviewExpired',
          ),
        );
        return false;
      }
      _emitApplied(review, applied);
      await _refreshAfterApply(context, action);
      return true;
    } catch (error) {
      if (!isClosed &&
          action == _actionRevision &&
          state.contextKey == context) {
        final rejected = _isReviewRejected(error);
        emit(
          state.copyWith(
            status: rejected
                ? MenuPricingStatus.stale
                : _isUncertain(error)
                ? MenuPricingStatus.uncertain
                : _status(error),
            reviewApplyRejected: rejected,
            error: !rejected && _isUncertain(error)
                ? 'pricingApplyUncertain'
                : _safe(error),
          ),
        );
      }
      return false;
    }
  }

  void _emitApplied(MenuPriceAdjustment original, MenuPriceAdjustment applied) {
    final fulfilled = original.operation == 'manual_changes'
        ? original.items.map((item) => item.variantId).toSet()
        : const <int>{};
    final drafts = Map<int, ManualPriceDraft>.from(state.drafts)
      ..removeWhere((id, _) => fulfilled.contains(id));
    ++_draftRevision;
    emit(
      state.copyWith(
        status: MenuPricingStatus.saved,
        review: applied,
        drafts: Map<int, ManualPriceDraft>.unmodifiable(drafts),
        savedAdjustmentId: applied.id,
        overviewRefreshFailed: false,
        reviewApplyRejected: false,
        clearError: true,
      ),
    );
  }

  Future<void> _refreshAfterApply(
    MenuPricingContextKey context,
    int action,
  ) async {
    final ticket = ++_requestRevision;
    try {
      final overview = await repository.getMenuPricingOverview(
        menuId: context.menuId,
        branchId: context.branchId,
        channel: context.channel,
        search: state.search,
        categoryId: state.categoryId,
        page: state.page,
      );
      if (!isClosed &&
          action == _actionRevision &&
          ticket == _requestRevision &&
          state.contextKey == context) {
        emit(
          state.copyWith(status: MenuPricingStatus.saved, overview: overview),
        );
      }
    } catch (_) {
      if (!isClosed &&
          action == _actionRevision &&
          ticket == _requestRevision &&
          state.contextKey == context) {
        emit(
          state.copyWith(
            status: MenuPricingStatus.saved,
            overviewRefreshFailed: true,
            error: 'pricingOverviewRefreshFailed',
          ),
        );
      }
    }
  }

  /// Status lookup preserves the original id/fingerprint; it never re-previews.
  Future<bool> recover() async {
    final context = state.contextKey;
    final review = state.review;
    if (context == null || review == null || state.isRecovering) return false;
    final action = ++_actionRevision;
    emit(
      state.copyWith(status: MenuPricingStatus.recovering, clearError: true),
    );
    try {
      final found = await repository.getMenuPriceAdjustment(
        context.menuId,
        review.id,
      );
      if (isClosed ||
          action != _actionRevision ||
          state.contextKey != context) {
        return false;
      }
      if (found.status == 'applied') {
        _emitApplied(review, found);
        await _refreshAfterApply(context, action);
        return true;
      }
      final invalid = !found.isApplyCandidate;
      emit(
        state.copyWith(
          status: invalid ? MenuPricingStatus.stale : MenuPricingStatus.loaded,
          review: found,
          reviewApplyRejected: invalid,
          error: invalid ? 'pricingPreviewExpired' : null,
          clearError: !invalid,
        ),
      );
      return false;
    } catch (error) {
      if (!isClosed &&
          action == _actionRevision &&
          state.contextKey == context) {
        // A failed lookup does not establish the Apply result. Preserve the
        // exact reviewed identity and context lock so the user can recover or
        // retry this same idempotent adjustment rather than silently discard it.
        emit(
          state.copyWith(
            status: MenuPricingStatus.uncertain,
            error: 'pricingApplyUncertain',
          ),
        );
      }
      return false;
    }
  }

  bool _isUncertain(Object error) =>
      error is ApiException &&
      <ApiErrorType>{
        ApiErrorType.networkUnavailable,
        ApiErrorType.connectionTimeout,
        ApiErrorType.sendTimeout,
        ApiErrorType.receiveTimeout,
        ApiErrorType.server,
        ApiErrorType.unknown,
      }.contains(error.type);

  MenuPricingStatus _status(Object error) =>
      error is ApiException && error.type == ApiErrorType.forbidden
      ? MenuPricingStatus.forbidden
      : error is ApiException &&
            <String>{
              'MENU_PRICING_PREVIEW_STALE',
              'MENU_PRICING_PREVIEW_EXPIRED',
              'MENU_PRICING_PREVIEW_FINGERPRINT_MISMATCH',
              'MENU_PRICING_CONTEXT_INVALID',
            }.contains(error.code)
      ? MenuPricingStatus.stale
      : MenuPricingStatus.failure;

  bool _isReviewRejected(Object error) =>
      error is ApiException &&
      <String>{
        'MENU_PRICING_PREVIEW_STALE',
        'MENU_PRICING_PREVIEW_EXPIRED',
        'MENU_PRICING_PREVIEW_FINGERPRINT_MISMATCH',
        'MENU_PRICING_CONTEXT_INVALID',
      }.contains(error.code);

  String _safe(Object error) => error is ApiException
      ? switch (error.code) {
          'MENU_PRICING_FORBIDDEN' => 'pricingForbidden',
          'MENU_PRICING_PREVIEW_STALE' ||
          'MENU_PRICING_PREVIEW_FINGERPRINT_MISMATCH' ||
          'MENU_PRICING_CONTEXT_INVALID' => 'pricingPreviewStale',
          'MENU_PRICING_PREVIEW_EXPIRED' => 'pricingPreviewExpired',
          'MENU_PRICING_OPPOSITE_DIRECTION_ACKNOWLEDGEMENT_REQUIRED' =>
            'pricingAcknowledgementRequired',
          _ => 'pricingFailed',
        }
      : 'pricingFailed';
}
