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

  tearDown(() {
    appRouter.go(AppRoutes.pos);
  });

  testWidgets('Discounts sidebar opens the discounts list and is active', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discounts'));
    await tester.pumpAndSettle();

    expect(find.text('Discounts & Coupons'), findsOneWidget);
    expect(_discountsSidebarItem(tester).isActive, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Discounts actions remain overflow-free at the full-sidebar threshold',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go(AppRoutes.discounts);
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}

AppSidebarItem _discountsSidebarItem(WidgetTester tester) {
  return tester.widget<AppSidebarItem>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppSidebarItem && widget.label == 'Discounts',
    ),
  );
}
