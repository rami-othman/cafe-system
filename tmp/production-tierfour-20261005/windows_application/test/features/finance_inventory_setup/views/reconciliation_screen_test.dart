import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/reconciliation_screen.dart';

void main() {
  testWidgets('loads real reconciliations and renders KPIs, table row, and type/status labels', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    expect(find.text('تسويات مفتوحة'), findsOneWidget);
    expect(find.text('تسويات مكتملة'), findsOneWidget);
    expect(find.text('فروقات غير محسومة'), findsOneWidget);
    expect(find.text('بحاجة مطابقة'), findsOneWidget);
    expect(find.text('REC-CASH-1'), findsOneWidget);
    expect(find.text('نقدي'), findsWidgets);
    expect(find.text('بنك'), findsWidgets);
  });

  testWidgets('shows the empty state when there are no reconciliations', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend()..sessions = <Map<String, dynamic>>[];
    await _pumpScreen(tester, backend);

    expect(find.text('لا توجد تسويات مسجلة بعد'), findsOneWidget);
  });

  testWidgets('shows an error message with retry when loading fails', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend()..failList = true;
    await _pumpScreen(tester, backend);

    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('creating a new cash reconciliation submits the real payload', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend);

    await tester.tap(find.text('تسوية جديدة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء'));
    await tester.pumpAndSettle();

    expect(backend.lastCreatePayload, isNotNull);
    expect(backend.lastCreatePayload!['type'], 'cash');
    expect(backend.lastCreatePayload!['financialLocationId'], 9);
  });

  testWidgets('tapping a reconciliation row navigates to its workspace route', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    final GoRouter router = GoRouter(
      initialLocation: '/finance/reconciliation',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/reconciliation',
          builder: (_, _) => _wired(backend, const ReconciliationScreen()),
        ),
        GoRoute(
          path: '/finance/reconciliation/:id',
          builder: (_, GoRouterState state) =>
              Scaffold(body: Text('workspace-route-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('REC-CASH-1'));
    await tester.pumpAndSettle();

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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: _wired(backend, const ReconciliationScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeBackend {
  bool failList = false;
  Map<String, dynamic>? lastCreatePayload;

  List<Map<String, dynamic>> sessions = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'reference': 'REC-CASH-1',
      'type': 'cash',
      'status': 'in_progress',
      'account': <String, dynamic>{
        'financialAccountId': 5,
        'financialAccountCode': '1010',
        'financialAccountName': 'Cash Drawer',
        'financialLocationId': 9,
        'name': 'Cash Drawer',
        'type': 'cash',
        'branchId': 1,
        'branchName': 'Main Branch',
      },
      'period': <String, dynamic>{'from': '2026-09-01', 'to': '2026-09-01'},
      'balances': <String, dynamic>{
        'bookOpening': '100.00',
        'bookClosing': '150.00',
        'externalOpening': null,
        'externalClosing': null,
        'actualCash': null,
        'difference': null,
        'differenceDirection': null,
      },
      'summary': <String, dynamic>{
        'systemTransactionsCount': 1,
        'statementLinesCount': 0,
        'matchedCount': 0,
        'unmatchedSystemCount': 0,
        'unmatchedStatementCount': 0,
        'matchedAmount': '0.00',
        'unmatchedSystemAmount': '0.00',
        'unmatchedStatementAmount': '0.00',
      },
      'canComplete': false,
      'blockingReasons': <String>['MISSING_ACTUAL_CASH_COUNT'],
      'allowedActions': <String>['edit', 'match', 'statementLineManage'],
    },
    <String, dynamic>{
      'id': 2,
      'reference': 'REC-BANK-2',
      'type': 'bank',
      'status': 'completed',
      'account': <String, dynamic>{
        'financialAccountId': 6,
        'financialAccountCode': '1030',
        'financialAccountName': 'Bank Account',
        'financialLocationId': 10,
        'name': 'Bank Account',
        'type': 'bank',
        'branchId': null,
        'branchName': null,
      },
      'period': <String, dynamic>{'from': '2026-08-01', 'to': '2026-08-31'},
      'balances': <String, dynamic>{
        'bookOpening': '0.00',
        'bookClosing': '100.00',
        'externalOpening': '0.00',
        'externalClosing': '100.00',
        'actualCash': null,
        'difference': '0.00',
        'differenceDirection': 'balanced',
      },
      'summary': <String, dynamic>{
        'systemTransactionsCount': 1,
        'statementLinesCount': 1,
        'matchedCount': 1,
        'unmatchedSystemCount': 0,
        'unmatchedStatementCount': 0,
        'matchedAmount': '100.00',
        'unmatchedSystemAmount': '0.00',
        'unmatchedStatementAmount': '0.00',
      },
      'canComplete': false,
      'blockingReasons': <String>['SESSION_ALREADY_COMPLETED'],
      'allowedActions': <String>[],
    },
  ];

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;
    final String method = options.method;

    if (path == 'finance/reconciliations' && method == 'GET') {
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
      return _ok(options, sessions, meta: <String, dynamic>{
        'currentPage': 1,
        'perPage': 50,
        'total': sessions.length,
        'lastPage': 1,
      });
    }
    if (path == 'finance/reconciliations' && method == 'POST') {
      lastCreatePayload = Map<String, dynamic>.from(options.data as Map);
      return _ok(options, sessions.first);
    }
    if (path == 'finance/cash-accounts') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 9,
          'code': 'CASH-DRAWER',
          'name': 'Cash Drawer',
          'kind': 'cash',
          'type': 'cash_drawer',
          'financialAccountId': 5,
          'financialAccountCode': '1010',
          'isActive': true,
          'balance': '150.00',
          'todayIncoming': '0.00',
          'todayOutgoing': '0.00',
        },
      ]);
    }
    if (path == 'finance/bank-accounts') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 10,
          'code': 'BANK',
          'name': 'Bank Account',
          'kind': 'bank',
          'type': 'bank_account',
          'financialAccountId': 6,
          'financialAccountCode': '1030',
          'isActive': true,
          'balance': '100.00',
          'todayIncoming': '0.00',
          'todayOutgoing': '0.00',
        },
      ]);
    }
    if (path == 'finance/payment-methods') {
      return _ok(options, <Map<String, dynamic>>[]);
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

  Response<dynamic> _ok(RequestOptions options, dynamic data, {Map<String, dynamic>? meta}) =>
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{'data': data, ...?meta == null ? null : <String, dynamic>{'meta': meta}},
      );
}
