import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';

void main() {
  late _FinanceRouter router;
  late FinanceSetupRepository repository;

  setUp(() {
    router = _FinanceRouter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          try {
            handler.resolve(router.respond(options));
          } on DioException catch (error) {
            handler.reject(error);
          }
        },
      ),
    );
    repository = FinanceSetupRepository(DioApiClient(dio: dio));
  });

  test('parses the cash location detail contract', () async {
    final location = await repository.getFinancialLocation('cash', 1);

    expect(location.id, 1);
    expect(location.kind, 'cash');
    expect(location.financialAccountCode, '1010');
    expect(router.paths.single, 'finance/cash-accounts/1');
  });

  test('parses the bank location detail contract', () async {
    final location = await repository.getFinancialLocation('bank', 2);

    expect(location.id, 2);
    expect(location.kind, 'bank');
    expect(location.bankName, 'Bank 618');
    expect(router.paths.single, 'finance/bank-accounts/2');
  });

  test(
    'parses location, transactions, and an empty transaction list',
    () async {
      final cash = await repository.getFinancialLocationTransactions('cash', 1);
      final bank = await repository.getFinancialLocationTransactions('bank', 2);
      final empty = await repository.getFinancialLocationTransactions(
        'cash',
        3,
      );

      expect(cash.location.kind, 'cash');
      expect(cash.transactions.single['reference'], 'JE-1');
      expect(bank.location.kind, 'bank');
      expect(bank.transactions.single['credit'], '50.00');
      expect(empty.transactions, isEmpty);
      expect(router.paths, <String>[
        'finance/cash-accounts/1/transactions',
        'finance/bank-accounts/2/transactions',
        'finance/cash-accounts/3/transactions',
      ]);
    },
  );

  test('preserves API errors and parses standard page metadata', () async {
    await expectLater(
      repository.getFinancialLocation('cash', 404),
      throwsA(isA<ApiException>()),
    );

    final page = await repository.getFinancePage(
      'finance/accounting-periods',
      queryParameters: const <String, dynamic>{'page': 2, 'perPage': 10},
    );
    expect(page.items.single['name'], 'February 2026');
    expect(page.meta.currentPage, 2);
    expect(page.meta.perPage, 10);
    expect(page.meta.total, 12);
    expect(page.meta.lastPage, 2);
  });
}

class _FinanceRouter {
  final List<String> paths = <String>[];

  Response<dynamic> respond(RequestOptions options) {
    paths.add(options.path);
    final String path = options.path;
    if (path == 'finance/accounting-periods') {
      return _response(options, <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'id': 12, 'name': 'February 2026'},
        ],
        'meta': <String, dynamic>{
          'currentPage': 2,
          'perPage': 10,
          'total': 12,
          'lastPage': 2,
        },
      });
    }
    if (path.endsWith('/404')) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: _response(options, <String, dynamic>{
          'message': 'Not found',
        }, 404),
      );
    }
    if (path.endsWith('/transactions')) {
      final bool bank = path.contains('bank-accounts');
      final bool empty = path.contains('/3/');
      return _response(options, <String, dynamic>{
        'data': <String, dynamic>{
          'location': _location(
            bank ? 2 : (empty ? 3 : 1),
            bank ? 'bank' : 'cash',
          ),
          'transactions': empty
              ? <Map<String, dynamic>>[]
              : <Map<String, dynamic>>[
                  <String, dynamic>{
                    'reference': bank ? 'BNK-1' : 'JE-1',
                    'debit': bank ? '0.00' : '100.00',
                    'credit': bank ? '50.00' : '0.00',
                  },
                ],
        },
      });
    }
    final bool bank = path.contains('bank-accounts');
    return _response(options, <String, dynamic>{
      'data': _location(bank ? 2 : 1, bank ? 'bank' : 'cash'),
    });
  }

  Response<dynamic> _response(
    RequestOptions options,
    dynamic data, [
    int statusCode = 200,
  ]) => Response<dynamic>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
  );

  Map<String, dynamic> _location(int id, String kind) => <String, dynamic>{
    'id': id,
    'code': kind == 'bank' ? 'BANK-618' : 'CASH-618',
    'name': kind == 'bank' ? 'Bank account' : 'Cash drawer',
    'kind': kind,
    'type': kind == 'bank' ? 'bank' : 'cash_drawer',
    'financialAccountId': kind == 'bank' ? 1020 : 1010,
    'financialAccountCode': kind == 'bank' ? '1020' : '1010',
    'bankName': kind == 'bank' ? 'Bank 618' : null,
    'balance': '100.00',
    'todayIncoming': '100.00',
    'todayOutgoing': '0.00',
    'isActive': true,
  };
}
