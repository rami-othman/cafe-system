import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/manufacturing/controllers/manufacturing_recipe_cubit.dart';
import 'package:windows_application/features/manufacturing/repositories/manufacturing_repository.dart';

Dio _fakeDio(
  Map<String, dynamic>? Function(String path, Map<String, dynamic> query)
  onPath,
) {
  final Dio dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        final Map<String, dynamic> query = Map<String, dynamic>.from(
          options.queryParameters,
        );
        final Map<String, dynamic>? data = onPath(options.path, query);
        if (data == null) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 500,
              ),
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        handler.resolve(
          Response<dynamic>(requestOptions: options, statusCode: 200, data: data),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('ManufacturingRecipeCubit.loadRecipes', () {
    test('a successful response populates the recipe list without an error', () async {
      final Dio dio = _fakeDio(
        (String path, Map<String, dynamic> query) => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'productItemId': 10,
              'name': 'لاتيه',
              'type': 'finished_good',
              'status': 'active',
              'yield': '1',
              'yieldUnit': 'piece',
              'version': 1,
            },
          ],
        },
      );
      final DioApiClient api = DioApiClient(dio: dio);
      final ManufacturingRecipeCubit cubit = ManufacturingRecipeCubit(
        repository: ManufacturingRepository(api),
        inventoryRepository: InventoryRepository(api),
      );
      addTearDown(cubit.close);

      await cubit.loadRecipes();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.recipes, hasLength(1));
      expect(cubit.state.recipes.single.name, 'لاتيه');
    });

    test('a backend failure surfaces an error instead of leaving a stale list silently', () async {
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) => null);
      final DioApiClient api = DioApiClient(dio: dio);
      final ManufacturingRecipeCubit cubit = ManufacturingRecipeCubit(
        repository: ManufacturingRepository(api),
        inventoryRepository: InventoryRepository(api),
      );
      addTearDown(cubit.close);

      await cubit.loadRecipes();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.recipes, isEmpty);
    });
  });
}
