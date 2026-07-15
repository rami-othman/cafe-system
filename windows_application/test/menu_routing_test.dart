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

    expect(find.text('Cafe System 618'), findsWidgets);
    expect(find.text('Search menu...'), findsOneWidget);
    expect(find.text('Recent Menu Activity'), findsOneWidget);
    expect(_menuSidebarItem(tester).isActive, isTrue);
  });

  testWidgets('Products tab opens the Products List route', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.menu);
    await _pumpApp(tester);

    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();

    expect(find.text('Products'), findsNWidgets(2));
    expect(
      find.text('Manage your catalog, pricing, and availability.'),
      findsOneWidget,
    );
    expect(find.text('Recent Menu Activity'), findsNothing);
    expect(_menuSidebarItem(tester).isActive, isTrue);
  });

  testWidgets('/menu/products opens Products and keeps Menu active', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.menuProducts);
    await _pumpApp(tester);

    expect(find.text('Products'), findsNWidgets(2));
    expect(find.text('Menu Management'), findsWidgets);
    expect(find.text('Search by name, SKU...'), findsOneWidget);
    expect(_menuSidebarItem(tester).isActive, isTrue);
  });

  testWidgets('Add Product opens General Information and keeps Menu active', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.menuProducts);
    await _pumpApp(tester);

    await tester.tap(find.text('Add Product'));
    await tester.pumpAndSettle();

    expect(find.text('Menu Management'), findsOneWidget);
    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('Product Summary'), findsOneWidget);
    expect(find.text('Save & Continue'), findsOneWidget);
    expect(_menuSidebarItem(tester).isActive, isTrue);
  });

  testWidgets('Create Product breadcrumbs navigate to Products and Menu', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.menuProductCreate);
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('breadcrumb-products')));
    await tester.pumpAndSettle();

    expect(
      find.text('Manage your catalog, pricing, and availability.'),
      findsOneWidget,
    );

    appRouter.go(AppRoutes.menuProductCreate);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('breadcrumb-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Recent Menu Activity'), findsOneWidget);
    expect(_menuSidebarItem(tester).isActive, isTrue);
  });

  testWidgets('/menu/modifiers opens Modifier Groups and keeps Menu active', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.menuModifiers);
    await _pumpApp(tester);

    expect(find.text('Menu Management'), findsWidgets);
    expect(find.text('Modifier Groups'), findsWidgets);
    expect(find.text('Milk Options'), findsWidgets);
    expect(find.byTooltip('Search'), findsOneWidget);
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
