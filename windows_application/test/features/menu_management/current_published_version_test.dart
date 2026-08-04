import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';

void main() {
  test(
    'collection publishing posts only the supported Branch and Channel fields',
    () async {
      late RequestOptions request;
      final BackendMenuCatalogRepository repository = _repository((options) {
        request = options;
        return <String, dynamic>{'data': _publicationJson()};
      });

      await repository.publishMenuScope(
        const ReviewContext(branchId: 7, channel: 'online'),
      );

      expect(request.method, 'POST');
      expect(request.path, endsWith('admin/menu-management/publish'));
      expect(request.data, <String, dynamic>{
        'branchId': 7,
        'channel': 'online',
      });
    },
  );

  test(
    'single Menu publishing submits exactly one supported menu ID',
    () async {
      late RequestOptions request;
      final BackendMenuCatalogRepository repository = _repository((options) {
        request = options;
        return <String, dynamic>{'data': _publicationJson()};
      });

      await repository.publishMenuScope(
        const ReviewContext(branchId: 7, channel: 'pos', menuId: 11),
      );

      expect(request.data, <String, dynamic>{
        'branchId': 7,
        'channel': 'pos',
        'menuIds': <int>[11],
      });
    },
  );

  test(
    'current Version gets metadata only and accepts no current Version',
    () async {
      late RequestOptions request;
      final BackendMenuCatalogRepository repository = _repository((options) {
        request = options;
        return <String, dynamic>{'data': null};
      });

      final PublishedMenuVersion? result = await repository
          .getCurrentPublishedVersion(
            const ReviewContext(branchId: 7, channel: 'pos'),
          );

      expect(result, isNull);
      expect(request.method, 'GET');
      expect(request.path, endsWith('admin/menu-management/current-version'));
      expect(request.queryParameters, <String, dynamic>{
        'branchId': 7,
        'channel': 'pos',
      });
    },
  );

  test(
    'current Version parses null optional metadata without snapshot payload',
    () async {
      final BackendMenuCatalogRepository repository = _repository(
        (_) => <String, dynamic>{
          'data': <String, dynamic>{
            'id': 9,
            'versionNumber': 4,
            'checksum': 'abc',
            'status': 'future_status',
            'branchId': 7,
            'channel': 'pos',
            'publishedAt': null,
            'publicationId': null,
            'payloadJson': <String, dynamic>{'mustNot': 'be used'},
          },
        },
      );

      final PublishedMenuVersion? version = await repository
          .getCurrentPublishedVersion(
            const ReviewContext(branchId: 7, channel: 'pos'),
          );

      expect(version?.status, 'future_status');
      expect(version?.publishedAt, isEmpty);
      expect(version?.publicationId, isNull);
    },
  );

  test('Laravel validation errors are mapped safely', () async {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 422,
                data: <String, dynamic>{
                  'message': 'The given data was invalid.',
                  'errors': <String, dynamic>{
                    'publish': <String>['Menu validation failed.'],
                  },
                },
              ),
            ),
          ),
        ),
      );
    final BackendMenuCatalogRepository repository =
        BackendMenuCatalogRepository(DioApiClient(dio: dio));

    await expectLater(
      repository.publishMenuScope(
        const ReviewContext(branchId: 7, channel: 'pos'),
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status code', 422)
            .having(
              (error) => error.validationErrors?['publish']?.single,
              'publish error',
              'Menu validation failed.',
            ),
      ),
    );
  });
}

BackendMenuCatalogRepository _repository(
  Map<String, dynamic> Function(RequestOptions options) responder,
) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<dynamic>(requestOptions: options, data: responder(options)),
        ),
      ),
    );
  return BackendMenuCatalogRepository(DioApiClient(dio: dio));
}

Map<String, dynamic> _publicationJson() => <String, dynamic>{
  'published': true,
  'noChanges': false,
  'publicationId': 31,
  'version': <String, dynamic>{
    'id': 9,
    'versionNumber': 4,
    'checksum': 'abc',
    'status': 'current',
    'publishedAt': '2026-08-02T10:00:00+03:00',
  },
  'validation': <String, dynamic>{
    'isValid': true,
    'errorCount': 0,
    'warningCount': 0,
    'informationCount': 0,
  },
};
