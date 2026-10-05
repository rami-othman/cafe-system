import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  test(
    'recipe material catalog retains one stable entry per material ID',
    () async {
      final BackendMenuCatalogRepository repository = _repository(
        (_) => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            _materialJson(id: 1, name: 'Beans'),
            _materialJson(id: 1, name: 'Beans duplicate'),
            _materialJson(id: 2, name: 'Milk'),
          ],
        },
      );

      final materials = await repository.listRecipeMaterials();

      expect(materials.map((material) => material.id), <int>[1, 2]);
      expect(materials.first.name, 'Beans');
    },
  );

  test('recipe material catalog requests all statuses when required', () async {
    late RequestOptions request;
    final BackendMenuCatalogRepository repository = _repository((options) {
      request = options;
      return <String, dynamic>{'data': <Map<String, dynamic>>[]};
    });

    await repository.listRecipeMaterials(includeUnavailable: true);

    expect(request.queryParameters, <String, dynamic>{'status': 'all'});
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

Map<String, dynamic> _materialJson({required int id, required String name}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'unitCode': 'g',
      'allowedRecipeUnits': <String>['g'],
      'configurationAvailable': true,
    };
