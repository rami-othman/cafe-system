import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu/controllers/menu_cubit.dart';
import 'package:windows_application/features/menu/controllers/menu_state.dart';
import 'package:windows_application/features/menu/models/menu_enums.dart';
import 'package:windows_application/features/menu/repositories/mock_menu_repository.dart';

void main() {
  group('MenuCubit', () {
    late MenuCubit cubit;

    setUp(() {
      cubit = MenuCubit(repository: const MockMenuRepository());
    });

    tearDown(() => cubit.close());

    test('loads all menu foundation data', () async {
      await cubit.loadMenuData();

      expect(cubit.state.loadingStatus, MenuLoadingStatus.loaded);
      expect(cubit.state.categories, hasLength(7));
      expect(cubit.state.products, hasLength(7));
      expect(cubit.state.modifierGroups, hasLength(5));
      expect(cubit.state.recentActivities, isNotEmpty);
      expect(cubit.state.errorMessage, isNull);
    });

    test(
      'filters products by search, category, type, status, and branch',
      () async {
        await cubit.loadMenuData();
        cubit.updateSearchQuery('lat');
        cubit.updateFilters(
          category: 'hot-coffee',
          type: ProductType.variant,
          status: ProductStatus.active,
          branch: 'downtown',
        );

        expect(
          cubit.getFilteredProducts().map((product) => product.name),
          <String>['Caffe Latte'],
        );
      },
    );

    test('changes the selected menu tab', () {
      cubit.changeTab(MenuTab.products);

      expect(cubit.state.selectedMenuTab, MenuTab.products);
    });
  });
}
