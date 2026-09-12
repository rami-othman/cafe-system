import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/purchasing/controllers/purchasing_cubit.dart';
import 'package:windows_application/features/purchasing/repositories/purchasing_repository.dart';
import 'package:windows_application/features/purchasing/views/purchase_invoice_detail_screen.dart';
import 'package:windows_application/features/purchasing/views/purchasing_center_screen.dart';

void main() {
  testWidgets('renders the Purchasing Center with real-shaped list data', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend());

    expect(find.text('المشتريات'), findsWidgets);
    expect(find.text('جميع المشتريات'), findsOneWidget);
    expect(find.text('فواتير الشراء'), findsOneWidget);
    // Deferred-phase features are visually present but marked, never operational.
    expect(find.text('أوامر الشراء'), findsOneWidget);
    expect(find.text('قريباً'), findsWidgets);
    expect(find.text('DEMO-BEANS-001'), findsOneWidget);
    expect(find.text('Demo Bean Roasters'), findsOneWidget);
  });

  testWidgets('switching to the invoices tab shows the full filterable table', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend());

    await tester.tap(find.text('فواتير الشراء'));
    await tester.pumpAndSettle();

    expect(find.text('رقم الفاتورة'), findsOneWidget);
    expect(find.text('نوع الشراء'), findsOneWidget);
    expect(find.text('حالة الدفع'), findsOneWidget);
    expect(find.text('حالة المستند'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no purchases', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend(purchases: const <Map<String, dynamic>>[]));

    expect(find.text('لا توجد مشتريات مسجلة بعد'), findsOneWidget);
  });

  testWidgets('shows an error message with retry when loading fails', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend(failList: true));

    expect(find.text('تعذّر تحميل المشتريات.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('tapping a purchase row navigates to its detail route', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = GoRouter(
      initialLocation: '/finance/purchases',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/purchases',
          builder: (_, _) => _wired(backend, const PurchasingCenterScreen()),
        ),
        GoRoute(
          path: '/finance/purchases/:id',
          builder: (_, GoRouterState state) => _wired(
            backend,
            PurchaseInvoiceDetailScreen(
              purchaseId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DEMO-BEANS-001'));
    await tester.pumpAndSettle();

    expect(find.text('سجل الاستلامات'), findsOneWidget);
    expect(find.text('لم يتم إنشاء أي استلام مخزون بعد لهذه الفاتورة'), findsOneWidget);
    expect(find.text('Arabica beans'), findsOneWidget);
  });

  testWidgets('switching to the receipts tab shows the real Goods Receipt list', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend());

    await tester.tap(find.text('الاستلامات'));
    await tester.pumpAndSettle();

    expect(find.text('رقم الاستلام'), findsWidgets);
    expect(find.text('GRN-2026-000001'), findsOneWidget);
    expect(find.text('DEMO-BEANS-001'), findsWidgets);
  });

  testWidgets('detail screen shows the receive action and receipt history when present', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend(receivable: true);
    final GoRouter router = GoRouter(
      initialLocation: '/finance/purchases/1',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/purchases/:id',
          builder: (_, GoRouterState state) => _wired(
            backend,
            PurchaseInvoiceDetailScreen(
              purchaseId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('استلام مخزون'), findsOneWidget);
    expect(find.text('GRN-2026-000001'), findsOneWidget);
  });
}

Widget _wired(_FakeBackend backend, Widget child) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        try {
          handler.resolve(backend.respond(options));
        } on DioException catch (error) {
          handler.reject(error);
        }
      },
    ),
  );
  final DioApiClient client = DioApiClient(dio: dio);
  final PurchasingCubit purchasingCubit = PurchasingCubit(
    repository: PurchasingRepository(client),
  );
  final FinanceSetupCubit financeCubit = FinanceSetupCubit(
    repository: FinanceSetupRepository(client),
  );
  return Scaffold(
    body: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<PurchasingCubit>.value(value: purchasingCubit),
        BlocProvider<FinanceSetupCubit>.value(value: financeCubit),
      ],
      child: child,
    ),
  );
}

Future<void> _pump(WidgetTester tester, _FakeBackend backend) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: _wired(backend, const PurchasingCenterScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeBackend {
  _FakeBackend({
    List<Map<String, dynamic>>? purchases,
    this.failList = false,
    this.receivable = false,
  }) : _purchases = purchases ?? <Map<String, dynamic>>[_purchase()];

  final List<Map<String, dynamic>> _purchases;
  final bool failList;
  /// When true, the detail fixture behaves like a fully-postable inventory
  /// purchase with remaining quantity and the `receive` allowedAction — the
  /// shape a real Phase 2 backend response has once `finance.purchases.receive`
  /// is granted and the invoice isn't yet fully received.
  final bool receivable;

  static Map<String, dynamic> _purchase() => <String, dynamic>{
    'id': 1,
    'internalReference': 'AP-000001',
    'invoiceNumber': 'DEMO-BEANS-001',
    'supplierId': 1,
    'supplierName': 'Demo Bean Roasters',
    'branchId': null,
    'branchName': null,
    'invoiceDate': '2026-08-15',
    'dueDate': '2026-09-14',
    'purchaseType': 'inventory',
    'debitAccountId': 5,
    'debitAccountCode': '1100',
    'debitAccountName': 'أصل المخزون',
    'subtotal': '175.00',
    'taxAmount': '0.00',
    'totalAmount': '175.00',
    'paidAmount': '0.00',
    'remainingAmount': '175.00',
    'documentStatus': 'posted',
    'paymentStatus': 'unpaid',
    'receiptStatus': 'not_received',
    'status': 'posted',
    'isOverdue': false,
    'createdByName': 'Finance Demo Owner',
    'allowedActions': <String>['reverse'],
  };

  static Map<String, dynamic> _receiptSummary() => <String, dynamic>{
    'id': 5,
    'receiptNumber': 'GRN-2026-000001',
    'receiptDate': '2026-08-20',
    'status': 'posted',
    'branchName': 'المستودع المركزي',
    'lineCount': 1,
    'createdByName': 'Finance Demo Owner',
  };

  Map<String, dynamic> _detail() => <String, dynamic>{
    ..._purchase(),
    if (receivable) 'allowedActions': <String>['reverse', 'receive'],
    'lines': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'lineNumber': 1,
        'lineType': 'inventory',
        'description': 'Arabica beans',
        'inventoryItemId': 9,
        'inventoryItemName': 'Arabica beans',
        'purchaseUnit': 'kg',
        'baseUnit': 'kg',
        'quantity': '10.000',
        'unitPrice': '17.5000',
        'discountAmount': '0.00',
        'taxAmount': '0.00',
        'lineTotal': '175.00',
        'warehouseId': null,
        'receivedQuantity': '0.000',
        'remainingQuantity': '10.000',
      },
    ],
    'payments': <Map<String, dynamic>>[],
    'receipts': receivable
        ? <Map<String, dynamic>>[_receiptSummary()]
        : <Map<String, dynamic>>[],
  };

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;

    if (path == 'finance/purchases' && options.method == 'GET') {
      if (failList) {
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
      return _ok(
        options,
        _purchases,
        meta: <String, dynamic>{
          'currentPage': 1,
          'perPage': 20,
          'total': _purchases.length,
          'lastPage': 1,
        },
      );
    }
    if (path == 'finance/purchases/1') {
      return _ok(options, _detail());
    }
    if (path == 'finance/purchase-receipts' && options.method == 'GET') {
      return _ok(
        options,
        <Map<String, dynamic>>[
          <String, dynamic>{
            ..._receiptSummary(),
            'supplierInvoiceId': 1,
            'invoiceNumber': 'DEMO-BEANS-001',
            'supplierId': 1,
            'supplierName': 'Demo Bean Roasters',
            'allowedActions': <String>[],
          },
        ],
        meta: <String, dynamic>{
          'currentPage': 1,
          'perPage': 20,
          'total': 1,
          'lastPage': 1,
        },
      );
    }
    if (path == 'branches') {
      return _ok(options, <Map<String, dynamic>>[]);
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

  Response<dynamic> _ok(RequestOptions options, dynamic data, {Map<String, dynamic>? meta}) =>
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{
          'data': data,
          ...?meta == null ? null : <String, dynamic>{'meta': meta},
        },
      );
}
