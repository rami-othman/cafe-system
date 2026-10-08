import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/cafe_configuration/models/discount_settings.dart';
import 'package:windows_application/features/discounts/models/discount_detail.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';

class _CodeClient extends DioApiClient {
  _CodeClient(this.code);
  final Object? code;
  String? path;

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    this.path = path;
    return <String, dynamic>{'code': code};
  }
}

Map<String, dynamic> _detailJson({
  Object? combinationBehavior = 'follow_cafe_policy',
  List<Map<String, dynamic>> requirements = const <Map<String, dynamic>>[],
  bool omitCombination = false,
}) => <String, dynamic>{
  'id': 9,
  'name': 'Latte combo',
  'code': 'K7M4P',
  'applicationMode': 'code',
  'type': 'percentage',
  'scope': 'bundle',
  'value': 15,
  'isActive': true,
  'appliesToAllBranches': true,
  'customerEligibilityMode': 'all',
  if (!omitCombination) 'combinationBehavior': combinationBehavior,
  'bundleRequirements': requirements,
};

void main() {
  group('combinationBehavior', () {
    test('reads exclusive and round-trips it through the upsert request', () {
      final DiscountDetail detail = DiscountDetail.fromJson(
        _detailJson(combinationBehavior: 'exclusive'),
      );
      expect(detail.combinationBehavior, 'exclusive');
      expect(detail.toUpsertRequest().combinationBehavior, 'exclusive');
      expect(
        detail.toUpsertRequest().toJson()['combinationBehavior'],
        'exclusive',
      );
    });

    test(
      'an older backend response and unknown values read as follow_cafe_policy',
      () {
        expect(
          DiscountDetail.fromJson(
            _detailJson(omitCombination: true),
          ).combinationBehavior,
          'follow_cafe_policy',
        );
        expect(
          DiscountDetail.fromJson(
            _detailJson(combinationBehavior: 'stack'),
          ).combinationBehavior,
          'follow_cafe_policy',
        );
        expect(
          DiscountDetail.fromJson(
            _detailJson(combinationBehavior: null),
          ).combinationBehavior,
          'follow_cafe_policy',
        );
      },
    );

    test('a new request defaults to follow_cafe_policy', () {
      const DiscountUpsertRequest request = DiscountUpsertRequest(
        name: 'New',
        applicationMode: 'manual',
        type: 'percentage',
        scope: 'order',
        value: 5,
        isActive: true,
        appliesToAllBranches: true,
      );
      expect(request.toJson()['combinationBehavior'], 'follow_cafe_policy');
    });
  });

  group('short generated coupon codes', () {
    test(
      'the repository hands the five-character backend code through unchanged',
      () async {
        final _CodeClient client = _CodeClient('K7M4P');
        expect(
          await DiscountsApiRepository(client).generateCouponCode(),
          'K7M4P',
        );
        expect(client.path, 'discounts/generate-code');
      },
    );

    test('legacy long codes still read and write back unchanged', () {
      final DiscountDetail detail = DiscountDetail.fromJson(
        _detailJson()..['code'] = 'CPN-ABCD-EFGH',
      );
      expect(detail.code, 'CPN-ABCD-EFGH');
      expect(detail.toUpsertRequest().toJson()['code'], 'CPN-ABCD-EFGH');
    });

    test('an empty generated code is rejected rather than saved', () async {
      expect(
        DiscountsApiRepository(_CodeClient('  ')).generateCouponCode(),
        throwsStateError,
      );
    });
  });

  group('package variant requirements', () {
    test('selected variants are restored and written back unchanged', () {
      final DiscountDetail detail = DiscountDetail.fromJson(
        _detailJson(
          requirements: <Map<String, dynamic>>[
            <String, dynamic>{
              'productId': 11,
              'quantity': 1,
              'variantMode': 'selected',
              'variantIds': <int>[101, 102],
              'variants': <Map<String, dynamic>>[
                <String, dynamic>{'id': 101, 'name': 'Large', 'isActive': true},
                <String, dynamic>{'id': 102, 'name': 'Iced', 'isActive': false},
              ],
            },
            <String, dynamic>{
              'productId': 12,
              'quantity': 2,
              'variantMode': 'all',
              'variantIds': <int>[],
              'variants': <Map<String, dynamic>>[],
            },
          ],
        ),
      );
      final DiscountBundleRequirement selected = detail.bundleRequirements[0];
      expect(selected.isSelected, isTrue);
      expect(selected.variantIds, <int>[101, 102]);
      expect(selected.variants.map((v) => v.name), <String>['Large', 'Iced']);
      expect(selected.variants.last.isAvailable, isFalse);
      expect(detail.bundleRequirements[1].variantMode, 'all');
      expect(
        detail.toUpsertRequest().toJson()['bundleRequirements'],
        <Map<String, dynamic>>[
          <String, dynamic>{
            'productId': 11,
            'quantity': 1.0,
            'variantMode': 'selected',
            'variantIds': <int>[101, 102],
          },
          <String, dynamic>{
            'productId': 12,
            'quantity': 2.0,
            'variantMode': 'all',
            'variantIds': <int>[],
          },
        ],
      );
    });

    test(
      'a legacy response without variant fields means all and writes none',
      () {
        final DiscountDetail detail = DiscountDetail.fromJson(
          _detailJson(
            requirements: <Map<String, dynamic>>[
              <String, dynamic>{'productId': 11, 'quantity': 1},
            ],
          ),
        );
        final DiscountBundleRequirement requirement =
            detail.bundleRequirements.single;
        expect(requirement.variantMode, isNull);
        expect(requirement.isSelected, isFalse);
        expect(requirement.variantIds, isEmpty);
        // Omitted on write so the backend keeps whatever scope is saved.
        expect(requirement.toJson(), <String, dynamic>{
          'productId': 11,
          'quantity': 1.0,
        });
      },
    );

    test('all never writes variant ids, even if some were attached', () {
      const DiscountBundleRequirement requirement = DiscountBundleRequirement(
        productId: 11,
        quantity: 1,
        variantMode: 'all',
        variantIds: <int>[5],
      );
      expect(requirement.toJson()['variantIds'], isEmpty);
    });

    test('variant scope validation', () {
      DiscountBundleRequirement req(String? mode, List<int> ids) =>
          DiscountBundleRequirement(
            productId: 11,
            quantity: 1,
            variantMode: mode,
            variantIds: ids,
          );
      expect(req(null, const <int>[]).isVariantScopeValid, isTrue);
      expect(req('all', const <int>[]).isVariantScopeValid, isTrue);
      expect(req('all', const <int>[1]).isVariantScopeValid, isFalse);
      expect(req('selected', const <int>[1, 2]).isVariantScopeValid, isTrue);
      expect(req('selected', const <int>[]).isVariantScopeValid, isFalse);
      expect(req('selected', const <int>[1, 1]).isVariantScopeValid, isFalse);
      expect(req('selected', const <int>[0]).isVariantScopeValid, isFalse);
      expect(req('some', const <int>[1]).isVariantScopeValid, isFalse);
    });
  });

  group('Cafe discount policy settings', () {
    final Map<String, dynamic> legacy = <String, dynamic>{
      'automaticEnabled': false,
      'selectionStrategy': 'priority',
      'combinationMode': 'single',
      'orderDiscountBehavior': 'exclusive',
      'couponBehavior': 'exclusive',
      'manualBehavior': 'exclusive',
      'maximumTotalDiscountPercent': 12.5,
      'allowAutomaticSuppression': true,
      'version': 4,
      'engineReady': false,
    };

    test('parses the V3 policy next to the legacy fields', () {
      final SavedDiscountSettings saved =
          SavedDiscountSettings.fromJson(<String, dynamic>{
            ...legacy,
            'allowMultipleDiscounts': true,
            'stackingMode': 'same_item_allowed',
            'allowMultipleCoupons': true,
            'allowCouponWithConfigured': true,
            'allowOrderAfterItemDiscounts': true,
            'maximumDiscountsPerOrder': 4,
            'conflictResolution': 'priority',
          });
      expect(saved.policy.allowMultipleDiscounts, isTrue);
      expect(saved.policy.stackingMode, 'same_item_allowed');
      expect(saved.policy.allowMultipleCoupons, isTrue);
      expect(saved.policy.allowCouponWithConfigured, isTrue);
      expect(saved.policy.allowOrderAfterItemDiscounts, isTrue);
      expect(saved.policy.maximumDiscountsPerOrder, 4);
      expect(saved.policy.conflictResolution, 'priority');
      // The total-percent limit stays a single shared field.
      expect(saved.draft.maximumTotalDiscountPercent, '12.5');
      expect(saved.draft.selectionStrategy, 'priority');
      expect(saved.version, 4);
      expect(DiscountCafePolicy.fromJson(saved.policy.toJson()), saved.policy);
    });

    test(
      'an older backend without V3 fields reads today single-discount defaults',
      () {
        final SavedDiscountSettings saved = SavedDiscountSettings.fromJson(
          legacy,
        );
        expect(saved.policy, const DiscountCafePolicy());
        expect(saved.policy.allowMultipleDiscounts, isFalse);
        expect(saved.policy.stackingMode, 'different_items_only');
        expect(saved.policy.maximumDiscountsPerOrder, 1);
        expect(saved.policy.conflictResolution, 'best_saving');
      },
    );

    test(
      'unknown enum values and bad counts fall back to the safe defaults',
      () {
        final DiscountCafePolicy policy =
            DiscountCafePolicy.fromJson(<String, dynamic>{
              'stackingMode': 'overlap',
              'conflictResolution': 'lowest_saving',
              'maximumDiscountsPerOrder': '3',
              'allowMultipleDiscounts': 'yes',
            });
        expect(policy, const DiscountCafePolicy());
      },
    );

    test(
      'the existing screen payload is unchanged and carries no V3 fields',
      () {
        final Map<String, dynamic> body = SavedDiscountSettings.fromJson(
          legacy,
        ).draft.toJson(4);
        expect(body.keys.toSet(), <String>{
          'automaticEnabled',
          'selectionStrategy',
          'combinationMode',
          'orderDiscountBehavior',
          'couponBehavior',
          'manualBehavior',
          'maximumTotalDiscountPercent',
          'allowAutomaticSuppression',
          'expectedVersion',
        });
      },
    );
  });
}
