import 'package:equatable/equatable.dart';

import '../models/menu_price_adjustment_models.dart';
import '../models/menu_pricing_models.dart';

enum MenuPricingStatus {
  initial,
  loading,
  loaded,
  failure,
  forbidden,
  applying,
  recovering,
  saved,
  stale,
  uncertain,
  contextDiscardRequired,
}

/// Identity for drafts and reviews. Browsing fields are deliberately excluded.
class MenuPricingContextKey extends Equatable {
  const MenuPricingContextKey(this.menuId, this.branchId, this.channel);
  final int menuId;
  final int branchId;
  final String channel;
  @override
  List<Object> get props => <Object>[menuId, branchId, channel];
}

class MenuPricingState extends Equatable {
  const MenuPricingState({
    this.status = MenuPricingStatus.initial,
    this.menuId,
    this.branchId,
    this.channel,
    this.search = '',
    this.categoryId,
    this.page = 1,
    this.overview,
    this.drafts = const <int, ManualPriceDraft>{},
    this.review,
    this.error,
    this.savedAdjustmentId,
    this.overviewRefreshFailed = false,
    this.reviewApplyRejected = false,
  });
  final MenuPricingStatus status;
  final int? menuId, branchId, categoryId;
  final String? channel;
  final String search;
  final int page;
  final MenuPricingOverview? overview;
  final Map<int, ManualPriceDraft> drafts;
  final MenuPriceAdjustment? review;
  final String? error;
  final int? savedAdjustmentId;
  final bool overviewRefreshFailed;

  /// The server rejected this exact reviewed adjustment. Keep its identity for
  /// audit/display, but never let a previewed response become an Apply target.
  final bool reviewApplyRejected;

  MenuPricingContextKey? get contextKey =>
      menuId == null || branchId == null || channel == null
      ? null
      : MenuPricingContextKey(menuId!, branchId!, channel!);
  bool get hasDrafts => drafts.isNotEmpty;
  bool get isReviewApplyCandidate =>
      review != null && review!.isApplyCandidate && !reviewApplyRejected;
  bool get hasReview => isReviewApplyCandidate;
  bool get isApplying => status == MenuPricingStatus.applying;
  bool get isRecovering => status == MenuPricingStatus.recovering;
  bool get isActionInFlight => isApplying || isRecovering;
  bool get hasUncertainApply => status == MenuPricingStatus.uncertain;
  bool get hasUnresolvedApply => hasUncertainApply || isRecovering;
  bool get blocksContextChange => isActionInFlight || hasUncertainApply;
  bool get hasUnsavedWork => hasDrafts || hasReview || blocksContextChange;
  bool get hasSavedHandoff => savedAdjustmentId != null;

  MenuPricingState copyWith({
    MenuPricingStatus? status,
    int? menuId,
    int? branchId,
    String? channel,
    String? search,
    int? categoryId,
    int? page,
    MenuPricingOverview? overview,
    Map<int, ManualPriceDraft>? drafts,
    MenuPriceAdjustment? review,
    String? error,
    int? savedAdjustmentId,
    bool? overviewRefreshFailed,
    bool? reviewApplyRejected,
    bool clearCategory = false,
    bool clearOverview = false,
    bool clearDrafts = false,
    bool clearReview = false,
    bool clearError = false,
    bool clearSavedHandoff = false,
  }) => MenuPricingState(
    status: status ?? this.status,
    menuId: menuId ?? this.menuId,
    branchId: branchId ?? this.branchId,
    channel: channel ?? this.channel,
    search: search ?? this.search,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    page: page ?? this.page,
    overview: clearOverview ? null : overview ?? this.overview,
    drafts: clearDrafts
        ? const <int, ManualPriceDraft>{}
        : drafts ?? this.drafts,
    review: clearReview ? null : review ?? this.review,
    error: clearError ? null : error ?? this.error,
    savedAdjustmentId: clearSavedHandoff
        ? null
        : savedAdjustmentId ?? this.savedAdjustmentId,
    overviewRefreshFailed: overviewRefreshFailed ?? this.overviewRefreshFailed,
    reviewApplyRejected: clearReview
        ? false
        : reviewApplyRejected ?? this.reviewApplyRejected,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    menuId,
    branchId,
    channel,
    search,
    categoryId,
    page,
    overview,
    drafts,
    review,
    error,
    savedAdjustmentId,
    overviewRefreshFailed,
    reviewApplyRejected,
  ];
}
