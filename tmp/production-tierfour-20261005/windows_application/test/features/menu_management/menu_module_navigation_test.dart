import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_colors.dart';
import 'package:windows_application/features/menu_management/widgets/menu_module_navigation.dart';
import 'package:windows_application/features/menu_management/widgets/menu_module_scaffold.dart';

import '../../support/menu_management_test_harness.dart';

void main() {
  test('deep routes resolve to one parent Menu Management destination', () {
    final Map<MenuModuleDestination, List<String>> routes =
        <MenuModuleDestination, List<String>>{
          MenuModuleDestination.products: <String>[
            '/menu-management/products',
            '/menu-management/products/create',
            '/menu-management/products/7',
            '/menu-management/products/7/edit',
            '/menu-management/products/7/variants',
            '/menu-management/products/7/modifiers',
            '/menu-management/product-variants/9/recipe?productId=7',
            '/menu-management/product-variants/not-an-id/recipe',
            '/menu-management/products/7/modifier-options/2/recipe-adjustments',
          ],
          MenuModuleDestination.modifiers: <String>[
            '/menu-management/modifiers',
            '/menu-management/modifiers/4',
            '/menu-management/modifiers/4/edit',
            '/menu-management/modifier-options/2/recipe-adjustments',
          ],
          MenuModuleDestination.menus: <String>[
            '/menu-management/menus',
            '/menu-management/menus/create',
            '/menu-management/menus/5',
            '/menu-management/menus/5/placements',
          ],
          MenuModuleDestination.assignments: <String>[
            '/menu-management/assignments?branchId=1&channel=pos',
          ],
          MenuModuleDestination.review: <String>[
            '/menu-management/review?tab=versions',
          ],
          MenuModuleDestination.catalogSetup: <String>[
            '/menu-management/catalog-setup?tab=categories',
            '/menu-management/catalog-setup?tab=reporting-categories',
            '/menu-management/catalog-setup?tab=kitchen-stations',
          ],
        };

    for (final MapEntry<MenuModuleDestination, List<String>> entry
        in routes.entries) {
      for (final String route in entry.value) {
        expect(
          MenuModuleDestination.forPath(Uri.parse(route).path),
          entry.key,
          reason: route,
        );
      }
    }
  });

  testWidgets(
    '1280 shows all grouped horizontal destinations without overflow',
    (WidgetTester tester) async {
      await pumpMenuManagementHarness(
        tester,
        viewport: MenuDesktopViewport.desktop1280,
        child: const MenuModuleNavigation(
          selected: MenuModuleDestination.products,
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('menu-module-navigation'))).width,
        1280,
      );
      expect(
        tester
            .widget<Container>(find.byKey(const Key('menu-module-navigation')))
            .color,
        AppColors.contentBackground,
      );
      expect(
        tester.getSize(find.byKey(const Key('menu-module-products'))).height,
        44,
      );
      for (final MenuModuleDestination destination
          in MenuModuleDestination.values) {
        expect(
          find.byKey(Key('menu-module-${destination.name}')),
          findsOneWidget,
        );
      }
      final Text assignments = tester.widget<Text>(
        find.text('Assignments & Schedules'),
      );
      expect(assignments.maxLines, 1);
      expect(assignments.softWrap, isFalse);
      expectNoMenuLayoutOverflow(tester);
    },
  );

  testWidgets(
    '1440 and 1920 show grouped horizontal navigation and selected state',
    (WidgetTester tester) async {
      for (final MenuDesktopViewport viewport in <MenuDesktopViewport>[
        MenuDesktopViewport.desktop1440,
        MenuDesktopViewport.desktop1920,
      ]) {
        await pumpMenuManagementHarness(
          tester,
          viewport: viewport,
          child: const MenuModuleNavigation(
            selected: MenuModuleDestination.assignments,
          ),
        );

        expect(
          find.byKey(const Key('menu-module-assignments')),
          findsOneWidget,
        );
        final SemanticsHandle semantics = tester.ensureSemantics();
        expect(
          tester
              .getSemantics(find.byKey(const Key('menu-module-assignments')))
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        semantics.dispose();
        expectNoMenuLayoutOverflow(tester);
      }
    },
  );

  testWidgets('navigation destinations are keyboard reachable and actionable', (
    WidgetTester tester,
  ) async {
    final List<MenuModuleDestination> selections = <MenuModuleDestination>[];
    await pumpMenuManagementHarness(
      tester,
      child: MenuModuleNavigation(
        selected: MenuModuleDestination.products,
        onDestinationSelected: selections.add,
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(selections, <MenuModuleDestination>[
      MenuModuleDestination.modifiers,
    ]);
  });

  testWidgets('pointer navigation selects the configured destination', (
    WidgetTester tester,
  ) async {
    MenuModuleDestination? selection;
    await pumpMenuManagementHarness(
      tester,
      child: MenuModuleNavigation(
        selected: MenuModuleDestination.products,
        onDestinationSelected: (MenuModuleDestination destination) {
          selection = destination;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('menu-module-assignments')));

    expect(selection, MenuModuleDestination.assignments);
    expect(selection!.path, '/menu-management/assignments');
  });

  testWidgets('module scaffold renders navigation above the full workspace', (
    WidgetTester tester,
  ) async {
    await pumpMenuManagementHarness(
      tester,
      viewport: MenuDesktopViewport.desktop1280,
      child: MenuModuleScaffold(
        navigationSlot: const MenuModuleNavigation(
          selected: MenuModuleDestination.products,
        ),
        child: const SizedBox(key: Key('menu-module-workspace')),
      ),
    );

    final Finder navigation = find.byKey(const Key('menu-module-navigation'));
    final Finder workspace = find.byKey(const Key('menu-module-workspace'));
    expect(tester.getSize(navigation).width, 1280);
    expect(tester.getTopLeft(navigation).dy, 0);
    expect(tester.getTopLeft(workspace).dy, greaterThan(0));
    expectNoMenuLayoutOverflow(tester);
  });

  testWidgets('breadcrumbs reflect deep route context without technical IDs', (
    WidgetTester tester,
  ) async {
    late List<MenuBreadcrumb> breadcrumbs;
    await pumpMenuManagementHarness(
      tester,
      child: Builder(
        builder: (BuildContext context) {
          breadcrumbs = menuModuleBreadcrumbsFor(
            context,
            Uri.parse('/menu-management/products/7/variants'),
          );
          return MenuModuleScaffold(
            navigationSlot: const SizedBox(height: 64),
            breadcrumbs: breadcrumbs,
            child: const SizedBox.expand(
              child: ColoredBox(color: AppColors.surface),
            ),
          );
        },
      ),
    );

    expect(breadcrumbs.map((MenuBreadcrumb item) => item.label), <String>[
      'Products',
      'Product',
      'Variants',
    ]);
    expect(find.text('7'), findsNothing);
    expectNoMenuLayoutOverflow(tester);
  });

  testWidgets('Catalog Setup omits its redundant breadcrumb row', (
    WidgetTester tester,
  ) async {
    late List<MenuBreadcrumb> breadcrumbs;
    await pumpMenuManagementHarness(
      tester,
      child: Builder(
        builder: (BuildContext context) {
          breadcrumbs = menuModuleBreadcrumbsFor(
            context,
            Uri.parse('/menu-management/catalog-setup?tab=categories'),
          );
          return const SizedBox.shrink();
        },
      ),
    );

    expect(breadcrumbs, isEmpty);
  });

  testWidgets(
    'recipe child breadcrumbs retain their canonical workspace parent',
    (WidgetTester tester) async {
      late List<MenuBreadcrumb> breadcrumbs;
      await pumpMenuManagementHarness(
        tester,
        child: Builder(
          builder: (BuildContext context) {
            breadcrumbs = menuModuleBreadcrumbsFor(
              context,
              Uri.parse(
                '/menu-management/products/7/variants/9/recipe-simulation',
              ),
            );
            return const SizedBox.shrink();
          },
        ),
      );

      expect(breadcrumbs.map((MenuBreadcrumb item) => item.label), <String>[
        'Products',
        'Product',
        'Recipe & Materials',
        'Test Recipe',
      ]);
      expect(breadcrumbs[0].onTap, isNotNull);
      expect(breadcrumbs[1].onTap, isNotNull);
      expect(breadcrumbs[2].onTap, isNotNull);
      expect(breadcrumbs[3].onTap, isNull);
    },
  );

  testWidgets(
    'Arabic navigation mirrors safely and localizes labels/tooltips',
    (WidgetTester tester) async {
      await pumpMenuManagementHarness(
        tester,
        viewport: MenuDesktopViewport.desktop1280,
        locale: const Locale('ar'),
        child: const MenuModuleNavigation(
          selected: MenuModuleDestination.review,
        ),
      );

      expectMenuTextDirection(
        tester,
        find.byKey(const Key('menu-module-navigation')),
        TextDirection.rtl,
      );
      expect(find.text('المنتجات'), findsOneWidget);
      expect(find.text('مراجعة ونشر'), findsOneWidget);
      expectNoMenuLayoutOverflow(tester);
    },
  );
}
