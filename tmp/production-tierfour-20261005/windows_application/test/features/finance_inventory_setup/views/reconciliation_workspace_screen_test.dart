import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/reconciliation_workspace_screen.dart';

void main() {
  testWidgets('cash workspace renders balances, blocked readiness, and cash movements with journal drill-down', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 1);

    expect(find.text('Cash Drawer'), findsWidgets);
    expect(find.text('الرصيد الافتتاحي (دفتر)'), findsOneWidget);
    expect(find.text('محظورة عن الإنهاء'), findsOneWidget);
    expect(find.textContaining('لم يتم إدخال النقد الفعلي بعد'), findsOneWidget);
    expect(find.text('Cash sale'), findsOneWidget);

    await tester.tap(find.text('Cash sale'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
    expect(find.text('JE-CASH-901'), findsWidgets);
  });

  testWidgets('updating actual cash then completing succeeds once backend readiness allows it', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 1);

    await tester.tap(find.text('تحديث النقد الفعلي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'النقد الفعلي'), '150.00');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(backend.lastUpdatePayload, <String, dynamic>{'actualCashCount': '150.00'});
    expect(find.text('جاهزة للإنهاء'), findsOneWidget);

    await tester.tap(find.text('إكمال التسوية'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'إنهاء التسوية'));
    await tester.pumpAndSettle();

    expect(backend.completedCalled, isTrue);
  });

  testWidgets('bank workspace renders the two-panel system/statement compare', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 2);

    expect(find.text('حركات النظام'), findsOneWidget);
    expect(find.text('سطور الكشف'), findsOneWidget);
    expect(find.textContaining('JE-201'), findsOneWidget);
    expect(find.textContaining('STMT-101'), findsOneWidget);
  });

  testWidgets('selecting one system transaction and one statement line enables an exact match', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 2);

    // System checkboxes render first (201, 202, 203, 204 — 205 is already
    // fully matched and shows a check icon instead), then statement
    // checkboxes (101, 103, 104 — 102 is already fully matched). So index 0
    // is JE-201 and index 4 is the first selectable statement line, STMT-101.
    await tester.tap(find.byWidgetPredicate((Widget w) => w is Checkbox).at(0));
    await tester.tap(find.byWidgetPredicate((Widget w) => w is Checkbox).at(4));
    await tester.pump();

    final ElevatedButton matchButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'مطابقة'),
    );
    expect(matchButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'مطابقة'));
    await tester.pumpAndSettle();

    expect(backend.matchCalls, hasLength(1));
    expect(backend.matchCalls.single['statementLineId'], 101);
    expect(backend.matchCalls.single['journalEntryId'], 201);
    expect(backend.matchCalls.single['amount'], '60.00');
  });

  testWidgets('match is disabled while the selected totals differ', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 2);

    // JE-202 (30.00, index 1) against STMT-101 (60.00 remaining, index 4) — an intentional mismatch.
    await tester.tap(find.byWidgetPredicate((Widget w) => w is Checkbox).at(1));
    await tester.tap(find.byWidgetPredicate((Widget w) => w is Checkbox).at(4));
    await tester.pump();

    final ElevatedButton matchButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'مطابقة'),
    );
    expect(matchButton.onPressed, isNull);
    expect(backend.matchCalls, isEmpty);
  });

  testWidgets('many-to-one: two system transactions matched against one statement line submit two matches', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 2);

    // JE-202 (index 1) + JE-203 (index 2) against STMT-101 (index 4, 60.00 remaining).
    await tester.tap(find.byWidgetPredicate((Widget w) => w is Checkbox).at(1));
    await tester.tap(find.byWidgetPredicate((Widget w) => w is Checkbox).at(2));
    await tester.tap(find.byWidgetPredicate((Widget w) => w is Checkbox).at(4));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'مطابقة'));
    await tester.pumpAndSettle();

    expect(backend.matchCalls, hasLength(2));
    expect(
      backend.matchCalls.map((Map<String, dynamic> c) => c['journalEntryId']),
      containsAll(<int>[202, 203]),
    );
    expect(backend.matchCalls.every((Map<String, dynamic> c) => c['statementLineId'] == 101), isTrue);
  });

  testWidgets('unmatching a recorded match calls the real unmatch endpoint after confirmation', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 2);

    expect(find.text('مطابقات مسجلة'), findsOneWidget);
    await tester.tap(find.text('إلغاء المطابقة').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء المطابقة').last);
    await tester.pumpAndSettle();

    expect(backend.unmatchedIds, contains(301));
  });

  testWidgets('adding a statement line posts the real fields', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 2);

    await tester.tap(find.text('إضافة سطر كشف'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'الوصف'), 'Manual deposit');
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), '12.50');
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();

    expect(backend.lastAddLinePayload, isNotNull);
    expect(backend.lastAddLinePayload!['description'], 'Manual deposit');
    expect(backend.lastAddLinePayload!['amount'], '12.50');
    expect(backend.lastAddLinePayload!['direction'], 'inflow');
  });

  testWidgets('an unmatched statement line can be deleted after confirmation', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 2);

    // Deletable statement lines render in order 101, 103, 104 (102 is
    // already fully matched and has no delete action) — index 1 is 103.
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(backend.deletedLineIds, contains(103));
  });

  testWidgets('accepting a match suggestion calls the backend match endpoint with the candidate', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 2);

    expect(find.text('اقتراحات المطابقة'), findsOneWidget);
    await tester.tap(find.text('قبول الاقتراح'));
    await tester.pumpAndSettle();

    expect(backend.matchCalls, hasLength(1));
    expect(backend.matchCalls.single['statementLineId'], 104);
    expect(backend.matchCalls.single['journalEntryId'], 204);
    expect(backend.matchCalls.single['amount'], '25.00');
  });

  testWidgets('a completed reconciliation is read-only with no match/unmatch/add/delete affordances', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pumpScreen(tester, backend, 3);

    expect(find.textContaining('تم إنهاء هذه التسوية'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('إضافة سطر كشف'), findsNothing);
    expect(find.text('مطابقة'), findsNothing);
    expect(find.text('إلغاء المطابقة'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('إكمال التسوية'), findsNothing);

    await tester.tap(find.byTooltip('عرض القيد'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
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
      await tester.pumpWidget(_app(backend, 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

Widget _app(_FakeBackend backend, int id) {
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
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: BlocProvider<FinanceSetupCubit>.value(
          value: cubit,
          child: ReconciliationWorkspaceScreen(reconciliationId: id),
        ),
      ),
    ),
  );
}

Future<void> _pumpScreen(WidgetTester tester, _FakeBackend backend, int id) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(backend, id));
  await tester.pumpAndSettle();
}

class _FakeBackend {
  Map<String, dynamic>? lastUpdatePayload;
  Map<String, dynamic>? lastAddLinePayload;
  final List<Map<String, dynamic>> matchCalls = <Map<String, dynamic>>[];
  final List<int> unmatchedIds = <int>[];
  final List<int> deletedLineIds = <int>[];
  bool completedCalled = false;

  Map<String, dynamic> _cashAccount() => <String, dynamic>{
    'financialAccountId': 5,
    'financialAccountCode': '1010',
    'financialAccountName': 'Cash Drawer',
    'financialLocationId': 9,
    'name': 'Cash Drawer',
    'type': 'cash',
    'branchId': 1,
    'branchName': 'Main Branch',
  };

  Map<String, dynamic> _bankAccount() => <String, dynamic>{
    'financialAccountId': 6,
    'financialAccountCode': '1030',
    'financialAccountName': 'Bank Account',
    'financialLocationId': 10,
    'name': 'Bank Account',
    'type': 'bank',
    'branchId': null,
    'branchName': null,
  };

  Map<String, dynamic> _session1() => <String, dynamic>{
    'id': 1,
    'reference': 'REC-CASH-1',
    'type': 'cash',
    'status': 'in_progress',
    'account': _cashAccount(),
    'period': <String, dynamic>{'from': '2026-09-01', 'to': '2026-09-01'},
    'balances': <String, dynamic>{
      'bookOpening': '100.00',
      'bookClosing': '150.00',
      'externalOpening': null,
      'externalClosing': null,
      'actualCash': lastUpdatePayload?['actualCashCount'],
      'difference': lastUpdatePayload == null ? null : '0.00',
      'differenceDirection': lastUpdatePayload == null ? null : 'balanced',
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
    'canComplete': lastUpdatePayload != null,
    'blockingReasons': lastUpdatePayload != null ? <String>[] : <String>['MISSING_ACTUAL_CASH_COUNT'],
    'allowedActions': <String>['edit', 'match'],
    'statementLines': <Map<String, dynamic>>[],
    'matches': <Map<String, dynamic>>[],
  };

  Map<String, dynamic> _session2() => <String, dynamic>{
    'id': 2,
    'reference': 'REC-BANK-2',
    'type': 'bank',
    'status': 'in_progress',
    'account': _bankAccount(),
    'period': <String, dynamic>{'from': '2026-08-01', 'to': '2026-08-31'},
    'balances': <String, dynamic>{
      'bookOpening': '0.00',
      'bookClosing': '200.00',
      'externalOpening': '0.00',
      'externalClosing': '200.00',
      'actualCash': null,
      'difference': '0.00',
      'differenceDirection': 'balanced',
    },
    'summary': <String, dynamic>{
      'systemTransactionsCount': 5,
      'statementLinesCount': 4,
      'matchedCount': 1,
      'unmatchedSystemCount': 4,
      'unmatchedStatementCount': 3,
      'matchedAmount': '40.00',
      'unmatchedSystemAmount': '145.00',
      'unmatchedStatementAmount': '100.00',
    },
    'canComplete': false,
    'blockingReasons': <String>['UNMATCHED_STATEMENT_LINES', 'UNMATCHED_SYSTEM_TRANSACTIONS'],
    'allowedActions': <String>['edit', 'match', 'statementLineManage'],
    'statementLines': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 101,
        'transactionDate': '2026-08-05',
        'valueDate': null,
        'reference': 'STMT-101',
        'description': 'Deposit A',
        'amount': '60.00',
        'direction': 'inflow',
        'externalIdentifier': null,
        'matchedAmount': '0.00',
        'remainingAmount': '60.00',
      },
      <String, dynamic>{
        'id': 102,
        'transactionDate': '2026-08-06',
        'valueDate': null,
        'reference': 'STMT-102',
        'description': 'Deposit B (matched)',
        'amount': '40.00',
        'direction': 'inflow',
        'externalIdentifier': null,
        'matchedAmount': '40.00',
        'remainingAmount': '0.00',
      },
      <String, dynamic>{
        'id': 103,
        'transactionDate': '2026-08-07',
        'valueDate': null,
        'reference': 'STMT-103',
        'description': 'Deposit C (deletable)',
        'amount': '15.00',
        'direction': 'inflow',
        'externalIdentifier': null,
        'matchedAmount': '0.00',
        'remainingAmount': '15.00',
      },
      <String, dynamic>{
        'id': 104,
        'transactionDate': '2026-08-05',
        'valueDate': null,
        'reference': 'STMT-104',
        'description': 'Deposit D (suggested)',
        'amount': '25.00',
        'direction': 'inflow',
        'externalIdentifier': null,
        'matchedAmount': '0.00',
        'remainingAmount': '25.00',
      },
    ],
    'matches': <Map<String, dynamic>>[
      <String, dynamic>{'id': 301, 'statementLineId': 102, 'journalEntryId': 205, 'journalReference': 'JE-205', 'amount': '40.00'},
    ],
  };

  Map<String, dynamic> _session3() => <String, dynamic>{
    'id': 3,
    'reference': 'REC-BANK-3',
    'type': 'bank',
    'status': 'completed',
    'account': _bankAccount(),
    'period': <String, dynamic>{'from': '2026-07-01', 'to': '2026-07-31'},
    'balances': <String, dynamic>{
      'bookOpening': '0.00',
      'bookClosing': '90.00',
      'externalOpening': '0.00',
      'externalClosing': '90.00',
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
      'matchedAmount': '90.00',
      'unmatchedSystemAmount': '0.00',
      'unmatchedStatementAmount': '0.00',
    },
    'canComplete': false,
    'blockingReasons': <String>['SESSION_ALREADY_COMPLETED'],
    'allowedActions': <String>[],
    'completedAt': '2026-08-01',
    'statementLines': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 901,
        'transactionDate': '2026-07-05',
        'valueDate': null,
        'reference': 'STMT-901',
        'description': 'Closed deposit',
        'amount': '90.00',
        'direction': 'inflow',
        'externalIdentifier': null,
        'matchedAmount': '90.00',
        'remainingAmount': '0.00',
      },
    ],
    'matches': <Map<String, dynamic>>[
      <String, dynamic>{'id': 901, 'statementLineId': 901, 'journalEntryId': 901, 'journalReference': 'JE-901', 'amount': '90.00'},
    ],
  };

  List<Map<String, dynamic>> _transactions1() => <Map<String, dynamic>>[
    <String, dynamic>{
      'journalEntryId': 901,
      'reference': 'JE-CASH-901',
      'date': '2026-09-01',
      'description': 'Cash sale',
      'direction': 'inflow',
      'amount': '50.00',
      'matchedAmount': '0.00',
    },
  ];

  List<Map<String, dynamic>> _transactions2() => <Map<String, dynamic>>[
    <String, dynamic>{
      'journalEntryId': 201,
      'reference': 'JE-201',
      'date': '2026-08-05',
      'description': 'Bank receipt A',
      'direction': 'inflow',
      'amount': '60.00',
      'matchedAmount': '0.00',
    },
    <String, dynamic>{
      'journalEntryId': 202,
      'reference': 'JE-202',
      'date': '2026-08-06',
      'description': 'Bank receipt B part 1',
      'direction': 'inflow',
      'amount': '30.00',
      'matchedAmount': '0.00',
    },
    <String, dynamic>{
      'journalEntryId': 203,
      'reference': 'JE-203',
      'date': '2026-08-06',
      'description': 'Bank receipt B part 2',
      'direction': 'inflow',
      'amount': '30.00',
      'matchedAmount': '0.00',
    },
    <String, dynamic>{
      'journalEntryId': 204,
      'reference': 'JE-204',
      'date': '2026-08-05',
      'description': 'Suggested receipt',
      'direction': 'inflow',
      'amount': '25.00',
      'matchedAmount': '0.00',
    },
    <String, dynamic>{
      'journalEntryId': 205,
      'reference': 'JE-205',
      'date': '2026-08-06',
      'description': 'Matched receipt',
      'direction': 'inflow',
      'amount': '40.00',
      'matchedAmount': '40.00',
    },
  ];

  List<Map<String, dynamic>> _transactions3() => <Map<String, dynamic>>[
    <String, dynamic>{
      'journalEntryId': 901,
      'reference': 'JE-901',
      'date': '2026-07-05',
      'description': 'Closed deposit',
      'direction': 'inflow',
      'amount': '90.00',
      'matchedAmount': '90.00',
    },
  ];

  List<Map<String, dynamic>> _suggestions2() => <Map<String, dynamic>>[
    <String, dynamic>{
      'statementLineId': 104,
      'confidence': 'high',
      'candidates': <Map<String, dynamic>>[
        <String, dynamic>{
          'journalEntryId': 204,
          'reference': 'JE-204',
          'date': '2026-08-05',
          'description': 'Suggested receipt',
          'direction': 'inflow',
          'amount': '25.00',
          'matchedAmount': '0.00',
        },
      ],
    },
  ];

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;
    final String method = options.method;

    if (path == 'finance/reconciliations/1' && method == 'GET') return _ok(options, _session1());
    if (path == 'finance/reconciliations/2' && method == 'GET') return _ok(options, _session2());
    if (path == 'finance/reconciliations/3' && method == 'GET') return _ok(options, _session3());
    if (path == 'finance/reconciliations/1/system-transactions') return _ok(options, _transactions1());
    if (path == 'finance/reconciliations/2/system-transactions') return _ok(options, _transactions2());
    if (path == 'finance/reconciliations/3/system-transactions') return _ok(options, _transactions3());
    if (path == 'finance/reconciliations/1/suggestions') return _ok(options, <Map<String, dynamic>>[]);
    if (path == 'finance/reconciliations/2/suggestions') return _ok(options, _suggestions2());
    if (path == 'finance/reconciliations/3/suggestions') return _ok(options, <Map<String, dynamic>>[]);
    if (path == 'finance/reconciliations/1' && method == 'PATCH') {
      lastUpdatePayload = Map<String, dynamic>.from(options.data as Map);
      return _ok(options, _session1());
    }
    if (path == 'finance/reconciliations/1/complete' && method == 'POST') {
      completedCalled = true;
      return _ok(options, _session1());
    }
    if (path == 'finance/reconciliations/2/matches' && method == 'POST') {
      matchCalls.add(Map<String, dynamic>.from(options.data as Map));
      return Response<dynamic>(
        requestOptions: options,
        statusCode: 201,
        data: <String, dynamic>{'data': <String, dynamic>{'id': 900 + matchCalls.length}},
      );
    }
    if (path.startsWith('finance/reconciliations/2/matches/') && method == 'DELETE') {
      unmatchedIds.add(int.parse(path.split('/').last));
      return Response<dynamic>(requestOptions: options, statusCode: 204, data: null);
    }
    if (path == 'finance/reconciliations/2/statement-lines' && method == 'POST') {
      lastAddLinePayload = Map<String, dynamic>.from(options.data as Map);
      return _ok(options, <String, dynamic>{'id': 999, ...lastAddLinePayload!});
    }
    if (path.startsWith('finance/reconciliations/2/statement-lines/') && method == 'DELETE') {
      deletedLineIds.add(int.parse(path.split('/').last));
      return Response<dynamic>(requestOptions: options, statusCode: 204, data: null);
    }
    if (path.startsWith('finance/transactions/')) {
      final int id = int.parse(path.split('/').last);
      return _ok(options, <String, dynamic>{
        'id': id,
        'reference': 'JE-CASH-901',
        'transactionDate': '2026-09-01',
        'description': 'Cash sale',
        'branch': <String, dynamic>{'name': 'Main Branch'},
        'source': <String, dynamic>{
          'type': 'pos_order',
          'normalizedType': 'sale',
          'resourceKind': 'order',
          'id': 1,
          'available': true,
        },
        'displayAmount': <String, dynamic>{'amount': '50.00'},
        'reversal': <String, dynamic>{'state': 'none'},
        'journal': <String, dynamic>{'id': id, 'status': 'posted', 'lines': <Map<String, dynamic>>[]},
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
