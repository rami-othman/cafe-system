import 'discount_form_references.dart';
import 'discount_product_selection.dart';

class DiscountUpsertRequest {
  const DiscountUpsertRequest({
    required this.name,
    required this.applicationMode,
    required this.type,
    required this.scope,
    required this.value,
    this.fixedAmountBasis = 'per_order',
    this.priority,
    this.combinationBehavior = 'follow_cafe_policy',
    required this.isActive,
    this.code,
    this.description,
    this.conditions,
    this.minimumOrderAmount,
    this.maximumDiscountAmount,
    this.startsAt,
    this.endsAt,
    this.startDate,
    this.endDate,
    this.activeDays,
    this.startTime,
    this.endTime,
    this.usageLimit,
    this.usageLimitPerCustomer,
    this.perCustomerDailyUsageLimit,
    this.customerEligibilityMode = 'all',
    this.customerGroupIds = const <int>[],
    this.customerIds = const <int>[],
    this.paymentMethodIds = const <int>[],
    this.productVariantSelections = const [],
    this.targetProductIds = const <int>[],
    this.targetCategoryIds = const <int>[],
    this.bundleRequirements = const <DiscountBundleRequirement>[],
    this.channelKeys = const <String>[],
    // Deprecated server compatibility fields. New callers should use the
    // canonical IDs and eligibility mode above.
    this.customerEligibility,
    this.paymentMethod,
    required this.appliesToAllBranches,
    this.branchIds = const <int>[],
  });

  final String name;
  final String? code;
  final String? description;
  final String applicationMode;
  final String type;
  final String scope;
  final double value;
  final String fixedAmountBasis;
  final int? priority;

  /// `follow_cafe_policy` or `exclusive`. A discount may only restrict the
  /// cafe policy, never widen it. Not editable in the UI until Discount V3
  /// Phase 3; it is carried so a fetch-edit-save cycle never resets it.
  final String combinationBehavior;
  final String? conditions;
  final double? minimumOrderAmount;
  final double? maximumDiscountAmount;
  final String? startsAt;
  final String? endsAt;
  final String? startDate;
  final String? endDate;
  final List<String>? activeDays;
  final String? startTime;
  final String? endTime;
  final int? usageLimit;
  final int? usageLimitPerCustomer;
  final int? perCustomerDailyUsageLimit;
  final String customerEligibilityMode;
  final List<int> customerGroupIds;
  final List<int> customerIds;
  final List<int> paymentMethodIds;
  final List<DiscountProductSelection> productVariantSelections;
  final List<int> targetProductIds;
  final List<int> targetCategoryIds;
  final List<DiscountBundleRequirement> bundleRequirements;
  final List<String> channelKeys;
  final String? customerEligibility;
  final String? paymentMethod;
  final bool appliesToAllBranches;
  final List<int> branchIds;
  final bool isActive;

  /// PUT uses full-policy replacement. Nullable keys are intentionally kept so
  /// an edit can explicitly clear a prior V1 value instead of retaining it.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'code': code,
    'description': description,
    'applicationMode': applicationMode,
    'type': type,
    'scope': scope,
    'value': value,
    'fixedAmountBasis': fixedAmountBasis,
    if (priority != null) 'priority': priority,
    'combinationBehavior': combinationBehavior,
    'conditions': conditions,
    'minimumOrderAmount': minimumOrderAmount,
    'maximumDiscountAmount': maximumDiscountAmount,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'startDate': startDate,
    'endDate': endDate,
    'activeDays': activeDays,
    'startTime': _time(startTime),
    'endTime': _time(endTime),
    'usageLimit': usageLimit,
    'usageLimitPerCustomer': usageLimitPerCustomer,
    'perCustomerDailyUsageLimit': perCustomerDailyUsageLimit,
    'customerEligibilityMode': customerEligibilityMode,
    'customerGroupIds': customerGroupIds,
    'customerIds': customerIds,
    'paymentMethodIds': paymentMethodIds,
    'targetProductIds': targetProductIds,
    if (scope == 'product') 'productVariantSelections': _selectionWrites(),
    'targetCategoryIds': targetCategoryIds,
    'bundleRequirements': bundleRequirements
        .map((DiscountBundleRequirement item) => item.toJson())
        .toList(growable: false),
    'channelKeys': channelKeys,
    'customerEligibility': customerEligibility,
    'paymentMethod': paymentMethod,
    'appliesToAllBranches': appliesToAllBranches,
    'branchIds': branchIds,
    'isActive': isActive,
  };
  static String? _time(String? value) =>
      value != null && RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(value)
      ? value.substring(0, 5)
      : value;
  List<Map<String, dynamic>> _selectionWrites() {
    final selections = productVariantSelections.isEmpty
        ? targetProductIds
              .map((id) => DiscountProductSelection(productId: id))
              .toList()
        : productVariantSelections;
    if (targetProductIds.toSet().length != targetProductIds.length ||
        selections.length != targetProductIds.length ||
        selections.map((s) => s.productId).toSet().length !=
            selections.length ||
        selections.any(
          (s) =>
              !targetProductIds.contains(s.productId) ||
              !s.isValid ||
              s.hasUnavailable,
        )) {
      throw ArgumentError('productVariantSelections');
    }
    return selections.map((s) => s.toJson()).toList();
  }
}

class DiscountBundleRequirement {
  const DiscountBundleRequirement({
    required this.productId,
    required this.quantity,
    this.variantMode,
    this.variantIds = const <int>[],
    this.variants = const <DiscountFormReference>[],
  });

  final int productId;
  final double quantity;

  /// `all` or `selected`. Null means the variant scope was not specified: the
  /// field is then omitted from writes and the backend keeps the saved scope.
  final String? variantMode;
  final List<int> variantIds;
  final List<DiscountFormReference> variants;

  bool get isSelected => variantMode == 'selected';

  bool get isVariantScopeValid =>
      variantMode == null ||
      (variantMode == 'all'
          ? variantIds.isEmpty
          : variantMode == 'selected' &&
                variantIds.isNotEmpty &&
                variantIds.every((int id) => id > 0) &&
                variantIds.toSet().length == variantIds.length);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'productId': productId,
    'quantity': quantity,
    if (variantMode != null) ...<String, dynamic>{
      'variantMode': variantMode,
      'variantIds': variantMode == 'selected' ? variantIds : const <int>[],
    },
  };
}
