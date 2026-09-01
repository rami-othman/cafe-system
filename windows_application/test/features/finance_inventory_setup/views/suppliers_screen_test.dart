import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/suppliers_screen.dart';

void main() {
  testWidgets('loads real suppliers, renders AP KPI cards and outstanding balances', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter());

    expect(find.text('إجمالي المستحقات'), findsOneWidget);
    expect(find.text('مستحقات متأخرة'), findsOneWidget);
    expect(find.text('SUP-00001'), findsOneWidget);
    expect(find.text('Acme Roasters'), findsOneWidget);
    expect(find.text('800.00'), findsWidgets);
  });

  testWidgets('shows the empty state when there are no suppliers', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter(suppliers: const <Map<String, dynamic>>[]));

    expect(find.text('لا يوجد موردون مسجلون بعد.'), findsOneWidget);
  });

  testWidgets('shows an error message with retry when loading fails', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter(failSuppliers: true));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('blocks saving a new supplier with an empty name', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter());

    await tester.tap(find.text('إضافة مورد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('أدخل اسم المورد.'), findsOneWidget);
  });
}

Future<void> _pumpScreen(WidgetTester tester, {required _FakeRouter router}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

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
  final FinanceSetupRepository repository = FinanceSetupRepository(
    DioApiClient(dio: dio),
  );
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BlocProvider<FinanceSetupCubit>.value(
            value: cubit,
            child: const SuppliersScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeRouter {
  _FakeRouter({List<Map<String, dynamic>>? suppliers, this.failSuppliers = false})
    : _suppliers = suppliers ?? <Map<String, dynamic>>[_supplier()];

  final List<Map<String, dynamic>> _suppliers;
  final bool failSuppliers;

  static Map<String, dynamic> _supplier() => <String, dynamic>{
    'id': 1,
    'supplierNumber': 'SUP-00001',
    'name': 'Acme Roasters',
    'isActive': true,
    'outstandingBalance': '800.00',
    'overdueBalance': '200.00',
    'openInvoiceCount': 2,
    'lastInvoiceDate': '2026-08-20',
  };

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;

    if (path == 'finance/suppliers' && options.method == 'GET') {
      if (failSuppliers) {
        throw DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 500,
            data: <String, dynamic>{'message': 'Backend error.'},
          ),
          type: DioExceptionType.badResponse,
        );
      }
      return _ok(options, _suppliers);
    }
    if (path == 'finance/setup-status') {
      return _ok(options, <String, dynamic>{
        'systemAccountsReady': true,
        'centralWarehouseReady': true,
        'branchWarehouseCoverageReady': true,
        'financialSetupReady': true,
        'missingBranchWarehouses': <String>[],
        'totalPayables': '1000.00',
        'overduePayables': '200.00',
        'openSupplierInvoiceCount': 3,
        'activeSupplierCount': 1,
      });
    }

    throw DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{'message': 'Unhandled test route: $path'},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  Response<dynamic> _ok(RequestOptions options, dynamic data) => Response<dynamic>(
    requestOptions: options,
    statusCode: 200,
    data: <String, dynamic>{'data': data},
  );
}
