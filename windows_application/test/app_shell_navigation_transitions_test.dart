import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/shared/widgets/app_sidebar_item.dart';

// Route-scoped widget tests elsewhere in this suite all call
// `appRouter.go(path)` BEFORE the first `pumpWidget`, so the app is built
// cold, already at the target route. That never exercises an in-app route
// TRANSITION, which is how a real user actually gets anywhere after launch.
// A ShellRoute-level MultiBlocProvider whose `providers` list length changed
// conditionally (e.g. `if (isReports) BlocProvider<ReportsOverviewCubit>(...)`)
// passed every cold-start test yet threw ProviderNotFoundException the first
// time a real session navigated POS -> Reports, because changing the list's
// length reshapes the provider chain's nested Elements out from under the
// already-mounted subtree. Keep every module's providers scoped to its own
// GoRoute builder (matching Finance/Orders/Discounts) — never conditionally
// sized at the ShellRoute level — and keep this test exercising real,
// in-app, repeated transitions to catch the next regression of this class.
void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() => appRouter.go(AppRoutes.pos));

  Future<void> tapSidebar(WidgetTester tester, String label) async {
    await tester.tap(
      find.byWidgetPredicate(
        (Widget widget) => widget is AppSidebarItem && widget.label == label,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'navigating between every main-shell module within a running app never throws',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String destination in <String>[
        'Reports',
        'POS',
        'Finance',
        'POS',
        'Inventory',
        'POS',
        'Orders',
        'POS',
        'Reports',
      ]) {
        await tapSidebar(tester, destination);
        expect(
          tester.takeException(),
          isNull,
          reason: 'navigating to $destination threw',
        );
      }
      expect(find.text('Reports Overview'), findsOneWidget);
    },
  );
}
