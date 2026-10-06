import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import '../../integration_test/fixtures/discount_contract_probe.dart';
import '../features/pos/discount_engine_fixture.dart';

void main() {
  test('protocol assertion still rejects missing contract metadata', () {
    expect(
      () => verifyDiscountRequestContract(
        RequestOptions(path: 'orders/42/discount-state'),
      ),
      throwsA(isA<TestFailure>()),
    );
  });
  test(
    'asynchronous protocol assertion does not abort valid saved state',
    () async {
      final dio = Dio();
      final client = DioApiClient(dio: dio);
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            verifyDiscountRequestContract(r);
            paths.add(r.path);
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: {
                  'data': savedJson(
                    intent: {'source': 'configured_manual', 'discountId': 7},
                  ),
                },
              ),
            );
          },
        ),
      );
      // The HTTP completion runs outside a still-awaited widget pump zone.
      // Flutter's guarded expect here used to turn a valid read into D2_GENERIC.
      final barrier = Completer<void>();
      final widgetWork = TestAsyncUtils.guard(() => barrier.future);
      late final dynamic saved;
      try {
        saved = await PosRepository(apiClient: client).getDiscountState(42);
      } finally {
        barrier.complete();
        await widgetWork;
        dio.close();
      }
      expect(paths, ['orders/42/discount-state']);
      expect(saved.explicitIntent.discountId, 7);
      expect(saved.totals.total, '7.56');
      expect(saved.discounts.length, 2);
    },
  );
}
