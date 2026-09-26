import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/purchasing/controllers/purchasing_cubit.dart';
import 'package:windows_application/features/purchasing/repositories/purchasing_repository.dart';

void main() {
  test('a rejected receipt can be corrected before retry', () async {
    final dio = Dio();
    var creates = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/receipts')) {
            creates++;
            if (creates == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 422,
                    data: {'message': 'Invalid quantity'},
                  ),
                ),
              );
              return;
            }
            expect((options.data as Map)['quantity'], '4.000');
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'id': 7,
                  'supplierInvoiceId': 1,
                  'status': options.path.endsWith('/post') ? 'posted' : 'draft',
                },
              },
            ),
          );
        },
      ),
    );
    final cubit = PurchasingCubit(
      repository: PurchasingRepository(DioApiClient(dio: dio)),
    );
    addTearDown(cubit.close);
    await expectLater(
      cubit.receiveAndPost(1, {'quantity': '0'}),
      throwsA(anything),
    );
    expect(
      (await cubit.receiveAndPost(1, {'quantity': '4.000'})).status,
      'posted',
    );
    expect(creates, 2);
  });
  for (final failure in <String>[
    'create_response',
    'post_before_commit',
    'post_response',
  ]) {
    test(
      'receipt retry after $failure preserves one receipt and stock effect',
      () async {
        final dio = Dio();
        final createKeys = <String>{};
        final postKeys = <String>{};
        var failed = false;
        var stockEffects = 0;
        var receiptStatus = 'draft';
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'POST' &&
                  options.path.endsWith('/receipts')) {
                createKeys.add(
                  (options.data as Map)['idempotencyKey'] as String,
                );
                if (failure == 'create_response' && !failed) {
                  failed = true;
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.receiveTimeout,
                    ),
                  );
                  return;
                }
              } else if (options.path.endsWith('/post')) {
                postKeys.add((options.data as Map)['idempotencyKey'] as String);
                if (failure == 'post_before_commit' && !failed) {
                  failed = true;
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.connectionError,
                    ),
                  );
                  return;
                }
                if (receiptStatus != 'posted') stockEffects++;
                receiptStatus = 'posted';
                if (failure == 'post_response' && !failed) {
                  failed = true;
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.receiveTimeout,
                    ),
                  );
                  return;
                }
              }
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'data': <String, dynamic>{
                      'id': 7,
                      'receiptNumber': 'GRN-7',
                      'status': receiptStatus,
                      'supplierInvoiceId': 1,
                      'lineCount': 1,
                    },
                  },
                ),
              );
            },
          ),
        );
        final cubit = PurchasingCubit(
          repository: PurchasingRepository(DioApiClient(dio: dio)),
        );
        addTearDown(cubit.close);
        final payload = <String, dynamic>{
          'receiptDate': '2026-09-26',
          'lines': <dynamic>[
            <String, dynamic>{
              'supplierInvoiceLineId': 1,
              'quantity': '10.000',
              'warehouseId': 3,
            },
          ],
        };
        await expectLater(cubit.receiveAndPost(1, payload), throwsA(anything));
        final receipt = await cubit.receiveAndPost(1, payload);
        expect(receipt.status, 'posted');
        expect(createKeys, hasLength(1));
        expect(postKeys, hasLength(1));
        expect(stockEffects, 1);
      },
    );
  }
}
