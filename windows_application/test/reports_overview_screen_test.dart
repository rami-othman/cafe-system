import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/shared/widgets/app_sidebar_item.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() => appRouter.go(AppRoutes.pos));

  testWidgets('Reports route opens the overview and keeps the sidebar active', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);

    expect(find.text('Reports Overview'), findsOneWidget);
    expect(find.text('vs. Previous Period'), findsOneWidget);
    expect(
      find.byTooltip('Available in detailed report screens'),
      findsOneWidget,
    );
    expect(_reportsSidebarItem(tester).isActive, isTrue);
  });

  testWidgets('overview has a retryable backend error state', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.reports);
    await _pumpApp(tester);

    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('requires a connected backend'), findsOneWidget);
  });
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
