import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/shift/models/shift_models.dart';
import 'package:windows_application/features/shift/repositories/shift_repository.dart';

void main() {
  test(
    'API drawer keeps customer settlements and authoritative expected cash',
    () async {
      final dio = Dio();
      final api = DioApiClient(dio: dio);
      final requests = <RequestOptions>[];
      final snapshot = <String, dynamic>{
        'identity': {
          'id': 7,
          'shiftNumber': 'SH-7',
          'openedAt': '2026-09-25T08:00:00Z',
        },
        'sales': {'grossSales': '100.00', 'discounts': '10.00'},
        'drawer': {
          'openingFloat': '100.00',
          'cashSales': '90.00',
          'customerPayments': '30.00',
          'customerRefunds': '5.00',
          'expectedCash': '215.00',
        },
      };
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': options.method == 'POST'
                      ? {
                          'snapshot': snapshot,
                          'cash': {
                            'expected': '215.00',
                            'actual': '215.00',
                            'difference': '0.00',
                          },
                          'closedAt': '2026-09-26T20:59:59Z',
                          'closedBy': 'Cashier',
                          'reportNumber': 'RPT-7',
                        }
                      : snapshot,
                },
              ),
            );
          },
        ),
      );
      final repository = ShiftRepository(apiClient: api);
      final loaded = (await repository.loadOpenShift())!;
      expect(loaded.drawer.expected, 215);
      expect(loaded.drawer.customerPayments, 30);
      expect(loaded.drawer.customerRefunds, 5);
      expect(loaded.sales.netSales, 90);
      final closed = await repository.closeShift(
        ShiftClosingResult(
          snapshot: loaded,
          cash: const CashCountResult(expected: 215, actual: 215),
          closingNotes: '',
          closedAt: DateTime(2026, 9, 27),
          closingDate: DateTime(2026, 9, 26),
          closedBy: 'Cashier',
          reportNumber: 'RPT-7',
        ),
      );
      expect((requests.last.data as Map)['closingDate'], '2026-09-26');
      expect(closed.closedAt.toUtc(), DateTime.utc(2026, 9, 26, 20, 59, 59));
    },
  );

  test(
    'legacy drawer fallback includes customer settlements without subtracting sales discounts twice',
    () {
      const drawer = CashDrawerSnapshot(
        openingFloat: 100,
        cashSales: 90,
        cashRefunds: 0,
        withdrawals: 40,
        deposits: 40,
        expenses: 0,
        customerPayments: 30,
        customerRefunds: 5,
        movements: [],
      );
      expect(drawer.expected, 215);
    },
  );
}
