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

  testWidgets('1280 shows an icon rail with accessible destinations', (
    WidgetTester tester,
  ) async {
    await pumpMenuManagementHarness(
      tester,
      viewport: MenuDesktopViewport.desktop1280,
      child: const MenuModuleNavigation(
        selected: MenuModuleDestination.products,
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('menu-module-navigation'))).width,
      64,
    );
    expect(find.text('Catalog'), findsNothing);
    expect(find.byTooltip('Products'), findsOneWidget);
    expect(find.byTooltip('Review & Publish'), findsOneWidget);
    expectNoMenuLayoutOverflow(tester);
  });

  testWidgets(
    '1440 and 1920 show grouped labeled navigation and selected state',
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
          tester.getSize(find.byKey(const Key('menu-module-navigation'))).width,
          208,
        );
        expect(find.text('Catalog'), findsOneWidget);
        expect(find.text('Menus'), findsWidgets);
        expect(find.text('Release'), findsOneWidget);
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
            navigationSlot: const SizedBox(width: 64),
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
      expect(find.byTooltip('المنتجات'), findsOneWidget);
      expect(find.byTooltip('مراجعة ونشر'), findsOneWidget);
      expectNoMenuLayoutOverflow(tester);
    },
  );
}
