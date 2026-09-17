import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/discounts/models/discount_detail.dart';

void main() {
  test(
    'complete V1 detail deserializes and preserves a complete upsert policy',
    () {
      final DiscountDetail detail = DiscountDetail.fromJson(<String, dynamic>{
        'id': 81,
        'name': 'Member evening offer',
        'code': 'MEMBER20',
        'description': 'No loss on edit',
        'applicationMode': 'code',
        'type': 'percentage',
        'scope': 'category',
        'value': 20,
        'conditions': 'Canonical V1',
        'startDate': '2026-10-01',
        'endDate': '2026-10-31',
        'activeDays': <String>['Mon', 'Fri'],
        'startTime': '22:00:00',
        'endTime': '02:00:00',
        'minimumOrderAmount': 30,
        'maximumDiscountAmount': 50,
        'usageLimit': 200,
        'usageLimitPerCustomer': 3,
        'customerEligibilityMode': 'selected_groups',
        'targetProductIds': const <int>[],
        'targetCategoryIds': <int>[31, 32],
        'customerGroupIds': <int>[41, 42],
        'appliesToAllBranches': false,
        'branchIds': <int>[51, 52],
        'paymentMethodIds': <int>[61, 62],
        'isActive': true,
        'status': 'active',
        'categoryTargets': <Map<String, dynamic>>[
          <String, dynamic>{'id': 31, 'name': 'Drinks', 'isActive': true},
        ],
        'customerGroups': <Map<String, dynamic>>[
          <String, dynamic>{'id': 41, 'name': 'Members', 'isActive': true},
        ],
        'branches': <Map<String, dynamic>>[
          <String, dynamic>{'id': 51, 'name': 'Main', 'isActive': true},
        ],
        'paymentMethods': <Map<String, dynamic>>[
          <String, dynamic>{'id': 61, 'name': 'Cash Drawer', 'isActive': true},
        ],
      });

      final Map<String, dynamic> request = detail.toUpsertRequest().toJson();
      expect(request['startDate'], '2026-10-01');
      expect(request['endDate'], '2026-10-31');
      expect(request['activeDays'], <String>['Mon', 'Fri']);
      expect(request['startTime'], '22:00:00');
      expect(request['endTime'], '02:00:00');
      expect(request['targetCategoryIds'], <int>[31, 32]);
      expect(request['customerGroupIds'], <int>[41, 42]);
      expect(request['branchIds'], <int>[51, 52]);
      expect(request['paymentMethodIds'], <int>[61, 62]);
      expect(request['usageLimitPerCustomer'], 3);
      expect(detail.customerGroups.single.name, 'Members');
    },
  );

  test('complete V2 detail remains lossless through an upsert request', () {
    final DiscountDetail detail = DiscountDetail.fromJson(<String, dynamic>{
      'id': 82,
      'name': 'Customer bundle',
      'code': 'CPN-ABCD-EFGH',
      'applicationMode': 'code',
      'type': 'fixed',
      'scope': 'bundle',
      'value': 5000,
      'isActive': true,
      'appliesToAllBranches': false,
      'customerEligibilityMode': 'selected_customers',
      'targetProductIds': const <int>[],
      'targetCategoryIds': const <int>[],
      'customerGroupIds': const <int>[],
      'customerIds': <int>[71, 72],
      'branchIds': <int>[51],
      'paymentMethodIds': const <int>[],
      'perCustomerDailyUsageLimit': 1,
      'channelKeys': <String>['pos', 'delivery'],
      'bundleRequirements': <Map<String, dynamic>>[
        <String, dynamic>{'productId': 11, 'quantity': 1},
        <String, dynamic>{'productId': 12, 'quantity': 2},
      ],
    });

    final Map<String, dynamic> request = detail.toUpsertRequest().toJson();
    expect(request['scope'], 'bundle');
    expect(request['customerIds'], <int>[71, 72]);
    expect(request['customerGroupIds'], isEmpty);
    expect(request['perCustomerDailyUsageLimit'], 1);
    expect(request['channelKeys'], <String>['pos', 'delivery']);
    expect(request['bundleRequirements'], <Map<String, dynamic>>[
      <String, dynamic>{'productId': 11, 'quantity': 1.0},
      <String, dynamic>{'productId': 12, 'quantity': 2.0},
    ]);
  });
}
