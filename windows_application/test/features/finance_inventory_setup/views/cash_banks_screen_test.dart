import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/finance_inventory_setup/models/finance_setup_models.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/cash_banks_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_pagination.dart';
import 'package:windows_application/features/pos/models/branch.dart';

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
    await tester.pumpWidget(app(const CashBanksScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders backend-authoritative KPIs, the configuration warning, and cash/bank sections',
    (WidgetTester tester) async {
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          cash: <FinancialLocation>[_cashDrawer()],
          bank: <FinancialLocation>[_bankAccount()],
          paymentMethods: <PaymentMethodSetting>[_unlinkedWallet()],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('إجمالي النقدية'), findsOneWidget);
      expect(find.text('إجمالي البنوك'), findsOneWidget);
      expect(find.text('الداخل اليوم'), findsOneWidget);
      expect(find.text('الخارج اليوم'), findsOneWidget);
      expect(
        find.textContaining('طريقة دفع غير مربوطة بحساب مالي'),
        findsOneWidget,
      );
      expect(find.textContaining('محفظة رقمية'), findsOneWidget);
      expect(find.text('النقدية'), findsOneWidget);
      expect(find.text('البنوك'), findsOneWidget);
      expect(find.text('الصندوق الرئيسي'), findsOneWidget);
      expect(find.text('حساب البنك الأهلي'), findsOneWidget);
      expect(find.text('نشط'), findsWidgets);
      // Raw backend source codes must never leak.
      expect(find.text('cash_drawer'), findsNothing);
    },
  );

  testWidgets('hides the configuration warning when every active payment method is linked', (
    WidgetTester tester,
  ) async {
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(
        cash: <FinancialLocation>[_cashDrawer()],
        paymentMethods: <PaymentMethodSetting>[
          const PaymentMethodSetting(
            id: 9,
            code: 'cash',
            name: 'نقدي',
            type: 'cash',
            financialAccountId: 1,
            financialAccountCode: '1010',
            isActive: true,
            financialLocationId: 501,
            financialLocationName: 'الصندوق الرئيسي',
          ),
        ],
      ),
    );
    await pumpScreen(tester);
    expect(find.textContaining('طريقة دفع غير مربوطة بحساب مالي'), findsNothing);
  });

  testWidgets('empty cash and bank sections show their own empty state', (
    WidgetTester tester,
  ) async {
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(),
    );
    await pumpScreen(tester);
    expect(find.text('لا توجد حسابات نقدية'), findsOneWidget);
    expect(find.text('لا توجد حسابات بنكية'), findsOneWidget);
  });

  testWidgets('shows a loading state before the first load resolves', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(gate: gate),
    );
    await tester.pumpWidget(app(const CashBanksScreen()));
    await tester.pump();
    expect(find.text('جارٍ تحميل النقدية والبنوك…'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('لا توجد حسابات نقدية'), findsOneWidget);
  });

  testWidgets('shows error and retry without treating errors as zero', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(
        failFirstLoad: () => calls++ == 0,
      ),
    );
    await tester.pumpWidget(app(const CashBanksScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذّر تحميل النقدية والبنوك'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد حسابات نقدية'), findsOneWidget);
  });

  testWidgets('create account dialog validates required fields then submits the real payload', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? submitted;
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(
        accounts: <FinancialAccount>[_ledgerAccount()],
        branches: <Branch>[
          const Branch(id: 3, name: 'فرع دمشق', currency: 'SYP', timezone: 'Asia/Damascus', isActive: true),
        ],
        onSave: (String kind, Map<String, dynamic> payload, int? id) async {
          submitted = payload;
        },
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('حساب جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('أكمل الحقول المطلوبة.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'الرمز'), 'CASH-2');
    await tester.enterText(find.widgetWithText(TextField, 'الاسم'), 'صندوق فرعي');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!['code'], 'CASH-2');
    expect(submitted!['name'], 'صندوق فرعي');
    expect(find.text('حفظ'), findsNothing, reason: 'dialog closed after saving');
  });

  testWidgets('toggling account status calls the real endpoint and refreshes', (
    WidgetTester tester,
  ) async {
    final List<bool> calls = <bool>[];
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => _FakeRepository(
        cash: <FinancialLocation>[_cashDrawer()],
        onStatus: (String kind, int id, bool isActive) async {
          calls.add(isActive);
        },
      ),
    );
    await pumpScreen(tester);
    await tester.tap(find.text('نشط').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعطيل'));
    await tester.pumpAndSettle();
    expect(calls, <bool>[false]);
  });

  testWidgets(
    'transfer dialog rejects equal accounts and non-positive amounts, then submits with the impact preview',
    (WidgetTester tester) async {
      Map<String, dynamic>? submitted;
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          cash: <FinancialLocation>[_cashDrawer()],
          bank: <FinancialLocation>[_bankAccount()],
          onTransfer: (Map<String, dynamic> payload) async {
            submitted = payload;
          },
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('تحويل بين الحسابات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ترحيل التحويل'));
      await tester.pumpAndSettle();
      expect(find.text('أدخل مبلغاً موجباً صحيحاً.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), '150.00');
      await tester.pumpAndSettle();
      expect(find.byType(RichText).evaluate().isNotEmpty, isTrue);
      expect(find.text('الأثر المحاسبي المتوقع'), findsOneWidget);

      await tester.tap(find.text('ترحيل التحويل'));
      await tester.pumpAndSettle();
      expect(submitted, isNotNull);
      expect(submitted!['amount'], '150.00');
      expect(
        submitted!['fromFinancialLocationId'],
        isNot(submitted!['toFinancialLocationId']),
      );
    },
  );

  testWidgets(
    'the transfer picker excludes inactive accounts and disables when fewer than two active accounts remain',
    (WidgetTester tester) async {
      final FinancialLocation inactiveBank = FinancialLocation(
        id: _bankAccount().id,
        code: _bankAccount().code,
        name: 'حساب بنكي معطّل',
        kind: 'bank',
        type: 'bank',
        financialAccountId: _bankAccount().financialAccountId,
        financialAccountCode: _bankAccount().financialAccountCode,
        balance: _bankAccount().balance,
        todayIncoming: _bankAccount().todayIncoming,
        todayOutgoing: _bankAccount().todayOutgoing,
        isActive: false,
      );
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          cash: <FinancialLocation>[_cashDrawer()],
          bank: <FinancialLocation>[inactiveBank],
        ),
      );
      await pumpScreen(tester);

      // Two total accounts exist, but only one is active — the page-level
      // transfer action must stay disabled rather than open a dialog with
      // an unusable single-account picker.
      final Finder primaryTransfer = find.widgetWithText(
        ElevatedButton,
        'تحويل بين الحسابات',
      );
      expect(
        tester.widget<ElevatedButton>(primaryTransfer).onPressed,
        isNull,
      );
      expect(find.text('حساب بنكي معطّل'), findsOneWidget);
    },
  );

  testWidgets(
    'account detail shows real KPIs and movements, and a movement row opens the journal drawer',
    (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/finance/cash-banks',
        routes: <RouteBase>[
          GoRoute(
            path: '/finance/cash-banks',
            builder: (_, _) => const CashBanksScreen(),
          ),
          GoRoute(
            path: '/finance/expenses',
            builder: (_, _) => const Scaffold(body: Text('expenses-route')),
          ),
        ],
      );
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          cash: <FinancialLocation>[_cashDrawer()],
          locationTransactions: FinancialLocationTransactions(
            location: _cashDrawer(),
            transactions: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'date': '2026-09-01',
                'journalEntryId': 501,
                'entryNumber': 'JE-501',
                'sourceType': 'expense',
                'description': 'دفعة كهرباء',
                'debit': '0.00',
                'credit': '500.00',
                'runningBalance': '17500.00',
              },
            ],
          ),
          detail: <String, dynamic>{
            'id': 501,
            'reference': 'JE-501',
            'transactionDate': '2026-09-01',
            'description': 'دفعة كهرباء',
            'branch': <String, dynamic>{'name': 'فرع دمشق'},
            'source': <String, dynamic>{
              'type': 'expense',
              'normalizedType': 'expense',
              'resourceKind': 'expense',
              'id': 77,
              'available': true,
            },
            'displayAmount': <String, dynamic>{'amount': '500.00'},
            'reversal': <String, dynamic>{'state': 'none'},
            'journal': <String, dynamic>{
              'id': 501,
              'status': 'posted',
              'lines': <Map<String, dynamic>>[
                <String, dynamic>{
                  'accountCode': '5010',
                  'accountNameAr': 'مصروفات تشغيلية',
                  'debit': '500.00',
                  'credit': '0.00',
                },
              ],
            },
          },
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1440, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('الصندوق الرئيسي').first);
      await tester.pumpAndSettle();
      expect(find.text('الرصيد الحالي'), findsOneWidget);
      expect(find.text('دفعة كهرباء'), findsWidgets);

      await tester.tap(find.text('دفعة كهرباء').last);
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
      expect(find.text('عرض المصدر'), findsOneWidget);

      await tester.tap(find.text('عرض المصدر'));
      await tester.pumpAndSettle();
      expect(find.text('expenses-route'), findsOneWidget);
    },
  );

  testWidgets('remains overflow-free at Finance desktop widths', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[
      const Size(1280, 900),
      const Size(1440, 900),
      const Size(1600, 900),
    ]) {
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => _FakeRepository(
          cash: <FinancialLocation>[_cashDrawer()],
          bank: <FinancialLocation>[_bankAccount()],
        ),
      );
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(app(const CashBanksScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await serviceLocator.reset();
    }
    await tester.binding.setSurfaceSize(null);
  });
}

FinancialLocation _cashDrawer() => const FinancialLocation(
  id: 501,
  code: 'CASH-DRAWER',
  name: 'الصندوق الرئيسي',
  kind: 'cash',
  type: 'cash_drawer',
  financialAccountId: 1,
  financialAccountCode: '1010',
  financialAccountNameAr: 'الصندوق',
  balance: '18000.00',
  todayIncoming: '500.00',
  todayOutgoing: '120.00',
  isActive: true,
  branchName: 'فرع دمشق',
);

FinancialLocation _bankAccount() => const FinancialLocation(
  id: 502,
  code: 'BANK',
  name: 'حساب البنك الأهلي',
  kind: 'bank',
  type: 'bank',
  financialAccountId: 2,
  financialAccountCode: '1020',
  financialAccountNameAr: 'البنك',
  balance: '42000.00',
  todayIncoming: '0.00',
  todayOutgoing: '3000.00',
  isActive: true,
  bankName: 'البنك الأهلي',
  maskedReference: '****4821',
);

PaymentMethodSetting _unlinkedWallet() => const PaymentMethodSetting(
  id: 8,
  code: 'wallet',
  name: 'محفظة رقمية',
  type: 'other',
  financialAccountId: 3,
  financialAccountCode: '1030',
  isActive: true,
);

FinancialAccount _ledgerAccount() => const FinancialAccount(
  id: 1,
  code: '1010',
  nameAr: 'الصندوق',
  nameEn: 'Cash',
  accountGroup: 'assets',
  normalBalance: 'debit',
  isActive: true,
  isSystemProtected: false,
);

typedef _SaveCallback = Future<void> Function(String kind, Map<String, dynamic> payload, int? id);
typedef _StatusCallback = Future<void> Function(String kind, int id, bool isActive);
typedef _TransferCallback = Future<void> Function(Map<String, dynamic> payload);

class _FakeRepository extends FinanceSetupRepository {
  _FakeRepository({
    this.cash = const <FinancialLocation>[],
    this.bank = const <FinancialLocation>[],
    this.paymentMethods = const <PaymentMethodSetting>[],
    this.accounts = const <FinancialAccount>[],
    this.branches = const <Branch>[],
    this.onSave,
    this.onStatus,
    this.onTransfer,
    this.detail,
    this.locationTransactions,
    this.failFirstLoad,
    this.gate,
  }) : super(DioApiClient(dio: Dio()));

  final List<FinancialLocation> cash;
  final List<FinancialLocation> bank;
  final List<PaymentMethodSetting> paymentMethods;
  final List<FinancialAccount> accounts;
  final List<Branch> branches;
  final _SaveCallback? onSave;
  final _StatusCallback? onStatus;
  final _TransferCallback? onTransfer;
  final Map<String, dynamic>? detail;
  final FinancialLocationTransactions? locationTransactions;
  final bool Function()? failFirstLoad;
  final Completer<void>? gate;

  @override
  Future<List<FinancialLocation>> getFinancialLocations(String kind) async {
    if (gate != null) await gate!.future;
    if (failFirstLoad?.call() ?? false) throw StateError('offline');
    return kind == 'cash' ? cash : bank;
  }

  @override
  Future<List<PaymentMethodSetting>> getPaymentMethods() async => paymentMethods;

  @override
  Future<List<FinancialAccount>> getAccounts({
    String? search,
    String? group,
    String? status,
    String? system,
  }) async => accounts;

  @override
  Future<List<Branch>> getBranches() async => branches;

  @override
  Future<FinancePage<Map<String, dynamic>>> getFinancePage(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => const FinancePage<Map<String, dynamic>>(
    items: <Map<String, dynamic>>[],
    meta: FinancePageMeta.singlePage(),
  );

  @override
  Future<Map<String, dynamic>> saveFinancialLocation(
    String kind,
    Map<String, dynamic> payload, {
    int? id,
  }) async {
    await onSave?.call(kind, payload, id);
    return <String, dynamic>{};
  }

  @override
  Future<void> setFinancialLocationStatus(
    String kind,
    int id,
    bool isActive,
  ) async => onStatus?.call(kind, id, isActive);

  @override
  Future<void> createCashTransfer(Map<String, dynamic> payload) async =>
      onTransfer?.call(payload);

  @override
  Future<void> reverseCashTransfer(int id) async {}

  @override
  Future<FinancialLocationTransactions> getFinancialLocationTransactions(
    String kind,
    int id, {
    Map<String, dynamic>? queryParameters,
  }) async => locationTransactions!;

  @override
  Future<Map<String, dynamic>> getFinanceMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => detail ?? <String, dynamic>{};
}
