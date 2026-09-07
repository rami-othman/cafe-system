import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/reports/models/reports_overview.dart';
import 'package:windows_application/features/reports/repositories/reports_repository.dart';
import 'package:windows_application/features/reports/views/reports_overview_screen.dart';
import 'package:windows_application/shared/widgets/app_sidebar_item.dart';
import 'package:windows_application/shared/widgets/app_top_bar.dart';
import 'package:windows_application/shared/widgets/shift_status_badge.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() => appRouter.go(AppRoutes.pos));

  testWidgets('Reports route resolves to ReportsOverviewScreen and keeps the sidebar active', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);

    expect(find.byType(ReportsOverviewScreen), findsOneWidget);
    expect(find.text('Reports Overview'), findsOneWidget);
    expect(find.text('vs. Previous Period'), findsOneWidget);
    expect(
      find.byTooltip('Available in detailed report screens'),
      findsOneWidget,
    );
    expect(_reportsSidebarItem(tester, 'Reports').isActive, isTrue);
  });

  testWidgets('Reports module header shows the shared POS chrome', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);

    expect(find.byType(AppTopBar), findsOneWidget);
    // "Reports" appears once, as the sidebar nav item — the shared top bar
    // now shows POS branch tabs instead of a static module label, the same
    // chrome every other module renders (see app_router.dart's _topBarFor).
    expect(find.text('Reports'), findsWidgets);
    expect(find.byType(ShiftStatusBadge), findsOneWidget);
    // The offline PosCubit fixture supplies exactly one branch ("Downtown"),
    // which now surfaces as the shared top bar's branch tab.
    expect(find.text('Downtown'), findsOneWidget);
  });

  testWidgets('Reports module header shows the Arabic label under RTL', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);
    await _switchLanguage(tester, 'العربية');

    expect(find.text('التقارير'), findsWidgets);
    expect(find.text('نظرة عامة على التقارير'), findsOneWidget);
    expect(find.text('كل الفروع'), findsOneWidget);
    expect(find.text('مقارنة بالفترة السابقة'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(AppTopBar))),
      TextDirection.rtl,
    );
    expect(_reportsSidebarItem(tester, 'التقارير').isActive, isTrue);
    // No mixed languages.
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Reports Overview'), findsNothing);
    expect(find.text('All branches'), findsNothing);
  });

  testWidgets('Reports reacts to runtime language switching without re-navigating', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);
    expect(find.text('Reports Overview'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(AppTopBar))),
      TextDirection.ltr,
    );

    await _switchLanguage(tester, 'العربية');
    expect(find.text('نظرة عامة على التقارير'), findsOneWidget);
    expect(find.text('Reports Overview'), findsNothing);
    expect(
      Directionality.of(tester.element(find.byType(AppTopBar))),
      TextDirection.rtl,
    );

    await _switchLanguage(tester, 'English');
    expect(find.text('Reports Overview'), findsOneWidget);
    expect(find.text('نظرة عامة على التقارير'), findsNothing);
    expect(
      Directionality.of(tester.element(find.byType(AppTopBar))),
      TextDirection.ltr,
    );
  });

  testWidgets('empty-state messaging renders when there is no data for the period', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);

    // useBackend:false returns a real, successful but empty overview.
    expect(
      find.text('Choose all branches to compare performance.'),
      findsOneWidget,
    );
    expect(
      find.text('No products were sold for this period.'),
      findsOneWidget,
    );
    expect(
      find.text('No operational exceptions found for this period.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'sales trend chart keeps chronological labels aligned to the line under RTL',
    (WidgetTester tester) async {
      // The line is painted left-to-right in raw pixels regardless of app
      // text direction; the start/end date labels must stay aligned to it
      // (start on the physical left) instead of being mirrored by RTL Row
      // layout, which would misdescribe which end of the chart is which.
      serviceLocator.unregister<ReportsRepository>();
      serviceLocator.registerLazySingleton<ReportsRepository>(
        () => _TrendReportsRepository(),
      );

      appRouter.go(AppRoutes.reports);
      await _pumpApp(tester);
      await _switchLanguage(tester, 'العربية');

      final double startX = tester
          .getTopLeft(find.byKey(const Key('trend-chart-start-label')))
          .dx;
      final double endX = tester
          .getTopLeft(find.byKey(const Key('trend-chart-end-label')))
          .dx;
      expect(
        startX,
        lessThan(endX),
        reason:
            'earliest date label must stay on the physical left even in RTL',
      );
    },
  );

  testWidgets('fixed module header stays visible while report content scrolls', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);

    final Offset before = tester.getTopLeft(find.byType(AppTopBar));
    await tester.drag(
      find.byKey(const Key('reports-overview-scroll-view')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    final Offset after = tester.getTopLeft(find.byType(AppTopBar));

    expect(after, before);
    expect(find.byType(AppTopBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview has a retryable backend error state and Retry actually reloads', (
    WidgetTester tester,
  ) async {
    // The offline/demo repository (useBackend: false) succeeds with an
    // empty overview rather than failing, so the error state has to be
    // triggered by a repository that actually throws.
    final _FailingReportsRepository repository = _FailingReportsRepository();
    serviceLocator.unregister<ReportsRepository>();
    serviceLocator.registerLazySingleton<ReportsRepository>(() => repository);

    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);

    // The raw exception text must never reach the UI: only the localized
    // error message is shown, in either language.
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('The overview could not be loaded.'), findsOneWidget);
    expect(find.textContaining('Backend is not reachable'), findsNothing);

    repository.shouldFail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsNothing);
    expect(find.text('The overview could not be loaded.'), findsNothing);
    expect(find.text('Reports Overview'), findsOneWidget);
  });

  testWidgets('overview error state is localized in Arabic with no English leakage', (
    WidgetTester tester,
  ) async {
    final _FailingReportsRepository repository = _FailingReportsRepository();
    serviceLocator.unregister<ReportsRepository>();
    serviceLocator.registerLazySingleton<ReportsRepository>(() => repository);

    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);
    await _switchLanguage(tester, 'العربية');

    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('تعذّر تحميل النظرة العامة.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('Backend is not reachable'), findsNothing);

    repository.shouldFail = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(find.text('نظرة عامة على التقارير'), findsOneWidget);
  });

  for (final double width in <double>[1280, 1366, 1440, 1600, 1920]) {
    testWidgets('remains overflow-free in English at $width', (
      WidgetTester tester,
    ) async {
      appRouter.go(AppRoutes.reports);
      await _pumpApp(tester, size: Size(width, 900));
      expect(tester.takeException(), isNull);
    });

    testWidgets('remains overflow-free in Arabic at $width', (
      WidgetTester tester,
    ) async {
      appRouter.go(AppRoutes.reports);
      await _pumpApp(tester, size: Size(width, 900));
      await _switchLanguage(tester, 'العربية');
      expect(tester.takeException(), isNull);
    });
  }
}

class _FailingReportsRepository extends ReportsRepository {
  _FailingReportsRepository();

  bool shouldFail = true;

  @override
  Future<ReportsOverview> getOverview({
    required DateTime from,
    required DateTime to,
    int? branchId,
    required bool comparePrevious,
  }) async {
    if (shouldFail) {
      throw Exception('Backend is not reachable.');
    }
    return ReportsOverview.fromJson(<String, dynamic>{
      'period': <String, dynamic>{
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
      'currency': 'SYP',
      'branches': const <dynamic>[],
      'selectedBranchId': branchId,
      'kpis': const <String, dynamic>{},
      'salesTrend': const <dynamic>[],
      'branchComparison': const <dynamic>[],
      'topProducts': const <dynamic>[],
      'recentExceptions': const <dynamic>[],
    });
  }
}

class _TrendReportsRepository extends ReportsRepository {
  _TrendReportsRepository();

  @override
  Future<ReportsOverview> getOverview({
    required DateTime from,
    required DateTime to,
    int? branchId,
    required bool comparePrevious,
  }) async => ReportsOverview.fromJson(<String, dynamic>{
    'period': <String, dynamic>{
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    },
    'currency': 'SYP',
    'branches': const <dynamic>[],
    'selectedBranchId': branchId,
    'kpis': const <String, dynamic>{},
    'salesTrend': <Map<String, dynamic>>[
      <String, dynamic>{
        'date': DateTime(2024, 1, 1).toIso8601String(),
        'netSales': 100,
      },
      <String, dynamic>{
        'date': DateTime(2024, 1, 14).toIso8601String(),
        'netSales': 400,
      },
    ],
    'branchComparison': const <dynamic>[],
    'topProducts': const <dynamic>[],
    'recentExceptions': const <dynamic>[],
  });
}

Future<void> _pumpApp(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

Future<void> _switchLanguage(WidgetTester tester, String optionLabel) async {
  await tester.tap(find.byKey(const Key('app-language-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionLabel));
  await tester.pumpAndSettle();
}

AppSidebarItem _reportsSidebarItem(WidgetTester tester, String label) =>
    tester.widget<AppSidebarItem>(
      find.byWidgetPredicate(
        (Widget widget) => widget is AppSidebarItem && widget.label == label,
      ),
    );
