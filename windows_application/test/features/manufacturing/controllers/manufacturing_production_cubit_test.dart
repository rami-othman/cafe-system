import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/manufacturing/controllers/manufacturing_production_cubit.dart';
import 'package:windows_application/features/manufacturing/repositories/manufacturing_repository.dart';

/// Mirrors the fake-Dio pattern already used by
/// `manufacturing_repository_test.dart` / `manufacturing_cubit_test.dart`.
Dio _fakeDio(Response<dynamic> Function(RequestOptions options) onRequest) {
  final Dio dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        final Response<dynamic> response = onRequest(options);
        if (response.statusCode != null && response.statusCode! >= 400) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        handler.resolve(response);
      },
    ),
  );
  return dio;
}

void main() {
  test(
    'completion retries reuse keys and changed operating costs mint a new key',
    () async {
      final bodies = <Map<String, dynamic>>[];
      var key = 0;
      final dio = _fakeDio((options) {
        bodies.add(Map<String, dynamic>.from(options.data as Map));
        return Response<dynamic>(requestOptions: options, statusCode: 500);
      });
      final cubit = ManufacturingProductionCubit(
        repository: ManufacturingRepository(DioApiClient(dio: dio)),
        operationKeyGenerator: (_) => 'key-${++key}',
      );
      addTearDown(cubit.close);
      for (final amount in ['5.00', '5.00', '6.00']) {
        await cubit.completeDraft(
          draftId: 1,
          actualQty: '3',
          additionalCosts: [
            {'type': 'أجور', 'amount': amount},
          ],
        );
      }
      expect(bodies[0]['idempotencyKey'], bodies[1]['idempotencyKey']);
      expect(bodies[2]['idempotencyKey'], isNot(bodies[1]['idempotencyKey']));
      expect(bodies[2]['additionalCosts'], [
        {'type': 'أجور', 'amount': '6.00'},
      ]);
    },
  );
  group('ManufacturingProductionCubit.createDraft idempotency', () {
    test(
      'a retry after a failed attempt (same recipe/qty/warehouse) reuses the same idempotencyKey',
      () async {
        final List<String?> sentKeys = <String?>[];
        int attempt = 0;
        final Dio dio = _fakeDio((RequestOptions options) {
          if (options.path == 'manufacturing/production/drafts') {
            final Map<String, dynamic> body = Map<String, dynamic>.from(
              options.data as Map,
            );
            sentKeys.add(body['idempotencyKey'] as String?);
            attempt++;
            if (attempt == 1) {
              return Response<dynamic>(
                requestOptions: options,
                statusCode: 500,
              );
            }
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 201,
              data: <String, dynamic>{
                'data': <String, dynamic>{
                  'id': 900,
                  'recipeId': 4,
                  'warehouseId': 2,
                  'qty': '5.000',
                  'preview': <String, dynamic>{
                    'batchCost': 10.0,
                    'unitCost': 2.0,
                  },
                  'consumption': <Map<String, dynamic>>[],
                },
              },
            );
          }
          return Response<dynamic>(requestOptions: options, statusCode: 404);
        });
        final ManufacturingProductionCubit cubit = ManufacturingProductionCubit(
          repository: ManufacturingRepository(DioApiClient(dio: dio)),
        );
        addTearDown(cubit.close);

        final bool firstAttempt = await cubit.createDraft(
          recipeId: 4,
          qty: '5.000',
          warehouseId: 2,
        );
        expect(firstAttempt, isFalse);
        expect(cubit.state.error, isNotNull);

        final bool secondAttempt = await cubit.createDraft(
          recipeId: 4,
          qty: '5.000',
          warehouseId: 2,
        );
        expect(secondAttempt, isTrue);
        expect(cubit.state.draft?.id, 900);

        expect(sentKeys, hasLength(2));
        expect(sentKeys[0], isNotNull);
        expect(
          sentKeys[1],
          sentKeys[0],
          reason:
              'A retry of the exact same draft-creation request must reuse the '
              'first attempt\'s idempotency key, not mint a new one.',
        );
      },
    );

    test(
      'starting a genuinely new draft action (different qty) mints a new key',
      () async {
        final List<String?> sentKeys = <String?>[];
        final Dio dio = _fakeDio((RequestOptions options) {
          final Map<String, dynamic> body = Map<String, dynamic>.from(
            options.data as Map,
          );
          sentKeys.add(body['idempotencyKey'] as String?);
          return Response<dynamic>(requestOptions: options, statusCode: 500);
        });
        final ManufacturingProductionCubit cubit = ManufacturingProductionCubit(
          repository: ManufacturingRepository(DioApiClient(dio: dio)),
        );
        addTearDown(cubit.close);

        await cubit.createDraft(recipeId: 4, qty: '5.000', warehouseId: 2);
        await cubit.createDraft(recipeId: 4, qty: '9.000', warehouseId: 2);

        expect(sentKeys, hasLength(2));
        expect(sentKeys[0], isNot(sentKeys[1]));
      },
    );
  });

  group('ManufacturingProductionCubit.reverseOrder', () {
    test(
      'a PRODUCTION_NOT_REVERSIBLE conflict surfaces the backend Arabic message and does not mutate the loaded order',
      () async {
        const String arabicMessage =
            'لا يمكن عكس عملية التصنيع هذه لأن الناتج تم استهلاكه أو بيعه بالكامل.';
        final Dio dio = _fakeDio((RequestOptions options) {
          if (options.path == 'manufacturing/production/PR-1') {
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': <String, dynamic>{
                  'id': 'PR-1',
                  'recordId': 1,
                  'recipeId': 4,
                  'product': 'كيك',
                  'type': 'finished_good',
                  'warehouseId': 2,
                  'planned': '1.000',
                  'actual': '1.000',
                  'unit': 'piece',
                  'status': 'completed',
                  'soldQty': 1.0,
                  'materialsConsumed': <Map<String, dynamic>>[],
                },
              },
            );
          }
          if (options.path == 'manufacturing/production/PR-1/reverse') {
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 409,
              data: <String, dynamic>{
                'message': arabicMessage,
                'code': 'PRODUCTION_NOT_REVERSIBLE',
              },
            );
          }
          return Response<dynamic>(requestOptions: options, statusCode: 404);
        });
        final ManufacturingProductionCubit cubit = ManufacturingProductionCubit(
          repository: ManufacturingRepository(DioApiClient(dio: dio)),
        );
        addTearDown(cubit.close);

        await cubit.loadOrder('PR-1');
        expect(cubit.state.selected?.status, 'completed');

        final bool ok = await cubit.reverseOrder(
          idOrReference: 'PR-1',
          reason: 'اختبار',
        );

        expect(ok, isFalse);
        expect(cubit.state.error, arabicMessage);
        // The previously loaded order must be untouched by a failed reversal.
        expect(cubit.state.selected?.status, 'completed');
      },
    );
  });
}
