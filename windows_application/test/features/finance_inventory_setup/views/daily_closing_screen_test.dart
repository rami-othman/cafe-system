import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/daily_closing_screen.dart';

void main() {
  testWidgets('loads real daily closings and renders KPIs and a table row', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    expect(find.text('أيام مفتوحة'), findsOneWidget);
    expect(find.text('أيام مغلقة'), findsOneWidget);
    expect(find.text('أيام بحاجة معالجة'), findsOneWidget);
    expect(find.text('DC-001'), findsNothing); // reference isn't rendered in the table, date/branch is
    expect(find.text('2026-09-01'), findsOneWidget);
    expect(find.text('Downtown'), findsOneWidget);
    expect(find.text('محظورة'), findsOneWidget);
    expect(find.text('غير مغلق'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no daily closings', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend()..rows = <Map<String, dynamic>>[];
    await _pumpScreen(tester, backend);

    expect(find.text('لا توجد إغلاقات يومية مسجلة بعد'), findsOneWidget);
  });

  testWidgets('shows an error message with retry when loading fails', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend()..failList = true;
    await _pumpScreen(tester, backend);

    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('tapping a row navigates to its workspace route', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = GoRouter(
      initialLocation: '/finance/daily-closing',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/daily-closing',
          builder: (_, _) => _wired(backend, const DailyClosingScreen()),
        ),
        GoRoute(
          path: '/finance/daily-closing/:id',
          builder: (_, GoRouterState state) => Scaffold(body: Text('workspace-route-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Downtown'));
    await tester.pumpAndSettle();

    expect(find.text('workspace-route-1'), findsOneWidget);
  });

  testWidgets('opening a day previews (get-or-creates) it and navigates to the workspace', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = GoRouter(
      initialLocation: '/finance/daily-closing',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/daily-closing',
          builder: (_, _) => _wired(backend, const DailyClosingScreen()),
        ),
        GoRoute(
          path: '/finance/daily-closing/:id',
          builder: (_, GoRouterState state) => Scaffold(body: Text('workspace-route-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح إغلاق يوم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(backend.previewCalls, hasLength(1));
    expect(find.text('workspace-route-1'), findsOneWidget);
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
  final FinanceSetupRepository repository = FinanceSetupRepository(DioApiClient(dio: dio));
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);
  return Scaffold(body: BlocProvider<FinanceSetupCubit>.value(value: cubit, child: child));
}

Future<void> _pumpScreen(WidgetTester tester, _FakeBackend backend) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: _wired(backend, const DailyClosingScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeBackend {
  bool failList = false;
  final List<Map<String, dynamic>> previewCalls = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'reference': 'DC-001',
      'businessDate': '2026-09-01',
      'branch': <String, dynamic>{'id': 1, 'name': 'Downtown'},
      'status': 'open',
      'readiness': 'blocked',
      'warningsCount': 0,
      'netSales': '4980.00',
      'expectedCash': '1360.00',
      'actualCash': null,
      'difference': null,
      'closedBy': null,
      'closedAt': null,
      'allowedActions': <String>['edit', 'close'],
    },
    <String, dynamic>{
      'id': 2,
      'reference': 'DC-002',
      'businessDate': '2026-08-31',
      'branch': <String, dynamic>{'id': 2, 'name': 'Mall'},
      'status': 'closed',
      'readiness': 'closed',
      'warningsCount': 0,
      'netSales': '9400.00',
      'expectedCash': '4200.00',
      'actualCash': '4200.00',
      'difference': '0.00',
      'closedBy': 3,
      'closedAt': '2026-09-01 08:40',
      'allowedActions': <String>[],
    },
  ];

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;
    final String method = options.method;

    if (path == 'branches') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Downtown', 'currency': 'SYP', 'timezone': 'Asia/Damascus', 'isActive': true},
      ]);
    }
    if (path == 'finance/daily-closings' && method == 'GET') {
      if (failList) {
        throw DioException(
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 500, data: <String, dynamic>{'message': 'Backend error.'}),
          type: DioExceptionType.badResponse,
        );
      }
      return _ok(
        options,
        rows,
        meta: <String, dynamic>{'currentPage': 1, 'perPage': 50, 'total': rows.length, 'lastPage': 1},
      );
    }
    if (path == 'finance/daily-closing' && method == 'GET') {
      previewCalls.add(Map<String, dynamic>.from(options.queryParameters));
      return _ok(options, <String, dynamic>{
        'id': 1,
        'reference': 'DC-001',
        'businessDate': '2026-09-01',
        'status': 'open',
        'readiness': 'blocked',
        'canClose': false,
        'branch': <String, dynamic>{'id': 1, 'name': 'Downtown'},
        'sales': _emptySales(),
        'refunds': <String, dynamic>{},
        'cash': _emptyCash(),
        'operations': _emptyOperations(),
        'shifts': <String, dynamic>{'total': 0, 'open': 0, 'closed': 0},
        'paymentBreakdown': <Map<String, dynamic>>[],
        'reconciliation': _emptyReconciliation(),
        'financialIntegrity': <String, dynamic>{
          'draftJournals': 0,
          'missingPostings': 0,
          'failedPostings': 0,
          'lateActivityAfterClose': 0,
        },
        'integrityIssues': <String, dynamic>{'lateActivity': <Map<String, dynamic>>[]},
        'blockers': <Map<String, dynamic>>[],
        'warnings': <Map<String, dynamic>>[],
        'closedBy': null,
        'closedAt': null,
        'allowedActions': <String>['edit', 'close'],
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

  Map<String, dynamic> _emptySales() => <String, dynamic>{
    'grossSales': '0.00',
    'discounts': '0.00',
    'refunds': '0.00',
    'netSales': '0.00',
    'cashSales': '0.00',
    'cardSales': '0.00',
    'otherSales': '0.00',
  };
  Map<String, dynamic> _emptyCash() => <String, dynamic>{
    'openingCash': '0.00',
    'cashSales': '0.00',
    'cashRefunds': '0.00',
    'expensesCash': '0.00',
    'supplierPaymentsCash': '0.00',
    'transfersIn': '0.00',
    'transfersOut': '0.00',
    'expectedCash': '0.00',
    'actualCash': null,
    'difference': null,
    'differenceState': null,
  };
  Map<String, dynamic> _emptyOperations() => <String, dynamic>{
    'expensesTotal': '0.00',
    'pendingExpensesCount': 0,
    'supplierPaymentsTotal': '0.00',
    'wasteValue': '0.00',
    'stockShortageValue': '0.00',
    'stockSurplusValue': '0.00',
  };
  Map<String, dynamic> _emptyReconciliation() => <String, dynamic>{
    'required': false,
    'complete': true,
    'unresolvedCount': 0,
    'requiredCount': 0,
    'completedCount': 0,
    'incompleteCount': 0,
    'accounts': <Map<String, dynamic>>[],
  };

  Response<dynamic> _ok(RequestOptions options, dynamic data, {Map<String, dynamic>? meta}) => Response<dynamic>(
    requestOptions: options,
    statusCode: 200,
    data: <String, dynamic>{'data': data, ...?meta == null ? null : <String, dynamic>{'meta': meta}},
  );
}
