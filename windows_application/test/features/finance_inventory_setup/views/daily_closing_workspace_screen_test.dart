import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/daily_closing_workspace_screen.dart';

void main() {
  testWidgets('blocked day renders blockers with a working "view" action', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 1);
    await _pump(tester, router);

    expect(find.text('محظورة عن الإغلاق'), findsOneWidget);
    expect(find.textContaining('يوجد 2 مصروف بانتظار الاعتماد'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'إغلاق اليوم').first, findsOneWidget);
    final ElevatedButton closeButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'إغلاق اليوم').last);
    expect(closeButton.onPressed, isNull);

    await tester.tap(find.text('عرض').first);
    await tester.pumpAndSettle();
    expect(find.text('route:/finance/expenses'), findsOneWidget);
  });

  testWidgets('renders sales summary and payment breakdown from backend aggregation', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 1);
    await _pump(tester, router);

    expect(find.text('ملخص المبيعات'), findsOneWidget);
    expect(find.text('توزيع طرق الدفع'), findsOneWidget);
    expect(find.text('نقدي'), findsOneWidget);
    expect(find.text('بطاقة'), findsOneWidget);
  });

  testWidgets('ready-with-warnings day allows close and shows the warning label', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 2);
    await _pump(tester, router);

    expect(find.text('تحذير'), findsWidgets);
    expect(find.text('جاهزة مع وجود تحذيرات'), findsOneWidget);
    final ElevatedButton closeButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'إغلاق اليوم').last);
    expect(closeButton.onPressed, isNotNull);
  });

  testWidgets('updating actual cash submits the real payload and refreshes the snapshot', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 2);
    await _pump(tester, router);

    await tester.tap(find.text('تحديث النقد الفعلي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'النقد الفعلي'), '4200.00');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(backend.lastUpdatePayload, <String, dynamic>{'actualCash': '4200.00'});
  });

  testWidgets('an expense row navigates to the canonical expense screen', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 1);
    await _pump(tester, router);

    await tester.tap(find.text('EXP-1'));
    await tester.pumpAndSettle();
    expect(find.text('route:/finance/expenses?expenseId=501'), findsOneWidget);
  });

  testWidgets('a supplier payment row navigates to the canonical supplier screen', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 1);
    await _pump(tester, router);

    await tester.ensureVisible(find.text('PAY-1'));
    await tester.tap(find.text('PAY-1'));
    await tester.pumpAndSettle();
    expect(find.text('route:/finance/suppliers?paymentId=701'), findsOneWidget);
  });

  testWidgets('an unposted inventory event row navigates to inventory movements', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 1);
    await _pump(tester, router);

    await tester.ensureVisible(find.text('Milk'));
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('route:/inventory/movements'), findsOneWidget);
  });

  testWidgets('reconciliation review button navigates to the canonical reconciliation list', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 1);
    await _pump(tester, router);

    await tester.tap(find.text('مراجعة التسويات'));
    await tester.pumpAndSettle();
    expect(find.text('route:/finance/reconciliation'), findsOneWidget);
  });

  testWidgets('close confirmation succeeds when the backend allows it and shows the closed banner', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 2);
    await _pump(tester, router);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'إغلاق اليوم').last);
    await tester.tap(find.widgetWithText(ElevatedButton, 'إغلاق اليوم').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد الإغلاق'));
    await tester.pumpAndSettle();

    expect(backend.closeCalled, isTrue);
    expect(find.textContaining('تم إغلاق هذا اليوم'), findsOneWidget);
    expect(find.text('تحديث النقد الفعلي'), findsNothing);
  });

  testWidgets('a backend close failure surfaces the error and resets the closing flag', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend()..failClose = true;
    final GoRouter router = _router(backend, 2);
    await _pump(tester, router);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'إغلاق اليوم').last);
    await tester.tap(find.widgetWithText(ElevatedButton, 'إغلاق اليوم').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد الإغلاق'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذّر إغلاق اليوم'), findsOneWidget);
    final ElevatedButton closeButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'إغلاق اليوم').last);
    expect(closeButton.onPressed, isNotNull); // re-enabled, not stuck on the spinner
  });

  testWidgets('a closed day is read-only and shows late activity that opens the journal drawer', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = _router(backend, 3);
    await _pump(tester, router);

    expect(find.text('هذا الإغلاق مغلق — اللقطة للقراءة فقط ولا يمكن تعديل أي قيمة فيها.'), findsOneWidget);
    expect(find.text('تحديث النقد الفعلي'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'إغلاق اليوم'), findsNothing);
    expect(find.text('تم تسجيل نشاط مالي بعد الإغلاق'), findsOneWidget);

    await tester.ensureVisible(find.text('JE-LATE-1'));
    await tester.tap(find.text('JE-LATE-1'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
  });

  testWidgets('renders without overflow across common desktop widths', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    for (final double width in <double>[1280, 1366, 1440, 1600, 1920]) {
      final GoRouter router = _router(backend, 1);
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

GoRouter _router(_FakeBackend backend, int id) => GoRouter(
  initialLocation: '/finance/daily-closing/$id',
  routes: <RouteBase>[
    GoRoute(
      path: '/finance/daily-closing/:id',
      builder: (_, GoRouterState state) =>
          _wired(backend, DailyClosingWorkspaceScreen(closingId: int.parse(state.pathParameters['id']!))),
    ),
    GoRoute(path: '/finance/daily-closing', builder: (_, _) => const Scaffold(body: Text('route:/finance/daily-closing'))),
    GoRoute(
      path: '/finance/expenses',
      builder: (_, GoRouterState state) =>
          Scaffold(body: Text('route:/finance/expenses${state.uri.query.isEmpty ? '' : '?${state.uri.query}'}')),
    ),
    GoRoute(
      path: '/finance/suppliers',
      builder: (_, GoRouterState state) =>
          Scaffold(body: Text('route:/finance/suppliers${state.uri.query.isEmpty ? '' : '?${state.uri.query}'}')),
    ),
    GoRoute(path: '/finance/reconciliation', builder: (_, _) => const Scaffold(body: Text('route:/finance/reconciliation'))),
    GoRoute(path: '/inventory/movements', builder: (_, _) => const Scaffold(body: Text('route:/inventory/movements'))),
    GoRoute(path: '/finance/journal-entries/:id', builder: (_, _) => const Scaffold(body: Text('route:/finance/journal-entries'))),
  ],
);

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
  final FinanceSetupRepository repository = FinanceSetupRepository(DioApiClient(dio: dio));
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);
  return Scaffold(body: BlocProvider<FinanceSetupCubit>.value(value: cubit, child: child));
}

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

class _FakeBackend {
  Map<String, dynamic>? lastUpdatePayload;
  bool closeCalled = false;
  bool failClose = false;

  Map<String, dynamic> _sales() => <String, dynamic>{
    'grossSales': '5130.00',
    'discounts': '0.00',
    'refunds': '150.00',
    'netSales': '4980.00',
    'cashSales': '1360.00',
    'cardSales': '3620.00',
    'otherSales': '0.00',
  };

  Map<String, dynamic> _cash({String? actual, String? diff, String? diffState}) => <String, dynamic>{
    'openingCash': '5120.00',
    'cashSales': '1360.00',
    'cashRefunds': '80.00',
    'expensesCash': '0.00',
    'supplierPaymentsCash': '0.00',
    'transfersIn': '0.00',
    'transfersOut': '0.00',
    'expectedCash': '6400.00',
    'actualCash': actual,
    'difference': diff,
    'differenceState': diffState,
  };

  List<Map<String, dynamic>> _paymentBreakdown() => <Map<String, dynamic>>[
    <String, dynamic>{'method': 'نقدي', 'gross': '1440.00', 'refunded': '80.00', 'net': '1360.00'},
    <String, dynamic>{'method': 'بطاقة', 'gross': '3690.00', 'refunded': '70.00', 'net': '3620.00'},
  ];

  Map<String, dynamic> _detail1() => <String, dynamic>{
    'id': 1,
    'reference': 'DC-001',
    'businessDate': '2026-09-01',
    'status': 'open',
    'readiness': 'blocked',
    'canClose': false,
    'branch': <String, dynamic>{'id': 1, 'name': 'Downtown'},
    'sales': _sales(),
    'refunds': <String, dynamic>{'total': '150.00', 'cash': '80.00', 'card': '70.00', 'other': '0.00'},
    'cash': _cash(),
    'operations': <String, dynamic>{
      'expensesTotal': '0.00',
      'pendingExpensesCount': 2,
      'supplierPaymentsTotal': '0.00',
      'wasteValue': '0.00',
      'stockShortageValue': '0.00',
      'stockSurplusValue': '0.00',
    },
    'shifts': <String, dynamic>{'total': 1, 'open': 0, 'closed': 1},
    'paymentBreakdown': _paymentBreakdown(),
    'reconciliation': <String, dynamic>{
      'required': true,
      'complete': false,
      'unresolvedCount': 1,
      'requiredCount': 1,
      'completedCount': 0,
      'incompleteCount': 1,
      'accounts': <Map<String, dynamic>>[],
    },
    'financialIntegrity': <String, dynamic>{'draftJournals': 0, 'missingPostings': 0, 'failedPostings': 0, 'lateActivityAfterClose': 0},
    'integrityIssues': <String, dynamic>{'lateActivity': <Map<String, dynamic>>[]},
    'blockers': <Map<String, dynamic>>[
      <String, dynamic>{'code': 'PENDING_EXPENSE_APPROVAL', 'severity': 'blocking', 'count': 2},
      <String, dynamic>{
        'code': 'UNPOSTED_INVENTORY_FINANCIAL_EVENT',
        'severity': 'blocking',
        'movementId': 901,
        'type': 'waste',
        'item': 'Milk',
        'amount': '12.00',
        'financeStatus': 'CONFIGURATION_REQUIRED',
      },
    ],
    'warnings': <Map<String, dynamic>>[],
    'closedBy': null,
    'closedAt': null,
    'allowedActions': <String>['edit'],
  };

  Map<String, dynamic> _detail2() => <String, dynamic>{
    'id': 2,
    'reference': 'DC-002',
    'businessDate': '2026-08-31',
    'status': 'open',
    'readiness': 'ready',
    'canClose': true,
    'branch': <String, dynamic>{'id': 1, 'name': 'Downtown'},
    'sales': _sales(),
    'refunds': <String, dynamic>{'total': '0.00', 'cash': '0.00', 'card': '0.00', 'other': '0.00'},
    'cash': _cash(actual: lastUpdatePayload?['actualCash'] as String?, diff: lastUpdatePayload == null ? null : '0.00', diffState: lastUpdatePayload == null ? null : 'balanced'),
    'operations': <String, dynamic>{
      'expensesTotal': '0.00',
      'pendingExpensesCount': 0,
      'supplierPaymentsTotal': '0.00',
      'wasteValue': '0.00',
      'stockShortageValue': '0.00',
      'stockSurplusValue': '0.00',
    },
    'shifts': <String, dynamic>{'total': 1, 'open': 0, 'closed': 1},
    'paymentBreakdown': _paymentBreakdown(),
    'reconciliation': <String, dynamic>{
      'required': false,
      'complete': true,
      'unresolvedCount': 0,
      'requiredCount': 0,
      'completedCount': 0,
      'incompleteCount': 0,
      'accounts': <Map<String, dynamic>>[],
    },
    'financialIntegrity': <String, dynamic>{'draftJournals': 0, 'missingPostings': 0, 'failedPostings': 0, 'lateActivityAfterClose': 0},
    'integrityIssues': <String, dynamic>{'lateActivity': <Map<String, dynamic>>[]},
    'blockers': <Map<String, dynamic>>[],
    'warnings': <Map<String, dynamic>>[
      <String, dynamic>{'code': 'BANK_RECONCILIATION_INCOMPLETE', 'severity': 'warning'},
    ],
    'closedBy': null,
    'closedAt': null,
    'allowedActions': <String>['edit', 'close'],
  };

  Map<String, dynamic> _detail3() => <String, dynamic>{
    'id': 3,
    'reference': 'DC-003',
    'businessDate': '2026-08-28',
    'status': 'closed',
    'readiness': 'closed',
    'canClose': false,
    'branch': <String, dynamic>{'id': 1, 'name': 'Downtown'},
    'sales': _sales(),
    'refunds': <String, dynamic>{'total': '0.00', 'cash': '0.00', 'card': '0.00', 'other': '0.00'},
    'cash': _cash(actual: '4200.00', diff: '0.00', diffState: 'balanced'),
    'operations': <String, dynamic>{
      'expensesTotal': '0.00',
      'pendingExpensesCount': 0,
      'supplierPaymentsTotal': '0.00',
      'wasteValue': '0.00',
      'stockShortageValue': '0.00',
      'stockSurplusValue': '0.00',
    },
    'shifts': <String, dynamic>{'total': 1, 'open': 0, 'closed': 1},
    'paymentBreakdown': _paymentBreakdown(),
    'reconciliation': <String, dynamic>{
      'required': false,
      'complete': true,
      'unresolvedCount': 0,
      'requiredCount': 0,
      'completedCount': 0,
      'incompleteCount': 0,
      'accounts': <Map<String, dynamic>>[],
    },
    'financialIntegrity': <String, dynamic>{'draftJournals': 0, 'missingPostings': 0, 'failedPostings': 0, 'lateActivityAfterClose': 1},
    'integrityIssues': <String, dynamic>{
      'lateActivity': <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'LATE_FINANCIAL_ACTIVITY_AFTER_CLOSE',
          'journalId': 777,
          'reference': 'JE-LATE-1',
          'sourceType': 'manual',
          'sourceId': null,
          'amount': '180.00',
          'postedAt': '2026-08-29 08:00',
        },
      ],
    },
    'blockers': <Map<String, dynamic>>[],
    'warnings': <Map<String, dynamic>>[],
    'closedBy': 3,
    'closedAt': '2026-08-29 08:40',
    'allowedActions': <String>[],
  };

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;
    final String method = options.method;

    if (path == 'finance/daily-closings/1' && method == 'GET') return _ok(options, _detail1());
    if (path == 'finance/daily-closings/2' && method == 'GET') return _ok(options, _detail2());
    if (path == 'finance/daily-closings/3' && method == 'GET') return _ok(options, _detail3());
    if (path == 'finance/daily-closings/2' && method == 'PATCH') {
      lastUpdatePayload = Map<String, dynamic>.from(options.data as Map);
      return _ok(options, _detail2());
    }
    if (path == 'finance/daily-closings/2/close' && method == 'POST') {
      if (failClose) {
        throw DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 422,
            data: <String, dynamic>{'message': 'Closing is blocked.'},
          ),
          type: DioExceptionType.badResponse,
        );
      }
      closeCalled = true;
      final Map<String, dynamic> closed = Map<String, dynamic>.from(_detail2())
        ..['status'] = 'closed'
        ..['readiness'] = 'closed'
        ..['closedAt'] = '2026-09-01 09:00'
        ..['closedBy'] = 3
        ..['allowedActions'] = <String>[];
      return _ok(options, closed);
    }
    if (path == 'finance/expenses' && method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 501,
          'expenseNumber': 'EXP-1',
          'expenseCategoryId': 1,
          'expenseCategoryName': 'Utilities',
          'amount': '100.00',
          'taxAmount': '0.00',
          'totalAmount': '100.00',
          'expenseDate': '2026-09-01',
          'description': 'Electricity',
          'status': 'approved',
          'paymentStatus': 'unpaid',
        },
      ]);
    }
    if (path == 'finance/supplier-payments' && method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 701,
          'paymentNumber': 'PAY-1',
          'supplierId': 12,
          'supplierName': 'Eastern Mills',
          'paymentDate': '2026-09-01',
          'amount': '250.00',
          'paymentMethodName': 'Cash',
          'financialLocationName': 'Cash Drawer',
          'status': 'posted',
        },
      ]);
    }
    if (path == 'finance/transactions/777' && method == 'GET') {
      return _ok(options, <String, dynamic>{
        'reference': 'JE-LATE-1',
        'transactionDate': '2026-08-29',
        'description': 'Late manual entry',
        'branch': <String, dynamic>{'name': 'Downtown'},
        'source': <String, dynamic>{'available': false},
        'displayAmount': <String, dynamic>{'amount': '180.00'},
        'reversal': <String, dynamic>{'state': 'none'},
        'journal': <String, dynamic>{'id': 777, 'status': 'posted', 'lines': <Map<String, dynamic>>[]},
      });
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

  Response<dynamic> _ok(RequestOptions options, dynamic data) =>
      Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': data});
}
