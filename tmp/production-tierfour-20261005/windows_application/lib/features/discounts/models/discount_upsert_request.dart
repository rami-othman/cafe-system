class DiscountUpsertRequest {
  const DiscountUpsertRequest({
    required this.name,
    required this.applicationMode,
    required this.type,
    required this.scope,
    required this.value,
    required this.isActive,
    this.code,
    this.description,
    this.conditions,
    this.minimumOrderAmount,
    this.maximumDiscountAmount,
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
  final String? conditions;
  final double? minimumOrderAmount;
  final double? maximumDiscountAmount;
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
    'conditions': conditions,
    'minimumOrderAmount': minimumOrderAmount,
    'maximumDiscountAmount': maximumDiscountAmount,
    'startDate': startDate,
    'endDate': endDate,
    'activeDays': activeDays,
    'startTime': startTime,
    'endTime': endTime,
    'usageLimit': usageLimit,
    'usageLimitPerCustomer': usageLimitPerCustomer,
    'perCustomerDailyUsageLimit': perCustomerDailyUsageLimit,
    'customerEligibilityMode': customerEligibilityMode,
    'customerGroupIds': customerGroupIds,
    'customerIds': customerIds,
    'paymentMethodIds': paymentMethodIds,
    'targetProductIds': targetProductIds,
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
}

class DiscountBundleRequirement {
  const DiscountBundleRequirement({
    required this.productId,
    required this.quantity,
  });

  final int productId;
  final double quantity;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'productId': productId,
    'quantity': quantity,
  };
}
