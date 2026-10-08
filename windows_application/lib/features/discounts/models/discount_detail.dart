import 'discount_product_selection.dart';
import 'discount_form_references.dart';
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
    this.fixedAmountBasis = 'per_order',
    this.priority = 0,
    this.combinationBehavior = 'follow_cafe_policy',
    required this.isActive,
    required this.appliesToAllBranches,
    required this.customerEligibilityMode,
    required this.targetProductIds,
    required this.targetCategoryIds,
    required this.customerGroupIds,
    this.customerIds = const <int>[],
    required this.branchIds,
    required this.paymentMethodIds,
    this.code,
    this.description,
    this.conditions,
    this.startsAt,
    this.endsAt,
    this.startDate,
    this.endDate,
    this.activeDays = const <String>[],
    this.startTime,
    this.endTime,
    this.minimumOrderAmount,
    this.maximumDiscountAmount,
    this.usageLimit,
    this.usageLimitPerCustomer,
    this.perCustomerDailyUsageLimit,
    this.status,
    this.productVariantSelections = const [],
    this.productTargets = const <DiscountTargetDetail>[],
    this.categoryTargets = const <DiscountTargetDetail>[],
    this.customerGroups = const <DiscountTargetDetail>[],
    this.customers = const <DiscountTargetDetail>[],
    this.branches = const <DiscountTargetDetail>[],
    this.paymentMethods = const <DiscountTargetDetail>[],
    this.bundleRequirements = const <DiscountBundleRequirement>[],
    this.channelKeys = const <String>[],
  });

  final int id;
  final String name;
  final String? code;
  final String? description;
  final String applicationMode;
  final String type;
  final String scope;
  final double value;
  final String fixedAmountBasis;
  final int priority;
  final String combinationBehavior;
  final String? conditions;
  final String? startsAt;
  final String? endsAt;
  final String? startDate;
  final String? endDate;
  final List<String> activeDays;
  final String? startTime;
  final String? endTime;
  final double? minimumOrderAmount;
  final double? maximumDiscountAmount;
  final int? usageLimit;
  final int? usageLimitPerCustomer;
  final int? perCustomerDailyUsageLimit;
  final String customerEligibilityMode;
  final List<int> targetProductIds;
  final List<int> targetCategoryIds;
  final List<int> customerGroupIds;
  final List<int> customerIds;
  final bool appliesToAllBranches;
  final List<int> branchIds;
  final List<int> paymentMethodIds;
  final bool isActive;
  final String? status;
  final List<DiscountProductSelection> productVariantSelections;
  List<DiscountProductSelection> get effectiveProductSelections =>
      targetProductIds
          .map(
            (id) =>
                productVariantSelections
                    .where((s) => s.productId == id)
                    .firstOrNull ??
                DiscountProductSelection(
                  productId: id,
                  product: productTargets
                      .where((p) => p.id == id)
                      .map(
                        (p) => DiscountFormReference(
                          id: p.id,
                          name: p.name ?? '#${p.id}',
                          isActive: p.isActive,
                        ),
                      )
                      .firstOrNull,
                ),
          )
          .toList();
  final List<DiscountTargetDetail> productTargets;
  final List<DiscountTargetDetail> categoryTargets;
  final List<DiscountTargetDetail> customerGroups;
  final List<DiscountTargetDetail> customers;
  final List<DiscountTargetDetail> branches;
  final List<DiscountTargetDetail> paymentMethods;
  final List<DiscountBundleRequirement> bundleRequirements;
  final List<String> channelKeys;

  factory DiscountDetail.fromJson(Map<String, dynamic> json) => DiscountDetail(
    id: readInt(json['id']) ?? 0,
    name: readString(json['name']),
    code: _nullable(json['code']),
    description: _nullable(json['description']),
    applicationMode: readString(json['applicationMode']),
    type: readString(json['type']),
    scope: readString(json['scope']),
    value: readDouble(json['value']),
    priority: readInt(json['priority']) ?? 0,
    combinationBehavior: _combinationBehavior(json['combinationBehavior']),
    fixedAmountBasis: readString(
      json['fixedAmountBasis'],
      fallback: 'per_order',
    ),
    conditions: _nullable(json['conditions']),
    startsAt: _nullable(json['startsAt']),
    endsAt: _nullable(json['endsAt']),
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
    perCustomerDailyUsageLimit: readInt(json['perCustomerDailyUsageLimit']),
    customerEligibilityMode: readString(
      json['customerEligibilityMode'],
      fallback: 'all',
    ),
    targetProductIds: _ids(json['targetProductIds']),
    targetCategoryIds: _ids(json['targetCategoryIds']),
    customerGroupIds: _ids(json['customerGroupIds']),
    customerIds: _ids(json['customerIds']),
    appliesToAllBranches: readBool(
      json['appliesToAllBranches'],
      fallback: true,
    ),
    branchIds: _ids(json['branchIds']),
    paymentMethodIds: _ids(json['paymentMethodIds']),
    isActive: readBool(json['isActive']),
    status: _nullable(json['status']),
    productVariantSelections: (json['productVariantSelections'] as List? ?? [])
        .map(
          (s) =>
              DiscountProductSelection.fromJson(Map<String, dynamic>.from(s)),
        )
        .toList(),
    productTargets: _targets(json['productTargets']),
    categoryTargets: _targets(json['categoryTargets']),
    customerGroups: _targets(json['customerGroups']),
    customers: _targets(json['customers']),
    branches: _targets(json['branches']),
    paymentMethods: _targets(json['paymentMethods']),
    bundleRequirements: _bundleRequirements(json['bundleRequirements']),
    channelKeys: _strings(json['channelKeys']),
  );

  DiscountUpsertRequest toUpsertRequest() => DiscountUpsertRequest(
    name: name,
    code: code,
    description: description,
    applicationMode: applicationMode,
    type: type,
    scope: scope,
    value: value,
    fixedAmountBasis: fixedAmountBasis,
    priority: priority,
    combinationBehavior: combinationBehavior,
    conditions: conditions,
    startsAt: startsAt,
    endsAt: endsAt,
    startDate: startDate,
    endDate: endDate,
    activeDays: activeDays,
    startTime: startTime,
    endTime: endTime,
    minimumOrderAmount: minimumOrderAmount,
    maximumDiscountAmount: maximumDiscountAmount,
    usageLimit: usageLimit,
    usageLimitPerCustomer: usageLimitPerCustomer,
    perCustomerDailyUsageLimit: perCustomerDailyUsageLimit,
    customerEligibilityMode: customerEligibilityMode,
    customerGroupIds: customerGroupIds,
    customerIds: customerIds,
    paymentMethodIds: paymentMethodIds,
    productVariantSelections: effectiveProductSelections,
    targetProductIds: targetProductIds,
    targetCategoryIds: targetCategoryIds,
    bundleRequirements: bundleRequirements,
    channelKeys: channelKeys,
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
  static List<DiscountBundleRequirement> _bundleRequirements(dynamic value) =>
      (value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (Map item) => DiscountBundleRequirement(
              productId: readInt(item['productId']) ?? 0,
              quantity: readDouble(item['quantity']),
              variantMode: item['variantMode'] == 'selected'
                  ? 'selected'
                  : (item['variantMode'] == 'all' ? 'all' : null),
              variantIds: _ids(item['variantIds']),
              variants:
                  (item['variants'] as List<dynamic>? ?? const <dynamic>[])
                      .whereType<Map>()
                      .map(
                        (Map variant) => DiscountFormReference.fromJson(
                          Map<String, dynamic>.from(variant),
                        ),
                      )
                      .toList(growable: false),
            ),
          )
          .where((DiscountBundleRequirement item) => item.productId > 0)
          .toList(growable: false);

  /// Legacy responses carry no value; unknown values read as the safe default.
  static String _combinationBehavior(dynamic value) =>
      value == 'exclusive' ? 'exclusive' : 'follow_cafe_policy';
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
