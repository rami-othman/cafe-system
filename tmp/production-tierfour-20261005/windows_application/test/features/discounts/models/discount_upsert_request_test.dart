import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';

void main() {
  test('all branches serializes an empty integer branch ID list', () {
    final Map<String, dynamic> json = _request(
      appliesToAllBranches: true,
    ).toJson();
    expect(json['appliesToAllBranches'], isTrue);
    expect(json['branchIds'], isEmpty);
    expect(json.containsKey('branchId'), isFalse);
  });

  test('selected branches serialize real integer IDs and never labels', () {
    final Map<String, dynamic> json = _request(
      appliesToAllBranches: false,
      branchIds: const <int>[41, 43],
    ).toJson();
    expect(json['appliesToAllBranches'], isFalse);
    expect(json['branchIds'], <int>[41, 43]);
    expect(json['branchIds'], isNot(contains('Downtown')));
  });

  test('serializes the complete V1 policy with canonical ID targets', () {
    final Map<String, dynamic> json = DiscountUpsertRequest(
      name: 'Late member discount',
      code: 'LATE125',
      description: 'Member-only evening offer',
      applicationMode: 'code',
      type: 'percentage',
      scope: 'category',
      value: 12.5,
      minimumOrderAmount: 5000,
      maximumDiscountAmount: 25000,
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      activeDays: const <String>['Mon', 'Fri'],
      startTime: '22:00',
      endTime: '02:00',
      usageLimit: 200,
      usageLimitPerCustomer: 3,
      customerEligibilityMode: 'selected_groups',
      customerGroupIds: const <int>[41, 42],
      paymentMethodIds: const <int>[61, 62],
      targetCategoryIds: const <int>[31, 32],
      appliesToAllBranches: false,
      branchIds: const <int>[51, 52],
      isActive: true,
    ).toJson();

    expect(json['value'], 12.5);
    expect(json['targetProductIds'], isEmpty);
    expect(json['targetCategoryIds'], <int>[31, 32]);
    expect(json['customerGroupIds'], <int>[41, 42]);
    expect(json['paymentMethodIds'], <int>[61, 62]);
    expect(json['activeDays'], <String>['Mon', 'Fri']);
    expect(json['startTime'], '22:00');
    expect(json['endTime'], '02:00');
    expect(json['usageLimitPerCustomer'], 3);
    expect(json['customerEligibility'], isNull);
    expect(json['paymentMethod'], isNull);
  });

  test('serializes a zero configured discount value as zero', () {
    final Map<String, dynamic> json = _request(
      appliesToAllBranches: true,
      value: 0,
    ).toJson();

    expect(json['value'], 0);
  });

  test(
    'serializes explicit nullable clears without retaining stale targets',
    () {
      final Map<String, dynamic> json = DiscountUpsertRequest(
        name: 'Cleared policy',
        applicationMode: 'manual',
        type: 'fixed',
        scope: 'order',
        value: 7.5,
        maximumDiscountAmount: null,
        startDate: null,
        endDate: null,
        activeDays: const <String>[],
        startTime: null,
        endTime: null,
        customerEligibilityMode: 'all',
        customerGroupIds: const <int>[],
        targetProductIds: const <int>[],
        targetCategoryIds: const <int>[],
        appliesToAllBranches: true,
        branchIds: const <int>[],
        isActive: true,
      ).toJson();

      expect(json['maximumDiscountAmount'], isNull);
      expect(json['startDate'], isNull);
      expect(json['endDate'], isNull);
      expect(json['startTime'], isNull);
      expect(json['endTime'], isNull);
      expect(json['customerGroupIds'], isEmpty);
      expect(json['targetProductIds'], isEmpty);
      expect(json['targetCategoryIds'], isEmpty);
      expect(json['branchIds'], isEmpty);
    },
  );

  test('serializes V2 customer, channel, daily-limit, and bundle fields', () {
    final Map<String, dynamic> json = DiscountUpsertRequest(
      name: 'VIP breakfast package',
      code: 'CPN-ABCD-EFGH',
      applicationMode: 'code',
      type: 'percentage',
      scope: 'bundle',
      value: 20,
      customerEligibilityMode: 'selected_customers',
      customerIds: const <int>[71, 72],
      customerGroupIds: const <int>[],
      perCustomerDailyUsageLimit: 1,
      channelKeys: const <String>['pos', 'delivery'],
      bundleRequirements: const <DiscountBundleRequirement>[
        DiscountBundleRequirement(productId: 11, quantity: 1),
        DiscountBundleRequirement(productId: 12, quantity: 2),
      ],
      appliesToAllBranches: true,
      isActive: true,
    ).toJson();

    expect(json['customerEligibilityMode'], 'selected_customers');
    expect(json['customerIds'], <int>[71, 72]);
    expect(json['customerGroupIds'], isEmpty);
    expect(json['perCustomerDailyUsageLimit'], 1);
    expect(json['channelKeys'], <String>['pos', 'delivery']);
    expect(json['bundleRequirements'], <Map<String, dynamic>>[
      <String, dynamic>{'productId': 11, 'quantity': 1.0},
      <String, dynamic>{'productId': 12, 'quantity': 2.0},
    ]);
  });
}

DiscountUpsertRequest _request({
  required bool appliesToAllBranches,
  List<int> branchIds = const <int>[],
  double value = 10,
}) => DiscountUpsertRequest(
  name: 'Branch test',
  applicationMode: 'code',
  type: 'percentage',
  scope: 'order',
  value: value,
  isActive: true,
  appliesToAllBranches: appliesToAllBranches,
  branchIds: branchIds,
);
