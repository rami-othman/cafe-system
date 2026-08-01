import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/availability/models/availability_models.dart';
import 'package:windows_application/features/menu_management/availability/schedule_summary.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  group('scheduled product availability models', () {
    test(
      'repository uses the shared Product endpoints and complete payload',
      () async {
        final List<RequestOptions> requests = <RequestOptions>[];
        final repository = BackendMenuCatalogRepository(
          _client((options) {
            requests.add(options);
            final bool preview = options.path.endsWith('availability-preview');
            return Response<dynamic>(
              requestOptions: options,
              data: <String, dynamic>{
                'data': preview
                    ? <String, dynamic>{
                        'isScheduledAvailable': true,
                        'reason': 'matched_rule',
                        'matchedRuleId': 2,
                        'matchedScope': 'branch_channel',
                        'matchedLevel': 'variant',
                        'productVariantId': 12,
                        'branchId': 1,
                        'channel': 'pos',
                        'timezone': 'Asia/Damascus',
                      }
                    : <String, dynamic>{
                        'productId': 11,
                        'rules': const <Map<String, dynamic>>[],
                      },
              },
            );
          }),
        );
        const product = AvailabilityRuleDraft(
          productVariantId: null,
          branchId: null,
          channel: null,
          dayOfWeek: 1,
          startTime: '07:00',
          endTime: '12:00',
          startDate: null,
          endDate: null,
          priority: 0,
          isActive: true,
        );
        const variant = AvailabilityRuleDraft(
          productVariantId: 12,
          branchId: 1,
          channel: 'pos',
          dayOfWeek: 2,
          startTime: '18:00',
          endTime: '02:00',
          startDate: '2026-08-01',
          endDate: '2026-08-31',
          priority: 4,
          isActive: false,
        );

        await repository.listProductAvailabilityRules(11);
        await repository.syncProductAvailabilityRules(
          11,
          <AvailabilityRuleDraft>[product, variant],
        );
        await repository.previewProductAvailability(
          11,
          variantId: 12,
          branchId: 1,
          channel: 'pos',
          dateTime: '2026-08-04T10:00:00',
        );

        expect(requests.map((item) => item.path), <String>[
          'admin/catalog/products/11/availability-rules',
          'admin/catalog/products/11/availability-rules',
          'admin/catalog/products/11/availability-preview',
        ]);
        expect(requests[1].data, <String, dynamic>{
          'rules': <Map<String, dynamic>>[product.toJson(), variant.toJson()],
        });
        expect(requests[2].queryParameters, <String, dynamic>{
          'productVariantId': 12,
          'branchId': 1,
          'channel': 'pos',
          'dateTime': '2026-08-04T10:00:00',
        });
        expect(
          (requests[1].data as Map<String, dynamic>)['rules'][1].containsKey(
            'id',
          ),
          isFalse,
        );
        expect(
          (requests[1].data as Map<String, dynamic>)['rules'][1].containsKey(
            'matchedRuleId',
          ),
          isFalse,
        );
      },
    );

    test(
      'parses a variant branch and channel rule from the backend resource',
      () {
        final rule = AvailabilityRule.fromJson(<String, dynamic>{
          'id': 8,
          'productVariantId': 12,
          'branchId': 1,
          'channel': 'pos',
          'dayOfWeek': 1,
          'startTime': '18:00',
          'endTime': '02:00',
          'startDate': '2026-08-01',
          'endDate': '2026-08-31',
          'priority': 7,
          'isActive': true,
        });
        expect(rule.scope, AvailabilityScope.branchChannel);
        expect(rule.isOvernight, isTrue);
        expect(rule.toDraft().toJson(), isNot(contains('id')));
      },
    );

    test('serializes the four real backend scopes', () {
      AvailabilityRuleDraft rule({int? branchId, String? channel}) =>
          AvailabilityRuleDraft(
            productVariantId: null,
            branchId: branchId,
            channel: channel,
            dayOfWeek: null,
            startTime: null,
            endTime: null,
            startDate: null,
            endDate: null,
            priority: 0,
            isActive: true,
          );
      expect(rule().scope, AvailabilityScope.global);
      expect(rule(branchId: 1).scope, AvailabilityScope.branch);
      expect(rule(channel: 'delivery').scope, AvailabilityScope.channel);
      expect(
        rule(branchId: 1, channel: 'delivery').scope,
        AvailabilityScope.branchChannel,
      );
      expect(
        rule(branchId: 1).toJson().keys,
        containsAll(<String>['branchId', 'channel', 'isActive']),
      );
    });

    test(
      'parses the authoritative preview response and preserves reason code',
      () {
        final preview = AvailabilityPreview.fromJson(<String, dynamic>{
          'isScheduledAvailable': false,
          'reason': 'outside_schedule',
          'matchedRuleId': null,
          'matchedScope': 'branch',
          'matchedLevel': 'variant',
          'productVariantId': 12,
          'branchId': 1,
          'channel': 'pos',
          'timezone': 'Asia/Damascus',
        });
        expect(preview.statusLabel, 'Outside Schedule');
        expect(preview.timezone, 'Asia/Damascus');
      },
    );

    test('summarizes overnight weekly and date-bound rules', () {
      const rule = AvailabilityRuleDraft(
        productVariantId: null,
        branchId: null,
        channel: null,
        dayOfWeek: 1,
        startTime: '18:00',
        endTime: '02:00',
        startDate: '2026-08-01',
        endDate: '2026-08-31',
        priority: 0,
        isActive: true,
      );
      expect(scheduleSummary(rule), contains('Mon'));
      expect(scheduleSummary(rule), contains('Overnight'));
      expect(scheduleSummary(rule), contains('Aug'));
    });
  });
}

DioApiClient _client(Response<dynamic> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(responder(options)),
    ),
  );
  return DioApiClient(dio: dio);
}
