import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/expenses_screen.dart';

void main() {
  testWidgets('loads real expenses, renders KPI cards and table columns', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter());

    expect(find.text('مصروفات اليوم'), findsOneWidget);
    expect(find.text('بانتظار الاعتماد'), findsOneWidget);
    expect(find.text('غير مدفوعة'), findsOneWidget);
    expect(find.text('42.75'), findsOneWidget); // expensesToday KPI value

    expect(find.text('EXP-000001'), findsOneWidget);
    expect(find.text('August rent'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget); // paymentMethodName column
    expect(find.text('Finance Owner'), findsOneWidget); // createdByName column
  });

  testWidgets('shows the empty state when there are no expenses', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter(expenses: const <Map<String, dynamic>>[]));

    expect(find.text('لا توجد مصروفات مسجلة بعد.'), findsOneWidget);
  });

  testWidgets('shows an error message with retry when loading fails', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, router: _FakeRouter(failExpenses: true));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('submitting a draft expense posts the submit action and refreshes its status', (
    WidgetTester tester,
  ) async {
    final _FakeRouter router = _FakeRouter();
    await _pumpScreen(tester, router: router);

    expect(find.text('مسودة'), findsOneWidget);
    final Finder submitButton = find.widgetWithIcon(IconButton, Icons.send_outlined);
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(router.submittedIds, contains(1));
    expect(find.text('مسودة'), findsNothing);
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
            child: const ExpensesScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Routes finance-repository calls used by [ExpensesScreen] to canned JSON,
/// mirroring the backend's `{data: ...}` envelope. Mutates its in-memory
/// expense list on submit/approve/reject/pay so a reload after an action
/// reflects the new state, the same way the real API would.
class _FakeRouter {
  _FakeRouter({
    List<Map<String, dynamic>>? expenses,
    this.failExpenses = false,
  }) : _expenses = expenses ?? <Map<String, dynamic>>[_draftExpense()];

  final List<Map<String, dynamic>> _expenses;
  final bool failExpenses;
  final List<int> submittedIds = <int>[];

  static Map<String, dynamic> _draftExpense() => <String, dynamic>{
    'id': 1,
    'expenseNumber': 'EXP-000001',
    'branchId': null,
    'branchName': null,
    'expenseCategoryId': 4,
    'expenseCategoryCode': 'RENT',
    'expenseCategoryName': 'Rent',
    'amount': '15.50',
    'taxAmount': '0.00',
    'totalAmount': '15.50',
    'expenseDate': '2026-08-20',
    'description': 'August rent',
    'notes': null,
    'status': 'draft',
    'paymentStatus': 'unpaid',
    'paymentMethodId': 1,
    'paymentMethodName': 'Cash',
    'financialLocationId': null,
    'financialLocationName': null,
    'paidAt': null,
    'journalEntryId': null,
    'reversalJournalEntryId': null,
    'createdByName': 'Finance Owner',
    'approvedAt': null,
    'rejectedAt': null,
    'rejectionReason': null,
    'createdAt': '2026-08-19T09:00:00Z',
    'updatedAt': '2026-08-19T09:00:00Z',
  };

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;

    if (path == 'finance/expenses' && options.method == 'GET') {
      if (failExpenses) {
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
      return _ok(options, _expenses);
    }
    if (path.startsWith('finance/expenses/') && path.endsWith('/submit')) {
      final int id = int.parse(path.split('/')[2]);
      submittedIds.add(id);
      final Map<String, dynamic> expense = _expenses.firstWhere((e) => e['id'] == id);
      expense['status'] = 'pending_approval';
      return _ok(options, expense);
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
    if (path == 'finance/cash-accounts' || path == 'finance/bank-accounts') {
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
    if (path == 'finance/setup-status') {
      return _ok(options, <String, dynamic>{
        'systemAccountsReady': true,
        'centralWarehouseReady': true,
        'branchWarehouseCoverageReady': true,
        'financialSetupReady': true,
        'missingBranchWarehouses': <String>[],
        'expensesToday': '42.75',
        'expensesThisMonth': '99.00',
        'pendingExpenseCount': _expenses.where((e) => e['status'] == 'pending_approval').length,
        'unpaidExpenseCount': _expenses.where((e) => e['paymentStatus'] == 'unpaid').length,
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
