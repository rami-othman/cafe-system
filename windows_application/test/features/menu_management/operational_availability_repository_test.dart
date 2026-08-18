import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/operational_availability/models/operational_availability_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  group('operational availability repository contract', () {
    test(
      'lists all Product pages with the actual endpoint and de-duplicates records',
      () async {
        final _RecordingBackend backend = _RecordingBackend();
        final BackendMenuCatalogRepository repository = backend.repository;

        final List<OperationalAvailabilityOverride> rows = await repository
            .listProductOperationalOverrides(11);

        expect(rows.map((item) => item.id), <int>[1, 2]);
        expect(rows.every((item) => item.productId == 11), isTrue);
        expect(
          backend.requests.take(2).map((item) => item.path),
          everyElement('admin/catalog/operational-availability'),
        );
        expect(backend.requests[0].query, <String, dynamic>{
          'level': 'product',
          'includeArchived': true,
          'perPage': 100,
          'page': 1,
        });
        expect(backend.requests[1].query['page'], 2);
      },
    );

    test(
      'uses exact Product and Variant mutation and clear routes without computed fields',
      () async {
        final _RecordingBackend backend = _RecordingBackend();
        final BackendMenuCatalogRepository repository = backend.repository;
        final OperationalAvailabilityDraft productDraft =
            OperationalAvailabilityDraft(
              branchId: 3,
              channel: 'all',
              status: OperationalAvailabilityStatus.temporarilyUnavailable,
              remainingQuantity: 0,
              unavailableUntil: DateTime.parse('2030-08-04T10:30:00'),
              reason: 'Machine service',
            );
        const OperationalAvailabilityDraft variantDraft =
            OperationalAvailabilityDraft(
              branchId: 3,
              channel: 'delivery',
              status: OperationalAvailabilityStatus.available,
              remainingQuantity: 2,
            );

        await repository.upsertProductOperationalOverride(11, productDraft);
        await repository.clearProductOperationalOverride(11, 3, 'all');
        await repository.upsertVariantOperationalOverride(12, variantDraft);
        await repository.clearVariantOperationalOverride(12, 3, 'delivery');

        expect(
          backend.requests.map((item) => '${item.method} ${item.path}'),
          <String>[
            'PUT admin/catalog/products/11/operational-availability',
            'DELETE admin/catalog/products/11/operational-availability',
            'PUT admin/catalog/product-variants/12/operational-availability',
            'DELETE admin/catalog/product-variants/12/operational-availability',
          ],
        );
        expect(backend.requests[0].data, <String, dynamic>{
          'branchId': 3,
          'channel': 'all',
          'status': 'temporarily_unavailable',
          'remainingQuantity': 0,
          'unavailableUntil': '2030-08-04T10:30:00',
          'reason': 'Machine service',
        });
        expect(backend.requests[1].query, <String, dynamic>{
          'branchId': 3,
          'channel': 'all',
        });
        expect(backend.requests[2].data, <String, dynamic>{
          'branchId': 3,
          'channel': 'delivery',
          'status': 'available',
          'remainingQuantity': 2,
        });
        for (final _Request request in backend.requests.where(
          (item) => item.data != null,
        )) {
          expect(request.data!.containsKey('tenantId'), isFalse);
          expect(request.data!.containsKey('branchName'), isFalse);
          expect(request.data!.containsKey('isExpired'), isFalse);
          expect(request.data!.containsKey('updatedAt'), isFalse);
        }
      },
    );

    test(
      'filters Variant listing by identity using the Variant level',
      () async {
        final _RecordingBackend backend = _RecordingBackend();
        final List<OperationalAvailabilityOverride> rows = await backend
            .repository
            .listVariantOperationalOverrides(12);

        expect(rows.map((item) => item.productVariantId), everyElement(12));
        expect(backend.requests.single.query['level'], 'variant');
        expect(backend.requests.single.query['includeArchived'], isTrue);
      },
    );

    test(
      'uses the authoritative product preview route for Product and Variant contexts',
      () async {
        final _RecordingBackend backend = _RecordingBackend();
        final BackendMenuCatalogRepository repository = backend.repository;

        final OperationalAvailabilityPreview product = await repository
            .previewProductOperationalAvailability(
              11,
              branchId: 3,
              channel: 'pos',
            );
        final OperationalAvailabilityPreview variant = await repository
            .previewVariantOperationalAvailability(
              11,
              12,
              branchId: 3,
              channel: 'delivery',
            );

        expect(product.isFallback, isTrue);
        expect(product.status, OperationalAvailabilityStatus.available);
        expect(variant.matchedLevel, OperationalAvailabilityLevel.variant);
        expect(
          backend.requests[0].path,
          'admin/catalog/products/11/operational-availability-preview',
        );
        expect(backend.requests[0].query, <String, dynamic>{
          'branchId': 3,
          'channel': 'pos',
        });
        expect(backend.requests[1].query, <String, dynamic>{
          'productVariantId': 12,
          'branchId': 3,
          'channel': 'delivery',
        });
        for (final _Request request in backend.requests) {
          expect(request.query.containsKey('tenantId'), isFalse);
          expect(request.query.containsKey('at'), isFalse);
        }
      },
    );
  });
}

class _RecordingBackend {
  _RecordingBackend() {
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1/'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: _respond));
    repository = BackendMenuCatalogRepository(DioApiClient(dio: dio));
  }

  late final BackendMenuCatalogRepository repository;
  final List<_Request> requests = <_Request>[];

  void _respond(RequestOptions options, RequestInterceptorHandler handler) {
    final Map<String, dynamic> query = Map<String, dynamic>.from(
      options.queryParameters,
    );
    final Map<String, dynamic>? data = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : null;
    requests.add(_Request(options.method, options.path, query, data));
    final dynamic body = switch (options.method) {
      'GET' when options.path.contains('operational-availability-preview') =>
        <String, dynamic>{'data': _preview(query)},
      'GET' => _page(query),
      'PUT' => <String, dynamic>{'data': _row(1)},
      _ => <String, dynamic>{
        'data': <String, dynamic>{'cleared': true},
      },
    };
    handler.resolve(
      Response<dynamic>(requestOptions: options, statusCode: 200, data: body),
    );
  }

  Map<String, dynamic> _page(Map<String, dynamic> query) {
    final String level = query['level'] as String;
    final int page = query['page'] as int;
    final List<Map<String, dynamic>> rows = level == 'product'
        ? page == 1
              ? <Map<String, dynamic>>[_row(1), _row(99, productId: 99)]
              : <Map<String, dynamic>>[_row(1), _row(2)]
        : <Map<String, dynamic>>[
            _row(4, variantId: 12),
            _row(98, variantId: 98),
          ];
    return <String, dynamic>{
      'data': rows,
      'meta': <String, dynamic>{'last_page': level == 'product' ? 2 : 1},
    };
  }

  Map<String, dynamic> _preview(
    Map<String, dynamic> query,
  ) => <String, dynamic>{
    'productId': 11,
    'productVariantId': query['productVariantId'],
    'branchId': query['branchId'],
    'channel': query['channel'],
    'isOperationallyAvailable': query['productVariantId'] == null,
    'status': query['productVariantId'] == null ? 'available' : 'sold_out',
    'matchedLevel': query['productVariantId'] == null ? null : 'variant',
    'matchedScope': query['productVariantId'] == null ? null : 'exact_channel',
    'matchedRecordId': query['productVariantId'] == null ? null : 12,
    'remainingQuantity': 0,
    'unavailableUntil': null,
    'reason': query['productVariantId'] == null
        ? 'no_operational_override'
        : 'Sold out',
  };
}

class _Request {
  const _Request(this.method, this.path, this.query, this.data);
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic>? data;
}

Map<String, dynamic> _row(int id, {int productId = 11, int? variantId}) =>
    <String, dynamic>{
      'id': id,
      'level': variantId == null ? 'product' : 'variant',
      'productId': productId,
      'productVariantId': variantId,
      'branch': <String, dynamic>{
        'id': 3,
        'name': 'Main',
        'timezone': 'Asia/Damascus',
      },
      'channel': 'all',
      'status': 'sold_out',
      'remainingQuantity': null,
      'unavailableUntil': null,
      'reason': null,
      'isExpired': false,
    };
