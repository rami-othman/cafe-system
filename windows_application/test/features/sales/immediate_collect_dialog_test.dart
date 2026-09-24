import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/sales/views/sales_screens.dart';

/// C4 — the sales post-and-collect payment date must be explicit, not a
/// hidden `now()`/`_today()`. Direct-cash sales keep payment date == invoice
/// date (A3 semantics, unchanged); a registered customer's collection date
/// must be user-editable and default to today.
void main() {
  Dio buildDio() {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == 'finance/payment-methods') {
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'data': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 1,
                      'code': 'CASH',
                      'name': 'نقدي',
                      'type': 'cash',
                      'financialAccountId': 9,
                      'financialAccountCode': '1010',
                      'isActive': true,
                    },
                  ],
                  'meta': <String, dynamic>{
                    'currentPage': 1,
                    'lastPage': 1,
                    'total': 1,
                  },
                },
              ),
            );
          }
          if (options.path == 'finance/cash-source-options') {
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'cashSourceMode': 'shift',
                  'resolvedCashLocation': <String, dynamic>{
                    'id': 7,
                    'name': 'الصندوق',
                  },
                  'allowedCashLocations': <Map<String, dynamic>>[],
                },
              ),
            );
          }
          return handler.reject(
            DioException(
              requestOptions: options,
              message: 'unexpected path: ${options.path}',
            ),
          );
        },
      ),
    );
    return dio;
  }

  String today() {
    final DateTime d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  testWidgets(
    'registered-customer collection shows an editable payment-date field defaulting to today',
    (tester) async {
      final FinanceSetupRepository repository = FinanceSetupRepository(
        DioApiClient(dio: buildDio()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ImmediateCollectDialog(
              financeSetupRepository: repository,
              invoiceTotal: '100.00',
              branchId: 3,
              directSale: false,
              invoiceDate: '2026-09-01',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تاريخ الدفع'), findsOneWidget);
      expect(find.text(today()), findsOneWidget);
    },
  );

  testWidgets('direct-cash collection does not show a payment-date field', (
    tester,
  ) async {
    final FinanceSetupRepository repository = FinanceSetupRepository(
      DioApiClient(dio: buildDio()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ImmediateCollectDialog(
            financeSetupRepository: repository,
            invoiceTotal: '100.00',
            branchId: 3,
            directSale: true,
            invoiceDate: '2026-09-01',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تاريخ الدفع'), findsNothing);
  });
}
