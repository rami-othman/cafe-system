import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/recipes/models/recipe_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  test('product and variant recipe routes use the catalog contract', () async {
    final requests = <RequestOptions>[];
    final repository = _repository(requests);
    await repository.getProductRecipe(2);
    await repository.saveProductRecipe(2, const <RecipeComponent>[]);
    await repository.deleteProductRecipe(2);
    await repository.deleteVariantRecipe(7);
    await repository.resolveVariantRecipe(7, const <Map<String, dynamic>>[]);
    expect(requests.map((r) => '${r.method} ${r.path}'), <String>[
      'GET admin/catalog/products/2/recipe',
      'PUT admin/catalog/products/2/recipe',
      'DELETE admin/catalog/products/2/recipe',
      'DELETE admin/catalog/product-variants/7/recipe',
      'POST admin/catalog/product-variants/7/recipe/resolve',
    ]);
  });
}

BackendMenuCatalogRepository _repository(List<RequestOptions> requests) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: <String, dynamic>{
                'data': <String, dynamic>{
                  'productId': 2,
                  'variantId': 7,
                  'components': <Object>[],
                },
              },
            ),
          );
        },
      ),
    );
  return BackendMenuCatalogRepository(DioApiClient(dio: dio));
}
