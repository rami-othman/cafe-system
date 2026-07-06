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
      expect(products.first.sku, 'BEV-ESP-01');
      expect(products.first.categoryName, 'Beverages');
      expect(products.first.basePrice, 3.50);
      expect(products[1].sku, 'BEV-LAT-00');
      expect(products[1].listSubtitle, '3 Variants (Size)');
      expect(products[2].status, ProductStatus.inactive);
      expect(
        products
            .singleWhere((product) => product.name == 'Morning Start Combo')
            .basePrice,
        8.00,
      );
      expect(
        products
            .singleWhere((product) => product.name == 'Morning Start Combo')
            .type,
        ProductType.combo,
      );
    });

    test('returns modifiers, overview activities, and KPI counts', () async {
      final modifierGroups = await repository.getModifierGroups();
      final activities = await repository.getRecentActivities();
      final kpis = await repository.getMenuKpis();

      expect(
        modifierGroups.map((group) => group.name),
        contains('Milk Options'),
      );
      final milkOptions = modifierGroups.first;
      expect(milkOptions.options, hasLength(4));
      expect(milkOptions.assignedProductIds, hasLength(12));
      expect(modifierGroups[1].options, hasLength(3));
      expect(modifierGroups[1].assignedProductIds, hasLength(8));
      expect(modifierGroups[2].options, hasLength(6));
      expect(modifierGroups[2].assignedProductIds, hasLength(15));
      expect(modifierGroups[3].options, hasLength(4));
      expect(modifierGroups[3].assignedProductIds, hasLength(5));
      expect(activities, hasLength(5));
      expect(
        activities.first.activity,
        'Latte price updated from \$4.50 to \$4.75',
      );
      expect(activities[2].status, 'Pending Sync');
      expect(kpis.totalCategories, 12);
      expect(kpis.totalProducts, 84);
      expect(kpis.activeProducts, 78);
      expect(kpis.inactiveProducts, 6);
      expect(kpis.modifierGroups, 15);
    });
  });
}
