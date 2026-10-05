import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/manufacturing/repositories/manufacturing_repository.dart';

/// Mirrors the fake-Dio pattern used by the Inventory repository/cubit tests
/// (see test/features/inventory/controllers/inventory_items_cubit_test.dart):
/// requests never touch the network, and [onPath] decides the JSON body (or
/// a 500 rejection when it returns null).
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
  group('ManufacturingRepository.getOverview', () {
    test('requests the flat {data:...} overview endpoint and parses it', () async {
      String? requestedPath;
      Map<String, dynamic>? requestedQuery;
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
        requestedPath = path;
        requestedQuery = query;
        return <String, dynamic>{
          'data': <String, dynamic>{
            'kpis': <String, dynamic>{
              'producedToday': 10,
              'productionCostToday': 50,
              'avgEfficiency': 88.0,
              'wasteToday': 0,
              'attentionCount': 0,
              'expiringCount': 0,
            },
            'recent': <Map<String, dynamic>>[],
            'attention': <Map<String, dynamic>>[],
            'expiring': <Map<String, dynamic>>[],
            'topCost': <Map<String, dynamic>>[],
          },
        };
      });
      final ManufacturingRepository repository = ManufacturingRepository(
        DioApiClient(dio: dio),
      );

      final overview = await repository.getOverview(warehouseId: 3);

      expect(requestedPath, 'manufacturing/overview');
      expect(requestedQuery?['warehouseId'], 3);
      expect(overview.kpis.producedToday, '10');
      expect(overview.kpis.avgEfficiency, '88.0');
    });

    test('a 500 response surfaces as an ApiException, not a raw crash', () async {
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) => null);
      final ManufacturingRepository repository = ManufacturingRepository(
        DioApiClient(dio: dio),
      );

      await expectLater(
        repository.getOverview(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
