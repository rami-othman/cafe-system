import 'package:equatable/equatable.dart';

import '../../../pos/models/branch.dart';
import '../../models/catalog_models.dart';
import '../models/operational_availability_models.dart';

enum OperationalAvailabilityLoadStatus {
  initial,
  loading,
  loaded,
  refreshing,
  failure,
}

enum OperationalAvailabilityPreviewStatus { initial, loading, loaded, failure }

class OperationalAvailabilityState extends Equatable {
  const OperationalAvailabilityState({
    this.status = OperationalAvailabilityLoadStatus.initial,
    this.product,
    this.branches = const <Branch>[],
    this.productOverrides = const <OperationalAvailabilityOverride>[],
    this.variantOverrides = const <OperationalAvailabilityOverride>[],
    this.selectedVariantId,
    this.selectedBranchId,
    this.selectedChannel,
    this.previewStatus = OperationalAvailabilityPreviewStatus.initial,
    this.preview,
    this.previewError,
    this.isAuthoritative = false,
    this.isMutating = false,
    this.currentActionId,
    this.fieldErrors = const <String, String>{},
    this.errorMessage,
    this.successMessage,
  });

  final OperationalAvailabilityLoadStatus status;
  final ProductDetail? product;
  final List<Branch> branches;
  final List<OperationalAvailabilityOverride> productOverrides;
  final List<OperationalAvailabilityOverride> variantOverrides;
  final int? selectedVariantId;
  final int? selectedBranchId;
  final String? selectedChannel;
  final OperationalAvailabilityPreviewStatus previewStatus;
  final OperationalAvailabilityPreview? preview;
  final String? previewError;
  final bool isAuthoritative;
  final bool isMutating;
  final String? currentActionId;
  final Map<String, String> fieldErrors;
  final String? errorMessage;
  final String? successMessage;

  ProductVariant? get selectedVariant => product?.variants
      .where((item) => item.id == selectedVariantId)
      .firstOrNull;
  bool get isProductArchived => product?.isArchived == true;
  bool get isSelectedVariantArchived => selectedVariant?.isArchived == true;
  bool get canMutateProduct =>
      isAuthoritative && !isProductArchived && !isMutating;
  bool get canMutateVariant =>
      canMutateProduct &&
      selectedVariantId != null &&
      !isSelectedVariantArchived;
  List<OperationalAvailabilityOverride> get visibleProductOverrides =>
      _filter(productOverrides);
  List<OperationalAvailabilityOverride> get visibleVariantOverrides =>
      _filter(variantOverrides);

  List<OperationalAvailabilityOverride> _filter(
    List<OperationalAvailabilityOverride> values,
  ) => values
      .where(
        (item) =>
            (selectedBranchId == null || item.branchId == selectedBranchId) &&
            (selectedChannel == null ||
                item.channel == selectedChannel ||
                item.channel == 'all'),
      )
      .toList(growable: false);

  OperationalAvailabilityState copyWith({
    OperationalAvailabilityLoadStatus? status,
    ProductDetail? product,
    List<Branch>? branches,
    List<OperationalAvailabilityOverride>? productOverrides,
    List<OperationalAvailabilityOverride>? variantOverrides,
    int? selectedVariantId,
    int? selectedBranchId,
    String? selectedChannel,
    OperationalAvailabilityPreviewStatus? previewStatus,
    OperationalAvailabilityPreview? preview,
    String? previewError,
    bool? isAuthoritative,
    bool? isMutating,
    String? currentActionId,
    Map<String, String>? fieldErrors,
    String? errorMessage,
    String? successMessage,
    bool clearVariant = false,
    bool clearBranch = false,
    bool clearChannel = false,
    bool clearAction = false,
    bool clearFields = false,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearPreview = false,
    bool clearPreviewError = false,
  }) => OperationalAvailabilityState(
    status: status ?? this.status,
    product: product ?? this.product,
    branches: branches ?? this.branches,
    productOverrides: productOverrides ?? this.productOverrides,
    variantOverrides: variantOverrides ?? this.variantOverrides,
    selectedVariantId: clearVariant
        ? null
        : selectedVariantId ?? this.selectedVariantId,
    selectedBranchId: clearBranch
        ? null
        : selectedBranchId ?? this.selectedBranchId,
    selectedChannel: clearChannel
        ? null
        : selectedChannel ?? this.selectedChannel,
    previewStatus: previewStatus ?? this.previewStatus,
    preview: clearPreview ? null : preview ?? this.preview,
    previewError: clearPreviewError ? null : previewError ?? this.previewError,
    isAuthoritative: isAuthoritative ?? this.isAuthoritative,
    isMutating: isMutating ?? this.isMutating,
    currentActionId: clearAction
        ? null
        : currentActionId ?? this.currentActionId,
    fieldErrors: clearFields
        ? const <String, String>{}
        : fieldErrors ?? this.fieldErrors,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    product,
    branches,
    productOverrides,
    variantOverrides,
    selectedVariantId,
    selectedBranchId,
    selectedChannel,
    previewStatus,
    preview,
    previewError,
    isAuthoritative,
    isMutating,
    currentActionId,
    fieldErrors,
    errorMessage,
    successMessage,
  ];
}
