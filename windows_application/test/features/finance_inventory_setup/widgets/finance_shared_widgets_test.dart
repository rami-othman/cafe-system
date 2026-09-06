import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_components.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_design.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_navigation_bar.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_pagination.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_module_shell.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_shell.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/l10n/app_localizations_ar.dart';
import 'package:windows_application/l10n/app_localizations_en.dart';

final AppLocalizationsAr _ar = AppLocalizationsAr();
final AppLocalizationsEn _en = AppLocalizationsEn();

void main() {
  // Ambient Directionality now comes from MaterialApp.locale (Arabic ->
  // RTL, English -> LTR) rather than a manual wrapper, matching every real
  // Finance route. Defaults to Arabic/RTL since that is what most of these
  // widget-level assertions below exercise.
  Widget app(Widget child, {Locale locale = const Locale('ar')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
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
    expect(find.text(_ar.financeStatusApproved), findsOneWidget);
    expect(find.text(_ar.financeStatusCompleted), findsOneWidget);
    expect(find.text(_ar.financeReadinessPanelTitle), findsOneWidget);
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
            title: 'نظرة عامة',
            showContext: true,
            child: FinanceEmptyState(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'Finance module shell renders the breadcrumb and nav exactly once',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          const FinanceModuleShell(
            currentSection: 'نظرة عامة',
            selectedTab: 'overview',
            child: FinanceShell(
              title: 'نظرة عامة',
              child: FinanceEmptyState(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text(_ar.financeBreadcrumb(_ar.navigationFinance, 'نظرة عامة')),
        findsOneWidget,
      );
      expect(find.byType(FinanceNavigationBar), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    },
  );

  testWidgets(
    'Finance module shell and navigation bar are English/LTR under English locale',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          const FinanceModuleShell(
            currentSection: 'Overview',
            selectedTab: 'overview',
            child: FinanceShell(title: 'Overview', child: FinanceEmptyState()),
          ),
          locale: const Locale('en'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text(_en.financeBreadcrumb(_en.navigationFinance, 'Overview')),
        findsOneWidget,
      );
      expect(find.text(_en.financeSectionExpenses), findsOneWidget);
      expect(find.text(_ar.financeSectionExpenses), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(FinanceNavigationBar))),
        TextDirection.ltr,
      );
    },
  );

  for (final Locale locale in <Locale>[
    const Locale('ar'),
    const Locale('en'),
  ]) {
    testWidgets(
      'amount and references stay LTR under ambient ${locale.languageCode}',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          app(
            const Column(
              children: <Widget>[
                FinanceAmount(value: '1,234.50'),
                FinanceReference(reference: 'JV-2026-001'),
              ],
            ),
            locale: locale,
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
      },
    );
  }

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
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
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

  test('Finance statuses use canonical semantic tones in Arabic', () {
    expect(FinanceStatusBadge.resolve(_ar, 'paid').tone, FinanceTone.success);
    expect(FinanceStatusBadge.resolve(_ar, 'pending').tone, FinanceTone.warning);
    expect(FinanceStatusBadge.resolve(_ar, 'rejected').tone, FinanceTone.danger);
    expect(FinanceStatusBadge.resolve(_ar, 'approved').label, _ar.financeStatusApproved);
    expect(
      FinanceStatusBadge.resolve(_ar, 'pending_approval').label,
      _ar.financeStatusPendingApproval,
    );
    expect(
      FinanceStatusBadge.resolve(_ar, 'pending_approval').tone,
      FinanceTone.warning,
    );
    expect(FinanceStatusBadge.resolve(_ar, 'reversed').label, _ar.financeStatusReversed);
    expect(
      FinanceStatusBadge.resolve(_ar, 'partially_paid').label,
      _ar.financeStatusPartiallyPaid,
    );
    expect(FinanceStatusBadge.resolve(_ar, 'locked').label, _ar.financeStatusLocked);
  });

  test('Finance statuses use canonical semantic tones in English', () {
    expect(FinanceStatusBadge.resolve(_en, 'paid').tone, FinanceTone.success);
    expect(FinanceStatusBadge.resolve(_en, 'approved').label, 'Approved');
    expect(
      FinanceStatusBadge.resolve(_en, 'pending_approval').label,
      'Pending Approval',
    );
    expect(FinanceStatusBadge.resolve(_en, 'reversed').label, 'Reversed');
    expect(FinanceStatusBadge.resolve(_en, 'approved').label, isNot('معتمد'));
  });
}
