import 'package:equatable/equatable.dart';

import '../../models/catalog_models.dart';
import '../../../pos/models/branch.dart';
import '../models/variant_price_models.dart';

enum VariantPriceOverridesStatus {
  initial,
  loading,
  loaded,
  refreshing,
  failure,
}

class VariantPriceOverridesState extends Equatable {
  const VariantPriceOverridesState({
    this.status = VariantPriceOverridesStatus.initial,
    this.product,
    this.variant,
    this.basePrice,
    this.saved = const <VariantPriceOverride>[],
    this.draft = const <VariantPriceOverrideDraft>[],
    this.branches = const <Branch>[],
    this.branchError,
    this.fieldErrors = const <String, String>{},
    this.errorMessage,
    this.successMessage,
    this.isAuthoritative = false,
    this.isSaving = false,
    this.effectivePrice,
    this.effectiveBranchId,
    this.effectiveChannel,
    this.isEffectiveLoading = false,
    this.effectiveError,
  });
  final VariantPriceOverridesStatus status;
  final ProductDetail? product;
  final ProductVariant? variant;
  final PriceAmount? basePrice;
  final List<VariantPriceOverride> saved;
  final List<VariantPriceOverrideDraft> draft;
  final List<Branch> branches;
  final String? branchError;
  final Map<String, String> fieldErrors;
  final String? errorMessage;
  final String? successMessage;
  final bool isAuthoritative;
  final bool isSaving;
  final EffectiveVariantPrice? effectivePrice;
  final int? effectiveBranchId;
  final String? effectiveChannel;
  final bool isEffectiveLoading;
  final String? effectiveError;
  bool get isReadOnly =>
      product?.isArchived == true || variant?.isArchived == true;
  bool get isDirty =>
      _draftPayload(draft) !=
      _draftPayload(
        saved
            .map(VariantPriceOverrideDraft.fromOverride)
            .toList(growable: false),
      );
  bool get canEdit => isAuthoritative && !isReadOnly && !isSaving;
  VariantPriceOverridesState copyWith({
    VariantPriceOverridesStatus? status,
    ProductDetail? product,
    ProductVariant? variant,
    PriceAmount? basePrice,
    List<VariantPriceOverride>? saved,
    List<VariantPriceOverrideDraft>? draft,
    List<Branch>? branches,
    String? branchError,
    Map<String, String>? fieldErrors,
    String? errorMessage,
    String? successMessage,
    bool? isAuthoritative,
    bool? isSaving,
    EffectiveVariantPrice? effectivePrice,
    int? effectiveBranchId,
    String? effectiveChannel,
    bool? isEffectiveLoading,
    String? effectiveError,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearFields = false,
    bool clearBranchError = false,
    bool clearEffective = false,
    bool clearEffectiveError = false,
    bool clearEffectiveBranch = false,
    bool clearEffectiveChannel = false,
  }) => VariantPriceOverridesState(
    status: status ?? this.status,
    product: product ?? this.product,
    variant: variant ?? this.variant,
    basePrice: basePrice ?? this.basePrice,
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    branches: branches ?? this.branches,
    branchError: clearBranchError ? null : branchError ?? this.branchError,
    fieldErrors: clearFields
        ? const <String, String>{}
        : fieldErrors ?? this.fieldErrors,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
    isAuthoritative: isAuthoritative ?? this.isAuthoritative,
    isSaving: isSaving ?? this.isSaving,
    effectivePrice: clearEffective
        ? null
        : effectivePrice ?? this.effectivePrice,
    effectiveBranchId: clearEffectiveBranch
        ? null
        : effectiveBranchId ?? this.effectiveBranchId,
    effectiveChannel: clearEffectiveChannel
        ? null
        : effectiveChannel ?? this.effectiveChannel,
    isEffectiveLoading: isEffectiveLoading ?? this.isEffectiveLoading,
    effectiveError: clearEffectiveError
        ? null
        : effectiveError ?? this.effectiveError,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    product,
    variant,
    basePrice,
    saved,
    draft,
    branches,
    branchError,
    fieldErrors,
    errorMessage,
    successMessage,
    isAuthoritative,
    isSaving,
    effectivePrice,
    effectiveBranchId,
    effectiveChannel,
    isEffectiveLoading,
    effectiveError,
  ];
}

String _draftPayload(List<VariantPriceOverrideDraft> items) =>
    (items.map((item) => item.toJson().toString()).toList()..sort()).join('|');
