import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/manufacturing/controllers/manufacturing_cubit.dart';
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

Map<String, dynamic> _overviewEnvelope() => <String, dynamic>{
  'data': <String, dynamic>{
    'kpis': <String, dynamic>{
      'producedToday': 5,
      'productionCostToday': 20,
      'avgEfficiency': 100.0,
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

void main() {
  group('ManufacturingCubit.loadOverview', () {
    test('a successful response transitions loading -> loaded with no error', () async {
      final Dio dio = _fakeDio(
        (String path, Map<String, dynamic> query) => _overviewEnvelope(),
      );
      final ManufacturingCubit cubit = ManufacturingCubit(
        repository: ManufacturingRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.overview, isNull);

      await cubit.loadOverview();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.overview, isNotNull);
      expect(cubit.state.overview!.kpis.producedToday, '5');
    });

    test('a backend error transitions loading -> error instead of spinning forever', () async {
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) => null);
      final ManufacturingCubit cubit = ManufacturingCubit(
        repository: ManufacturingRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      await cubit.loadOverview();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.overview, isNull);
    });

    test('refresh() after a load supersedes a slow duplicate without leaking a stale result', () async {
      int callCount = 0;
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
        callCount++;
        return _overviewEnvelope();
      });
      final ManufacturingCubit cubit = ManufacturingCubit(
        repository: ManufacturingRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      final Future<void> first = cubit.loadOverview();
      final Future<void> second = cubit.refresh();
      await Future.wait(<Future<void>>[first, second]);

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.overview, isNotNull);
      expect(callCount, 2);
    });
  });
}
