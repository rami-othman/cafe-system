import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';

void main() {
  test('validation parsing preserves backend severities and unknown codes', () {
    final result = MenuValidationResult.fromJson(<String, dynamic>{
      'isValid': false,
      'errorCount': 1,
      'warningCount': 1,
      'informationCount': 1,
      'errors': <Map<String, dynamic>>[_issue('error', 'MENU_ARCHIVED')],
      'warnings': <Map<String, dynamic>>[_issue('warning', 'FUTURE_CODE')],
      'information': <Map<String, dynamic>>[_issue('information', 'DETAIL')],
    });
    expect(result.canPublish, isFalse);
    expect(result.errors.single.placementId, 41);
    expect(result.warnings.single.code, 'FUTURE_CODE');
    expect(validationSeverity('future'), ValidationSeverity.unknown);
  });

  test(
    'resolved preview parses price, distinct availability, and modifiers',
    () {
      final preview = ResolvedPreview.fromJson(<String, dynamic>{
        'canPublish': false,
        'context': <String, dynamic>{
          'timezone': 'Asia/Damascus',
          'evaluatedAt': '2026-08-01T10:00:00+03:00',
        },
        'menus': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 10,
            'name': 'Main',
            'priority': 2,
            'isAssigned': true,
            'isScheduledAvailable': true,
            'scheduleReason': 'matched_rule',
            'sections': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Coffee',
                'sortOrder': 0,
                'products': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'productId': 11,
                    'name': 'Latte',
                    'isVisible': true,
                    'isScheduledAvailable': true,
                    'isOperationallyAvailable': false,
                    'isSellable': false,
                    'unavailabilityReasons': <String>['variant_sold_out'],
                    'variants': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'name': 'Regular',
                        'effectivePrice': 4.5,
                        'matchedPriceScope': 'branch_channel',
                        'isDefault': true,
                        'isScheduledAvailable': true,
                        'isOperationallyAvailable': false,
                        'isSellable': false,
                        'unavailabilityReasons': <String>['variant_sold_out'],
                      },
                    ],
                    'modifierGroups': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'name': 'Milk',
                        'isRequired': true,
                        'minSelections': 1,
                        'maxSelections': 1,
                        'allowQuantity': false,
                        'options': <Map<String, dynamic>>[
                          <String, dynamic>{
                            'name': 'Oat',
                            'priceDelta': 0.5,
                            'isAvailable': true,
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      });
      final product = preview.menus.single.sections.single.products.single;
      expect(preview.timezone, 'Asia/Damascus');
      expect(product.isScheduledAvailable, isTrue);
      expect(product.isOperationallyAvailable, isFalse);
      expect(product.variants.single.effectivePrice, 4.5);
      expect(product.modifiers.single.options.single.priceDelta, 0.5);
    },
  );

  test('repository uses exact menu and collection review endpoints', () async {
    final requests = <RequestOptions>[];
    final repository = BackendMenuCatalogRepository(
      _client((options) {
        requests.add(options);
        return Response<dynamic>(
          requestOptions: options,
          data: <String, dynamic>{
            'data': options.path.endsWith('validate')
                ? _validationJson()
                : _previewJson(),
          },
        );
      }),
    );
    const context = ReviewContext(
      branchId: 1,
      channel: 'pos',
      menuId: 10,
      language: 'ar',
      includeHidden: true,
      includeUnavailable: false,
    );
    await repository.validateMenu(10, context);
    await repository.validateMenuCollection(context);
    await repository.previewMenu(10, context);
    await repository.previewMenuCollection(context);
    expect(requests.map((request) => request.path), <String>[
      'admin/menus/10/validate',
      'admin/menu-management/validate',
      'admin/menus/10/preview',
      'admin/menu-management/preview',
    ]);
    expect(requests[0].data, <String, dynamic>{
      'branchId': 1,
      'channel': 'pos',
    });
    expect(requests[1].data, <String, dynamic>{
      'branchId': 1,
      'channel': 'pos',
    });
    expect(requests[2].data, <String, dynamic>{
      'branchId': 1,
      'channel': 'pos',
      'language': 'ar',
      'includeHidden': true,
      'includeUnavailable': false,
    });
    expect(
      (requests[2].data as Map<String, dynamic>).containsKey('tenantId'),
      isFalse,
    );
    expect(
      (requests[2].data as Map<String, dynamic>).containsKey('at'),
      isFalse,
    );
  });
}

Map<String, dynamic> _issue(String severity, String code) => <String, dynamic>{
  'severity': severity,
  'code': code,
  'message': 'Message',
  'entityType': 'placement',
  'entityId': 41,
  'menuId': 10,
  'sectionId': 12,
  'placementId': 41,
  'metadata': <String, dynamic>{'status': 'sold_out'},
};
Map<String, dynamic> _validationJson() => <String, dynamic>{
  'isValid': true,
  'errorCount': 0,
  'warningCount': 0,
  'informationCount': 0,
  'errors': const <Object>[],
  'warnings': const <Object>[],
  'information': const <Object>[],
};
Map<String, dynamic> _previewJson() => <String, dynamic>{
  'canPublish': true,
  'context': <String, dynamic>{
    'timezone': 'Asia/Damascus',
    'evaluatedAt': '2026-08-01T10:00:00+03:00',
  },
  'menus': const <Object>[],
};
DioApiClient _client(Response<dynamic> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(responder(options)),
    ),
  );
  return DioApiClient(dio: dio);
}
