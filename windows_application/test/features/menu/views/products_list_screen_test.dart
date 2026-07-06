import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/menu/controllers/menu_cubit.dart';
import 'package:windows_application/features/menu/repositories/mock_menu_repository.dart';
import 'package:windows_application/features/menu/views/products_list_screen.dart';
import 'package:windows_application/features/menu/widgets/product_status_chip.dart';
import 'package:windows_application/features/menu/widgets/product_type_chip.dart';

void main() {
  testWidgets('renders Products filters, table rows, chips, and pagination', (
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
            child: const ProductsListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Products'), findsOneWidget);
    expect(
      find.text('Manage your catalog, pricing, and availability.'),
      findsOneWidget,
    );
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Add Product'), findsOneWidget);
    expect(find.text('Search by name, SKU...'), findsOneWidget);
    expect(find.text('Category: All'), findsOneWidget);
    expect(find.text('Type: All'), findsOneWidget);
    expect(find.text('Status: All'), findsOneWidget);
    expect(find.text('Branch: All'), findsOneWidget);
    expect(find.text('Availability: All'), findsOneWidget);
    expect(find.text('More Filters'), findsOneWidget);

    for (final String product in <String>[
      'Espresso',
      'Caffe Latte',
      'Cappuccino',
      'Almond Croissant',
      'Morning Start Combo',
    ]) {
      expect(find.text(product), findsOneWidget);
    }

    expect(find.text('3 Variants (Size)'), findsOneWidget);
    expect(find.text('2 Variants (Milk)'), findsOneWidget);
    expect(find.text('Coffee + Pastry'), findsOneWidget);
    expect(find.byType(ProductTypeChip), findsNWidgets(5));
    expect(find.byType(ProductStatusChip), findsNWidgets(5));
    expect(find.text('Showing 1 to 5 of 124 entries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
