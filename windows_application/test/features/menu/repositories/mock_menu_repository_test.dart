import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu/models/menu_enums.dart';
import 'package:windows_application/features/menu/repositories/mock_menu_repository.dart';

void main() {
  group('MockMenuRepository', () {
    const MockMenuRepository repository = MockMenuRepository();

    test('returns the expected cafe categories and products', () async {
      final categories = await repository.getCategories();
      final products = await repository.getProducts();

      expect(categories, hasLength(7));
      expect(
        categories.map((category) => category.name),
        contains('Hot Coffee'),
      );
      expect(products.map((product) => product.name), contains('Espresso'));
      expect(
        products
            .singleWhere((product) => product.name == 'Morning Start Combo')
            .type,
        ProductType.combo,
      );
    });

    test('returns modifiers, activities, and derived KPI counts', () async {
      final modifierGroups = await repository.getModifierGroups();
      final activities = await repository.getRecentActivities();
      final kpis = await repository.getMenuKpis();

      expect(
        modifierGroups.map((group) => group.name),
        contains('Milk Options'),
      );
      expect(activities, isNotEmpty);
      expect(kpis.totalCategories, 7);
      expect(kpis.totalProducts, 7);
      expect(kpis.modifierGroups, 5);
    });
  });
}
