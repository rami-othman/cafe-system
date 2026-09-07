import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';
import 'package:windows_application/shared/widgets/shift_status_badge.dart';

// Regression coverage for the shared global AppShell (AppSidebar + the
// default AppTopBar/ShiftStatusBadge) staying bilingual on every module
// route, not just /reports. These tests drive the REAL router and App, not
// an isolated shell/module widget, so a route-specific override (like
// Finance's SizedBox.shrink() top bar or a hard-coded shell string) shows up
// exactly as a user would see it.
//
// Inventory and Finance module *content* is a separate, larger, pre-existing
// Arabic-only surface (no l10n usage at all in either feature) that is out
// of scope here — these tests only assert on the shell chrome that actually
// claims to be bilingual: the sidebar destinations and the shift-status
// badge, which both route through AppLocalizations.

const List<String> _arabicShellLabels = <String>[
  'لوحة التحكم',
  'نقطة البيع',
  'الطلبات',
  'العملاء',
  'الخصومات',
  'إدارة القائمة',
  'المخزون',
  'المالية',
  'التقارير',
  'الإعدادات',
];

const List<String> _englishShellLabels = <String>[
  'Dashboard',
  'POS',
  'Orders',
  'Customers',
  'Discounts',
  'Menu Management',
  'Inventory',
  'Finance',
  'Reports',
  'Settings',
];

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() => appRouter.go(AppRoutes.pos));

  for (final String path in <String>[
    AppRoutes.inventory,
    AppRoutes.finance,
    AppRoutes.reports,
  ]) {
    testWidgets('$path shell sidebar is Arabic with zero English leakage', (
      WidgetTester tester,
    ) async {
      // Finance replaces AppTopBar with SizedBox.shrink() (it owns its own
      // chrome), so the language selector living in AppTopBar isn't present
      // on /finance itself. Switch while the selector is available (POS),
      // then navigate to the target route to prove the persisted locale
      // still drives that route's sidebar — the realistic user path anyway,
      // since nothing requires switching language from inside every module.
      appRouter.go(AppRoutes.pos);
      await _pumpApp(tester);
      await _switchLanguage(tester, 'العربية');

      appRouter.go(path);
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      for (final String label in _arabicShellLabels) {
        expect(
          find.text(label),
          findsWidgets,
          reason: '$path sidebar is missing the Arabic label "$label"',
        );
      }
      for (final String label in _englishShellLabels) {
        expect(
          find.text(label),
          findsNothing,
          reason: '$path leaked the English shell label "$label" in Arabic mode',
        );
      }
      expect(
        Directionality.of(tester.element(find.byType(AppSidebar))),
        TextDirection.rtl,
      );
    });

    testWidgets('$path shell sidebar is English with zero Arabic leakage', (
      WidgetTester tester,
    ) async {
      appRouter.go(path);
      await _pumpApp(tester);

      for (final String label in _englishShellLabels) {
        expect(
          find.text(label),
          findsWidgets,
          reason: '$path sidebar is missing the English label "$label"',
        );
      }
      for (final String label in _arabicShellLabels) {
        expect(
          find.text(label),
          findsNothing,
          reason: '$path leaked the Arabic shell label "$label" in English mode',
        );
      }
      expect(
        Directionality.of(tester.element(find.byType(AppSidebar))),
        TextDirection.ltr,
      );
    });
  }

  testWidgets(
    'inventory shift status badge switches AR <-> EN at runtime without re-navigating',
    (WidgetTester tester) async {
      appRouter.go(AppRoutes.inventory);
      await _pumpApp(tester);

      expect(find.byType(ShiftStatusBadge), findsOneWidget);
      expect(find.text('SHIFT OPEN'), findsOneWidget);
      expect(find.text('الوردية مفتوحة'), findsNothing);

      await _switchLanguage(tester, 'العربية');
      expect(appRouter.state.uri.path, AppRoutes.inventory);
      expect(find.text('الوردية مفتوحة'), findsOneWidget);
      expect(find.text('SHIFT OPEN'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(ShiftStatusBadge))),
        TextDirection.rtl,
      );

      await _switchLanguage(tester, 'English');
      expect(appRouter.state.uri.path, AppRoutes.inventory);
      expect(find.text('SHIFT OPEN'), findsOneWidget);
      expect(find.text('الوردية مفتوحة'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(ShiftStatusBadge))),
        TextDirection.ltr,
      );
    },
  );

  testWidgets(
    'finance shell and Reports shell both show the shared POS shift badge',
    (WidgetTester tester) async {
      // Finance, Reports, Menu Management, and Inventory all render the
      // exact same shared AppTopBar (see app_router.dart's _topBarFor), so
      // the shift badge (and its localization) is not module-specific — it
      // is exercised in depth on Inventory above; here we only confirm
      // Finance and Reports render it too, rather than a bespoke chrome.
      appRouter.go(AppRoutes.finance);
      await _pumpApp(tester);
      expect(find.byType(ShiftStatusBadge), findsOneWidget);

      appRouter.go(AppRoutes.reports);
      await _pumpApp(tester);
      expect(find.byType(ShiftStatusBadge), findsOneWidget);
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
  // Inventory (and Finance) content hits real network calls with no backend
  // reachable in this sandbox; that is pre-existing and out of scope for a
  // shell/chrome test (see finance_route_smoke_test.dart), so drain it.
  while (tester.takeException() != null) {}
}

Future<void> _switchLanguage(WidgetTester tester, String optionLabel) async {
  await tester.tap(find.byKey(const Key('app-language-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionLabel));
  await tester.pumpAndSettle();
  while (tester.takeException() != null) {}
}
