import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/features/finance_inventory_setup/views/finance_overview.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_shell.dart';

void main() {
  Future<FinanceOverviewPayload> data(FinanceOverviewQuery _) async =>
      _payload();

  Widget app(Widget child) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );

  testWidgets('renders the six live KPI concepts and all overview sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(FinanceOverview(loader: data)));
    await tester.pumpAndSettle();

    for (final String label in <String>[
      'صافي المبيعات',
      'إجمالي الربح',
      'المصروفات',
      'صافي الربح التشغيلي',
      'النقدية والبنوك',
      'مستحقات الموردين',
    ]) {
      expect(find.text(label), findsAtLeastNWidgets(1));
    }
    expect(find.text('يحتاج انتباهك'), findsOneWidget);
    expect(find.text('الإيرادات مقابل المصروفات'), findsOneWidget);
    expect(find.text('أداء الفروع'), findsOneWidget);
    expect(find.text('أحدث الحركات المالية'), findsOneWidget);
    expect(find.text('مصاريف تشغيل'), findsOneWidget);
  });

  testWidgets(
    'shows loading, error and retry without treating errors as zero',
    (WidgetTester tester) async {
      final Completer<FinanceOverviewPayload> loading =
          Completer<FinanceOverviewPayload>();
      await tester.pumpWidget(
        app(FinanceOverview(loader: (_) => loading.future)),
      );
      expect(find.text('جارٍ تحميل النظرة المالية…'), findsOneWidget);

      int calls = 0;
      await tester.pumpWidget(
        app(
          FinanceOverview(
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
      expect(find.textContaining('تعذّر تحميل النظرة المالية'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('صافي المبيعات'), findsOneWidget);
    },
  );

  testWidgets(
    'period, branch and comparison context trigger real loader queries',
    (WidgetTester tester) async {
      final List<FinanceOverviewQuery> queries = <FinanceOverviewQuery>[];
      await tester.pumpWidget(
        app(
          FinanceOverview(
            loader: (FinanceOverviewQuery query) async {
              queries.add(query);
              return _payload();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('اليوم'));
      await tester.pumpAndSettle();
      expect(queries.last.dateFrom, queries.last.dateTo);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الفرع: فرع دمشق').last);
      await tester.pumpAndSettle();
      expect(queries.last.branchId, 2);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(queries.last.comparison, isFalse);
    },
  );

  testWidgets('KPI and attention actions use canonical Finance routes', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/finance',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance',
          builder: (_, _) => Scaffold(body: FinanceOverview(loader: data)),
        ),
        GoRoute(
          path: '/finance/expenses',
          builder: (_, _) => const Scaffold(body: Text('expenses-route')),
        ),
        GoRoute(
          path: '/finance/cash-banks',
          builder: (_, _) => const Scaffold(body: Text('cash-route')),
        ),
        GoRoute(
          path: '/finance/suppliers',
          builder: (_, _) => const Scaffold(body: Text('suppliers-route')),
        ),
        GoRoute(
          path: '/finance/reconciliations',
          builder: (_, _) => const Scaffold(body: Text('reconciliation-route')),
        ),
        GoRoute(
          path: '/finance/daily-closings',
          builder: (_, _) => const Scaffold(body: Text('closing-route')),
        ),
        GoRoute(
          path: '/finance/journal-entries',
          builder: (_, _) => const Scaffold(body: Text('journal-route')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final Finder expenses = find
        .ancestor(
          of: find.byIcon(Icons.request_quote_outlined),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.ensureVisible(expenses);
    await tester.tap(expenses);
    await tester.pumpAndSettle();
    expect(find.text('expenses-route'), findsOneWidget);
  });

  testWidgets(
    'recent activity row navigates to the canonical source destination',
    (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/finance',
        routes: <RouteBase>[
          GoRoute(
            path: '/finance',
            builder: (_, _) => Scaffold(body: FinanceOverview(loader: data)),
          ),
          GoRoute(
            path: '/finance/expenses',
            builder: (_, _) => const Scaffold(body: Text('expenses-route')),
          ),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final Finder row = find.text('مصاريف تشغيل');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('expenses-route'), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('overview remains overflow-free at Finance desktop widths', (
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
            currentSection: 'نظرة عامة',
            child: FinanceOverview(loader: data),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}

FinanceOverviewPayload _payload() => const FinanceOverviewPayload(
  dashboard: <String, dynamic>{
    'context': <String, dynamic>{
      'branches': <Map<String, dynamic>>[
        <String, dynamic>{'id': 2, 'name': 'فرع دمشق'},
      ],
    },
    'kpis': <String, dynamic>{
      'netSales': <String, dynamic>{
        'current': '120000.00',
        'percentageChange': 12.5,
        'changeState': 'increase',
      },
      'grossProfit': <String, dynamic>{
        'current': '70000.00',
        'percentageChange': 8.0,
        'changeState': 'increase',
      },
      'operatingExpenses': <String, dynamic>{
        'current': '20000.00',
        'percentageChange': -3.0,
        'changeState': 'decrease',
      },
      'operatingProfit': <String, dynamic>{
        'current': '50000.00',
        'percentageChange': 10.0,
        'changeState': 'increase',
      },
      'cashBanks': <String, dynamic>{
        'total': '90000.00',
        'percentageChange': 4.0,
        'changeState': 'increase',
      },
      'supplierPayables': <String, dynamic>{
        'outstanding': '12000.00',
        'percentageChange': -2.0,
        'changeState': 'decrease',
      },
    },
    'alerts': <Map<String, dynamic>>[
      <String, dynamic>{
        'code': 'PENDING_EXPENSE_APPROVAL',
        'severity': 'warning',
        'metadata': <String, dynamic>{'count': 2},
        'branch': <String, dynamic>{'name': 'فرع دمشق'},
        'amount': '500.00',
      },
    ],
    'recentTransactions': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 501,
        'reference': 'JV-1001',
        'transactionDate': '2026-09-01',
        'source': <String, dynamic>{
          'type': 'expense',
          'normalizedType': 'expense',
          'resourceKind': 'expense',
          'id': 77,
          'available': true,
        },
        'description': 'مصاريف تشغيل',
        'branch': <String, dynamic>{'name': 'فرع دمشق'},
        'displayAmount': '500.00',
        'journal': <String, dynamic>{'id': 501, 'status': 'posted'},
      },
    ],
  },
  trends: <String, dynamic>{
    'revenueVsExpenses': <String, dynamic>{
      'granularity': 'day',
      'series': <Map<String, dynamic>>[
        <String, dynamic>{
          'periodStart': '2026-09-01',
          'netSales': '120000.00',
          'operatingExpenses': '20000.00',
        },
        <String, dynamic>{
          'periodStart': '2026-09-02',
          'netSales': '90000.00',
          'operatingExpenses': '30000.00',
        },
      ],
    },
  },
  branches: <String, dynamic>{
    'branches': <Map<String, dynamic>>[
      <String, dynamic>{
        'branch': <String, dynamic>{'id': 2, 'name': 'فرع دمشق'},
        'netSales': '120000.00',
      },
    ],
  },
);
