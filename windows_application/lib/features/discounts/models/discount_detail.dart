import '../../pos/models/json_helpers.dart';
import 'discount_upsert_request.dart';

/// Complete administrative Discount V1 representation. Keep raw date/time
/// values as strings so a fetch-edit-save cycle cannot shift branch-local
/// calendar dates through the Flutter device timezone.
class DiscountDetail {
  const DiscountDetail({
    required this.id,
    required this.name,
    required this.applicationMode,
    required this.type,
    required this.scope,
    required this.value,
    required this.isActive,
    required this.appliesToAllBranches,
    required this.customerEligibilityMode,
    required this.targetProductIds,
    required this.targetCategoryIds,
    required this.customerGroupIds,
    required this.branchIds,
    required this.paymentMethodIds,
    this.code,
    this.description,
    this.conditions,
    this.startDate,
    this.endDate,
    this.activeDays = const <String>[],
    this.startTime,
    this.endTime,
    this.minimumOrderAmount,
    this.maximumDiscountAmount,
    this.usageLimit,
    this.usageLimitPerCustomer,
    this.status,
    this.productTargets = const <DiscountTargetDetail>[],
    this.categoryTargets = const <DiscountTargetDetail>[],
    this.customerGroups = const <DiscountTargetDetail>[],
    this.branches = const <DiscountTargetDetail>[],
    this.paymentMethods = const <DiscountTargetDetail>[],
  });

  final int id;
  final String name;
  final String? code;
  final String? description;
  final String applicationMode;
  final String type;
  final String scope;
  final double value;
  final String? conditions;
  final String? startDate;
  final String? endDate;
  final List<String> activeDays;
  final String? startTime;
  final String? endTime;
  final double? minimumOrderAmount;
  final double? maximumDiscountAmount;
  final int? usageLimit;
  final int? usageLimitPerCustomer;
  final String customerEligibilityMode;
  final List<int> targetProductIds;
  final List<int> targetCategoryIds;
  final List<int> customerGroupIds;
  final bool appliesToAllBranches;
  final List<int> branchIds;
  final List<int> paymentMethodIds;
  final bool isActive;
  final String? status;
  final List<DiscountTargetDetail> productTargets;
  final List<DiscountTargetDetail> categoryTargets;
  final List<DiscountTargetDetail> customerGroups;
  final List<DiscountTargetDetail> branches;
  final List<DiscountTargetDetail> paymentMethods;

  factory DiscountDetail.fromJson(Map<String, dynamic> json) => DiscountDetail(
    id: readInt(json['id']) ?? 0,
    name: readString(json['name']),
    code: _nullable(json['code']),
    description: _nullable(json['description']),
    applicationMode: readString(json['applicationMode']),
    type: readString(json['type']),
    scope: readString(json['scope']),
    value: readDouble(json['value']),
    conditions: _nullable(json['conditions']),
    startDate: _nullable(json['startDate']),
    endDate: _nullable(json['endDate']),
    activeDays: _strings(json['activeDays']),
    startTime: _nullable(json['startTime']),
    endTime: _nullable(json['endTime']),
    minimumOrderAmount: json['minimumOrderAmount'] == null
        ? null
        : readDouble(json['minimumOrderAmount']),
    maximumDiscountAmount: json['maximumDiscountAmount'] == null
        ? null
        : readDouble(json['maximumDiscountAmount']),
    usageLimit: readInt(json['usageLimit']),
    usageLimitPerCustomer: readInt(json['usageLimitPerCustomer']),
    customerEligibilityMode: readString(
      json['customerEligibilityMode'],
      fallback: 'all',
    ),
    targetProductIds: _ids(json['targetProductIds']),
    targetCategoryIds: _ids(json['targetCategoryIds']),
    customerGroupIds: _ids(json['customerGroupIds']),
    appliesToAllBranches: readBool(
      json['appliesToAllBranches'],
      fallback: true,
    ),
    branchIds: _ids(json['branchIds']),
    paymentMethodIds: _ids(json['paymentMethodIds']),
    isActive: readBool(json['isActive']),
    status: _nullable(json['status']),
    productTargets: _targets(json['productTargets']),
    categoryTargets: _targets(json['categoryTargets']),
    customerGroups: _targets(json['customerGroups']),
    branches: _targets(json['branches']),
    paymentMethods: _targets(json['paymentMethods']),
  );

  DiscountUpsertRequest toUpsertRequest() => DiscountUpsertRequest(
    name: name,
    code: code,
    description: description,
    applicationMode: applicationMode,
    type: type,
    scope: scope,
    value: value,
    conditions: conditions,
    startDate: startDate,
    endDate: endDate,
    activeDays: activeDays,
    startTime: startTime,
    endTime: endTime,
    minimumOrderAmount: minimumOrderAmount,
    maximumDiscountAmount: maximumDiscountAmount,
    usageLimit: usageLimit,
    usageLimitPerCustomer: usageLimitPerCustomer,
    customerEligibilityMode: customerEligibilityMode,
    customerGroupIds: customerGroupIds,
    paymentMethodIds: paymentMethodIds,
    targetProductIds: targetProductIds,
    targetCategoryIds: targetCategoryIds,
    appliesToAllBranches: appliesToAllBranches,
    branchIds: branchIds,
    isActive: isActive,
  );

  static List<int> _ids(dynamic value) =>
      (value as List<dynamic>? ?? const <dynamic>[])
          .map(readInt)
          .whereType<int>()
          .toList(growable: false);
  static List<String> _strings(dynamic value) =>
      (value as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => readString(item))
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
  static List<DiscountTargetDetail> _targets(dynamic value) =>
      (value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (Map item) =>
                DiscountTargetDetail.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
  static String? _nullable(dynamic value) {
    final String result = readString(value).trim();
    return result.isEmpty ? null : result;
  }
}

class DiscountTargetDetail {
  const DiscountTargetDetail({
    required this.id,
    this.name,
    required this.isActive,
  });

  final int id;
  final String? name;
  final bool isActive;

  factory DiscountTargetDetail.fromJson(Map<String, dynamic> json) =>
      DiscountTargetDetail(
        id: readInt(json['id']) ?? 0,
        name: DiscountDetail._nullable(json['name']),
        isActive: readBool(json['isActive']),
      );
}
