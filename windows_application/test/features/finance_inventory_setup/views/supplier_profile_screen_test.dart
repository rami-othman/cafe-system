import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/supplier_profile_screen.dart';

void main() {
  testWidgets('renders supplier KPIs, invoices tab, an overdue badge, and drops the Purchases placeholder', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    expect(find.textContaining('SUP-00003'), findsWidgets);
    expect(find.text('الرصيد المستحق'), findsOneWidget);
    expect(find.text('800.00'), findsWidgets);
    expect(find.text('AP-000010'), findsOneWidget);
    expect(find.text('متأخر'), findsOneWidget);
    expect(find.text('نشط'), findsOneWidget);
    // Phase 6 explicitly drops the old unimplemented 4th tab.
    expect(find.text('المشتريات'), findsNothing);
  });

  testWidgets('shows a loading state before the first load resolves', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend()..gateSupplier = true;
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(backend, const SupplierProfileScreen(supplierId: 3)));
    await tester.pump();
    expect(find.text('جارٍ تحميل ملف المورد…'), findsOneWidget);
    backend.gateSupplier = false;
    await tester.pumpAndSettle();
    expect(find.text('AP-000010'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when loading fails', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend()..failFirstSupplierCall = true;
    await _pumpScreen(tester, backend);

    expect(find.text('إعادة المحاولة'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('AP-000010'), findsOneWidget);
  });

  testWidgets('switching to الدفعات shows the payments tab', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('الدفعات'));
    await tester.pumpAndSettle();
    expect(find.text('SPAY-000005'), findsOneWidget);
  });

  testWidgets('statement tab shows the computed summary and drills into an invoice', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('كشف الحساب'));
    await tester.pumpAndSettle();
    expect(find.text('الرصيد الافتتاحي'), findsOneWidget);
    expect(find.text('الرصيد الختامي'), findsOneWidget);
    expect(find.text('800.00'), findsWidgets); // closing balance from the last statement line

    await tester.tap(find.text('AP-000010').last);
    await tester.pumpAndSettle();
    expect(find.text('فاتورة مورد'), findsOneWidget);
  });

  testWidgets('draft invoice can be edited and re-saved', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('AP-000011'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل'), findsOneWidget);
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();

    final Finder subtotalField = find.widgetWithText(TextField, 'الإجمالي الفرعي');
    await tester.enterText(subtotalField, '650.00');
    await tester.tap(find.text('حفظ كمسودة'));
    await tester.pumpAndSettle();

    expect(backend.lastInvoiceUpdatePayload, isNotNull);
    expect(backend.lastInvoiceUpdatePayload!['subtotal'], '650.00');
  });

  testWidgets('posting a draft invoice calls the post endpoint and reloads', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('AP-000011'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ترحيل'));
    await tester.pumpAndSettle();

    expect(backend.postedInvoiceIds, contains(11));
  });

  testWidgets('single-invoice partial payment posts an exact allocation', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('دفعة جديدة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'مبلغ الدفعة'), '300.00');
    final Finder allocationField = find.widgetWithText(TextField, 'تخصيص').first;
    await tester.enterText(allocationField, '300.00');
    await tester.pumpAndSettle();

    expect(find.text('300.00'), findsWidgets); // allocated + remaining(0.00) shown

    await tester.tap(find.text('ترحيل الدفعة'));
    await tester.pumpAndSettle();

    expect(backend.lastPaymentPayload, isNotNull);
    expect(backend.lastPaymentPayload!['amount'], '300.00');
    final List<dynamic> allocations = backend.lastPaymentPayload!['allocations'] as List<dynamic>;
    expect(allocations, hasLength(1));
  });

  testWidgets('multi-invoice allocation splits one payment across two open invoices', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('دفعة جديدة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'مبلغ الدفعة'), '500.00');
    final Finder allocationFields = find.widgetWithText(TextField, 'تخصيص');
    await tester.enterText(allocationFields.at(0), '300.00');
    await tester.enterText(allocationFields.at(1), '200.00');
    await tester.pumpAndSettle();

    await tester.tap(find.text('ترحيل الدفعة'));
    await tester.pumpAndSettle();

    expect(backend.lastPaymentPayload, isNotNull);
    final List<dynamic> allocations = backend.lastPaymentPayload!['allocations'] as List<dynamic>;
    expect(allocations, hasLength(2));
  });

  testWidgets('allocation must exactly match the payment amount before submitting', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('دفعة جديدة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'مبلغ الدفعة'), '500.00');
    await tester.enterText(find.widgetWithText(TextField, 'تخصيص').first, '300.00');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ترحيل الدفعة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('يجب أن يساوي إجمالي التخصيصات'), findsOneWidget);
    expect(backend.lastPaymentPayload, isNull);
  });

  testWidgets('overpayment is rejected by the backend even if client math looked fine', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend()..rejectNextPayment = true;
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('دفعة جديدة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'مبلغ الدفعة'), '300.00');
    await tester.enterText(find.widgetWithText(TextField, 'تخصيص').first, '300.00');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ترحيل الدفعة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('exceeds'), findsOneWidget);
    // Dialog stays open on server rejection; nothing was silently accepted.
    expect(find.text('دفعة مورد جديدة'), findsOneWidget);
  });

  testWidgets('payment detail lists allocations and drills into the allocated invoice', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('الدفعات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SPAY-000005'));
    await tester.pumpAndSettle();

    expect(find.text('توزيع الدفعة على الفواتير'), findsOneWidget);
    expect(find.text('AP-000010'), findsWidgets);

    await tester.tap(find.text('AP-000010').last);
    await tester.pumpAndSettle();
    expect(find.text('فاتورة مورد'), findsOneWidget);
  });

  testWidgets('posted invoice journal action opens the shared journal drawer', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('AP-000010'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض القيد'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
    expect(find.text('JE-55'), findsOneWidget);
  });

  testWidgets('a posted invoice with no allowedActions offers no mutation buttons', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend()..lockInvoiceActions = true;
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('AP-000010'));
    await tester.pumpAndSettle();

    expect(find.text('تعديل'), findsNothing);
    expect(find.text('ترحيل'), findsNothing);
    expect(find.text('عكس'), findsNothing);
  });

  testWidgets('opening the profile with ?openPayment auto-opens that payment detail', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = GoRouter(
      initialLocation: '/finance/suppliers/3?openPayment=5',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/suppliers/:id',
          builder: (_, GoRouterState state) => Scaffold(
            body: SupplierProfileScreen(
              supplierId: int.parse(state.pathParameters['id']!),
              openPaymentId: int.tryParse(state.uri.queryParameters['openPayment'] ?? ''),
            ),
          ),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_appRouter(backend, router));
    await tester.pumpAndSettle();

    expect(find.text('SPAY-000005'), findsWidgets);
    expect(find.text('توزيع الدفعة على الفواتير'), findsOneWidget);
  });

  testWidgets('remains overflow-free at Finance desktop widths', (WidgetTester tester) async {
    for (final Size size in <Size>[
      const Size(1280, 900),
      const Size(1366, 900),
      const Size(1440, 900),
      const Size(1600, 1000),
      const Size(1920, 1080),
    ]) {
      final _FakeBackend backend = _FakeBackend();
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(backend, const SupplierProfileScreen(supplierId: 3)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

Widget _app(_FakeBackend backend, Widget child) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        try {
          handler.resolve(await backend.respond(options));
        } on DioException catch (error) {
          handler.reject(error);
        }
      },
    ),
  );
  final FinanceSetupRepository repository = FinanceSetupRepository(DioApiClient(dio: dio));
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: BlocProvider<FinanceSetupCubit>.value(value: cubit, child: child),
      ),
    ),
  );
}

Widget _appRouter(_FakeBackend backend, GoRouter router) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        try {
          handler.resolve(await backend.respond(options));
        } on DioException catch (error) {
          handler.reject(error);
        }
      },
    ),
  );
  final FinanceSetupRepository repository = FinanceSetupRepository(DioApiClient(dio: dio));
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);
  return MaterialApp.router(
    routerConfig: router,
    builder: (BuildContext context, Widget? child) => Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider<FinanceSetupCubit>.value(value: cubit, child: child ?? const SizedBox.shrink()),
    ),
  );
}

Future<void> _pumpScreen(WidgetTester tester, _FakeBackend backend) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(backend, const SupplierProfileScreen(supplierId: 3)));
  await tester.pumpAndSettle();
}

class _FakeBackend {
  bool gateSupplier = false;
  bool failFirstSupplierCall = false;
  bool _supplierFailed = false;
  bool lockInvoiceActions = false;
  bool rejectNextPayment = false;

  final Map<int, String> _invoiceStatus = <int, String>{10: 'posted', 11: 'draft'};
  final Set<int> postedInvoiceIds = <int>{};
  Map<String, dynamic>? lastInvoiceUpdatePayload;
  Map<String, dynamic>? lastPaymentPayload;

  Map<String, dynamic> _invoice10() => <String, dynamic>{
    'id': 10,
    'internalReference': 'AP-000010',
    'invoiceNumber': 'INV-777',
    'supplierId': 3,
    'supplierName': 'Acme Roasters',
    'invoiceDate': '2026-08-01',
    'dueDate': '2020-01-01',
    'invoiceType': 'expense',
    'subtotal': '800.00',
    'taxAmount': '0.00',
    'totalAmount': '800.00',
    'remainingAmount': '800.00',
    'status': _invoiceStatus[10],
    'isOverdue': _invoiceStatus[10] != 'draft',
    'journalEntryId': 55,
    'allowedActions': lockInvoiceActions ? <String>[] : <String>['reverse'],
  };

  Map<String, dynamic> _invoice11() => <String, dynamic>{
    'id': 11,
    'internalReference': 'AP-000011',
    'invoiceNumber': 'INV-778',
    'supplierId': 3,
    'supplierName': 'Acme Roasters',
    'invoiceDate': '2026-08-02',
    'dueDate': '2026-09-02',
    'invoiceType': 'expense',
    'expenseCategoryId': 4,
    'expenseCategoryName': 'Rent',
    'subtotal': '500.00',
    'taxAmount': '0.00',
    'totalAmount': '500.00',
    'remainingAmount': '500.00',
    'status': _invoiceStatus[11],
    'isOverdue': false,
    'allowedActions': _invoiceStatus[11] == 'draft' ? <String>['edit', 'post'] : <String>['reverse'],
  };

  Map<String, dynamic> _invoice12() => <String, dynamic>{
    'id': 12,
    'internalReference': 'AP-000012',
    'invoiceNumber': 'INV-779',
    'supplierId': 3,
    'supplierName': 'Acme Roasters',
    'invoiceDate': '2026-08-03',
    'dueDate': '2026-09-03',
    'invoiceType': 'expense',
    'subtotal': '200.00',
    'taxAmount': '0.00',
    'totalAmount': '200.00',
    'remainingAmount': '200.00',
    'status': 'posted',
    'isOverdue': false,
    'allowedActions': <String>['reverse'],
  };

  Map<String, dynamic> _payment5() => <String, dynamic>{
    'id': 5,
    'paymentNumber': 'SPAY-000005',
    'supplierId': 3,
    'supplierName': 'Acme Roasters',
    'paymentDate': '2026-08-15',
    'amount': '700.00',
    'paymentMethodName': 'Cash',
    'financialLocationName': 'Cash Drawer',
    'status': 'posted',
    'journalEntryId': 77,
    'allowedActions': <String>['reverse'],
    'allocations': <Map<String, dynamic>>[
      <String, dynamic>{'invoiceId': 10, 'invoiceReference': 'AP-000010', 'amount': '700.00'},
    ],
  };

  Future<Response<dynamic>> respond(RequestOptions options) async {
    final String path = options.path;
    final String method = options.method;

    if (path == 'finance/suppliers/3' && method == 'GET') {
      if (failFirstSupplierCall && !_supplierFailed) {
        _supplierFailed = true;
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
      while (gateSupplier) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return _ok(options, <String, dynamic>{
        'id': 3,
        'supplierNumber': 'SUP-00003',
        'name': 'Acme Roasters',
        'isActive': true,
        'paymentTermsDays': 30,
        'outstandingBalance': '800.00',
        'overdueBalance': '300.00',
        'openInvoiceCount': 1,
        'totalInvoiced': '1500.00',
        'totalPaid': '700.00',
        'allowedActions': <String>['edit', 'changeStatus'],
      });
    }
    if (path == 'finance/supplier-invoices' && method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[_invoice10(), _invoice11(), _invoice12()]);
    }
    if (path == 'finance/supplier-invoices/10' && method == 'GET') {
      return _ok(options, _invoice10());
    }
    if (path == 'finance/supplier-invoices/11' && method == 'PATCH') {
      lastInvoiceUpdatePayload = Map<String, dynamic>.from(options.data as Map);
      return _ok(options, _invoice11());
    }
    if (path == 'finance/supplier-invoices/11/post' && method == 'POST') {
      postedInvoiceIds.add(11);
      _invoiceStatus[11] = 'posted';
      return _ok(options, _invoice11());
    }
    if (path == 'finance/supplier-payments' && method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[_payment5()]);
    }
    if (path == 'finance/supplier-payments' && method == 'POST') {
      final Map<String, dynamic> payload = Map<String, dynamic>.from(options.data as Map);
      lastPaymentPayload = payload;
      if (rejectNextPayment) {
        throw DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 422,
            data: <String, dynamic>{
              'message': 'Allocation for AP-000010 exceeds its remaining balance of 250.00.',
            },
          ),
          type: DioExceptionType.badResponse,
        );
      }
      return _ok(options, _payment5());
    }
    if (path == 'finance/suppliers/3/statement') {
      return _ok(options, <String, dynamic>{
        'supplier': <String, dynamic>{'id': 3},
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 10,
            'date': '2026-08-01',
            'type': 'invoice',
            'reference': 'AP-000010',
            'debit': '0.00',
            'credit': '1500.00',
            'runningBalance': '1500.00',
          },
          <String, dynamic>{
            'id': 5,
            'date': '2026-08-15',
            'type': 'payment',
            'reference': 'SPAY-000005',
            'debit': '700.00',
            'credit': '0.00',
            'runningBalance': '800.00',
          },
        ],
      });
    }
    if (path == 'finance/transactions/55') {
      return _ok(options, <String, dynamic>{
        'id': 55,
        'reference': 'JE-55',
        'transactionDate': '2026-08-01',
        'description': 'فاتورة مورد AP-000010',
        'branch': <String, dynamic>{'name': 'فرع دمشق'},
        'source': <String, dynamic>{
          'type': 'supplier_invoice',
          'normalizedType': 'supplier_invoice',
          'resourceKind': 'supplier_invoice',
          'id': 10,
          'available': true,
        },
        'displayAmount': <String, dynamic>{'amount': '800.00'},
        'reversal': <String, dynamic>{'state': 'none'},
        'journal': <String, dynamic>{'id': 55, 'status': 'posted', 'lines': <Map<String, dynamic>>[]},
      });
    }
    if (path == 'finance/expense-categories') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 4,
          'code': 'RENT',
          'name': 'Rent',
          'financialAccountId': 12,
          'financialAccountCode': '6100',
          'isActive': true,
          'sortOrder': 0,
        },
      ]);
    }
    if (path == 'finance/accounts') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 12,
          'code': '6100',
          'nameAr': 'مصروف إيجار',
          'nameEn': 'Rent Expense',
          'accountGroup': 'expenses',
          'normalBalance': 'debit',
          'isActive': true,
          'isSystemProtected': false,
        },
      ]);
    }
    if (path == 'branches') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Main Branch',
          'currency': 'SYP',
          'timezone': 'Asia/Damascus',
          'isActive': true,
        },
      ]);
    }
    if (path == 'finance/payment-methods') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'code': 'CASH',
          'name': 'Cash',
          'type': 'cash',
          'financialAccountId': 2,
          'financialAccountCode': '1010',
          'isActive': true,
        },
      ]);
    }
    if (path == 'finance/cash-accounts') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 3,
          'code': 'CASH-DRAWER',
          'name': 'Cash Drawer',
          'kind': 'cash',
          'type': 'cash_drawer',
          'financialAccountId': 2,
          'financialAccountCode': '1010',
          'isActive': true,
          'balance': '500.00',
          'todayIncoming': '0.00',
          'todayOutgoing': '0.00',
        },
      ]);
    }
    if (path == 'finance/bank-accounts') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 8,
          'code': 'BANK-MAIN',
          'name': 'Main Bank',
          'kind': 'bank',
          'type': 'bank_account',
          'financialAccountId': 6,
          'financialAccountCode': '1020',
          'isActive': true,
          'balance': '2000.00',
          'todayIncoming': '0.00',
          'todayOutgoing': '0.00',
        },
      ]);
    }

    throw DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{'message': 'Unhandled test route: $method $path'},
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
