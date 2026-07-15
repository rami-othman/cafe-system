import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/menu/controllers/menu_cubit.dart';
import 'package:windows_application/features/menu/repositories/mock_menu_repository.dart';
import 'package:windows_application/features/menu/views/modifier_groups_screen.dart';

void main() {
  testWidgets('renders modifier groups and the selected group detail', (
    WidgetTester tester,
  ) async {
    final MenuCubit cubit = await _loadedMenuCubit();
    addTearDown(cubit.close);

    await _pumpScreen(tester, cubit: cubit);

    expect(find.text('Modifier Groups'), findsWidgets);
    expect(find.text('New Group'), findsOneWidget);
    expect(find.text('Search modifier groups...'), findsOneWidget);
    for (final String group in <String>[
      'Milk Options',
      'Extra Shot',
      'Syrups',
      'Toppings',
      'Bread Type',
    ]) {
      expect(find.text(group), findsWidgets);
    }
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(
      find.text(
        'Manage milk alternatives and base options for espresso beverages.',
      ),
      findsOneWidget,
    );
    expect(find.text('Options (4)'), findsOneWidget);
    expect(find.text('Whole Milk'), findsOneWidget);
    expect(find.text('Oat Milk'), findsOneWidget);
    expect(find.text('Almond Milk'), findsOneWidget);
    expect(find.text('Soy Milk'), findsOneWidget);
    expect(find.text('LOW STOCK'), findsOneWidget);
    expect(find.text('Assigned Products (12)'), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.text('+6 more'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates local selection, filters groups, and shows feedback', (
    WidgetTester tester,
  ) async {
    final MenuCubit cubit = await _loadedMenuCubit();
    addTearDown(cubit.close);

    await _pumpScreen(tester, cubit: cubit);

    await tester.tap(find.byKey(const Key('modifier-group-extra-shot')));
    await tester.pump();
    expect(find.text('Add espresso shots'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('modifier-group-search')),
      'Syrups',
    );
    await tester.pump();
    expect(find.byKey(const Key('modifier-group-syrups')), findsOneWidget);
    expect(find.byKey(const Key('modifier-group-extra-shot')), findsNothing);

    await tester.tap(find.text('New Group'));
    await tester.pump();
    expect(
      find.text('New modifier group creation is not implemented yet.'),
      findsOneWidget,
    );
  });

  testWidgets('stacks safely at a compact desktop width', (
    WidgetTester tester,
  ) async {
    final MenuCubit cubit = await _loadedMenuCubit();
    addTearDown(cubit.close);

    await _pumpScreen(tester, cubit: cubit, size: const Size(760, 900));

    expect(find.text('Modifier Groups'), findsWidgets);
    expect(find.text('Options (4)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<MenuCubit> _loadedMenuCubit() async {
  final MenuCubit cubit = MenuCubit(repository: const MockMenuRepository());
  await cubit.loadMenuData();
  return cubit;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required MenuCubit cubit,
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: BlocProvider<MenuCubit>.value(
          value: cubit,
          child: const ModifierGroupsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
