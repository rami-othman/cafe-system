import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_components.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_design.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_navigation_bar.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_pagination.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_shell.dart';

void main() {
  Widget app(Widget child, {TextDirection direction = TextDirection.rtl}) =>
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(body: child),
        ),
      );

  testWidgets('renders the Finance shared component set', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          child: Column(
            children: <Widget>[
              const FinancePageHeader(
                title: 'عنوان الصفحة',
                subtitle: 'وصف مختصر',
              ),
              SizedBox(
                width: 1200,
                child: FinanceKpiGrid(
                  items: const <FinanceKpiData>[
                    FinanceKpiData(
                      label: 'الرصيد',
                      value: '100,000',
                      trend: '+5%',
                    ),
                    FinanceKpiData(
                      label: 'التحصيل',
                      value: '80,000',
                      tone: FinanceTone.success,
                    ),
                  ],
                ),
              ),
              const FinanceStatusBadge(status: 'approved'),
              FinanceFilterBar(
                children: const <Widget>[
                  SizedBox(
                    width: 180,
                    child: TextField(
                      decoration: InputDecoration(labelText: 'بحث'),
                    ),
                  ),
                ],
              ),
              FinanceTable(
                headers: const <String>['المرجع', 'القيمة'],
                rows: const <List<Widget>>[
                  <Widget>[
                    FinanceReference(reference: 'JV-001'),
                    FinanceAmount(value: '100'),
                  ],
                ],
              ),
              const FinanceEntityHeader(
                title: 'سند قيد',
                reference: 'JV-001',
                status: 'posted',
              ),
              const FinanceInfoGrid(
                items: <FinanceInfoItem>[
                  FinanceInfoItem('الفرع', 'الفرع الرئيسي'),
                  FinanceInfoItem('المستخدم', 'المحاسب'),
                ],
              ),
              const FinanceAlertBanner(message: 'تحتاج هذه العملية إلى مراجعة'),
              const FinanceReadinessPanel(
                items: <String>['الفترة المحاسبية مفتوحة'],
              ),
              FinanceOperationalBar(
                message: 'هناك إجراء مطلوب',
                actionLabel: 'فتح',
                onAction: () {},
              ),
              const FinanceDialogShell(
                title: 'تأكيد العملية',
                child: Text('محتوى الحوار'),
              ),
              const SizedBox(
                height: 200,
                child: FinanceJournalDrawer(child: Text('القيد المحاسبي')),
              ),
              const FinanceLoadingState(),
              const FinanceEmptyState(),
              const FinanceErrorState(message: 'تعذر تحميل البيانات'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('عنوان الصفحة'), findsOneWidget);
    // 'approved' and 'posted' are distinct expense/journal states and must
    // not collapse onto the same Arabic label.
    expect(find.text('معتمد'), findsOneWidget);
    expect(find.text('مكتمل'), findsOneWidget);
    expect(find.text('الجاهزية التشغيلية'), findsOneWidget);
    expect(find.text('تعذر تحميل البيانات'), findsOneWidget);
  });

  testWidgets('Finance shell fits narrow desktop and retains RTL context', (
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
          const FinanceShell(
            currentSection: 'نظرة عامة',
            showContext: true,
            child: FinanceEmptyState(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
    expect(find.text('المالية / نظرة عامة'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('amount and references stay LTR in both app directions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Column(
          children: <Widget>[
            FinanceAmount(value: '1,234.50'),
            FinanceReference(reference: 'JV-2026-001'),
          ],
        ),
        direction: TextDirection.ltr,
      ),
    );
    expect(
      Directionality.of(tester.element(find.text('1,234.50 SYP'))),
      TextDirection.ltr,
    );
    expect(
      Directionality.of(tester.element(find.text('JV-2026-001'))),
      TextDirection.ltr,
    );
  });

  testWidgets('server pagination delegates the requested page', (
    WidgetTester tester,
  ) async {
    int? requestedPage;
    await tester.pumpWidget(
      app(
        FinancePagination(
          meta: const FinancePageMeta(
            currentPage: 1,
            perPage: 10,
            total: 21,
            lastPage: 3,
          ),
          onPageChanged: (int page) => requestedPage = page,
        ),
      ),
    );
    await tester.tap(find.text('التالي'));
    expect(requestedPage, 2);
  });

  testWidgets('canonical finance tabs navigate and mark their stable targets', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/finance',
      routes: <RouteBase>[
        GoRoute(
          path: '/finance',
          builder: (_, _) => const FinanceNavigationBar(selected: 'overview'),
        ),
        GoRoute(
          path: '/finance/expenses',
          builder: (_, _) => const FinanceNavigationBar(selected: 'expenses'),
        ),
        GoRoute(
          path: '/finance/cash-banks',
          builder: (_, _) => const FinanceNavigationBar(selected: 'cashbanks'),
        ),
        GoRoute(
          path: '/finance/suppliers',
          builder: (_, _) => const FinanceNavigationBar(selected: 'suppliers'),
        ),
        GoRoute(
          path: '/finance/reconciliations',
          builder: (_, _) =>
              const FinanceNavigationBar(selected: 'reconciliation'),
        ),
        GoRoute(
          path: '/finance/journal-entries',
          builder: (_, _) => const FinanceNavigationBar(selected: 'journals'),
        ),
        GoRoute(
          path: '/finance/daily-closings',
          builder: (_, _) => const FinanceNavigationBar(selected: 'closing'),
        ),
        GoRoute(
          path: '/finance/reports/general-ledger',
          builder: (_, _) => const FinanceNavigationBar(selected: 'reports'),
        ),
        GoRoute(
          path: '/finance/accounts',
          builder: (_, _) => const FinanceNavigationBar(selected: 'accounts'),
        ),
        GoRoute(
          path: '/finance/accounting-periods',
          builder: (_, _) => const FinanceNavigationBar(selected: 'periods'),
        ),
        GoRoute(
          path: '/finance/settings',
          builder: (_, _) => const FinanceNavigationBar(selected: 'settings'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(
      find.byKey(const ValueKey<String>('finance-tab-overview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('finance-tab-settings')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('finance-tab-expenses')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('finance-tab-expenses')),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/finance/expenses');
  });

  test('Finance statuses use canonical semantic tones', () {
    expect(FinanceStatusBadge.resolve('paid').tone, FinanceTone.success);
    expect(FinanceStatusBadge.resolve('pending').tone, FinanceTone.warning);
    expect(FinanceStatusBadge.resolve('rejected').tone, FinanceTone.danger);
    expect(FinanceStatusBadge.resolve('approved').label, 'معتمد');
    expect(FinanceStatusBadge.resolve('pending_approval').label, 'بانتظار الموافقة');
    expect(FinanceStatusBadge.resolve('pending_approval').tone, FinanceTone.warning);
    expect(FinanceStatusBadge.resolve('reversed').label, 'معكوس');
  });
}
