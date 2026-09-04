import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/finance_inventory_setup/models/finance_setup_models.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/expenses_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_pagination.dart';

void main() {
  tearDown(() async {
    await serviceLocator.reset();
  });

  Widget app(Widget child) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );

  Future<void> pumpScreen(WidgetTester tester, {Size size = const Size(1440, 1400)}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const ExpensesScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders backend summary KPIs, localized statuses, and the expense table',
    (WidgetTester tester) async {
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          expenseRows: <Map<String, dynamic>>[_draftRow()],
          categories: <ExpenseCategory>[_rentCategory()],
          summary: const <String, dynamic>{
            'count': 1,
            'totalAmount': '15.50',
            'pendingApprovalAmount': '0.00',
            'rejectedAmount': '0.00',
            'averageAmount': '15.50',
          },
        ),
      );
      await pumpScreen(tester);

      expect(find.text('إجمالي المصروفات'), findsOneWidget);
      expect(find.text('بانتظار الموافقة'), findsOneWidget);
      expect(find.text('مرفوضة'), findsOneWidget);
      expect(find.text('متوسط المصروف'), findsOneWidget);
      expect(find.text('EXP-000001'), findsOneWidget);
      expect(find.text('August rent'), findsOneWidget);
      expect(find.text('Rent'), findsWidgets);
      expect(find.text('قيد المراجعة'), findsOneWidget); // draft badge
      expect(find.text('draft'), findsNothing); // raw backend code must not leak
    },
  );

  testWidgets('shows the empty state when there are no expenses', (
    WidgetTester tester,
  ) async {
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(categories: <ExpenseCategory>[_rentCategory()]),
    );
    await pumpScreen(tester);
    expect(find.text('لا توجد مصروفات مسجلة للفترة المحددة'), findsOneWidget);
  });

  testWidgets('shows a loading state before the first load resolves', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(gate: gate),
    );
    await tester.pumpWidget(app(const ExpensesScreen()));
    await tester.pump();
    expect(find.text('جارٍ تحميل المصروفات…'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مصروفات مسجلة للفترة المحددة'), findsOneWidget);
  });

  testWidgets('shows error and retry without treating errors as zero', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(failFirstLoad: () => calls++ == 0),
    );
    await tester.pumpWidget(app(const ExpensesScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذّر تحميل المصروفات'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مصروفات مسجلة للفترة المحددة'), findsOneWidget);
  });

  testWidgets(
    'global branch context and the status filter both narrow the list, and clearing filters preserves the branch',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          expenseRows: <Map<String, dynamic>>[_draftRow()],
          categories: <ExpenseCategory>[_rentCategory()],
          branchRows: <Map<String, dynamic>>[
            <String, dynamic>{'id': 2, 'name': 'فرع دمشق'},
          ],
          onListQuery: queries.add,
        ),
      );
      await tester.pumpWidget(app(const ExpensesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('الفرع: فرع دمشق').last);
      await tester.pumpAndSettle();
      expect(queries.last['branchId'], 2);
      expect(queries.last['page'], 1);

      await tester.tap(find.text('الحالة: الكل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مسودة').last);
      await tester.pumpAndSettle();
      expect(queries.last['status'], 'draft');
      expect(queries.last['branchId'], 2, reason: 'branch context is preserved');

      await tester.tap(find.text('إعادة تعيين'));
      await tester.pumpAndSettle();
      expect(queries.last['status'], isNull);
      expect(
        queries.last['branchId'],
        2,
        reason: 'clearing local filters keeps the global branch context',
      );
    },
  );

  testWidgets('create expense dialog validates required fields then submits the real payload', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? submitted;
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(
        categories: <ExpenseCategory>[_rentCategory()],
        onSave: (Map<String, dynamic> payload, int? id) async {
          submitted = payload;
        },
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('إضافة مصروف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل مبلغاً صالحاً، فئة، ووصفاً.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), '40.00');
    await tester.enterText(find.widgetWithText(TextField, 'الوصف'), 'صيانة');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!['amount'], '40.00');
    expect(submitted!['description'], 'صيانة');
    expect(submitted!['expenseCategoryId'], _rentCategory().id);
    expect(find.text('حفظ'), findsNothing, reason: 'dialog closed after saving');
  });

  testWidgets(
    'pending-approval detail shows only backend-allowed actions and rejecting requires a reason',
    (WidgetTester tester) async {
      final List<Map<String, dynamic>?> rejectCalls = <Map<String, dynamic>?>[];
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          expenseRows: <Map<String, dynamic>>[
            _pendingRow(allowedActions: const <String>['reject']),
          ],
          categories: <ExpenseCategory>[_rentCategory()],
          onAction: (int id, String action, Map<String, dynamic>? payload) async {
            if (action == 'reject') rejectCalls.add(payload);
          },
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('صيانة القهوة'));
      await tester.pumpAndSettle();
      // The creator cannot approve their own expense — only reject is offered.
      expect(find.text('اعتماد'), findsNothing);
      expect(find.text('رفض'), findsOneWidget);

      await tester.tap(find.text('رفض'));
      await tester.pumpAndSettle();
      final Finder confirmReject = find.widgetWithText(TextButton, 'رفض');
      expect(tester.widget<TextButton>(confirmReject).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'سبب الرفض'), 'تجاوز الميزانية');
      await tester.pumpAndSettle();
      await tester.tap(confirmReject);
      await tester.pumpAndSettle();

      expect(rejectCalls, hasLength(1));
      expect(rejectCalls.single!['rejectionReason'], 'تجاوز الميزانية');
    },
  );

  testWidgets('approved detail pays through the real flow with the accounting impact preview', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? paid;
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(
        expenseRows: <Map<String, dynamic>>[
          _approvedRow(allowedActions: const <String>['pay']),
        ],
        categories: <ExpenseCategory>[_rentCategory()],
        paymentMethods: <PaymentMethodSetting>[_cashMethod()],
        locations: <FinancialLocation>[_cashDrawer()],
        onPay: (int id, Map<String, dynamic> payload) async {
          paid = payload;
        },
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('صيانة القهوة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل دفعة'));
    await tester.pumpAndSettle();

    expect(find.text('الأثر المحاسبي المتوقع'), findsOneWidget);
    await tester.tap(find.text('ترحيل الدفع'));
    await tester.pumpAndSettle();

    expect(paid, isNotNull);
    expect(paid!['paymentMethodId'], _cashMethod().id);
    expect(paid!['financialLocationId'], _cashDrawer().id);
  });

  testWidgets('paid expense is immutable and its journal action opens the shared journal drawer', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/finance/expenses',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/expenses',
          builder: (_, _) => const Scaffold(body: ExpensesScreen()),
        ),
        GoRoute(
          path: '/finance/journal-entries/:id',
          builder: (_, GoRouterState state) =>
              Scaffold(body: Text('journal-route-${state.pathParameters['id']}')),
        ),
      ],
    );
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(
        expenseRows: <Map<String, dynamic>>[
          _paidRow(allowedActions: const <String>[]),
        ],
        categories: <ExpenseCategory>[_rentCategory()],
        detail: (int id) => <String, dynamic>{
          'id': id,
          'reference': 'JE-900',
          'transactionDate': '2026-08-21',
          'description': 'صيانة القهوة',
          'branch': <String, dynamic>{'name': 'فرع دمشق'},
          'source': <String, dynamic>{
            'type': 'expense',
            'normalizedType': 'expense',
            'resourceKind': 'expense',
            'id': 5,
            'available': true,
          },
          'displayAmount': <String, dynamic>{'amount': '40.00'},
          'reversal': <String, dynamic>{'state': 'none'},
          'journal': <String, dynamic>{
            'id': id,
            'status': 'posted',
            'lines': <Map<String, dynamic>>[],
          },
        },
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('صيانة القهوة'));
    await tester.pumpAndSettle();
    // A paid expense with no allowedActions offers no mutation button.
    expect(find.text('تعديل'), findsNothing);
    expect(find.text('عكس المصروف'), findsNothing);

    await tester.tap(find.text('عرض القيد'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
    expect(find.text('JE-900'), findsOneWidget);
  });

  testWidgets('opening the screen with ?expenseId auto-opens that expense detail', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/finance/expenses?expenseId=1',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance/expenses',
          builder: (_, _) => const Scaffold(body: ExpensesScreen()),
        ),
      ],
    );
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(
        expenseRows: <Map<String, dynamic>>[_draftRow()],
        categories: <ExpenseCategory>[_rentCategory()],
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('EXP-000001 — August rent'), findsOneWidget);
  });

  testWidgets('remains overflow-free at Finance desktop widths', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[
      const Size(1280, 900),
      const Size(1366, 900),
      const Size(1440, 900),
      const Size(1600, 900),
      const Size(1920, 1080),
    ]) {
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          expenseRows: <Map<String, dynamic>>[_draftRow()],
          categories: <ExpenseCategory>[_rentCategory()],
        ),
      );
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(app(const ExpensesScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await serviceLocator.reset();
    }
    await tester.binding.setSurfaceSize(null);
  });
}

Map<String, dynamic> _draftRow() => <String, dynamic>{
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
  'status': 'draft',
  'paymentStatus': 'unpaid',
  'allowedActions': <String>['edit', 'submit'],
};

Map<String, dynamic> _pendingRow({required List<String> allowedActions}) => <String, dynamic>{
  'id': 2,
  'expenseNumber': 'EXP-000002',
  'branchId': null,
  'branchName': null,
  'expenseCategoryId': 4,
  'expenseCategoryCode': 'RENT',
  'expenseCategoryName': 'Rent',
  'amount': '40.00',
  'taxAmount': '0.00',
  'totalAmount': '40.00',
  'expenseDate': '2026-08-20',
  'description': 'صيانة القهوة',
  'status': 'pending_approval',
  'paymentStatus': 'unpaid',
  'allowedActions': allowedActions,
};

Map<String, dynamic> _approvedRow({required List<String> allowedActions}) => <String, dynamic>{
  'id': 3,
  'expenseNumber': 'EXP-000003',
  'branchId': null,
  'branchName': null,
  'expenseCategoryId': 4,
  'expenseCategoryCode': 'RENT',
  'expenseCategoryName': 'Rent',
  'amount': '40.00',
  'taxAmount': '0.00',
  'totalAmount': '40.00',
  'expenseDate': '2026-08-20',
  'description': 'صيانة القهوة',
  'status': 'approved',
  'paymentStatus': 'unpaid',
  'allowedActions': allowedActions,
};

Map<String, dynamic> _paidRow({required List<String> allowedActions}) => <String, dynamic>{
  'id': 5,
  'expenseNumber': 'EXP-000005',
  'branchId': null,
  'branchName': null,
  'expenseCategoryId': 4,
  'expenseCategoryCode': 'RENT',
  'expenseCategoryName': 'Rent',
  'amount': '40.00',
  'taxAmount': '0.00',
  'totalAmount': '40.00',
  'expenseDate': '2026-08-21',
  'description': 'صيانة القهوة',
  'status': 'paid',
  'paymentStatus': 'paid',
  'journalEntryId': 900,
  'allowedActions': allowedActions,
};

ExpenseCategory _rentCategory() => const ExpenseCategory(
  id: 4,
  code: 'RENT',
  name: 'Rent',
  financialAccountId: 12,
  financialAccountCode: '6100',
  financialAccountName: 'Rent Expense',
  isActive: true,
);

PaymentMethodSetting _cashMethod() => const PaymentMethodSetting(
  id: 1,
  code: 'CASH',
  name: 'Cash',
  type: 'cash',
  financialAccountId: 2,
  financialAccountCode: '1010',
  isActive: true,
);

FinancialLocation _cashDrawer() => const FinancialLocation(
  id: 3,
  code: 'CASH-DRAWER',
  name: 'Cash Drawer',
  kind: 'cash',
  type: 'cash_drawer',
  financialAccountId: 2,
  financialAccountCode: '1010',
  balance: '500.00',
  todayIncoming: '0.00',
  todayOutgoing: '0.00',
  isActive: true,
);

typedef _SaveCallback = Future<void> Function(Map<String, dynamic> payload, int? id);
typedef _ActionCallback = Future<void> Function(int id, String action, Map<String, dynamic>? payload);
typedef _PayCallback = Future<void> Function(int id, Map<String, dynamic> payload);

class _FakeRepository extends FinanceSetupRepository {
  _FakeRepository({
    this.expenseRows = const <Map<String, dynamic>>[],
    this.categories = const <ExpenseCategory>[],
    this.branchRows = const <Map<String, dynamic>>[],
    this.summary = const <String, dynamic>{},
    this.paymentMethods = const <PaymentMethodSetting>[],
    this.locations = const <FinancialLocation>[],
    this.detail,
    this.onAction,
    this.onPay,
    this.onSave,
    this.onListQuery,
    this.failFirstLoad,
    this.gate,
  }) : super(DioApiClient(dio: Dio()));

  final List<Map<String, dynamic>> expenseRows;
  final List<ExpenseCategory> categories;
  final List<Map<String, dynamic>> branchRows;
  final Map<String, dynamic> summary;
  final List<PaymentMethodSetting> paymentMethods;
  final List<FinancialLocation> locations;
  final Map<String, dynamic> Function(int id)? detail;
  final _ActionCallback? onAction;
  final _PayCallback? onPay;
  final _SaveCallback? onSave;
  final void Function(Map<String, dynamic> query)? onListQuery;
  final bool Function()? failFirstLoad;
  final Completer<void>? gate;

  @override
  Future<List<ExpenseCategory>> getExpenseCategories() async => categories;

  @override
  Future<List<PaymentMethodSetting>> getPaymentMethods() async => paymentMethods;

  @override
  Future<List<FinancialLocation>> getFinancialLocations(String kind) async =>
      locations.where((FinancialLocation l) => l.kind == kind).toList();

  @override
  Future<FinancePage<Map<String, dynamic>>> getFinancePage(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (gate != null) await gate!.future;
    if (failFirstLoad?.call() ?? false) throw StateError('offline');
    onListQuery?.call(queryParameters ?? const <String, dynamic>{});
    return FinancePage<Map<String, dynamic>>(
      items: expenseRows,
      meta: FinancePageMeta(
        currentPage: 1,
        perPage: 10,
        total: expenseRows.length,
        lastPage: 1,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getFinanceMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path == 'finance/expenses/summary') return summary;
    if (path == 'finance/expenses/branches') {
      return <String, dynamic>{'branches': branchRows};
    }
    if (path.startsWith('finance/transactions/')) {
      final int id = int.parse(path.split('/').last);
      return detail?.call(id) ?? <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  @override
  Future<ExpenseRecord> getExpense(int id) async => ExpenseRecord.fromJson(
    expenseRows.firstWhere((Map<String, dynamic> r) => r['id'] == id),
  );

  @override
  Future<void> saveExpense(Map<String, dynamic> payload, {int? id}) async =>
      onSave?.call(payload, id);

  @override
  Future<void> expenseAction(
    int id,
    String action, [
    Map<String, dynamic>? payload,
  ]) async => onAction?.call(id, action, payload);

  @override
  Future<void> payExpense(int id, Map<String, dynamic> payload) async =>
      onPay?.call(id, payload);
}
