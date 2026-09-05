import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/supplier_profile_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/suppliers_screen.dart';

void main() {
  testWidgets('loads real suppliers, renders AP KPI cards and outstanding balances', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter());

    expect(find.text('إجمالي المستحقات'), findsOneWidget);
    expect(find.text('متأخر السداد'), findsOneWidget);
    expect(find.text('الموردون النشطون'), findsOneWidget);
    expect(find.text('متوسط مهلة السداد'), findsOneWidget);
    expect(find.text('SUP-00001'), findsOneWidget);
    expect(find.text('Acme Roasters'), findsOneWidget);
    expect(find.text('800.00'), findsWidgets);
    // Active/inactive is not a workflow status; must not read the FinanceStatusBadge label.
    expect(find.text('نشط'), findsOneWidget);
    expect(find.text('مكتمل'), findsNothing);
  });

  testWidgets('shows the empty state when there are no suppliers', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter(suppliers: const <Map<String, dynamic>>[]));

    expect(find.text('لا يوجد موردون مسجلون بعد'), findsOneWidget);
  });

  testWidgets('shows an error message with retry when loading fails', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter(failSuppliers: true));

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

  testWidgets('tapping a supplier row navigates to its profile route', (
    WidgetTester tester,
  ) async {
    final _FakeRouter fake = _FakeRouter();
    final GoRouter router = GoRouter(
      initialLocation: '/finance/suppliers',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/suppliers',
          builder: (_, _) => _wired(fake, const SuppliersScreen()),
        ),
        GoRoute(
          path: '/finance/suppliers/:id',
          builder: (_, GoRouterState state) =>
              Scaffold(body: Text('profile-route-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Acme Roasters'));
    await tester.pumpAndSettle();

    expect(find.text('profile-route-1'), findsOneWidget);
  });

  testWidgets('opening the list with ?invoiceId resolves the supplier and redirects to its profile', (
    WidgetTester tester,
  ) async {
    final _FakeRouter fake = _FakeRouter();
    final GoRouter router = GoRouter(
      initialLocation: '/finance/suppliers?invoiceId=10',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/suppliers',
          builder: (_, _) => _wired(fake, const SuppliersScreen()),
        ),
        GoRoute(
          path: '/finance/suppliers/:id',
          builder: (_, GoRouterState state) => _wired(
            fake,
            SupplierProfileScreen(
              supplierId: int.parse(state.pathParameters['id']!),
              openInvoiceId: int.tryParse(state.uri.queryParameters['openInvoice'] ?? ''),
            ),
          ),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Resolved supplier 1 from invoice 10 and auto-opened the invoice detail dialog.
    expect(find.text('فاتورة مورد'), findsOneWidget);
    expect(find.text('AP-000010'), findsWidgets);
  });
}

Widget _wired(_FakeRouter fake, Widget child) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        try {
          handler.resolve(fake.respond(options));
        } on DioException catch (error) {
          handler.reject(error);
        }
      },
    ),
  );
  final FinanceSetupRepository repository = FinanceSetupRepository(DioApiClient(dio: dio));
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);
  return Scaffold(
    body: BlocProvider<FinanceSetupCubit>.value(value: cubit, child: child),
  );
}

Future<void> _pumpScreen(WidgetTester tester, {required _FakeRouter router}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: _wired(router, const SuppliersScreen()),
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
    'paymentTermsDays': 30,
    'outstandingBalance': '800.00',
    'overdueBalance': '200.00',
    'openInvoiceCount': 2,
    'lastInvoiceDate': '2026-08-20',
    'allowedActions': <String>['edit', 'changeStatus'],
  };

  static Map<String, dynamic> _invoice() => <String, dynamic>{
    'id': 10,
    'internalReference': 'AP-000010',
    'invoiceNumber': 'INV-777',
    'supplierId': 1,
    'supplierName': 'Acme Roasters',
    'invoiceDate': '2026-08-01',
    'dueDate': '2026-09-01',
    'invoiceType': 'expense',
    'subtotal': '800.00',
    'taxAmount': '0.00',
    'totalAmount': '800.00',
    'remainingAmount': '800.00',
    'status': 'posted',
    'isOverdue': false,
    'allowedActions': <String>['reverse'],
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
      return _ok(options, _suppliers, meta: <String, dynamic>{
        'currentPage': 1,
        'perPage': 10,
        'total': _suppliers.length,
        'lastPage': 1,
      });
    }
    if (path == 'finance/suppliers/1') {
      return _ok(options, <String, dynamic>{..._supplier(), 'totalInvoiced': '800.00', 'totalPaid': '0.00'});
    }
    if (path == 'finance/supplier-invoices/10') {
      return _ok(options, _invoice());
    }
    if (path == 'finance/supplier-invoices') {
      return _ok(options, <Map<String, dynamic>>[_invoice()]);
    }
    if (path == 'finance/supplier-payments') {
      return _ok(options, <Map<String, dynamic>>[]);
    }
    if (path == 'finance/suppliers/1/statement') {
      return _ok(options, <String, dynamic>{
        'supplier': <String, dynamic>{'id': 1},
        'lines': <Map<String, dynamic>>[],
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

  Response<dynamic> _ok(RequestOptions options, dynamic data, {Map<String, dynamic>? meta}) => Response<dynamic>(
    requestOptions: options,
    statusCode: 200,
    data: <String, dynamic>{'data': data, ...?meta == null ? null : <String, dynamic>{'meta': meta}},
  );
}
