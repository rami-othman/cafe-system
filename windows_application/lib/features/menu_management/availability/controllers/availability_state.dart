// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';

import '../../../pos/models/branch.dart';
import '../../models/catalog_models.dart';
import '../models/availability_models.dart';

enum AvailabilityStatus { initial, loading, loaded, refreshing, failure }

class AvailabilityState extends Equatable {
  const AvailabilityState({
    this.status = AvailabilityStatus.initial,
    this.product,
    this.branches = const <Branch>[],
    this.saved = const <AvailabilityRule>[],
    this.draft = const <AvailabilityRuleDraft>[],
    this.selectedVariantId,
    this.selectedBranchId,
    this.selectedChannel,
    this.isAuthoritative = false,
    this.isSaving = false,
    this.previewAt,
    this.preview,
    this.isPreviewLoading = false,
    this.errorMessage,
    this.previewError,
    this.fieldErrors = const <String, String>{},
    this.successMessage,
  });
  final AvailabilityStatus status;
  final ProductDetail? product;
  final List<Branch> branches;
  final List<AvailabilityRule> saved;
  final List<AvailabilityRuleDraft> draft;
  final int? selectedVariantId;
  final int? selectedBranchId;
  final String? selectedChannel;
  final bool isAuthoritative;
  final bool isSaving;
  final DateTime? previewAt;
  final AvailabilityPreview? preview;
  final bool isPreviewLoading;
  final String? errorMessage;
  final String? previewError;
  final Map<String, String> fieldErrors;
  final String? successMessage;
  ProductVariant? get selectedVariant => product?.variants
      .where((item) => item.id == selectedVariantId)
      .firstOrNull;
  bool get isReadOnly =>
      product?.isArchived == true || selectedVariant?.isArchived == true;
  bool get canEdit => isAuthoritative && !isReadOnly && !isSaving;
  AvailabilityScope get selectedScope =>
      availabilityScopeOf(branchId: selectedBranchId, channel: selectedChannel);
  bool get isDirty =>
      _payload(draft) != _payload(saved.map((r) => r.toDraft()).toList());
  List<AvailabilityRuleDraft> get exactRules => draft
      .where(
        (item) =>
            item.productVariantId == selectedVariantId &&
            item.branchId == selectedBranchId &&
            item.channel == selectedChannel,
      )
      .toList(growable: false);
  List<AvailabilityRule> get inheritedRules => saved
      .where((item) {
        if (item.productVariantId != selectedVariantId &&
            !(selectedVariantId != null && item.productVariantId == null))
          return false;
        if (item.productVariantId == selectedVariantId &&
            item.scope == selectedScope)
          return false;
        return (item.branchId == null || item.branchId == selectedBranchId) &&
            (item.channel == null || item.channel == selectedChannel);
      })
      .toList(growable: false);
  AvailabilityState copyWith({
    AvailabilityStatus? status,
    ProductDetail? product,
    List<Branch>? branches,
    List<AvailabilityRule>? saved,
    List<AvailabilityRuleDraft>? draft,
    int? selectedVariantId,
    int? selectedBranchId,
    String? selectedChannel,
    bool? isAuthoritative,
    bool? isSaving,
    DateTime? previewAt,
    AvailabilityPreview? preview,
    bool? isPreviewLoading,
    String? errorMessage,
    String? previewError,
    Map<String, String>? fieldErrors,
    String? successMessage,
    bool clearVariant = false,
    bool clearBranch = false,
    bool clearChannel = false,
    bool clearError = false,
    bool clearPreview = false,
    bool clearPreviewError = false,
    bool clearFields = false,
    bool clearSuccess = false,
  }) => AvailabilityState(
    status: status ?? this.status,
    product: product ?? this.product,
    branches: branches ?? this.branches,
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    selectedVariantId: clearVariant
        ? null
        : selectedVariantId ?? this.selectedVariantId,
    selectedBranchId: clearBranch
        ? null
        : selectedBranchId ?? this.selectedBranchId,
    selectedChannel: clearChannel
        ? null
        : selectedChannel ?? this.selectedChannel,
    isAuthoritative: isAuthoritative ?? this.isAuthoritative,
    isSaving: isSaving ?? this.isSaving,
    previewAt: previewAt ?? this.previewAt,
    preview: clearPreview ? null : preview ?? this.preview,
    isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    previewError: clearPreviewError ? null : previewError ?? this.previewError,
    fieldErrors: clearFields
        ? const <String, String>{}
        : fieldErrors ?? this.fieldErrors,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    product,
    branches,
    saved,
    draft,
    selectedVariantId,
    selectedBranchId,
    selectedChannel,
    isAuthoritative,
    isSaving,
    previewAt,
    preview,
    isPreviewLoading,
    errorMessage,
    previewError,
    fieldErrors,
    successMessage,
  ];
}

String _payload(List<AvailabilityRuleDraft> items) =>
    (items.map((item) => item.toJson().toString()).toList()..sort()).join('|');
