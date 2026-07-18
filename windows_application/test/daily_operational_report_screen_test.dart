import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/reports/controllers/daily_report_cubit.dart';
import 'package:windows_application/features/reports/views/daily_operational_report_screen.dart';
import 'package:windows_application/shared/widgets/app_sidebar_item.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() => appRouter.go(AppRoutes.pos));

  testWidgets(
    'Reports route renders the daily operational report and active sidebar item',
    (WidgetTester tester) async {
      appRouter.go(AppRoutes.reports);
      await _pumpApp(tester);

      expect(find.text('Daily Operational Report'), findsOneWidget);
      expect(find.text('Today, Oct 24, 2023'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Export Report'), findsOneWidget);
      expect(find.byTooltip('Refresh screen data'), findsOneWidget);
      expect(_reportsSidebarItem(tester).isActive, isTrue);
    },
  );

  testWidgets('daily report renders all presentation data and peak bar', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);

    for (final String value in <String>[
      '\$4,250.00',
      '\$4,632.50',
      '142',
      '\$8.77',
      '-\$125.00',
      '\$382.50',
      '-\$42.50',
      '\$650.00',
    ]) {
      expect(find.text(value), findsWidgets);
    }
    for (final String label in <String>[
      '6a',
      '7a',
      '8a',
      '9a',
      '10a',
      '11a',
      '12p',
      '1p',
      '2p',
      '3p',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('hour-bar-9a')), findsOneWidget);
    expect(find.text('Card'), findsWidgets);
    expect(find.text('Digital Wallet'), findsOneWidget);
    expect(find.text('DINE-IN'), findsOneWidget);
    expect(find.text('Vanilla Latte'), findsOneWidget);
    expect(find.text('#1042 - Wrong Item'), findsOneWidget);
    expect(find.text('Loyalty Free Coffee'), findsOneWidget);
    expect(find.text('#1142'), findsOneWidget);
    expect(find.text('Paid'), findsNWidgets(4));
    expect(find.text('Refunded'), findsOneWidget);
    expect(find.text('\$34.72'), findsOneWidget);
  });

  testWidgets('print and export actions show report action messages', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);
    await tester.tap(find.text('Print'));
    await tester.pump();
    expect(
      find.text('Print the report from your system print dialog.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Export Report'));
    await tester.pump();
    expect(
      find.text('Report data is loaded from the current branch and date.'),
      findsOneWidget,
    );
  });

  testWidgets('empty and error report states render their recovery UI', (
    WidgetTester tester,
  ) async {
    final DailyReportCubit cubit = DailyReportCubit()..showEmpty();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<DailyReportCubit>.value(
          value: cubit,
          child: const DailyOperationalReportScreen(),
        ),
      ),
    );
    expect(
      find.text('No report data is available for this date.'),
      findsOneWidget,
    );

    cubit.showError();
    await tester.pump();
    expect(find.text('The report could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'report page scrolls and remains stable at desktop and narrow widths',
    (WidgetTester tester) async {
      appRouter.go(AppRoutes.reports);
      await _pumpApp(tester);
      await tester.drag(
        find.byKey(const Key('daily-report-scroll-view')),
        const Offset(0, -500),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(820, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

AppSidebarItem _reportsSidebarItem(WidgetTester tester) =>
    tester.widget<AppSidebarItem>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppSidebarItem && widget.label == 'Reports',
      ),
    );
