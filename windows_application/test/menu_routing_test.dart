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

  testWidgets('Menu sidebar opens the menu overview route', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Menu Management'), findsOneWidget);
    expect(_menuSidebarItem(tester).isActive, isTrue);
  });

  testWidgets('/menu/products opens Products and keeps Menu active', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.menuProducts);
    await _pumpApp(tester);

    expect(find.text('Products'), findsOneWidget);
    expect(_menuSidebarItem(tester).isActive, isTrue);
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

AppSidebarItem _menuSidebarItem(WidgetTester tester) {
  return tester.widget<AppSidebarItem>(
    find.byWidgetPredicate(
      (Widget widget) => widget is AppSidebarItem && widget.label == 'Menu',
    ),
  );
}
