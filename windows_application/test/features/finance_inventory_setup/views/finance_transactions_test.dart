import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/features/finance_inventory_setup/models/finance_setup_models.dart';
import 'package:windows_application/features/finance_inventory_setup/views/finance_transactions.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_pagination.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_shell.dart';

void main() {
  Future<Map<String, dynamic>> branches() async => <String, dynamic>{
    'branches': <Map<String, dynamic>>[
      <String, dynamic>{'id': 2, 'name': 'فرع دمشق'},
    ],
  };
  Future<List<FinancialAccount>> accounts() async => const <FinancialAccount>[
    FinancialAccount(
      id: 10,
      code: '5010',
      nameAr: 'مصروفات تشغيلية',
      nameEn: 'Operating Expenses',
      accountGroup: 'expenses',
      normalBalance: 'debit',
      isActive: true,
      isSystemProtected: false,
    ),
  ];
  Future<List<PaymentMethodSetting>> paymentMethods() async =>
      const <PaymentMethodSetting>[
        PaymentMethodSetting(
          id: 5,
          code: 'cash',
          name: 'نقدي',
          type: 'cash',
          financialAccountId: 1,
          financialAccountCode: '1010',
          isActive: true,
        ),
      ];

  Widget app(Widget child) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );

  FinanceTransactionsView view({
    required FinanceTransactionsLoader loader,
    FinanceTransactionDetailLoader? detailLoader,
    Key? key,
  }) => FinanceTransactionsView(
    key: key,
    loader: loader,
    detailLoader: detailLoader ?? (int id) async => _detail(id),
    branchesLoader: branches,
    accountsLoader: accounts,
    paymentMethodsLoader: paymentMethods,
  );

  testWidgets(
    'renders backend summary KPIs, localized type/status, and reversed rows',
    (WidgetTester tester) async {
      await tester.pumpWidget(app(view(loader: (_) async => _payload())));
      await tester.pumpAndSettle();

      expect(find.text('إجمالي الحركات'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('إجمالي الداخل'), findsOneWidget);
      expect(find.text('إجمالي الخارج'), findsOneWidget);
      expect(find.text('القيود المسودة'), findsOneWidget);
      expect(find.text('الحركات المعكوسة'), findsOneWidget);

      // Raw backend codes must never leak; only the mapped Arabic label shows.
      expect(find.text('expense'), findsNothing);
      expect(find.text('pos_order'), findsNothing);
      expect(find.text('مصروف'), findsOneWidget);
      expect(find.text('مبيعات'), findsOneWidget);
      expect(find.text('معكوس'), findsOneWidget);
      expect(find.text('JE-2026-000501'), findsOneWidget);
      expect(find.text('500.00 SYP'), findsWidgets);
    },
  );

  testWidgets(
    'shows loading, error and retry without treating errors as zero',
    (WidgetTester tester) async {
      final Completer<FinanceTransactionsPayload> loading =
          Completer<FinanceTransactionsPayload>();
      await tester.pumpWidget(app(view(loader: (_) => loading.future)));
      expect(find.text('جارٍ تحميل الحركات المالية…'), findsOneWidget);

      int calls = 0;
      await tester.pumpWidget(
        app(
          view(
            key: UniqueKey(),
            loader: (_) async {
              calls++;
              if (calls == 1) throw StateError('offline');
              return _payload();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('تعذّر تحميل الحركات المالية'),
        findsOneWidget,
      );
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('إجمالي الحركات'), findsOneWidget);
    },
  );

  testWidgets(
    'period, branch, and filter changes reset to page 1 and preserve other filters',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final List<FinanceTransactionsQuery> queries = <FinanceTransactionsQuery>[];
      await tester.pumpWidget(
        app(
          view(
            loader: (FinanceTransactionsQuery query) async {
              queries.add(query);
              return _payload(page: query.page);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('اليوم'));
      await tester.pumpAndSettle();
      expect(queries.last.dateFrom, queries.last.dateTo);
      expect(queries.last.page, 1);

      await tester.tap(find.byType(DropdownButton<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('الفرع: فرع دمشق').last);
      await tester.pumpAndSettle();
      expect(queries.last.branchId, 2);
      expect(queries.last.page, 1);

      await tester.tap(find.text('نوع الحركة: الكل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مصروف').last);
      await tester.pumpAndSettle();
      expect(queries.last.filters.sourceType, 'expense');
      expect(queries.last.branchId, 2, reason: 'branch filter is preserved');

      await tester.tap(find.text('الحالة: الكل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مرحّل').last);
      await tester.pumpAndSettle();
      expect(queries.last.filters.status, 'posted');
      expect(
        queries.last.filters.sourceType,
        'expense',
        reason: 'type filter is preserved',
      );

      await tester.tap(find.text('إعادة تعيين'));
      await tester.pumpAndSettle();
      expect(queries.last.filters.sourceType, isNull);
      expect(queries.last.filters.status, isNull);
      expect(
        queries.last.branchId,
        2,
        reason: 'clearing local filters keeps the global branch context',
      );
    },
  );

  testWidgets('search debounces before triggering a backend request', (
    WidgetTester tester,
  ) async {
    final List<FinanceTransactionsQuery> queries = <FinanceTransactionsQuery>[];
    await tester.pumpWidget(
      app(
        view(
          loader: (FinanceTransactionsQuery query) async {
            queries.add(query);
            return _payload();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final int before = queries.length;

    await tester.enterText(find.byType(TextField), 'JE-2026');
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      queries.length,
      before,
      reason: 'debounce must not fire a request per keystroke',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(queries.last.filters.search, 'JE-2026');
  });

  testWidgets('empty filtered result offers to clear active filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        view(
          loader: (FinanceTransactionsQuery query) async =>
              FinanceTransactionsPayload(
                summary: _payload().summary,
                page: const FinancePage<Map<String, dynamic>>(
                  items: <Map<String, dynamic>>[],
                  meta: FinancePageMeta(
                    currentPage: 1,
                    perPage: 10,
                    total: 0,
                    lastPage: 1,
                  ),
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد حركات مالية للفترة المحددة'), findsOneWidget);
  });

  testWidgets(
    'row tap opens the journal drawer with lazy-loaded impact lines and navigation',
    (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/finance',
        routes: <RouteBase>[
          GoRoute(
            path: '/finance',
            builder: (_, _) => Scaffold(
              body: FinanceShell(
                currentSection: 'الحركات المالية',
                child: view(loader: (_) async => _payload()),
              ),
            ),
          ),
          GoRoute(
            path: '/finance/expenses',
            builder: (_, _) => const Scaffold(body: Text('expenses-route')),
          ),
          GoRoute(
            path: '/finance/journal-entries/:id',
            builder: (_, GoRouterState state) =>
                Scaffold(body: Text('journal-route-${state.pathParameters['id']}')),
          ),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(1440, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('دفعة كهرباء'));
      await tester.pump();
      expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
      expect(find.text('جارٍ تحميل تفاصيل القيد…'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('1010 — الصندوق'), findsOneWidget);
      expect(find.text('عرض المصدر'), findsOneWidget);
      expect(find.text('عرض القيد'), findsOneWidget);

      await tester.tap(find.text('عرض المصدر'));
      await tester.pumpAndSettle();
      expect(find.text('expenses-route'), findsOneWidget);
    },
  );

  testWidgets('journal drawer shows an error with retry when detail loading fails', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int calls = 0;
    await tester.pumpWidget(
      app(
        view(
          loader: (_) async => _payload(),
          detailLoader: (int id) async {
            calls++;
            if (calls == 1) throw StateError('offline');
            return _detail(id);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('دفعة كهرباء'));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر تحميل تفاصيل القيد.'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('1010 — الصندوق'), findsOneWidget);
  });

  testWidgets('remains overflow-free at Finance desktop widths', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[
      const Size(1280, 800),
      const Size(1440, 900),
      const Size(1600, 900),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        app(
          FinanceShell(
            currentSection: 'الحركات المالية',
            child: view(loader: (_) async => _payload()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}

FinanceTransactionsPayload _payload({int page = 1}) => FinanceTransactionsPayload(
  summary: const <String, dynamic>{
    'transactionCount': 12,
    'externalCashInflow': '5000.00',
    'externalCashOutflow': '1200.00',
    'draftJournalCount': 2,
    'reversedOriginalCount': 1,
  },
  page: FinancePage<Map<String, dynamic>>(
    items: const <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 501,
        'reference': 'JE-2026-000501',
        'transactionDate': '2026-09-01',
        'description': 'دفعة كهرباء',
        'branch': <String, dynamic>{'id': 2, 'name': 'فرع دمشق'},
        'source': <String, dynamic>{
          'type': 'expense',
          'normalizedType': 'expense',
          'resourceKind': 'expense',
          'id': 77,
          'available': true,
        },
        'displayAmount': <String, dynamic>{'amount': '500.00'},
        'journal': <String, dynamic>{
          'id': 501,
          'status': 'posted',
          'totalDebit': '500.00',
          'totalCredit': '500.00',
        },
        'reversal': <String, dynamic>{'state': 'none'},
      },
      <String, dynamic>{
        'id': 502,
        'reference': 'JE-2026-000502',
        'transactionDate': '2026-09-02',
        'description': 'فاتورة مبيعات',
        'branch': <String, dynamic>{'id': 2, 'name': 'فرع دمشق'},
        'source': <String, dynamic>{
          'type': 'pos_order',
          'normalizedType': 'sale',
          'resourceKind': 'order',
          'id': 900,
          'available': true,
        },
        'displayAmount': <String, dynamic>{'amount': '1200.00'},
        'journal': <String, dynamic>{
          'id': 502,
          'status': 'posted',
          'totalDebit': '1200.00',
          'totalCredit': '1200.00',
        },
        'reversal': <String, dynamic>{'state': 'original_reversed'},
      },
    ],
    meta: FinancePageMeta(currentPage: page, perPage: 10, total: 2, lastPage: 1),
  ),
);

Map<String, dynamic> _detail(int id) => <String, dynamic>{
  'id': id,
  'reference': 'JE-2026-000501',
  'transactionDate': '2026-09-01',
  'description': 'دفعة كهرباء',
  'branch': <String, dynamic>{'id': 2, 'name': 'فرع دمشق'},
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
    'id': id,
    'status': 'posted',
    'totalDebit': '500.00',
    'totalCredit': '500.00',
    'lines': <Map<String, dynamic>>[
      <String, dynamic>{
        'accountCode': '5010',
        'accountNameAr': 'مصروفات تشغيلية',
        'debit': '500.00',
        'credit': '0.00',
      },
      <String, dynamic>{
        'accountCode': '1010',
        'accountNameAr': 'الصندوق',
        'debit': '0.00',
        'credit': '500.00',
      },
    ],
  },
};
