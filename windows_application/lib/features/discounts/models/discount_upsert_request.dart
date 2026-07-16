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
    this.activeDays,
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
  final List<String>? activeDays;
  final String? customerEligibility;
  final String? paymentMethod;
  final bool appliesToAllBranches;
  final List<int> branchIds;
  final bool isActive;

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
    'activeDays': activeDays,
    'customerEligibility': customerEligibility,
    'paymentMethod': paymentMethod,
    'appliesToAllBranches': appliesToAllBranches,
    'branchIds': branchIds,
    'isActive': isActive,
  }..removeWhere((String _, dynamic value) => value == null);
}
