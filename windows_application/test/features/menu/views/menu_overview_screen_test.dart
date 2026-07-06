import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/menu/controllers/menu_cubit.dart';
import 'package:windows_application/features/menu/repositories/mock_menu_repository.dart';
import 'package:windows_application/features/menu/views/menu_overview_screen.dart';

void main() {
  testWidgets('renders menu overview actions, KPIs, filters, and activities', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final MenuCubit cubit = MenuCubit(repository: const MockMenuRepository());
    addTearDown(cubit.close);
    await cubit.loadMenuData();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: BlocProvider<MenuCubit>.value(
            value: cubit,
            child: const MenuOverviewScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Product'), findsOneWidget);
    expect(find.text('Add Category'), findsOneWidget);
    expect(find.text('Add Modifier Group'), findsOneWidget);
    expect(find.text('Total Categories'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Total Products'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);
    expect(find.text('Active Products'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('Inactive Products'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Modifier Groups'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('All Categories'), findsOneWidget);
    expect(find.text('All Statuses'), findsOneWidget);
    expect(find.text('All Branches'), findsOneWidget);
    expect(
      find.text('Latte price updated from \$4.50 to \$4.75'),
      findsOneWidget,
    );
    expect(find.text('Pending Sync'), findsOneWidget);
  });
}
